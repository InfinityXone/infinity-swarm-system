#!/bin/bash
# =====================================================
# Infinity Swarm Continuous Sync + Health Update
# =====================================================
BASE="$HOME/infinity-swarm-system"
LOG="$BASE/logs/swarm_sync.log"

while true; do
  echo "[$(date)] Syncing checklist + health..." | tee -a "$LOG"
  bash "$BASE/scripts/checklist_update.sh" >>"$LOG" 2>&1
  # TODO: add rclone or supabase push commands here if desired
  sleep 900  # every 15 minutes
done
