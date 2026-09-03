# Restore: Corredor - Interruptor Escada (Zigbee2MQTT)

Referência para quando o interruptor sair do ar e for re-pareado.
Última configuração válida: 2026-08-30.

## Dispositivo

| Campo | Valor |
|---|---|
| Nome HA | `Corredor - Interruptor Escada` |
| Área | `corredor` |
| IEEE (referência) | `0x60a423fffe9c15d9` |
| Integração | Zigbee2MQTT (Tuya 4 canais) |

Após re-parear, o HA tende a criar: `switch.corredor_interruptor_escada_l1` … `l4`.

## Canais — switches → luzes (`switch_as_x`)

| Canal | Nome | Switch | Luz | Área luz | Ícone luz |
|---|---|---|---|---|---|
| L1 | Balizador | `switch.corredor_interruptor_escada_z2m_l1_balizador` | `light.corredor_interruptor_escada_z2m_l1_balizador` | corredor | `mdi:floor-lamp-torchiere-variant-outline` |
| L2 | Trilho Corredor | `switch.corredor_interruptor_escada_z2m_l2_trilho_corredor` | `light.corredor_interruptor_escada_z2m_l2_trilho_corredor` | corredor | `hue:ceiling-buratto-four` |
| L3 | Jardim Japonês | `switch.corredor_interruptor_escada_z2m_l3_jardim_japones` | `light.corredor_interruptor_escada_z2m_l3_jardim_japones` | corredor | `phu:floor-lantern` |
| L4 | Pé Direito | `switch.corredor_interruptor_escada_z2m_l4_pe_direito` | `light.sala_de_jantar_interruptor_escada_z2m_l4_pe_direito` | sala_de_jantar | `mdi:lightbulb-fluorescent-tube-outline` |

## Paralelos virtuais (outros interruptores — não alterar)

| Automação | Luz escada | Virtual |
|---|---|---|
| `automation.paralelo_virtual_balizador` | `light.corredor_interruptor_escada_z2m_l1_balizador` | `switch.cozinha_interruptor_corredor_z2m_l3_balizador_virtual` |
| `automation.paralelo_virtual_trilho_corredor` | `light.corredor_interruptor_escada_z2m_l2_trilho_corredor` | `switch.corredor_interruptor_corredor_z2m_l4_trilho_corredor_virtual` |
| `automation.paralelo_virtual_pe_direito` | `light.sala_de_jantar_interruptor_escada_z2m_l4_pe_direito` | `switch.corredor_interruptor_sala_de_jantar_z2m_l2_pe_direito_virtual` + `switch.corredor_interruptor_corredor_z2m_l2_pe_direito_virtual` |

## Outras dependências

- `automation.controle_cecilia` → `light.corredor_interruptor_escada_z2m_l1_balizador`
- `automation.jardim_japones_lanterna_unidirecional` → L3 escada → `light.jardim_japones_lanterna_japonesa`
- Dashboard `dashboard-casa`: cards Home Corredor/Sala de Jantar + views Corredor/Sala de Jantar

## Procedimento de restore

**Script automático:** `/root/homelab/scripts/restore-interruptor-escada.py`

```bash
# Opção A — add-on HA MCP a correr (porta 9583)
python3 /root/homelab/scripts/restore-interruptor-escada.py

# Opção B — token de longa duração
echo 'SEU_TOKEN' > /root/.ha-token && chmod 600 /root/.ha-token
python3 /root/homelab/scripts/restore-interruptor-escada.py
```

Passos (feitos pelo script ou manualmente via MCP):

1. Z2M: remover fantasma (se existir), permit join, re-parear
2. Renomear switches `l1`…`l4` para entity_ids finais
3. Criar 4× `switch_as_x` (switch → light)
4. Renomear luzes para entity_ids finais + nomes, áreas, ícones
5. Dispositivo → `Corredor - Interruptor Escada`, área `corredor`
6. Verificar automações e dashboard (referências já apontam para IDs finais)

Após re-parear, o MQTT discovery pode criar `switch.corredor_-_interruptor_escada_l1` (com hífens do nome do dispositivo) — o script trata ambas as variantes.
