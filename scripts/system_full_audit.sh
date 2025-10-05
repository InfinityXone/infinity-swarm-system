#!/usr/bin/env bash
# system_full_audit.sh
# Comprehensive audit for Infinity Codex environment
# Writes human-readable report and JSON summary to ~/infinity-swarm-system/logs/full_audit_*.{txt,json}
#
# Usage:
#   chmod +x ~/infinity-swarm-system/scripts/system_full_audit.sh
#   ~/infinity-swarm-system/scripts/system_full_audit.sh

set -uo pipefail
IFS=$'\n\t'

BASE="$HOME/infinity-swarm-system"
LOGDIR="$BASE/logs"
mkdir -p "$LOGDIR"
TS=$(date -u +"%Y%m%dT%H%M%SZ")
OUT_TXT="$LOGDIR/full_audit_${TS}.txt"
OUT_JSON="$LOGDIR/full_audit_${TS}.json"
TMPDIR="$(mktemp -d /tmp/codex_audit.XXXXXX)"

echo "Starting Infinity Codex full audit: $TS"
echo "Output (text): $OUT_TXT"
echo "Output (json): $OUT_JSON"
echo

# helper
safe_cmd() { "$@" 2>&1 || true; }

# --- collect basic system info ---
echo "== SYSTEM INFO ==" >"$OUT_TXT"
uname -a >>"$OUT_TXT" 2>&1
echo >>"$OUT_TXT"
echo "Timezone: $(date +'%z %Z') / Localtime: $(date)" >>"$OUT_TXT"
echo >>"$OUT_TXT"

echo "== ENV SUMMARY ==" >>"$OUT_TXT"
echo "User: $USER" >>"$OUT_TXT"
echo "HOME: $HOME" >>"$OUT_TXT"
echo "PWD: $(pwd)" >>"$OUT_TXT"
echo >>"$OUT_TXT"

# Environment variable snapshot (non-secret filter)
echo "== .env & Vault files (existence) ==" >>"$OUT_TXT"
for f in "$BASE/.env" "$BASE/.env.local" "$BASE/.env.production" "$HOME/.config/cloud/vault.json" "$HOME/.config/cloud/vault.json.enc"; do
  if [[ -f "$f" ]]; then
    echo "$f : exists (size: $(stat -c%s "$f") bytes, mtime: $(stat -c%y "$f"))" >>"$OUT_TXT"
  else
    echo "$f : MISSING" >>"$OUT_TXT"
  fi
done
echo >>"$OUT_TXT"

# --- repository and folder tree checks ---
echo "== TOP-LEVEL FOLDERS (counts) ==" >>"$OUT_TXT"
for p in "$BASE" "$BASE/apps" "$BASE/apps/api" "$BASE/apps/web" "$BASE/data" "$BASE/data/semantic_vectors" "$BASE/scripts" "$BASE/infra" "$BASE/logs" "$BASE/.config"; do
  if [[ -e "$p" ]]; then
    echo "$p -> $(find "$p" -maxdepth 3 -type f | wc -l) files" >>"$OUT_TXT"
  else
    echo "$p -> MISSING" >>"$OUT_TXT"
  fi
done
echo >>"$OUT_TXT"

echo "== FULL FOLDER TREE (trimmed to depth 4) ==" >>"$OUT_TXT"
safe_cmd find "$BASE" -maxdepth 4 -type d -print | sed "s|$HOME|~|" >>"$OUT_TXT"
echo >>"$OUT_TXT"

# list top files in key dirs
echo "== SAMPLE FILES: apps/api ==" >>"$OUT_TXT"
safe_cmd ls -la "$BASE/apps/api" >>"$OUT_TXT" 2>&1
echo >>"$OUT_TXT"
echo "== SAMPLE FILES: apps/web ==" >>"$OUT_TXT"
safe_cmd ls -la "$BASE/apps/web" >>"$OUT_TXT" 2>&1
echo >>"$OUT_TXT"

# --- git repositories (scan for .git) ---
echo "== GIT REPOS FOUND ==" >>"$OUT_TXT"
REPOS=()
while IFS= read -r repo; do
  REPOS+=("$repo")
  echo "---- $repo ----" >>"$OUT_TXT"
  safe_cmd git -C "$repo" remote -v >>"$OUT_TXT" 2>&1
  safe_cmd git -C "$repo" status --porcelain -b | sed -n '1,20p' >>"$OUT_TXT" 2>&1
  echo >>"$OUT_TXT"
done < <(find "$BASE" -maxdepth 4 -type d -name ".git" -print 2>/dev/null | sed 's/\/.git$//')

if [[ ${#REPOS[@]} -eq 0 ]]; then
  echo "No git repositories found under $BASE (search depth 4)." >>"$OUT_TXT"
fi
echo >>"$OUT_TXT"

# --- python / venv info ---
echo "== PYTHON / VENV ==" >>"$OUT_TXT"
if [[ -d "$BASE/venv" ]]; then
  PY="$BASE/venv/bin/python3"
  echo "venv: $BASE/venv exists" >>"$OUT_TXT"
  echo "python: $(safe_cmd "$PY" --version)" >>"$OUT_TXT"
  echo "pip freeze (top 80 lines):" >>"$OUT_TXT"
  safe_cmd "$BASE/venv/bin/pip" freeze | sed -n '1,80p' >>"$OUT_TXT"
else
  echo "venv: NOT FOUND at $BASE/venv" >>"$OUT_TXT"
fi
echo >>"$OUT_TXT"

# --- fastapi / uvicorn processes & logs ---
echo "== FASTAPI / Uvicorn processes ==" >>"$OUT_TXT"
ps aux | egrep 'uvicorn|fastapi|apps.api.main|python.*main.py' | egrep -v 'egrep' || true >>"$OUT_TXT"
echo >>"$OUT_TXT"

echo "== API logs (tail 200 lines if present) ==" >>"$OUT_TXT"
if [[ -f "$BASE/logs/api.log" ]]; then
  safe_cmd tail -n 200 "$BASE/logs/api.log" >>"$OUT_TXT"
else
  echo "api.log not found" >>"$OUT_TXT"
fi
echo >>"$OUT_TXT"

# --- supabase cache ---
echo "== SUPABASE CACHE ==" >>"$OUT_TXT"
if [[ -f "$BASE/data/supabase_cache.json" ]]; then
  echo "supabase_cache.json exists (size: $(stat -c%s "$BASE/data/supabase_cache.json") bytes)" >>"$OUT_TXT"
  echo "Top of file:" >>"$OUT_TXT"
  safe_cmd head -n 120 "$BASE/data/supabase_cache.json" >>"$OUT_TXT"
else
  echo "supabase_cache.json MISSING" >>"$OUT_TXT"
fi
echo >>"$OUT_TXT"

# --- mnt data sync path ---
SYNC_PATH="/mnt/data/infinity-swarm-system-sync"
echo "== /mnt DATA SYNC ==" >>"$OUT_TXT"
if [[ -d "$SYNC_PATH" ]]; then
  echo "$SYNC_PATH exists -> summary:" >>"$OUT_TXT"
  safe_cmd du -sh "$SYNC_PATH"/* 2>/dev/null | sed -n '1,40p' >>"$OUT_TXT"
  echo >>"$OUT_TXT"
  safe_cmd find "$SYNC_PATH" -maxdepth 3 -type f -printf "%p %s bytes\n" | sed -n '1,200p' >>"$OUT_TXT"
else
  echo "$SYNC_PATH -> MISSING" >>"$OUT_TXT"
fi
echo >>"$OUT_TXT"

# --- docker (if present) ---
echo "== DOCKER (images & containers) ==" >>"$OUT_TXT"
if command -v docker >/dev/null 2>&1; then
  safe_cmd docker ps -a --no-trunc | sed -n '1,200p' >>"$OUT_TXT"
  echo >>"$OUT_TXT"
  safe_cmd docker images --format '{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}' | sed -n '1,100p' >>"$OUT_TXT"
else
  echo "docker CLI not found" >>"$OUT_TXT"
fi
echo >>"$OUT_TXT"

# --- systemd user units and timers ---
echo "== systemd (user units & timers) ==" >>"$OUT_TXT"
safe_cmd systemctl --user list-units --type=service --no-legend | sed -n '1,200p' >>"$OUT_TXT" 2>&1
echo >>"$OUT_TXT"
safe_cmd systemctl --user list-timers --no-legend | sed -n '1,200p' >>"$OUT_TXT" 2>&1
echo >>"$OUT_TXT"

echo "== systemd unit files present under ~/.config/systemd/user ==" >>"$OUT_TXT"
safe_cmd ls -la ~/.config/systemd/user | sed -n '1,200p' >>"$OUT_TXT" 2>&1
echo >>"$OUT_TXT"

# --- cron / crontab ---
echo "== crontab & /etc/cron* ==" >>"$OUT_TXT"
echo "-- current user's crontab --" >>"$OUT_TXT"
safe_cmd crontab -l 2>/dev/null >>"$OUT_TXT"
echo >>"$OUT_TXT"
echo "-- system cron folders --" >>"$OUT_TXT"
safe_cmd ls -la /etc/cron* 2>/dev/null | sed -n '1,200p' >>"$OUT_TXT"
echo >>"$OUT_TXT"

# --- cloud CLIs and status checks (if installed) ---
echo "== CLOUD CLIS ==" >>"$OUT_TXT"
# gcloud
if command -v gcloud >/dev/null 2>&1; then
  echo "gcloud present" >>"$OUT_TXT"
  safe_cmd gcloud config list --format=json >>"$OUT_TXT" 2>&1
  safe_cmd gcloud projects list --limit=20 --format="value(projectId)" >>"$OUT_TXT" 2>&1
else
  echo "gcloud not installed" >>"$OUT_TXT"
fi
echo >>"$OUT_TXT"

# vercel
if command -v vercel >/dev/null 2>&1; then
  echo "vercel CLI present" >>"$OUT_TXT"
  safe_cmd vercel whoami >>"$OUT_TXT"
  safe_cmd vercel projects ls --json | sed -n '1,80p' >>"$OUT_TXT"
else
  echo "vercel CLI not installed" >>"$OUT_TXT"
fi
echo >>"$OUT_TXT"

# supabase CLI
if command -v supabase >/dev/null 2>&1; then
  echo "supabase CLI present" >>"$OUT_TXT"
  safe_cmd supabase projects list >>"$OUT_TXT" 2>&1
else
  echo "supabase CLI not installed" >>"$OUT_TXT"
fi
echo >>"$OUT_TXT"

# docker-compose
if command -v docker-compose >/dev/null 2>&1; then
  echo "docker-compose present" >>"$OUT_TXT"
  safe_cmd docker-compose -v >>"$OUT_TXT"
else
  echo "docker-compose not installed" >>"$OUT_TXT"
fi
echo >>"$OUT_TXT"

# --- network ports ---
echo "== NETWORK PORTS (listening) ==" >>"$OUT_TXT"
if command -v ss >/dev/null 2>&1; then
  safe_cmd ss -ltnp | sed -n '1,200p' >>"$OUT_TXT"
elif command -v netstat >/dev/null 2>&1; then
  safe_cmd netstat -ltnp | sed -n '1,200p' >>"$OUT_TXT"
else
  echo "ss/netstat not available" >>"$OUT_TXT"
fi
echo >>"$OUT_TXT"

# --- processes of interest ---
echo "== PROCESSES OF INTEREST (infinity|codex|uvicorn|gpt|bridge) ==" >>"$OUT_TXT"
ps aux | egrep 'infinity|codex|uvicorn|gpt_bridge|gpt_bridge_sync|bridge|codex' | sed -n '1,200p' >>"$OUT_TXT" 2>&1
echo >>"$OUT_TXT"

# --- secrets & sensitive notes (only existence) ---
echo "== SENSITIVE FILES (exists only) ==" >>"$OUT_TXT"
for s in "$BASE/.env" "$BASE/.env.production" "$HOME/.config/cloud/vault.json"; do
  if [[ -f "$s" ]]; then
    echo "$s -> exists (size $(stat -c%s "$s") bytes, mtime $(stat -c%y "$s"))" >>"$OUT_TXT"
  fi
done
echo >>"$OUT_TXT"

# --- summary counts to JSON ---
echo "Building JSON summary..."

# helper to JSON-escape
je() { python3 - <<PY
import json,sys
print(json.dumps(sys.stdin.read()))
PY
}

# Build JSON using here-doc
cat >"$OUT_JSON" <<JSON
{
  "timestamp": "$(date -Iseconds)",
  "base_path": "$BASE",
  "folders": {
    "apps_api_exists": $( [[ -d "$BASE/apps/api" ]] && echo true || echo false ),
    "apps_web_exists": $( [[ -d "$BASE/apps/web" ]] && echo true || echo false ),
    "data_exists": $( [[ -d "$BASE/data" ]] && echo true || echo false ),
    "semantic_vectors_count": $( (find "$BASE/data/semantic_vectors" -type f 2>/dev/null | wc -l) || echo 0 )
  },
  "git_repos_scanned": $(echo "${#REPOS[@]}" || echo 0),
  "venv_present": $( [[ -d "$BASE/venv" ]] && echo true || echo false ),
  "supabase_cache_present": $( [[ -f "$BASE/data/supabase_cache.json" ]] && echo true || echo false ),
  "infinity_api_service_status": "$(systemctl --user is-enabled infinity-api.service 2>/dev/null || echo 'not-enabled') / $(systemctl --user is-active infinity-api.service 2>/dev/null || echo 'not-active')",
  "codex_health_timer_status": "$(systemctl --user is-enabled codex-health.timer 2>/dev/null || echo 'not-enabled') / $(systemctl --user is-active codex-health.timer 2>/dev/null || echo 'not-active')",
  "mnt_sync_path": "$(if [[ -d "$SYNC_PATH" ]]; then echo "$SYNC_PATH"; else echo ""; fi)",
  "docker_present": $(command -v docker >/dev/null 2>&1 && echo true || echo false),
  "gcloud_present": $(command -v gcloud >/dev/null 2>&1 && echo true || echo false),
  "vercel_present": $(command -v vercel >/dev/null 2>&1 && echo true || echo false),
  "supabase_cli_present": $(command -v supabase >/dev/null 2>&1 && echo true || echo false)
}
JSON

# copy the human-readable file into logs and echo location
echo "Audit complete."
echo "Text report: $OUT_TXT"
echo "JSON summary: $OUT_JSON"

# cleanup temp
rm -rf "$TMPDIR"
