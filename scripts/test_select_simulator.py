import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from ci import select_simulator  # noqa: E402


def inventory(devices_26=None, devices_17=None, include_watch=True):
    payload = {
        "runtimes": [
            {
                "identifier": "com.apple.CoreSimulator.SimRuntime.iOS-17-0",
                "platform": "iOS",
                "version": "17.0",
                "name": "iOS 17.0",
                "isAvailable": True,
            },
            {
                "identifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-0",
                "platform": "iOS",
                "version": "26.0",
                "name": "iOS 26.0",
                "isAvailable": True,
            },
        ],
        "devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-17-0": devices_17
            if devices_17 is not None
            else [{"name": "iPhone 15", "udid": "AAA-17", "isAvailable": True}],
            "com.apple.CoreSimulator.SimRuntime.iOS-26-0": devices_26
            if devices_26 is not None
            else [
                {"name": "iPhone 17 Pro", "udid": "CCC-26", "isAvailable": True},
                {"name": "iPhone 17", "udid": "BBB-26", "isAvailable": True},
            ],
        },
    }
    if include_watch:
        payload["runtimes"].append(
            {
                "identifier": "com.apple.CoreSimulator.SimRuntime.watchOS-11-0",
                "platform": "watchOS",
                "version": "11.0",
                "isAvailable": True,
            }
        )
    return payload


class SelectionTests(unittest.TestCase):
    def test_prefers_the_newest_runtime_with_a_usable_iphone(self):
        selection = select_simulator.select_simulator(inventory())
        self.assertEqual(selection["runtime"], "com.apple.CoreSimulator.SimRuntime.iOS-26-0")
        self.assertEqual(selection["udid"], "BBB-26")
        self.assertEqual(selection["name"], "iPhone 17")

    def test_selection_is_stable_regardless_of_device_order(self):
        first = select_simulator.select_simulator(inventory())
        devices = list(inventory()["devices"]["com.apple.CoreSimulator.SimRuntime.iOS-26-0"])
        devices.reverse()
        second = select_simulator.select_simulator(inventory(devices_26=devices))
        self.assertEqual(first, second)

    def test_unavailable_devices_fall_back_to_an_older_runtime(self):
        unavailable = [
            {
                "name": "iPhone 17",
                "udid": "BBB-26",
                "isAvailable": False,
                "availability": "(unavailable, runtime profile not found)",
            }
        ]
        selection = select_simulator.select_simulator(inventory(devices_26=unavailable))
        self.assertEqual(selection["runtime"], "com.apple.CoreSimulator.SimRuntime.iOS-17-0")

    def test_availability_string_with_unavailable_is_rejected(self):
        devices = [
            {
                "name": "iPhone 17",
                "udid": "BBB-26",
                "isAvailable": True,
                "availability": "(unavailable, runtime profile not found)",
            }
        ]
        selection = select_simulator.select_simulator(inventory(devices_26=devices))
        self.assertEqual(selection["runtime"], "com.apple.CoreSimulator.SimRuntime.iOS-17-0")

    def test_no_ios_runtime_is_actionable(self):
        payload = {"runtimes": [], "devices": {}}
        with self.assertRaises(select_simulator.SelectionError) as context:
            select_simulator.select_simulator(payload)
        self.assertIn("No available iOS simulator runtime", str(context.exception))

    def test_no_iphone_devices_is_actionable(self):
        payload = inventory(devices_26=[], devices_17=[])
        with self.assertRaises(select_simulator.SelectionError) as context:
            select_simulator.select_simulator(payload)
        message = str(context.exception)
        self.assertIn("No available iPhone device", message)
        self.assertIn("iOS-26-0", message)

    def test_malformed_inventory_is_rejected(self):
        payload = {"devices": {}}
        with self.assertRaises(select_simulator.SelectionError):
            select_simulator.select_simulator(payload)

    def test_load_inventory_reports_invalid_json(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "inventory.json"
            path.write_text("{not json", encoding="utf-8")
            with self.assertRaises(select_simulator.SelectionError):
                select_simulator.load_inventory(str(path))

    def test_cli_writes_the_selection(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "inventory.json"
            source.write_text(json.dumps(inventory()), encoding="utf-8")
            output = root / "selected.json"
            status = select_simulator.main(
                ["--inventory", str(source), "--output", str(output)]
            )
            self.assertEqual(status, 0)
            selection = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(selection["udid"], "BBB-26")

    def test_cli_reports_failure_for_empty_inventory(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "inventory.json"
            source.write_text(json.dumps({"runtimes": [], "devices": {}}), encoding="utf-8")
            self.assertEqual(select_simulator.main(["--inventory", str(source)]), 2)


if __name__ == "__main__":
    unittest.main()
