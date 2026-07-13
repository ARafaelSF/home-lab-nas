#!/bin/bash
# Permite subnet routing Tailscale → LANs (HA, Proxmox, UniFi, Hikvision, …).
# O Docker define FORWARD policy DROP; sem isto o Tailscale não encaminha para a LAN.
# Usar iptables-legacy (mesmo backend que o Docker nesta VM).

set -euo pipefail

IPT="${IPTABLES_BIN:-iptables-legacy}"
MARKER="homelab-tailscale-forward"

if ! command -v "$IPT" >/dev/null 2>&1; then
  IPT=iptables
fi

if ! ip link show tailscale0 >/dev/null 2>&1; then
  echo "tailscale0 ausente — ignorado"
  exit 0
fi

# Remover regras anteriores com o mesmo marker
while true; do
  line="$("$IPT" -S FORWARD 2>/dev/null | grep "comment.*${MARKER}" | head -1 || true)"
  [[ -z "$line" ]] && break
  # shellcheck disable=SC2086
  eval "$IPT" -D ${line#-A }
done
while "$IPT" -t nat -C POSTROUTING -s 100.64.0.0/10 -o eth0 -m comment --comment "$MARKER" -j MASQUERADE 2>/dev/null; do
  "$IPT" -t nat -D POSTROUTING -s 100.64.0.0/10 -o eth0 -m comment --comment "$MARKER" -j MASQUERADE || break
done

"$IPT" -I FORWARD 1 -m conntrack --ctstate RELATED,ESTABLISHED -m comment --comment "$MARKER" -j ACCEPT
"$IPT" -I FORWARD 2 -i tailscale0 -d 192.168.3.0/24 -m comment --comment "$MARKER" -j ACCEPT
"$IPT" -I FORWARD 3 -i tailscale0 -d 192.168.68.0/24 -m comment --comment "$MARKER" -j ACCEPT
"$IPT" -I FORWARD 4 -i tailscale0 -d 192.168.2.0/24 -m comment --comment "$MARKER" -j ACCEPT
"$IPT" -I FORWARD 5 -o tailscale0 -s 192.168.3.0/24 -m comment --comment "$MARKER" -j ACCEPT
"$IPT" -I FORWARD 6 -o tailscale0 -s 192.168.68.0/24 -m comment --comment "$MARKER" -j ACCEPT
"$IPT" -I FORWARD 7 -o tailscale0 -s 192.168.2.0/24 -m comment --comment "$MARKER" -j ACCEPT
"$IPT" -t nat -I POSTROUTING 1 -s 100.64.0.0/10 -o eth0 -m comment --comment "$MARKER" -j MASQUERADE

echo "OK: forward Tailscale → 192.168.3/68/2 via $IPT"
