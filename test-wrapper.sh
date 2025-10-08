#!/bin/bash

TOKEN=$(gcloud auth print-identity-token)

curl -X POST https://codex-wrapper-467992722695.us-central1.run.app/api/v1/exec/stream \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Gateway-Key: IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc=" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Qual é 2+2?", "model": "gpt-4o-mini"}' \
  --no-buffer
