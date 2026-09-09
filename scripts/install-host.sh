#!/usr/bin/env bash
# Instala no host o que o git versiona mas o sistema precisa em /etc e systemd.
# NÃO copia código para /opt — o código corre a partir de /root/homelab (git).
# /opt/container-ops fica só para dados: backups/, *.env, logs/
set -euo pipefail

REPO="${HOMELAB_ROOT:-/root/homelab}"
DATA="${CONTAINER_OPS_DATA:-/opt/container-ops}"

log() { printf '[install-host] %s\n' "$*"; }

[[ -d "$REPO" ]] || { echo "Repo não encontrado: $REPO"; exit 1; }

mkdir -p "$DATA/backups" "$DATA/logs"
chmod 700 "$DATA" 2>/dev/null || true

# --- DNS do host (opcional se já existir) ---
if [[ -f "$REPO/etc/systemd/resolved.conf.d/homelab-dns.conf" ]]; then
  mkdir -p /etc/systemd/resolved.conf.d
  cp -f "$REPO/etc/systemd/resolved.conf.d/homelab-dns.conf" \
    /etc/systemd/resolved.conf.d/homelab-dns.conf
  log "DNS: /etc/systemd/resolved.conf.d/homelab-dns.conf"
fi

# --- Rota Hangar 192.168.68.0/24 ---
if [[ -f "$REPO/etc/network/if-up.d/route-lan68" ]]; then
  install -m 755 "$REPO/etc/network/if-up.d/route-lan68" /etc/network/if-up.d/route-lan68
  IFACE=eth0 /etc/network/if-up.d/route-lan68 || true
  log "Rota: /etc/network/if-up.d/route-lan68 + aplicada agora"
fi

# --- systemd: listener HA updates ---
install -m 644 "$REPO/scripts/container-ops/container-ops-ha-update.service" \
  /etc/systemd/system/container-ops-ha-update.service

# Env do listener (só cria se não existir — não sobrescreve token)
if [[ ! -f "$DATA/ha-update.env" ]]; then
  if [[ -f "$REPO/scripts/container-ops/ha-update.env.example" ]]; then
    cp "$REPO/scripts/container-ops/ha-update.env.example" "$DATA/ha-update.env"
    chmod 600 "$DATA/ha-update.env"
    log "AVISO: criado $DATA/ha-update.env a partir do example — preenche DOCKER_OPS_TOKEN"
  fi
else
  # Garante caminhos do código no git (preserva o resto do ficheiro)
  python3 - <<'PY'
from pathlib import Path
p = Path("/opt/container-ops/ha-update.env")
text = p.read_text()
updates = {
    "CONTAINER_OPS_SH": "/root/homelab/scripts/container-ops/ops.sh",
    "CONTAINER_OPS_APPS": "/root/homelab/scripts/container-ops/apps.conf",
    "CONTAINER_OPS_LOG_DIR": "/opt/container-ops/logs",
    "CONTAINER_OPS_DATA": "/opt/container-ops",
}
lines = []
seen = set()
for line in text.splitlines():
    if not line.strip() or line.strip().startswith("#") or "=" not in line:
        lines.append(line)
        continue
    k, _, _ = line.partition("=")
    k = k.strip()
    if k in updates:
        lines.append(f"{k}={updates[k]}")
        seen.add(k)
    else:
        lines.append(line)
for k, v in updates.items():
    if k not in seen:
        lines.append(f"{k}={v}")
p.write_text("\n".join(lines) + "\n")
PY
  log "Actualizado caminhos em $DATA/ha-update.env"
fi

# --- systemd: minipc temp + adguard sync ---
install -m 644 "$REPO/scripts/minipc-temp/minipc-temp-publisher.service" \
  /etc/systemd/system/minipc-temp-publisher.service
install -m 644 "$REPO/scripts/minipc-temp/minipc-temp-publisher.timer" \
  /etc/systemd/system/minipc-temp-publisher.timer
install -m 644 "$REPO/scripts/adguard-sync/adguard-backup-sync.service" \
  /etc/systemd/system/adguard-backup-sync.service
install -m 644 "$REPO/scripts/adguard-sync/adguard-backup-sync.timer" \
  /etc/systemd/system/adguard-backup-sync.timer

# Wrappers em /opt para hábitos antigos (apontam ao git; não são a fonte)
cat >"$DATA/ops.sh" <<'EOF'
#!/usr/bin/env bash
# Wrapper — o script real está no git. Não edites este ficheiro.
exec /root/homelab/scripts/container-ops/ops.sh "$@"
EOF
chmod +x "$DATA/ops.sh"

# Remove cópias mortas de código (mantém .env, backups, logs)
rm -f "$DATA/ha-update-listener.py" "$DATA/apps.conf" "$DATA/GUIA.md" "$DATA/README.md" 2>/dev/null || true
rm -rf "$DATA/minipc-temp" "$DATA/adguard-sync" "$DATA/__pycache__" 2>/dev/null || true

systemctl daemon-reload
systemctl enable --now container-ops-ha-update.service
systemctl enable --now minipc-temp-publisher.timer
systemctl enable --now adguard-backup-sync.timer
systemctl restart container-ops-ha-update.service
systemctl restart systemd-resolved.service 2>/dev/null || true

log "OK. Código: $REPO/scripts/…  |  Dados: $DATA"
log "Teste: curl -s http://192.168.3.21:8787/health"
log "Teste: /root/homelab/scripts/container-ops/ops.sh list | head"
