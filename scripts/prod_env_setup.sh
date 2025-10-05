#!/usr/bin/env bash
# File: scripts/prod_env_setup.sh
# Purpose: Auto-clean .env, harden for production, and install robust env loader.

set -euo pipefail

PROJECT_ROOT="${1:-$HOME/infinity-swarm-system}"
ENV_FILE="${PROJECT_ROOT}/.env"
BACKUP_FILE="${ENV_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
CLEANED_FILE="${ENV_FILE}.cleaned"
EXAMPLE_FILE="${PROJECT_ROOT}/.env.example"
LOADER_FILE="${PROJECT_ROOT}/load_env.sh"
REPORT_FILE="${PROJECT_ROOT}/.env_clean_report.txt"

mkdir -p "${PROJECT_ROOT}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "[-] No .env found at ${ENV_FILE}" >&2
  exit 1
fi

cp "${ENV_FILE}" "${BACKUP_FILE}"
echo "[+] Backup created: ${BACKUP_FILE}"

# Python cleaner emitted to temp file
PYTMP="$(mktemp -t envcleaner.XXXXXX.py)"
cat > "${PYTMP}" << 'PYCODE'
#!/usr/bin/env python3
from __future__ import annotations
import os, re, sys, pathlib

ROOT = pathlib.Path(sys.argv[1]).expanduser().resolve()
ENV_FILE = ROOT / ".env"
CLEANED_FILE = ROOT / ".env.cleaned"
REPORT_FILE = ROOT / ".env_clean_report.txt"
EXAMPLE_FILE = ROOT / ".env.example"

kv_line_re = re.compile(r'^\s*([^=\s#][^=]*)\s*=\s*(.*)$')
yaml_sep_re = re.compile(r'^\s*---\s*$')

def normalize_key(raw: str) -> str:
    import re
    k = raw.strip().replace('-', '_')
    k = re.sub(r'\W', '_', k)
    k = re.sub(r'_+', '_', k)
    if not re.match(r'^[A-Za-z_]', k): k = '_' + k
    return k.upper()

def needs_quotes(v: str) -> bool:
    if not v or v[:1] in ("'", '"'):
        return False
    risky = set(' ,:@/#~`$&*()[]{}|;<>\\')
    return any(c in risky for c in v)

def smart_quote(v: str) -> str:
    if v[:1] in ("'", '"'):
        return v
    v = v.replace('\\', '\\\\').replace('"', '\\"')
    return f'"{v}"'

def looks_like_pubkey_path(v: str) -> bool:
    return v.endswith('.pub') and (v.startswith('~') or v.startswith('/'))

def read_pubkey_if_exists(v: str) -> str | None:
    p = pathlib.Path(os.path.expanduser(v))
    if p.exists() and p.is_file() and p.stat().st_size < 10000:
        return p.read_text(encoding='utf-8').strip()
    return None

def scrub_trailing_greater(v: str) -> str:
    return v.rstrip('>') if (v and v[-1] == '>' and (not v.endswith('\\>'))) else v

raw_lines = ENV_FILE.read_text(encoding='utf-8', errors='ignore').splitlines()

cleaned, example, dropped, renamed, modified = [], [], [], [], []
for idx, s in enumerate(raw_lines, 1):
    t = s.rstrip('\n')
    if t.strip().startswith('#') or t.strip() == '':
        continue
    if yaml_sep_re.match(t):
        dropped.append((idx, t, "YAML separator '---'"))
        continue
    m = kv_line_re.match(t)
    if not m:
        dropped.append((idx, t, "Not KEY=VALUE"))
        continue

    raw_key, raw_val = m.group(1).strip(), m.group(2).strip()
    new_key = normalize_key(raw_key)
    if new_key != raw_key: renamed.append((raw_key, new_key))

    val = raw_val
    if val[:1] not in ("'", '"'):
        val = re.split(r'(?<!\\)#', val, maxsplit=1)[0].rstrip()
        val = scrub_trailing_greater(val)

    if val[:1] not in ("'", '"') and looks_like_pubkey_path(val):
        pk = read_pubkey_if_exists(val)
        if pk:
            val = pk
            modified.append((new_key, "inlined SSH pubkey content"))

    if needs_quotes(val):
        val = smart_quote(val)

    cleaned.append(f"{new_key}={val}")
    example.append(f"{new_key}=<set-in-prod>")

CLEANED_FILE.write_text("\n".join(cleaned) + "\n", encoding='utf-8')
EXAMPLE_FILE.write_text("\n".join(example) + "\n", encoding='utf-8')
with REPORT_FILE.open('w', encoding='utf-8') as rf:
    rf.write("# .env Cleaning Report\n\n")
    if renamed:
        rf.write("Renamed keys:\n" + "\n".join(f"- {a} -> {b}" for a,b in renamed) + "\n\n")
    if modified:
        rf.write("Modified values:\n" + "\n".join(f"- {k}: {why}" for k,why in modified) + "\n\n")
    if dropped:
        rf.write("Dropped lines:\n" + "\n".join(f"- line {n}: {why}: {txt}" for n,txt,why in dropped) + "\n")
PYCODE
chmod +x "${PYTMP}"

python3 "${PYTMP}" "${PROJECT_ROOT}"
mv "${CLEANED_FILE}" "${ENV_FILE}"
echo "[+] Cleaned .env → ${ENV_FILE}"
echo "[i] Report  → ${REPORT_FILE}"
echo "[i] Example → ${EXAMPLE_FILE}"

# .gitignore hygiene
GITIGNORE="${PROJECT_ROOT}/.gitignore"
touch "${GITIGNORE}"
grep -qE '(^|/)\.env(\s|$)' "${GITIGNORE}" || echo ".env" >> "${GITIGNORE}"
grep -qE '(^|/)!\.env\.example(\s|$)' "${GITIGNORE}" || echo "!.env.example" >> "${GITIGNORE}"
echo "[+] .gitignore updated"

# Hardened loader
cat > "${LOADER_FILE}" << 'LOADER'
#!/usr/bin/env bash
set -euo pipefail
ENV_FILE="${1:-$HOME/infinity-swarm-system/.env}"
TMP_CLEAN="${ENV_FILE}.tmp.load"
echo "[+] Loading environment from ${ENV_FILE}"
[[ -f "${ENV_FILE}" ]] || { echo "[-] .env not found: ${ENV_FILE}" >&2; exit 1; }
grep -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=' "${ENV_FILE}" \
  | sed -E 's/^[[:space:]]+//; s/[[:space:]]+=/=/' > "${TMP_CLEAN}"
set -a
# shellcheck disable=SC1090
. "${TMP_CLEAN}"
set +a
rm -f "${TMP_CLEAN}"
echo "[✓] Environment loaded"
LOADER
chmod +x "${LOADER_FILE}"

# Lock perms
chmod 600 "${ENV_FILE}" || true
chmod 644 "${EXAMPLE_FILE}" || true

# Smoke test
set +e
source "${LOADER_FILE}" "${ENV_FILE}" >/dev/null 2>&1
RC=$?
set -e
if [[ ${RC} -eq 0 ]]; then
  echo "[✓] Smoke load OK"
else
  echo "[-] Smoke load failed (${RC}). See ${REPORT_FILE}" >&2
fi

echo "[i] Sample checks:"
for k in SUPABASE_URL GROQ_API_KEYS OPERATOR_EMAIL SSH_PUB_KEY; do
  v=$(bash -c "source '${LOADER_FILE}' '${ENV_FILE}' >/dev/null 2>&1; printf '%s' \"\${$k:-}\"")
  [[ -n "${v}" ]] && echo " - ${k} present" || echo " - ${k} not set"
done
echo "[done]"
