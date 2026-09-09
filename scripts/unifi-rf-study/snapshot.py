#!/usr/bin/env python3
"""Snapshot UniFi wireless clients for 2.4 GHz min-rate study. No secrets in output."""
from __future__ import annotations

import json
import ssl
import sys
import urllib.request
import http.cookiejar
from datetime import datetime, timezone
from pathlib import Path

ENV = Path("/root/homelab/compose/unifi-mcp/.env")
OUT = Path("/root/homelab/scripts/unifi-rf-study/data/clients.jsonl")


def load_env() -> dict[str, str]:
    vals: dict[str, str] = {}
    for line in ENV.read_text().splitlines():
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            vals[k] = v
    return vals


class CSRF(urllib.request.BaseHandler):
    csrf = None

    def http_response(self, req, resp):
        t = resp.headers.get("X-CSRF-Token") or resp.headers.get("x-csrf-token")
        if t:
            CSRF.csrf = t
        return resp

    https_response = http_response


def api(vals: dict[str, str]):
    host = f"https://{vals['UNIFI_HOST']}"
    ctx = ssl._create_unverified_context()
    cj = http.cookiejar.CookieJar()
    op = urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(cj),
        urllib.request.HTTPSHandler(context=ctx),
        CSRF(),
    )

    def call(path: str, method: str = "GET", data=None):
        h = {"Accept": "application/json", "Origin": host, "Referer": host + "/"}
        if CSRF.csrf:
            h["X-CSRF-Token"] = CSRF.csrf
        body = None
        if data is not None:
            body = json.dumps(data).encode()
            h["Content-Type"] = "application/json"
        req = urllib.request.Request(host + path, data=body, headers=h, method=method)
        with op.open(req, timeout=45) as r:
            return json.loads(r.read())

    call(
        "/api/auth/login",
        "POST",
        {
            "username": vals["UNIFI_USERNAME"],
            "password": vals["UNIFI_PASSWORD"],
            "rememberMe": True,
        },
    )
    return call


def main() -> int:
    vals = load_env()
    call = api(vals)
    aps = {
        d["mac"]: d.get("name")
        for d in call("/proxy/network/api/s/default/stat/device")["data"]
        if d.get("type") == "uap"
    }
    now = datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
    rows = []
    for c in call("/proxy/network/api/s/default/stat/sta")["data"]:
        if c.get("is_wired"):
            continue
        radio = {"ng": "2.4", "na": "5", "6e": "6"}.get(c.get("radio"), c.get("radio"))
        rows.append(
            {
                "ts": now,
                "name": c.get("name") or c.get("hostname") or c.get("mac"),
                "mac": c.get("mac"),
                "ssid": c.get("essid"),
                "radio": radio,
                "ap": aps.get(c.get("ap_mac")),
                "ip": c.get("ip"),
                "signal": c.get("signal"),
                "tx_rate": c.get("tx_rate"),
                "rx_rate": c.get("rx_rate"),
                "satisfaction": c.get("satisfaction"),
            }
        )
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("a", encoding="utf-8") as f:
        f.write(json.dumps({"ts": now, "clients": rows}, ensure_ascii=False) + "\n")
    n24 = sum(1 for r in rows if r["radio"] == "2.4")
    low = sum(
        1
        for r in rows
        if r["radio"] == "2.4"
        and r.get("tx_rate")
        and r.get("rx_rate")
        and min(r["tx_rate"], r["rx_rate"]) < 6000
    )
    print(f"{now} wireless={len(rows)} 2.4={n24} below_6mbps_now={low} -> {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
