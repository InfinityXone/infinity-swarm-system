#!/usr/bin/env bash
set -euo pipefail
# ===============================================================
# Infinity Swarm — Full Recursive Cloud + Repo Sync
# Safe, checksummed, environment-aware version
# ===============================================================

LOCAL_DIR="/mnt/data/infinity-swarm-system-sync"
REPO_DIR="$HOME/infinity-swarm-system"
BUCKET="gs://infinity-swarm-system"
LOGFILE="$HOME/.config/cloud/recursive-sync.log"
mkdir -p "$(dirname "$LOGFILE")"

exec > >(tee -a "$LOGFILE") 2>&1
echo "== Recursive Sync ($(date -Iseconds)) =="

# ---- Validation Layer ----
REQUIRED=("SUPABASE_URL" "SUPABASE_SERVICE_ROLE_KEY" "GCP_PROJECT" "VERCEL_TOKEN")
for v in "${REQUIRED[@]}"; do
  if [ -z "${!v:-}" ]; then
    echo "[warn] Missing required env var: $v"
  fi
done

# ---- Push local → GCS ----
echo "[GCS] syncing local → bucket"
gsutil -m rsync -r -d "$LOCAL_DIR" "$BUCKET" || echo "[warn] GCS push failed"

# ---- Pull GCS → local ----
echo "[GCS] syncing bucket → local"
gsutil -m rsync -r "$BUCKET" "$LOCAL_DIR" || echo "[warn] GCS pull failed"

# ---- Mirror approved → repo (with checksum + update) ----
echo "[Local] syncing approved → repo"
rsync -avc --update --checksum \
  --exclude='.env*' --exclude='*.key' \
  "$LOCAL_DIR/" "$REPO_DIR/" || echo "[warn] local rsync failed"

# ---- Auto-verify before commit ----
cd "$REPO_DIR"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if ! git diff --quiet; then
    git add .
    git commit -m "Auto sync $(date -Iseconds)" || true
    git push origin main || echo "[warn] Git push failed"
    echo "[GitHub] repo sync complete"
  else
    echo "[GitHub] no changes to commit"
  fi
else
  echo "[warn] not a git repo: $REPO_DIR"
fi

echo "== Sync complete =="
