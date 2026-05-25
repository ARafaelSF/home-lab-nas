# Homelab — lista do que fazer depois

Documento vivo: marque com `[x]` quando concluir.

**Servidor:** VM Docker no Proxmox (`192.168.3.21`)  
**Última atualização:** 2026-05-25

---

## 1 — Etapa final: NPM (Proxy Hosts + HTTPS na LAN)

**Status:** concluído em 2026-05-25 (9 proxy hosts no NPM).

- [x] Proxy Hosts: fotos, jellyfin, portainer, receitas, uptimekuma, nginx (+ 3 anteriores)
- [x] Immich `PUBLIC_URL` configurado
- [ ] Testar `https://fotos...` no celular em Wi‑Fi + upload grande
- [x] Monitores Uptime Kuma em HTTPS via NPM (DNS AdGuard)
- [x] Duplicati: `https://duplicati.antonio.rafael.nom.br/` (NPM proxy host 12)
- [x] Uptime Kuma: grupos (Mídia / Casa / Infra) + webhook → HA
- [x] Uptime Kuma migrado para **v2** (`louislam/uptime-kuma:2`, 2026-05-25)
- [x] Automações Uptime Kuma no HA (MCP): Telegram + app + painel HA

---

## 2 — Vaultwarden: ativar 2FA na sua conta

**Quando:** assim que tiver 5 minutos.

**O que é:** segundo fator de login (app autenticador). Não se configura pelo Docker — é no painel do Vaultwarden, na sua conta.

**Passos:**

1. Abrir `https://senhas.antonio.rafael.nom.br/`
2. Conta → **Configurações de segurança** → **Autenticação de dois fatores**
3. Ativar (TOTP, ex.: Google Authenticator, Aegis, etc.)
4. Guardar códigos de recuperação em lugar seguro

- [ ] 2FA ativado na conta principal
- [ ] Códigos de recuperação guardados

---

## 3 — Mealie: cadastro aberto na internet (`ALLOW_SIGNUP`)

### O que é o Mealie?

App de **receitas** (cardápio, lista de compras, planejamento de refeições). Você acessa em `https://receitas.antonio.rafael.nom.br/` (porta local `9925`).

### O que é `ALLOW_SIGNUP=true`?

Significa que **qualquer pessoa que abrir o site pode criar uma conta nova**, como um “cadastre-se aqui” público.

Hoje está assim no Docker:

```yaml
ALLOW_SIGNUP=true
```

### Precisa mudar se só você e sua esposa usam?

**Recomendado: sim** — colocar `ALLOW_SIGNUP=false` depois que as duas contas já existirem.

| Situação | O que fazer |
|----------|-------------|
| Contas **já criadas** (você + esposa) | Mudar para `ALLOW_SIGNUP=false` → ninguém mais se cadastra |
| Ainda **não** criaram as contas | Criar as duas contas primeiro, **depois** desligar signup |
| Quer convidar alguém no futuro | Manter `true` ou usar convite/admin (depende da versão) |

**Não apaga receitas** — só impede conta nova.

**O que fazer depois:**

1. Confirmar que vocês dois já têm login no Mealie
2. No Portainer, stack **mealie** → variável `ALLOW_SIGNUP=false`
3. Update da stack

- [x] Contas criadas (você + esposa)
- [x] `ALLOW_SIGNUP=false` aplicado no compose (2026-05-25)

---

## 4 — Duplicati: teste de restore (trimestral)

**Quando:** 1x a cada 3 meses (ou após mudança grande no servidor).

**Por quê:** backup sem teste de restauração não garante que funciona.

**Script de verificação rápida:** `homelab/scripts/duplicati-verificar-backup.sh`

**Teste manual:**

1. Abrir Duplicati (`http://192.168.3.21:8200` na rede local)
2. **Restore** → backup recente de algo **pequeno** (ex.: config do Homepage)
3. Restaurar em `/tmp/restore-test`
4. Abrir arquivos → apagar pasta de teste

- [ ] Restore de teste feito em: ___/___/______

---

## 5 — Immich: atualizar stack + Redis → Valkey

**Quando:** depois que você fizer **backup completo** (fotos + volume Postgres + pasta `library`).

**Por quê:** versões novas do Immich usam **Valkey** em vez de `redis:6.2-alpine`. Não trocar só o Redis sem seguir o `docker-compose.yml` da release alvo.

**Passos (resumo):**

1. Backup Immich (Duplicati ou cópia dos volumes `immich_*` + `UPLOAD_LOCATION`)
2. Baixar compose + `.env` da release em https://github.com/immich-app/immich/releases
3. Atualizar server, ML, database e redis/valkey **juntos**
4. Testar upload e login; só então remover backup temporário

- [ ] Backup Immich feito em: ___/___/______
- [ ] Stack Immich atualizada (Valkey + Postgres da release)
- [ ] Teste de upload/fotos OK

---

## 6 — Outros (prioridade baixa)

### 6.1 — Documentar VLAN IoT no UniFi

Anotar aqui o CIDR da VLAN IoT (só referência; **não** colocar em `/etc/docker/homelab-trusted-networks.conf`):

- VLAN IoT: `________________` (ex.: `192.168.50.0/24`)

### 6.2 — WUD no Home Assistant (nomenclatura)

- [x] Device: **Sistema - Monitor Docker - Wud** (área Sistema)
- [x] Entidades: `update.sistema_docker_*` (nomes curtos: Duplicati, Jellyfin, …)
- [x] Labels Docker `wud.display.name` sem prefixo Sistema
- [x] Sensores agregados WUD renomeados e habilitados (`sistema_docker_*`)
- Labels no compose: `homelab/homeassistant/wud-ha-rename-map.json`

### 6.3 — Senha MQTT do WUD

- [x] Migrado para `compose/26/.env` (`WUD_MQTT_PASSWORD`)

### 6.4 — Filebrowser

Monta o disco raiz (`/`). Uso só admin; manter senha forte. Acesso via Cloudflare/NPM.

### 6.5 — Limites de memória (Immich ML / Jellyfin)

Opcional no compose se um dia faltar RAM em pico.

### 6.6 — fail2ban no SSH

Só se SSH estiver acessível fora da LAN.

---

## Já concluído (referência)

- [x] Fase 1: RAM 8 GB, swap, timezone Brasil
- [x] Fase 2: WUD `getwud/wud`, healthchecks, Uptime Kuma
- [x] Fase 3: Vaultwarden sem signup público, firewall VLANs, script backup
- [x] Firewall: `192.168.3.0/24` + `192.168.68.0/24` (computadores Vlan_Hangar)

---

## Repositório Git (`/root/homelab`)

- [ ] `git init` + push para GitHub/GitLab
- [x] Segredos em `.env` fora do compose (cloudflared, duplicati, wud) — ver `docs/SECRETS.md`

## Arquivos úteis

| Arquivo | Uso |
|---------|-----|
| `/root/homelab-pendencias.md` | Symlink → esta lista |
| `/root/homelab/README.md` | Reconstruir o servidor do zero |
| `homelab/docs/RECOMENDACOES.md` | Revisão Docker e próximos passos |
| `homelab/scripts/duplicati-verificar-backup.sh` | Checar tamanho dos backups |
| `homelab/etc/docker/homelab-trusted-networks.conf` | VLANs liberadas no firewall |
| `homelab/backups/uptime-kuma-monitores-referencia.json` | Referência monitores Kuma |
