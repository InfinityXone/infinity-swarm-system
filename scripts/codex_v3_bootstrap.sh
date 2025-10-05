#!/usr/bin/env bash
# Infinity Codex v3 Bootstrap + Upgrade
# -------------------------------------------------------------------
set -euo pipefail
BASE="$HOME/infinity-swarm-system"
LOG="$BASE/logs/bootstrap_codex_v3.log"
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1

echo "[🧠] Infinity Codex v3 Bootstrap — $(date)"

# -------------------------------------------------------------------
# 1. Verify core folders and create if missing
echo "[*] Auditing folder structure..."

declare -a dirs=(
  "$BASE/apps/api/services/supabase_sync"
  "$BASE/apps/web"
  "$BASE/data/semantic_vectors"
  "$BASE/data/logs"
  "$BASE/infra/systemd"
  "$BASE/scripts"
  "$BASE/logs"
)
for d in "${dirs[@]}"; do mkdir -p "$d"; done

# -------------------------------------------------------------------
# 2. Ensure vault + env foundation
VAULT="$HOME/.config/cloud/vault.json"
mkdir -p "$(dirname "$VAULT")"
[[ ! -f "$VAULT" ]] && echo "{}" > "$VAULT"
chmod 700 "$(dirname "$VAULT")"
chmod 600 "$VAULT"

cat > "$BASE/.gitignore" <<'EOF'
.env
*.key
*.enc
.vault*
*.log
data/semantic_vectors/*
data/supabase_cache.json
EOF

# -------------------------------------------------------------------
# 3. Create core service files if missing
SYNC="$BASE/apps/api/services/supabase_sync/sync.py"
if [[ ! -f "$SYNC" ]]; then
cat > "$SYNC" <<'PYCODE'
import os, json, time, threading
from supabase import create_client, Client
from fastapi import APIRouter

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
CACHE_PATH = os.path.expanduser("~/infinity-swarm-system/data/supabase_cache.json")
router = APIRouter(prefix="/api/supabase", tags=["Supabase Sync"])

def get_client() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)

def sync_loop():
    client = get_client()
    while True:
        try:
            tables = ["blueprint","memory","logs","agents"]
            snapshot={}
            for t in tables:
                data=client.table(t).select("*").execute()
                snapshot[t]=data.data
            os.makedirs(os.path.dirname(CACHE_PATH),exist_ok=True)
            json.dump(snapshot,open(CACHE_PATH,"w"),indent=2)
            print("[sync] cache updated")
        except Exception as e:
            print("[sync] error",e)
        time.sleep(300)

@router.get("/status")
async def status():
    ok=os.path.exists(CACHE_PATH)
    return {"status":"ok" if ok else "missing"}

def start_bg():
    threading.Thread(target=sync_loop,daemon=True).start()
PYCODE
fi

# -------------------------------------------------------------------
# 4. Backend main entry if missing
MAIN="$BASE/apps/api/main.py"
if [[ ! -f "$MAIN" ]]; then
cat > "$MAIN" <<'PYCODE'
from fastapi import FastAPI
from apps.api.services.supabase_sync.sync import router, start_bg

app = FastAPI(title="Infinity Codex Core API")
app.include_router(router)
start_bg()

@app.get("/")
async def root(): return {"status":"running"}
PYCODE
fi

# -------------------------------------------------------------------
# 5. Guardian + Health System
HEALTH="$BASE/scripts/system_health_check.sh"
cat > "$HEALTH" <<'BASH'
#!/usr/bin/env bash
BASE="$HOME/infinity-swarm-system"
REPORT="$BASE/logs/system_health.json"
python_ok=$(which python3 >/dev/null 2>&1 && echo 1 || echo 0)
supabase_ok=$(grep -q SUPABASE_URL "$BASE/.env" 2>/dev/null && echo 1 || echo 0)
dashboard_ok=$(pgrep -f uvicorn >/dev/null && echo 1 || echo 0)
sync_ok=$(grep -q "cache updated" "$BASE/logs/bootstrap_codex_v3.log" && echo 1 || echo 0)
cat > "$REPORT" <<JSON
{
  "timestamp": "$(date)",
  "python_env": $python_ok,
  "supabase_connected": $supabase_ok,
  "dashboard_running": $dashboard_ok,
  "sync_active": $sync_ok
}
JSON
echo "[health] report → $REPORT"
BASH
chmod +x "$HEALTH"

# -------------------------------------------------------------------
# 6. Environment sync + vault backup to cloud
SYNC_SCRIPT="$BASE/scripts/full_recursive_sync.sh"
cat > "$SYNC_SCRIPT" <<'BASH'
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
BASH
chmod +x "$SYNC_SCRIPT"

# -------------------------------------------------------------------
# 7. Create systemd services (local fallback)
SYS="$HOME/.config/systemd/user/codex-health.timer"
mkdir -p "$(dirname "$SYS")"
cat > "$SYS" <<'EOF'
[Unit]
Description=Codex Health Check
[Timer]
OnBootSec=5m
OnUnitActiveSec=10m
Persistent=true
[Install]
WantedBy=timers.target
EOF

cat > "$HOME/.config/systemd/user/codex-health.service" <<'EOF'
[Unit]
Description=Codex Health Diagnostic
[Service]
Type=oneshot
ExecStart=%h/infinity-swarm-system/scripts/system_health_check.sh
EOF

systemctl --user daemon-reload
systemctl --user enable --now codex-health.timer

# -------------------------------------------------------------------
# 8. Final status
echo "[✅] Infinity Codex v3 foundation online."
echo "Check → $BASE/logs/system_health.json"
