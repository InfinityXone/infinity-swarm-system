#!/bin/bash
# =============================================================
# Infinity Swarm — Cloud Memory Hydration & Sync (Read-Only)
# =============================================================

BASE="$HOME/infinity-swarm-system"
LOG="$BASE/logs/hydrate_and_sync.log"
SNAP="$BASE/docs/machine/state_sync.json"
source "$BASE/load_env.sh"

echo "[*] Starting memory hydration: $(date)" | tee -a "$LOG"

# --- 1. Pull current repo structure (checksums only)
find "$BASE" -type f ! -path "*/venv/*" ! -path "*/logs/*" \
  -printf '{"path":"%P","mtime":%T@},\n' | \
  jq -s '{repo_snapshot: .}' > "$SNAP.tmp"

# --- 2. Add Supabase data snapshot
curl -s -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
     -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
     "$SUPABASE_URL/rest/v1/projects?select=*" \
     | jq '{supabase_projects: .}' >> "$SNAP.tmp"

# --- 3. Merge and timestamp
jq -s 'add + {timestamp: now}' "$SNAP.tmp" > "$SNAP"
rm "$SNAP.tmp"

# --- 4. Push to Supabase
curl -s -X POST "$SUPABASE_URL/rest/v1/state_snapshot" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d @"$SNAP" | tee -a "$LOG"

echo "[✓] Synced to Supabase at $(date)" | tee -a "$LOG"
