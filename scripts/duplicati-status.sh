#!/bin/bash
# Estado dos jobs Duplicati (local + OneDrive).
set -euo pipefail

PW=$(docker exec duplicati printenv DUPLICATI__WEBSERVICE_PASSWORD 2>/dev/null || true)
if [[ -z "$PW" ]]; then
  echo "ERRO: container duplicati não encontrado."
  exit 1
fi

TOKEN=$(curl -s -X POST "http://127.0.0.1:8200/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "import json; print(json.dumps({'Password': '''$PW'''}))")" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessToken'])")

echo "=== Jobs Duplicati ==="
curl -s -H "Authorization: Bearer $TOKEN" "http://127.0.0.1:8200/api/v1/backups" | python3 -c "
import json, sys
for x in json.load(sys.stdin):
    b = x['Backup']
    s = x.get('Schedule') or {}
    m = b.get('Metadata') or {}
    print(f\"\\n{b['Name']} (id {b['ID']})\")
    print(f\"  Destino: {b.get('TargetURL','?')}\")
    if s:
        print(f\"  Agenda: {s.get('Repeat','?')} — {s.get('Rule','')}\")
        print(f\"  Próxima: {s.get('Time','?')}\")
    if m.get('LastBackupFinished'):
        print(f\"  Último OK: {m['LastBackupFinished']} — {m.get('TargetSizeString','')}\")
    if m.get('LastErrorMessage'):
        print(f\"  Erro: {m['LastErrorMessage'][:120]}...\")
"

echo ""
echo "=== Tarefas em execução ==="
curl -s -H "Authorization: Bearer $TOKEN" "http://127.0.0.1:8200/api/v1/tasks" | python3 -c "
import json, sys
tasks = json.load(sys.stdin)
if not tasks:
    print('  (nenhuma)')
for t in tasks:
    print(f\"  Task {t['ID']}: {t['Status']} — {t.get('ErrorMessage') or 'em curso'}\")
" 2>/dev/null || echo "  (API tasks indisponível)"

echo ""
echo "SSD local:"
du -sh /mnt/ssd-backup/docker-volumes/proxmox-docker01 2>/dev/null || echo "  pasta não encontrada"
