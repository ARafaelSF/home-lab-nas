#!/usr/bin/env python3
"""Passive, read-only health monitor for SMLIGHT SLZB-06.

It polls the controller's read-only HTTP status/log endpoints and subscribes
to diagnostic Zigbee2MQTT MQTT topics.  It never opens the Zigbee TCP port,
publishes MQTT messages, or sends commands to the controller.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import threading
import time
from collections import Counter
from pathlib import Path
from typing import Any

try:
    import requests
except ImportError:  # pragma: no cover - deployment dependency check
    requests = None

SLZB_URL = os.getenv("SLZB_STATUS_URL", "http://192.168.2.237/api2?action=0&page=0")
SLZB_LOG_URL = os.getenv("SLZB_LOG_URL", "http://192.168.2.237/api2?action=5")
MQTT_HOST = os.getenv("MQTT_HOST", "192.168.3.10")
MQTT_PORT = os.getenv("MQTT_PORT", "1883")
MQTT_USER = os.getenv("MQTT_USER", "homeassistant")
LOG_DIR = Path(os.getenv("SLZB_MONITOR_STATE", "/var/lib/slzb-monitor"))
LOG_FILE = LOG_DIR / "events.jsonl"
POLL_SECONDS = int(os.getenv("SLZB_POLL_SECONDS", "60"))
MAX_BYTES = 100 * 1024 * 1024
MAX_AGE = dt.timedelta(days=14)
TOPICS = (
    "zigbee2mqtt/#",
)
TECHNICAL = re.compile(
    r"SRSP|NWK_|MAC_|APS_|Data request|Adapter disconnected|ECONNRESET|"
    r"timeout|failed to ping|disconnected|offline|reset|serial|socket|watchdog",
    re.I,
)


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _value(values: dict[str, str], *names: str) -> str | None:
    for name in names:
        if name in values:
            return values[name]
    return None


def parse_status_header(header: str) -> dict[str, Any]:
    """Parse SMLIGHT's respValuesArr header without retaining the full page."""
    try:
        decoded = json.loads(header)
    except (TypeError, json.JSONDecodeError):
        decoded = None
    if isinstance(decoded, dict):
        values = {str(key): str(value) for key, value in decoded.items()}
    else:
        values = {}
        for part in header.split(","):
            if "=" in part:
                key, value = part.split("=", 1)
                values[key.strip()] = value.strip().strip('"')
    result: dict[str, Any] = {
        "device": _value(values, "DEVICE"),
        "core_firmware": _value(values, "BUILD", "espRev"),
        "zigbee_firmware": _value(values, "zbRev"),
        "zigbee_hardware": _value(values, "zbHw"),
        "ip": _value(values, "ethIp"),
        "ethernet_connected": _value(values, "ethConn"),
        "zigbee_status": _value(values, "zbStatus"),
        "uptime": _value(values, "uptime"),
        "radio_uptime": _value(values, "zbConnT"),
        "crash_info": _value(values, "crash_info"),
    }
    for source, target in (("zbTemp", "zigbee_temp_c"), ("esp32Temp", "core_temp_c")):
        raw = _value(values, source)
        if raw is not None:
            try:
                result[target] = float(raw)
            except ValueError:
                result[target] = None
    return {key: value for key, value in result.items() if value is not None}


def summarize_health(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise ValueError("health payload is not an object")
    process = payload.get("process") if isinstance(payload.get("process"), dict) else {}
    mqtt = payload.get("mqtt") if isinstance(payload.get("mqtt"), dict) else {}
    os_info = payload.get("os") if isinstance(payload.get("os"), dict) else {}
    devices = payload.get("devices") if isinstance(payload.get("devices"), dict) else {}
    counters: dict[str, dict[str, Any]] = {}
    for ieee, item in devices.items():
        if not isinstance(item, dict):
            continue
        row = {}
        for key in ("messages", "messages_per_sec", "leave_count", "network_address_changes"):
            value = item.get(key)
            if isinstance(value, (int, float)) and not isinstance(value, bool):
                row[key] = value
        if row:
            counters[str(ieee).lower()] = row
    return {
        "process_uptime_sec": process.get("uptime_sec"),
        "mqtt_connected": mqtt.get("connected"),
        "mqtt_received": mqtt.get("received"),
        "mqtt_published": mqtt.get("published"),
        "load": os_info.get("load_average"),
        "device_count": len(devices),
        "device_counters": counters,
    }


def health_with_deltas(payload: Any, previous: dict[str, Any] | None) -> tuple[dict[str, Any], dict[str, Any] | None]:
    """Return a bounded health summary and safe deltas, never negative traffic."""
    current = summarize_health(payload)
    previous_counters = (previous or {}).get("device_counters", {}) if previous else {}
    current_counters = current.get("device_counters", {})
    process_uptime = current.get("process_uptime_sec")
    previous_uptime = (previous or {}).get("process_uptime_sec") if previous else None
    reset = bool(
        previous
        and isinstance(process_uptime, (int, float))
        and isinstance(previous_uptime, (int, float))
        and process_uptime < previous_uptime
    )
    if not reset and isinstance(previous_counters, dict):
        for ieee, row in current_counters.items():
            old = previous_counters.get(ieee, {}) if isinstance(previous_counters.get(ieee), dict) else {}
            if any(isinstance(old.get(key), (int, float)) and value < old[key] for key, value in row.items()):
                reset = True
                break
    deltas: dict[str, dict[str, Any]] = {}
    if not reset and isinstance(previous_counters, dict):
        for ieee, row in current_counters.items():
            old = previous_counters.get(ieee, {}) if isinstance(previous_counters.get(ieee), dict) else {}
            delta_row = {}
            for key, value in row.items():
                prior = old.get(key)
                if isinstance(prior, (int, float)) and value >= prior:
                    delta_row[key] = value - prior
            if delta_row:
                deltas[ieee] = delta_row
    current["counter_reset"] = reset
    current["device_set_changed"] = bool(previous and set(current_counters) != set(previous_counters))
    current["device_deltas"] = deltas
    if reset:
        current["delta_quality"] = "reset_detected"
    elif previous is None:
        current["delta_quality"] = "baseline"
    else:
        current["delta_quality"] = "valid"
    return current, current


def parse_devices_inventory(payload: Any) -> dict[str, str]:
    """Extract only IEEE/friendly_name pairs; exclude coordinator and groups."""
    items = payload if isinstance(payload, list) else payload.get("devices") if isinstance(payload, dict) else None
    if not isinstance(items, list):
        return {}
    result: dict[str, str] = {}
    for item in items:
        if not isinstance(item, dict):
            continue
        kind = str(item.get("type", "")).lower()
        ieee = item.get("ieee_address") or item.get("ieeeAddr")
        name = item.get("friendly_name") or item.get("name")
        if not ieee or not name or kind in {"coordinator", "group"}:
            continue
        result[str(ieee).lower()] = str(name)
    return result


def parse_mqtt_line(raw: str) -> tuple[bool, str, str] | None:
    """Parse mosquitto_sub -F '%r\\t%t\\t%p' output."""
    parts = raw.rstrip("\r\n").split("\t", 2)
    if len(parts) != 3:
        return None
    retain = parts[0].strip().lower() in {"1", "true", "yes"}
    return retain, parts[1], parts[2]


def match_device_topic(topic: str, base_topic: str, inventory: dict[str, str]) -> str | None:
    """Match the longest known friendly name, including names containing '/'."""
    prefix = base_topic.rstrip("/") + "/"
    if not topic.startswith(prefix):
        return None
    suffix = topic[len(prefix):]
    if suffix.startswith("bridge/"):
        return None
    for name in sorted(inventory.values(), key=len, reverse=True):
        if suffix == name or suffix.startswith(name + "/"):
            remainder = suffix[len(name):].lstrip("/")
            if remainder in {"availability", "set", "get"} or remainder.startswith(("set/", "get/", "availability/")):
                return None
            return next((ieee for ieee, friendly in inventory.items() if friendly == name), None)
    return None


class ActivityTracker:
    def __init__(self, base_topic: str = "zigbee2mqtt") -> None:
        self.base_topic = base_topic
        self.lock = threading.Lock()
        self.inventory: dict[str, str] = {}
        self.window_counts: Counter[str] = Counter()
        self.last_seen: dict[str, str] = {}
        self.unmatched = 0
        self.mqtt_connected = False
        self.bridge_state: str | None = None
        self.window_started = time.monotonic()
        self.window_observable = False

    def inventory_update(self, payload: Any) -> int:
        if not isinstance(payload, list) and not (isinstance(payload, dict) and isinstance(payload.get("devices"), list)):
            with self.lock:
                return len(self.inventory)
        inventory = parse_devices_inventory(payload)
        with self.lock:
            self.inventory = inventory
        return len(inventory)

    def observe(self, retain: bool, topic: str, payload: Any) -> None:
        if topic == f"{self.base_topic}/bridge/devices":
            self.inventory_update(payload)
            return
        with self.lock:
            if topic == f"{self.base_topic}/bridge/state":
                state = payload.get("state") if isinstance(payload, dict) else payload
                self.bridge_state = str(state) if state is not None else None
                return
            if retain:
                return
            ieee = match_device_topic(topic, self.base_topic, self.inventory)
            if ieee is None:
                if (topic.startswith(self.base_topic + "/")
                        and not topic.startswith(self.base_topic + "/bridge/")
                        and not topic.startswith(self.base_topic + "/group/")
                        and "/availability" not in topic):
                    self.unmatched += 1
                return
            self.window_counts[ieee] += 1
            self.last_seen[ieee] = now()
            self.window_observable = True

    def set_connection(self, connected: bool) -> None:
        with self.lock:
            self.mqtt_connected = connected

    def minute_snapshot(self) -> dict[str, Any]:
        with self.lock:
            counters = dict(self.window_counts)
            current_time = dt.datetime.now(dt.timezone.utc)
            silence = {}
            for ieee, timestamp in self.last_seen.items():
                try:
                    silence[ieee] = max(0, int((current_time - dt.datetime.fromisoformat(timestamp)).total_seconds()))
                except ValueError:
                    continue
            snapshot = {
                "known_device_count": len(self.inventory),
                "active_device_count": len(counters),
                "device_message_count": sum(counters.values()),
                "device_messages_per_device": counters,
                "last_message_utc": dict(self.last_seen),
                "seconds_since_last_message": silence,
                "bridge_state": self.bridge_state,
                "mqtt_connected": self.mqtt_connected,
                "collection_quality": "live" if self.window_observable and self.mqtt_connected else "no_observed_device_messages",
                "unmatched_topic_count": self.unmatched,
            }
            self.window_counts.clear()
            self.unmatched = 0
            self.window_observable = False
            return snapshot


def activity_loop(log: EventLog, tracker: ActivityTracker) -> None:
    while True:
        time.sleep(60)
        log.write({"source": "mqtt", "kind": "device_activity_minute", "data": tracker.minute_snapshot()})


def technical_log(topic: str, payload: Any) -> dict[str, Any] | None:
    if isinstance(payload, dict):
        level = str(payload.get("level", "")).lower()
        message = str(payload.get("message", ""))
        namespace = payload.get("namespace")
    else:
        level, message, namespace = "", str(payload), None
    if level not in {"warn", "warning", "error", "fatal"} and not TECHNICAL.search(message):
        return None
    return {"topic": topic, "level": level, "namespace": namespace, "message": message[:800]}


def mqtt_command(password: str) -> list[str]:
    return [
        "mosquitto_sub", "-h", MQTT_HOST, "-p", str(MQTT_PORT), "-u", MQTT_USER,
        "-P", password, "-F", "%r\\t%t\\t%p", *sum((["-t", topic] for topic in TOPICS), []),
    ]


class EventLog:
    def __init__(self, path: Path = LOG_FILE) -> None:
        self.path = path
        self.lock = threading.Lock()
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def write(self, event: dict[str, Any]) -> None:
        event = {"ts_utc": now(), **event}
        line = json.dumps(event, ensure_ascii=False, separators=(",", ":")) + "\n"
        with self.lock:
            with self.path.open("a", encoding="utf-8") as stream:
                stream.write(line)
            self.prune()

    def prune(self) -> None:
        cutoff = time.time() - MAX_AGE.total_seconds()
        files = [p for p in self.path.parent.glob("events.jsonl*") if p.is_file()]
        for item in files:
            if item != self.path and item.stat().st_mtime < cutoff:
                item.unlink(missing_ok=True)
        total = sum(item.stat().st_size for item in files if item.exists())
        if total > MAX_BYTES:
            for item in sorted((p for p in files if p != self.path), key=lambda p: p.stat().st_mtime):
                item.unlink(missing_ok=True)
                total -= item.stat().st_size if item.exists() else 0
                if total <= MAX_BYTES:
                    break


def poll_slzb(log: EventLog, previous_lines: set[str]) -> set[str]:
    if requests is None:
        log.write({"kind": "http_error", "error": "python requests is unavailable"})
        return previous_lines
    try:
        response = requests.get(SLZB_URL, timeout=8)
        response.raise_for_status()
        header = response.headers.get("respValuesArr", "")
        log.write({"source": "slzb", "kind": "status", "data": parse_status_header(header)})
    except Exception as exc:  # read-only monitor must survive transient failures
        log.write({"source": "slzb", "kind": "http_error", "endpoint": "status", "error": type(exc).__name__})
    time.sleep(1)
    try:
        response = requests.get(SLZB_LOG_URL, timeout=8)
        response.raise_for_status()
        lines = set(response.text.splitlines())
        new_lines = lines - previous_lines
        for line in sorted(new_lines):
            if TECHNICAL.search(line):
                log.write({"source": "slzb", "kind": "internal_log", "line": line[:800], "line_sha256": hashlib.sha256(line.encode()).hexdigest()})
        return lines
    except Exception as exc:
        log.write({"source": "slzb", "kind": "http_error", "endpoint": "internal_log", "error": type(exc).__name__})
        return previous_lines


def mqtt_loop(log: EventLog, tracker: ActivityTracker, health_state: dict[str, Any]) -> None:
    password = os.getenv("WUD_MQTT_PASSWORD")
    if not password:
        log.write({"source": "mqtt", "kind": "config_missing"})
        return
    while True:
        process = None
        try:
            process = subprocess.Popen(mqtt_command(password), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            log.write({"source": "mqtt", "kind": "subscriber_started", "topics": list(TOPICS)})
            tracker.set_connection(True)
            assert process.stdout is not None
            for raw in process.stdout:
                parsed = parse_mqtt_line(raw)
                if parsed is None:
                    continue
                retain, topic, payload = parsed
                try:
                    decoded = json.loads(payload)
                except json.JSONDecodeError:
                    decoded = payload
                tracker.observe(retain, topic, decoded)
                if topic.endswith("/state"):
                    log.write({"source": "mqtt", "kind": "bridge_state", "state": decoded if isinstance(decoded, str) else str(decoded)[:40]})
                elif topic.endswith("/health"):
                    try:
                        summary, health_state["previous"] = health_with_deltas(decoded, health_state.get("previous"))
                        log.write({"source": "mqtt", "kind": "bridge_health", "data": summary})
                    except ValueError:
                        log.write({"source": "mqtt", "kind": "health_invalid"})
                elif topic.endswith("/devices"):
                    if not isinstance(decoded, (list, dict)):
                        log.write({"source": "mqtt", "kind": "devices_invalid"})
                    else:
                        log.write({"source": "mqtt", "kind": "device_inventory", "retained": retain, "known_device_count": len(tracker.inventory)})
                elif topic in {f"{tracker.base_topic}/bridge/log", f"{tracker.base_topic}/bridge/logging"}:
                    event = technical_log(topic, decoded)
                    if event:
                        log.write({"source": "mqtt", "kind": "technical_log", **event})
        except Exception as exc:
            log.write({"source": "mqtt", "kind": "subscriber_error", "error": type(exc).__name__})
        finally:
            tracker.set_connection(False)
            if process is not None:
                process.kill()
                process.wait()
            log.write({"source": "mqtt", "kind": "subscriber_exit"})
        time.sleep(5)


def main() -> None:
    log = EventLog()
    log.write({"kind": "monitor_started", "poll_seconds": POLL_SECONDS, "topics": list(TOPICS)})
    tracker = ActivityTracker()
    health_state: dict[str, Any] = {}
    threading.Thread(target=mqtt_loop, args=(log, tracker, health_state), daemon=True).start()
    threading.Thread(target=activity_loop, args=(log, tracker), daemon=True).start()
    lines: set[str] = set()
    while True:
        started = time.monotonic()
        lines = poll_slzb(log, lines)
        time.sleep(max(1, POLL_SECONDS - (time.monotonic() - started)))


if __name__ == "__main__":
    main()
