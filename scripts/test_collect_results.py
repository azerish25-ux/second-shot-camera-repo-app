import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from ci import collect_results  # noqa: E402


def summary(total=25, passed=25, failed=0, skipped=0, result="Passed"):
    return {
        "result": result,
        "totalTestCount": total,
        "passedTests": passed,
        "failedTests": failed,
        "skippedTests": skipped,
    }


NAMES = {"SecondShotAppTests", "SecondShotUITests", "testExample", "Test Suite"}


def passed(checks):
    return all(check["passed"] for check in checks)


class EvaluateTests(unittest.TestCase):
    def test_complete_evidence_passes(self):
        checks = collect_results.evaluate(summary(), NAMES, 7, None)
        self.assertTrue(passed(checks), checks)

    def test_empty_run_fails(self):
        checks = collect_results.evaluate(summary(total=0, passed=0), NAMES, 7, None)
        self.assertFalse(passed(checks))

    def test_failures_fail(self):
        checks = collect_results.evaluate(summary(passed=24, failed=1, result="Failed"), NAMES, 7, None)
        self.assertFalse(passed(checks))

    def test_skips_are_not_a_pass(self):
        checks = collect_results.evaluate(summary(passed=24, skipped=1), NAMES, 7, None)
        failing = [check["name"] for check in checks if not check["passed"]]
        self.assertIn("no-skips", failing)

    def test_missing_ui_suite_fails(self):
        checks = collect_results.evaluate(summary(), {"SecondShotAppTests"}, 7, None)
        failing = [check["name"] for check in checks if not check["passed"]]
        self.assertIn("suite-SecondShotUITests", failing)

    def test_missing_screenshots_fail(self):
        checks = collect_results.evaluate(summary(), NAMES, 2, None)
        failing = [check["name"] for check in checks if not check["passed"]]
        self.assertIn("screenshot-evidence", failing)

    def test_attachment_diagnostic_is_recorded(self):
        checks = collect_results.evaluate(summary(), NAMES, 7, "export unsupported")
        screenshot = next(check for check in checks if check["name"] == "screenshot-evidence")
        self.assertIn("export unsupported", screenshot["detail"])


class TreeTests(unittest.TestCase):
    def test_nested_names_are_collected(self):
        tree = {
            "testNodes": [
                {
                    "name": "SecondShotUITests",
                    "nodeType": "Test Suite",
                    "children": [
                        {"name": "testDemo", "nodeType": "Test Case", "children": []},
                    ],
                },
                {"name": "SecondShotAppTests", "children": [{"name": "testFormat", "children": []}]},
            ]
        }
        names = collect_results.collect_node_names(tree)
        self.assertEqual(
            names,
            {"SecondShotUITests", "testDemo", "SecondShotAppTests", "testFormat"},
        )

    def test_malformed_tree_is_tolerated(self):
        self.assertEqual(collect_results.collect_node_names({"unexpected": 1}), set())
        self.assertEqual(collect_results.collect_node_names(None), set())


if __name__ == "__main__":
    unittest.main()
