# Configurar MCP do Home Assistant no Cursor

## Add-on em uso: **HA MCP Server** (ha-mcp)

| Item | Valor |
|------|--------|
| Porta | **9583** |
| URL | `http://192.168.3.10:9583/private_XXXXX` (copiar do log do add-on) |
| Autenticação | O path `/private_...` **é** a chave — não compartilhe |

**Não** use `@coolver/home-assistant-mcp` nem porta 8099 — isso é outro projeto (Vibecode).

---

## Parte 1 — No Home Assistant (≈ 5 min)

### 1.1 Adicionar repositório do add-on

1. Abra https://homeassistant.antonio.rafael.nom.br/ (ou `http://192.168.3.10:8123`)
2. **Configurações** → **Add-ons** → **Loja de add-ons**
3. Menu **⋮** (canto superior direito) → **Repositórios**
4. Adicione:
   ```
   https://github.com/coolver/home-assistant-vibecode-agent
   ```
5. **Adicionar** → aguarde atualizar a loja

### 1.2 Instalar o add-on

1. Procure **HA Vibecode Agent**
2. **Instalar** → aguarde
3. Ative **Iniciar na inicialização**
4. **Iniciar**
5. Abra **Abrir interface web** (Web UI)

### 1.3 Copiar a Agent Key

Na Web UI do add-on:

1. Aba **Cursor** (ou a que mostrar a config MCP)
2. Copie a **Agent Key** (chave longa)
3. Guarde — você vai colar no `mcp.json` (não commite no Git)

### 1.4 Testar (opcional)

No notebook, PowerShell:

```powershell
curl http://192.168.3.10:8099/api/health
```

Resposta esperada: JSON com `"status": "healthy"`.

---

## Parte 2 — No computador do Cursor

> **Importante:** O MCP roda no **mesmo PC onde o Cursor está instalado** (seu Windows `C:\Users\arafa\`), **não** dentro da VM Docker do homelab — a menos que você use Cursor só via SSH nesta VM.

### 2.1 Instalar Node.js (se ainda não tiver)

1. https://nodejs.org — versão **24 LTS**
2. Instale com opções padrão
3. Abra **novo** PowerShell:
   ```powershell
   node --version
   npx --version
   ```
   Precisa ser **v20+**.

### 2.2 Onde fica o `mcp.json`

| Uso | Caminho |
|-----|---------|
| **Global (recomendado)** | `C:\Users\arafa\.cursor\mcp.json` |
| Só este projeto remoto | `/root/.cursor/mcp.json` no servidor (só se o Cursor rodar MCP remoto) |

No Cursor: **Ctrl+Shift+P** → digite **"MCP"** → **Cursor Settings: MCP** (ou **Open MCP Config**).

### 2.3 Conteúdo do `mcp.json`

Cole (troque só a chave):

```json
{
  "mcpServers": {
    "home-assistant": {
      "command": "npx",
      "args": ["-y", "@coolver/home-assistant-mcp@latest"],
      "env": {
        "HA_AGENT_URL": "http://192.168.3.10:8099",
        "HA_AGENT_KEY": "SUA_AGENT_KEY_AQUI"
      }
    }
  }
}
```

- **HA_AGENT_URL:** use o IP `192.168.3.10` (funciona na sua LAN; `homeassistant.local` só se o mDNS resolver).
- **HA_AGENT_KEY:** a chave copiada da Web UI do add-on.

Modelo salvo no servidor: `/root/.cursor/mcp.json.example`

### 2.4 Reiniciar o Cursor

Feche o Cursor **por completo** e abra de novo.

### 2.5 Conferir se conectou

1. **Configurações** → **MCP** (ou ícone MCP na barra)
2. Servidor **home-assistant** deve aparecer **verde / conectado**
3. No chat, teste:
   ```
   Conecte ao Home Assistant e liste 5 entidades climate.
   Mostre o status do HA Vibecode Agent.
   ```

---

## Segurança

- **Não** coloque a Agent Key no Git
- Add `/root/.cursor/mcp.json` ao `.gitignore` se usar chave real no servidor
- O Agent só deve ser acessível na **rede local** (não exponha a porta 8099 na internet)

---

## Problemas comuns

| Erro | Solução |
|------|---------|
| `Connection refused` :8099 | Add-on não iniciado no HA |
| `Invalid Agent Key` | Copie de novo na Web UI do add-on |
| `spawn npx ENOENT` | Instale Node.js no **PC do Cursor** e reinicie |
| MCP cinza / sem tools | Reinicie Cursor; confira JSON válido |
| Só funciona em casa | Normal — URL é IP local `192.168.3.10` |

---

## Depois de conectar

Peça no chat, por exemplo:

- *"Instale o package uptime_kuma em /config/packages e reinicie o HA"*
- *"Liste minhas automações e mostre como costumo nomear alias e ícones"*
- *"Crie as automações do Uptime Kuma webhook como editáveis na UI"*

---

## Links

- [HA Vibecode Agent (add-on)](https://github.com/Coolver/home-assistant-vibecode-agent)
- [@coolver/home-assistant-mcp (npm)](https://www.npmjs.com/package/@coolver/home-assistant-mcp)
