#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
SUPABASE_URL="${SUPABASE_URL:-https://xzxkyrdelmbqlcucmzpx.supabase.co}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-sbp_4d438a8456ad1930739f7847d7855d05340ffeac}"
OUT_DIR="$HOME/.config/cloud/supabase_snapshot"
mkdir -p "$OUT_DIR"

echo "== Supabase Snapshot $(date -Iseconds) =="
echo "Writing to: $OUT_DIR"

# simple query helper
run_query() {
  local table="$1"
  local limit="${2:-100}"
  local outfile="$OUT_DIR/${table}.json"
  echo "→ pulling $table ($limit rows)..."
  curl -s "$SUPABASE_URL/rest/v1/$table?select=*&limit=$limit" \
    -H "apikey: $SUPABASE_KEY" \
    -H "Authorization: Bearer $SUPABASE_KEY" \
    -H "Accept: application/json" \
    -o "$outfile"
}

# --- core tables ---
run_query "logs" 200
run_query "memory_rosetta" 100
run_query "memory_vectors" 100
run_query "metrics" 100

# --- optional: list tables / schema overview ---
echo "→ listing all tables..."
curl -s "$SUPABASE_URL/rest/v1/?select=table_name" \
  -H "apikey: $SUPABASE_KEY" \
  -H "Authorization: Bearer $SUPABASE_KEY" \
  -H "Accept: application/json" \
  -o "$OUT_DIR/schema_overview.json" || true

# --- summary ---
echo ""
echo "== Snapshot summary =="
for f in "$OUT_DIR"/*.json; do
  echo "$(basename "$f"): $(jq length "$f" 2>/dev/null || echo '?') rows"
done

echo ""
echo "== Done. All data saved under: $OUT_DIR =="
