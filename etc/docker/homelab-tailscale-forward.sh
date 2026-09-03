#!/bin/bash
# Permite subnet routing Tailscale → LANs (HA, Proxmox, UniFi, Hikvision, …).
# O Docker define FORWARD policy DROP no backend nft; o Tailscale usa iptables-legacy.
# Aplicamos as regras nos dois backends para o forward funcionar de forma fiável.

set -euo pipefail

MARKER="homelab-tailscale-forward"
LANS=(
  "192.168.3.0/24"
  "192.168.68.0/24"
  "192.168.2.0/24"
)

if ! ip link show tailscale0 >/dev/null 2>&1; then
  echo "tailscale0 ausente — ignorado"
  exit 0
fi

apply_backend() {
  local IPT="$1"
  if ! command -v "$IPT" >/dev/null 2>&1; then
    return 0
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
  local pos=2
  local lan
  for lan in "${LANS[@]}"; do
    "$IPT" -I FORWARD "$pos" -i tailscale0 -d "$lan" -m comment --comment "$MARKER" -j ACCEPT
    pos=$((pos + 1))
  done
  for lan in "${LANS[@]}"; do
    "$IPT" -I FORWARD "$pos" -o tailscale0 -s "$lan" -m comment --comment "$MARKER" -j ACCEPT
    pos=$((pos + 1))
  done
  "$IPT" -t nat -I POSTROUTING 1 -s 100.64.0.0/10 -o eth0 -m comment --comment "$MARKER" -j MASQUERADE
  echo "OK: forward Tailscale → 192.168.3/68/2 via $IPT"
}

# nft (Docker FORWARD DROP) + legacy (cadeias do Tailscale)
apply_backend iptables
apply_backend iptables-legacy
