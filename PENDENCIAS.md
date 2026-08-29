# Homelab — pendências

Só o que **ainda falta**. Quando concluir, apague o item ou marque `[x]`.

**Servidor:** VM Docker `192.168.3.21`  
**Atualizado:** 2026-08-29

---

## 1. UniFi — DNS da VLAN Hangar (Wi‑Fi PCs)

**Prioridade:** alta  
**Contexto:** Desde ~20/07/2026 a VLAN `192.168.68.0/24` deixou de usar o AdGuard (`192.168.3.21`). Domínios `*.antonio.rafael.nom.br` resolvem para Cloudflare em vez do NPM local.

**Onde:** UniFi → **Settings → WiFi → [SSID Hangar]** (ou **Networks → Hangar**) → **DHCP DNS Server**

**Decisão a tomar:**

- [ ] **Com filtro + split DNS:** DNS = `192.168.3.21`
- [ ] **Bypass (diagnóstico/convidados):** DNS = `8.8.8.8`, `8.8.4.4`

**Teste após alterar:** no PC na WLAN Hangar, `nslookup jellyfin.antonio.rafael.nom.br` deve devolver `192.168.3.21` se usar AdGuard.

**Doc:** `docs/ADGUARD-DNS-REMOTO.md` (secção «DNS por WLAN no UniFi»)

---

## 2. UniFi — Firewall para Home Assistant local

**Prioridade:** média (só se quiser acesso por IP na LAN, além do domínio via túnel)

**Contexto:** PCs em `192.168.68.x` não fazem ping a `192.168.3.10` (HA). HTTPS via `casa.antonio.rafael.nom.br` funciona via Cloudflare.

**Onde:** UniFi → **Settings → Security → Firewall Rules**

- [ ] Criar regra: **Computers (`192.168.68.0/24`) → HA (`192.168.3.10`)** — permitir TCP `8123` (e ICMP opcional)

---

## 3. AdGuard — Protecção global (decisão)

**Prioridade:** baixa (não afecta velocidade de internet; afecta bloqueio de anúncios/tracking)

**Contexto:** `protection_enabled: false` no AdGuard live — filtros carregados mas bloqueio desligado (provavelmente para não quebrar IoT: Tuya, Hikvision, Samsung).

- [ ] Manter desligado (resolver/cache só)
- [ ] Reativar protecção e testar dispositivos IoT um a um
- [ ] Ou activar por cliente/grupo no painel AdGuard em vez de global

---

## 4. Evidências para ISP (Trix) — após Grafana

**Prioridade:** média (quando internet voltar a falhar)

**Contexto:** Dashboard **Qualidade Internet** activo em `http://192.168.3.21:3005/d/internet-quality/qualidade-internet`

- [ ] Recolher 24–48 h de latência, perda, HTTP e DNS antes de abrir chamado
- [ ] Anotar horário exacto dos incidentes para cruzar com gráficos

---

## Já resolvido (referência)

| Item | Data |
|------|------|
| Quad9 DoH removido dos upstreams AdGuard (erros `unexpected EOF`) | 2026-08-04 |
| Stack monitoramento internet (ping/blackbox/speedtest + Grafana) | 2026-08-04 |
| Exportadores registados no container-ops + scrape speedtest 6h | 2026-08-29 |
| Commit Git (monitoramento, Vaultwarden, WUD, DNS) | 2026-08-29 |
| DNS do servidor NAS directo `8.8.8.8` / `8.8.4.4` (sem AdGuard) | 2026-08-03 |

---

## Arquivos úteis

| Arquivo | Uso |
|---------|-----|
| `/root/homelab/README.md` | Índice |
| `docs/SERVIDOR-HOMELAB.md` | Guia completo |
| `docs/ADGUARD-DNS-REMOTO.md` | DNS por WLAN, DoH remoto, split DNS |
| `docs/DUPLICATI-BACKUP.md` | Backup |
| `/opt/container-ops/GUIA.md` | Atualizar containers |
