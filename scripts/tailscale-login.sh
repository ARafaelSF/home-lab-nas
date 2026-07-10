#!/bin/bash
# Liga o container Tailscale à tailnet (primeira vez ou após "Logged out").
# Uso:
#   ./tailscale-login.sh              # abre URL no browser — completar login
#   ./tailscale-login.sh --check      # só mostra estado
set -euo pipefail

SOCKET=/tmp/tailscaled.sock
HOSTNAME="${TS_HOSTNAME:-homelab-docker}"

if [[ "${1:-}" == "--check" ]]; then
  docker exec tailscale tailscale --socket="$SOCKET" status
  exit 0
fi

echo "=== Tailscale: a aguardar autenticação ==="
echo "Abra o URL abaixo no browser (conta Tailscale do desktop) e autorize."
echo "Não reinicie o container até ver 'Logged in' no status."
echo

docker exec tailscale tailscale --socket="$SOCKET" up \
  --accept-dns=false \
  --hostname="$HOSTNAME" \
  "$@"

echo
docker exec tailscale tailscale --socket="$SOCKET" status
