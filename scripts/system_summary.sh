#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/infinity-swarm-system"
OUT="$ROOT/logs/system_health_summary.txt"
mkdir -p "$ROOT/logs"

echo "====================================================" > "$OUT"
echo " Infinity Swarm System — Repository Summary " >> "$OUT"
echo " Generated: $(date -Iseconds)" >> "$OUT"
echo "====================================================" >> "$OUT"

# --- basic repo info ---
echo "" >> "$OUT"
echo "[ GIT STATUS ]" >> "$OUT"
(cd "$ROOT" && git status -sb 2>/dev/null || echo "not a git repo") >> "$OUT"

# --- folder tree (first 3 levels) ---
echo "" >> "$OUT"
echo "[ DIRECTORY STRUCTURE (depth 3) ]" >> "$OUT"
tree -L 3 "$ROOT" >> "$OUT" 2>/dev/null || find "$ROOT" -maxdepth 3 -type d >> "$OUT"

# --- python service files ---
echo "" >> "$OUT"
echo "[ FASTAPI / SUPABASE SYNC FILES ]" >> "$OUT"
find "$ROOT/apps/api/services/supabase_sync" -type f >> "$OUT" 2>/dev/null || echo "no supabase_sync folder" >> "$OUT"

# --- systemd units ---
echo "" >> "$OUT"
echo "[ SYSTEMD USER UNITS ENABLED ]" >> "$OUT"
systemctl --user list-units --type=service --state=running --no-pager | grep infinity | awk '{$1=$1};1' >> "$OUT" || true
systemctl --user list-timers --no-pager | grep infinity | awk '{$1=$1};1' >> "$OUT" || true

# --- key scripts ---
echo "" >> "$OUT"
echo "[ MAJOR SCRIPTS ]" >> "$OUT"
find "$ROOT/scripts" -maxdepth 1 -type f -exec basename {} \; | sort >> "$OUT"

# --- environment sanity ---
echo "" >> "$OUT"
echo "[ ENVIRONMENT SNAPSHOT ]" >> "$OUT"
grep -E 'SUPABASE|VERCEL|GCP_PROJECT' "$HOME/.config/cloud/cloud-env-sync.env" 2>/dev/null || echo "cloud env file missing" >> "$OUT"

# --- last system health json preview ---
echo "" >> "$OUT"
echo "[ SYSTEM HEALTH JSON HEAD ]" >> "$OUT"
head -n 20 "$ROOT/logs/system_health.json" >> "$OUT" 2>/dev/null || echo "no system_health.json found" >> "$OUT"

echo "" >> "$OUT"
echo "Summary written to $OUT"
echo "===================================================="
cat "$OUT"
