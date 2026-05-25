# Duplicati — backup semanal no OneDrive

## Estratégia activa no servidor (2026-05-25)

| Job | O quê | Quando | Destino |
|-----|--------|--------|---------|
| **`docker-local`** | Volumes Docker, `/media`, homelab, configs | **Diário 02:00** | SSD `/mnt/ssd-backup/.../proxmox-docker01` |
| **`homelab-onedrive`** | Cópia **já backupada** no SSD (não relê tudo) | **Terça 04:00** (horário de Brasília) | OneDrive pasta `/Homelab-Backup` |

Destino OneDrive guardado como **«OneDrive #1»** (OAuth da conta 2).

**Primeiro envio à nuvem:** concluído 2026-05-25 (~**157 GB** enviados, backup size 157,76 GB no OneDrive).

**Opção no job (Docker):** `--disable-module=console-password-input` — evita erro ao clicar «Run now» na UI (`Console.Read`).

Ver progresso: `homelab/scripts/duplicati-status.sh` ou UI → job `homelab-onedrive`.

---

## Estratégia completa (porque está optimizada)

### Regra 3-2-1

| Princípio | Como está no homelab |
|-----------|----------------------|
| **3** cópias | Dados originais + repositório no SSD + repositório no OneDrive |
| **2** tipos de suporte | SSD local + nuvem Microsoft |
| **1** cópia off-site | OneDrive (conta separada / fora de casa) |

### Os dois jobs em cadeia (não duplicam trabalho)

```text
Dados reais (Docker, /media, homelab, configs)
        │
        ▼  docker-local — diário 02:00
     SSD  /mnt/ssd-backup/.../proxmox-docker01  (~147 GB deduplicado)
        │
        ▼  homelab-onedrive — terça 04:00
     OneDrive  /Homelab-Backup
```

**Passo 1 — `docker-local`** lê ficheiros **vivos** no servidor:

- volumes Docker, `/media` (Jellyfin), `/root/homelab`, `/etc/docker`, rede.

**Passo 2 — `homelab-onedrive`** lê **só** a pasta do backup no SSD:

- `/backups/docker-volumes/proxmox-docker01` (ficheiros encriptados do repositório Duplicati).

O `/media` **já está** no passo 1. A nuvem **não volta** a ler `/media` no disco — só copia o que o passo 1 já guardou. Isso poupa tempo, quota OneDrive e CPU.

| Se a nuvem lesse `/media` outra vez | Efeito |
|-------------------------------------|--------|
| Duplicava leitura de terabytes | Muito mais lento |
| Duas cópias independentes na nuvem | Quota e confusão na restauração |

### Retenção — não são «7, 14 e 30 dias» cheios

| Job | Política | Significado |
|-----|----------|-------------|
| **docker-local** (SSD) | `1W:1D,4W:1W,12M:1M` | Última semana: máx. **1 backup/dia**; 4 semanas: **1/semana**; 12 meses: **1/mês** |
| **homelab-onedrive** (nuvem) | `4W:1W,12M:1M` | 4 semanas: **1/semana**; 12 meses: **1/mês** (sem ponto diário na nuvem) |

O Duplicati usa **deduplicação**: blocos iguais guardam-se uma vez. Várias «versões» não significam 147 GB × número de dias — o SSD mantém um pool de blocos (~147 GB hoje).

### O OneDrive recebe todas as versões diárias do SSD?

**Não.** São históricos **separados**:

| Onde | Histórico |
|------|-----------|
| **SSD** | Pontos no tempo **diários** (retenção fina) |
| **OneDrive** | Pontos **semanais** (terça 04:00) + mensais (retenção do job nuvem) |

Cada terça o job nuvem envia o **estado actual** da pasta no SSD (incremental). Não replica cada snapshot diário do SSD para a Microsoft.

| Fase | Tamanho típico |
|------|----------------|
| Primeira subida OneDrive | Grande (~tamanho do repositório no SSD) |
| Terças seguintes | Só blocos novos/alterados |

### Resumo FAQ

| Pergunta | Resposta |
|----------|----------|
| Está optimizado? | Sim — local rápido + nuvem semanal sem reler tudo |
| `/media` vai para a nuvem? | Sim, **via** SSD (já no `docker-local`) |
| Local guarda 7+14+30 cópias completas? | Não — retenção inteligente + deduplicação |
| OneDrive guarda todos os dias? | Não — versões semanais/mensais na nuvem |
| Mesma passphrase? | Sim — login UI = passphrase AES (Vaultwarden) |

---

## Recomendação (resumo)

| Pergunta | Resposta |
|----------|----------|
| Criar **outro serviço** Docker (rclone, OneDrive, etc.)? | **Não.** Use um **segundo job** no mesmo Duplicati. |
| Com que frequência? | **1× por semana** — terça 04:00 (Brasília). |
| O quê enviar? | A cópia **já feita no SSD local**, não voltar a ler `/media` e todos os volumes outra vez. |
| Job local `docker-local`? | Mantém **diário** às 02:00 — não mexer. |

Isto segue a regra **3-2-1**: cópia local rápida + cópia off-site encriptada na nuvem.

---

## Arquitectura

```text
┌─────────────────────────────────────────────────────────────┐
│  Job 1: docker-local (diário 02:00)                         │
│  Fontes: volumes Docker, /media, homelab, /etc/docker...  │
│  Destino: /mnt/ssd-backup/.../proxmox-docker01            │
│  Hooks: param/sobem containers (Immich, Postgres, etc.)     │
└───────────────────────────┬─────────────────────────────────┘
                            │ dados já encriptados (AES)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Job 2: homelab-onedrive (terça 04:00)                     │
│  Fonte: /backups/docker-volumes/proxmox-docker01 (só isto)  │
│  Destino: OneDrive (OAuth na UI Duplicati)                  │
│  Hooks: nenhum (ficheiros estáticos no SSD)                 │
└─────────────────────────────────────────────────────────────┘
```

**Porquê não um container OneDrive à parte?**

- Duplicati já inclui backend **OneDrive** (`Duplicati.Library.Backend.OneDrive.dll`).
- Mesma passphrase, mesma UI, retenção e logs.
- rclone/cron seria um segundo sistema a manter sem ganho real.

**Porquê semanal e não diário na nuvem?**

- Upload inicial + incrementais consomem quota e tempo (hoje ~16 GB local; pode crescer).
- O SSD local já protege contra falha do disco **hoje**; OneDrive é para incêndio/roubo/falha do servidor.
- Semanal é o equilíbrio usual para homelab (podes mudar para 2×/semana depois).

---

## Pré-requisitos

1. Job **`docker-local`** a correr bem (backup no SSD sem erros graves).
2. Conta **Microsoft** com espaço OneDrive suficiente (1 TB pessoal ou Microsoft 365).
3. Senha Duplicati no Vaultwarden (login UI = passphrase dos backups).
4. Primeiro backup local **completo** antes do primeiro envio à nuvem (evita subir cópia a meio).

Verificar tamanho actual:

```bash
du -sh /mnt/ssd-backup/docker-volumes/proxmox-docker01
```

---

## Passo a passo na UI Duplicati

Abrir Duplicati para configurar OneDrive — **use a URL na LAN** (evita OAuth e WebSockets pela internet):

```text
http://192.168.3.21:8200
```

> Se usar `https://duplicati.antonio.rafael.nom.br` e aparecer **«Reconnecting… connection to the server is lost»**, o proxy precisa de **WebSockets** (já corrigido no NPM, host 12). Mesmo assim, para **login Microsoft**, prefira a URL LAN.

### Conta Microsoft 2 (não a do Edge)

O Duplicati usa a sessão do **browser no momento do OAuth**, não a conta “predefinida” do Edge.

1. **Edge:** janela InPrivate → login só na **conta 2** → `http://192.168.3.21:8200` → OAuth OneDrive.
2. **Firefox:** perfil limpo ou “Iniciar sessão” Microsoft e escolher **conta 2** quando o Duplicati abrir a página Microsoft.
3. Se já ligou à conta 1: **Settings → Destinations** → remover destino OneDrive errado → criar de novo e repetir OAuth com conta 2.
4. Em [account.microsoft.com](https://account.microsoft.com) → **Sign out** da conta 1 no mesmo browser antes do OAuth, se necessário.

Não é preciso outro container OneDrive — só repetir autenticação com a conta certa.

### 1. Adicionar destino OneDrive

1. **Settings** → **Destinations** → **Add destination** (ou ao criar o job escolher destino novo).
2. Tipo: **Microsoft OneDrive** (ou OneDrive v2 / Microsoft Graph, conforme a versão).
3. Clicar **AuthID** / **Log in** → login Microsoft → autorizar Duplicati (conta 2).
4. Campo **Path** / **Folder** / **Caminho no servidor** — **obrigatório**, com barra inicial:

```text
/Homelab-Backup
```

Se ao guardar o Duplicati **apagar** a primeira `/`, use o truque do Duplicati:

```text
//Homelab-Backup
```

(guarda → fica `/Homelab-Backup`).

| Evitar | Porquê |
|--------|--------|
| Campo vazio | Erro `root:` → `Resource not found for segment 'root:'` |
| `Homelab-Backup:` (com `:` no fim) | URL Graph inválida |
| Só espaços | Mesmo erro |

5. **Test connection** / **Teste de ligação** — deve ficar verde antes de guardar.
6. Guardar destino com nome claro: `OneDrive-Homelab`.

> A autenticação OAuth **só** funciona no browser; não dá para commitar tokens no Git.

**Se OAuth OK mas Test falha com `root:`:** o Path está vazio ou mal formatado — corrigir como acima e repetir Test.

### 2. Novo backup — `homelab-onedrive`

| Campo | Valor |
|-------|--------|
| **Name** | `homelab-onedrive` |
| **Encryption** | AES-256, **mesma passphrase** que `docker-local` |
| **Destination** | OneDrive → pasta `Homelab-Backup` |
| **Source** | **Apenas** `/backups/docker-volumes/proxmox-docker01` |

**Não** incluir `/source/media/` nem `/source/docker_data/` neste job — isso duplicaria trabalho e tempo.

### 3. Opções importantes

| Opção | Valor sugerido |
|-------|----------------|
| **Remote volume size** | 50 MB (igual ao local) |
| **Compression** | Zip |
| **Retention** | `4W:1W,12M:1M` (4 semanas diários na nuvem, 12 meses 1/mês) — ou `8W:1W` se quota apertar |
| **Run script before/after** | **Desligados** neste job |

### 4. Filtros (opcional)

Normalmente **não** precisas de filtros extra — a pasta local já é output do job 1.

Se quiseres excluir algo que não deva ir à nuvem, adiciona filtro **apenas** neste job (ex. ficheiros temporários se existirem na pasta de backup).

### 5. Agendamento

| Campo | Valor |
|-------|--------|
| **Run regularly** | Sim |
| **Repeat** | `1W` (semanal) |
| **Day** | Domingo |
| **Time** | **05:00** (America/Sao_Paulo) — 3 h depois do local às 02:00 |

**Ordem no domingo:** primeiro termina (ou quase) o backup local; depois o OneDrive envia **incremental** do que mudou no SSD.

### 6. Primeira execução

1. **Não** marques “Run right now” se o job local ainda estiver a correr ou incompleto.
2. Quando o SSD estiver estável, **Run now** no job `homelab-onedrive`.
3. A primeira vez demora mais (upload base). As seguintes são incrementais.

### 7. Teste

Após o primeiro backup na nuvem:

- **Test** no job `homelab-onedrive` (menu do job).
- No OneDrive (browser): pasta `Homelab-Backup` com ficheiros `dblock`, `dindex`, etc. (nomes Duplicati, encriptados).

---

## Tamanho e quota

| Cenário | Nota |
|---------|------|
| ~16 GB hoje no SSD | Primeiro upload ~16 GB + overhead Duplicati |
| Crescimento (Immich + media) | Local diário cresce; nuvem semanal envia só deltas |
| OneDrive 1 TB | Suficiente para homelab se não duplicares `/media` em dois jobs separados na nuvem |

Se a quota apertar:

- Aumentar retenção mais agressiva na nuvem (`4W:1W` apenas).
- Ou excluir do job local pastas muito grandes que não precisam de off-site (decisão consciente no job `docker-local`, não no OneDrive).

---

## Segredos (Vaultwarden)

| Entrada | Conteúdo |
|---------|----------|
| `Duplicati homelab` | Senha UI + passphrase (já existe) |
| `Duplicati OneDrive` (opcional) | Nota: “OAuth Microsoft — reauth na UI se expirar” |

Não guardar tokens OAuth em ficheiros no servidor; o Duplicati guarda em `/config` (volume `25_duplicati_config`, incluído no backup local).

---

## Resolução de problemas

| Sintoma | Acção |
|---------|--------|
| OAuth falhou | Repetir login em Settings → Destinations; conta Microsoft pessoal vs trabalho |
| Upload muito lento | Normal na 1.ª vez; verificar horário (05:00) e uplink |
| “Source is empty” | Job local ainda não criou `proxmox-docker01` — correr `docker-local` primeiro |
| Erro quota OneDrive | Reduzir retenção nuvem ou limpar versões antigas no Duplicati |
| Token expirado | Re-autenticar destino OneDrive na UI |
| `Cannot read keys` / `Console.Read` (backup 0s) | Job sem TTY no Docker — opção avançada `--disable-module=console-password-input` (já aplicado em `homelab-onedrive`) |
| Log com **1 erro** + outro **157 GB OK** | O envio grande **já terminou**; o erro 0s é tentativa à parte (UI sem consola). Ver **Test** e pasta OneDrive |
| «Reconnecting… connection lost» | 1) Fechar separador e **Ctrl+F5**. 2) Preferir `http://192.168.3.21:8200` na LAN. 3) Se usar `https://duplicati...`, o NPM precisa de WebSocket só em `/notifications` (corrigido no servidor). 4) DNS do PC deve ser AdGuard (`192.168.3.21`) — senão o domínio vai à Cloudflare e o túnel pode falhar no WebSocket. |
| OAuth foi para conta 1 | Apagar destino OneDrive no Duplicati; OAuth de novo em InPrivate com conta 2 |
| `BadRequest` … `segment 'root:'` | Path vazio ou sem `/` inicial → usar `/Homelab-Backup` ou `//Homelab-Backup` |
| Conta Microsoft 365 só empresarial | Pode não ter `me/drive` pessoal — usar destino **SharePoint / OneDrive for Business** em vez de OneDrive pessoal |

---

## Checklist

- [ ] Destino OneDrive autenticado na UI
- [ ] Job `homelab-onedrive` criado (fonte = pasta SSD local apenas)
- [ ] Agendamento semanal (domingo 05:00)
- [ ] Mesma passphrase que `docker-local`
- [ ] Primeiro **Test** OK na nuvem
- [ ] Marcar em `PENDENCIAS.md`

---

## Referências

- Backup local: `docs/DUPLICATI-BACKUP.md`
- Verificar tamanho SSD: `scripts/duplicati-verificar-backup.sh`
- Testar senha: `scripts/duplicati-testar-senha.sh`
