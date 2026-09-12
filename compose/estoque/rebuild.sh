#!/bin/bash
# Actualiza o código da oficina e reconstrói as imagens.
set -euo pipefail
cd /opt/controle-estoque
git pull --ff-only
cd /root/homelab/compose/estoque
docker compose -p estoque build --pull api web
docker compose -p estoque up -d
docker compose -p estoque ps
