#!/usr/bin/env bash
# Infinity Repo Evolution Tracker — persistent, self-updating repo tree map
# --------------------------------------------------------------------------
BASE="${HOME}/infinity-swarm-system"
LOG_DIR="${BASE}/logs"
MAP_TXT="${LOG_DIR}/repo_map.txt"
MAP_JSON="${LOG_DIR}/repo_map.json"
SNAP_DIR="${LOG_DIR}/repo_snapshots"

mkdir -p "$LOG_DIR" "$SNAP_DIR"

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

echo "[🧭] Scanning repo at $(timestamp)"

# Generate readable tree
tree -a -I '.git|__pycache__|venv|node_modules|.next|.DS_Store' "$BASE" > "$MAP_TXT"

# Generate structured JSON summary
echo '{' > "$MAP_JSON"
echo "  \"timestamp\": \"$(timestamp)\"," >> "$MAP_JSON"
echo '  "repo_structure": [' >> "$MAP_JSON"
find "$BASE" -type d -printf '    {"folder":"%P"},\n' >> "$MAP_JSON"
find "$BASE" -type f -printf '    {"file":"%P"},\n' >> "$MAP_JSON"
echo '  ]' >> "$MAP_JSON"
echo '}' >> "$MAP_JSON"

# Save a dated copy
cp "$MAP_JSON" "${SNAP_DIR}/repo_map_$(date -u +%Y%m%dT%H%M%S).json"

# Optional: Git auto-commit of structure map
if [ -d "$BASE/.git" ]; then
  cd "$BASE"
  git add "$LOG_DIR/repo_map.txt" "$LOG_DIR/repo_map.json" || true
  git commit -m "Auto: repo structure snapshot $(timestamp)" >/dev/null 2>&1 || true
fi

echo "[✅] Repo map updated → $MAP_JSON"
