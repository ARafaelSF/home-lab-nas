# home-lab-nas

Homelab Docker — documentação e infraestrutura para reconstruir a VM NAS/homelab.

Repositório: [github.com/ARafaelSF/home-lab-nas](https://github.com/ARafaelSF/home-lab-nas)

| Item | Valor |
|------|--------|
| **Hypervisor** | Proxmox `192.168.3.20` |
| **VM** | `docker` — Debian 12, 8 GB RAM |
| **IP** | `192.168.3.21/26` (gateway `192.168.3.1`) |
| **Home Assistant** | `192.168.3.10` (VM separada) |
| **DNS / split DNS** | AdGuard nesta VM |
| **Acesso público** | Cloudflare Tunnel + NPM (HTTPS) |

**Tarefas pendentes:** [`PENDENCIAS.md`](PENDENCIAS.md) — na raiz do servidor: `/root/homelab-pendencias.md` (symlink).

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
│   ├── duplicati/
│   ├── immich/               ← .env.example
│   ├── jellyfin/
│   ├── nginx-proxy-manager/
│   ├── uptime-kuma/          ← imagem :2
│   ├── wud/
│   └── portainer/
├── etc/
│   ├── docker/               ← daemon.json, firewall, VLANs
│   └── network/if-up.d/      ← rota LAN 68.x
├── scripts/
│   ├── deploy-stack.sh
│   └── duplicati-verificar-backup.sh
├── homeassistant/            ← referência WUD / automações
├── backups/                  ← exports de referência (sem dados live)
└── docs/
    ├── RECOMENDACOES.md      ← revisão Docker + próximos passos
    ├── roteamento-docker-lan.md
    └── MCP-HOME-ASSISTANT-GUIA.md
```

---

## Reconstruir o servidor do zero

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
cp etc/docker/wud-lscr.env.example /etc/docker/
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

- Configurar DNS rewrites / split DNS para domínios internos → `192.168.3.21`.
- Upstream DNS conforme preferência.

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

| Serviço | URL pública (ex.) | Porta host |
|---------|-------------------|------------|
| Immich | https://fotos.antonio.rafael.nom.br | 2283 |
| Jellyfin | https://jellyfin.antonio.rafael.nom.br | 8096 |
| Vaultwarden | https://senhas.antonio.rafael.nom.br | 3003 |
| Mealie | https://receitas.antonio.rafael.nom.br | 9925 |
| Uptime Kuma | https://uptimekuma.antonio.rafael.nom.br | 3002 |
| Portainer | https://portainer.antonio.rafael.nom.br | 9443 |
| Homepage | (LAN / domínio interno) | 3001 |
| Duplicati | LAN `8200` (admin bloqueado WAN) | 8200 |
| Filebrowser | LAN `8085` | 8085 |

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
| Atualizar imagens | WUD + `docker compose pull` por stack |
| Verificar backups | `scripts/duplicati-verificar-backup.sh` |
| Reaplicar firewall | `/etc/docker/homelab-firewall.sh` |
| Pendências | `PENDENCIAS.md` |

---

## Contacto / notas

Domínio base: `antonio.rafael.nom.br`. Ajuste `PUBLIC_URL`, certificados e monitores Kuma se mudar domínio ou IP.
