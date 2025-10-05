#!/bin/bash
# ==========================================================
# Infinity Swarm Dashboard Auto-Port Launcher
# ==========================================================

APPDIR="$HOME/infinity-swarm-system/scripts"
source "$HOME/infinity-swarm-system/venv/bin/activate"

START_PORT=8088
MAX_PORT=8100
LOG="$HOME/infinity-swarm-system/logs/dashboard_autorun.log"

cd "$APPDIR"

echo "[$(date)] Checking available port range $START_PORT-$MAX_PORT..." | tee -a "$LOG"

PORT=$START_PORT
while [ $PORT -le $MAX_PORT ]; do
  if ! ss -tuln | grep -q ":$PORT "; then
    echo "[$(date)] Starting FastAPI dashboard on port $PORT" | tee -a "$LOG"
    uvicorn web_dashboard:app --host 0.0.0.0 --port $PORT --reload >>"$LOG" 2>&1
    exit 0
  fi
  PORT=$((PORT+1))
done

echo "[$(date)] No open ports available in range." | tee -a "$LOG"
exit 1
