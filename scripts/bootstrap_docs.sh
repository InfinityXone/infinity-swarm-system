#!/bin/bash
# ==========================================================
# Infinity Swarm Docs + Checklist Bootstrap
# ==========================================================
set -euo pipefail
BASE="$HOME/infinity-swarm-system"
DOCS="$BASE/docs"
CHECKLIST="$BASE/docs/machine/build_checklist.json"
LOG="$BASE/logs/docs_bootstrap.log"

mkdir -p "$DOCS/human" "$DOCS/machine"

# === 1. Create Human Docs with enterprise templates ===
declare -A HUMAN_DOCS=(
  [README.md]="# Infinity Swarm System\nOverview of system purpose, architecture, and ownership."
  [STRATEGY.md]="# Strategy\n- Mission\n- Roadmap\n- Governance\n- Financial vision"
  [BLUEPRINT.md]="# Architecture Blueprint\nSystem components, agents, and communication flow."
  [FOLDER_TREE.md]="# Folder Tree\nDirectory structure and file purpose."
  [SCALE_PLAN.md]="# Scaling Plan\nRegional scaling roadmap, Atlas replication rules."
  [FINANCIAL_PLAN.md]="# Financial Plan\nFinSynapse projections, ROI table, cost model."
  [CHECKLISTS.md]="# Developer Checklist\nSee machine/build_checklist.json for live status."
  [CONTRIBUTORS.md]="# Contributors\nRoles, permissions, and contacts."
  [CHANGELOG.md]="# Change Log\nVersion history and milestones."
)

for f in "${!HUMAN_DOCS[@]}"; do
  echo -e "${HUMAN_DOCS[$f]}" > "$DOCS/human/$f"
done

# === 2. Create Machine Docs placeholders ===
declare -a MACHINE_DOCS=(
  manifest.yaml env.sample supabase_schema.json vercel_config.json
  gcp_service_accounts.json api_endpoints.json cron_manifest.json metrics_spec.json
)
for f in "${MACHINE_DOCS[@]}"; do
  echo "# Auto-generated machine doc: $f" > "$DOCS/machine/$f"
done

# === 3. Extend checklist with doc files ===
if [[ -f "$CHECKLIST" ]]; then
  jq '.sections.docs_human = ["README.md","STRATEGY.md","BLUEPRINT.md","FOLDER_TREE.md","SCALE_PLAN.md","FINANCIAL_PLAN.md","CHECKLISTS.md","CONTRIBUTORS.md","CHANGELOG.md"]
      | .sections.docs_machine = ["manifest.yaml","env.sample","supabase_schema.json","vercel_config.json","gcp_service_accounts.json","api_endpoints.json","cron_manifest.json","metrics_spec.json"]' \
      "$CHECKLIST" > "$CHECKLIST.tmp"
  mv "$CHECKLIST.tmp" "$CHECKLIST"
else
  echo "{}" > "$CHECKLIST"
fi

echo "[$(date)] Docs bootstrap complete." | tee -a "$LOG"
