# 🔌 Integração MCP no Codex Wrapper Cloud Run

## 📋 Visão Geral

O Codex possui suporte nativo para **Model Context Protocol (MCP)**, permitindo integração com servidores MCP externos que fornecem ferramentas adicionais.

## ✅ MCP Pipedrive Configurado

O wrapper já está configurado para usar o **MCP Pipedrive** deployado no Google Cloud Run.

### 🎯 Configuração Atual

**Arquivo:** `config.toml`

```toml
[mcp_servers.pipedrive]
url = "https://pipedrive-mcp-467992722695.us-central1.run.app/sse"
startup_timeout_sec = 30
tool_timeout_sec = 120
```

**Variável de Ambiente:** `.env`

```bash
PIPEDRIVE_API_TOKEN=b2afb1e6ba1d5ba44745e05e4ea6d7e2faf93296
```

### 🛠️ Ferramentas Disponíveis (30 no total)

O MCP Pipedrive fornece **30 ferramentas** para interagir com a API do Pipedrive:

#### 📊 Deals (Negócios)
- `list_deals_from_pipedrive` - Listar negócios
- `create_deal_in_pipedrive` - Criar negócio
- `update_deal_in_pipedrive` - Atualizar negócio
- `get_deal_from_pipedrive` - Obter detalhes de negócio
- `delete_deal_in_pipedrive` - Deletar negócio

#### 👥 Persons (Pessoas)
- `list_persons_from_pipedrive` - Listar pessoas
- `create_person_in_pipedrive` - Criar pessoa
- `update_person_in_pipedrive` - Atualizar pessoa
- `get_person_from_pipedrive` - Obter detalhes de pessoa
- `delete_person_in_pipedrive` - Deletar pessoa

#### 🏢 Organizations (Organizações)
- `list_organizations_from_pipedrive` - Listar organizações
- `create_organization_in_pipedrive` - Criar organização
- `update_organization_in_pipedrive` - Atualizar organização
- `get_organization_from_pipedrive` - Obter detalhes de organização
- `delete_organization_in_pipedrive` - Deletar organização

#### 📝 Activities (Atividades)
- `list_activities_from_pipedrive` - Listar atividades
- `create_activity_in_pipedrive` - Criar atividade
- `update_activity_in_pipedrive` - Atualizar atividade
- `get_activity_from_pipedrive` - Obter detalhes de atividade
- `delete_activity_in_pipedrive` - Deletar atividade

#### 📋 Pipelines e Stages
- `list_pipelines_from_pipedrive` - Listar pipelines
- `list_stages_from_pipedrive` - Listar estágios
- `get_pipeline_from_pipedrive` - Obter detalhes de pipeline

#### 👤 Users
- `list_users_from_pipedrive` - Listar usuários
- `get_current_user_from_pipedrive` - Obter usuário atual

#### 🏷️ Outros
- `list_products_from_pipedrive` - Listar produtos
- `search_pipedrive` - Busca global
- `list_notes_from_pipedrive` - Listar notas
- `create_note_in_pipedrive` - Criar nota
- `list_custom_fields_from_pipedrive` - Listar campos personalizados

## 🚀 Como Usar

### 1. Via CLI Local (conectando ao Cloud)

```bash
# O CLI local automaticamente carrega a configuração do config.toml
codex exec "Liste os 10 últimos negócios do Pipedrive"
```

### 2. Via API do Wrapper

```bash
curl -X POST https://sua-url-cloud-run.run.app/api/v1/exec/stream \
  -H "Authorization: Bearer IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc=" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Liste os últimos 10 negócios do Pipedrive e me mostre os valores",
    "model": "claude-sonnet-4-5",
    "approval_policy": "auto"
  }'
```

### 3. Exemplo de Uso Programático

```python
import requests

response = requests.post(
    "https://sua-url-cloud-run.run.app/api/v1/exec/stream",
    headers={
        "Authorization": "Bearer IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc=",
        "Content-Type": "application/json"
    },
    json={
        "prompt": "Crie um negócio no Pipedrive para a empresa 'Acme Corp' com valor de R$ 50.000",
        "model": "claude-sonnet-4-5"
    },
    stream=True
)

for line in response.iter_lines():
    if line:
        print(line.decode('utf-8'))
```

## 🔧 Arquitetura de Integração

```
┌─────────────────────────────────────────┐
│   Codex Wrapper Cloud Run               │
│  ┌───────────────────────────────┐      │
│  │  codex-app-server             │      │
│  │  ├─ McpConnectionManager      │      │
│  │  │  ├─ RmcpClient             │      │
│  │  │  └─ McpToolCall Handler    │      │
│  │  └─ config.toml (mcp_servers) │      │
│  └───────────────────────────────┘      │
└─────────────┬───────────────────────────┘
              │ HTTPS/SSE
┌─────────────▼───────────────────────────┐
│   MCP Pipedrive Server (Cloud Run)      │
│  ┌───────────────────────────────┐      │
│  │  Pipedrive MCP Server         │      │
│  │  ├─ 30 Tools                  │      │
│  │  ├─ SSE Endpoint               │      │
│  │  └─ Pipedrive API Client      │      │
│  └───────────────────────────────┘      │
└─────────────┬───────────────────────────┘
              │ HTTPS
┌─────────────▼───────────────────────────┐
│   Pipedrive API (api.pipedrive.com)     │
└─────────────────────────────────────────┘
```

## 📝 Fluxo de Chamada MCP

1. **Usuário faz request** via CLI ou API
2. **Codex processa** o prompt e identifica necessidade de usar ferramenta
3. **McpConnectionManager** conecta ao servidor MCP Pipedrive via SSE
4. **RmcpClient** invoca a ferramenta específica (ex: `list_deals_from_pipedrive`)
5. **MCP Server** faz request à API do Pipedrive
6. **Resposta retorna** via SSE para o Codex
7. **Codex processa** o resultado e continua a execução

## 🔐 Segurança

### Autenticação em Camadas

1. **Gateway → Codex**: Bearer token (`GATEWAY_API_KEY`)
2. **Codex → MCP Server**: SSE connection (pode usar `bearer_token` no config)
3. **MCP Server → Pipedrive API**: API token (`PIPEDRIVE_API_TOKEN`)

### Variáveis de Ambiente Sensíveis

```bash
# Nunca commitar essas variáveis!
GATEWAY_API_KEY=...          # Auth do wrapper
PIPEDRIVE_API_TOKEN=...      # Auth do Pipedrive
```

## 🐛 Troubleshooting

### MCP Server não conecta

```bash
# Verificar se o MCP Server está rodando
curl https://pipedrive-mcp-467992722695.us-central1.run.app/sse

# Logs do wrapper
docker logs <container-id>

# Verificar configuração
cat config.toml | grep -A 5 "mcp_servers.pipedrive"
```

### Timeout em chamadas de ferramenta

```toml
# Aumentar timeout no config.toml
[mcp_servers.pipedrive]
tool_timeout_sec = 180  # 3 minutos
```

### Erros de autenticação Pipedrive

```bash
# Verificar se o token está correto
echo $PIPEDRIVE_API_TOKEN

# Testar diretamente na API
curl -H "Authorization: Bearer $PIPEDRIVE_API_TOKEN" \
  https://api.pipedrive.com/v1/users/me
```

## 🔄 Adicionando Novos MCP Servers

### Exemplo: Adicionar MCP Slack

```toml
[mcp_servers.slack]
url = "https://seu-mcp-slack.run.app/sse"
bearer_token = "seu-token-slack"
startup_timeout_sec = 30
tool_timeout_sec = 60
```

### Exemplo: MCP Local via Docker

```toml
[mcp_servers.local-tool]
command = "docker"
args = ["run", "-i", "--rm", "seu-mcp-server:latest"]
startup_timeout_sec = 10
tool_timeout_sec = 30
```

## 📊 Monitoramento

### Métricas Disponíveis

- **Tempo de inicialização** do MCP server (`startup_timeout_sec`)
- **Tempo de execução** de cada tool call (`tool_timeout_sec`)
- **Taxa de sucesso** das chamadas MCP
- **Erros de conexão** ao servidor MCP

### Logs Estruturados

```rust
// O Codex já loga automaticamente:
// - McpToolCallBegin: Início da chamada
// - McpToolCallEnd: Fim da chamada (com duração e resultado)
```

## 📚 Referências

- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [Codex MCP Client](../mcp-client/)
- [Codex MCP Types](../mcp-types/)
- [Pipedrive MCP Server Docs](../../packages/mcp/CLOUD_RUN_DEPLOY.md)

## 🎯 Próximos Passos

- [ ] Adicionar cache de ferramentas MCP
- [ ] Implementar retry logic para falhas temporárias
- [ ] Dashboard de métricas MCP
- [ ] Suporte a múltiplas instâncias do mesmo servidor
- [ ] Auto-discovery de MCP servers via registry

---

**Última atualização:** 2025-10-04
**Versão do Codex:** wrapper-cloud-run v0.1.0
