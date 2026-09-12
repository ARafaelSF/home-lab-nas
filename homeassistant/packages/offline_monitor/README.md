# Monitor de dispositivos offline (Grafana)

Publica a cada minuto a métrica Influx `device_availability` com a **mesma regra** do `sensor.dispositivos_offline`.

## Componentes

- `custom_templates/device_availability.jinja` — monta o line protocol (`Área — Nome` na tag `device`)
- `rest_command.influx_write_device_availability` — POST no Influx (`home_energy`)
- Automação `automation.influx_exportar_disponibilidade_de_dispositivos` — `time_pattern` `/1`
- Dashboard Grafana: **Casa → Dispositivos offline** (`uid: dispositivos-offline`)

## Uso

Abrir `http://192.168.3.21:3005/d/dispositivos-offline` e escolher o intervalo de tempo.
Legenda dos gráficos = `Área — Nome do dispositivo` (igual ao dashboard do HA).
