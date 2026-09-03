# LocalThings — substituto local do SmartThings (Samsung)

Integração comunitária: [mbillow/localthings](https://github.com/mbillow/localthings)

Controla aparelhos Samsung **na LAN** (CoAP/DTLS), sem depender da API cloud SmartThings.

## Estado no homelab (2026-09-01)

| Item | Status |
|------|--------|
| HACS — LocalThings v0.25.0 | ✅ Instalado |
| Certificados CA `AC14K_M` | ✅ Gerados via `setup_cert.py` (bundle público) |
| Config entries LocalThings | ✅ 3 ACs (LAN `192.168.2.x`) |
| Entidades `climate.*` | ✅ LocalThings — leitura + escrita testadas |
| SmartThings cloud | ⚠️ Ainda activo — pode desactivar após validar automations |

### Mapeamento IP → entidade

| Cômodo | IP | Entidade climate |
|--------|-----|------------------|
| Suíte | 192.168.2.170 | `climate.samsung_airconditioner_ara_ww_tp1_22_common` |
| Sala de TV | 192.168.2.171 | `climate.samsung_airconditioner_ara_ww_tp1_22_common_3` |
| Escritório | 192.168.2.172 | `climate.samsung_airconditioner_ara_ww_tp1_22_common_2` |

Certificados gerados em `homelab/homeassistant/localthings-certs/` (não commitar — contém chave privada CA).

### Renomeação (2026-09-01)

Padrão igual ao Tuya (`_localtuya` / `_tuyacloud`):

| Integração | Sufixo entity_id | Dispositivo |
|------------|------------------|-------------|
| **LocalThings** (activo) | `_smartthings` | `{Cômodo} - Ar condicionado` |
| **SmartThings cloud** (monitorização) | `_cloud` | `{Cômodo} - Ar condicionado Cloud` |

Script: `homelab/homeassistant/scripts/rename-smartthings-localthings.py`

Automations, dashboards e utility meters continuam a usar `*_smartthings` — agora servidos pelo LocalThings.

### Ar-condicionados Samsung (SmartThings)

| Cômodo | Modelo | Firmware | TizenRT | DAWIT |
|--------|--------|----------|---------|-------|
| Suíte | ARA-WW-TP1-22-COMMON | `_11260327` | 3.1 | 2.0 |
| Sala de TV | ARA-WW-TP1-22-COMMON | `_11260327` | 3.1 | 2.0 |
| Escritório | ARA-WW-TP1-22-COMMON | `_11260327` | 3.1 | 2.0 |

O config flow do LocalThings **pediu CA Certificate + CA Private Key** no primeiro dispositivo — seguir Part 2 do README upstream.

## Instalação (já feita)

1. HACS → Integrations → **LocalThings** → Download
2. Reiniciar Home Assistant

## Configurar (próximo passo manual)

1. **Definições → Dispositivos e serviços → Adicionar integração → LocalThings**
2. **Primeiro AC** — campos obrigatórios:
   - **Host:** IP fixo do ar-condicionado na LAN (ex.: `192.168.3.x`)
   - **CA Certificate (PEM)** e **CA Private Key (PEM):** credenciais `AC14K_M` (ver abaixo)
3. **ACs seguintes** — só pedem o IP (reutilizam a CA guardada)

### Obter certificados CA (AC14K_M)

O repositório **não inclui** as chaves. Referência:

- [smartthings-local setup_cert.py](https://github.com/QuiteYellow/SmartThings-Local/blob/main/setup_cert.py)

Só é necessário **uma vez** por instalação HA.

### Descobrir IP de cada AC

- Router UniFi / AdGuard (DHCP leases, hostname `Samsung-Room-Air-Conditioner`)
- App SmartThings → dispositivo → informações de rede (se disponível)
- Desligar/ligar um AC e ver qual IP responde nas portas UDP **49152–49160**

## Depois de configurar

- Criar entidades `climate.*` novas (domínio `localthings`) — **não** renomear automaticamente as antigas `*_smartthings` até validar
- Testar: ligar/desligar, modo, temperatura alvo
- Sensores de energia: confirmar se LocalThings expõe o mesmo que SmartThings (`sensor.*_energia_*`)
- Automations que usam `*_smartthings` — migrar entity_id só após testes OK

## Compatibilidade

LocalThings documenta **DAWIT 3.0+**. Estes ACs reportam **DAWIT 2.0** (TizenRT 3.1). Pode funcionar na mesma — **só o teste confirma**. Se o config flow falhar na sonda DTLS, o firmware pode não expor API local.

## Links

- [LocalThings no GitHub](https://github.com/mbillow/localthings)
- [SmartThings-Local (protocolo)](https://github.com/QuiteYellow/SmartThings-Local)
