#!/bin/bash
# Verificação rápida dos backups Duplicati (rodar mensalmente).
# Teste de restore completo: faça manualmente no painel Duplicati com 1 volume pequeno.

set -euo pipefail

BACKUP_ROOT="/mnt/ssd-backup"
MIN_GB=50

echo "=== Duplicati — verificação de backup ==="
echo "Data: $(date '+%Y-%m-%d %H:%M:%S %z')"
echo

if [[ ! -d "$BACKUP_ROOT" ]]; then
  echo "ERRO: $BACKUP_ROOT não existe ou não está montado."
  exit 1
fi

echo "Espaço no SSD de backup:"
df -h "$BACKUP_ROOT" | tail -1
echo

echo "Tamanho por pasta:"
du -sh "$BACKUP_ROOT"/* 2>/dev/null | sort -h
echo

USED_GB=$(du -s "$BACKUP_ROOT" | awk '{print int($1/1024/1024)}')
if [[ "$USED_GB" -lt "$MIN_GB" ]]; then
  echo "AVISO: menos de ${MIN_GB} GB de backup — confira se os jobs rodaram."
else
  echo "OK: ~${USED_GB} GB de dados de backup no SSD."
fi

echo
echo "=== Teste de restore (manual, 1x por trimestre) ==="
echo "1. Abra Duplicati: http://127.0.0.1:8200 (só na rede local)"
echo "2. Restore → escolha um backup recente de um volume PEQUENO (ex.: homepage_config)"
echo "3. Restaure para uma pasta temporária (/tmp/restore-test)"
echo "4. Confirme que os arquivos abrem; depois apague /tmp/restore-test"
echo
echo "Container Duplicati: $(docker inspect duplicati --format '{{.State.Status}}' 2>/dev/null || echo 'não encontrado')"
