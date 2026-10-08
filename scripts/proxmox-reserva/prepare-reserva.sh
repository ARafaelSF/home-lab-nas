#!/usr/bin/env bash
# Preflight somente leitura da reserva. Falha fechado: não altera VMs, storage ou energia.
set -euo pipefail

PRIMARY_SSH="${PRIMARY_SSH:-proxmox}"
RESERVA_SSH="${RESERVA_SSH:-proxmox-reserva}"
PBS_PRIMARY="${PBS_PRIMARY:-pbs-reserva}"
PBS_RESERVA="${PBS_RESERVA:-pbs-local}"
VMIDS=(100 101)
ALLOW_REBUILD="${ALLOW_REBUILD:-0}"

failures=0
unsafe=0
needs_rebuild=0
fail() { printf 'ERRO: %s\n' "$*" >&2; failures=$((failures + 1)); }
mark_unsafe() { unsafe=1; fail "$@"; }
mark_rebuild() { needs_rebuild=1; fail "$@"; }
note() { printf '%s\n' "$*"; }
ssh_r() { ssh -o BatchMode=yes -o ConnectTimeout=15 "$RESERVA_SSH" "$@"; }
ssh_p() { ssh -o BatchMode=yes -o ConnectTimeout=15 "$PRIMARY_SSH" "$@"; }

note '=== conectividade e identidade ==='
if ! ssh_r 'hostname >/dev/null && pvesh get /nodes/$(hostname)/status --output-format json >/dev/null'; then
  mark_unsafe 'Proxmox reserva inacessível ou API local indisponível'
fi
if ! ssh_p 'hostname >/dev/null && pvesh get /nodes/$(hostname)/status --output-format json >/dev/null'; then
  mark_unsafe 'Proxmox principal inacessível ou API local indisponível'
fi

note '=== VMs reserva ==='
for vmid in "${VMIDS[@]}"; do
  if ! cfg="$(ssh_r "qm config $vmid 2>/dev/null")"; then
    mark_rebuild "VM $vmid ausente ou configuração ilegível na reserva"
    continue
  fi
  state="$(ssh_r "qm status $vmid | awk '{print \$2}'")"
  [[ "$state" == stopped ]] || mark_unsafe "VM $vmid não está stopped (estado=$state)"
  grep -q '^lock:' <<<"$cfg" && mark_unsafe "VM $vmid possui lock: $(grep '^lock:' <<<"$cfg")"
  if ! grep -Eq '^(scsi|sata|virtio|ide|efidisk)[0-9]*:' <<<"$cfg"; then
    mark_rebuild "VM $vmid sem disco configurado; reconstrução manual necessária"
    continue
  fi
  grep -q '^onboot: 0$' <<<"$cfg" || mark_unsafe "VM $vmid não está explicitamente onboot=0"
  if grep -Eq '^net[0-9]+:' <<<"$cfg"; then
    while IFS= read -r net; do
      [[ "$net" == *',link_down=1'* ]] || mark_unsafe "VM $vmid possui interface sem link_down=1: $net"
    done < <(grep -E '^net[0-9]+:' <<<"$cfg")
  else
    mark_rebuild "VM $vmid não possui interface de rede para validar isolamento"
    continue
  fi
done

note '=== tasks e processos críticos ==='
if ssh_r "pvesh get /nodes/\$(hostname)/tasks --output-format json 2>/dev/null | python3 -c 'import json,sys; ts=json.load(sys.stdin); critical={\"qmrestore\",\"vzdump\",\"vma\",\"pbs-restore\"}; sys.exit(0 if any(t.get(\"type\") in critical and t.get(\"status\") not in {\"OK\",\"ERROR\",\"STOPPED\",\"stopped\"} for t in ts) else 1)'"; then
  mark_unsafe 'há task crítica Proxmox ativa na reserva'
fi
if ssh_r "ps -eo pid=,args= | awk '/[q]mrestore|[p]bs-restore|[v]zdump|[v]ma|[q]emu-img/ {found=1} END {exit !found}'"; then
  mark_unsafe 'há processo crítico de backup/restore ativo na reserva'
fi

note '=== PBS e storage ==='
ssh_r "pvesm status --output-format json" || fail 'não foi possível consultar storages da reserva'
for storage in "$PBS_RESERVA"; do
  ssh_r "pvesm status --storage $storage --output-format json 2>/dev/null | grep -q 'active'" \
    || mark_unsafe "storage $storage não está ativo"
done
ssh_p "pvesm status --storage $PBS_PRIMARY --output-format json 2>/dev/null | grep -q 'active'" \
  || mark_unsafe "storage $PBS_PRIMARY não está ativo no principal"

note '=== identidade PBS (somente leitura) ==='
for vmid in "${VMIDS[@]}"; do
  ssh_p "pvesm list $PBS_PRIMARY 2>/dev/null | grep -q '/vm/$vmid/'" \
    || mark_rebuild "não há snapshot PBS do principal para VM $vmid"
done

note '=== temperatura e SMART/NVMe ==='
nvme_report="$(ssh_r "if command -v nvme >/dev/null; then nvme smart-log /dev/nvme0 2>/dev/null; elif command -v smartctl >/dev/null; then smartctl -a /dev/nvme0 2>/dev/null; else exit 2; fi" || true)"
if [[ -z "$nvme_report" ]]; then
  mark_unsafe 'não foi possível consultar SMART/NVMe'
else
  printf '%s\n' "$nvme_report" | grep -E 'temperature|Temperature|critical_warning|Critical Warning|media_errors|Media and Data Integrity|unsafe_shutdowns|Unsafe Shutdowns|warning_comp|critical_comp' || true
  if grep -Eiq 'critical.?warning:[[:space:]]*(0x)?[1-9a-f]|critical.?comp.*(temp|temperature).*threshold:[[:space:]]*[0-9]{2,3}' <<<"$nvme_report"; then
    mark_unsafe 'indicador térmico/SMART crítico presente'
  fi
  sensor2="$(awk -F: '/Temperature Sensor 2/ {gsub(/[^0-9.]/, "", $2); print $2; exit}' <<<"$nvme_report")"
  critical_temp="$(awk -F: '/Critical Comp\. Temp\. Threshold/ {gsub(/[^0-9.]/, "", $2); print $2; exit}' <<<"$nvme_report")"
  if [[ "$sensor2" =~ ^[0-9]+([.][0-9]+)?$ && "$critical_temp" =~ ^[0-9]+([.][0-9]+)?$ ]] \
      && awk -v actual="$sensor2" -v limit="$critical_temp" 'BEGIN { exit !(actual >= limit) }'; then
    mark_unsafe "sensor NVMe 2 acima do limiar crítico (${sensor2} >= ${critical_temp})"
  fi
fi

if (( failures )); then
  if (( unsafe )); then
    result=UNSAFE
  elif (( needs_rebuild )); then
    result=NEEDS_REBUILD
  else
    result=UNSAFE
  fi
  printf 'PREFLIGHT %s: %d verificação(ões). Nenhuma alteração foi executada.\n' "$result" "$failures" >&2
  if (( unsafe == 0 && needs_rebuild != 0 && ALLOW_REBUILD == 1 )); then
    printf 'PREFLIGHT NEEDS_REBUILD aceito para reconstrução explícita; nenhuma alteração foi executada.\n'
    exit 0
  fi
  exit 1
fi
printf 'PREFLIGHT READY: ambiente reserva consistente e isolado.\n'
