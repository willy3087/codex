# 🗄️ Cloud SQL PostgreSQL - Sandbox e Armazenamento

## 📋 Visão Geral

O Codex Wrapper agora usa **Cloud SQL PostgreSQL** para:
- ✅ Sandbox de execução de código SQL
- ✅ Armazenamento persistente de sessões
- ✅ Cache de resultados
- ✅ Histórico de execuções

## 🔧 Informações da Instância

```yaml
Projeto: elaihub-prod
Região: us-central1
Instância: sandbox
Connection Name: elaihub-prod:us-central1:sandbox

IP Público: 136.112.247.204
Porta: 5432 (PostgreSQL padrão)

Service Account: p467992722695-hc6sid@gcp-sa-cloud-sql.iam.gserviceaccount.com
```

## 🚀 Setup Automático

Execute o script de configuração:

```bash
/Users/williamduarte/NCMproduto/codex/codex-rs/wrapper-cloud-run/setup-cloudsql.sh
```

Esse script irá:
1. ✅ Criar secret `cloud-sql-password` com senha do PostgreSQL
2. ✅ Configurar permissões IAM (`roles/cloudsql.client`)
3. ✅ Criar database `sandbox` (se não existir)
4. ✅ Mostrar string de conexão para Cloud Run

## 🔐 Secrets Configurados

| Secret Name | Descrição | Usado para |
|-------------|-----------|------------|
| `cloud-sql-password` | Senha do PostgreSQL | Autenticação no banco |
| `gateway-api-key-codex` | API key do gateway | Autenticação HTTP |
| `openai-api-key` | OpenAI API key | Modelo gpt-4o-mini |
| `pipedrive-api-token-codex` | Pipedrive token | MCP Pipedrive |

## 📦 Deploy com Cloud SQL

### Via Script Automatizado

```bash
# 1. Executar setup
./setup-cloudsql.sh

# 2. Deploy será mostrado no final do script
# Copiar e executar o comando gerado
```

### Via gcloud (Manual)

```bash
gcloud run deploy codex-wrapper \
  --image us-central1-docker.pkg.dev/elaihub-prod/codex-wrapper/wrapper:latest \
  --region us-central1 \
  --platform managed \
  --memory 2Gi \
  --cpu 2 \
  --timeout 300 \
  --max-instances 10 \
  --add-cloudsql-instances elaihub-prod:us-central1:sandbox \
  --set-env-vars "DATABASE_URL=postgresql://postgres@localhost/sandbox?host=/cloudsql/elaihub-prod:us-central1:sandbox,RUST_LOG=info,CODEX_CONFIG_PATH=/app/config.toml" \
  --set-secrets "CLOUD_SQL_PASSWORD=cloud-sql-password:latest,GATEWAY_API_KEY=gateway-api-key-codex:latest,OPENAI_API_KEY=openai-api-key:latest,PIPEDRIVE_API_TOKEN=pipedrive-api-token-codex:latest" \
  --project elaihub-prod
```

### Via Console Web

1. Acesse: https://console.cloud.google.com/run/detail/us-central1/codex-wrapper?project=elaihub-prod
2. Clique em **"EDIT & DEPLOY NEW REVISION"**
3. Em **"Connections"** → **"Cloud SQL connections"**:
   - Adicionar: `elaihub-prod:us-central1:sandbox`
4. Em **"Variables & Secrets"**:
   - Adicionar variável: `DATABASE_URL=postgresql://postgres@localhost/sandbox?host=/cloudsql/elaihub-prod:us-central1:sandbox`
   - Adicionar secret: `CLOUD_SQL_PASSWORD=cloud-sql-password:latest`
5. Clicar em **"DEPLOY"**

## 🔌 Strings de Conexão

### Cloud Run (via Unix Socket)
```
postgresql://postgres@localhost/sandbox?host=/cloudsql/elaihub-prod:us-central1:sandbox
```

### Desenvolvimento Local (via IP Público)
```bash
# Obter senha do secret
PASSWORD=$(gcloud secrets versions access latest --secret=cloud-sql-password --project=elaihub-prod)

# String de conexão
postgresql://postgres:${PASSWORD}@136.112.247.204:5432/sandbox
```

### Via Cloud SQL Proxy (Desenvolvimento Local)
```bash
# Instalar Cloud SQL Proxy
gcloud components install cloud-sql-proxy

# Iniciar proxy
cloud-sql-proxy elaihub-prod:us-central1:sandbox

# Conectar (em outro terminal)
psql "postgresql://postgres@localhost:5432/sandbox"
```

## 📊 Schema do Banco

### Tabelas Principais

```sql
-- Sessões do Codex
CREATE TABLE codex_sessions (
    session_id UUID PRIMARY KEY,
    user_id VARCHAR(255),
    model VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50),
    metadata JSONB
);

-- Histórico de execuções
CREATE TABLE execution_history (
    id SERIAL PRIMARY KEY,
    session_id UUID REFERENCES codex_sessions(session_id),
    prompt TEXT,
    response TEXT,
    tokens_used INTEGER,
    execution_time_ms INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sandbox de código SQL
CREATE TABLE sandbox_executions (
    id SERIAL PRIMARY KEY,
    session_id UUID,
    sql_query TEXT,
    result JSONB,
    error TEXT,
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Cache de MCP tool calls
CREATE TABLE mcp_cache (
    id SERIAL PRIMARY KEY,
    tool_name VARCHAR(255),
    arguments JSONB,
    result JSONB,
    cached_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);
```

## 🧪 Testando a Conexão

### Via codex-cloud CLI

```bash
./target/release/codex-cloud exec "Execute no PostgreSQL: SELECT version();"
```

### Via curl

```bash
TOKEN=$(gcloud auth print-identity-token)

curl -X POST https://codex-wrapper-467992722695.us-central1.run.app/api/v1/exec/stream \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Gateway-Key: IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc=" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Execute SQL: SELECT current_database(), current_user;", "model": "gpt-4o-mini"}' \
  --no-buffer
```

### Via psql (Desenvolvimento)

```bash
# Obter senha
PASSWORD=$(gcloud secrets versions access latest --secret=cloud-sql-password --project=elaihub-prod)

# Conectar
PGPASSWORD=$PASSWORD psql -h 136.112.247.204 -U postgres -d sandbox

# Executar queries
sandbox=> SELECT version();
sandbox=> \dt  -- Listar tabelas
sandbox=> \q   -- Sair
```

## 🔒 Segurança

### Permissões IAM Necessárias

```bash
# Cloud SQL Client (para codex-wrapper-sa)
gcloud projects add-iam-policy-binding elaihub-prod \
  --member="serviceAccount:codex-wrapper-sa@elaihub-prod.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

# Secret Manager Access
gcloud secrets add-iam-policy-binding cloud-sql-password \
  --member="serviceAccount:codex-wrapper-sa@elaihub-prod.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=elaihub-prod
```

### Configurações de Rede

```yaml
Conectividade IP Particular: Desativado
Conectividade IP Público: Ativado (136.112.247.204)

# Para produção, recomenda-se:
# - Ativar IP Particular
# - Desativar IP Público
# - Usar VPC Peering
```

### Usuários e Roles

```sql
-- Criar usuário apenas para leitura (para analytics)
CREATE USER analytics_reader WITH PASSWORD 'read_only_2025';
GRANT CONNECT ON DATABASE sandbox TO analytics_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO analytics_reader;

-- Criar usuário para escrita limitada
CREATE USER codex_app WITH PASSWORD 'app_user_2025';
GRANT CONNECT ON DATABASE sandbox TO codex_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO codex_app;
```

## 📈 Monitoramento

### Via Console GCP

```
https://console.cloud.google.com/sql/instances/sandbox/overview?project=elaihub-prod
```

### Queries de Diagnóstico

```sql
-- Conexões ativas
SELECT * FROM pg_stat_activity;

-- Tamanho do banco
SELECT pg_size_pretty(pg_database_size('sandbox'));

-- Tabelas maiores
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;

-- Performance de queries
SELECT
    query,
    calls,
    total_time,
    mean_time,
    max_time
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 10;
```

## 🐛 Troubleshooting

### Erro: "connection refused"

```bash
# Verificar se IP público está ativo
gcloud sql instances describe sandbox \
  --project=elaihub-prod \
  --format="value(ipAddresses[0].ipAddress)"

# Deve retornar: 136.112.247.204
```

### Erro: "password authentication failed"

```bash
# Verificar secret
gcloud secrets versions access latest \
  --secret=cloud-sql-password \
  --project=elaihub-prod

# Resetar senha se necessário
gcloud sql users set-password postgres \
  --instance=sandbox \
  --password=nova_senha_aqui \
  --project=elaihub-prod
```

### Erro: "too many connections"

```sql
-- Ver limite atual
SHOW max_connections;

-- Ver conexões ativas
SELECT count(*) FROM pg_stat_activity;

-- Matar conexões ociosas
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle'
AND state_change < current_timestamp - INTERVAL '10 minutes';
```

### Cloud Run não conecta ao Cloud SQL

```bash
# Verificar se connection está adicionada
gcloud run services describe codex-wrapper \
  --region=us-central1 \
  --project=elaihub-prod \
  --format="value(spec.template.spec.containers[0].resources.cloudsql_instances)"

# Deve retornar: elaihub-prod:us-central1:sandbox
```

## 🔄 Backup e Restore

### Backup Automático (já configurado)

```bash
# Ver backups existentes
gcloud sql backups list \
  --instance=sandbox \
  --project=elaihub-prod

# Criar backup manual
gcloud sql backups create \
  --instance=sandbox \
  --project=elaihub-prod
```

### Export/Import Manual

```bash
# Export para Cloud Storage
gcloud sql export sql sandbox \
  gs://elaistore/backups/sandbox-$(date +%Y%m%d).sql \
  --database=sandbox \
  --project=elaihub-prod

# Import de Cloud Storage
gcloud sql import sql sandbox \
  gs://elaistore/backups/sandbox-20250101.sql \
  --database=sandbox \
  --project=elaihub-prod
```

## 📚 Referências

- [Cloud SQL PostgreSQL Docs](https://cloud.google.com/sql/docs/postgres)
- [Connecting from Cloud Run](https://cloud.google.com/sql/docs/postgres/connect-run)
- [Cloud SQL Proxy](https://cloud.google.com/sql/docs/postgres/sql-proxy)
- [Best Practices](https://cloud.google.com/sql/docs/postgres/best-practices)

---

**Última atualização:** 2025-10-05
**Versão:** 1.0.0
**Instância:** elaihub-prod:us-central1:sandbox
