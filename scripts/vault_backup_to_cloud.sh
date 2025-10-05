#!/bin/bash
# =====================================================
# Vault Backup Script — backs up only encrypted vaults
# =====================================================
VAULT_DIR="$HOME/.config/cloud"
VAULT_ENC="$VAULT_DIR/vault.json.enc"
BUCKET="gs://infinity-swarm-system/vault_backups"
LOG="$HOME/infinity-swarm-system/logs/vault_backup.log"

mkdir -p "$(dirname "$LOG")"

echo "[$(date)] Starting secure vault backup..." | tee -a "$LOG"

if [ ! -f "$VAULT_ENC" ]; then
  echo "[warn] No encrypted vault found — run: python3 scripts/vault_system.py encrypt" | tee -a "$LOG"
  exit 1
fi

# verify authentication before uploading
if ! gsutil ls "$BUCKET" >/dev/null 2>&1; then
  echo "[warn] GCS bucket unreachable — run 'gcloud auth application-default login'" | tee -a "$LOG"
  exit 1
fi

gsutil cp "$VAULT_ENC" "$BUCKET/vault_$(date +%Y%m%d_%H%M).json.enc" && \
  echo "[ok] Vault encrypted copy uploaded to GCS" | tee -a "$LOG"

chmod 600 "$VAULT_ENC"
echo "[$(date)] Backup complete" | tee -a "$LOG"
