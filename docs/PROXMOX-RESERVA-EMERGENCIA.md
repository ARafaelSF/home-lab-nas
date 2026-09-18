# Emergência — ativar o Mini PC de reserva

Guia para o dia em que o **Proxmox principal** (`192.168.3.20`) falha.  
Objetivo: a casa voltar a ter **Home Assistant** e **Docker** com os **mesmos IPs** de sempre.

Lê isto **antes** de precisar. Em pânico, segue só a checklist no fim.

---

## O que tens (lembrete)

| Peça | Papel |
|------|--------|
| Mini PC **principal** | `192.168.3.20` — Proxmox do dia a dia |
| Mini PC **reserva** | `192.168.3.30` — cold standby; VMs 100/101 já restauradas, **paradas**, `onboot=0` |
| Tomada Tasmota | `switch.escritorio_servidor_minipc_tasmota` (reserva) |
| SSD WD **~1 TB** | Só no principal; Duplicati / `/mnt/pve/Backup-1TB` → disco `scsi2` da VM Docker |
| VM **101** | Home Assistant → IP **`192.168.3.10`** |
| VM **100** | Docker (AdGuard, NPM, Immich, …) → IP **`192.168.3.21`** |

**Regra de ouro:** nunca as mesmas VMs a correr nos **dois** Proxmox ao mesmo tempo (IPs iguais → conflito na rede).

---

## Antes de começares

1. Confirma que o **principal está morto** (ou vais desligá-lo de propósito).  
   Se ainda responde, **desliga-o** (UI Proxmox → shutdown, ou corta a corrente **depois** de `halt` se possível).
2. Tens acesso físico aos dois mini PCs e ao SSD.
3. Tens um PC/telemóvel na LAN (ou Tailscale) para abrir `https://192.168.3.30:8006`.
4. Senha root do Proxmox da reserva (a mesma que usas no dia a dia / no guia de instalação).

---

## Passo A — Desligar o principal

1. Se o Proxmox `.20` ainda abre: **Datacenter → nó → Shutdown** (ou `shutdown -h now` por SSH).
2. Espera apagar. Confirma que **não faz ping**:
   ```bash
   ping -c 2 192.168.3.20
   ```
3. Se não desliga sozinho: corta a corrente do principal.

Enquanto o principal estiver ligado com as VMs a correr, **não** ligues as VMs na reserva.

---

## Passo B — Mover o SSD de 1 TB

O SSD **não** vai na cópia semanal. Tens de o mudar à mão.

1. **Desliga a corrente** do principal (já deve estar).
2. Abre o mini PC principal. Localiza o SSD SATA WD (~1 TB), série típica `21401J801458` (confirma a etiqueta).
3. Desliga o cabo SATA + alimentação; retira o SSD.
4. Instala o mesmo SSD no **mini PC de reserva** (SATA + alimentação).
5. Fecha a caixa.

Não formates o disco. O conteúdo (Duplicati, etc.) tem de permanecer.

---

## Passo C — Ligar a reserva

1. Liga a **tomada Tasmota** da reserva (app / HA se ainda tiveres outro caminho; senão, botão físico na tomada ou cabo direto na parede).
2. Espera **3–5 minutos** o Proxmox arrancar.
3. Abre no browser: **https://192.168.3.30:8006**  
   (UI do PBS, se precisares: `https://192.168.3.30:8007`)
4. Confirma em **VMs**:
   - `100` docker → **stopped**
   - `101` homeassistant → **stopped**

Se o IP `.30` não responder: cabo de rede na VLAN Servidor, gateway `192.168.3.1`, e a tomada realmente a alimentar o PC.

---

## Passo D — Montar o SSD na reserva (storage + disco da VM)

No Proxmox da reserva (`.30`):

### D1 — Storage `Backup-1TB`

1. Identifica o disco novo:
   ```bash
   lsblk -o NAME,SIZE,MODEL,SERIAL,MOUNTPOINT
   ```
2. Se ainda **não** há mount em `/mnt/pve/Backup-1TB`:
   - Cria o ponto de montagem e monta a partição do SSD (no principal era `sda1` → `/mnt/pve/Backup-1TB`).
   - Exemplo (ajusta `sdX1` ao que o `lsblk` mostrar):
     ```bash
     mkdir -p /mnt/pve/Backup-1TB
     # Se o filesystem já existir (caso normal):
     mount /dev/sdX1 /mnt/pve/Backup-1TB
     # Persistência: entrada em /etc/fstab (UUID preferível)
     ```
3. Em **Datacenter → Storage → Add → Directory** (se ainda não existir):
   - ID: `Backup-1TB`
   - Directory: `/mnt/pve/Backup-1TB`
   - Content: inclui **Disk image** (e o que usavas no principal)
   - *Advanced:* “Shared” não é preciso (um nó só)

### D2 — Ligar o disco à VM Docker (100)

No principal o disco era:

`scsi2: Backup-1TB:100/vm-100-disk-0.qcow2,backup=0,size=920G,ssd=1`

Na reserva:

1. Confirma que o ficheiro existe, por exemplo:
   ```bash
   ls -la /mnt/pve/Backup-1TB/100/
   ```
2. Na VM **100** → Hardware → **Add** → Hard Disk (ou edita config):
   - Storage: `Backup-1TB`
   - Usa o disco/qcow2 existente (não cries disco vazio por cima).
   - Bus: SCSI, idealmente **scsi2** (igual ao principal).
   - `backup=0` (opcional mas recomendado).

Se a UI confundir, por SSH na reserva:

```bash
# Só se o path do qcow2 for o mesmo layout:
qm set 100 -scsi2 Backup-1TB:100/vm-100-disk-0.qcow2,backup=0,ssd=1
```

(Confirma o path exacto com `ls` antes.)

---

## Passo E — Arrancar as VMs (ordem importa)

**1. Home Assistant (101) primeiro**

```bash
qm start 101
```

- Espera ficar acessível: **http://192.168.3.10:8123**
- Zigbee/MQTT/integrações: dá 2–5 min.

**2. Docker (100) a seguir**

```bash
qm start 100
```

- Espera: **ping 192.168.3.21** e serviços críticos (AdGuard `:53` / UI `:8080`, NPM, etc.).

**Porquê esta ordem:** o HA estabiliza a casa; o Docker traz DNS, proxy e o resto. Ligar os dois ao mesmo tempo também costuma funcionar, mas HA primeiro reduz surpresas.

**Não** actives `onboot=1` nas duas enquanto estiveres a testar. Quando a reserva for o “novo normal” por uns dias, podes pôr:

```bash
qm set 101 -onboot 1
qm set 100 -onboot 1
```

---

## Passo F — Checklist rápido (está vivo?)

Marca mentalmente:

| Serviço | Como validar |
|---------|----------------|
| Proxmox reserva | `https://192.168.3.30:8006` |
| Home Assistant | `http://192.168.3.10:8123` |
| Docker / NAS | `ping 192.168.3.21` |
| DNS AdGuard | Resolução na LAN; UI `http://192.168.3.21:8080` (failover Pi `.22` se o `.21` ainda não subiu) |
| Internet / túnel | Um hostname Cloudflare que uses no telemóvel |
| SSD / Duplicati | Dentro da VM Docker: `df -h /mnt/ssd-backup` ou path que usas no job (mount interno da VM) |

Lista mais completa de URLs: `docs/checklist-servicos-nas.txt`.

---

## IPs — o que muda e o que não muda

| Quem | IP | Notas |
|------|-----|--------|
| Proxmox (hypervisor) | **`.30`** em emergência (antes era `.20`) | A UI deixa de ser `:8006` no `.20` |
| Home Assistant | **`.10`** (igual) | Não mudas |
| Docker | **`.21`** (igual) | Não mudas |
| PBS na reserva | `.30:8007` | Continua no mesmo host |

**Fase 2 (ainda não feito):** script para renumerar o host reserva para `.20` se quiseres “parecer” o principal. **Não é necessário** para a casa funcionar — só cosmética / hábitos de bookmark.

---

## Quando voltares ao principal

1. Desliga as VMs na **reserva** (`qm stop 100`, `qm stop 101`).
2. Desliga a reserva (`shutdown -h now`) e a tomada.
3. Move o SSD de volta ao principal.
4. Liga o principal; confirma VMs e storage `Backup-1TB`.
5. Na próxima terça a rotina semanal volta a refrescar a reserva.

Enquanto o principal estiver outra vez o activo, a reserva deve ficar **parada** (cold standby).

---

## Problemas frequentes

| Sintoma | O que fazer |
|---------|-------------|
| Conflito de IP / rede “estranha” | Principal ainda ligado com VMs a correr — desliga o principal |
| HA não abre em `.10` | `qm status 101`; consola da VM; espera cloud-init/rede |
| Docker sem SSD / Duplicati vazio | Storage `Backup-1TB` ou `scsi2` em falta — revisita passo D |
| Sem DNS na casa | AdGuard `.21` ainda a subir; temporário: Pi **`.22`** já é 2.º DNS no UniFi |
| Sem UI Proxmox no `.20` | Em emergência a UI é **`.30`** |

---

## Fora deste guia (fase 2)

- Script automático de IPs do hypervisor  
- Failover automático sem intervenção  
- Copiar o SSD pela rede  

Plano geral: `docs/PROXMOX-RESERVA-PASSO-A-PASSO.md`.
