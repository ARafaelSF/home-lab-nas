#!/bin/bash
# Restringe portas administrativas — permite VLANs confiáveis + Docker + localhost.
# IoT e demais VLANs permanecem bloqueadas nas portas admin.

set -euo pipefail

ADMIN_PORTS="8000,9443,8200,8085,3003"
CHAIN="DOCKER-USER"
CONFIG="/etc/docker/homelab-trusted-networks.conf"
MARKER="homelab-admin-ports"

# Recria a chain do zero (evita regras duplicadas ao atualizar VLANs)
iptables -F "$CHAIN"

# Conexões já estabelecidas
iptables -I "$CHAIN" 1 -m conntrack --ctstate RELATED,ESTABLISHED -m comment --comment "$MARKER" -j RETURN

pos=2
if [[ -f "$CONFIG" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue
    iptables -I "$CHAIN" "$pos" -s "$line" -m comment --comment "$MARKER" -j RETURN
    pos=$((pos + 1))
  done < "$CONFIG"
else
  iptables -I "$CHAIN" "$pos" -s 192.168.3.0/24 -m comment --comment "$MARKER" -j RETURN
  pos=$((pos + 1))
fi

iptables -I "$CHAIN" "$pos" -s 172.16.0.0/12 -m comment --comment "$MARKER" -j RETURN
pos=$((pos + 1))
iptables -I "$CHAIN" "$pos" -s 127.0.0.0/8 -m comment --comment "$MARKER" -j RETURN

iptables -A "$CHAIN" -p tcp -m multiport --dports "$ADMIN_PORTS" -m comment --comment "$MARKER" -j DROP
iptables -A "$CHAIN" -j RETURN
