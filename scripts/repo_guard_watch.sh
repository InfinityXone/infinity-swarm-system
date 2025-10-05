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
