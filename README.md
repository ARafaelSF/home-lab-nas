# home-lab-nas

Homelab Docker — documentação e infraestrutura para reconstruir a VM NAS/homelab.

Repositório: [github.com/ARafaelSF/home-lab-nas](https://github.com/ARafaelSF/home-lab-nas)

---

## Atualizar containers (uso diário)

No servidor Docker (`192.168.3.21`), use o script **`container-ops`**:

```text
/opt/container-ops/ops.sh          ← no servidor (cópia activa)
homelab/scripts/container-ops/     ← código-fonte neste repositório
```

Depois de um `git pull`, sincronize a cópia activa:

```bash
cp /root/homelab/scripts/container-ops/ops.sh /opt/container-ops/ops.sh
cp /root/homelab/scripts/container-ops/apps.conf /opt/container-ops/apps.conf
cp /root/homelab/scripts/container-ops/GUIA.md /opt/container-ops/GUIA.md
```

### Exemplos (o essencial)

Atualizar **um** container (backup → pull → restart → validação → refresh no HA):

```bash
/opt/container-ops/ops.sh update hermes latest
/opt/container-ops/ops.sh update jellyfin latest
/opt/container-ops/ops.sh update adguard latest
```

Atualizar **todos** os apps cadastrados de uma vez (tag habitual: `latest`; Immich/`immich-ml` → `release`; Uptime Kuma → `2`):

```bash
/opt/container-ops/ops.sh update all
```

Se um app falhar, o `update all` continua com os restantes e no fim faz um único refresh WUD→HA.

### Passo a passo

1. **Ver o que está pendente** — Home Assistant (badge Docker) ou Homepage («Containers com atualização disponível»). O WUD verifica **um container por hora** (`/etc/cron.d/wud-stagger`), não em batch (para evitar 429 no GHCR).

2. **Listar apps que o script conhece:**

```bash
/opt/container-ops/ops.sh list
```

3. **Atualizar** — um app ou todos:

```bash
/opt/container-ops/ops.sh update <app> <tag>
/opt/container-ops/ops.sh update all
```

| App no comando | Serviço | Tag habitual | Exemplo |
|----------------|---------|--------------|---------|
| `hermes` | Hermes Agent | `latest` | `/opt/container-ops/ops.sh update hermes latest` |
| `jellyfin` | Jellyfin | `latest` | `/opt/container-ops/ops.sh update jellyfin latest` |
| `duplicati` | Duplicati | `latest` | `/opt/container-ops/ops.sh update duplicati latest` |
| `mealie` | Receitas | `latest` | `/opt/container-ops/ops.sh update mealie latest` |
| `adguard` | DNS AdGuard | `latest` | `/opt/container-ops/ops.sh update adguard latest` |
| `wud` | What's Up Docker | `latest` ou `8.3.0` | `/opt/container-ops/ops.sh update wud latest` |
| `node-exporter` | Métricas do host | `latest` | `/opt/container-ops/ops.sh update node-exporter latest` |
| `immich` | Fotos (servidor) | `release` | `/opt/container-ops/ops.sh update immich release` |
| `immich-ml` | Fotos (ML) | `release` | `/opt/container-ops/ops.sh update immich-ml release` |
| `…` | ver `list` | | `/opt/container-ops/ops.sh update all` |

**Immich:** depois de actualizar o servidor, actualize também o ML com a **mesma tag** (o `update all` já faz os dois).

4. **Se algo correr mal**, volte à tag anterior (backups em `/opt/container-ops/backups/<app>/`):

```bash
/opt/container-ops/ops.sh rollback jellyfin latest
```

5. **Só backup** (sem update):

```bash
/opt/container-ops/ops.sh backup jellyfin
/opt/container-ops/ops.sh backup-all
```

6. **Forçar verificação WUD** (opcional — o `update` já faz isto automaticamente):

```bash
/opt/container-ops/ops.sh refresh-ha              # todos os containers (~30 s)
/opt/container-ops/ops.sh refresh-ha jellyfin     # só um (~3 s)
```

Guia completo em português: [`scripts/container-ops/GUIA.md`](scripts/container-ops/GUIA.md)

---

| Item | Valor |
|------|--------|
| **Hypervisor** | Proxmox `192.168.3.20` |
| **VM** | `docker` — Debian 12, 8 GB RAM |
| **IP** | `192.168.3.21/26` (gateway `192.168.3.1`) |
| **Home Assistant** | `192.168.3.10` (VM separada) |
| **DNS / split DNS** | AdGuard nesta VM |
| **Acesso público** | Cloudflare Tunnel + NPM (HTTPS) |
| **Tailscale** | Subnet router `192.168.3.0/24`, `192.168.68.0/24`, `192.168.2.0/24` |

**Tarefas pendentes:** [`PENDENCIAS.md`](PENDENCIAS.md) — na raiz do servidor: `/root/homelab-pendencias.md` (symlink).

**Guia completo (replicar tudo):** [`docs/SERVIDOR-HOMELAB.md`](docs/SERVIDOR-HOMELAB.md) — VM Proxmox, stacks, NPM, Cloudflare, AdGuard split DNS, Duplicati, HA.

---

## Estrutura do repositório

```
homelab/
├── README.md                 ← este ficheiro
├── PENDENCIAS.md             ← lista de tarefas
├── .gitignore
├── compose/                  ← um pasta por serviço (sem segredos)
│   ├── adguard-home/
│   ├── cloudflare-tunnel/    ← .env.example
│   ├── dozzle/
│   ├── duplicati/
│   ├── firefly-iii/
│   ├── hermes-agent/
│   ├── homepage/
│   ├── immich/               ← .env.example (Valkey em vez de Redis)
│   ├── jellyfin/
│   ├── mealie/
│   ├── monitoring/           ← Prometheus, Grafana, node-exporter
│   ├── nginx-proxy-manager/
│   ├── portainer/
│   ├── tailscale/
│   ├── uptime-kuma/          ← imagem :2
│   ├── vaultwarden/
│   └── wud/
├── etc/
│   ├── cron/                 ← wud-stagger
│   ├── docker/               ← daemon.json, firewall, Tailscale forward, VLANs
│   └── network/if-up.d/      ← rota LAN 68.x
├── config/
│   ├── adguard/              ← DoH example (insecure_enabled)
│   ├── cursor/mcp.json.example
│   ├── homepage/
│   └── portainer/
├── scripts/
│   ├── deploy-stack.sh
│   ├── sync-portainer-compose.sh
│   ├── container-ops/        ← backup/update/rollback de stacks
│   ├── duplicati-hooks/      ← pre/post backup + webhook HA
│   ├── wud-stagger-watch.sh  ← fila horária WUD (evita 429 GHCR)
│   └── testar-dns-remoto.sh
├── homeassistant/            ← referência WUD, Duplicati, automações
├── backups/                  ← exports de referência (sem dados live)
└── docs/
    ├── SERVIDOR-HOMELAB.md   ← guia completo para replicar
    ├── ADGUARD-DNS-REMOTO.md ← DNS 4G / split horizon
    ├── DUPLICATI-BACKUP.md
    ├── SECRETS.md
    ├── RECOMENDACOES.md
    ├── roteamento-docker-lan.md
    ├── PUSH-GITHUB.md
    └── MCP-HOME-ASSISTANT-GUIA.md
```

---

## Reconstruir o servidor do zero

> Passo a passo detalhado (arquitectura, ordem de deploy, NPM, Cloudflare, AdGuard, checklist): **`docs/SERVIDOR-HOMELAB.md`**.

### 1. VM e SO

1. Criar VM no Proxmox (Debian 12, 8 GB RAM, disco adequado).
2. IP estático `192.168.3.21/26`, gateway `192.168.3.1`, DNS inicial qualquer.
3. Instalar Docker + plugin Compose:

```bash
apt update && apt install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list
apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

### 2. Ficheiros de sistema (copiar do repo)

```bash
cp etc/docker/daemon.json /etc/docker/
cp etc/docker/homelab-firewall.sh /etc/docker/
cp etc/docker/homelab-trusted-networks.conf /etc/docker/
cp etc/docker/wud-registries.env.example /etc/docker/wud-registries.env
chmod +x /etc/docker/homelab-firewall.sh
cp etc/network/if-up.d/route-lan68 /etc/network/if-up.d/
chmod +x /etc/network/if-up.d/route-lan68
```

Aplicar firewall após o Docker estar instalado:

```bash
/etc/docker/homelab-firewall.sh
```

Persistir no boot (exemplo systemd ou `@reboot` no cron):

```bash
@reboot /etc/docker/homelab-firewall.sh
```

### 3. Pré-requisitos no host

| Caminho | Uso |
|---------|-----|
| `/media` | Jellyfin (biblioteca) |
| `/mnt/ssd-backup` | Destino backups Duplicati |
| `/opt/duplicati-scripts` | Hooks pre/post backup (opcional) |

### 4. Subir os stacks

Ordem sugerida (rede e DNS primeiro):

```bash
cd homelab/scripts
./deploy-stack.sh adguard-home
./deploy-stack.sh nginx-proxy-manager
./deploy-stack.sh cloudflare-tunnel   # requer compose/cloudflare-tunnel/.env
./deploy-stack.sh homepage
./deploy-stack.sh vaultwarden
./deploy-stack.sh uptime-kuma
./deploy-stack.sh immich              # requer stack.env
./deploy-stack.sh jellyfin
./deploy-stack.sh mealie
./deploy-stack.sh duplicati
./deploy-stack.sh wud
docker compose -f ../compose/portainer/docker-compose.yml up -d
```

**Antes de cada stack com `.env.example`:**

```bash
cp .env.example .env   # editar com valores reais
```

**Immich:**

```bash
cd compose/immich
cp .env.example .env
# Editar DB_PASSWORD, PUBLIC_URL, etc.
chmod 600 .env
docker compose -p immich up -d
```

### 5. Portainer (opcional)

Se usar Portainer, os composes “live” ficam em:

`/var/lib/docker/volumes/portainer_data/_data/compose/`

Sincronize a partir deste repositório após alterações, ou importe stacks pela UI.

### 6. NPM + domínios

1. Aceder `http://192.168.3.21:81` (só LAN).
2. Criar Proxy Hosts para cada serviço (`*.antonio.rafael.nom.br`).
3. Certificados Let's Encrypt (DNS ou HTTP challenge conforme setup).

### 7. AdGuard

- DNS upstream conforme preferência.
- **Split DNS:** rewrites só para clientes `192.168.0.0/16` — ver `config/adguard/split-dns-user-rules.example.txt` e `docs/ADGUARD-DNS-REMOTO.md`.
- **Não** activar painel «Criptografia» se usar Cloudflare Tunnel + NPM.

### 8. Home Assistant

- Add-on **HA MCP** porta `9583` (ver `docs/MCP-HOME-ASSISTANT-GUIA.md`).
- WUD → MQTT → entidades `update.sistema_docker_*` (ver `homeassistant/wud-ha-rename-map.json`).
- Uptime Kuma → webhook `http://192.168.3.10:8123/api/webhook/uptime_kuma_homelab`.

### 9. Uptime Kuma v2

- Imagem: `louislam/uptime-kuma:2` (não `:latest` — ainda é v1).
- Migração v1→v2: ver [wiki oficial](https://github.com/louislam/uptime-kuma/wiki/Migration-From-v1-To-v2).
- Backup dados: volume `uptime-kuma_uptime-kuma_data` → `/app/data`.

---

## Serviços e URLs (exemplo)

| Serviço | URL pública (ex.) | Porta host / LAN |
|---------|-------------------|------------------|
| Homepage | https://home.antonio.rafael.nom.br (se configurado) | `192.168.3.21:3001` |
| Immich | https://fotos.antonio.rafael.nom.br | 2283 |
| Jellyfin | https://jellyfin.antonio.rafael.nom.br | 8096 |
| Home Assistant | https://homeassistant.antonio.rafael.nom.br | `192.168.3.10:8123` |
| Mealie | https://receitas.antonio.rafael.nom.br | 9925 |
| Vaultwarden | https://senhas.antonio.rafael.nom.br | 3003 (só HTTPS público) |
| Firefly III | https://firefly.antonio.rafael.nom.br | 3004 |
| Hermes Agent | https://hermes.antonio.rafael.nom.br | 9119 |
| Filebrowser | https://filebrowser.antonio.rafael.nom.br | 8085 |
| Uptime Kuma | https://uptimekuma.antonio.rafael.nom.br | 3002 |
| Portainer | https://portainer.antonio.rafael.nom.br | 9443 |
| NPM admin | (só LAN) | `192.168.3.21:81` |
| AdGuard UI | https://adguard.antonio.rafael.nom.br | 8080 |
| DNS DoH (4G) | `dns.antonio.rafael.nom.br` | 8080 (via NPM/túnel) |
| Duplicati | https://duplicati.antonio.rafael.nom.br | 8200 |
| Dozzle | https://dozzle.antonio.rafael.nom.br | 8888 |
| Grafana | https://grafana.antonio.rafael.nom.br | 3005 |
| Prometheus | (só LAN) | `192.168.3.21:9090` |
| Glances | (só LAN) | `192.168.3.21:61208` |
| Proxmox | (só LAN / Tailscale) | `https://192.168.3.20:8006` |

---

## Segurança

- **Nunca** commitar `.env`, `stack.env`, tokens Cloudflare, senhas Duplicati/MQTT.
- Firewall: `etc/docker/homelab-firewall.sh` restringe portas admin às VLANs em `homelab-trusted-networks.conf`.
- Roteamento: ver `docs/roteamento-docker-lan.md`.
- Revisão periódica: `docs/RECOMENDACOES.md`.

---

## Git

```bash
cd /root/homelab
git init
git add .
git status   # confirmar que .env não entra
git commit -m "Infra homelab Docker: composes, firewall, documentação"
git remote add origin git@github.com:SEU_USER/SEU_REPO.git
git push -u origin main
```

---

## Manutenção

| Tarefa | Comando / ficheiro |
|--------|-------------------|
| **Atualizar containers** | `/opt/container-ops/ops.sh update hermes latest` — ou tudo: `update all` |
| Verificar updates (WUD) | Fila horária (`/etc/cron.d/wud-stagger`); manual um: `docker exec wud curl -s -X POST http://127.0.0.1:3000/api/containers/<id>/watch` |
| Token GHCR (WUD) | `/etc/docker/wud-registries.env` — ver `etc/docker/wud-registries.env.example` |
| Verificar backups | `scripts/duplicati-verificar-backup.sh` |
| Documentação Duplicati | `docs/DUPLICATI-BACKUP.md` |
| Duplicati → OneDrive + estratégia 3-2-1 | `docs/DUPLICATI-ONEDRIVE.md` |
| Estado dos backups | `scripts/duplicati-status.sh` |
| Guia completo / replicação | `docs/SERVIDOR-HOMELAB.md` |
| Testar DNS 4G / LAN | `scripts/testar-dns-remoto.sh` |
| Reaplicar firewall | `/etc/docker/homelab-firewall.sh` |
| Pendências | `PENDENCIAS.md` |

---

## Contacto / notas

Domínio base: `antonio.rafael.nom.br`. Ajuste `PUBLIC_URL`, certificados e monitores Kuma se mudar domínio ou IP.
