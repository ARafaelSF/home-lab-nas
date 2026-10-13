# Monitor passivo do SLZB-06

Monitor somente leitura, executado no HomeLab. A cada 60 segundos consulta
os endpoints HTTP de estado e log do SLZB-06 e assina passivamente os tópicos
diagnósticos do Zigbee2MQTT. Não abre a porta TCP 6638, não publica MQTT e
não envia comandos ao coordenador.

Os eventos são JSONL em `/var/lib/slzb-monitor/events.jsonl`, fora do Git,
com retenção aproximada de 14 dias e limite de 100 MiB. Credenciais MQTT vêm
do `EnvironmentFile` protegido já usado pelo HomeLab e nunca são gravadas.

Os endpoints SMLIGHT disponíveis neste equipamento são `api2?action=0&page=0`
(status) e `api2?action=5` (log interno). Os endpoints genéricos `/metrics`,
`/ha_info` e `/ha_sensors` não estavam disponíveis; o monitor não os simula.

Para instalar, copiar o serviço para `/etc/systemd/system`, executar
`systemctl daemon-reload` e habilitar/iniciar somente este serviço. A unidade
não altera os serviços existentes.
