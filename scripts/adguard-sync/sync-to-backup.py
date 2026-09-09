#!/usr/bin/env python3
"""Copia filtros, user_rules e rewrites do AdGuard oficial para o YAML do backup.

Não toca em http, users, bind_hosts, querylog nem caminhos de trabalho do Pi.
"""
from __future__ import annotations

import argparse
import copy
import sys
from pathlib import Path

import yaml

FILTER_KEYS = ("filters", "whitelist_filters", "user_rules")
FILTERING_KEYS = (
    "rewrites",
    "blocked_services",
    "filtering_enabled",
    "rewrites_enabled",
    "parental_enabled",
    "safebrowsing_enabled",
    "protection_enabled",
    "filters_update_interval",
)
DNS_KEYS = (
    "upstream_dns",
    "bootstrap_dns",
    "fallback_dns",
    "upstream_mode",
    "blocked_hosts",
)


def load(path: Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        data = yaml.safe_load(fh)
    if not isinstance(data, dict):
        raise SystemExit(f"YAML inválido: {path}")
    return data


def apply(origin: dict, replica: dict) -> dict:
    out = copy.deepcopy(replica)
    for key in FILTER_KEYS:
        if key in origin:
            out[key] = copy.deepcopy(origin[key])
    orig_f = origin.get("filtering") or {}
    out.setdefault("filtering", {})
    for key in FILTERING_KEYS:
        if key in orig_f:
            out["filtering"][key] = copy.deepcopy(orig_f[key])
    orig_dns = origin.get("dns") or {}
    out.setdefault("dns", {})
    for key in DNS_KEYS:
        if key in orig_dns:
            out["dns"][key] = copy.deepcopy(orig_dns[key])
    return out


def dump(path: Path, data: dict) -> None:
    with path.open("w", encoding="utf-8") as fh:
        yaml.safe_dump(
            data,
            fh,
            default_flow_style=False,
            allow_unicode=True,
            sort_keys=False,
        )


def extract(data: dict) -> dict:
    filtering = data.get("filtering") or {}
    dns = data.get("dns") or {}
    view = {key: data.get(key) for key in FILTER_KEYS}
    for key in FILTERING_KEYS:
        view[f"filtering.{key}"] = filtering.get(key)
    for key in DNS_KEYS:
        view[f"dns.{key}"] = dns.get(key)
    return view


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--origin", required=True, type=Path)
    parser.add_argument("--replica", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    origin = load(args.origin)
    replica = load(args.replica)
    if extract(origin) == extract(replica):
        print("unchanged")
        return 10
    merged = apply(origin, replica)
    dump(args.output, merged)
    print("ok", args.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
