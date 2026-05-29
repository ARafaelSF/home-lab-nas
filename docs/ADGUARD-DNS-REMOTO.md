# AdGuard — DNS no celular (4G / fora de casa)

**Implementação activa:** opção B (DoH via Cloudflare), concluída em 2026-05-25.  
**Correcção DoH (insecure):** 2026-05-29 — `http.doh.insecure_enabled: true` (ver abaixo).  
**Guia completo do servidor:** `SERVIDOR-HOMELAB.md`.

---

## Arquitectura de hostnames

| Hostname | Função | Cloudflare Access |
|----------|--------|-------------------|
| `adguard.antonio.rafael.nom.br` | Painel admin AdGuard | Opcional (recomendado) |
| `dns.antonio.rafael.nom.br` | DoH `/dns-query` apenas | **Não** (sem login interactivo) |

- **LAN / Intra:** URL DoH `https://dns.antonio.rafael.nom.br/dns-query`
- **Túnel (ambos):** origem `http://192.168.3.21:8080` (não `https://443` no hostname `dns`)

Snippet versionado: `config/adguard/AdGuardHome.http-doh.example.yaml`

---

## Comportamento actual

| Onde está | DNS | `jellyfin.antonio.rafael.nom.br` |
|-----------|-----|----------------------------------|
| **Casa / VPN `192.168.x`** | AdGuard `192.168.3.21` | `192.168.3.21` (NPM local) |
| **4G com DNS privado** `dns.antonio...` | DoH via Cloudflare → AdGuard | IP Cloudflare (túnel) |

---

## Por que o painel «Criptografia» do AdGuard fica desligado

Com **Cloudflare Tunnel** + **NPM** não é preciso activar HTTPS no AdGuard:

| Camada | Certificado |
|--------|-------------|
| Telemóvel ↔ Internet | Cloudflare |
| Túnel `dns` → NPM | NPM wildcard (`https://192.168.3.21:443`, noTLSVerify no cloudflared) |
| NPM → AdGuard | HTTP `:8080` |
| Túnel `adguard` | HTTP directo `:8080` |

No AdGuard:

- **Ativar criptografia** → desligado
- **DNS simples** → ligado (porta 53 na LAN)
- DoH em `:8080` com `http.doh.insecure_enabled: true` no YAML

---

## Configuração no servidor

### 1. AdGuard (`AdGuardHome.yaml` no volume `adguard-home_adguard_conf`)

- `filtering.rewrites` globais para `*.antonio.rafael.nom.br` → **disabled**
- `user_rules` com `$client=192.168.0.0/16` — ver `config/adguard/split-dns-user-rules.example.txt`
- `tls.enabled: false` (painel «Criptografia» desligado)
- `http.doh.insecure_enabled: true` — copiar de `config/adguard/AdGuardHome.http-doh.example.yaml`
- `trusted_proxies`: `172.16.0.0/12`, `192.168.0.0/16` (e redes Docker se necessário)

### Incidente: DoH externo em 404 (2026-05-29)

**Sintoma:** `https://dns.antonio.rafael.nom.br/dns-query` não funcionava; localmente `http://127.0.0.1:8080/dns-query` devolvia **404**.

**Causa:** No YAML live, `tls.enabled` estava `false` e `http.doh.insecure_enabled` estava `false`. Com túnel Cloudflare (HTTPS público → HTTP interno `:8080`), o AdGuard só expõe `/dns-query` em modo «inseguro» interno quando `insecure_enabled: true`.

**Correcção aplicada:**

```yaml
http:
  doh:
    insecure_enabled: true   # era false
```

Reinício: `docker restart adguardhome`

**Rollback:** repor `insecure_enabled: false`, reiniciar o container — DoH deixa de responder em HTTP (comportamento anterior).

### 2. NPM — proxy host id 13

| Campo | Valor |
|-------|--------|
| Domain | `dns.antonio.rafael.nom.br` |
| Forward | `192.168.3.21:8080` |
| SSL | wildcard `*.antonio.rafael.nom.br` |

### 3. Cloudflare Zero Trust — Public Hostnames

| Hostname | Service URL | Extra |
|----------|-------------|--------|
| `adguard.antonio.rafael.nom.br` | `http://192.168.3.21:8080` | — |
| `dns.antonio.rafael.nom.br` | **`http://192.168.3.21:8080`** | — |

> **Importante (Intra / 4G):** Não usar `https://192.168.3.21:443` para `dns`. O cloudflared liga ao IP sem SNI TLS; o NPM responde `tls: unrecognized name` e o DoH falha no 4G. No Wi‑Fi funciona porque o telemóvel resolve `dns.antonio...` → `192.168.3.21` e faz TLS com o hostname correcto.

Se quiser manter `https://443`, no painel Cloudflare (Additional settings → TLS) defina **HTTP Host Header** e **Origin Server Name** = `dns.antonio.rafael.nom.br` + No TLS Verify. Mais simples: `http://8080` como o `adguard`.

---

## Celular

**Android 9+** — Definições → Rede → DNS privado:

```text
dns.antonio.rafael.nom.br
```

**iPhone / Intra** — URL DoH:

```text
https://dns.antonio.rafael.nom.br/dns-query
```

**Teste 4G:** Jellyfin e outros `.antonio.rafael.nom.br` abrem; consultas no painel AdGuard.

### Intra no 4G falha, no Wi‑Fi OK?

| Rede | O que acontece |
|------|----------------|
| **Wi‑Fi** | `dns.antonio...` resolve para `192.168.3.21` → telemóvel fala TLS directo com NPM → OK |
| **4G** | Resolve para Cloudflare → túnel → `https://192.168.3.21:443` **sem SNI** → NPM rejeita → Intra falha |

**Correcção na Cloudflare:** rota `dns` → `http://192.168.3.21:8080` (igual `adguard`). Reinicie não é preciso; o túnel actualiza em ~1 min.

**Workaround no Intra (até mudar a rota):** URL DoH:

```text
https://adguard.antonio.rafael.nom.br/dns-query
```

Ver erros no servidor: `docker logs cloudflared 2>&1 | tail -20` → `tls: unrecognized name` na rota `dns`.

---

## Testes

```bash
# No servidor (suite completa)
/root/homelab/scripts/testar-dns-remoto.sh
/root/homelab/scripts/testar-dns-local.sh
```

### Validação DoH (manual)

Pedido **sem** payload DNS — endpoint activo, corpo inválido:

```bash
curl -i "http://127.0.0.1:8080/dns-query"
curl -i "https://dns.antonio.rafael.nom.br/dns-query"
# Esperado: HTTP 400 Bad Request (não 404)
```

Pedido **com** payload DoH (`www.example.com` A):

```bash
curl -sS -o /dev/null -w "%{http_code}\n" \
  -H "accept: application/dns-message" \
  "https://dns.antonio.rafael.nom.br/dns-query?dns=AAABAAABAAAAAAAAA3d3dwdleGFtcGxlA2NvbQAAAQAB"
# Esperado: 200
```

| Resultado esperado | Significado |
|--------------------|-------------|
| LAN → `192.168.3.21` | Split DNS local OK |
| Container Docker → IP Cloudflare | Simula 4G OK |
| DoH local/remoto **sem** payload → **400** | `/dns-query` activo (404 = `insecure_enabled` ainda false) |
| DoH **com** `?dns=...` + header `accept: application/dns-message` → **200** | DoH funcional de ponta a ponta |
| `curl -sk https://dns.antonio.../` → 302/400 | Túnel + origem HTTP OK |

---

## Opção A — VPN (alternativa não usada)

WireGuard no UniFi/Proxmox; DNS `192.168.3.21` com VPN ligada. Não precisa de hostname `dns` na Cloudflare. Ver secção histórica em commits anteriores se quiser migrar.

---

## O que NÃO fazer

| Método | Motivo |
|--------|--------|
| Abrir porta 53 no router | Abuso, CGNAT |
| Rewrite global sem `$client` | Quebra domínios no 4G |
| Activar criptografia no AdGuard com túnel | Redundante; complica certificados |
