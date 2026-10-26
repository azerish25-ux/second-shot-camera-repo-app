import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from ci import check_repository  # noqa: E402


class LinkTests(unittest.TestCase):
    def test_external_and_anchor_links_are_ignored(self):
        text = "[site](https://example.com) [top](#section) [mail](mailto:a@b.c)"
        self.assertEqual(check_repository.extract_relative_links(text), [])

    def test_image_links_are_not_treated_as_documents(self):
        text = "![shot](artifacts/shot.png) [doc](docs/STATUS.md)"
        self.assertEqual(check_repository.extract_relative_links(text), ["docs/STATUS.md"])

    def test_code_spans_and_fences_are_ignored(self):
        text = "Use `[missing](nope.md)` in prose.\n\n```\n[also-missing](other.md)\n```\n"
        self.assertEqual(check_repository.extract_relative_links(text), [])

    def test_broken_link_is_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "doc.md").write_text("[missing](nope.md)\n", encoding="utf-8")
            report = check_repository.Report()
            check_repository.check_markdown_links(root, report)
            self.assertTrue(any("nope.md" in error for error in report.errors))

    def test_link_escaping_repository_is_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "doc.md").write_text("[outside](../../elsewhere.md)\n", encoding="utf-8")
            report = check_repository.Report()
            check_repository.check_markdown_links(root, report)
            self.assertTrue(report.errors)


class WorkflowTests(unittest.TestCase):
    def _workflow_root(self, workflow: str) -> Path:
        directory = tempfile.mkdtemp()
        workflow_dir = Path(directory) / ".github/workflows"
        workflow_dir.mkdir(parents=True)
        (workflow_dir / "ci.yml").write_text(workflow, encoding="utf-8")
        return Path(directory)

    def test_unpinned_action_is_rejected(self):
        root = self._workflow_root(
            "name: CI\non:\n  push:\npermissions:\n  contents: read\n"
            "jobs:\n  build:\n    steps:\n      - uses: actions/checkout@v4\n"
        )
        report = check_repository.Report()
        check_repository.check_workflows(root, report)
        self.assertTrue(any("full commit SHA" in error for error in report.errors))

    def test_pinned_action_and_tabs(self):
        root = self._workflow_root(
            "name: CI\non:\n  push:\npermissions:\n  contents: read\n"
            "jobs:\n  build:\n    steps:\n"
            "      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262\n"
        )
        report = check_repository.Report()
        check_repository.check_workflows(root, report)
        self.assertEqual(report.errors, [])

    def test_missing_permissions_is_rejected(self):
        root = self._workflow_root(
            "name: CI\non:\n  push:\njobs:\n  build:\n    steps:\n"
            "      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262\n"
        )
        report = check_repository.Report()
        check_repository.check_workflows(root, report)
        self.assertTrue(any("permissions" in error for error in report.errors))


class AccessibilityIdentifierTests(unittest.TestCase):
    def _tree(self, view: str, test: str) -> Path:
        directory = Path(tempfile.mkdtemp())
        (directory / "Sources/SecondShotApp").mkdir(parents=True)
        (directory / "Tests/SecondShotUITests").mkdir(parents=True)
        (directory / "Sources/SecondShotApp/View.swift").write_text(view, encoding="utf-8")
        (directory / "Tests/SecondShotUITests/Journey.swift").write_text(test, encoding="utf-8")
        return directory

    def test_missing_identifier_is_reported(self):
        root = self._tree(
            'Text("x").accessibilityIdentifier("demo.badge")\n',
            'app.buttons["demo.missing"].tap()\n',
        )
        report = check_repository.Report()
        check_repository.check_accessibility_identifiers(root, report)
        self.assertTrue(any("demo.missing" in error for error in report.errors))

    def test_defined_identifier_passes(self):
        root = self._tree(
            'Text("x").accessibilityIdentifier("demo.badge")\n',
            'app.buttons["demo.badge"].tap()\n'
            'app.descendants(matching: .any).matching(identifier: "demo.badge").firstMatch\n',
        )
        report = check_repository.Report()
        check_repository.check_accessibility_identifiers(root, report)
        self.assertEqual(report.errors, [])

    def test_plain_labels_are_not_treated_as_identifiers(self):
        root = self._tree(
            'Text("x")\n',
            'app.staticTexts["Guidance unavailable"]\n',
        )
        report = check_repository.Report()
        check_repository.check_accessibility_identifiers(root, report)
        self.assertEqual(report.errors, [])


class PhaseTests(unittest.TestCase):
    def test_missing_phase_files_are_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "docs/phases").mkdir(parents=True)
            report = check_repository.Report()
            check_repository.check_phase_files(root, report)
            self.assertEqual(len([e for e in report.errors if "Missing phase specification" in e]), 24)


class RepositoryIntegrationTests(unittest.TestCase):
    def test_repository_checks_pass_on_this_tree(self):
        self.assertEqual(check_repository.main(check_repository.ROOT), 0)


if __name__ == "__main__":
    unittest.main()
