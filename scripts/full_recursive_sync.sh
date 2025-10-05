#!/usr/bin/env bash
set -euo pipefail
LOCAL="/mnt/data/infinity-swarm-system-sync"
REPO="$HOME/infinity-swarm-system"
BUCKET="gs://infinity-swarm-system"
LOG="$HOME/.config/cloud/recursive-sync.log"
mkdir -p "$(dirname "$LOG")"

echo "[sync] $(date -Iseconds)" | tee -a "$LOG"
gsutil -m rsync -r -d "$LOCAL" "$BUCKET" || echo "[warn] gcs push fail" >>"$LOG"
gsutil -m rsync -r "$BUCKET" "$LOCAL" || echo "[warn] gcs pull fail" >>"$LOG"
rsync -avc --update --exclude='.env*' --exclude='*.key' "$LOCAL/" "$REPO/" || echo "[warn] local rsync fail" >>"$LOG"
echo "[sync] done" >>"$LOG"
