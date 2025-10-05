#!/usr/bin/env bash
BASE="$HOME/infinity-swarm-system"
REPORT="$BASE/logs/system_health.json"
python_ok=$(which python3 >/dev/null 2>&1 && echo 1 || echo 0)
supabase_ok=$(grep -q SUPABASE_URL "$BASE/.env" 2>/dev/null && echo 1 || echo 0)
dashboard_ok=$(pgrep -f uvicorn >/dev/null && echo 1 || echo 0)
sync_ok=$(grep -q "cache updated" "$BASE/logs/bootstrap_codex_v3.log" && echo 1 || echo 0)
cat > "$REPORT" <<JSON
{
  "timestamp": "$(date)",
  "python_env": $python_ok,
  "supabase_connected": $supabase_ok,
  "dashboard_running": $dashboard_ok,
  "sync_active": $sync_ok
}
JSON
echo "[health] report → $REPORT"
