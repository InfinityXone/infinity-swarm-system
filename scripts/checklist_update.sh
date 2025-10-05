#!/bin/bash
# ==========================================================
# Infinity Swarm Checklist Auto-Sync
# ==========================================================
BASE="$HOME/infinity-swarm-system"
CHECKLIST="$BASE/docs/machine/build_checklist.json"
TOTAL=0
DONE=0

jq --arg date "$(date)" '.last_scan = $date | .status = {}' "$CHECKLIST" > "$CHECKLIST.tmp"

for dir in backend frontend infra scripts docs logs; do
  have=$(find "$BASE/$dir" -type f | wc -l)
  target=$(jq -r --arg d "$dir" '.sections[$d]|length' "$CHECKLIST" 2>/dev/null || echo 0)
  [[ "$target" == "null" ]] && target=0
  pct=0
  [[ $target -gt 0 ]] && pct=$(( 100 * have / target ))
  jq --arg d "$dir" --argjson have "$have" --argjson target "$target" --argjson pct "$pct" \
     '.status[$d] = {"files_present":$have,"files_expected":$target,"percent":$pct}' \
     "$CHECKLIST.tmp" > "$CHECKLIST.tmp2"
  mv "$CHECKLIST.tmp2" "$CHECKLIST.tmp"
  TOTAL=$((TOTAL+target)); DONE=$((DONE+have))
done

PCT_TOTAL=$(( 100 * DONE / (TOTAL==0?1:TOTAL) ))
jq --argjson total "$TOTAL" --argjson done "$DONE" --argjson pct "$PCT_TOTAL" \
   '.progress = {"total_files":$total,"present":$done,"percent_complete":$pct}' "$CHECKLIST.tmp" > "$CHECKLIST"
echo "Checklist sync complete → ${PCT_TOTAL}% filled."
