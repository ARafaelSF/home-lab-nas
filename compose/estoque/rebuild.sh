#!/bin/bash
# Actualiza o código da oficina e reconstrói as imagens.
set -euo pipefail
cd /opt/controle-estoque
git pull --ff-only
cd /root/homelab/compose/estoque
# BUILD_ID muda o nome dos chunks e evita cache CDN/browser com HTML no lugar de .js
export BUILD_ID="${BUILD_ID:-$(date +%s)}"
docker compose -p estoque build --pull api web
docker compose -p estoque up -d
docker compose -p estoque ps

# Smoke: rotas da API devem ir ao backend (401 sem token), nunca HTML do SPA.
smoke_api_route() {
  local path="$1"
  local ctype
  ctype=$(curl -sS -m 10 -o /tmp/estoque-smoke.body -D /tmp/estoque-smoke.hdr \
    -w '%{content_type}' "http://127.0.0.1:3011${path}" || true)
  if grep -qi 'text/html' /tmp/estoque-smoke.hdr 2>/dev/null || [[ "$ctype" == *html* ]]; then
    echo "FALHA smoke: ${path} devolveu HTML (nginx sem proxy para esta rota). Ver nginx.conf." >&2
    exit 1
  fi
  echo "OK smoke: ${path} -> ${ctype}"
}
smoke_api_route /meta/location-types
smoke_api_route /meta/item-table-columns
smoke_api_route /location-kinds
smoke_api_route /locations
smoke_api_route /settings/item-table-columns
