# Snapshot pré–Alexa Devices Last Called (20260907_104420)

Cópia dos YAMLs live do HA (`/config` via Samba) **antes** de migrar last_alexa
para `event.*_voice_event` (Alexa Devices).

Para reverter manualmente, copiar de volta para `/mnt/ha-config/` (ou `/config` no HA)
e `script.reload` / `automation.reload` / `template.reload`.
