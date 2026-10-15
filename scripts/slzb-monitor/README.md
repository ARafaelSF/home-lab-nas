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

## Métricas de atividade

O assinante agora observa passivamente `zigbee2mqtt/#`. O tópico retained
`zigbee2mqtt/bridge/devices` fornece somente o mapa IEEE/friendly name; o
payload completo não é persistido. Mensagens retained, `bridge/*`, grupos,
`availability`, `set`, `get` e nomes desconhecidos são descartados da
atividade individual. Friendly names que contêm `/` são resolvidos pelo
maior prefixo conhecido.

Uma vez por minuto é gravado um evento `device_activity_minute` com o número
de dispositivos que publicaram, contagem total, contagem por IEEE, última
observação, estado do bridge, conexão MQTT e qualidade da janela. A métrica
representa mensagens MQTT publicadas pelo Zigbee2MQTT, não quadros de rádio;
ausência de mensagem não classifica um dispositivo como offline.

O evento `bridge_health` preserva os contadores individuais disponíveis
(`messages`, `messages_per_sec`, `leave_count` e
`network_address_changes`) e calcula deltas somente quando a amostra é
compatível com a anterior. Reinício do processo, reset de contadores ou
mudança do conjunto de dispositivos é marcado explicitamente; não é
convertido em tráfego negativo ou zero.

Quando MQTT, o bridge, o inventário ou o SLZB ficam indisponíveis, o evento
registra a lacuna de observabilidade. O monitor não tenta preencher a lacuna
nem envia comandos.

Para instalar, copiar o serviço para `/etc/systemd/system`, executar
`systemctl daemon-reload` e habilitar/iniciar somente este serviço. A unidade
não altera os serviços existentes.
