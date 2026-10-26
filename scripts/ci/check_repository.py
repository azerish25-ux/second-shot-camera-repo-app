#!/usr/bin/env python3
"""Structural checks for the Second Shot repository.

This validates documentation, workflow hygiene, project specification paths and
asset syntax. It deliberately does not compile Swift: passing this script is not
an iOS build result.
"""

from __future__ import annotations

import json
import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIRED_FILES = [
    "AGENTS.md",
    "README.md",
    "Package.swift",
    "project.yml",
    "docs/STATUS.md",
    "docs/ROADMAP.md",
    "docs/PRODUCT_BRIEF.md",
    "docs/ACCEPTANCE_GATES.md",
    "docs/CI_WORKFLOW.md",
    "docs/WORKING_AGREEMENT.md",
    "docs/templates/PHASE_REPORT.md",
    "docs/testing/DEVICE_VALIDATION.md",
    "docs/testing/phase-01-protocol.md",
    "docs/testing/interview-guide.md",
    "docs/testing/consent-and-data-handling.md",
    "docs/release/RELEASE_CHECKLIST.md",
    "docs/design/README.md",
    "docs/design/DESIGN_SYSTEM.md",
    "docs/design/SCREEN_SPECIFICATIONS.md",
    "docs/design/INTERACTION_AND_MOTION.md",
    "docs/design/ACCESSIBILITY.md",
    "docs/architecture/README.md",
    "docs/architecture/capture-and-coordinates.md",
    "docs/architecture/alignment-and-export.md",
    "Sources/SecondShotCore",
    "Sources/SecondShotApp",
    "Tests/SecondShotCoreTests",
    "Tests/SecondShotAppTests",
    "Tests/SecondShotUITests",
    "scripts/ci/check_repository.py",
    "scripts/ci/select_simulator.py",
    "scripts/ci/collect_results.py",
    "scripts/ci/run_simulator_tests.sh",
    "scripts/ci/install_xcodegen.sh",
    ".github/workflows/repository-checks.yml",
    ".github/workflows/ios-ci.yml",
]

PHASE_FILES = [
    "00-foundation.md",
    "01-product-validation.md",
    "02-pose-math.md",
    "03-lifecycle-state-machine.md",
    "04-project-storage.md",
    "05-device-capabilities.md",
    "06-ar-tracking.md",
    "07-reference-capture.md",
    "08-relocalization.md",
    "09-path-rendering.md",
    "10-guided-retake.md",
    "11-tracking-recovery.md",
    "12-review-and-time-alignment.md",
    "13-registration-diagnostics.md",
    "14-video-export.md",
    "15-device-proof-gate.md",
    "16-production-ui-accessibility.md",
    "17-library-and-project-lifecycle.md",
    "18-performance-and-device-matrix.md",
    "19-privacy-safety-localization.md",
    "20-pro-unlock.md",
    "21-testflight-beta.md",
    "22-app-store-release.md",
    "23-launch-and-maintenance.md",
]

# Phase 01 requires a frozen protocol whose declared invariants cannot quietly
# disappear. Markers are matched against whitespace-stripped, lower-cased text so
# wording and line wrapping stay free while the substance is pinned.
PHASE_01_DOCUMENTS = {
    "docs/testing/phase-01-protocol.md": [
        "protocolversion",
        "falsifi",
        "60predeclaredevaluationcases",
        "30guided",
        "30unaided",
        "counterbalanc",
        "two-attempt",
        "firstattemptsuccessrate",
        "budgetedcasesuccessrate",
        "stoprules",
        "restricted",
        "withdrawal",
        "non-lidar",
        "ios17",
        "07-reference-capture.md",
        "15-device-proof-gate.md",
    ],
    "docs/testing/interview-guide.md": [
        "notused",
        "pastbehaviour",
        "willingnesstopay",
        "participantcode",
        "synthetic",
    ],
    "docs/testing/consent-and-data-handling.md": [
        "notinforce",
        "retention",
        "withdraw",
        "rehearsal",
    ],
}

SCENARIO_ROW_RE = re.compile(r"^\|\s*(S[123])\s*\|", re.MULTILINE)
RESULTS_LINK_RE = re.compile(r"\((?:\.\./)?reports/(phase-01[^)\s]*)\)")

LINK_RE = re.compile(r"(?<!\!)\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
FENCE_RE = re.compile(r"```.*?```", re.DOTALL)
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")
PINNED_ACTION_RE = re.compile(r"^\s*-?\s*uses:\s*(\S+)")
SHA_RE = re.compile(r"^[0-9a-f]{40}$")
# Assembled at runtime so this scanner does not flag its own source text.
SECRET_MARKERS = [
    "BEGIN " + "RSA PRIVATE KEY",
    "BEGIN " + "EC PRIVATE KEY",
    "BEGIN " + "PRIVATE KEY",
]


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.notes: list[str] = []

    def error(self, message: str) -> None:
        self.errors.append(message)

    def note(self, message: str) -> None:
        self.notes.append(message)


def strip_code(text: str) -> str:
    """Remove fenced and inline code so examples are not treated as links."""
    without_fences = FENCE_RE.sub("", text)
    return INLINE_CODE_RE.sub("", without_fences)


def check_required_files(root: Path, report: Report) -> None:
    for relative in REQUIRED_FILES:
        if not (root / relative).exists():
            report.error(f"Missing required path: {relative}")


def check_phase_files(root: Path, report: Report) -> None:
    phase_dir = root / "docs/phases"
    if not phase_dir.is_dir():
        report.error("Missing docs/phases directory")
        return

    present = {path.name for path in phase_dir.glob("*.md")}
    for name in PHASE_FILES:
        path = phase_dir / name
        if not path.exists():
            report.error(f"Missing phase specification: docs/phases/{name}")
            continue
        text = path.read_text(encoding="utf-8")
        if len(text.strip()) < 400:
            report.error(f"Phase specification is too short to be actionable: {name}")
        if not text.lstrip().startswith("# Phase"):
            report.error(f"Phase specification lacks a '# Phase' title: {name}")
        if "Status:" not in text:
            report.error(f"Phase specification lacks a Status declaration: {name}")

    unexpected = present - set(PHASE_FILES)
    if unexpected:
        report.note(f"Additional phase documents present: {', '.join(sorted(unexpected))}")


def normalize_marker(text: str) -> str:
    return re.sub(r"\s+", "", text).lower()


def check_validation_protocol(root: Path, report: Report) -> None:
    """Phase 01's protocol must keep its declared substance and honesty status.

    Guards two failure modes: quietly dropping a registered invariant (sample
    size, metrics, stop rules, gate links) and reporting a study as executed
    without a sanitized results report behind it.
    """
    for relative, markers in PHASE_01_DOCUMENTS.items():
        path = root / relative
        if not path.exists():
            report.error(f"Missing phase-01 document: {relative}")
            continue
        normalized = normalize_marker(path.read_text(encoding="utf-8"))
        for marker in markers:
            if marker not in normalized:
                report.error(f"{relative} is missing required content: {marker!r}")

    protocol = root / "docs/testing/phase-01-protocol.md"
    if not protocol.exists():
        return
    text = protocol.read_text(encoding="utf-8")

    declared = set(SCENARIO_ROW_RE.findall(text))
    for scenario in ("S1", "S2", "S3"):
        if scenario not in declared:
            report.error(f"Phase-01 protocol is missing the {scenario} scenario row")

    normalized = normalize_marker(text)
    if "notexecuted" not in normalized:
        links = RESULTS_LINK_RE.findall(text)
        if not links:
            report.error(
                "Phase-01 protocol does not state that the study is unexecuted and "
                "links no sanitized results report"
            )
        for link in links:
            if not (root / "docs/reports" / Path(link).name).exists():
                report.error(f"Phase-01 protocol links a missing results report: {link}")


def markdown_files(root: Path) -> list[Path]:
    return sorted(
        path
        for path in root.rglob("*.md")
        if not any(part.startswith(".") for part in path.relative_to(root).parts)
        and ".build" not in path.parts
        and "node_modules" not in path.parts
    )


def extract_relative_links(text: str) -> list[str]:
    stripped = strip_code(text)
    links = []
    for match in LINK_RE.finditer(stripped):
        target = match.group(1).strip()
        if target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        links.append(target)
    return links


def check_markdown_links(root: Path, report: Report) -> None:
    for path in markdown_files(root):
        text = path.read_text(encoding="utf-8")
        for target in extract_relative_links(text):
            clean = target.split("#", 1)[0].split("?", 1)[0]
            if not clean:
                continue
            resolved = (path.parent / clean).resolve()
            try:
                resolved.relative_to(root.resolve())
            except ValueError:
                report.error(f"Link escapes the repository in {path.relative_to(root)}: {target}")
                continue
            if not resolved.exists():
                report.error(f"Broken relative link in {path.relative_to(root)}: {target}")


def check_workflows(root: Path, report: Report) -> None:
    workflow_dir = root / ".github/workflows"
    if not workflow_dir.is_dir():
        report.error("Missing .github/workflows directory")
        return

    workflows = sorted(workflow_dir.glob("*.yml"))
    if not workflows:
        report.error("No workflow files found")
    for path in workflows:
        text = path.read_text(encoding="utf-8")
        name = path.relative_to(root)
        if "\t" in text:
            report.error(f"Workflow uses tab characters: {name}")
        if not re.search(r"^on:", text, re.MULTILINE):
            report.error(f"Workflow has no 'on:' trigger: {name}")
        if not re.search(r"^permissions:", text, re.MULTILINE):
            report.error(f"Workflow must declare read-only permissions: {name}")
        elif "contents: read" not in text:
            report.error(f"Workflow should request 'contents: read': {name}")
        if "pull_request_target" in text:
            report.error(f"Workflow must not use pull_request_target: {name}")
        for line in text.splitlines():
            match = PINNED_ACTION_RE.match(line)
            if not match:
                continue
            action = match.group(1).strip().strip("\"'")
            if action.startswith("./"):
                continue
            if "@" not in action:
                report.error(f"Unpinned action reference in {name}: {action}")
                continue
            ref = action.rsplit("@", 1)[1]
            if not SHA_RE.match(ref):
                report.error(f"Action must be pinned to a full commit SHA in {name}: {action}")


def check_project_spec(root: Path, report: Report) -> None:
    spec = root / "project.yml"
    if not spec.exists():
        report.error("Missing project.yml")
        return
    text = spec.read_text(encoding="utf-8")
    if "Sources/SecondShotApp" not in text:
        report.error("project.yml does not reference Sources/SecondShotApp")
    if "Tests/SecondShotUITests" not in text:
        report.error("project.yml does not reference the UI test target")
    if "Tests/SecondShotCoreTests" not in text:
        report.error("project.yml does not run the core tests on the simulator build")
    if "SecondShotCore" not in text:
        report.error("project.yml does not depend on SecondShotCore")
    for expected_dir in ("Sources/SecondShotApp", "Tests/SecondShotAppTests", "Tests/SecondShotUITests"):
        if not (root / expected_dir).is_dir():
            report.error(f"Target source directory is missing: {expected_dir}")


def check_json_and_plists(root: Path, report: Report) -> None:
    for path in sorted(root.rglob("*.json")):
        if any(part in {".build", ".git", "artifacts"} for part in path.parts):
            continue
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            report.error(f"Invalid JSON in {path.relative_to(root)}: {error}")
    for path in sorted(root.rglob("*.plist")):
        if any(part in {".build", ".git", "artifacts"} for part in path.parts):
            continue
        try:
            with path.open("rb") as handle:
                plistlib.load(handle)
        except Exception as error:  # plistlib raises several types
            report.error(f"Invalid property list in {path.relative_to(root)}: {error}")


APP_IDENTIFIER_RE = re.compile(r'accessibilityIdentifier\("([^"]+)"\)')
UI_TEST_QUERY_RE = re.compile(
    r'(?:buttons|staticTexts|otherElements|textFields|switches)\["([^"]+)"\]'
    r'|descendants\(matching: \.any\)\["([^"]+)"\]'
)


def check_accessibility_identifiers(root: Path, report: Report) -> None:
    """Every dotted query in the UI tests must exist in the app sources."""
    app_dir = root / "Sources/SecondShotApp"
    test_dir = root / "Tests/SecondShotUITests"
    if not app_dir.is_dir() or not test_dir.is_dir():
        return

    defined: set[str] = set()
    for path in app_dir.rglob("*.swift"):
        defined.update(APP_IDENTIFIER_RE.findall(path.read_text(encoding="utf-8")))

    for path in sorted(test_dir.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        for match in UI_TEST_QUERY_RE.finditer(text):
            query = match.group(1) or match.group(2)
            if not query or "." not in query:
                continue
            if query not in defined:
                report.error(
                    f"UI test {path.relative_to(root)} queries identifier {query!r}, "
                    "which no app view defines"
                )


def check_package_manifest(root: Path, report: Report) -> None:
    manifest = root / "Package.swift"
    if not manifest.exists():
        return
    text = manifest.read_text(encoding="utf-8")
    if "// swift-tools-version:" not in text:
        report.error("Package.swift lacks a swift-tools-version declaration")
    if "SecondShotCore" not in text:
        report.error("Package.swift does not declare SecondShotCore")
    if "Sources/SecondShotApp" in text:
        report.error("Package.swift must not compile the SwiftUI app target")


def check_secret_markers(root: Path, report: Report) -> None:
    allowed = {".build", ".git", "artifacts"}
    this_file = Path(__file__).resolve()
    for path in root.rglob("*"):
        if not path.is_file() or any(part in allowed for part in path.parts):
            continue
        if path.resolve() == this_file:
            continue
        if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".pdf", ".zip", ".xcresult"}:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for marker in SECRET_MARKERS:
            if marker in text:
                report.error(f"Possible private key material in {path.relative_to(root)}")


def main(root: Path = ROOT) -> int:
    report = Report()
    check_required_files(root, report)
    check_phase_files(root, report)
    check_validation_protocol(root, report)
    check_markdown_links(root, report)
    check_workflows(root, report)
    check_project_spec(root, report)
    check_accessibility_identifiers(root, report)
    check_json_and_plists(root, report)
    check_package_manifest(root, report)
    check_secret_markers(root, report)

    for note in report.notes:
        print(f"note: {note}")
    for error in report.errors:
        print(f"error: {error}", file=sys.stderr)

    if report.errors:
        print(f"\nRepository checks failed with {len(report.errors)} error(s).", file=sys.stderr)
        return 1
    print("Repository checks passed: documents, links, workflows, project spec and assets.")
    return 0


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT))
