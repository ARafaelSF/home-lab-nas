#!/bin/bash
# Healthcheck keepalived: AdGuard a escutar DNS localmente.
# Exit 0 = saudável (mantém/assume VIP); !=0 = falha (cede VIP).
set -euo pipefail
# UDP :53 a responder (example.com)
python3 - <<'PY'
import socket, sys
pkt = (b"\xab\xcd\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00"
       b"\x07example\x03com\x00\x00\x01\x00\x01")
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(1.0)
try:
    s.sendto(pkt, ("127.0.0.1", 53))
    data, _ = s.recvfrom(512)
    sys.exit(0 if len(data) >= 12 else 1)
except OSError:
    sys.exit(1)
finally:
    s.close()
PY
