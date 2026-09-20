# Homelab — pendências

Só o que **ainda falta**. Quando concluir, apague o item ou marque `[x]`.

**Servidor:** VM Docker `192.168.3.21`  
**Atualizado:** 2026-09-20 (relógio suíte toggle; aviso alexa_skill.yaml)

---

## 0. Recorder HA — limpeza do banco (MariaDB)

**Prioridade:** alta  
**Contexto (2026-09-20):** O sensor de presença do escritório (`escritorio_presenca_z2m_*` / legado `ld2410_escritorio_*`) gerou histórico em massa. Foi feita limpeza pontual (MariaDB + SQLite legado) e exclusão do recorder de `illuminance` / `dis_current` desse dispositivo. O banco continua ~1,6 GB com outros sensores ruidosos.

- [ ] Repetir o mesmo tipo de limpeza para **outros sensores** que incham o recorder (começar pelos top: `lavanderia_consumo_lavadoras_4x_*_timestamp_*`, corrente/potência/voltagem da geladeira Midea, `automation.pirata_cecilia_atualizar_tempo_restante`, system_monitor memória/CPU, etc.)
- [ ] Excluir do recorder (ou reduzir frequência) os que só precisam de valor ao vivo
- [ ] `recorder.purge` + **repack** MariaDB depois das exclusões
- [ ] Confirmar que o SQLite legado `home-assistant_v2.db` no share config não é mais usado (já limpo o LD2410 escritório; pode apagar/arquivar o ficheiro se confirmado)

---

## 1. HA — revisão de nomenclatura e vínculos por integração

**Prioridade:** alta (propor → aprovar → aplicar; idioma **PT-BR**)  
**Progresso:** **9 feitas / 54 faltam** (alta 9/18).  
**Documento:** `homeassistant/REVISAO-INTEGRACOES-NOMENCLATURA.md` · **Como continuar:** `docs/CONTINUAR.md` § Nomenclatura HA

- [x] `bthome` — títulos `Área - Termo-higrômetro` + device Quarto Cecília (2026-09-15)
- [x] `xiaomi_ble` — 3 entradas LYWSD03MMC duplicadas removidas (2026-09-15)
- [x] `tuya` — validado OK (2026-09-15)
- [x] `localtuya` — cosméticos (indicador alarme, LocalTuya, Antônio) (2026-09-15)
- [x] `localthings` — `Área - Ar-condicionado` + nomes PT-BR (2026-09-15)
- [x] `smartthings` — devices Cloud + nomes (2026-09-15)
- [x] `broadlink` — `Área - BroadLink` + `Controle remoto` / `Emissor IR` (2026-09-15)
- [x] `hikvision_axpro` — entrada Hub AX Pro + botões PT-BR (2026-09-15)
- [x] `ttlock` — Fechadura + Gateway Sistema (2026-09-15)
- [ ] **Seguinte (alta):** `tasmota` → `sonoff` → `esphome` → `mqtt` → `tapo_control` → `midea_ac_lan` → `unifi` → `alexa_media` → `inkbird_iht2pb`
- [ ] Reautenticar **Alexa Media Player** se ainda pedir login após restarts

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

## 5. HA — avisos de config (`alexa_skill.yaml`)

**Prioridade:** baixa  
**Contexto (2026-09-20):** `ha core check` / `check_config` passa, mas o YAML avisa chaves `description` duplicadas em `packages/alexa_skill/alexa_skill.yaml` (linhas ~379/381 e ~448/450). Cosmético / higiene YAML; não bloqueia o Core.

- [ ] Revisar e remover as chaves `description` duplicadas no skill Alexa

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
| UniFi DNAT porta 53 → AdGuard `.21` (VLANs clientes; exclui `.21`/`.22` desde 2026-09-19) | 2026-09-14 / 2026-09-19 |
| UniFi minimum rate 2,4 GHz: 284 amostras/48 h analisadas; manter **1 Mbps** devido a IoT fraco | 2026-09-15 |
| AdGuard VIP keepalived `.23` + DNAT failover (exclui `.20`/`.30`) | 2026-09-19 |
| Exaustor lavabo: ignore unavailable + watchdog | 2026-09-19 |
| Relógio suíte: brilho noite 0 / peek / dia 3 | 2026-09-20 |
| Tiles backup: datas `dd/mm/YYYY HH:MM` (`backup_ultimos_fmt.yaml`) | 2026-09-20 |
| Hangar Wi‑Fi: senha nova no Pi + UniFi; clientes a migrar | 2026-09-20 |
| Purge recorder presença escritório + exclude illuminance/dis_current | 2026-09-20 |
| Relógio suíte: duplo clique toggle; à noite auto-apaga aos 60 s | 2026-09-20 |

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
