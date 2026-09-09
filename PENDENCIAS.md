# Homelab — pendências

Só o que **ainda falta**. Quando concluir, apague o item ou marque `[x]`.

**Servidor:** VM Docker `192.168.3.21`  
**Atualizado:** 2026-09-09 (noite — uplink APs)

---

## 1. UniFi — uplink AP a 100 Mbps (físico)

**Prioridade:** média  
**Estado actual (API 2026-09-09 ~19:48):**

| AP | IP | Porta UCG | Uplink |
|----|-----|-----------|--------|
| **U7 Pro Escritório** | `192.168.68.2` | porta **1** | **100 Mbps** ← problema agora |
| **U7 Pro Suíte** | `192.168.68.3` | porta **2** | **1 Gbps** ← ficou bom |

**Histórico:** antes o 100 Mbps era na **suíte**. Testes anteriores: cabo UCG↔injector, cabo injector↔AP (tester 8 pinos OK), troca dos PoE, troca das portas no UCG — o problema acompanhava o cabo/ponta da suíte.

**2026-09-09:** AP da suíte levado junto ao PoE e depois reposto. Resultado: suíte passou a **1 Gbps**; o **escritório** ficou a **100 Mbps**. O defeito **mudou de sítio** → reforça causa física (cabo/ponta/injector/troca ao remontar), não RF nem config UniFi.

**Hipóteses ao remontar:** pontas/injectores trocados entre os dois APs; APs trocados de sítio; ou ponta do escritório afrouxada.

**Não é configuração UniFi.** RF (canais, SSIDs) — ver `docs/UNIFI-RF.md`.

- [ ] No UCG, trocar só as fichas porta 1 ↔ 2 (ou só os dois injectores) e ver se os 100 Mbps seguem o cabo ou o AP
- [ ] Se seguirem o cabo: recrimpar / substituir esse lançamento (ou testar com cabo curto junto ao UCG)
- [ ] Se ficarem no mesmo AP após a troca: suspeitar da porta Ethernet desse U7
- [x] Teste “AP suíte junto ao PoE” feito (2026-09-09) — suíte recuperou 1G; problema passou ao escritório

---

## 1b. UniFi — min. rate 2.4 GHz (a monitorizar, **não mudar agora**)

**Prioridade:** baixa  
**Contexto:** 2.4 GHz separado (escritório 11 / suíte 6). Min. rate continua **1 Mbps**. Subir para 6 Mbps pode largar IoT fraco. A gravar snapshots a cada 10 min neste PC: `scripts/unifi-rf-study/`.

**Não aplicar** até haver uns dias de amostras e decisão explícita.

Candidatos a problema (leitura 2026-09-08):

- Risco alto: Tuya Indicador Alarme (−74), Sonoff Luz Brinquedoteca (−74)
- Risco médio: Sonoff Tomada Sala TV, portões Tuya, soldador/repelente oficina, Luz Cozinha, EspHome AC Cecília
- Rate baixo com sinal ok (provavelmente a dormir): Geladeira, Bancada Cozinha, Nebulosa, Kron QGD/Usina, Ventilador Jantar

- [ ] Deixar gravar **alguns dias** (`scripts/unifi-rf-study/data/clients.jsonl`)
- [ ] Analisar quem vive abaixo de 6 Mbps vs. quem só cochila
- [ ] Só então decidir se sobe o min. rate (SSID-wide; sem exclusão por aparelho)

---

## 2. Hermes Agent — acesso ao HA (adiado)

**Prioridade:** — (adiado por decisão do utilizador, 2026-09-03)

`HASS_TOKEN=` está **vazio** em `compose/hermes-agent/.env`. O Hermes funciona para o resto; não investiga falhas de backup reportadas pelo HA.

- [ ] **Adiado** — criar token em Perfil → Segurança, preencher `HASS_TOKEN`, `ops.sh update hermes latest`

---

## 3. AdGuard — failover DHCP (opcional)

**Prioridade:** baixa  
**Contexto:** 2.º AdGuard no Pi Zero (`192.168.3.22`, VLAN Servidor) já está de pé. O switch do HA espelha a protecção nos dois. DHCP das VLANs ainda aponta **só** para `192.168.3.21`.

**Não fazer:** meter `8.8.8.8` como secundário no DHCP UniFi.

- [x] 2.º AdGuard no Pi + UniFi VLAN Servidor `.22`
- [x] HA: `rest_command.adguard_backup_protection` + automação a espelhar `switch.adguard_home_protecao`
- [ ] Se quiseres failover automático: 2.º IP AdGuard no DHCP **ou** VIP — decidir depois
- [ ] Documentar o desenho em `docs/ADGUARD-DNS-REMOTO.md`

---

## 4. Inkbird IHT-2PB — ligação GATT instável

**Prioridade:** média  
**Contexto (2026-09-06):** Leituras passivas até vão; comandos/alvos falham (`No backend with an available connection slot` / `non-connectable history`). Proxies ESP esgotam slots GATT. Realtek USB na VM HA ajuda BTHome perto do servidor; o Inkbird (cozinha externa) continua a depender dos ESP.

- [ ] Estabilizar ligação GATT do IHT-2PB (slots nos proxies / rota preferencial)
- [ ] Confirmar setpoints (alvos) a aplicar de forma fiável a partir do HA

---

## 5. Pirata Cecília + Last Alexa (Alexa Devices)

**Prioridade:** alta (validar em uso real)  
**Contexto (2026-09-07):** Migrámos o Last Called para `sensor.alexa_devices_last_called` (`event.*_voice_event`), com fallback AMP. Snapshot git: `homeassistant/snapshots/pre-alexa-last-called_20260907_104420/`. Commit `72115d3`.

- [ ] Recarregar integração **Alexa Devices** se `event.*_voice_event` estiver `unavailable`
- [ ] Confirmar `sensor.alexa_devices_last_called` com `echo_amigavel` após falar num Echo
- [ ] Rotina Alexa **Teste Last Alexa** — deve anunciar o Echo certo e `via alexa_devices`
- [ ] **Validar Pirata Cecília** (consultar / pausar / continuar / lembrete) no Echo correcto
- [ ] Se ok estável: reduzir dependência do poll AMP nos scripts do Pirata

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
| Contador luzes: excluir 4 noturnas à noite + badge/dash + reconcile blueprint horário | 2026-09-07 |
| Timeout wait botões notificação baterias (1 h) | 2026-09-07 |
| Docker: UniFi MCP + Dozzle + Hermes actualizados | 2026-09-07 |
| Duplicati hooks restaurados (compose monta `scripts/duplicati-hooks`) | 2026-09-07 |
| Evidências ISP (Trix): dashboard + retenção 90d + pacote em `docs/evidencias-isp-trix-20260907/` — reanalisar sob pedido | 2026-09-07 |
| Dash Servidor: Sonoff HomeLab, Tasmota backup visível (ainda não ligado), temp CPU MiniPC via Proxmox | 2026-09-07 |
| Updates Docker a partir do HA (`ops.sh` + listener `:8787`); Firefly e Influx cadastrados | 2026-09-07 |
| AdGuard backup Pi `.22` + botão HA a filtrar nos dois | 2026-09-08 |
| UniFi RF: 2.4 ch 11/6, Zigbee 11, 6 GHz 160, Aeron off, Visitantes só 5 GHz | 2026-09-08 |
| Teste AP suíte junto ao PoE: suíte a 1G; 100 Mbps passou ao escritório | 2026-09-09 |

---

## Arquivos úteis

| Arquivo | Uso |
|---------|-----|
| `/root/homelab/README.md` | Índice |
| `docs/SERVIDOR-HOMELAB.md` | Guia completo |
| `docs/ADGUARD-DNS-REMOTO.md` | DNS / AdGuard |
| `homeassistant/snapshots/pre-alexa-last-called_20260907_104420/` | Rollback pré–Last Alexa |
| `docs/CONTINUAR.md` | Como retomar noutro computador |
| `docs/UNIFI-RF.md` | Canais Wi-Fi × Zigbee, o que não mexer, estudo min. rate |
