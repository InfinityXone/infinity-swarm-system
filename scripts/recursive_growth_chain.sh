#!/usr/bin/env bash
API="https://codex-core.run.app/api/reflect"
while true; do
  payload='{"prompt":"Analyze last 24h logs and propose system improvements."}'
  curl -s -X POST $API -H "Content-Type: application/json" -d "$payload" || true
  sleep 3600
done
