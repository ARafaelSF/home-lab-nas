# Home Assistant — espelho de segurança

Cópia de referência dos YAML críticos (sem `secrets.yaml`).

## Restaurar no HA (`/config`)

1. Copiar `automations.yaml`, `scripts.yaml` e `blueprints/automation/Antonio/*` para `/config`.
2. `configuration.yaml.reference` é **sanitizado** (senhas removidas) — usar só como guia; o vivo tem `secrets` e passwords reais.
3. Garantir pastas: `themes/`, `packages/`.
4. Em Developer Tools → YAML → Check configuration → Reiniciar.

## Porque isto existe

Edições via Samba/CIFS a partir do Cursor podem apagar ficheiros no save. Este espelho no GitHub `home-lab-nas` serve para recuperar.
