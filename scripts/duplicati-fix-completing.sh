#!/bin/bash
# Corrige "Completing previous backup …" no job docker-local (Duplicati 2.3.x).
# Uso: sudo bash /root/homelab/scripts/duplicati-fix-completing.sh

set -euo pipefail

DB_JOB="/var/lib/docker/volumes/25_duplicati_config/_data/LCTRVMFCIT.sqlite"
LOCK="/var/lib/docker/volumes/25_duplicati_config/_data/control_dir_v2/lock_v2"

echo "==> A subir containers parados pelos hooks..."
docker exec duplicati sh /scripts/post-backup.sh 2>/dev/null || true
for c in filebrowser vaultwarden mealie immich_postgres immich_machine_learning immich_server; do
  docker start "$c" >/dev/null 2>&1 || true
done

echo "==> A parar Duplicati..."
docker stop duplicati

echo "==> A limpar volumes Temporary na BD..."
python3 <<PY
import sqlite3
con = sqlite3.connect("$DB_JOB")
n = con.execute("SELECT COUNT(*) FROM Remotevolume WHERE State='Temporary'").fetchone()[0]
con.execute("DELETE FROM Remotevolume WHERE State='Temporary'")
con.commit()
con.execute("PRAGMA wal_checkpoint(TRUNCATE)")
con.commit()
print(f"   Removidos {n} registo(s) Temporary")
PY

rm -f "$LOCK"
docker start duplicati
echo "==> Feito. Atualize a UI e aguarde ~30s antes de Run now."
