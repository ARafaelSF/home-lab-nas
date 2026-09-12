#!/bin/sh
set -eu
cd /app
echo "[estoque-api] prisma migrate deploy..."
npx prisma migrate deploy
echo "[estoque-api] seed admin (só se a base estiver vazia)..."
node /app/seed-admin.cjs
echo "[estoque-api] a arrancar..."
exec node dist/server.js
