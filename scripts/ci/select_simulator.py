#!/usr/bin/env python3
"""Select an available iPhone simulator deterministically.

Input is the JSON produced by ``xcrun simctl list --json``. Selection prefers the
newest available iOS runtime that has an available iPhone device, then the first
device in stable name order. Nothing is guessed: a missing runtime or device is
an actionable failure, never a silent platform switch.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


class SelectionError(RuntimeError):
    """Raised when the inventory cannot satisfy the selection contract."""


def is_available(entry: dict[str, Any]) -> bool:
    """Honour both the boolean flag and the human-readable availability string."""
    if entry.get("isAvailable") is False:
        return False
    availability = entry.get("availability")
    if availability is None:
        return True
    text = str(availability).strip().lower()
    if "unavailable" in text:
        return False
    return "available" in text or text in {"", "yes", "true"}


def parse_version(value: Any) -> tuple[int, ...]:
    numbers = re.findall(r"\d+", str(value))
    if not numbers:
        return (0,)
    return tuple(int(number) for number in numbers)


def available_ios_runtimes(inventory: dict[str, Any]) -> list[dict[str, Any]]:
    runtimes = inventory.get("runtimes")
    if not isinstance(runtimes, list):
        raise SelectionError(
            "Simulator inventory has no 'runtimes' array. "
            "Run 'xcrun simctl list --json' and check Xcode is selected."
        )
    selected = []
    for runtime in runtimes:
        if not isinstance(runtime, dict):
            continue
        if runtime.get("platform") != "iOS":
            continue
        if not runtime.get("identifier"):
            continue
        if not is_available(runtime):
            continue
        selected.append(runtime)
    return selected


def select_simulator(inventory: dict[str, Any], family: str = "iPhone") -> dict[str, Any]:
    runtimes = available_ios_runtimes(inventory)
    if not runtimes:
        raise SelectionError(
            "No available iOS simulator runtime found. Install an iOS runtime in Xcode "
            "or check the runner image; the workflow does not download one implicitly."
        )

    runtimes.sort(key=lambda runtime: (parse_version(runtime.get("version")), runtime["identifier"]), reverse=True)

    devices_by_runtime = inventory.get("devices")
    if not isinstance(devices_by_runtime, dict):
        raise SelectionError("Simulator inventory has no 'devices' map.")

    tried: list[str] = []
    for runtime in runtimes:
        identifier = runtime["identifier"]
        devices = devices_by_runtime.get(identifier, [])
        if not isinstance(devices, list):
            devices = []
        candidates = [
            device
            for device in devices
            if isinstance(device, dict)
            and device.get("udid")
            and str(device.get("name", "")).startswith(family)
            and is_available(device)
        ]
        tried.append(f"{identifier} ({len(candidates)} usable {family} device(s))")
        if not candidates:
            continue
        candidates.sort(key=lambda device: (str(device.get("name", "")), str(device.get("udid", ""))))
        device = candidates[0]
        return {
            "runtime": identifier,
            "runtimeVersion": runtime.get("version"),
            "runtimeName": runtime.get("name"),
            "name": device.get("name"),
            "udid": device.get("udid"),
            "os": runtime.get("version"),
        }

    raise SelectionError(
        "No available {family} device on any available iOS runtime. Tried: {tried}".format(
            family=family, tried="; ".join(tried)
        )
    )


def load_inventory(path: str) -> dict[str, Any]:
    try:
        if path == "-":
            data = sys.stdin.read()
        else:
            data = Path(path).read_text(encoding="utf-8")
    except OSError as error:
        raise SelectionError(f"Could not read simulator inventory at {path}: {error}") from error
    try:
        payload = json.loads(data)
    except json.JSONDecodeError as error:
        raise SelectionError(f"Simulator inventory is not valid JSON: {error}") from error
    if not isinstance(payload, dict):
        raise SelectionError("Simulator inventory must be a JSON object.")
    return payload


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", required=True, help="Path to simctl JSON output, or - for stdin")
    parser.add_argument("--output", help="Optional path for the selection JSON")
    parser.add_argument("--field", help="Print a single field instead of JSON")
    parser.add_argument("--family", default="iPhone", help="Device family prefix (default: iPhone)")
    args = parser.parse_args(argv)

    try:
        selection = select_simulator(load_inventory(args.inventory), family=args.family)
    except SelectionError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    if args.field:
        if args.field not in selection:
            print(f"error: unknown field {args.field!r}", file=sys.stderr)
            return 2
        print(selection[args.field])
        return 0

    payload = json.dumps(selection, indent=2, sort_keys=True)
    if args.output:
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(payload + "\n", encoding="utf-8")
        print(f"selected {selection['name']} ({selection['udid']}) on {selection['runtime']}")
    else:
        print(payload)
    return 0


if __name__ == "__main__":
    sys.exit(main())
