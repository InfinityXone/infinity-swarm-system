#!/usr/bin/env bash
set -euo pipefail

REPO="$HOME/infinity-swarm-system"
LOGFILE="$HOME/.config/cloud/git-auto-push.log"
SUPABASE_REF="xzxkyrdelmbqlcucmzpx"
VERCEL_PROJECT="vercel-prj_AqQGs01K6D6hcJWhbQA7SvqBGiAa"

mkdir -p "$(dirname "$LOGFILE")"
exec > >(tee -a "$LOGFILE") 2>&1

echo "== Git Auto Clean & Push ($(date -Iseconds)) =="

cd "$REPO"

# Remove generated or temp dirs (safe)
echo "[Cleanup] pruning cache, dist, node_modules, __pycache__"
find . -type d -name "__pycache__" -exec rm -rf {} + || true
rm -rf build dist .next node_modules .supabase/functions || true

# Git sanity check
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[warn] not a git repo — initializing"
  git init
  git remote add origin git@github.com:InfinityXone/infinity-swarm-system.git || true
fi

git status --short

# Stage clean changes only
git add -A
git reset $(git ls-files -i --exclude-from=.gitignore) 2>/dev/null || true

# Commit if diff exists
if ! git diff --cached --quiet; then
  git commit -m "Automated sync $(date -Iseconds)"
else
  echo "[No changes to commit]"
fi

# Push to main
git push origin main || echo "[warn] push failed"

# Vercel Deploy
if command -v vercel >/dev/null; then
  echo "[Vercel] deploying production"
  vercel --prod --token "$VERCEL_TOKEN" --confirm --yes >/dev/null 2>&1 && echo "[ok] Vercel deploy triggered"
else
  echo "[warn] vercel CLI missing"
fi

# Supabase push / migrate (optional)
if command -v supabase >/dev/null; then
  echo "[Supabase] syncing schema and secrets"
  supabase db push --project-ref "$SUPABASE_REF" >/dev/null 2>&1 || true
  supabase secrets set --from-file /etc/infinity/env/profiles/production/production.env --project-ref "$SUPABASE_REF" >/dev/null 2>&1 || true
else
  echo "[warn] supabase CLI missing"
fi

echo "== Auto push complete =="
