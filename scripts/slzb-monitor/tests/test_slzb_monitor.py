#!/usr/bin/env python3
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from slzb_monitor import (
    ActivityTracker,
    EventLog,
    health_with_deltas,
    match_device_topic,
    mqtt_command,
    parse_devices_inventory,
    parse_mqtt_line,
    parse_status_header,
    summarize_health,
    technical_log,
)


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
        self.assertEqual(result["device_counters"]["a"]["messages"], 4)

    def test_health_deltas_and_reset(self):
        first, baseline = health_with_deltas({"process": {"uptime_sec": 10}, "devices": {"a": {"messages": 4}}}, None)
        self.assertEqual(first["delta_quality"], "baseline")
        second, _ = health_with_deltas({"process": {"uptime_sec": 20}, "devices": {"a": {"messages": 9}}}, baseline)
        self.assertEqual(second["device_deltas"]["a"]["messages"], 5)
        reset, _ = health_with_deltas({"process": {"uptime_sec": 2}, "devices": {"a": {"messages": 1}}}, second)
        self.assertTrue(reset["counter_reset"])
        self.assertEqual(reset["device_deltas"], {})

    def test_inventory_excludes_coordinator_and_groups(self):
        result = parse_devices_inventory([
            {"type": "Coordinator", "ieee_address": "0xcoord", "friendly_name": "Coordinator"},
            {"type": "Router", "ieee_address": "0xA", "friendly_name": "Sala/TV"},
            {"type": "Group", "ieee_address": "0xG", "friendly_name": "Grupo"},
        ])
        self.assertEqual(result, {"0xa": "Sala/TV"})

    def test_topic_matching_supports_slash_names_and_excludes_control_topics(self):
        inventory = {"0xa": "Sala/TV"}
        self.assertEqual(match_device_topic("zigbee2mqtt/Sala/TV", "zigbee2mqtt", inventory), "0xa")
        self.assertEqual(match_device_topic("zigbee2mqtt/Sala/TV/action", "zigbee2mqtt", inventory), "0xa")
        self.assertIsNone(match_device_topic("zigbee2mqtt/Sala/TV/set", "zigbee2mqtt", inventory))
        self.assertIsNone(match_device_topic("zigbee2mqtt/Sala/TV/availability", "zigbee2mqtt", inventory))
        self.assertIsNone(match_device_topic("zigbee2mqtt/bridge/logging", "zigbee2mqtt", inventory))

    def test_retained_messages_are_parsed_and_discarded(self):
        self.assertEqual(parse_mqtt_line("1" + chr(9) + "zigbee2mqtt/Sala" + chr(9) + "{}"), (True, "zigbee2mqtt/Sala", "{}"))
        tracker = ActivityTracker()
        tracker.inventory_update([{"type": "Router", "ieee_address": "0xa", "friendly_name": "Sala"}])
        tracker.observe(True, "zigbee2mqtt/Sala", {"state": "ON"})
        self.assertEqual(tracker.minute_snapshot()["device_message_count"], 0)
        tracker.observe(False, "zigbee2mqtt/Sala", {"state": "ON"})
        self.assertEqual(tracker.minute_snapshot()["device_message_count"], 1)

    def test_activity_snapshot_does_not_call_silence_offline(self):
        tracker = ActivityTracker()
        tracker.inventory_update([{"type": "Router", "ieee_address": "0xa", "friendly_name": "Sala"}])
        tracker.set_connection(True)
        snapshot = tracker.minute_snapshot()
        self.assertEqual(snapshot["active_device_count"], 0)
        self.assertEqual(snapshot["collection_quality"], "no_observed_device_messages")

    def test_invalid_inventory_does_not_create_known_devices(self):
        tracker = ActivityTracker()
        tracker.observe(True, "zigbee2mqtt/bridge/devices", {"invalid": True})
        self.assertEqual(tracker.minute_snapshot()["known_device_count"], 0)

    def test_invalid_inventory_does_not_erase_last_valid_inventory(self):
        tracker = ActivityTracker()
        tracker.inventory_update([{"type": "Router", "ieee_address": "0xa", "friendly_name": "Sala"}])
        tracker.observe(True, "zigbee2mqtt/bridge/devices", {"invalid": True})
        self.assertEqual(tracker.minute_snapshot()["known_device_count"], 1)

    def test_unmatched_topic_is_not_counted(self):
        tracker = ActivityTracker()
        tracker.inventory_update([{"type": "Router", "ieee_address": "0xa", "friendly_name": "Sala"}])
        tracker.observe(False, "zigbee2mqtt/Unknown", {"state": "ON"})
        snapshot = tracker.minute_snapshot()
        self.assertEqual(snapshot["device_message_count"], 0)
        self.assertEqual(snapshot["unmatched_topic_count"], 1)

    def test_bridge_and_group_topics_are_not_unmatched_devices(self):
        tracker = ActivityTracker()
        tracker.observe(False, "zigbee2mqtt/bridge/info", {})
        tracker.observe(False, "zigbee2mqtt/group/Grupo", {})
        self.assertEqual(tracker.minute_snapshot()["unmatched_topic_count"], 0)

    def test_technical_filter_ignores_normal_log(self):
        self.assertIsNone(technical_log("zigbee2mqtt/bridge/log", {"level": "info", "message": "normal"}))
        self.assertIsNotNone(technical_log("zigbee2mqtt/bridge/log", {"level": "error", "message": "SRSP timeout"}))

    def test_mqtt_command_is_passive_only(self):
        command = mqtt_command("not-logged")
        joined = " ".join(command)
        self.assertNotIn("/set", joined)
        self.assertNotIn("/request", joined)
        self.assertIn("zigbee2mqtt/#", joined)

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
