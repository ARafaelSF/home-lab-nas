#!/bin/bash
# Testa se a passphrase do backup coincide com a que digitas (sem gravar a senha).
set -euo pipefail

echo "=== Teste de senha Duplicati ==="
echo "Digite a senha que guardou no Vaultwarden (a do login Duplicati):"
read -rs PASS1
echo
echo "Digite de novo para confirmar:"
read -rs PASS2
echo

if [[ "$PASS1" != "$PASS2" ]]; then
  echo "ERRO: as duas digitações não coincidem."
  exit 1
fi

TEST_URL="file:///backups/duplicati-passphrase-test"
TEST_DB="/config/passphrase-test.sqlite"
RESTORE="/tmp/passphrase-test-restore"

docker exec duplicati sh -c "rm -rf '$RESTORE' /backups/duplicati-passphrase-test '$TEST_DB' 2>/dev/null; mkdir -p /backups/duplicati-passphrase-test '$RESTORE'"

echo "A criar backup de teste (1 ficheiro)..."
if ! docker exec -e PASSPHRASE="$PASS1" duplicati /app/duplicati/duplicati-cli backup \
  "$TEST_URL" /source/homelab/README.md \
  --passphrase="$PASS1" \
  --dbpath="$TEST_DB" \
  --disable-module=console-password-input >/dev/null 2>&1; then
  echo "ERRO: backup de teste falhou — a senha pode estar errada."
  exit 1
fi

echo "A verificar integridade (Test)..."
if docker exec duplicati /app/duplicati/duplicati-cli test "$TEST_URL" \
  --passphrase="$PASS1" \
  --dbpath="$TEST_DB" \
  --disable-module=console-password-input 2>&1 | grep -q "no errors"; then
  echo "OK: senha CORRETA — o backup de teste abre sem erros."
else
  echo "ERRO: Test falhou com esta senha."
  exit 1
fi

docker exec duplicati sh -c "rm -rf '$RESTORE' /backups/duplicati-passphrase-test '$TEST_DB'"
echo
echo "Pode guardar esta senha no Vaultwarden como 'Duplicati homelab' (login + passphrase)."
