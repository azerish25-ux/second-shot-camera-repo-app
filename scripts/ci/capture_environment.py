#!/usr/bin/env python3
"""Record the exact toolchain and runner used for simulator evidence."""

from __future__ import annotations

import json
import os
import platform
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ARTIFACTS = ROOT / "artifacts/ios"


def run(command: list[str]) -> dict[str, object]:
    try:
        process = subprocess.run(command, capture_output=True, text=True, check=False)
    except FileNotFoundError as error:
        return {"command": command, "available": False, "error": str(error)}
    return {
        "command": command,
        "available": True,
        "status": process.returncode,
        "stdout": process.stdout.strip(),
        "stderr": process.stderr.strip(),
    }


def main() -> int:
    ARTIFACTS.mkdir(parents=True, exist_ok=True)

    if sys.platform != "darwin":
        print("error: environment capture requires macOS with Xcode.", file=sys.stderr)
        return 1

    environment = {
        "commit": os.environ.get("GITHUB_SHA"),
        "ref": os.environ.get("GITHUB_REF"),
        "workflow": os.environ.get("GITHUB_WORKFLOW"),
        "runId": os.environ.get("GITHUB_RUN_ID"),
        "attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
        "runnerImage": os.environ.get("ImageOS"),
        "runnerImageVersion": os.environ.get("ImageVersion"),
        "hostname": platform.node(),
        "architecture": platform.machine(),
        "python": platform.python_version(),
        "developerDir": os.environ.get("DEVELOPER_DIR"),
        "expectedXcode": os.environ.get("SECOND_SHOT_EXPECTED_XCODE"),
        "xcodebuild": run(["xcodebuild", "-version"]),
        "swift": run(["swift", "--version"]),
        "iphonesimulatorSDK": run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"]),
        "osVersion": run(["sw_vers"]),
    }

    (ARTIFACTS / "environment.json").write_text(
        json.dumps(environment, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    for name, command in (
        ("runtimes.json", ["xcrun", "simctl", "list", "runtimes", "--json"]),
        ("devices.json", ["xcrun", "simctl", "list", "--json"]),
    ):
        result = run(command)
        if not result.get("available") or result.get("status") != 0:
            print(f"error: could not capture {name}: {result}", file=sys.stderr)
            return 1
        (ARTIFACTS / name).write_text(str(result["stdout"]) + "\n", encoding="utf-8")

    xcode_output = environment["xcodebuild"]
    print(f"Xcode: {xcode_output.get('stdout', '') if isinstance(xcode_output, dict) else xcode_output}")
    print(f"Environment captured in {ARTIFACTS / 'environment.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
