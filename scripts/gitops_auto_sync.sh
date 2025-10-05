#!/usr/bin/env bash
set -euo pipefail

REPO="$HOME/infinity-swarm-system"
LOG="$HOME/.config/cloud/gitops-auto-sync.log"
SUPABASE_REF="xzxkyrdelmbqlcucmzpx"
VERCEL_PROJECT="vercel-prj_AqQGs01K6D6hcJWhbQA7SvqBGiAa"

mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1

echo "== GitOps Auto-Sync $(date -Iseconds) =="

cd "$REPO"

# --- Clean ephemeral build output ---
echo "[cleanup] removing build + cache dirs"
find backend -type d \( -name "__pycache__" -o -name "build" -o -name "dist" \) -exec rm -rf {} + || true
rm -rf frontend/.next frontend/out frontend/node_modules || true

# --- Git sanity ---
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git init
  git remote add origin git@github.com:InfinityXone/infinity-swarm-system.git || true
fi

git add -A
git reset $(git ls-files -i --exclude-from=.gitignore) 2>/dev/null || true

if ! git diff --cached --quiet; then
  git commit -m "auto-sync $(date -Iseconds)" || true
  git push origin main || echo "[warn] git push failed"
else
  echo "[no changes]"
fi

# --- Deploy to Vercel ---
if command -v vercel >/dev/null; then
  vercel --prod --token "$VERCEL_TOKEN" --confirm --yes >/dev/null 2>&1 \
    && echo "[ok] vercel deploy"
fi

# --- Supabase schema + secrets ---
if command -v supabase >/dev/null; then
  supabase db push --project-ref "$SUPABASE_REF" >/dev/null 2>&1 || true
  supabase secrets set --from-file /etc/infinity/env/profiles/production/production.env \
    --project-ref "$SUPABASE_REF" >/dev/null 2>&1 || true
fi

echo "== GitOps sync done =="
