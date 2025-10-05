#!/bin/bash
# ==========================================================
# Infinity Swarm System — Full Bootstrap & Checklist Tracker
# ==========================================================

set -euo pipefail
BASE="$HOME/infinity-swarm-system"
LOG="$BASE/logs/bootstrap.log"
CHECKLIST="$BASE/docs/machine/build_checklist.json"

echo "[$(date)] Starting bootstrap..." | tee -a "$LOG"

# === 1. Create full folder tree ===
mkdir -p $BASE/{backend/{core,services,api,utils,tests},frontend/{app/{dashboard,agents,wallets,finance,logs,chat,api},components,lib,styles,public},infra,scripts,docs/{human,machine},logs}

# === 2. Create placeholder files ===
touch $BASE/backend/{Dockerfile,requirements.txt,main.py}
touch $BASE/frontend/{package.json,vercel.json}
touch $BASE/infra/{supabase_schema.sql,bootstrap_supabase.sh,gcp_config.yaml,vercel_env_setup.sh,vault_policies.sql,Makefile}
touch $BASE/docs/human/{README.md,STRATEGY.md,BLUEPRINT.md,FOLDER_TREE.md,SCALE_PLAN.md,FINANCIAL_PLAN.md,CHECKLISTS.md,CONTRIBUTORS.md,CHANGELOG.md}
touch $BASE/docs/machine/{manifest.yaml,env.sample,supabase_schema.json,vercel_config.json,gcp_service_accounts.json,api_endpoints.json,cron_manifest.json,metrics_spec.json}
touch $BASE/logs/{guardian.log,sync.log,deploy.log}
touch $BASE/{.env,.gitignore,Makefile}
echo "venv/" > $BASE/.gitignore

# === 3. Create backend agent files ===
for file in orchestrator finance optimizer treasury memory_sync gpt_bridge relay registry; do
  touch "$BASE/backend/core/${file}.py"
done

for file in guardian watcher replicator wallet queue scraper browser atlas compliance anomaly harvester; do
  touch "$BASE/backend/services/${file}.py"
done

for file in tasks finance guardian diagnostics repo chat scraper atlas harvester; do
  touch "$BASE/backend/api/${file}.py"
done

for file in supabase_client gcp_utils vercel_utils playwright_utils logger; do
  touch "$BASE/backend/utils/${file}.py"
done

touch "$BASE/backend/tests/test_health.py"

# === 4. Populate checklist JSON (machine readable) ===
mkdir -p "$(dirname $CHECKLIST)"
cat > "$CHECKLIST" <<'EOF'
{
  "project": "Infinity Swarm System",
  "generated": "$(date)",
  "sections": {
    "backend": ["core","services","api","utils","tests"],
    "frontend": ["app","components","lib","styles","public"],
    "infra": ["supabase_schema.sql","bootstrap_supabase.sh","gcp_config.yaml","vercel_env_setup.sh","vault_policies.sql","Makefile"],
    "docs": ["human","machine"],
    "scripts": [],
    "logs": []
  },
  "status": {}
}
EOF

# === 5. Create checklist updater ===
UPDATER="$BASE/scripts/checklist_update.sh"
cat > "$UPDATER" <<'UPDATEEOF'
#!/bin/bash
# Walks repo tree and updates checklist status
BASE="$HOME/infinity-swarm-system"
CHECKLIST="$BASE/docs/machine/build_checklist.json"

jq --arg date "$(date)" '.last_scan = $date | .status = {}' "$CHECKLIST" > "$CHECKLIST.tmp"

# Iterate over listed sections
for dir in backend frontend infra docs scripts logs; do
  count=$(find "$BASE/$dir" -type f | wc -l)
  jq --arg d "$dir" --argjson c "$count" '.status[$d] = $c' "$CHECKLIST.tmp" > "$CHECKLIST.tmp2"
  mv "$CHECKLIST.tmp2" "$CHECKLIST.tmp"
done

mv "$CHECKLIST.tmp" "$CHECKLIST"
echo "Checklist updated: $(date)"
UPDATEEOF
chmod +x "$UPDATER"

echo "Bootstrap complete — folders and checklist initialized." | tee -a "$LOG"
echo "Run: bash $UPDATER  # to update progress" | tee -a "$LOG"
