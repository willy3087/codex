# 🚀 Codex Gateway CLI

Cliente interativo via terminal para o Codex Gateway em produção.

## 📦 Instalação Rápida

```bash
# 1. Garantir que as dependências Python estão instaladas
pip3 install websockets aiohttp

# 2. Tornar o script executável (já feito)
chmod +x scripts/gateway

# 3. (Opcional) Adicionar ao PATH para acesso global
echo 'export PATH="$PATH:'$(pwd)'/scripts"' >> ~/.bashrc
source ~/.bashrc
```

## 🎯 Uso Básico

### Opção 1: Via wrapper script (recomendado)

```bash
# Uso direto (busca API key automaticamente do Secret Manager)
./scripts/gateway

# Com API key manual
./scripts/gateway --key "sua-api-key"

# Com URL customizada
./scripts/gateway --url "https://outro-gateway.run.app"

# Verificar saúde do gateway
./scripts/gateway --health
```

### Opção 2: Via Python direto

```bash
# Definir API key manualmente
export GATEWAY_KEY=$(gcloud secrets versions access latest --secret=gateway-api-key)

# Executar cliente
python3 scripts/gateway_cli.py
```

## 💡 Exemplos de Uso

### Sessão Interativa

```bash
$ ./scripts/gateway

🚀 Codex Gateway CLI
📡 Conectado a: https://wrapper-uamdjcvg7q-uc.a.run.app
🔑 Session ID: cli-12345
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Digite seus prompts (ou 'exit' para sair, 'clear' para limpar)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💬 Você: Write a Python function that calculates fibonacci
⏳ Processando...

🤖 Resposta:
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)

💬 Você: Explain how it works
⏳ Processando...

🤖 Resposta:
This function uses recursion to calculate the nth Fibonacci number...

💬 Você: exit

👋 Encerrando sessão...
```

### Health Check

```bash
$ ./scripts/gateway --health

🔍 Verificando saúde do gateway...
✅ Gateway está saudável
📡 URL: https://wrapper-uamdjcvg7q-uc.a.run.app
```

## 🎨 Comandos Especiais

Durante a sessão interativa, você pode usar:

- **`exit`** - Encerra a sessão
- **`clear`** - Limpa a tela
- **`Ctrl+C`** - Interrompe e encerra

## 🔐 Autenticação

O CLI busca a API key de três formas (em ordem de prioridade):

1. **Argumento `--key`**: API key passada diretamente
2. **Variável `GATEWAY_KEY`**: API key na variável de ambiente
3. **Secret Manager**: Busca automaticamente via `gcloud`

```bash
# Método 1: Argumento
./scripts/gateway --key "minha-api-key"

# Método 2: Variável de ambiente
export GATEWAY_KEY="minha-api-key"
./scripts/gateway

# Método 3: Secret Manager (automático)
# Requer gcloud configurado e autenticado
./scripts/gateway
```

## 🌐 URLs Suportadas

Por padrão, conecta a:
```
https://wrapper-uamdjcvg7q-uc.a.run.app
```

Para usar outra URL:
```bash
export GATEWAY_URL="https://outro-gateway.com"
./scripts/gateway
```

## 📊 Características

- ✅ **Interativo**: Interface de chat no terminal
- ✅ **Sessões persistentes**: Mantém contexto da conversação
- ✅ **Auto-retry**: Tenta reconectar automaticamente
- ✅ **Health check**: Verifica disponibilidade antes de iniciar
- ✅ **Formatação**: Respostas formatadas e coloridas
- ✅ **Erros claros**: Mensagens de erro detalhadas

## 🐛 Troubleshooting

### Erro: "GATEWAY_KEY não definida"

```bash
# Solução 1: Obter do Secret Manager
export GATEWAY_KEY=$(gcloud secrets versions access latest --secret=gateway-api-key)

# Solução 2: Definir manualmente
export GATEWAY_KEY="sua-chave-aqui"
```

### Erro: "Gateway inacessível"

```bash
# Verificar saúde do gateway
./scripts/gateway --health

# Verificar URL
echo $GATEWAY_URL

# Testar conectividade
curl https://wrapper-uamdjcvg7q-uc.a.run.app/health
```

### Erro: "Dependências não encontradas"

```bash
# Instalar dependências Python
pip3 install websockets aiohttp

# Ou usar requirements.txt
pip3 install -r requirements.txt
```

## 🔧 Desenvolvimento

### Estrutura de Arquivos

```
scripts/
├── gateway              # Wrapper bash (ponto de entrada)
├── gateway_cli.py       # Cliente Python principal
└── README_CLI.md        # Esta documentação
```

### Protocolo

O cliente usa **HTTP JSON-RPC 2.0** para comunicação:

```json
{
  "jsonrpc": "2.0",
  "method": "conversation.prompt",
  "params": {
    "prompt": "seu prompt aqui",
    "session_id": "cli-12345"
  },
  "id": 1
}
```

### Extender Funcionalidades

Para adicionar novos métodos, edite `gateway_cli.py`:

```python
async def send_custom_method(self, params: dict) -> dict:
    payload = {
        "jsonrpc": "2.0",
        "method": "seu.metodo",
        "params": params,
        "id": self.message_id
    }
    # ... resto do código
```

## 📚 Referências

- [Gateway API Examples](../GATEWAY_API_EXAMPLES.md)
- [GCP Deployment Guide](../GCP_DEPLOYMENT.md)
- [JSON-RPC 2.0 Spec](https://www.jsonrpc.org/specification)

---

**Última Atualização**: 2025-11-13
**Versão**: 1.0.0
**Maintainer**: DevOps Team
