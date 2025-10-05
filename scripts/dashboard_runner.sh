#!/bin/bash
# =====================================================
# Infinity Swarm Dashboard Resilient Runner
# =====================================================

source "$HOME/infinity-swarm-system/venv/bin/activate"

APPDIR="$HOME/infinity-swarm-system/scripts"
PORTS=(8088 8090 8092)
LOG="$HOME/infinity-swarm-system/logs/dashboard_runner.log"

while true; do
  PORT_OK=false
  for P in "${PORTS[@]}"; do
    if ! ss -tuln | grep -q ":$P "; then
      PORT_OK=true
      echo "[$(date)] Starting dashboard on port $P" | tee -a "$LOG"
      cd "$APPDIR"
      uvicorn web_dashboard:app --host 0.0.0.0 --port "$P" >>"$LOG" 2>&1
      break
    fi
  done
  if [ "$PORT_OK" = false ]; then
    echo "[$(date)] All preferred ports busy, retrying in 60s..." | tee -a "$LOG"
    sleep 60
  fi
  echo "[$(date)] Dashboard stopped unexpectedly. Restarting in 10s..." | tee -a "$LOG"
  sleep 10
done
