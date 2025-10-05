#!/bin/bash
# ==============================================================
# Infinity Swarm — Foundational System Bootstrap + Diagnostics
# ==============================================================

set -e
BASE="$HOME/infinity-swarm-system"
LOG="$BASE/logs/system_bootstrap.log"
mkdir -p "$BASE"/{logs,scripts}

echo "[$(date)] 🧭 Starting Foundation Bootstrap..." | tee -a "$LOG"

# ---------- 1. Install Core Packages ----------
sudo apt-get update -y >>"$LOG" 2>&1
sudo apt-get install -y curl jq python3-venv python3-pip libnotify-bin >>"$LOG" 2>&1

# ---------- 2. Verify Virtualenv ----------
if [ ! -d "$BASE/venv" ]; then
  echo "Creating virtual environment..." | tee -a "$LOG"
  python3 -m venv "$BASE/venv"
fi
source "$BASE/venv/bin/activate"
pip install -q fastapi uvicorn jinja2 psutil python-multipart

# ---------- 3. Health Check Script ----------
cat > "$BASE/scripts/system_health_check.sh" <<'EOF'
#!/bin/bash
BASE="$HOME/infinity-swarm-system"
LOG="$BASE/logs/system_health.log"
REPORT="$BASE/logs/system_diagnostic.json"
mkdir -p "$BASE/logs"

timestamp=$(date +'%Y-%m-%d %H:%M:%S')
echo "[$timestamp] Running health check..." | tee -a "$LOG"

# --- Folder Structure ---
for d in backend frontend infra scripts docs logs; do
  [ -d "$BASE/$d" ] || { echo "Missing dir: $d"; mkdir -p "$BASE/$d"; }
done

# --- Service States ---
declare -A status
services=(infinity-dashboard.service infinity-dashboard-reflect.timer infinity-healthcheck.timer)
for s in "${services[@]}"; do
  systemctl --user is-active --quiet "$s" && status[$s]="running" || status[$s]="stopped"
done

# --- Virtualenv ---
pyenv_ok=0
source "$BASE/venv/bin/activate" 2>/dev/null && python3 -c "import fastapi,uvicorn" 2>/dev/null && pyenv_ok=1

# --- Supabase Connectivity ---
supabase_ok=0
if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_SERVICE_ROLE_KEY" ]; then
  curl -s --max-time 10 -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" "$SUPABASE_URL/rest/v1/?select=*" >/dev/null && supabase_ok=1
fi

# --- Dashboard Process ---
pgrep -f "uvicorn web_dashboard:app" >/dev/null && dash_ok=1 || dash_ok=0

# --- Git Sync ---
git -C "$BASE" status >/dev/null 2>&1 && git_ok=1 || git_ok=0

# --- Compile JSON Report ---
{
  echo "{"
  echo "\"timestamp\": \"$timestamp\","
  echo "\"python_env_ok\": $pyenv_ok,"
  echo "\"dashboard_running\": $dash_ok,"
  echo "\"supabase_connected\": $supabase_ok,"
  echo "\"git_ok\": $git_ok,"
  echo "\"services\": {"
  for s in "${!status[@]}"; do
    echo "\"$s\": \"${status[$s]}\","
  done | sed '$ s/,$//'
  echo "}}"
} >"$REPORT"

echo "[$timestamp] ✅ Diagnostic complete → $REPORT" | tee -a "$LOG"
EOF
chmod +x "$BASE/scripts/system_health_check.sh"

# ---------- 4. Reflection Hook ----------
cat > "$BASE/scripts/update_repo_index.sh" <<'EOF'
#!/bin/bash
BASE="$HOME/infinity-swarm-system"
INDEX="$BASE/docs/machine/repo_index.txt"
LOG="$BASE/logs/dashboard_reflection.log"
mkdir -p "$(dirname "$INDEX")" "$BASE/logs"

echo "[$(date)] Scanning repo structure..." | tee -a "$LOG"
find "$BASE" -maxdepth 4 -type f ! -path "*/venv/*" ! -path "*/logs/*" \
  -printf "%P\n" | sort > "$INDEX.tmp"

{
  echo "# Repo Index — $(date)"
  cat "$INDEX.tmp"
} > "$INDEX"
rm "$INDEX.tmp"
echo "[$(date)] Repo index updated." | tee -a "$LOG"
EOF
chmod +x "$BASE/scripts/update_repo_index.sh"

# ---------- 5. systemd Units ----------
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/infinity-healthcheck.service <<'EOF'
[Unit]
Description=Infinity Swarm Health Check
After=default.target
[Service]
Type=oneshot
ExecStart=%h/infinity-swarm-system/scripts/system_health_check.sh
StandardOutput=append:%h/infinity-swarm-system/logs/system_health.log
StandardError=append:%h/infinity-swarm-system/logs/system_health.log
EOF

cat > ~/.config/systemd/user/infinity-healthcheck.timer <<'EOF'
[Unit]
Description=Run Infinity Swarm Health Check every 10 minutes
[Timer]
OnBootSec=2min
OnUnitActiveSec=10min
Persistent=true
[Install]
WantedBy=timers.target
EOF

cat > ~/.config/systemd/user/infinity-dashboard-reflect.service <<'EOF'
[Unit]
Description=Infinity Swarm Repo Reflection Hook
After=default.target
[Service]
Type=oneshot
ExecStart=%h/infinity-swarm-system/scripts/update_repo_index.sh
StandardOutput=append:%h/infinity-swarm-system/logs/dashboard_reflection.log
StandardError=append:%h/infinity-swarm-system/logs/dashboard_reflection.log
EOF

cat > ~/.config/systemd/user/infinity-dashboard-reflect.timer <<'EOF'
[Unit]
Description=Run Reflection Hook every 3 minutes
[Timer]
OnBootSec=1min
OnUnitActiveSec=3min
Persistent=true
[Install]
WantedBy=timers.target
EOF

# ---------- 6. Enable Services ----------
systemctl --user daemon-reload
systemctl --user enable --now infinity-healthcheck.timer
systemctl --user enable --now infinity-dashboard-reflect.timer

# ---------- 7. Immediate Diagnostic ----------
echo "Running initial diagnostic..."
bash "$BASE/scripts/system_health_check.sh"

echo
echo "=================================================================="
echo "Foundation bootstrap complete. System services now active."
echo "Health reports stored in: $BASE/logs/system_diagnostic.json"
echo "=================================================================="
cat "$BASE/logs/system_diagnostic.json" | jq .
