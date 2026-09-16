# Revisão de integrações HA — nomenclatura e vínculos

**Gerado:** 2026-09-13 · **Atualizado:** 2026-09-15 (parar por hoje)  
**Padrão de referência:** BTHome — device `Área - Tipo`; entidade com nome curto do tipo; auxiliares (ex. sensação térmica) **vinculados ao mesmo device**.
**Progresso:** 9/63 feitas · **Continuar em:** `docs/CONTINUAR.md` § Nomenclatura HA · `PENDENCIAS.md` §0  
**Próxima:** `tasmota` (propor antes de aplicar).

- Entradas de configuração: **228**
- Domínios/integrações: **63**

Legenda de prioridade sugerida para a ordem de revisão: **alta** (dispositivos físicos / casa), **média** (helpers/energia), **baixa** (sistema/infra).

## Regra aprovada (2026-09-15)

- **Device:** `Área - Tipo [Qualificador]`. Não incluir marca ou integração, salvo quando forem necessárias para distinguir aparelhos.
- **Nome visível da entidade:** apenas a função no contexto do device, por exemplo `Temperatura`, `Bateria`, `Potência` ou `Reiniciar`.
- **Entity ID:** `domínio.area_tipo_função`, em `snake_case` e sem acentos. Preservar IDs coerentes; alterar somente os inconsistentes.
- **Sufixo de integração no ID:** usar apenas quando houver fontes paralelas ou risco de colisão, por exemplo `_localthings` e `_cloud`.
- **Título da entrada de integração:** alinhar a `Área - Tipo` quando for editável e seguro; evitar títulos técnicos baseados apenas em IP.
- **Vínculos:** entidades auxiliares pertencem ao mesmo device da entidade-fonte; helpers sem device nativo devem ser associados quando a plataforma permitir.
- **Idioma:** **português do Brasil (PT-BR)** nos nomes visíveis, com acentuação correta (ex. *controle*, não *controlo*; *redefinir*, não *repor*).
- **Execução:** uma integração por vez, verificando referências em automações, scripts, templates e dashboards antes de alterar qualquer ID.

## `alexa_media` — prioridade alta

- **Entradas:** arafaelsf@gmail.com - amazon.com
- **Entidades activas (aprox.):** 71
- **Amostra de entidades:** `switch.minha_casa_nao_incomodar, switch.suite_fire_tv_stick_4k_max_nao_incomodar, media_player.escritorio_echo_mediaplayer, media_player.banheiro_social_echo_mediaplayer, media_player.sala_de_tv_echo_mediaplayer, media_player.cozinha_echo_mediaplayer, media_player.oficina_echo_mediaplayer, media_player.brinquedoteca_echo_mediaplayer`
- **Nomenclatura — ajustes:** Devices já no padrão `Área - Echo …`. Entity names curtos (Echo Dot). Sufixo `_mediaplayer` nos entity_id — aceitável ou uniformizar.
- **Vínculos / organização — ajustes:** Reautenticar após restarts. Conferir switches “Não incomodar” e grupo Casa.
- **Estado sugerido:** reauth + revisão leve
- **Revisão conjunta:** [ ] por fazer

## `broadlink` — prioridade alta

- **Entradas:** Sala de TV - BroadLink, Quarto Cecília - BroadLink
- **Entidades activas (aprox.):** 4
- **Amostra de entidades:** `remote.sala_de_tv_remote_broadlink, infrared.sala_de_tv_ir_emitter_broadlink, remote.quarto_cecilia_remote_broadlink, infrared.quarto_cecilia_ir_emitter_broadlink`
- **Nomenclatura — ajustes:** Aplicado 2026-09-15: títulos `Área - BroadLink`; entidades `Controle remoto` / `Emissor IR` (corrigido PT-BR 2026-09-15: *controlo*→*controle*). IDs preservados.
- **Vínculos / organização — ajustes:** OK.
- **Estado sugerido:** concluído neste bloco
- **Revisão conjunta:** [x] feito 2026-09-15

## `bthome` — prioridade alta

- **Entradas:** Sala de TV / Quarto Cecília / Suíte / Escritório / Sala de Jantar / Oficina / Brinquedoteca / Banheiro Social / Banheiro Suíte / Cozinha Externa — Termo-higrômetro
- **Entidades activas (aprox.):** 30
- **Amostra de entidades:** `sensor.sala_de_tv_termo_bateria, sensor.sala_de_tv_termo_temperatura, sensor.sala_de_tv_termo_umidade, sensor.quarto_cecilia_termo_temperatura, sensor.quarto_cecilia_termo_umidade, sensor.quarto_cecilia_termo_bateria, sensor.suite_termo_temperatura, sensor.suite_termo_umidade`
- **Nomenclatura — ajustes:** Aplicado 2026-09-15: títulos das 10 entradas → `Área - Termo-higrômetro` (incl. antiga “Geladeira” → Quarto Cecília); device `Quarto Cecília - Termo-higrômetro`. IDs e nomes curtos das entidades mantidos.
- **Vínculos / organização — ajustes:** Sensação térmica vinculada aos devices BTHome. `sensor.cozinha_termo_sensacao_termica` (sem device) fica para `mqtt`/`template`.
- **Estado sugerido:** concluído neste bloco
- **Revisão conjunta:** [x] feito 2026-09-15

## `esphome` — prioridade alta

- **Entradas:** Ar Condicionado - Quarto Cecília, Gás de Cozinha, Interfone, Caixa d'agua, Água Copasa, Chuveiro Suíte, Ventilador Sala de Jantar, Bancada Oficina, Forno Área Gourmet, Jardim Japonês, Aquecedor Solar
- **Entidades activas (aprox.):** 74
- **Amostra de entidades:** `binary_sensor.ar_condicionado_quarto_cecilia_ventilador_ligado, binary_sensor.ar_condicionado_quarto_cecilia_refrigeracao_ligada, button.ar_condicionado_quarto_cecilia_reiniciar, sensor.ar_condicionado_quarto_cecilia_corrente, sensor.ar_condicionado_quarto_cecilia_tensao, sensor.ar_condicionado_quarto_cecilia_potencia, sensor.ar_condicionado_quarto_cecilia_consumo_total, sensor.ar_condicionado_quarto_cecilia_frequencia`
- **Nomenclatura — ajustes:** Mistura `Tipo - Área` (ex. Ar Condicionado - Quarto Cecília) vs `Área - Tipo`. Uniformizar.
- **Vínculos / organização — ajustes:** OK na maioria (entidades no device). Confirmar áreas (Gás em Terreiro vs Casa).
- **Estado sugerido:** nomenclatura a alinhar
- **Revisão conjunta:** [ ] por fazer

## `hikvision_axpro` — prioridade alta

- **Entradas:** Escritório - Hub AX Pro
- **Entidades activas (aprox.):** 52
- **Amostra de entidades:** `alarm_control_panel.alarme_hikvision_axpro, binary_sensor.cozinha_porta_alto_contato_hikvision_axpro, binary_sensor.cozinha_porta_baixo_contato_hikvision_axpro, sensor.cozinha_porta_alto_temperatura_hikvision_axpro, sensor.cozinha_porta_baixo_temperatura_hikvision_axpro, binary_sensor.escritorio_porta_varanda_contato_hikvision_axpro, sensor.escritorio_porta_varanda_temperatura_hikvision_axpro, binary_sensor.cozinha_porta_terreiro_contato_hikvision_axpro`
- **Nomenclatura — ajustes:** Aplicado 2026-09-15: título entrada `Escritório - Hub AX Pro`; botões `Alarme rápido` / `Limpar alarme rápido`. Devices/entidades já em `Área - Tipo` + nomes curtos. IDs preservados.
- **Vínculos / organização — ajustes:** OK (sensores no device da porta).
- **Estado sugerido:** concluído neste bloco
- **Revisão conjunta:** [x] feito 2026-09-15

## `inkbird_iht2pb` — prioridade alta

- **Entradas:** Inkbird IHT-2PB
- **Entidades activas (aprox.):** 76
- **Amostra de entidades:** `sensor.inkbird_iht_2pb_battery_raw_level, sensor.inkbird_iht_2pb_battery_report_quality, sensor.inkbird_iht_2pb_external_probe_state, sensor.inkbird_iht_2pb_external_probe_summary, sensor.inkbird_iht_2pb_temperature_unit, sensor.inkbird_iht_2pb_backlight_time, sensor.inkbird_iht_2pb_rom_version, sensor.inkbird_iht_2pb_device_name`
- **Nomenclatura — ajustes:** Prefixo `inkbird_iht_…` técnico; área Cozinha Externa.
- **Vínculos / organização — ajustes:** GATT instável (já em pendências §4). Agrupar sensores no device.
- **Estado sugerido:** rever + estabilidade
- **Revisão conjunta:** [ ] por fazer

## `localthings` — prioridade alta

- **Entradas:** Suíte / Escritório / Sala de TV — Ar-condicionado
- **Entidades activas (aprox.):** 59
- **Amostra de entidades:** `sensor.suite_ar_condicionado_temperatura_localthings, sensor.suite_ar_condicionado_umidade_localthings, sensor.suite_ar_condicionado_potencia_localthings, sensor.suite_ar_condicionado_energia_localthings, climate.suite_ar_condicionado_localthings, sensor.suite_ar_condicionado_energia_economizada_localthings, switch.suite_ar_condicionado_display_lighting_localthings, switch.suite_ar_condicionado_sound_effect_localthings`
- **Nomenclatura — ajustes:** Aplicado 2026-09-15: títulos das entradas e devices → `Área - Ar-condicionado`; nomes EN→PT-BR. Correção PT-BR 2026-09-15: *em curso*→*em andamento*, *Repor*→*Redefinir*. IDs `…_localthings` preservados.
- **Vínculos / organização — ajustes:** Medidores utility_meter ligados aos devices corretos.
- **Estado sugerido:** concluído neste bloco
- **Revisão conjunta:** [x] feito 2026-09-15

## `localtuya` — prioridade alta

- **Entradas:** LocalTuya
- **Entidades activas (aprox.):** 39
- **Amostra de entidades:** `switch.oficina_soldador_localtuya, switch.oficina_repelente_localtuya, cover.garagem_portao_menor_localtuya, cover.garagem_portao_maior_localtuya, light.alarme_indicacao_luz_localtuya, number.alarme_indicacao_temporizador_localtuya, light.brinquedoteca_nebulosa_localtuya, light.brinquedoteca_nebulosa_estrelas_localtuya`
- **Nomenclatura — ajustes:** Aplicado 2026-09-15: título da entrada `LocalTuya`; device `Sistema - Indicador de alarme`; entidade `Luz`; cabeceira Antônio. Restantes devices já estavam em `Área - Tipo`. IDs preservados.
- **Vínculos / organização — ajustes:** Entidades do mesmo aparelho no mesmo device.
- **Estado sugerido:** concluído neste bloco
- **Revisão conjunta:** [x] feito 2026-09-15

## `midea_ac_lan` — prioridade alta

- **Entradas:** Geladeira
- **Entidades activas (aprox.):** 8
- **Amostra de entidades:** `sensor.cozinha_geladeira_midea_temperatura_refrigerador, sensor.cozinha_geladeira_midea_temperatura_configurada_refrigerador, sensor.cozinha_geladeira_midea_temperatura_freezer, sensor.cozinha_geladeira_midea_temperatura_configurada_freezer, sensor.cozinha_geladeira_midea_consumo_energia, sensor.cozinha_geladeira_midea_umidade, binary_sensor.cozinha_geladeira_midea_porta_refrigerador, binary_sensor.cozinha_geladeira_midea_porta_freezer`
- **Nomenclatura — ajustes:** Conferir ACs vs área.
- **Vínculos / organização — ajustes:** —
- **Estado sugerido:** rever
- **Revisão conjunta:** [ ] por fazer

## `mqtt` — prioridade alta

- **Entradas:** Mosquitto broker
- **Entidades activas (aprox.):** 388
- **Amostra de entidades:** `binary_sensor.zigbee2mqtt_bridge_connection_state, button.zigbee2mqtt_bridge_restart, select.zigbee2mqtt_bridge_log_level, sensor.zigbee2mqtt_bridge_version, switch.zigbee2mqtt_bridge_permit_join, sensor.tensao_fase_1, sensor.tensao_fase_3, sensor.corrente_fase_1`
- **Nomenclatura — ajustes:** Maior volume (Z2M). Rever friendly_name no Zigbee2MQTT para `Área - Tipo` e entity_id estável.
- **Vínculos / organização — ajustes:** Garantir que sensores auxiliares (bateria, linkquality) fiquem no mesmo device que o interruptor/sensor principal.
- **Estado sugerido:** rever por área
- **Revisão conjunta:** [ ] por fazer

## `smartthings` — prioridade alta

- **Entradas:** Casa
- **Entidades activas (aprox.):** 36
- **Amostra de entidades:** `climate.suite_ar_condicionado_cloud, select.suite_ar_condicionado_dust_filter_alarm_threshold_cloud, sensor.suite_ar_condicionado_diferenca_de_energia_cloud, sensor.suite_ar_condicionado_potencia_da_energia_cloud, sensor.suite_ar_condicionado_energia_economizada_cloud, switch.suite_ar_condicionado_display_lighting_cloud, sensor.suite_ar_condicionado_temperatura_cloud, sensor.suite_ar_condicionado_umidade_cloud`
- **Nomenclatura — ajustes:** Aplicado 2026-09-15: devices `Área - Ar-condicionado Cloud`; climate `Ar-condicionado`; nomes PT preenchidos. IDs `…_cloud` preservados.
- **Vínculos / organização — ajustes:** —
- **Estado sugerido:** concluído neste bloco
- **Revisão conjunta:** [x] feito 2026-09-15

## `sonoff` — prioridade alta

- **Entradas:** arafaelsf@yahoo.com.br
- **Entidades activas (aprox.):** 53
- **Amostra de entidades:** `switch.escritorio_desktop_sonoff, switch.sistema_home_assistant_sonoff, switch.sala_de_tv_multimidia_sonoff, sensor.sala_de_tv_multimidia_potencia_sonoff, sensor.sistema_home_assistant_potencia_sonoff, switch.sala_de_tv_repelente_sonoff, switch.garagem_tomada_sonoff, switch.suite_repelente_sonoff`
- **Nomenclatura — ajustes:** Conferir devices e entity_id vs área.
- **Vínculos / organização — ajustes:** Sensores de energia/potência no mesmo device da tomada.
- **Estado sugerido:** rever
- **Revisão conjunta:** [ ] por fazer

## `tapo_control` — prioridade alta

- **Entradas:** 192.168.5.11, 192.168.5.12, 192.168.6.10, 192.168.6.11, 192.168.5.10
- **Entidades activas (aprox.):** 299
- **Amostra de entidades:** `camera.camera_cecilia_hd_stream, camera.camera_cecilia_sd_stream, button.camera_cecilia_reboot, button.camera_cecilia_format_sd_card, button.camera_cecilia_manual_alarm_start, button.camera_cecilia_manual_alarm_stop, button.camera_cecilia_sync_time, button.camera_cecilia_calibrate`
- **Nomenclatura — ajustes:** Muitos botões com nome longo `Câmera X Move …` em vez de tipo curto no device.
- **Vínculos / organização — ajustes:** Manter tudo no device da câmara; esconder/desactivar entidades pouco usadas.
- **Estado sugerido:** rever
- **Revisão conjunta:** [ ] por fazer

## `tasmota` — prioridade alta

- **Entradas:** Tasmota
- **Entidades activas (aprox.):** 26
- **Amostra de entidades:** `sensor.sala_de_jantar_robo_ultima_reinicializacao_tasmota, sensor.sala_de_jantar_robo_motivo_reinicio_tasmota, switch.sala_de_jantar_robo_tasmota, switch.escritorio_servidor_minipc_tasmota, sensor.escritorio_servidor_minipc_ultima_reinicializacao_tasmota, sensor.escritorio_servidor_minipc_motivo_reinicio_tasmota, sensor.escritorio_servidor_minipc_energia_total_tasmota, sensor.escritorio_servidor_minipc_potencia_tasmota`
- **Nomenclatura — ajustes:** Alguns nomes em inglês (`WiFi Connect Count`). Device Monitores OK.
- **Vínculos / organização — ajustes:** Auxiliares no device Tasmota correspondente.
- **Estado sugerido:** rever
- **Revisão conjunta:** [ ] por fazer

## `ttlock` — prioridade alta

- **Entradas:** Sala de TV - Fechadura
- **Entidades activas (aprox.):** 8
- **Amostra de entidades:** `lock.fechadura_sala, sensor.fechadura_sala_battery, sensor.fechadura_sala_last_operator, sensor.fechadura_sala_last_trigger, binary_sensor.fechadura_sala_passage_mode, switch.fechadura_sala_auto_lock, switch.fechadura_sala_lock_sound, binary_sensor.ttlockantonio_status`
- **Nomenclatura — ajustes:** Aplicado 2026-09-15 (PT-BR): título/entrada e device `Sala de TV - Fechadura`; gateway `Sistema - Gateway TTLock`; entidades `Fechadura`, `Bateria`, `Último operador`, `Último disparo`, `Modo passagem`, `Trancar automaticamente`, `Som`, `Estado`. IDs preservados.
- **Vínculos / organização — ajustes:** OK.
- **Estado sugerido:** concluído neste bloco
- **Revisão conjunta:** [x] feito 2026-09-15

## `tuya` — prioridade alta

- **Entradas:** arafaelsf@gmail.com
- **Entidades activas (aprox.):** 2
- **Amostra de entidades:** `sensor.suite_relogio_tuya_temperatura, sensor.suite_relogio_tuya_umidade`
- **Nomenclatura — ajustes:** Device `Suíte - Relógio` e entidades OK. Sufixo `_tuya` mantido (paralelo ao LocalTuya). Título da conta cloud deixado.
- **Vínculos / organização — ajustes:** OK no device.
- **Estado sugerido:** concluído (validado)
- **Revisão conjunta:** [x] feito 2026-09-15

## `unifi` — prioridade alta

- **Entradas:** Default
- **Entidades activas (aprox.):** 79
- **Amostra de entidades:** `sensor.escritorio_gateway_unifi_temperatura, sensor.escritorio_gateway_unifi_memoria, sensor.escritorio_gateway_unifi_cpu, sensor.escritorio_ap_unifi_mac_uplink, button.escritorio_ap_unifi_reiniciar, device_tracker.escritorio_ap_unifi, sensor.escritorio_ap_unifi_clientes, sensor.escritorio_ap_unifi_uptime`
- **Nomenclatura — ajustes:** Infra OK na maior parte; trackers com MAC/nome técnico (C200, midea_ca_0265).
- **Vínculos / organização — ajustes:** N/A para trackers.
- **Estado sugerido:** opcional
- **Revisão conjunta:** [ ] por fazer

## `xiaomi_ble` — prioridade alta

- **Entradas:** *(removidas 2026-09-15)*
- **Entidades activas (aprox.):** 0
- **Nomenclatura — ajustes:** Removidas as 3 entradas técnicas `LYWSD03MMC 1904/6ED4/8F33` — duplicavam BTHome (Banheiro Social, Banheiro Suíte, Cozinha Externa). Sem entidades/devices ligados.
- **Vínculos / organização — ajustes:** —
- **Estado sugerido:** concluído (removido)
- **Revisão conjunta:** [x] feito 2026-09-15

## `adaptive_lighting` — prioridade média

- **Entradas:** Suíte
- **Entidades activas (aprox.):** 4
- **Amostra de entidades:** `switch.adaptive_lighting_suite_sleep_mode, switch.adaptive_lighting_suite_adapt_color, switch.adaptive_lighting_suite_adapt_brightness, switch.adaptive_lighting_suite`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `group` — prioridade média

- **Entradas:** Portas Segurança, Saida - desligar (switches)
- **Entidades activas (aprox.):** 2
- **Amostra de entidades:** `binary_sensor.portas_seguranca, switch.saida_desligar_switches`
- **Nomenclatura — ajustes:** Helpers de sistema — OK.
- **Vínculos / organização — ajustes:** N/A
- **Estado sugerido:** ok
- **Revisão conjunta:** [ ] por fazer

## `ha_washdata` — prioridade média

- **Entradas:** Lava Louça, Lava Roupa
- **Entidades activas (aprox.):** 34
- **Amostra de entidades:** `sensor.lava_louca_state, sensor.lava_louca_program, sensor.lava_louca_time_remaining, sensor.lava_louca_progress, sensor.lava_louca_current_power, sensor.lava_louca_elapsed_time, binary_sensor.lava_louca_running, select.lava_louca_cycle_program`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `smlight` — prioridade média

- **Entradas:** SLZB-06
- **Entidades activas (aprox.):** 13
- **Amostra de entidades:** `binary_sensor.slzb_06_ethernet, binary_sensor.slzb_06_internet, button.slzb_06_reiniciar_core, button.slzb_06_reiniciar_zigbee, sensor.slzb_06_connection_mode, sensor.slzb_06_firmware_channel, sensor.slzb_06_core_chip_temp, sensor.slzb_06_zigbee_chip_temp`
- **Nomenclatura — ajustes:** Coordinator Zigbee — sistema.
- **Vínculos / organização — ajustes:** —
- **Estado sugerido:** baixa
- **Revisão conjunta:** [ ] por fazer

## `solarman` — prioridade média

- **Entradas:** Usina 1, Usina 2
- **Entidades activas (aprox.):** 110
- **Amostra de entidades:** `sensor.usina_1_update_interval, sensor.usina_1_device, sensor.usina_1_device_state, sensor.usina_1_today_production, sensor.usina_1_total_production, sensor.usina_1_today_production_1, sensor.usina_1_today_production_2, sensor.usina_1_today_production_3`
- **Nomenclatura — ajustes:** Usinas — rever nomes PT vs técnicos; setup com erros not_ready.
- **Vínculos / organização — ajustes:** Sensores por usina no mesmo device.
- **Estado sugerido:** rever + saúde
- **Revisão conjunta:** [ ] por fazer

## `tarifas_energia_brasil` — prioridade média

- **Entradas:** CEMIG-D
- **Entidades activas (aprox.):** 9
- **Amostra de entidades:** `sensor.tarifas_cemig_d_tarifa_vigente, sensor.tarifas_cemig_d_bandeira_vigente, sensor.tarifas_cemig_d_conexao_com_a_aneel, sensor.tarifas_cemig_d_ultima_atualizacao, sensor.tarifas_cemig_d_data_competencia_bandeira, sensor.tarifas_cemig_d_data_competencia_tarifa, sensor.sistema_tarifas_cemig_d_data_inicio_vigencia, sensor.sistema_tarifas_cemig_d_data_fim_vigencia`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `template` — prioridade média

- **Entradas:** Lava Louça - Energia 1x, Lava Roupa - Energia 1x, Contador - Luzes Acesas, Contador - Ar-Condicionado Ligado, Consumo da Casa - Hoje, Contador - Portas e Janelas Abertas, Contador - Repelente Ligado, Contador - EchoDot Tocando, Hidrômetro Medidor, Hidrômetro Copasa, Medidor Gás, Lava Roupa - Potência 1x…
- **Entidades activas (aprox.):** 46
- **Amostra de entidades:** `sensor.lavanderia_lava_louca_energia_1x, sensor.lavanderia_lava_roupa_energia_1x, sensor.sistema_contador_ar_condicionado_ligado, sensor.casa_consumo_hoje, sensor.sistema_contador_portas_e_janelas_abertas, sensor.sistema_contador_repelente_ligado, sensor.sistema_contador_echodot_tocando, sensor.casa_hidrometro_medidor`
- **Nomenclatura — ajustes:** Vários com nome longo no próprio sensor; sensação térmica já curta.
- **Vínculos / organização — ajustes:** Sensação térmica: vincular todas ao device do termo (cozinha solta). Contadores no device Contadores da Casa.
- **Estado sugerido:** rever vínculos
- **Revisão conjunta:** [ ] por fazer

## `utility_meter` — prioridade média

- **Entradas:** HomeAssistant, Multimídia Sala de TV, Ar-Condicionado Suíte, Ar-Condicionado Escritório, Ar-Condicionado Sala de TV, Usina Solar, Lava Louças, Lava Roupas, Ar-Condicionado Cecília, Gás, Água, Geladeira…
- **Entidades activas (aprox.):** 26
- **Amostra de entidades:** `sensor.sistema_home_assistant_medidor_sonoff, sensor.sala_de_tv_multimidia_medidor_sonoff, sensor.suite_ar_condicionado_medidor_localthings, sensor.escritorio_ar_condicionado_medidor_localthings, sensor.sala_de_tv_ar_condicionado_medidor_localthings, sensor.casa_usina_solar, sensor.lavanderia_lava_loucas, sensor.lavanderia_lava_roupas`
- **Nomenclatura — ajustes:** Alguns sem área/device (`geladeira_antiga`, usina).
- **Vínculos / organização — ajustes:** Ligar medidores ao device fonte de energia.
- **Estado sugerido:** rever
- **Revisão conjunta:** [ ] por fazer

## `adguard` — prioridade baixa

- **Entradas:** 192.168.3.21
- **Entidades activas (aprox.):** 13
- **Amostra de entidades:** `sensor.adguard_home_taxa_de_bloqueio_de_consultas_dns, sensor.adguard_home_consultas_de_dns_bloqueadas, sensor.adguard_home_consultas_de_dns, switch.adguard_home_protecao, sensor.adguard_home_controle_dos_pais_bloqueado, sensor.adguard_home_navegacao_segura_bloqueada, sensor.adguard_home_velocidade_media_de_processamento, switch.adguard_home_controle_dos_pais`
- **Nomenclatura — ajustes:** Sistema — OK.
- **Vínculos / organização — ajustes:** N/A
- **Estado sugerido:** ok
- **Revisão conjunta:** [ ] por fazer

## `alexa_todo` — prioridade baixa

- **Entradas:** arafaelsf@gmail.com
- **Entidades activas (aprox.):** 7
- **Amostra de entidades:** `todo.lista_compras, todo.lista_principal, todo.lista_escritorio, todo.lista_home_assistant, todo.lista_filmes, todo.lista_remedios, todo.alexa_todo_congelador`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `analytics` — prioridade baixa

- **Entradas:** Analytics
- **Entidades activas (aprox.):** 0
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `apple_tv` — prioridade baixa

- **Entradas:** zj-airplay (Apple TV 3)
- **Entidades activas (aprox.):** 0
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `backup` — prioridade baixa

- **Entradas:** Backup
- **Entidades activas (aprox.):** 5
- **Amostra de entidades:** `event.backup_automatic_backup, sensor.backup_backup_manager_state, sensor.backup_next_scheduled_automatic_backup, sensor.backup_last_successful_automatic_backup, sensor.backup_last_attempted_automatic_backup`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `bluetooth` — prioridade baixa

- **Entradas:** gas-cozinha (08:3A:F2:67:EA:56), interfone (EC:62:60:9A:3F:8A), caixa-dagua (EC:62:60:99:DA:12), agua-copasa (30:C6:F7:00:36:82), ventilador-sala-de-janta (78:21:84:7D:D3:E2), forno-area-gourmet (58:CF:79:1E:D6:92), jardim-japones (78:21:84:7B:F4:AA), aquecedor-solar (40:91:51:9B:A8:CE), Realtek Bluetooth Radio (1C:79:2D:94:09:7E)
- **Entidades activas (aprox.):** 0
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `co2signal` — prioridade baixa

- **Entradas:** Electricity Maps
- **Entidades activas (aprox.):** 2
- **Amostra de entidades:** `sensor.electricity_maps_intensidade_de_co2, sensor.electricity_maps_percentual_de_combustiveis_fosseis_da_rede`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `forecast_solar` — prioridade baixa

- **Entradas:** Casa
- **Entidades activas (aprox.):** 8
- **Amostra de entidades:** `sensor.energy_production_today, sensor.energy_production_today_remaining, sensor.energy_production_tomorrow, sensor.power_highest_peak_time_today, sensor.power_highest_peak_time_tomorrow, sensor.power_production_now, sensor.energy_current_hour, sensor.energy_next_hour`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `go2rtc` — prioridade baixa

- **Entradas:** go2rtc
- **Entidades activas (aprox.):** 0
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `google_generative_ai_conversation` — prioridade baixa

- **Entradas:** Google Generative AI
- **Entidades activas (aprox.):** 4
- **Amostra de entidades:** `ai_task.google_ai_task, conversation.google_ai_conversation, stt.google_ai_stt, tts.google_ai_tts`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `google_translate` — prioridade baixa

- **Entradas:** Google Translate text-to-speech
- **Entidades activas (aprox.):** 1
- **Amostra de entidades:** `tts.google_translate_en_com`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `ha_companion` — prioridade baixa

- **Entradas:** HA Companion - amazfit_bip_6_antonio
- **Entidades activas (aprox.):** 74
- **Amostra de entidades:** `sensor.sistema_amazfit_bip_6_antonio_amazfit_watch_age, sensor.sistema_amazfit_bip_6_antonio_amazfit_watch_air_pressure, sensor.sistema_amazfit_bip_6_antonio_amazfit_watch_altitude, binary_sensor.sistema_amazfit_bip_6_antonio_amazfit_watch_always_on_display, sensor.sistema_amazfit_bip_6_antonio_amazfit_watch_app_version, sensor.sistema_amazfit_bip_6_antonio_amazfit_watch_awake_time, sensor.sistema_amazfit_bip_6_antonio_amazfit_watch_battery, sensor.sistema_amazfit_bip_6_antonio_amazfit_watch_blood_oxygen`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `ha_mcp_tools` — prioridade baixa

- **Entradas:** HA-MCP File & YAML Tools
- **Entidades activas (aprox.):** 0
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `hacs` — prioridade baixa

- **Entradas:** ?
- **Entidades activas (aprox.):** 31
- **Amostra de entidades:** `update.hacs_update, update.sonoff_lan_update, update.custom_brand_icons_update, update.local_tuya_update, update.adaptive_lighting_update, update.smartir_update, update.webrtc_camera_update, update.magic_areas_update`
- **Nomenclatura — ajustes:** HACS — sistema.
- **Vínculos / organização — ajustes:** N/A
- **Estado sugerido:** ignorar
- **Revisão conjunta:** [ ] por fazer

## `hassio` — prioridade baixa

- **Entradas:** Supervisor
- **Entidades activas (aprox.):** 19
- **Amostra de entidades:** `update.home_assistant_supervisor_update, update.home_assistant_core_update, update.home_assistant_operating_system_update, update.matter_server_update, update.mosquitto_broker_update, update.samba_share_update, update.tasmoadmin_update, update.studio_code_server_update`
- **Nomenclatura — ajustes:** Supervisor — não aplicar padrão de áreas.
- **Vínculos / organização — ajustes:** N/A
- **Estado sugerido:** ignorar
- **Revisão conjunta:** [ ] por fazer

## `history_stats` — prioridade baixa

- **Entradas:** Z2M — Quedas bridge (24h), Z2M — Tempo offline (24h)
- **Entidades activas (aprox.):** 2
- **Amostra de entidades:** `sensor.sistema_zigbee2mqtt_bridge_z2m_quedas_bridge_24h, sensor.sistema_zigbee2mqtt_bridge_z2m_tempo_offline_24h`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `homekit_controller` — prioridade baixa

- **Entradas:** AOC H302X 07E5 ( Television )
- **Entidades activas (aprox.):** 0
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `ibeacon` — prioridade baixa

- **Entradas:** ibeacon
- **Entidades activas (aprox.):** 0
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `influxdb` — prioridade baixa

- **Entradas:** home_energy (http://192.168.3.21:8086)
- **Entidades activas (aprox.):** 0
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `ld2410_ble` — prioridade baixa

- **Entradas:** HLK-LD2410_86F7 (86F7)
- **Entidades activas (aprox.):** 0
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `local_todo` — prioridade baixa

- **Entradas:** Baterias Para Trocar, Zigbee Parear, Contas Mensais, NAS
- **Entidades activas (aprox.):** 4
- **Amostra de entidades:** `todo.baterias_para_trocar, todo.zigbee_parear, todo.contas_mensais, todo.nas`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `magic_areas` — prioridade baixa

- **Entradas:** Brinquedoteca
- **Entidades activas (aprox.):** 0
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `matter` — prioridade baixa

- **Entradas:** Matter
- **Entidades activas (aprox.):** 0
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `met` — prioridade baixa

- **Entradas:** Home
- **Entidades activas (aprox.):** 1
- **Amostra de entidades:** `weather.forecast_casa`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `min_max` — prioridade baixa

- **Entradas:** SLZB — Temp máxima chips
- **Entidades activas (aprox.):** 1
- **Amostra de entidades:** `sensor.slzb_temp_maxima_chips`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `mobile_app` — prioridade baixa

- **Entradas:** Edge Antonio, Edge Renata
- **Entidades activas (aprox.):** 10
- **Amostra de entidades:** `device_tracker.edge_antonio, sensor.edge_antonio_battery_level, sensor.edge_antonio_battery_state, sensor.edge_antonio_charger_type, notify.edge_antonio, device_tracker.edge_renata, sensor.edge_renata_battery_level, sensor.edge_renata_battery_state`
- **Nomenclatura — ajustes:** Telemóveis — fora do padrão de áreas da casa.
- **Vínculos / organização — ajustes:** N/A
- **Estado sugerido:** ignorar / baixa
- **Revisão conjunta:** [ ] por fazer

## `onedrive` — prioridade baixa

- **Entradas:** Antonio Rafael da Silva Filho's OneDrive
- **Entidades activas (aprox.):** 3
- **Amostra de entidades:** `sensor.onedrive_armazenamento_usado, sensor.onedrive_armazenamento_restante, sensor.onedrive_estado_da_unidade`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `radio_browser` — prioridade baixa

- **Entradas:** Radio Browser
- **Entidades activas (aprox.):** 0
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `roku` — prioridade baixa

- **Entradas:** 43" AOC Roku TV
- **Entidades activas (aprox.):** 2
- **Amostra de entidades:** `remote.suite_tv_roku, media_player.suite_tv_roku`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `statistics` — prioridade baixa

- **Entradas:** SLZB — Média core 24h, SLZB — Média zigbee 24h
- **Entidades activas (aprox.):** 2
- **Amostra de entidades:** `sensor.sistema_slzb_06_slzb_media_core_24h, sensor.sistema_slzb_06_slzb_media_zigbee_24h`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `sun` — prioridade baixa

- **Entradas:** Sun
- **Entidades activas (aprox.):** 6
- **Amostra de entidades:** `sensor.sun_next_dawn, sensor.sun_next_dusk, sensor.sun_next_midnight, sensor.sun_next_noon, sensor.sun_next_rising, sensor.sun_next_setting`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `switch_as_x` — prioridade baixa

- **Entradas:** Garagen, Arandela, Lustre, Box Suíte, Espelho Suíte, Pia Suíte, Bancada Cozinha, Espelho Banheiro Social, Luz Brinquedoteca, Luz Banheiro Social, Luz Cozinha, Luz Oficina…
- **Entidades activas (aprox.):** 41
- **Amostra de entidades:** `light.garagem_interruptor_cozinha_z2m_l2_garagen, light.sala_de_jantar_interruptor_sala_de_jantar_z2m_l4_arandela, light.sala_de_jantar_interruptor_sala_de_jantar_z2m_l1_lustre, light.banheiro_suite_interruptor_banheiro_suite_z2m_l2_box_suite, light.banheiro_suite_interruptor_banheiro_suite_z2m_l3_espelho_suite, light.banheiro_suite_interruptor_banheiro_suite_z2m_l4_pia_suite, light.cozinha_bancada_sonoff, light.banheiro_social_espelho_sonoff`
- **Nomenclatura — ajustes:** Herdam da entidade original — rever após a fonte.
- **Vínculos / organização — ajustes:** Manter ligação à switch-fonte.
- **Estado sugerido:** depois das fontes
- **Revisão conjunta:** [ ] por fazer

## `systemmonitor` — prioridade baixa

- **Entradas:** System Monitor
- **Entidades activas (aprox.):** 8
- **Amostra de entidades:** `sensor.system_monitor_disco_livre, sensor.system_monitor_uso_do_disco, sensor.system_monitor_utilizacao_do_disco, sensor.system_monitor_ultima_inicializacao, sensor.system_monitor_memoria_livre, sensor.system_monitor_utilizacao_de_memoria, sensor.system_monitor_uso_de_memoria, sensor.system_monitor_uso_do_processador`
- **Nomenclatura — ajustes:** Sistema HA — não aplicar padrão de áreas.
- **Vínculos / organização — ajustes:** N/A
- **Estado sugerido:** ignorar
- **Revisão conjunta:** [ ] por fazer

## `telegram_bot` — prioridade baixa

- **Entradas:** Homeassistant 2026
- **Entidades activas (aprox.):** 3
- **Amostra de entidades:** `event.homeassistantantonio_update_event, notify.homeassistantantonio_antonio_rafael_664449565, notify.homeassistant_2026_renata_1071303595`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `threshold` — prioridade baixa

- **Entradas:** SLZB — Core temp alta, SLZB — Zigbee temp alta
- **Entidades activas (aprox.):** 2
- **Amostra de entidades:** `binary_sensor.sistema_slzb_06_slzb_core_temp_alta, binary_sensor.sistema_slzb_06_slzb_zigbee_temp_alta`
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `tplink` — prioridade baixa

- **Entradas:** Câmera Cecília C200, Câmera Brinquedoteca C210, Câmera Suíte C200, Câmera Portão C500, Câmera Garagem C320WS
- **Entidades activas (aprox.):** 0
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

## `webrtc` — prioridade baixa

- **Entradas:** WebRTC Camera
- **Entidades activas (aprox.):** 0
- **Nomenclatura — ajustes:** Rever manualmente face ao padrão Área + Tipo (sem alteração automática nesta fase).
- **Vínculos / organização — ajustes:** Confirmar que sensores auxiliares estão no mesmo device que a entidade-fonte.
- **Estado sugerido:** pendente
- **Revisão conjunta:** [ ] por fazer

