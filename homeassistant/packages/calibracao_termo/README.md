# Calibração termohigrómetros

Dash: **Lab → Calibração** (`/lab-fake/calibracao-termo`)

## Uso
1. Coloca os sensores + termómetro calibrado na caixa.
2. Marca **Em uso** só nos que estão no conjunto.
3. Preenche referência °C e % (humidade opcional se não calibrares RH nessa amostra).
4. **Guardar amostra** → append em `/share/calibracao/termo_higro_amostras.csv`

`delta_*` = leitura − referência (positivo = sensor lê mais alto).

## Ficheiros
- `dispositivos.json` — lista de sensores
- `www/calib_termo_guardar.py` — grava CSV
- helpers: `input_boolean.calib_*_em_uso`, `input_number.calib_referencia_*`
