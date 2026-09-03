# Homelab — pendências

Só o que **ainda falta**. Quando concluir, apague o item ou marque `[x]`.

**Servidor:** VM Docker `192.168.3.21`  
**Atualizado:** 2026-09-03

---

## 1. UniFi — Isolamento entre VLANs restantes (IoT / câmaras / etc.)

**Prioridade:** alta  
**Contexto:** Visitantes já isolados. IoT, câmaras, Hangar e Servidor ainda comunicam entre si (zona Internal).

- [x] Isolar câmaras (internas vs externas) — concluído (2026-09-03)
- [x] Isolar IoT (`Vlan_IoT`): bloquear IoT → VLANs internas (exceto Servidor/HA) (2026-09-03)
- [x] mDNS global: **manter ligado** — risco baixo em rede doméstica; isolamento já garantido por firewall (2026-09-03)

---

## 2. UniFi — Câmaras Tapo (internas vs externas)

**Prioridade:** alta (desenho acordado; aplicar depois)

**Objetivo:**

| Quem | App Tapo fora de casa | Home Assistant (local ou remoto) |
|------|------------------------|-----------------------------------|
| Câmaras **externas** | Ver (cloud Tapo / internet) | Ver |
| Câmaras **internas** | **Não** ver (sem internet) | Ver (via HA, inclusive remoto) |

**Como encaixa:**

- Remoto: acedes ao HA (`casa…` / Tailscale) → HA fala **localmente** com as câmaras → internas **não precisam** de internet.
- App Tapo na cloud só mostra o que tem caminho à internet → só externas.

**Pendências técnicas:**

- [x] Confirmar integração HA das Tapo em **Tapo: Cameras Control** (local) — 5 câmeras loaded (2026-09-03)
- [x] Instalar HACS `JurajNyiri/HomeAssistant-Tapo-Control` v7.1.25 + restart HA (2026-09-03)
- [x] Adicionar câmeras ativas no `tapo_control`: Cecília, Brinquedoteca, Portão, Garagem, **Suíte** (2026-09-03)
- [x] Desativar entradas oficiais `tplink` dessas câmeras (2026-09-03)
- [x] Atualizar dashboard Casa: PTZ `inclinar_*`/`panoramica_*` → `move_*` + previews `*_hd_stream` (2026-09-03)
- [x] Firmware Suíte (`update.camera_suite_update` 1.4.5 → 1.9.1) — concluído (2026-09-03)
- [x] Firewall `Vlan_CamerasInternas` (`192.168.5.0/27`): **bloquear WAN** (regra UniFi `Cameras Internas → Bloquear WAN`, 2026-09-03)
- [x] Interruptor HA + timer 60 min na dash Câmeras (`input_boolean.cameras_internas_internet_tapo`) (2026-09-03)
- [x] Firewall `Vlan_CamerasExternas` (`192.168.6.0/27`): **permitir internet** + **isolamento entre VLANs** (HA + AdGuard liberados) (2026-09-03)
- [x] DNS: câmeras internas e externas apontando para AdGuard `192.168.3.21` (2026-09-03)
- [x] Testar: internas offline no app Tapo fora de casa; PTZ + vídeo no HA remoto; interruptor 60 min — validado pelo utilizador (2026-09-03)

---

## 3. UniFi — AP Suíte a 100 Mbps

**Prioridade:** média  
**Contexto:** U7 Pro Suíte (`192.168.68.3`) com uplink **100 Mbps**; U7 Pro Escritório a **1 Gbps**. No UCG, **Port 2** está a 100 Mbps (candidato ao cabo da Suíte).

- [ ] Verificar cabo / porta / injector PoE da Suíte

---

## 4. UniFi — Firewall Hangar → HA (IP local)

**Prioridade:** — (nada a fazer)

**Contexto:** Verificado 2026-09-03: `Vlan_Hangar` e `Vlan_Servidor` estão ambas na zona Internal sem regra de BLOCK entre si — o Hangar **já alcança** `192.168.3.10`. Só voltar a este item se algum dia se isolar o Hangar.

- [x] Confirmado: Hangar já acede ao HA, sem regra necessária (2026-09-03)

---

## 5. AdGuard — Protecção global (decisão)

**Prioridade:** baixa

Estado 2026-09-03: Proteção **on**, Filtragem **on**, Log de consulta **on**, Navegação segura **on**.

- [x] Navegação segura activada (2026-09-03)
- [x] Pesquisa segura + Controlo dos pais: **não aplicar** (sem crianças) (2026-09-03)

---

## 6. Evidências para ISP (Trix) — após Grafana

**Prioridade:** média (quando internet voltar a falhar)

Retenção Prometheus: **365d** (tecto 40 GB) — antes eram 30d e já estava a apagar. ~45 MB/dia → ~17 GB/ano; disco tem 412 GB livres. Dashboard: Grafana → **Qualidade Internet** (`http://192.168.3.21:3005`).

- [x] Retenção alargada 30d → 365d para guardar histórico de incidentes (2026-09-03)
- [ ] Recolher 24–48 h no dashboard Qualidade Internet
- [ ] Anotar horários dos incidentes

---

## 7. Home Assistant — base de dados do recorder

**Prioridade:** média

**Diagnóstico 2026-09-03:** a base MariaDB estava em 6,4 GB com só ~10 dias de retenção. Sonda SQL temporária mediu **460 098 linhas em 6 h** (~1,8 M/dia). Três grupos faziam **82%**:

| Grupo | Linhas/6 h | Peso |
|-------|-----------|------|
| LD2410 escritório (energia por gate) | 246 439 | 54% |
| `sensor.forno_area_gourmet_leitura_chama_adc` | 100 237 | 22% |
| Gateway UniFi escritório (temp + CPU + memória) | 30 299 | 7% |

Causa do maior bloco: `switch.ld2410_escritorio_modo_engenharia` estava **ligado** — modo de calibração que faz o radar transmitir a energia dos 9 gates em contínuo.

- [x] LD2410 removido do HA (entrada ESPHome + proxy BT + `ld2410_ble`) — sensor vai sair fisicamente (2026-09-03)
- [x] `exclude` do ADC do forno no `recorder` (o útil é `binary_sensor.forno_area_gourmet_chama_acesa`) (2026-09-03)
- [ ] Purga `recorder.purge_entities` do LD2410/ADC — lançada, ~2–3 h em segundo plano
- [ ] `recorder.purge` com `repack: true` **depois da purga** — InnoDB não devolve espaço ao disco sem isto
- [ ] Decidir diagnósticos do gateway UniFi (7%): Prometheus **não** recolhe UniFi, excluir perde histórico de temp/CPU

> `configuration.yaml` do HA **não** é versionado neste repo — a alteração ao recorder vive só no HA.

---

## 8. Home Assistant — erros de log pré-existentes

**Prioridade:** baixa. Nenhum vem da atualização 2026.9.0.

- [x] **Templates `float` sem `default`** (2026-09-03) — ver detalhe abaixo
- [ ] `alexa_devices`: IDs únicos duplicados (`select.casa_arafaelsf_gmail_com_default_device`) — defeito da integração, nada a corrigir localmente
- [ ] `select.suite_toldo_z2m_motor_direction`: recebe `back`, válidos são `normal`/`reversed` — converter Z2M
- [~] `sensor.casa_agua_copasa_chuva_acumulada`: unidade `mm` inválida para `precipitation_intensity` — ver detalhe abaixo
- [ ] Integrações custom com `via_device` obsoleto (param sai no HA 2027.8): `hikvision_axpro`, `alexa_media`, `ttlock`, `solarman`
- [ ] Constantes obsoletas (também HA 2027.8): `sonoff`, `localtuya`, `alexa_media`
- [ ] `localtuya`: 2 dispositivos inalcançáveis (`Errno 113`) — "Unidade Celsius" `192.168.2.230` e "Umidificador Cecília" `192.168.2.51`, ambos na VLAN IoT
- [ ] `alexa_devices`: 5 dispositivos com *refresh* falhado (usa cache) — 2 Echo Dot + 3 FireStick

### 8.1 Templates corrigidos (2026-09-03)

**Sensação térmica cozinha / cozinha externa** (helpers de UI, entries `01KQCJA35P…` e `01KQCJAMGP…`): já protegiam com `is_number()`, mas devolviam a *string* literal `unknown`, que o validador de sensores numéricos rejeita. Passaram a devolver `{{ none }}`. Estado final continua `unknown`; não se usou `availability` para não trocar o estado por `unavailable` e afetar dashboards.

**`sensor.fake_feels_like`** — causa raiz diferente: `input_number.fake_temperature` e `input_number.fake_humidity` tinham sido **apagados**, deixando o pacote `packages/template/fake.yaml` a apontar para o vazio. O arnês de teste está em uso (todos os `input_boolean.fake_*` existem e `automation.lab_fake_luz_por_presenca_inteligente` está ativa), por isso os dois helpers foram **recriados** (−10..50 °C e 0..100%, valores 25/60) em vez de se apagar o pacote. Os três templates do `sensor:` foram ainda blindados com `is_number()` + `{{ none }}` para não voltarem a rebentar se os helpers desaparecerem. Aplicado com `template.reload`, `check_config` ok.

### 8.2 Sensor de chuva do ESPHome — correção parcial

`Chuva Acumulada` (dispositivo `agua-copasa`) reporta `mm` com `device_class: precipitation_intensity`, que exige `mm/h` ou `mm/d`. Sendo um **acumulado**, o correto é `precipitation` (aceita `mm`).

Feito: override *Show As* no registry para `precipitation` — o estado passa a expor a combinação válida.

A fazer (precisa do ESPHome Device Builder + flash OTA, inalcançável por MCP; os YAML do ESPHome **não** estão neste repo):
- [ ] `device_class: precipitation` no YAML do `agua-copasa`
- [ ] Avaliar `state_class: total_increasing` — hoje o sensor **não tem** `state_class`, logo não alimenta estatísticas de longo prazo
- [ ] Confirmar se o aviso de arranque desaparece; o override é de *display* e o HA pode validar contra o `original_device_class`

---

## 9. Hermes Agent — sem acesso ao HA (decisão: manter assim)

**Prioridade:** — (adiado por decisão do utilizador, 2026-09-03)

`HASS_TOKEN=` está **vazio** em `compose/hermes-agent/.env`, por isso as 4 ferramentas do HA (`ha_list_entities`, `ha_get_state`, `ha_list_services`, `ha_call_service`) ficam indisponíveis. `HASS_URL` está correcto.

**Decisão:** não dar acesso ao HA por agora. O Hermes funciona normalmente para o resto (Docker, Glances, backups, Telegram). Única perda: não consegue investigar falhas de backup reportadas pelo HA, como pede o `SOUL-homelab.md`.

Notas para quando/se se decidir avançar:
- `ha_call_service` dá **controlo** da casa, não só leitura; token *long-lived* herda as permissões de quem o cria e o HA não tem permissões por entidade
- Preferir utilizador HA dedicado **não-admin** (limita config/apps/updates, mas não impede controlar luzes/clima)
- O token fica em texto simples no `.env` (os outros segredos estão no Vaultwarden)
- Risco de exposição é baixo: `TELEGRAM_ALLOWED_USERS` tem 1 utilizador e há autorização em `gateway/authz_mixin.py`

- [ ] **Adiado** — criar token em Perfil → Segurança, preencher `HASS_TOKEN`, `ops.sh update hermes latest`

---

## Já resolvido (referência)

| Item | Data |
|------|------|
| HA Core `2026.8.3` → `2026.9.0` (backup `Pre-Core-2026.9.0` / `c1e90b9a`, 4,4 GB) | 2026-09-03 |
| Container `hermes-agent` actualizado via `container-ops` | 2026-09-03 |
| **Internet 2** desativada (`enabled=false`; UniFi não permite apagar — `attr_no_delete`) | 2026-09-03 |
| **Visitantes isolados** + exceção **DNS → AdGuard** (`192.168.3.21:53`); DNS guest = AdGuard | 2026-09-03 |
| SSID **Hangar Visitantes** → `Vlan_Visitantes` (`192.168.10.0/27`) | 2026-09-03 |
| DNS Hangar DHCP → AdGuard `192.168.3.21` (confirmado na auditoria) | 2026-09-03 |
| Quad9 DoH removido dos upstreams AdGuard | 2026-08-04 |
| Stack monitoramento internet + Grafana | 2026-08-04 |
| DNS do servidor NAS directo `8.8.8.8` / `8.8.4.4` | 2026-08-03 |

---

## Arquivos úteis

| Arquivo | Uso |
|---------|-----|
| `/root/homelab/README.md` | Índice |
| `docs/SERVIDOR-HOMELAB.md` | Guia completo |
| `docs/ADGUARD-DNS-REMOTO.md` | DNS / AdGuard |
| Canvas `unifi-auditoria-hangar` | Auditoria inicial UniFi |
