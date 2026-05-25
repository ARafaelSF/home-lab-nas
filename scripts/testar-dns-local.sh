#!/bin/bash
# Rode este script NO NOTEBOOK (Linux/macOS) ou use os comandos Windows abaixo.
# Verifica se os domínios resolvem para o servidor local (192.168.3.21) ou Cloudflare.

LOCAL_IP="192.168.3.21"
ADGUARD_IP="192.168.3.21"
DOMAINS=(
  homeassistant.antonio.rafael.nom.br
  fotos.antonio.rafael.nom.br
  filebrowser.antonio.rafael.nom.br
  home-server-nas.antonio.rafael.nom.br
)

echo "=============================================="
echo "  Teste DNS — rede local vs bypass"
echo "=============================================="
echo

echo "1) Qual DNS o sistema está usando agora:"
if command -v resolvectl >/dev/null 2>&1; then
  resolvectl status | head -20
elif [ -f /etc/resolv.conf ]; then
  cat /etc/resolv.conf
fi
echo

echo "2) Resolução dos domínios (DNS padrão do notebook):"
for d in "${DOMAINS[@]}"; do
  ip=$(dig +short "$d" A 2>/dev/null | head -1)
  if [ -z "$ip" ]; then
    ip=$(getent hosts "$d" 2>/dev/null | awk '{print $1}')
  fi
  if [ "$ip" = "$LOCAL_IP" ]; then
    status="OK — LOCAL (passa pelo NPM em casa)"
  elif echo "$ip" | grep -qE '^(104\.|172\.6[4-7]\.)'; then
    status="CLOUDFLARE — DNS bypass (não usa AdGuard local)"
  else
    status="OUTRO: $ip"
  fi
  printf "  %-40s -> %-15s  %s\n" "$d" "${ip:-?}" "$status"
done
echo

echo "3) Resolução forçando AdGuard (@${ADGUARD_IP}):"
for d in "${DOMAINS[@]}"; do
  ip=$(dig +short "@${ADGUARD_IP}" "$d" A 2>/dev/null | head -1)
  printf "  %-40s -> %s\n" "$d" "${ip:-falhou}"
done
echo

echo "4) Teste HTTPS — de onde o servidor responde (cabeçalho X-Served-By do NPM):"
for d in homeassistant.antonio.rafael.nom.br fotos.antonio.rafael.nom.br; do
  served=$(curl -skI --max-time 5 "https://${d}/" 2>/dev/null | grep -i "x-served-by" | tr -d '\r')
  if [ -n "$served" ]; then
    echo "  $d: $served  (passou pelo NPM local)"
  else
    code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 5 "https://${d}/" 2>/dev/null)
    echo "  $d: sem X-Served-By, HTTP $code (pode ser Cloudflare direto)"
  fi
done
echo
echo "=============================================="
echo "  Resumo"
echo "  LOCAL  = IP ${LOCAL_IP} → você está na rede local correta"
echo "  CLOUDFLARE = IPs 104.x / 172.x → DNS não é o AdGuard"
echo "=============================================="
