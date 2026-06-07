#!/usr/bin/env bash
# Configura autenticação GHCR no WUD (evita estado "unknown" no Home Assistant).
# Uso: sudo bash /root/homelab/scripts/wud-setup-ghcr-auth.sh

set -euo pipefail

TARGET="/etc/docker/wud-registries.env"
EXAMPLE="/root/homelab/etc/docker/wud-registries.env.example"

if [[ -f "$TARGET" ]] && grep -qE '^WUD_REGISTRY_GHCR_PUBLIC_TOKEN=ghp_' "$TARGET" 2>/dev/null; then
  echo "Já existe token em $TARGET — a recriar o WUD..."
else
  echo "Crie um GitHub PAT (classic) com scope read:packages."
  read -r -p "Utilizador GitHub: " GH_USER
  read -r -s -p "Token (ghp_...): " GH_TOKEN
  echo
  install -d -m 700 /etc/docker
  cat >"$TARGET" <<EOF
WUD_REGISTRY_GHCR_PUBLIC_USERNAME=${GH_USER}
WUD_REGISTRY_GHCR_PUBLIC_TOKEN=${GH_TOKEN}
EOF
  chmod 600 "$TARGET"
  echo "Gravado em $TARGET"
fi

COMPOSE="/var/lib/docker/volumes/portainer_data/_data/compose/26/docker-compose.yml"
if [[ -f "$COMPOSE" ]]; then
  if ! grep -q 'wud-registries.env' "$COMPOSE"; then
    sed -i 's|/etc/docker/wud-lscr.env|/etc/docker/wud-registries.env|' "$COMPOSE"
    echo "Compose Portainer 26 atualizado."
  fi
fi

docker restart wud
sleep 6
docker exec wud printenv WUD_REGISTRY_GHCR_PUBLIC_USERNAME >/dev/null 2>&1 && echo "WUD carregou credenciais GHCR." || echo "AVISO: variáveis GHCR não visíveis no container."

docker exec wud wget -qO- http://127.0.0.1:3000/api/containers 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for c in data:
    if 'immich' in c.get('name', ''):
        err = (c.get('error') or {}).get('message', '')
        print(f\"{c['name']}: result={c.get('result')} error={err or '-'}\")
" || true
