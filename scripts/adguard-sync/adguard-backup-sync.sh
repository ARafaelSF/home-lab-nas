#!/usr/bin/env bash
# Replica filtros/regras do AdGuard oficial (Docker) para o Pi adguard-backup.
set -euo pipefail

SSH_KEY="${ADGUARD_BACKUP_SSH_KEY:-/root/.ssh/adguard-backup}"
REMOTE_YAML="/opt/AdGuardHome/AdGuardHome.yaml"
SYNC_PY="${ADGUARD_SYNC_PY:-/root/homelab/scripts/adguard-sync/sync-to-backup.py}"
WORKDIR="$(mktemp -d /tmp/adguard-sync.XXXXXX)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }

ssh_base=(ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes
          -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8)

pick_target() {
  if "${ssh_base[@]}" -o ConnectTimeout=4 pi@192.168.3.22 true 2>/dev/null; then
    TARGET_SSH=(pi@192.168.3.22)
    return 0
  fi
  if "${ssh_base[@]}" -p 2222 -o ConnectTimeout=4 pi@127.0.0.1 true 2>/dev/null; then
    TARGET_SSH=(-p 2222 pi@127.0.0.1)
    return 0
  fi
  return 1
}

log "A exportar YAML do AdGuard oficial..."
docker exec adguardhome cat /opt/adguardhome/conf/AdGuardHome.yaml >"$WORKDIR/origin.yaml"

if ! pick_target; then
  log "AVISO: Pi adguard-backup inacessível (192.168.3.22 e túnel :2222). Sync adiado."
  exit 0
fi

log "Alvo SSH: ${TARGET_SSH[*]}"
"${ssh_base[@]}" "${TARGET_SSH[@]}" "sudo cat ${REMOTE_YAML}" >"$WORKDIR/replica.yaml"

set +e
python3 "$SYNC_PY" \
  --origin "$WORKDIR/origin.yaml" \
  --replica "$WORKDIR/replica.yaml" \
  --output "$WORKDIR/merged.yaml"
sync_rc=$?
set -e
if [[ "$sync_rc" -eq 10 ]]; then
  log "Backup já estava alinhado — nada a reiniciar."
  exit 0
fi
if [[ "$sync_rc" -ne 0 ]]; then
  log "ERRO: merge do YAML falhou (rc=${sync_rc})."
  exit "$sync_rc"
fi

log "A enviar YAML alinhado e a reiniciar AdGuardHome no Pi..."
# shellcheck disable=SC2029
"${ssh_base[@]}" "${TARGET_SSH[@]}" "cat > /tmp/AdGuardHome.synced.yaml && sudo cp /tmp/AdGuardHome.synced.yaml ${REMOTE_YAML} && sudo chmod 644 ${REMOTE_YAML} && sudo systemctl restart AdGuardHome && rm -f /tmp/AdGuardHome.synced.yaml" \
  <"$WORKDIR/merged.yaml"

sleep 2
if "${ssh_base[@]}" "${TARGET_SSH[@]}" "systemctl is-active AdGuardHome" | grep -qx active; then
  log "AdGuard backup sincronizado e activo."
else
  log "ERRO: AdGuardHome no Pi não ficou active após o sync."
  exit 1
fi
