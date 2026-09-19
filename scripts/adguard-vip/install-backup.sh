#!/usr/bin/env bash
# Instala keepalived VIP no Pi backup (a partir do NAS).
# Uso: PI_SUDO_PASS='...' /root/homelab/scripts/adguard-vip/install-backup.sh
# Não grava a password em disco.
set -euo pipefail

SSH_KEY="${ADGUARD_BACKUP_SSH_KEY:-/root/.ssh/adguard-backup}"
TARGET="${ADGUARD_BACKUP_SSH_TARGET:-pi@192.168.3.22}"
SRC="$(cd "$(dirname "$0")" && pwd)"

if [[ -z "${PI_SUDO_PASS:-}" ]]; then
  echo "Defina PI_SUDO_PASS no ambiente (não será gravada)." >&2
  exit 1
fi

ssh_base=(ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes
          -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8)

sudo_remote() {
  # Uma única shell remota sob sudo (evita que && corra sem privilégios)
  # shellcheck disable=SC2029
  printf '%s\n' "$PI_SUDO_PASS" | "${ssh_base[@]}" "$TARGET" "sudo -S -p '' bash -lc $(printf '%q' "$*")"
}

log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }

log "A instalar keepalived no Pi..."
sudo_remote "DEBIAN_FRONTEND=noninteractive apt-get install -y keepalived python3"

log "A copiar configs..."
scp -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes \
  "$SRC/check_adguard.sh" "$SRC/keepalived.backup.conf" \
  "$TARGET:/tmp/"

sudo_remote "install -d /etc/keepalived && install -m 755 /tmp/check_adguard.sh /etc/keepalived/check_adguard.sh && install -m 644 /tmp/keepalived.backup.conf /etc/keepalived/keepalived.conf && rm -f /tmp/check_adguard.sh /tmp/keepalived.backup.conf"

# NOPASSWD mínimo para sync AdGuard + keepalived (evita password interativa no futuro)
log "A configurar sudoers (NOPASSWD limitado)..."
sudo_remote "tee /etc/sudoers.d/adguard-ops >/dev/null <<'EOF'
# Gerido por scripts/adguard-vip — sync AdGuard + keepalived
pi ALL=(root) NOPASSWD: /bin/cp, /usr/bin/cp, /bin/cat, /usr/bin/cat, /bin/chmod, /usr/bin/chmod
pi ALL=(root) NOPASSWD: /bin/systemctl, /usr/bin/systemctl
pi ALL=(root) NOPASSWD: /usr/sbin/service
EOF
chmod 440 /etc/sudoers.d/adguard-ops
visudo -cf /etc/sudoers.d/adguard-ops"

log "A activar keepalived..."
sudo_remote "systemctl enable --now keepalived"
sleep 2
"${ssh_base[@]}" "$TARGET" 'systemctl --no-pager -l status keepalived | head -15; ip -4 addr show wlan0 | grep -E "inet |192.168.3.23" || true'

log "Pi backup pronto (estado BACKUP — VIP só se o principal falhar)."
