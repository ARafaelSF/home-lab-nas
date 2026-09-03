#!/bin/bash
# Aplica ajustes do Hermes no volume (idempotente).
# Suprime "Gateway shutting down" no Telegram durante paradas previstas (ex.: backup Duplicati).
set -euo pipefail

if ! docker ps --format '{{.Names}}' | grep -qx hermes-agent; then
  echo "ERRO: container hermes-agent não está a correr"
  exit 1
fi

docker exec hermes-agent hermes config set gateway.platforms.telegram.gateway_restart_notification false

# A flag só entra em vigor no processo gateway após restart (lida na arranque).
docker compose -p hermes-agent -f /root/homelab/compose/hermes-agent/docker-compose.yml restart hermes

echo "OK: gateway_restart_notification=false (Telegram) + gateway reiniciado"
