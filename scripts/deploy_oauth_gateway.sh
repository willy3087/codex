#!/bin/bash

# Deploy OAuth-enabled Gateway to Docker
# This script stops the old container, starts the new one with OAuth support, and runs tests

set -e

CONTAINER_NAME="codex-gateway"
IMAGE_NAME="getway_elai"
ENV_FILE="/Users/williamduarte/NCMproduto/codex/codex-rs/.env"

# Generate secure OAuth client secret if not provided
OAUTH_CLIENT_SECRET="${OAUTH_CLIENT_SECRET:-$(openssl rand -hex 32)}"

echo "================================"
echo "Deploying OAuth Gateway"
echo "================================"
echo ""

# Step 1: Stop and remove existing container
echo "1. Stopping existing container..."
if docker ps -a | grep -q "$CONTAINER_NAME"; then
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    echo "   ✓ Old container removed"
else
    echo "   ℹ No existing container found"
fi

echo ""

# Step 2: Start new container with OAuth support
echo "2. Starting new container with OAuth support..."
docker run -d \
  --name "$CONTAINER_NAME" \
  -p 3000:8080 \
  --env-file "$ENV_FILE" \
  -e OAUTH_CLIENT_ID=codex-gateway-client \
  -e OAUTH_CLIENT_SECRET="$OAUTH_CLIENT_SECRET" \
  -e RUST_LOG=info,codex_gateway=debug \
  -e PORT=8080 \
  "$IMAGE_NAME"

echo "   ✓ Container started: $CONTAINER_NAME"
echo "   OAuth Client ID: codex-gateway-client"
echo "   OAuth Client Secret: ${OAUTH_CLIENT_SECRET:0:16}..."
echo ""

# Step 3: Wait for container to be ready
echo "3. Waiting for container to be ready..."
for i in {1..30}; do
    if curl -sf http://localhost:3000/health > /dev/null 2>&1; then
        echo "   ✓ Container is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "   ✗ Container failed to start within 30 seconds"
        echo "   Checking logs:"
        docker logs "$CONTAINER_NAME" | tail -20
        exit 1
    fi
    echo -n "."
    sleep 1
done

echo ""
echo ""

# Step 4: Display container info
echo "4. Container Information:"
docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Step 5: Test OAuth endpoints
echo "5. Testing OAuth Endpoints..."
echo ""

export OAUTH_CLIENT_SECRET
/Users/williamduarte/NCMproduto/codex/scripts/test_oauth.sh

echo ""
echo "================================"
echo "Deployment Complete!"
echo "================================"
echo ""
echo "Gateway URL: http://localhost:3000"
echo "OAuth Client ID: codex-gateway-client"
echo "OAuth Client Secret: ${OAUTH_CLIENT_SECRET}"
echo ""
echo "OAuth Endpoints:"
echo "  - GET  /oauth/authorize - Authorization endpoint"
echo "  - POST /oauth/token     - Token exchange endpoint"
echo ""
echo "For ChatGPT GPT Actions, configure:"
echo "  Authorization URL: https://your-domain.com/oauth/authorize"
echo "  Token URL: https://your-domain.com/oauth/token"
echo "  Client ID: codex-gateway-client"
echo "  Client Secret: ${OAUTH_CLIENT_SECRET}"
echo ""
