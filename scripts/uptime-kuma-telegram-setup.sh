#!/bin/bash
# Adiciona notificação Telegram nativa no Uptime Kuma (mesmo bot do Hermes).
# Mantém o webhook HA existente; liga Telegram a todos os monitores.
#
# Uso:
#   TELEGRAM_BOT_TOKEN=... TELEGRAM_CHAT_ID=... ./uptime-kuma-telegram-setup.sh
#   ./uptime-kuma-telegram-setup.sh   # lê de hermes-agent/.env

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HERMES_ENV="$REPO_ROOT/compose/hermes-agent/.env"
KUMA_DB="$(docker volume inspect uptime-kuma_uptime-kuma_data --format '{{.Mountpoint}}')/kuma.db"

if [[ -f "$HERMES_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$HERMES_ENV"
fi

TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-${TELEGRAM_HOME_CHANNEL:-${TELEGRAM_ALLOWED_USERS:-}}}"

if [[ -z "$TOKEN" || -z "$CHAT_ID" ]]; then
  echo "ERRO: defina TELEGRAM_BOT_TOKEN e TELEGRAM_CHAT_ID (ou TELEGRAM_HOME_CHANNEL no .env do Hermes)"
  exit 1
fi

if [[ ! -f "$KUMA_DB" ]]; then
  echo "ERRO: base Uptime Kuma não encontrada em $KUMA_DB"
  exit 1
fi

CONFIG=$(python3 - "$TOKEN" "$CHAT_ID" <<'PY'
import json, sys
token, chat = sys.argv[1], sys.argv[2]
print(json.dumps({
    "type": "telegram",
    "name": "Telegram Homelab",
    "telegramBotToken": token,
    "telegramChatID": chat,
    "telegramServerUrl": "https://api.telegram.org",
    "telegramUseTemplate": False,
    "telegramSendSilently": False,
    "telegramProtectContent": False,
    "isDefault": False,
}, separators=(",", ":")))
PY
)

EXISTING=$(sqlite3 "$KUMA_DB" "SELECT id FROM notification WHERE name='Telegram Homelab' LIMIT 1;")

if [[ -n "$EXISTING" ]]; then
  sqlite3 "$KUMA_DB" "UPDATE notification SET config='$CONFIG', active=1 WHERE id=$EXISTING;"
  NOTIF_ID="$EXISTING"
  echo "Notificação Telegram actualizada (id=$NOTIF_ID)"
else
  sqlite3 "$KUMA_DB" "INSERT INTO notification (name, active, user_id, is_default, config) VALUES ('Telegram Homelab', 1, 1, 0, '$CONFIG');"
  NOTIF_ID=$(sqlite3 "$KUMA_DB" "SELECT id FROM notification WHERE name='Telegram Homelab' LIMIT 1;")
  echo "Notificação Telegram criada (id=$NOTIF_ID)"
fi

while IFS= read -r mid; do
  [[ -z "$mid" ]] && continue
  sqlite3 "$KUMA_DB" "INSERT OR IGNORE INTO monitor_notification (monitor_id, notification_id) VALUES ($mid, $NOTIF_ID);"
done < <(sqlite3 "$KUMA_DB" "SELECT id FROM monitor WHERE user_id=1;")

echo "Telegram ligado a todos os monitores (webhook HA mantido)."

echo "A enviar mensagem de teste..."
docker exec uptime-kuma node -e "
const Telegram = require('/app/server/notification-providers/telegram');
const n = JSON.parse(process.argv[1]);
new Telegram().send(n, '[Uptime Kuma] Teste Telegram nativo — homelab OK').then(console.log).catch(e => { console.error(e.message); process.exit(1); });
" "$CONFIG"

echo "OK: verifica o Telegram."
