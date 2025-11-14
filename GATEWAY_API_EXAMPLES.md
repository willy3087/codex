# Codex Gateway - API Examples & Payloads

## 🔑 Configuração Inicial

### Variáveis de Ambiente

```bash
# Service URL
export GATEWAY_URL="https://wrapper-uamdjcvg7q-uc.a.run.app"

# Obter API Key do Secret Manager
export GATEWAY_KEY=$(gcloud secrets versions access latest --secret=gateway-api-key)

# Headers comuns
export HEADERS=(-H "X-API-Key: $GATEWAY_KEY" -H "Content-Type: application/json")
```

---

## 📡 Endpoints Disponíveis

### 1. Health Check

**Endpoint**: `GET /health`
**Autenticação**: Não requerida
**Descrição**: Verifica status do gateway

```bash
curl "$GATEWAY_URL/health"
```

**Resposta**:
```json
{
  "status": "healthy"
}
```

---

### 2. JSON-RPC API

**Endpoint**: `POST /jsonrpc`
**Autenticação**: Requerida (`X-API-Key`)
**Descrição**: API JSON-RPC 2.0 para comunicação com o gateway

---

### 3. WebSocket

**Endpoint**: `GET /ws`
**Autenticação**: Requerida (`X-API-Key`)
**Descrição**: Conexão WebSocket para comunicação em tempo real

---

### 4. Webhooks

**Endpoint**: `POST /webhook`
**Autenticação**: Requerida (`X-API-Key`)
**Descrição**: Recebe webhooks de integrações externas

---

## 🔄 JSON-RPC Payloads

### Estrutura Base JSON-RPC 2.0

```json
{
  "jsonrpc": "2.0",
  "method": "nome_do_metodo",
  "params": {
    "param1": "valor1",
    "param2": "valor2"
  },
  "id": 1
}
```

---

## 📦 Exemplos de Payloads por Método

### ✅ Métodos Implementados (Prontos para Uso)

#### 1. conversation.prompt - Executar Prompt de IA

**Status**: ✅ **IMPLEMENTADO** - Integrado com Codex Core

```json
{
  "jsonrpc": "2.0",
  "method": "conversation.prompt",
  "params": {
    "prompt": "Write a Rust function that adds two numbers",
    "session_id": "my-session-123"
  },
  "id": 1
}
```

**cURL**:
```bash
curl -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "conversation.prompt",
    "params": {
      "prompt": "Write a Rust function that adds two numbers",
      "session_id": "my-session-123"
    },
    "id": 1
  }'
```

**Resposta Esperada**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "type": "ai_response",
    "conversation_id": "conv_abc123",
    "content": "fn add(a: i32, b: i32) -> i32 {\n    a + b\n}",
    "model": "claude-3-sonnet",
    "timestamp": "2024-11-13T14:20:00.000Z",
    "events": [
      {
        "TaskStarted": { /* ... */ }
      },
      {
        "AgentMessage": { "message": "..." }
      },
      {
        "TaskComplete": { /* ... */ }
      }
    ]
  },
  "id": 1
}
```

---

#### 2. conversation.status - Verificar Status da Conversação

**Status**: ✅ **IMPLEMENTADO**

```json
{
  "jsonrpc": "2.0",
  "method": "conversation.status",
  "params": {
    "session_id": "my-session-123"
  },
  "id": 2
}
```

**cURL**:
```bash
curl -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "conversation.status",
    "params": {
      "session_id": "my-session-123"
    },
    "id": 2
  }'
```

**Resposta Success**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "conversation_id": "conv_abc123",
    "metadata": {
      "model": "claude-3-sonnet",
      "created_at": "2024-11-13T14:00:00.000Z"
    }
  },
  "id": 2
}
```

**Resposta Not Found**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "status": "not_found",
    "session_id": "my-session-123"
  },
  "id": 2
}
```

---

#### 3. conversation.cancel - Cancelar Conversação

**Status**: ✅ **IMPLEMENTADO**

```json
{
  "jsonrpc": "2.0",
  "method": "conversation.cancel",
  "params": {
    "session_id": "my-session-123"
  },
  "id": 3
}
```

**cURL**:
```bash
curl -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "conversation.cancel",
    "params": {
      "session_id": "my-session-123"
    },
    "id": 3
  }'
```

**Resposta Success**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "cancelled": true,
    "session_id": "my-session-123",
    "conversation_id": "conv_abc123"
  },
  "id": 3
}
```

---

### 🚧 Métodos Planejados (Roadmap Futuro)

Os métodos abaixo fazem parte da arquitetura planejada e serão implementados nas próximas fases:

#### Exec - Executar Comando

**Status**: 🚧 **PLANEJADO**

```json
{
  "jsonrpc": "2.0",
  "method": "exec",
  "params": {
    "command": "echo",
    "args": ["Hello from Codex Gateway"],
    "env": {
      "ENV_VAR": "value"
    },
    "cwd": "/tmp"
  },
  "id": 1
}
```

**cURL**:
```bash
curl -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "exec",
    "params": {
      "command": "echo",
      "args": ["Hello from Codex Gateway"]
    },
    "id": 1
  }'
```

**Resposta Esperada**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "stdout": "Hello from Codex Gateway\n",
    "stderr": "",
    "exit_code": 0
  },
  "id": 1
}
```

---

#### Proto - Comunicação Protocol Buffer Streaming

**Status**: 🚧 **PLANEJADO**

```json
{
  "jsonrpc": "2.0",
  "method": "proto",
  "params": {
    "stream_id": "session-123",
    "data": "base64_encoded_protobuf_data"
  },
  "id": 2
}
```

**cURL**:
```bash
curl -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "proto",
    "params": {
      "stream_id": "session-123",
      "data": "CgVIZWxsbw=="
    },
    "id": 2
  }'
```

---

#### MCP - Model Context Protocol Server

**Status**: 🚧 **PLANEJADO**

```json
{
  "jsonrpc": "2.0",
  "method": "mcp.connect",
  "params": {
    "server_config": {
      "name": "my-mcp-server",
      "command": "python",
      "args": ["-m", "mcp_server"]
    }
  },
  "id": 3
}
```

**cURL**:
```bash
curl -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "mcp.connect",
    "params": {
      "server_config": {
        "name": "my-mcp-server",
        "command": "python",
        "args": ["-m", "mcp_server"]
      }
    },
    "id": 3
  }'
```

---

#### Apply - Git Patch Application

**Status**: 🚧 **PLANEJADO**

```json
{
  "jsonrpc": "2.0",
  "method": "apply",
  "params": {
    "patch": "diff --git a/file.txt b/file.txt\nindex 1234567..abcdefg 100644\n--- a/file.txt\n+++ b/file.txt\n@@ -1 +1 @@\n-old content\n+new content",
    "repo_path": "/path/to/repo",
    "dry_run": false
  },
  "id": 4
}
```

**cURL**:
```bash
curl -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "apply",
    "params": {
      "patch": "diff --git a/file.txt b/file.txt\n...",
      "repo_path": "/tmp/repo",
      "dry_run": false
    },
    "id": 4
  }'
```

---

#### Interactive - Terminal Interativo

**Status**: 🚧 **PLANEJADO**

```json
{
  "jsonrpc": "2.0",
  "method": "interactive.start",
  "params": {
    "session_id": "tty-session-456",
    "shell": "/bin/bash",
    "cols": 80,
    "rows": 24
  },
  "id": 5
}
```

**cURL**:
```bash
curl -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "interactive.start",
    "params": {
      "session_id": "tty-session-456",
      "shell": "/bin/bash",
      "cols": 80,
      "rows": 24
    },
    "id": 5
  }'
```

---

#### Login/Logout - Autenticação de Sessão

**Status**: 🚧 **PLANEJADO**

**Login**:
```json
{
  "jsonrpc": "2.0",
  "method": "auth.login",
  "params": {
    "provider": "chatgpt",
    "credentials": {
      "token": "user-token-from-chatgpt"
    }
  },
  "id": 6
}
```

**Logout**:
```json
{
  "jsonrpc": "2.0",
  "method": "auth.logout",
  "params": {
    "session_id": "session-xyz"
  },
  "id": 7
}
```

**cURL Login**:
```bash
curl -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "auth.login",
    "params": {
      "provider": "chatgpt",
      "credentials": {
        "token": "user-token-from-chatgpt"
      }
    },
    "id": 6
  }'
```

---

#### BFF - Backend for Frontend Proxy

**Status**: 🚧 **PLANEJADO**

```json
{
  "jsonrpc": "2.0",
  "method": "bff.proxy",
  "params": {
    "endpoint": "/api/users",
    "method": "GET",
    "headers": {
      "Authorization": "Bearer token"
    },
    "query": {
      "page": 1,
      "limit": 10
    }
  },
  "id": 8
}
```

**cURL**:
```bash
curl -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "bff.proxy",
    "params": {
      "endpoint": "/api/users",
      "method": "GET",
      "query": {
        "page": 1,
        "limit": 10
      }
    },
    "id": 8
  }'
```

---

## 🔌 WebSocket Examples

### Python WebSocket Client

```python
#!/usr/bin/env python3
import asyncio
import websockets
import json
import os

GATEWAY_URL = "wss://wrapper-467992722695.us-central1.run.app/ws"
GATEWAY_KEY = os.getenv("GATEWAY_KEY")

async def connect_gateway():
    headers = {
        "X-API-Key": GATEWAY_KEY
    }

    async with websockets.connect(GATEWAY_URL, extra_headers=headers) as websocket:
        # Enviar mensagem
        message = {
            "jsonrpc": "2.0",
            "method": "exec",
            "params": {
                "command": "echo",
                "args": ["WebSocket test"]
            },
            "id": 1
        }

        await websocket.send(json.dumps(message))

        # Receber resposta
        response = await websocket.recv()
        print(f"Received: {response}")

if __name__ == "__main__":
    asyncio.run(connect_gateway())
```

---

### Node.js WebSocket Client

```javascript
#!/usr/bin/env node
const WebSocket = require('ws');

const GATEWAY_URL = 'wss://wrapper-467992722695.us-central1.run.app/ws';
const GATEWAY_KEY = process.env.GATEWAY_KEY;

const ws = new WebSocket(GATEWAY_URL, {
  headers: {
    'X-API-Key': GATEWAY_KEY
  }
});

ws.on('open', function open() {
  console.log('Connected to gateway');

  const message = {
    jsonrpc: '2.0',
    method: 'exec',
    params: {
      command: 'echo',
      args: ['WebSocket test from Node.js']
    },
    id: 1
  };

  ws.send(JSON.stringify(message));
});

ws.on('message', function message(data) {
  console.log('Received:', data.toString());
});

ws.on('error', function error(err) {
  console.error('WebSocket error:', err);
});
```

---

## 📤 Webhook Examples

### Payload de Webhook

```json
{
  "event": "deployment.success",
  "timestamp": "2025-01-13T10:30:00Z",
  "data": {
    "service": "wrapper",
    "version": "486a13c9",
    "region": "us-central1",
    "status": "healthy"
  }
}
```

**cURL**:
```bash
curl -X POST "$GATEWAY_URL/webhook" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "deployment.success",
    "timestamp": "2025-01-13T10:30:00Z",
    "data": {
      "service": "wrapper",
      "version": "486a13c9",
      "region": "us-central1",
      "status": "healthy"
    }
  }'
```

---

## 🧪 Scripts de Teste Completos

### 1. Test Suite - Bash Script (Métodos Implementados)

```bash
#!/bin/bash
# test_gateway.sh - Suite completa de testes dos métodos REAIS

set -euo pipefail

# Configuração
GATEWAY_URL="https://wrapper-uamdjcvg7q-uc.a.run.app"
GATEWAY_KEY=$(gcloud secrets versions access latest --secret=gateway-api-key)

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função de teste
test_endpoint() {
    local name="$1"
    local method="$2"
    local payload="$3"

    echo -e "${YELLOW}Testing: $name${NC}"

    response=$(curl -s -X POST "$GATEWAY_URL$method" \
        -H "X-API-Key: $GATEWAY_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload")

    if echo "$response" | jq -e . >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Success${NC}"
        echo "$response" | jq .
    else
        echo -e "${RED}✗ Failed${NC}"
        echo "$response"
    fi
    echo ""
}

# Teste 1: Health Check
echo -e "${YELLOW}Test 1: Health Check${NC}"
health=$(curl -s "$GATEWAY_URL/health")
if [ "$(echo $health | jq -r .status)" = "healthy" ]; then
    echo -e "${GREEN}✓ Health check passed${NC}"
else
    echo -e "${RED}✗ Health check failed${NC}"
fi
echo ""

# Teste 2: conversation.prompt (método REAL implementado)
test_endpoint "AI Prompt (conversation.prompt)" "/jsonrpc" '{
  "jsonrpc": "2.0",
  "method": "conversation.prompt",
  "params": {
    "prompt": "Write a simple hello world function in Python",
    "session_id": "test-session-001"
  },
  "id": 1
}'

# Teste 3: conversation.status
test_endpoint "Check Conversation Status" "/jsonrpc" '{
  "jsonrpc": "2.0",
  "method": "conversation.status",
  "params": {
    "session_id": "test-session-001"
  },
  "id": 2
}'

# Teste 4: conversation.cancel
test_endpoint "Cancel Conversation" "/jsonrpc" '{
  "jsonrpc": "2.0",
  "method": "conversation.cancel",
  "params": {
    "session_id": "test-session-001"
  },
  "id": 3
}'

# Teste 5: Invalid Method (erro esperado)
test_endpoint "Invalid Method (should fail)" "/jsonrpc" '{
  "jsonrpc": "2.0",
  "method": "nonexistent_method",
  "params": {},
  "id": 4
}'

echo -e "${GREEN}All tests completed!${NC}"
```

---

### 2. Python Test Client

```python
#!/usr/bin/env python3
"""
Codex Gateway Test Client
"""
import os
import json
import requests
from typing import Dict, Any, Optional

class CodexGatewayClient:
    def __init__(self, gateway_url: str, api_key: str):
        self.gateway_url = gateway_url
        self.api_key = api_key
        self.headers = {
            "X-API-Key": api_key,
            "Content-Type": "application/json"
        }

    def health_check(self) -> Dict[str, Any]:
        """Check gateway health"""
        response = requests.get(f"{self.gateway_url}/health")
        return response.json()

    def jsonrpc_call(self, method: str, params: Dict[str, Any], req_id: int = 1) -> Dict[str, Any]:
        """Make a JSON-RPC call"""
        payload = {
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": req_id
        }

        response = requests.post(
            f"{self.gateway_url}/jsonrpc",
            headers=self.headers,
            json=payload
        )

        return response.json()

    def conversation_prompt(self, prompt: str, session_id: str = None) -> Dict[str, Any]:
        """Execute AI prompt (conversation.prompt)"""
        params = {"prompt": prompt}
        if session_id:
            params["session_id"] = session_id

        return self.jsonrpc_call("conversation.prompt", params)

    def conversation_status(self, session_id: str) -> Dict[str, Any]:
        """Get conversation status"""
        return self.jsonrpc_call("conversation.status", {"session_id": session_id})

    def conversation_cancel(self, session_id: str) -> Dict[str, Any]:
        """Cancel conversation"""
        return self.jsonrpc_call("conversation.cancel", {"session_id": session_id})

    def webhook(self, event: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Send webhook event"""
        payload = {
            "event": event,
            "timestamp": "2025-01-13T10:30:00Z",
            "data": data
        }

        response = requests.post(
            f"{self.gateway_url}/webhook",
            headers=self.headers,
            json=payload
        )

        return response.json()

# Exemplo de uso
if __name__ == "__main__":
    GATEWAY_URL = "https://wrapper-uamdjcvg7q-uc.a.run.app"
    GATEWAY_KEY = os.getenv("GATEWAY_KEY")

    client = CodexGatewayClient(GATEWAY_URL, GATEWAY_KEY)

    # Teste 1: Health check
    print("=== Health Check ===")
    health = client.health_check()
    print(json.dumps(health, indent=2))

    # Teste 2: AI Prompt (método REAL implementado)
    print("\n=== AI Prompt (conversation.prompt) ===")
    result = client.conversation_prompt(
        "Write a simple hello world function in Python",
        session_id="python-test-session"
    )
    print(json.dumps(result, indent=2))

    # Teste 3: Conversation Status
    print("\n=== Conversation Status ===")
    status = client.conversation_status("python-test-session")
    print(json.dumps(status, indent=2))

    # Teste 4: Cancel Conversation
    print("\n=== Cancel Conversation ===")
    cancel = client.conversation_cancel("python-test-session")
    print(json.dumps(cancel, indent=2))

    # Teste 5: Invalid method (erro esperado)
    print("\n=== Invalid Method ===")
    try:
        result = client.jsonrpc_call("invalid_method", {})
        print(json.dumps(result, indent=2))
    except Exception as e:
        print(f"Error: {e}")
```

**Instalar dependências**:
```bash
pip install requests websockets
```

---

### 3. JavaScript/TypeScript Client

```typescript
// gateway-client.ts
interface JsonRpcRequest {
  jsonrpc: '2.0';
  method: string;
  params: Record<string, any>;
  id: number;
}

interface JsonRpcResponse {
  jsonrpc: '2.0';
  result?: any;
  error?: {
    code: number;
    message: string;
  };
  id: number;
}

class CodexGatewayClient {
  private gatewayUrl: string;
  private apiKey: string;

  constructor(gatewayUrl: string, apiKey: string) {
    this.gatewayUrl = gatewayUrl;
    this.apiKey = apiKey;
  }

  async healthCheck(): Promise<{ status: string }> {
    const response = await fetch(`${this.gatewayUrl}/health`);
    return response.json();
  }

  async jsonrpcCall(
    method: string,
    params: Record<string, any>,
    id: number = 1
  ): Promise<JsonRpcResponse> {
    const payload: JsonRpcRequest = {
      jsonrpc: '2.0',
      method,
      params,
      id,
    };

    const response = await fetch(`${this.gatewayUrl}/jsonrpc`, {
      method: 'POST',
      headers: {
        'X-API-Key': this.apiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    return response.json();
  }

  async conversationPrompt(
    prompt: string,
    sessionId?: string
  ): Promise<JsonRpcResponse> {
    const params: any = { prompt };
    if (sessionId) params.session_id = sessionId;

    return this.jsonrpcCall('conversation.prompt', params);
  }

  async conversationStatus(sessionId: string): Promise<JsonRpcResponse> {
    return this.jsonrpcCall('conversation.status', { session_id: sessionId });
  }

  async conversationCancel(sessionId: string): Promise<JsonRpcResponse> {
    return this.jsonrpcCall('conversation.cancel', { session_id: sessionId });
  }
}

// Exemplo de uso
const GATEWAY_URL = 'https://wrapper-uamdjcvg7q-uc.a.run.app';
const GATEWAY_KEY = process.env.GATEWAY_KEY!;

const client = new CodexGatewayClient(GATEWAY_URL, GATEWAY_KEY);

// Teste
(async () => {
  // Health check
  const health = await client.healthCheck();
  console.log('Health:', health);

  // AI Prompt (método REAL implementado)
  const result = await client.conversationPrompt(
    'Write a simple hello world function in TypeScript',
    'ts-test-session'
  );
  console.log('AI Result:', result);

  // Conversation Status
  const status = await client.conversationStatus('ts-test-session');
  console.log('Status:', status);

  // Cancel Conversation
  const cancel = await client.conversationCancel('ts-test-session');
  console.log('Cancelled:', cancel);
})();
```

---

## 🔐 Gerenciamento de API Keys

### Rotação de API Key

```bash
#!/bin/bash
# rotate_api_key.sh

# Gerar nova key
NEW_KEY="gateway-key-$(openssl rand -hex 16)"

# Adicionar nova versão ao secret
echo -n "$NEW_KEY" | gcloud secrets versions add gateway-api-key --data-file=-

# Testar nova key
curl -H "X-API-Key: $NEW_KEY" https://wrapper-uamdjcvg7q-uc.a.run.app/health

# Se OK, desabilitar versão antiga
OLD_VERSION=1
gcloud secrets versions disable $OLD_VERSION --secret=gateway-api-key
```

---

## 📊 Monitoramento e Logs

### Ver Logs em Tempo Real

```bash
# Logs do Cloud Run
gcloud run services logs tail wrapper --region=us-central1

# Filtrar por erro
gcloud logging read \
  "resource.labels.service_name=wrapper AND severity>=ERROR" \
  --limit=50 \
  --format=json

# Logs de acesso específico
gcloud logging read \
  "resource.labels.service_name=wrapper AND httpRequest.requestUrl=~'/jsonrpc'" \
  --limit=20
```

---

## 🎯 Rate Limiting

O gateway possui rate limiting configurado:
- **100 requests/minuto** por API key
- **1000 requests/hora** por API key
- **10000 requests/dia** por API key

**Cabeçalhos de resposta**:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1705147800
```

---

## ❌ Tratamento de Erros

### Códigos de Erro JSON-RPC

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32700,
    "message": "Parse error"
  },
  "id": null
}
```

**Códigos Comuns**:
- `-32700`: Parse error (JSON inválido)
- `-32600`: Invalid Request
- `-32601`: Method not found
- `-32602`: Invalid params
- `-32603`: Internal error
- `401`: Unauthorized (API key inválida)
- `429`: Too Many Requests (rate limit)
- `500`: Internal Server Error

---

## 📚 Referências

- **Service URL**: https://wrapper-uamdjcvg7q-uc.a.run.app
- **Cloud Console**: https://console.cloud.google.com/run/detail/us-central1/wrapper
- **Artifact Registry**: us-central1-docker.pkg.dev/elaihub-prod/codex-wrapper
- **Secrets**: https://console.cloud.google.com/security/secret-manager

---

---

## ⚠️ Importante: Compatibilidade com Web UI

### ✅ Métodos Compatíveis Agora (Implementados)

Os seguintes métodos **funcionam em produção** e são totalmente compatíveis com Web UI:

1. **`conversation.prompt`** - ✅ Sim, compatível
   - Envia prompt de texto
   - Recebe resposta de IA
   - Suporta sessions para contexto
   - **Ideal para chat interfaces**

2. **`conversation.status`** - ✅ Sim, compatível
   - Consulta status de sessão
   - Retorna metadata da conversação
   - **Útil para UI de status**

3. **`conversation.cancel`** - ✅ Sim, compatível
   - Cancela conversação ativa
   - **Botão de "Cancel" na UI**

### 🚧 Métodos Futuros (Planejados)

Os métodos `exec`, `proto`, `mcp.connect`, `apply`, `interactive.start`, `auth.login`, `bff.proxy` estão **planejados** para fases futuras e ainda não estão disponíveis.

### 💡 Exemplo de Integração Web UI

```javascript
// Exemplo React/Next.js
async function sendPromptToGateway(userPrompt, sessionId) {
  const response = await fetch('https://wrapper-uamdjcvg7q-uc.a.run.app/jsonrpc', {
    method: 'POST',
    headers: {
      'X-API-Key': GATEWAY_KEY,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      jsonrpc: '2.0',
      method: 'conversation.prompt',
      params: {
        prompt: userPrompt,
        session_id: sessionId
      },
      id: Date.now()
    })
  });

  const data = await response.json();
  return data.result; // { type: "ai_response", content: "...", ... }
}
```

---

**Última Atualização**: 2025-01-13 (Atualizado com métodos reais)
**Versão**: 1.1.0
**Status**: ✅ Métodos conversation.* implementados, outros em roadmap
**Maintainer**: DevOps Team
