# Monitor de dispositivos offline (Grafana)

Publica a cada minuto a métrica Influx `device_availability` com a **mesma regra** do `sensor.dispositivos_offline`.

## Componentes

- `custom_templates/device_availability.jinja` — monta o line protocol (`Área — Nome` na tag `device`)
- `rest_command.influx_write_device_availability` — POST no Influx (`home_energy`)
- Automação `automation.influx_exportar_disponibilidade_de_dispositivos` — `time_pattern` `/1`
- Dashboard Grafana: **Casa → Dispositivos offline** (`uid: dispositivos-offline`)
- Lovelace view `dispositivos-offline`: o `auto-entities` tem de usar o **mesmo filtro** que o sensor (inclui `binary_sensor`/`sensor`). Referência: `../dashboard-dispositivos-offline-filter.json` (corrigido 2026-09-13 — o card omitia esses domínios e o contador ficava a 1 com lista vazia).

## Uso

Abrir `http://192.168.3.21:3005/d/dispositivos-offline` e escolher o intervalo de tempo.
Legenda dos gráficos = `Área — Nome do dispositivo` (igual ao dashboard do HA).
