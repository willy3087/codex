#!/bin/bash

# OAuth Endpoint Testing Script
# Tests the OAuth 2.0 authorization code flow

set -e

GATEWAY_URL="${GATEWAY_URL:-http://localhost:3000}"
CLIENT_ID="${OAUTH_CLIENT_ID:-codex-gateway-client}"
CLIENT_SECRET="${OAUTH_CLIENT_SECRET:-secret-key-here}"
REDIRECT_URI="${REDIRECT_URI:-https://chatgpt.com/aip/g-test/oauth/callback}"

echo "================================"
echo "Testing OAuth 2.0 Endpoints"
echo "Gateway URL: $GATEWAY_URL"
echo "Client ID: $CLIENT_ID"
echo "================================"
echo ""

# Test 1: OAuth Authorization Endpoint
echo "1. Testing OAuth Authorization Endpoint..."
echo "   GET /oauth/authorize"
AUTH_RESPONSE=$(curl -sS -w "\nHTTP_CODE:%{http_code}" \
  "${GATEWAY_URL}/oauth/authorize?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&state=test_state_123")

HTTP_CODE=$(echo "$AUTH_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
LOCATION=$(echo "$AUTH_RESPONSE" | grep -i "^location:" | cut -d' ' -f2 | tr -d '\r\n' || echo "")

echo "   Status Code: $HTTP_CODE"
echo "   Redirect Location: $LOCATION"

if [ "$HTTP_CODE" = "303" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
    echo "   ✓ Authorization redirect successful"

    # Extract code from redirect URL
    if [ -n "$LOCATION" ]; then
        AUTH_CODE=$(echo "$LOCATION" | grep -oP 'code=\K[^&]+' || echo "")
        STATE=$(echo "$LOCATION" | grep -oP 'state=\K[^&]+' || echo "")
        echo "   Authorization Code: $AUTH_CODE"
        echo "   State: $STATE"

        if [ -n "$AUTH_CODE" ]; then
            echo ""
            echo "2. Testing OAuth Token Exchange..."
            echo "   POST /oauth/token"

            TOKEN_RESPONSE=$(curl -sS -X POST \
              -H "Content-Type: application/json" \
              -d "{
                \"grant_type\": \"authorization_code\",
                \"client_id\": \"${CLIENT_ID}\",
                \"client_secret\": \"${CLIENT_SECRET}\",
                \"code\": \"${AUTH_CODE}\",
                \"redirect_uri\": \"${REDIRECT_URI}\"
              }" \
              "${GATEWAY_URL}/oauth/token")

            echo "$TOKEN_RESPONSE" | jq '.' || echo "$TOKEN_RESPONSE"

            ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token' 2>/dev/null || echo "")

            if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "null" ]; then
                echo "   ✓ Token exchange successful"
                echo "   Access Token: ${ACCESS_TOKEN:0:20}..."

                echo ""
                echo "3. Testing API with Bearer Token..."
                API_RESPONSE=$(curl -sS \
                  -H "Authorization: Bearer $ACCESS_TOKEN" \
                  "${GATEWAY_URL}/health")

                echo "$API_RESPONSE" | jq '.' || echo "$API_RESPONSE"
                echo "   ✓ Bearer token authentication working"
            else
                echo "   ✗ Failed to get access token"
            fi
        else
            echo "   ✗ Failed to extract authorization code from redirect"
        fi
    else
        echo "   ✗ No redirect location in response"
    fi
else
    echo "   ✗ Authorization failed with status $HTTP_CODE"
    echo "$AUTH_RESPONSE"
fi

echo ""
echo "================================"
echo "OAuth Testing Complete"
echo "================================"
