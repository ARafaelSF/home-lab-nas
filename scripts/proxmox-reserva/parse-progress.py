#!/usr/bin/env python3
"""Lê o log da rotina semanal e devolve fase|pct_fase|pct_global (0-100)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

PHASES = (
    ("backup", "=== backup start", "=== backup end", 0, 30),
    ("restore_101", "=== restore 101", "=== restore 100", 30, 45),
    ("restore_100", "=== restore 100", "=== restore end", 45, 100),
)


def last_progress_pct(text: str) -> int:
    hits = re.findall(r"progress\s+(\d+)%", text)
    if not hits:
        return 0
    return int(hits[-1])


def phase_complete(text: str, start: str, end: str) -> bool:
    si = text.find(start)
    if si < 0:
        return False
    ei = text.find(end, si + len(start))
    return ei >= 0


def active_phase(text: str) -> tuple[str, int, int] | None:
    current: tuple[str, int, int] | None = None
    for name, start, end, lo, hi in PHASES:
        si = text.find(start)
        if si < 0:
            continue
        if phase_complete(text, start, end):
            current = (name, 100, hi)
            continue
        chunk = text[si:]
        pct = last_progress_pct(chunk)
        span = hi - lo
        overall = lo + (span * pct // 100)
        return name, pct, min(overall, 99)
    return current


def parse_log(path: Path) -> tuple[str, int, int]:
    text = path.read_text(encoding="utf-8", errors="replace")
    if "rotina semanal OK" in text or "=== restore end" in text:
        return "concluido", 100, 100
    act = active_phase(text)
    if act:
        return act
    if "reserva online" in text:
        return "aguardar_reserva", 100, 5
    return "inicio", 0, 0


def main() -> int:
    log = Path(
        sys.argv[1]
        if len(sys.argv) > 1
        else "/var/log/homelab/pbs-rotina-semanal-latest.log"
    )
    if not log.is_file():
        print("inicio|0|0")
        return 0
    phase, phase_pct, overall = parse_log(log)
    print(f"{phase}|{phase_pct}|{overall}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
