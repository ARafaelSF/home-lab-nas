# Homelab — pendências

Só o que **ainda falta**. Quando concluir, apague o item ou marque `[x]`.

**Servidor:** VM Docker `192.168.3.21`  
**Atualizado:** 2026-09-14 (AdGuard failover DHCP documentado)

---

## 0. HA — revisão de nomenclatura e vínculos por integração

**Prioridade:** alta (trabalho em série, uma integração de cada vez)  
**Contexto (2026-09-13):** Inventário de **63** domínios / **228** entradas. Padrão de referência = **BTHome** (`Área - Tipo` no device; entidade com tipo curto; auxiliares como sensação térmica **vinculados** ao device-fonte).

**Documento completo:** `homeassistant/REVISAO-INTEGRACOES-NOMENCLATURA.md`  
**Dados brutos:** `homeassistant/integracoes-revisao-nomenclatura.json`

- [ ] Percorrer a lista **integração a integração** (sem alterações em lote)
- [ ] Por cada uma: nomenclatura Área+Tipo + vínculos/organização
- [ ] Começar pelas prioridade **alta** (físicos): `bthome` (validar), `xiaomi_ble` (limpar duplicados), `mqtt`/`esphome`/`sonoff`/`tasmota`/`localtuya`/`tapo_control`/…
- [ ] Reautenticar **Alexa Media Player** se ainda pedir login (efeito dos restarts, não perda de config)

---

## 1. UniFi — min. rate 2.4 GHz (a monitorizar, **não mudar agora**)

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

## 3. Inkbird IHT-2PB — ligação GATT instável

**Prioridade:** média  
**Contexto (2026-09-06):** Leituras passivas até vão; comandos/alvos falham (`No backend with an available connection slot` / `non-connectable history`). Proxies ESP esgotam slots GATT. Realtek USB na VM HA ajuda BTHome perto do servidor; o Inkbird (cozinha externa) continua a depender dos ESP.

- [ ] Estabilizar ligação GATT do IHT-2PB (slots nos proxies / rota preferencial)
- [ ] Confirmar setpoints (alvos) a aplicar de forma fiável a partir do HA

---

## 4. Pirata Cecília + Last Alexa (Alexa Devices)

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
| UniFi uplink APs: Escritório + Suíte a **1 Gbps** (API confirmou; removido das pendências) | 2026-09-14 |
| AdGuard failover DHCP (`.21`+`.22`) + doc em `docs/ADGUARD-DNS-REMOTO.md` | 2026-09-14 |

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
| `homeassistant/REVISAO-INTEGRACOES-NOMENCLATURA.md` | Checklist nomenclatura/vínculos por integração |
| `homeassistant/integracoes-revisao-nomenclatura.json` | Inventário bruto (2026-09-13) |
