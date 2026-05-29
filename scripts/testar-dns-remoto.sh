#!/bin/bash
# Testa split DNS AdGuard: LAN (192.168.x) vs remoto simulado + DoH.
set -euo pipefail

ADGUARD="192.168.3.21"
DOMAIN="jellyfin.antonio.rafael.nom.br"
DNS_HOST="dns.antonio.rafael.nom.br"
# Consulta DNS wire (www.example.com A) em base64url para DoH GET
DOH_QUERY_B64="AAABAAABAAAAAAAAA3d3dwdleGFtcGxlA2NvbQAAAQAB"

echo "=== Teste DNS remoto / local ==="
echo

echo "1) AdGuard responde na porta 53?"
if docker run --rm --network host busybox nslookup google.com "$ADGUARD" >/dev/null 2>&1; then
  echo "   OK"
else
  echo "   FALHOU"
fi

echo
echo "2) Split DNS — consulta via AdGuard ($DOMAIN):"
LAN_IP=$(docker run --rm --network host busybox nslookup "$DOMAIN" "$ADGUARD" 2>/dev/null | awk '/^Address: / && !/53$/ {print $2; exit}')
echo "   Resposta: ${LAN_IP:-?}"
if [ "$LAN_IP" = "$ADGUARD" ]; then
  echo "   OK — rede local (192.168.x) → NPM em $ADGUARD"
else
  echo "   AVISO — esperado $ADGUARD para clientes 192.168.0.0/16"
fi

echo
echo "3) Simula cliente fora (container Docker):"
REMOTE_IP=$(docker run --rm busybox nslookup "$DOMAIN" "$ADGUARD" 2>/dev/null | awk '/^Address: / && !/53$/ {print $2; exit}')
echo "   Resposta: ${REMOTE_IP:-?}"
if echo "$REMOTE_IP" | grep -qE '^(104\.|172\.6[0-9])'; then
  echo "   OK — fora da LAN → Cloudflare (sem rewrite local)"
else
  echo "   AVISO — esperado IP Cloudflare 104.x ou 172.x"
fi

echo
echo "4) DoH local sem payload (http://${ADGUARD}:8080/dns-query):"
CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${ADGUARD}:8080/dns-query" || echo "000")
if [ "$CODE" = "400" ]; then
  echo "   HTTP $CODE — OK (endpoint activo; 404 = insecure_enabled false)"
elif [ "$CODE" = "404" ]; then
  echo "   HTTP $CODE — FALHOU (activar http.doh.insecure_enabled no YAML e reiniciar adguardhome)"
else
  echo "   HTTP $CODE — verificar AdGuard / túnel"
fi

echo
echo "5) DoH público sem payload (https://${DNS_HOST}/dns-query):"
CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://${DNS_HOST}/dns-query" 2>/dev/null || echo "000")
if [ "$CODE" = "400" ]; then
  echo "   HTTP $CODE — OK"
elif [ "$CODE" = "404" ]; then
  echo "   HTTP $CODE — FALHOU (YAML insecure_enabled ou rota CF para http://8080)"
else
  echo "   HTTP $CODE — verificar Cloudflare Tunnel"
fi

echo
echo "6) DoH público com payload (esperado 200):"
CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
  -H "accept: application/dns-message" \
  "https://${DNS_HOST}/dns-query?dns=${DOH_QUERY_B64}" 2>/dev/null || echo "000")
if [ "$CODE" = "200" ]; then
  echo "   HTTP $CODE — OK"
else
  echo "   HTTP $CODE — FALHOU (DoH não resolve consultas)"
fi

echo
echo "7) Túnel HTTPS — raiz $DNS_HOST:"
CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://${DNS_HOST}/" 2>/dev/null || echo "000")
echo "   HTTPS $CODE (302/400/502 — ver nota abaixo)"

echo
echo "8) UI AdGuard no túnel:"
CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://adguard.${DOMAIN#*.}" 2>/dev/null || echo "000")
echo "   https://adguard... → HTTP $CODE"

echo
echo "=============================================="
echo "No CELULAR (4G, Wi-Fi desligado):"
echo "  • DNS privado / Intra: $DNS_HOST"
echo "  • DoH URL: https://${DNS_HOST}/dns-query"
echo "  • Abrir https://$DOMAIN → deve carregar"
echo ""
echo "Se passo 5/6 falharem: na Cloudflare use"
echo "  http://192.168.3.21:8080  (não https://443)"
echo "  E no YAML: http.doh.insecure_enabled: true"
echo "=============================================="
