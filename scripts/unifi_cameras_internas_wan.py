#!/usr/bin/env python3
"""Enable/disable UniFi firewall rule: Cameras Internas → Bloquear WAN.

Usage:
  unifi_cameras_internas_wan.py block|allow|status

Env (or defaults below):
  UNIFI_HOST, UNIFI_USERNAME, UNIFI_PASSWORD, UNIFI_RULE_ID
"""
from __future__ import annotations

import base64
import json
import os
import ssl
import sys
import urllib.error
import urllib.request

HOST = os.environ.get("UNIFI_HOST", "192.168.68.1")
USER = os.environ.get("UNIFI_USERNAME", "CursorIA")
PASS = os.environ.get("UNIFI_PASSWORD", "")
RULE_ID = os.environ.get("UNIFI_RULE_ID", "6a997135a33c069ef0997675")
RULE_NAME = "Cameras Internas → Bloquear WAN"

ctx = ssl._create_unverified_context()
state = {"cookie": "", "csrf": ""}


def login() -> None:
    req = urllib.request.Request(
        f"https://{HOST}/api/auth/login",
        data=json.dumps({"username": USER, "password": PASS}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
        for c in resp.headers.get_all("Set-Cookie") or []:
            part = c.split(";", 1)[0]
            if part.startswith("TOKEN="):
                state["cookie"] = part
                tok = part.split("=", 1)[1]
                payload = tok.split(".")[1] + "=" * ((-len(tok.split(".")[1])) % 4)
                try:
                    state["csrf"] = json.loads(base64.urlsafe_b64decode(payload)).get(
                        "csrfToken", ""
                    )
                except Exception:
                    pass


def api(path: str, data=None, method: str | None = None):
    body = None if data is None else json.dumps(data).encode()
    m = method or ("PUT" if body else "GET")
    headers = {"Content-Type": "application/json", "Cookie": state["cookie"]}
    if state["csrf"]:
        headers["X-CSRF-Token"] = state["csrf"]
    req = urllib.request.Request(
        f"https://{HOST}{path}", data=body, headers=headers, method=m
    )
    with urllib.request.urlopen(req, context=ctx, timeout=60) as resp:
        return json.loads(resp.read().decode() or "null")


def get_rule():
    policies = api("/proxy/network/v2/api/site/default/firewall-policies")
    for p in policies:
        if p.get("_id") == RULE_ID or p.get("name") == RULE_NAME:
            return p
    raise SystemExit(f"rule not found: {RULE_ID} / {RULE_NAME}")


def set_enabled(enabled: bool) -> dict:
    rule = get_rule()
    if bool(rule.get("enabled")) == enabled:
        return rule
    rule = dict(rule)
    rule["enabled"] = enabled
    return api(
        f"/proxy/network/v2/api/site/default/firewall-policies/{rule['_id']}",
        rule,
        method="PUT",
    )


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in {"block", "allow", "status"}:
        print("usage: unifi_cameras_internas_wan.py block|allow|status", file=sys.stderr)
        return 2
    if not PASS:
        print("UNIFI_PASSWORD missing", file=sys.stderr)
        return 2
    cmd = sys.argv[1]
    login()
    if cmd == "status":
        rule = get_rule()
        print("blocked" if rule.get("enabled") else "allowed")
        return 0
    # block = rule enabled; allow = rule disabled
    rule = set_enabled(cmd == "block")
    print("blocked" if rule.get("enabled") else "allowed")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except urllib.error.HTTPError as e:
        print(e.read().decode()[:500], file=sys.stderr)
        raise SystemExit(1)
