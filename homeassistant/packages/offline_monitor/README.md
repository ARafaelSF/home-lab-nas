# Monitor de dispositivos offline (Grafana)

Publica a cada minuto a métrica Influx `device_availability` com a **mesma regra** do `sensor.dispositivos_offline`.

## Componentes

- `custom_templates/device_availability.jinja` — monta o line protocol (`Área — Nome` na tag `device`)
- `rest_command.influx_write_device_availability` — POST no Influx (`home_energy`)
- `rest_command.influx_delete_device_availability` — DELETE só da medição `device_availability`
- Script `script.limpar_historico_dispositivos_offline` — botão no subview Offline (confirmação no tap)
- Automação `automation.influx_exportar_disponibilidade_de_dispositivos` — `time_pattern` `/1`
- Dashboard Grafana (HA addon): **Dispositivos offline** (`uid: dispositivos-offline`)
- Cópia provisionada no Grafana Docker: `compose/monitoring/grafana/dashboards/casa/dispositivos-offline.json`
- JSON de importação no HA: `packages/influxdb_energia/grafana_dispositivos_offline.json`
- Lovelace view `dispositivos-offline`: o `auto-entities` tem de usar o **mesmo filtro** que o sensor (inclui `binary_sensor`/`sensor`). Referência: `../dashboard-dispositivos-offline-filter.json` (corrigido 2026-09-13 — o card omitia esses domínios e o contador ficava a 1 com lista vazia).

## Uso

- **Grafana no HA** (preferido): abrir o add-on Grafana → dashboard `Dispositivos offline`
- Grafana Docker (legado): `http://192.168.3.21:3005/d/dispositivos-offline`
- **Limpar ruído:** no subview Offline → **Limpar histórico offline** (apaga só `device_availability`; o export volta a encher a cada minuto)

Legenda dos gráficos = `Área — Nome do dispositivo` (igual ao dashboard do HA).

## Correção 2026-09-15

Os painéis **Offline agora** e **Dispositivos monitorados** faziam `count()` por tabela (um valor `1` por dispositivo). Passaram a usar `|> group() |> count()` para um total único. Datasource no HA: Flux `HomeAssistant-Homelab` (`cfwrrft8tz1moa` → bucket `home_energy`).

Reimportar no HA (se o ficheiro estiver em `/config`):

```bash
# shell_command.grafana_import_dispositivos_offline
```
