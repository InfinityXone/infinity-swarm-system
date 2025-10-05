#!/usr/bin/env bash
BASE="$HOME/infinity-swarm-system"
while true; do
  status=$(curl -s http://127.0.0.1:8000/api/supabase/status | grep ok || true)
  if [ -z "$status" ]; then
    echo "[⚠️] Backend offline — restarting..."
    systemctl --user restart infinity-api.service || true
  fi
  sleep 300
done
