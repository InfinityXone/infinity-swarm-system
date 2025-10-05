#!/bin/bash
# ==========================================================
# Infinity Swarm Full Cloud Sync
# Local <-> GitHub <-> Supabase <-> Google Cloud <-> Vercel
# ==========================================================

BASE="$HOME/infinity-swarm-system"
LOG="$BASE/logs/full_cloud_sync.log"
LOCK="$BASE/.sync.lock"
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# ---- Safety Checks ----
check_folder_integrity() {
  echo "[*] Validating folder structure..." | tee -a "$LOG"
  local expected=(backend frontend infra scripts docs logs)
  for f in "${expected[@]}"; do
    if [ ! -d "$BASE/$f" ]; then
      echo "[!] Missing critical folder: $f" | tee -a "$LOG"
      mkdir -p "$BASE/$f"
    fi
  done
}

check_naming_conventions() {
  echo "[*] Checking naming conventions..." | tee -a "$LOG"
  find "$BASE" -type f | while read -r f; do
    name=$(basename "$f")
    if [[ "$name" =~ [[:space:]] ]]; then
      echo "[!] File '$name' contains spaces — rename recommended." | tee -a "$LOG"
    fi
  done
}

safe_commit() {
  git add .
  if ! git diff --cached --quiet; then
    git commit -m "Auto-sync $(date +'%Y-%m-%d %H:%M:%S')"
  fi
}

# ---- GitHub Sync ----
sync_git() {
  cd "$BASE" || exit 1
  echo "[*] Syncing GitHub..." | tee -a "$LOG"
  git pull --rebase --autostash 2>&1 | tee -a "$LOG"
  safe_commit
  git push 2>&1 | tee -a "$LOG"
}

# ---- Supabase Sync ----
sync_supabase() {
  if command -v supabase >/dev/null 2>&1; then
    echo "[*] Syncing Supabase..." | tee -a "$LOG"
    supabase db pull 2>&1 | tee -a "$LOG"
    supabase db push 2>&1 | tee -a "$LOG"
  fi
}

# ---- Vercel Sync ----
sync_vercel() {
  if command -v vercel >/dev/null 2>&1; then
    echo "[*] Syncing Vercel..." | tee -a "$LOG"
    vercel pull --yes --environment=production 2>&1 | tee -a "$LOG"
    vercel deploy --prebuilt --yes 2>&1 | tee -a "$LOG"
  fi
}

# ---- Google Cloud Sync ----
sync_gcp() {
  if command -v gcloud >/dev/null 2>&1; then
    echo "[*] Syncing Google Cloud..." | tee -a "$LOG"
    gcloud config configurations activate default >/dev/null 2>&1
    gcloud storage rsync "$BASE" "gs://infinity-agent-artifacts" --recursive --quiet 2>&1 | tee -a "$LOG"
  fi
}

# ---- Mirror dashboard ----
mirror_dashboard() {
  echo "[*] Updating dashboard index..." | tee -a "$LOG"
  find "$BASE" -maxdepth 3 -type f -printf "%P\n" > "$BASE/docs/machine/repo_index.txt"
}

# ---- Protection Mechanism ----
check_integrity_and_sync() {
  check_folder_integrity
  check_naming_conventions
  sync_git
  sync_supabase
  sync_vercel
  sync_gcp
  mirror_dashboard
}

# ---- Main Loop ----
if [ -f "$LOCK" ]; then
  echo "[!] Sync already running."
  exit 0
fi
touch "$LOCK"

while true; do
  echo "==== Sync Cycle $(date) ====" | tee -a "$LOG"
  check_integrity_and_sync
  echo "[✓] Sync completed at $(date)" | tee -a "$LOG"
  sleep 300  # 5 minutes
done

rm -f "$LOCK"
