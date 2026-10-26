#!/usr/bin/env python3
"""Collect and validate Xcode test evidence.

Tests that ran but produced no screenshots, no executed cases, skips, or only one
of the required suites do not count as passing evidence. The script never edits
or re-runs a result bundle; it reports what is actually inside it.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_SUITES = ("SecondShotAppTests", "SecondShotUITests")
MIN_ATTACHMENTS = 5
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".heic", ".gif"}


class EvidenceError(RuntimeError):
    """Raised when the result bundle cannot be inspected."""


def run_xcresulttool(arguments: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["xcrun", "xcresulttool", *arguments],
        capture_output=True,
        text=True,
        check=False,
    )


def load_json_command(arguments: list[str]) -> dict[str, Any]:
    process = run_xcresulttool(arguments)
    if process.returncode != 0:
        raise EvidenceError(process.stderr.strip() or process.stdout.strip() or "xcresulttool failed")
    try:
        payload = json.loads(process.stdout)
    except json.JSONDecodeError as error:
        raise EvidenceError(f"xcresulttool returned invalid JSON: {error}") from error
    if not isinstance(payload, dict):
        raise EvidenceError("xcresulttool returned a non-object JSON payload")
    return payload


def load_summary(bundle: Path) -> dict[str, Any]:
    return load_json_command(
        ["get", "test-results", "summary", "--path", str(bundle), "--format", "json"]
    )


def load_test_tree(bundle: Path) -> dict[str, Any]:
    return load_json_command(
        ["get", "test-results", "tests", "--path", str(bundle), "--format", "json"]
    )


def collect_node_names(tree: Any) -> set[str]:
    """Walk the xcresult test tree and collect every node name."""
    names: set[str] = set()

    def walk(node: Any) -> None:
        if isinstance(node, dict):
            name = node.get("name")
            if isinstance(name, str):
                names.add(name)
            for child in node.get("children", []) if isinstance(node.get("children"), list) else []:
                walk(child)
            for key in ("testNodes", "testPlans"):
                value = node.get(key)
                if isinstance(value, list):
                    for child in value:
                        walk(child)
        elif isinstance(node, list):
            for child in node:
                walk(child)

    walk(tree)
    return names


def export_attachments(bundle: Path, destination: Path) -> tuple[int, str | None]:
    """Export attachments and return (image count, diagnostic)."""
    if destination.exists():
        for child in sorted(destination.rglob("*"), reverse=True):
            if child.is_file():
                child.unlink()
            elif child.is_dir():
                child.rmdir()
    destination.mkdir(parents=True, exist_ok=True)
    process = run_xcresulttool(
        ["export", "attachments", "--path", str(bundle), "--output-path", str(destination)]
    )
    diagnostic = None
    if process.returncode != 0:
        diagnostic = process.stderr.strip() or process.stdout.strip() or "attachment export failed"
    images = [path for path in destination.rglob("*") if path.is_file() and path.suffix.lower() in IMAGE_SUFFIXES]
    return len(images), diagnostic


def numeric(summary: dict[str, Any], key: str) -> int:
    value = summary.get(key, 0)
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def evaluate(
    summary: dict[str, Any],
    node_names: set[str],
    attachment_count: int,
    attachment_diagnostic: str | None,
) -> list[dict[str, Any]]:
    checks: list[dict[str, Any]] = []

    total = numeric(summary, "totalTestCount")
    passed = numeric(summary, "passedTests")
    failed = numeric(summary, "failedTests")
    skipped = numeric(summary, "skippedTests")
    result = str(summary.get("result", "")).lower()

    checks.append(
        {
            "name": "tests-executed",
            "passed": total > 0,
            "detail": f"totalTestCount={total}",
        }
    )
    checks.append(
        {
            "name": "tests-passed",
            "passed": passed > 0 and failed == 0,
            "detail": f"passed={passed} failed={failed}",
        }
    )
    checks.append(
        {
            "name": "no-skips",
            "passed": skipped == 0,
            "detail": f"skipped={skipped}",
        }
    )
    checks.append(
        {
            "name": "result-not-failed",
            "passed": result not in {"failed", "error"},
            "detail": f"result={summary.get('result')}",
        }
    )
    for suite in EXPECTED_SUITES:
        checks.append(
            {
                "name": f"suite-{suite}",
                "passed": suite in node_names,
                "detail": f"expected a {suite} node in the result tree",
            }
        )
    checks.append(
        {
            "name": "screenshot-evidence",
            "passed": attachment_count >= MIN_ATTACHMENTS,
            "detail": f"images={attachment_count} minimum={MIN_ATTACHMENTS}"
            + (f"; export diagnostic: {attachment_diagnostic}" if attachment_diagnostic else ""),
        }
    )
    return checks


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", default=str(ROOT / "artifacts/ios"))
    args = parser.parse_args(argv)

    artifacts = Path(args.artifacts)
    artifacts.mkdir(parents=True, exist_ok=True)
    bundle = artifacts / "SecondShot.xcresult"

    report: dict[str, Any] = {
        "resultBundle": str(bundle),
        "bundleExists": bundle.exists(),
        "checks": [],
        "passed": False,
    }

    if not bundle.exists():
        report["checks"] = [
            {
                "name": "result-bundle-exists",
                "passed": False,
                "detail": "No xcresult bundle was produced; inspect xcodebuild.log.",
            }
        ]
        (artifacts / "collection.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print("error: no xcresult bundle to validate", file=sys.stderr)
        return 2

    try:
        summary = load_summary(bundle)
    except (EvidenceError, OSError) as error:
        report["checks"] = [
            {"name": "read-summary", "passed": False, "detail": str(error)}
        ]
        (artifacts / "collection.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"error: could not read the result summary: {error}", file=sys.stderr)
        return 2

    (artifacts / "test-summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    try:
        tree = load_test_tree(bundle)
        node_names = collect_node_names(tree)
    except (EvidenceError, OSError) as error:
        tree = {"error": str(error)}
        node_names = set()
    (artifacts / "test-tree.json").write_text(json.dumps(tree, indent=2) + "\n", encoding="utf-8")

    attachment_count, attachment_diagnostic = export_attachments(bundle, artifacts / "attachments")
    if attachment_diagnostic:
        (artifacts / "attachment-export.log").write_text(attachment_diagnostic + "\n", encoding="utf-8")

    checks = evaluate(summary, node_names, attachment_count, attachment_diagnostic)
    report["checks"] = checks
    report["attachmentImages"] = attachment_count
    report["passed"] = all(check["passed"] for check in checks)
    (artifacts / "collection.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    for check in checks:
        status = "PASS" if check["passed"] else "FAIL"
        print(f"{status}  {check['name']}: {check['detail']}")

    if not report["passed"]:
        print("error: simulator evidence is incomplete or failed", file=sys.stderr)
        return 1
    print(f"collected evidence for {numeric(summary, 'totalTestCount')} tests and {attachment_count} images")
    return 0


if __name__ == "__main__":
    sys.exit(main())
