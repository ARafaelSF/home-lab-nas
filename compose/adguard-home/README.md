# AdGuard Home

DNS LAN (53) + UI/DoH na porta **8080** do host (`8080:80` no compose).

## DoH atrás do Cloudflare Tunnel

| Hostname público | Função |
|------------------|--------|
| `adguard.antonio.rafael.nom.br` | Painel admin (pode ter Cloudflare Access) |
| `dns.antonio.rafael.nom.br` | Endpoint DoH `/dns-query` (sem Access interativo) |

No volume `adguard_conf`, em `AdGuardHome.yaml`:

- `tls.enabled: false` (criptografia no painel AdGuard desligada)
- `http.doh.insecure_enabled: true` — ver `config/adguard/AdGuardHome.http-doh.example.yaml`

Depois de alterar o YAML: `docker restart adguardhome`

Documentação e testes: `docs/ADGUARD-DNS-REMOTO.md`, `scripts/testar-dns-remoto.sh`
