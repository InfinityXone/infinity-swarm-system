#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
SUPABASE_URL="${SUPABASE_URL:-https://xzxkyrdelmbqlcucmzpx.supabase.co}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-sbp_4d438a8456ad1930739f7847d7855d05340ffeac}"
OUT_DIR="$HOME/.config/cloud/supabase_snapshot_full"

mkdir -p "$OUT_DIR"
echo "== FULL Supabase Snapshot $(date -Iseconds) =="

# --- Get table list from information_schema ---
echo "→ retrieving table names from information_schema..."
TABLES=$(curl -s "${SUPABASE_URL}/rest/v1/information_schema.tables?select=table_name&table_schema=eq.public" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Accept: application/json" | jq -r '.[].table_name')

if [[ -z "$TABLES" ]]; then
  echo "⚠️  No tables found (check Supabase token permissions or project ref)"
  exit 1
fi

# --- Dump data for each table ---
SUMMARY_FILE="${OUT_DIR}/_summary.txt"
echo "Table Row Counts" > "$SUMMARY_FILE"
echo "-----------------" >> "$SUMMARY_FILE"

for t in $TABLES; do
  echo "→ dumping $t ..."
  OUTFILE="${OUT_DIR}/${t}.json"

  curl -s "${SUPABASE_URL}/rest/v1/${t}?select=*&limit=1000" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}" \
    -H "Accept: application/json" \
    -o "$OUTFILE"

  ROWS=$(jq length "$OUTFILE" 2>/dev/null || echo 0)
  printf "%-30s %s rows\n" "$t" "$ROWS" | tee -a "$SUMMARY_FILE"
done

# --- Dump column metadata ---
echo "→ pulling column metadata..."
curl -s "${SUPABASE_URL}/rest/v1/information_schema.columns?select=table_name,column_name,data_type&table_schema=eq.public" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Accept: application/json" \
  -o "${OUT_DIR}/columns.json"

# --- Output summary ---
echo ""
echo "== Snapshot complete =="
cat "$SUMMARY_FILE"
echo ""
echo "All table data + columns.json saved under: $OUT_DIR"
