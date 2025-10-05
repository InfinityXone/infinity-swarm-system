#!/usr/bin/env bash
# Infinity Codex v3 – Full System Diagnosis
set -euo pipefail
BASE="$HOME/infinity-swarm-system"
REPORT="$BASE/logs/system_diagnosis.json"
mkdir -p "$(dirname "$REPORT")"

echo "[*] Scanning Infinity Codex v3 structure..."

# expected top-level dirs
expected=(
  "$BASE/apps/api"
  "$BASE/apps/web"
  "$BASE/data"
  "$BASE/data/semantic_vectors"
  "$BASE/scripts"
  "$BASE/logs"
  "$BASE/infra"
  "$BASE/.config/cloud"
)

# gather file info
declare -A results
for path in "${expected[@]}"; do
  if [[ -d "$path" ]]; then
    count=$(find "$path" -type f | wc -l)
    results["$path"]="✅ ($count files)"
  else
    results["$path"]="❌ missing"
  fi
done

# env / vault check
env_status="❌ missing"
vault_status="❌ missing"
[[ -f "$BASE/.env" ]] && env_status="✅ present"
[[ -f "$HOME/.config/cloud/vault.json" ]] && vault_status="✅ present"

# active services
api_active=$(systemctl --user is-active infinity-api.service 2>/dev/null || true)
health_active=$(systemctl --user is-active codex-health.timer 2>/dev/null || true)

# supabase cache info
cache="$BASE/data/supabase_cache.json"
cache_state="❌ missing"
cache_bytes=0
if [[ -f "$cache" ]]; then
  cache_bytes=$(stat -c%s "$cache")
  cache_state="✅ ${cache_bytes} bytes"
fi

# backend endpoint check
api_status="❌ offline"
if curl -s --max-time 3 http://127.0.0.1:8000/api/supabase/status >/tmp/api_status.json 2>/dev/null; then
  api_status="✅ responding"
fi

# build report
cat >"$REPORT"<<JSON
{
  "timestamp": "$(date -Iseconds)",
  "folders": {
$(for k in "${!results[@]}"; do echo "    \"${k/$BASE\//}\": \"${results[$k]}\","; done)
    "_end": ""
  },
  "env": "$env_status",
  "vault": "$vault_status",
  "services": {
    "infinity-api.service": "$api_active",
    "codex-health.timer": "$health_active"
  },
  "supabase_cache": "$cache_state",
  "api_endpoint": "$api_status"
}
JSON

echo "[✓] Diagnosis complete → $REPORT"
cat "$REPORT"
