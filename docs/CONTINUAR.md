# Continuar noutro computador

Repo: `git@github.com-home-lab-nas:ARafaelSF/home-lab-nas.git`  
Branch: `main`  
Servidor Docker: `192.168.3.21` (`/root/homelab`)

## Regra de ouro (para não “desaparecer” nada)

| O quê | Onde vive | Notas |
|--------|-----------|--------|
| **Código** (scripts, compose, docs) | Git em `/root/homelab` | Única fonte. `git pull` no servidor chega. |
| **Dados / segredos** | `/opt/container-ops/*.env`, `backups/`, `logs/` | **Fora do git.** Nunca apagar `/opt` nem fazer `ln -sfn` do repo em cima. |
| **Home Assistant** | `/mnt/ha-config` na VM | **Fora deste git.** |
| **Unidades systemd / rotas / DNS** | `/etc/...` no host | Instaladas por `scripts/install-host.sh` a partir do git. |

**Não copies** `ops.sh` / listener / `apps.conf` para `/opt`. O HA e o systemd já apontam para o git.

## Checklist ao abrir noutro PC

1. `git pull` **no servidor** (`192.168.3.21:/root/homelab`) — ou SSH e puxa lá. O Cursor noutro PC só vê o clone local; o que corre em produção é o repo **no servidor**.
2. Se alteraste systemd, rotas ou DNS no git:
   ```bash
   ssh root@192.168.3.21 '/root/homelab/scripts/install-host.sh'
   ```
3. Se só alteraste `ops.sh` / `apps.conf` / compose: **nada a instalar** — o próximo update já usa o ficheiro do git.
4. Pendências: `PENDENCIAS.md`.
5. Abrir o Cursor na pasta do clone; para mudanças no host, trabalhar via SSH no `192.168.3.21` (ou Remote-SSH).

## Comandos do dia a dia (sempre no servidor)

```bash
/root/homelab/scripts/container-ops/ops.sh list
/root/homelab/scripts/container-ops/ops.sh update hermes latest
/root/homelab/scripts/container-ops/ops.sh update all
/root/homelab/scripts/install-host.sh   # só quando mudaste units/rotas/DNS
```

O wrapper `/opt/container-ops/ops.sh` ainda funciona (só redireciona para o git).

## Já aplicado em produção (não reinstalar à mão)

| O quê | Onde |
|--------|------|
| Listener updates Docker pelo HA (`:8787`) | systemd → **git** + token em `/opt/container-ops/ha-update.env` |
| Temp MiniPC MQTT a cada 30 s | timer → **git** `scripts/minipc-temp/` + `/opt/container-ops/minipc-temp.env` |
| Sync AdGuard → Pi | timer → **git** `scripts/adguard-sync/` |
| Rota Hangar `192.168.68.0/24` | `/etc/network/if-up.d/route-lan68` (via `install-host.sh`) |
| DNS do host NAS | `/etc/systemd/resolved.conf.d/homelab-dns.conf` |

## Segredos (não estão no git)

- Compose: cada `compose/*/.env`
- MQTT temp: `/opt/container-ops/minipc-temp.env`
- Token do listener Docker: `/opt/container-ops/ha-update.env`
- Token HA: variável `HA_TOKEN` / ficheiro fora do repo

## Rede Wi-Fi / RF

Canais já aplicados — ver `docs/UNIFI-RF.md`. Por agora **não mexer mais em RF**. Uplinks Escritório+Suíte a 1G. Min. rate 2,4 GHz mantido em **1 Mbps** (decisão 2026-09-15).

---

## Continuar: nomenclatura HA (parado 2026-09-15 à noite)

**Repos:** `home-lab-nas` + alterações **já aplicadas ao vivo** na VM HA (`192.168.3.10`, Proxmox VM 101).  
**Espelho HA (YAML/packages):** `git@github.com-homeassistant:ARafaelSF/HomeAssistant.git` em `/root/ha-github` no servidor.

### Estado

| | |
|--|--|
| Feitas | 9 — `bthome`, `xiaomi_ble`, `tuya`, `localtuya`, `localthings`, `smartthings`, `broadlink`, `hikvision_axpro`, `ttlock` |
| Faltam | 54 (alta: 9 · média: 8 · baixa: 37) |
| Próximas altas | `tasmota` → `sonoff` → `esphome` → `mqtt` → `tapo_control` → `midea_ac_lan` → `unifi` → `alexa_media` → `inkbird_iht2pb` |

### Regras (aprovadas)

- Device: `Área - Tipo`; entidade: só a função (`Temperatura`, `Bateria`…).
- **IDs:** preservar se coerentes; sufixo `_localthings` / `_cloud` só para fontes paralelas.
- Idioma: **PT-BR** (`controle`, não `controlo`).
- Fluxo: **propor tabela → utilizador aprova → só então aplicar** (pode agrupar 2 simples).
- Acesso live: `ssh proxmox` → `qm guest exec 101 …`; editar `.storage` com Core parado (`ha core stop`), Python via `docker run … python:3.12-alpine` em `/mnt/data/supervisor/homeassistant`, depois `ha core start`. Backup em `/mnt/data/supervisor/tmp/*.bak.*`.
- **Lovelace em modo storage** (`.storage/lovelace.*`): o Core lê o ficheiro uma única vez e mantém a config em memória. Editar por Samba com o Core a correr não tem efeito nenhum no frontend (nem com refresh) — é obrigatório `ha core stop` → editar → `ha core start`.

### Também feito nesta sessão (já em produção)

- UniFi DNAT DNS → AdGuard; min. rate 1 Mbps aceite; dash Grafana “Dispositivos offline” Flux otimizado.
- Cards internos Suíte / Sala de TV / Escritório: gráficos de temp/umidade passam a incluir **BTHome Ambiente** (+ AC + sensação). Lovace live na VM (não está no git YAML).

### Ao retomar

1. `git pull` em `192.168.3.21:/root/homelab` (e `/root/ha-github` se for packages).
2. Ler `PENDENCIAS.md` §0 + `homeassistant/REVISAO-INTEGRACOES-NOMENCLATURA.md`.
3. Inventariar a próxima integração no storage live; **mostrar proposta**; esperar aprovação.
