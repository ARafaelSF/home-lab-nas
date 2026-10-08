#!/usr/bin/env bash
# Harness local: todos os comandos externos são mocks; nunca usa SSH real.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PREPARE="$ROOT/scripts/proxmox-reserva/prepare-reserva.sh"
ROUTINE="$ROOT/scripts/proxmox-reserva/rotina-semanal.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat >"$TMP/bin/ssh" <<'MOCK'
#!/usr/bin/env bash
mode="${MOCK_MODE:-READY}"; cmd="${*: -1}"
[[ "$mode" == SSH_FAIL ]] && exit 255
case "$cmd" in
  *'pvesh get /nodes/'*'/status'*) printf '{}\n'; exit 0;;
  *'qm config 100'*) case "$mode" in NEEDS_REBUILD) printf 'memory: 128\n';; LOCK) printf 'lock: create\nmemory: 128\n';; *) printf 'onboot: 0\nnet0: virtio=aa,bridge=vmbr0,link_down=1\nscsi0: local-lvm:vm-100-disk-0,size=1010G\n';; esac; exit 0;;
  *'qm config 101'*) case "$mode" in NO_NET) printf 'onboot: 0\nscsi0: local-lvm:vm-101-disk-0,size=128G\n';; LINK_UP) printf 'onboot: 0\nnet0: virtio=aa,bridge=vmbr0\nscsi0: local-lvm:vm-101-disk-0,size=128G\n';; ONBOOT) printf 'onboot: 1\nnet0: virtio=aa,bridge=vmbr0,link_down=1\nscsi0: local-lvm:vm-101-disk-0,size=128G\n';; *) printf 'onboot: 0\nnet0: virtio=aa,bridge=vmbr0,link_down=1\nscsi0: local-lvm:vm-101-disk-0,size=128G\n';; esac; exit 0;;
  *'qm status '*) [[ "$mode" != VM_ON ]] && printf 'stopped\n' || printf 'running\n'; exit 0;;
  *'/tasks'*'python3 -c'*) [[ "$mode" == TASK ]] && printf '[{"type":"qmrestore","status":"running"}]\n' && exit 0 || printf '[]\n'; exit 1;;
  *'ps -eo pid='*) [[ "$mode" == TASK ]] && printf '123 qmrestore 100\n' && exit 0 || exit 1;;
  *'pvesm status --output-format json'*) [[ "$mode" == PBS_FAIL ]] && exit 1 || printf '[]\n'; exit 0;;
  *'pvesm status --storage'*'pbs-local'*) [[ "$mode" == STORAGE ]] && exit 1 || printf '{"active":1}\n'; exit 0;;
  *'pvesm status --storage'*'pbs-reserva'*) [[ "$mode" == PBS_FAIL ]] && exit 1 || printf '{"active":1}\n'; exit 0;;
  *'pvesm list'*'grep -q'*) [[ "$mode" == PBS_MISSING ]] && exit 1 || exit 0;;
  *'pvesm list'*) printf 'pbs-reserva:backup/vm/100/test\npbs-reserva:backup/vm/101/test\n'; exit 0;;
  *'nvme smart-log'*|*'smartctl -a'*) case "$mode" in SMART_FAIL) exit 1;; TEMP) printf 'critical_warning : 0x00\nTemperature Sensor 2 : 91 C\nCritical Comp. Temp. Threshold : 89 C\n';; *) printf 'critical_warning : 0x00\nTemperature Sensor 2 : 55 C\nCritical Comp. Temp. Threshold : 89 C\n';; esac; exit 0;;
esac
exit 0
MOCK
chmod 755 "$TMP/bin/ssh"
pass=0; fail=0
run_case() { name="$1"; expected="$2"; output="$(PATH="$TMP/bin:$PATH" MOCK_MODE="$name" bash "$PREPARE" 2>&1)"; rc=$?; if [[ "$expected" == 0 && "$rc" -eq 0 && "$output" == *'PREFLIGHT READY'* ]] || [[ "$expected" != 0 && "$rc" -ne 0 && "$output" == *"PREFLIGHT $expected"* ]]; then printf 'PASS %-16s -> %s\n' "$name" "$expected"; pass=$((pass+1)); else printf 'FAIL %-16s rc=%s expected=%s\n%s\n' "$name" "$rc" "$expected" "$output"; fail=$((fail+1)); fi; }
run_case READY 0
run_case NEEDS_REBUILD NEEDS_REBUILD
run_case LOCK UNSAFE
run_case VM_ON UNSAFE
run_case NO_NET NEEDS_REBUILD
run_case LINK_UP UNSAFE
run_case ONBOOT UNSAFE
run_case TASK UNSAFE
run_case PBS_FAIL UNSAFE
run_case STORAGE UNSAFE
run_case TEMP UNSAFE
run_case SMART_FAIL UNSAFE
cat >"$TMP/bin/ssh-fail" <<'MOCK'
#!/usr/bin/env bash
exit 255
MOCK
chmod 755 "$TMP/bin/ssh-fail"
if PATH="$TMP/bin:$PATH" MOCK_MODE=SSH_FAIL bash "$PREPARE" >/dev/null 2>&1; then printf 'FAIL SSH_FAIL\n'; fail=$((fail+1)); else printf 'PASS SSH_FAIL         -> UNSAFE\n'; pass=$((pass+1)); fi
grep -q -- '--start 0' "$ROUTINE" && ! grep -q -- '--force' "$ROUTINE" && ! grep -q -- '--skiplock' "$ROUTINE" && grep -q 'link_down=1' "$ROUTINE" && grep -q 'PIPESTATUS' "$ROUTINE" && grep -q 'return 1' "$ROUTINE" && { printf 'PASS routine-static    -> restore/shutdown seguros\n'; pass=$((pass+1)); } || { printf 'FAIL routine-static\n'; fail=$((fail+1)); }
printf 'RESULT pass=%d fail=%d\n' "$pass" "$fail"
(( fail == 0 ))
