#!/usr/bin/env python3
"""Exporta InfluxDB 1.x (HA) e importa para InfluxDB 2.x (homelab)."""
from __future__ import annotations

import json
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone

SRC = "http://192.168.3.10:8086"
SRC_DB = "home_energy"
DST = "http://127.0.0.1:8086"
DST_ORG = "homelab"
DST_BUCKET = "home_energy"
DST_TOKEN = open("/root/homelab/compose/monitoring/.env").read().split("INFLUXDB_HA_WRITE_TOKEN=")[1].split("\n")[0].strip()


def query_v1(q: str) -> dict:
    url = f"{SRC}/query?{urllib.parse.urlencode({'db': SRC_DB, 'q': q})}"
    with urllib.request.urlopen(url, timeout=120) as resp:
        return json.loads(resp.read())


def write_lp(lines: list[str]) -> None:
    if not lines:
        return
    body = "\n".join(lines).encode()
    req = urllib.request.Request(
        f"{DST}/api/v2/write?org={urllib.parse.quote(DST_ORG)}&bucket={urllib.parse.quote(DST_BUCKET)}&precision=ns",
        data=body,
        method="POST",
        headers={
            "Authorization": f"Token {DST_TOKEN}",
            "Content-Type": "text/plain; charset=utf-8",
        },
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        resp.read()


def esc_tag(s: str) -> str:
    return s.replace("\\", "\\\\").replace(" ", "\\ ").replace(",", "\\,").replace("=", "\\=")


def esc_field_key(s: str) -> str:
    return s.replace("\\", "\\\\").replace(" ", "\\ ").replace(",", "\\,").replace("=", "\\=")


def to_lp(measurement: str, tags: dict[str, str], fields: dict[str, object], ts_ns: int) -> str:
    tag_part = ",".join(f"{esc_tag(k)}={esc_tag(str(v))}" for k, v in sorted(tags.items()) if v is not None)
    field_parts = []
    for k, v in fields.items():
        if v is None:
            continue
        key = esc_field_key(k)
        if isinstance(v, bool):
            field_parts.append(f"{key}={'true' if v else 'false'}")
        elif isinstance(v, (int, float)):
            field_parts.append(f"{key}={v}")
        else:
            s = str(v).replace("\\", "\\\\").replace('"', '\\"')
            field_parts.append(f'{key}="{s}"')
    if not field_parts:
        return ""
    head = measurement if not tag_part else f"{measurement},{tag_part}"
    return f"{head} {','.join(field_parts)} {ts_ns}"


def export_measurement(name: str) -> int:
    print(f"  -> {name}", flush=True)
    result = query_v1(f'SELECT * FROM "{name}"')
    series_list = result.get("results", [{}])[0].get("series") or []
    count = 0
    batch: list[str] = []
    for series in series_list:
        cols = series["columns"]
        tag_cols = [c for c in cols if c not in ("time", "value")]
        for row in series.get("values", []):
            rowd = dict(zip(cols, row))
            ts_raw = rowd.pop("time")
            # 2019-01-01T00:00:00Z -> ns
            if ts_raw.endswith("Z"):
                ts_raw = ts_raw[:-1] + "+00:00"
            dt = datetime.fromisoformat(ts_raw)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            ts_ns = int(dt.timestamp() * 1_000_000_000)
            tags = {c: rowd.pop(c) for c in list(rowd.keys()) if c != "value" and rowd.get(c) is not None}
            fields = {}
            if "value" in rowd and rowd["value"] is not None:
                fields["value"] = rowd["value"]
            for k, v in rowd.items():
                if k != "value" and v is not None:
                    fields[k] = v
            line = to_lp(name, tags, fields, ts_ns)
            if line:
                batch.append(line)
                count += 1
                if len(batch) >= 5000:
                    write_lp(batch)
                    batch.clear()
    if batch:
        write_lp(batch)
    return count


def main() -> int:
    print("Listando measurements...")
    data = query_v1("SHOW MEASUREMENTS")
    measurements = [r[0] for r in data["results"][0]["series"][0]["values"]]
    print(f"Encontrados: {measurements}")
    total = 0
    for m in measurements:
        total += export_measurement(m)
    print(f"OK: {total} pontos importados para bucket {DST_BUCKET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
