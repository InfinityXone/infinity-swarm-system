#!/bin/bash
BASE="$HOME/infinity-swarm-system"
INDEX="$BASE/docs/machine/repo_index.txt"
LOG="$BASE/logs/dashboard_reflection.log"
mkdir -p "$(dirname "$INDEX")" "$BASE/logs"

echo "[$(date)] Scanning repo structure..." | tee -a "$LOG"
find "$BASE" -maxdepth 4 -type f ! -path "*/venv/*" ! -path "*/logs/*" \
  -printf "%P\n" | sort > "$INDEX.tmp"

{
  echo "# Repo Index — $(date)"
  cat "$INDEX.tmp"
} > "$INDEX"
rm "$INDEX.tmp"
echo "[$(date)] Repo index updated." | tee -a "$LOG"
