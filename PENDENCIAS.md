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

## Já resolvido (referência)

| Item | Data |
|------|------|
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
