#!/bin/bash
# ======================================================
# Infinity Swarm Repo Reset + Guardian Setup
# ======================================================

set -euo pipefail
BASE="$HOME/infinity-swarm-system"
BACKUPS="$HOME/infinity-swarm-backups"
STAMP=$(date +"%Y%m%d_%H%M%S")
LOG="$BASE/logs/repo_guard.log"

mkdir -p "$BACKUPS" "$BASE/logs"

echo "[$STAMP] Starting repo reset..." | tee -a "$LOG"

# === 1. BACKUP current repo ===
tar --exclude='venv' -czf "$BACKUPS/infinity-swarm-$STAMP.tgz" -C "$HOME" "infinity-swarm-system"
echo "Backup stored in $BACKUPS/infinity-swarm-$STAMP.tgz" | tee -a "$LOG"

# === 2. CLEAN current repo ===
find "$BASE" -mindepth 1 -maxdepth 1 ! -name logs ! -name scripts ! -name venv -exec rm -rf {} +
echo "Repo cleaned except logs/scripts/venv" | tee -a "$LOG"

# === 3. BOOTSTRAP new structure ===
mkdir -p "$BASE"/{backend/{core,services,api,utils,tests},frontend/{app,components,lib,styles,public},infra,scripts,docs/{human,machine},logs}
touch "$BASE"/docs/{human,machine}/.keep
echo "# Infinity Swarm System (clean bootstrap)" > "$BASE/README.md"
echo "Generated on $(date)" >> "$BASE/README.md"
echo "New structure scaffolded." | tee -a "$LOG"

# === 4. REPO GUARD WATCHER ===
GUARD="$BASE/scripts/repo_guard_watch.sh"
cat > "$GUARD" <<'GUARDEOF'
#!/bin/bash
# ======================================================
# Repo Guardian — keeps structure clean and organized
# ======================================================
BASE="$HOME/infinity-swarm-system"
LOG="$BASE/logs/repo_guard.log"
declare -A allowed
for d in backend frontend infra scripts docs logs; do allowed[$d]=1; done

find "$BASE" -mindepth 1 -maxdepth 1 -type d | while read -r d; do
  name=$(basename "$d")
  if [[ -z "${allowed[$name]:-}" ]]; then
    echo "[$(date)] ⚠ Unrecognized folder '$name' moved to ~/infinity-swarm-orphans/" >> "$LOG"
    mkdir -p "$HOME/infinity-swarm-orphans"
    mv "$d" "$HOME/infinity-swarm-orphans/" 2>/dev/null || true
  fi
done
GUARDEOF
chmod +x "$GUARD"

# === 5. Add cron job ===
( crontab -l 2>/dev/null; echo "*/30 * * * * bash $GUARD" ) | crontab -
echo "Repo guard cron installed (every 30 min)." | tee -a "$LOG"
echo "[$STAMP] Reset complete." | tee -a "$LOG"
