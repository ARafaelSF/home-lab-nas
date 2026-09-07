# Homelab — pendências

Só o que **ainda falta**. Quando concluir, apague o item ou marque `[x]`.

**Servidor:** VM Docker `192.168.3.21`  
**Atualizado:** 2026-09-06

---

## 1. UniFi — AP Suíte a 100 Mbps

**Prioridade:** média  
**Contexto:** U7 Pro Suíte (`192.168.68.3`) com uplink **100 Mbps**; U7 Pro Escritório a **1 Gbps**. No UCG, **Port 2** está a 100 Mbps (candidato ao cabo da Suíte). Cabo trocado 2026-09-06; UniFi **continua a 100 Mbps**.

- [ ] Verificar outra ponta / porta do AP / Port 2 do UCG / injector PoE

---

## 2. Evidências para ISP (Trix) — Grafana

**Prioridade:** média (quando internet voltar a falhar)

Retenção Prometheus: **365d**. Dashboard: Grafana → **Qualidade Internet** (`http://192.168.3.21:3005`).

- [ ] Recolher 24–48 h no dashboard Qualidade Internet
- [ ] Anotar horários dos incidentes

---

## 3. Hermes Agent — acesso ao HA (adiado)

**Prioridade:** — (adiado por decisão do utilizador, 2026-09-03)

`HASS_TOKEN=` está **vazio** em `compose/hermes-agent/.env`. O Hermes funciona para o resto; não investiga falhas de backup reportadas pelo HA.

- [ ] **Adiado** — criar token em Perfil → Segurança, preencher `HASS_TOKEN`, `ops.sh update hermes latest`

---

## 4. AdGuard — redundância se o DNS cair

**Prioridade:** média (quando houver tempo)  
**Contexto:** DHCP das VLANs aponta **só** para AdGuard `192.168.3.21`. Se o AdGuard cair, a casa fica sem DNS.

**Não fazer:** meter `8.8.8.8` (ou outro DNS público) como secundário no DHCP UniFi.

- [ ] Manter DHCP **só** com AdGuard + confirmar watchdog/alerta estáveis
- [ ] Avaliar **2.º AdGuard** (UCG, outra VM, ou 2.º contentor) com a **mesma config**
- [ ] Decidir failover: **IP flutuante (VIP)** *ou* 2.º IP interno AdGuard no DHCP
- [ ] Documentar o desenho em `docs/ADGUARD-DNS-REMOTO.md`

---

## 5. Inkbird IHT-2PB — ligação GATT instável

**Prioridade:** média  
**Contexto (2026-09-06):** Leituras passivas até vão; comandos/alvos falham (`No backend with an available connection slot` / `non-connectable history`). Proxies ESP esgotam slots GATT. Realtek USB na VM HA ajuda BTHome perto do servidor; o Inkbird (cozinha externa) continua a depender dos ESP.

- [ ] Estabilizar ligação GATT do IHT-2PB (slots nos proxies / rota preferencial)
- [ ] Confirmar setpoints (alvos) a aplicar de forma fiável a partir do HA

---

## Já resolvido / aceite (referência recente)

| Item | Data |
|------|------|
| UniFi isolamento VLANs (IoT / câmaras / visitantes) | 2026-09-03 |
| Câmaras Tapo (HA local, firewall internas sem WAN, dash) | 2026-09-03 |
| Hangar → HA (já alcança; sem regra extra) | 2026-09-03 |
| AdGuard protecção / navegação segura | 2026-09-03 |
| Recorder HA: purga + repack (~6,4 GB → ~1 GB) | 2026-09-03 |
| HA logs (templates, toldo, chuva, LocalTuya IPs, avisos HACS aceites) | 2026-09-06 |
| Realtek BT passthrough Proxmox VM 101 + rotas BTHome escritório/sala jantar | 2026-09-06 |
| Planilha dispositivos: SSID Aeron, Câmera Suíte, alinhamento | 2026-09-06 |
| `alexa_devices` refresh / cache — **aceite**; manter HACS (`alexa_media`) por actionable notification até a oficial cobrir | 2026-09-06 |

---

## Arquivos úteis

| Arquivo | Uso |
|---------|-----|
| `/root/homelab/README.md` | Índice |
| `docs/SERVIDOR-HOMELAB.md` | Guia completo |
| `docs/ADGUARD-DNS-REMOTO.md` | DNS / AdGuard |
