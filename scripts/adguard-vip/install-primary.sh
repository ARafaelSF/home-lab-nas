#!/usr/bin/env bash
# Instala keepalived VIP no AdGuard principal (este host = 192.168.3.21).
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"

install -d /etc/keepalived
install -m 755 "$SRC/check_adguard.sh" /etc/keepalived/check_adguard.sh
install -m 644 "$SRC/keepalived.primary.conf" /etc/keepalived/keepalived.conf

systemctl enable --now keepalived
sleep 2
systemctl --no-pager -l status keepalived | head -20
ip -4 addr show eth0 | grep -E 'inet |192.168.3.23' || true
echo "VIP esperado em eth0: 192.168.3.23 (se MASTER)"
