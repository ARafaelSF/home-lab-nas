#!/usr/bin/env bash
# Instala o failover DNAT no Pi adguard-backup (sobrevive se o .21 cair).
set -euo pipefail

SSH_KEY="${ADGUARD_BACKUP_SSH_KEY:-/root/.ssh/adguard-backup}"
TARGET="${ADGUARD_BACKUP_SSH_TARGET:-pi@192.168.3.22}"
SRC="$(cd "$(dirname "$0")" && pwd)"
UNIFI_ENV="${UNIFI_ENV:-/root/homelab/compose/unifi-mcp/.env}"

ssh_base=(ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes
          -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8)

log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }

if [[ ! -f "$UNIFI_ENV" ]]; then
  log "ERRO: falta $UNIFI_ENV"
  exit 1
fi

# Extrair user/pass do .env UniFi (sem imprimir)
eval "$(python3 - <<PY
from pathlib import Path
vals={}
for line in Path("$UNIFI_ENV").read_text().splitlines():
    line=line.strip()
    if not line or line.startswith('#') or '=' not in line: continue
    k,v=line.split('=',1)
    vals[k]=v
for k in ('UNIFI_USERNAME','UNIFI_PASSWORD'):
    if k not in vals: raise SystemExit(f'missing {k}')
    print(f'export {k}={vals[k]!r}')
PY
)"

log "A criar directórios no Pi..."
"${ssh_base[@]}" "$TARGET" 'mkdir -p ~/adguard-dnat-failover ~/.config ~/.cache'

log "A copiar script e units..."
scp -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes \
  "$SRC/adguard-dnat-failover.py" \
  "$TARGET:~/adguard-dnat-failover/adguard-dnat-failover.py"
scp -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes \
  "$SRC/adguard-dnat-failover.service" \
  "$SRC/adguard-dnat-failover.timer" \
  "$TARGET:~/.config/systemd/user/"

log "A gravar env (chmod 600)..."
# Forçar host acessível a partir da VLAN Servidor
"${ssh_base[@]}" "$TARGET" "cat > ~/.config/adguard-dnat-failover.env && chmod 600 ~/.config/adguard-dnat-failover.env" <<EOF
UNIFI_HOST=192.168.3.1
UNIFI_USERNAME=${UNIFI_USERNAME}
UNIFI_PASSWORD=${UNIFI_PASSWORD}
ADGUARD_PRIMARY=192.168.3.21
ADGUARD_BACKUP=192.168.3.22
FAIL_THRESHOLD=3
OK_THRESHOLD=3
EOF

log "A activar timer systemd --user..."
"${ssh_base[@]}" "$TARGET" 'systemctl --user daemon-reload
systemctl --user enable --now adguard-dnat-failover.timer
systemctl --user start adguard-dnat-failover.service
systemctl --user --no-pager status adguard-dnat-failover.timer | head -15
'

log "Instalação concluída no $TARGET"
