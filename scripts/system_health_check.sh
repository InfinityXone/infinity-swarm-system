#!/bin/bash
BASE="$HOME/infinity-swarm-system"
LOG="$BASE/logs/system_health.log"
REPORT="$BASE/logs/system_diagnostic.json"
mkdir -p "$BASE/logs"

timestamp=$(date +'%Y-%m-%d %H:%M:%S')
echo "[$timestamp] Running health check..." | tee -a "$LOG"

# --- Folder Structure ---
for d in backend frontend infra scripts docs logs; do
  [ -d "$BASE/$d" ] || { echo "Missing dir: $d"; mkdir -p "$BASE/$d"; }
done

# --- Service States ---
declare -A status
services=(infinity-dashboard.service infinity-dashboard-reflect.timer infinity-healthcheck.timer)
for s in "${services[@]}"; do
  systemctl --user is-active --quiet "$s" && status[$s]="running" || status[$s]="stopped"
done

# --- Virtualenv ---
pyenv_ok=0
source "$BASE/venv/bin/activate" 2>/dev/null && python3 -c "import fastapi,uvicorn" 2>/dev/null && pyenv_ok=1

# --- Supabase Connectivity ---
supabase_ok=0
if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_SERVICE_ROLE_KEY" ]; then
  curl -s --max-time 10 -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" "$SUPABASE_URL/rest/v1/?select=*" >/dev/null && supabase_ok=1
fi

# --- Dashboard Process ---
pgrep -f "uvicorn web_dashboard:app" >/dev/null && dash_ok=1 || dash_ok=0

# --- Git Sync ---
git -C "$BASE" status >/dev/null 2>&1 && git_ok=1 || git_ok=0

# --- Compile JSON Report ---
{
  echo "{"
  echo "\"timestamp\": \"$timestamp\","
  echo "\"python_env_ok\": $pyenv_ok,"
  echo "\"dashboard_running\": $dash_ok,"
  echo "\"supabase_connected\": $supabase_ok,"
  echo "\"git_ok\": $git_ok,"
  echo "\"services\": {"
  for s in "${!status[@]}"; do
    echo "\"$s\": \"${status[$s]}\","
  done | sed '$ s/,$//'
  echo "}}"
} >"$REPORT"

echo "[$timestamp] ✅ Diagnostic complete → $REPORT" | tee -a "$LOG"
