#!/usr/bin/env python3
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from slzb_monitor import EventLog, mqtt_command, parse_status_header, summarize_health, technical_log


class MonitorTests(unittest.TestCase):
    def test_status_header_is_normalized(self):
        data = parse_status_header("DEVICE=SLZB-06,BUILD=v3.4.3.dev1,zbHw=CC2652P,zbRev=20260311,zbTemp=62.91,esp32Temp=64.44,ethConn=Y")
        self.assertEqual(data["device"], "SLZB-06")
        self.assertEqual(data["zigbee_temp_c"], 62.91)
        self.assertEqual(data["zigbee_firmware"], "20260311")

    def test_status_header_accepts_smlight_json_header(self):
        data = parse_status_header('{"DEVICE":"SLZB-06","BUILD":"v3.4.3.dev1","zbHw":"CC2652P","zbTemp":"62.76","esp32Temp":"65.00"}')
        self.assertEqual(data["core_firmware"], "v3.4.3.dev1")
        self.assertEqual(data["core_temp_c"], 65.0)

    def test_health_does_not_retain_device_map(self):
        result = summarize_health({"process": {"uptime_sec": 10}, "mqtt": {"connected": True}, "devices": {"a": {"messages": 4}}})
        self.assertEqual(result["device_count"], 1)
        self.assertNotIn("devices", result)

    def test_technical_filter_ignores_normal_log(self):
        self.assertIsNone(technical_log("zigbee2mqtt/bridge/log", {"level": "info", "message": "normal"}))
        self.assertIsNotNone(technical_log("zigbee2mqtt/bridge/log", {"level": "error", "message": "SRSP timeout"}))

    def test_mqtt_command_is_passive_only(self):
        command = mqtt_command("not-logged")
        joined = " ".join(command)
        self.assertNotIn("/set", joined)
        self.assertNotIn("/request", joined)
        self.assertIn("zigbee2mqtt/bridge/health", joined)

    def test_log_is_jsonl_and_does_not_leak_password(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "events.jsonl"
            with patch("slzb_monitor.LOG_FILE", path):
                log = EventLog(path)
                log.write({"kind": "test", "value": "safe"})
            record = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(record["kind"], "test")
            self.assertNotIn("password", path.read_text(encoding="utf-8").lower())


if __name__ == "__main__":
    unittest.main()
