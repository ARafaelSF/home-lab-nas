#!/bin/bash
# Copia segredos do compose .env → /opt/data/.env (onde o Hermes lê em Docker).
set -euo pipefail

SRC="${1:-/root/homelab/compose/hermes-agent/.env}"
VOL="$(docker volume inspect hermes-agent_hermes_data --format '{{.Mountpoint}}')"
DEST="${VOL}/.env"

[[ -f "$SRC" ]] || { echo "ERRO: $SRC não existe"; exit 1; }

# Variáveis que o Hermes usa (gateway + plataformas)
KEYS=(
  OPENROUTER_API_KEY
  OPENAI_API_KEY
  ANTHROPIC_API_KEY
  GOOGLE_API_KEY
  TELEGRAM_BOT_TOKEN
  TELEGRAM_ALLOWED_USERS
  TELEGRAM_HOME_CHANNEL
  HASS_URL
  HASS_TOKEN
)

{
  echo "# Gerado por hermes-sync-env.sh — não editar manualmente no volume"
  echo "# Edite: /root/homelab/compose/hermes-agent/.env"
  for k in "${KEYS[@]}"; do
    v="$(grep -E "^${k}=" "$SRC" 2>/dev/null | cut -d= -f2- || true)"
    [[ -n "$v" ]] && echo "${k}=${v}"
  done
} >"$DEST"
chmod 600 "$DEST"
echo "OK: sincronizado → $DEST"
