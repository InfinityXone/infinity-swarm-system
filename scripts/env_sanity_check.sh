# File: ~/infinity-swarm-system/scripts/env_sanity_check.sh
#!/usr/bin/env bash
# Why: standalone diagnostics that won't terminate your interactive shell.

set -u  # no -e to avoid abrupt exit on non-zero; we handle RCs
PROJECT_ROOT="${1:-$HOME/infinity-swarm-system}"
ENV_FILE="${PROJECT_ROOT}/.env"
LOADER_FILE="${PROJECT_ROOT}/load_env.sh"
LOG_DIR="${PROJECT_ROOT}"
TS="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${LOG_DIR}/.env_diagnose_${TS}.log"

mkdir -p "${LOG_DIR}" "${PROJECT_ROOT}/scripts" >/dev/null 2>&1 || true

mask() {  # why: avoid leaking secrets in logs
  local s="${1:-}"; local n=${#s}
  if (( n <= 8 )); then printf '****'; else printf '%s…%s' "${s:0:6}" "${s: -3}"; fi
}

echo "[*] .env diagnostics @ ${TS}" | tee -a "${LOG_FILE}"
echo "[i] Project: ${PROJECT_ROOT}" | tee -a "${LOG_FILE}"
echo "[i] ENV:     ${ENV_FILE}" | tee -a "${LOG_FILE}"
echo "[i] Loader:  ${LOADER_FILE}" | tee -a "${LOG_FILE}"
echo | tee -a "${LOG_FILE}"

RC=0
if [[ ! -f "${ENV_FILE}" ]]; then echo "[-] Missing .env at ${ENV_FILE}" | tee -a "${LOG_FILE}"; RC=1; fi
if [[ ! -f "${LOADER_FILE}" ]]; then echo "[-] Missing loader at ${LOADER_FILE}" | tee -a "${LOG_FILE}"; RC=1; fi
[[ ${RC} -ne 0 ]] && { echo "[!] Fix above and re-run." | tee -a "${LOG_FILE}"; exit 1; }

echo "[+] Static lint:" | tee -a "${LOG_FILE}"
BAD_YAML=$(grep -nE '^\s*---\s*$' "${ENV_FILE}" || true)
BAD_DASH_KEYS=$(grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*-[A-Za-z0-9_-]*[[:space:]]*=' "${ENV_FILE}" || true)
NON_KV=$(grep -nE '^[[:space:]]*[^#[:space:]=][^=]*$' "${ENV_FILE}" || true)
TRAILING_GT=$(grep -nE '=[^#"]*>\s*$' "${ENV_FILE}" || true)

[[ -n "${BAD_YAML}" ]]      && { echo "  - YAML separators:" | tee -a "${LOG_FILE}"; echo "${BAD_YAML}" | tee -a "${LOG_FILE}"; RC=1; }
[[ -n "${BAD_DASH_KEYS}" ]] && { echo "  - Keys with dashes:" | tee -a "${LOG_FILE}"; echo "${BAD_DASH_KEYS}" | tee -a "${LOG_FILE}"; RC=1; }
[[ -n "${NON_KV}" ]]        && { echo "  - Non KEY=VALUE lines:" | tee -a "${LOG_FILE}"; echo "${NON_KV}" | tee -a "${LOG_FILE}"; RC=1; }
[[ -n "${TRAILING_GT}" ]]   && { echo "  - Values ending with '>':" | tee -a "${LOG_FILE}"; echo "${TRAILING_GT}" | tee -a "${LOG_FILE}"; RC=1; }
[[ ${RC} -eq 0 ]] && echo "  - Static lint OK." | tee -a "${LOG_FILE}"

echo | tee -a "${LOG_FILE}"
echo "[+] Subshell load test (clean env):" | tee -a "${LOG_FILE}"

# Clean environment subshell to avoid contaminating or killing current shell
LOAD_OUT="$(env -i HOME="$HOME" bash -c "
  set -u
  # keep output minimal from loader; we still capture stderr
  source '${LOADER_FILE}' '${ENV_FILE}' >/dev/null 2>&1 || exit 42
  # print selected vars; one per line as KEY=VALUE
  for k in SUPABASE_URL GROQ_API_KEYS OPERATOR_EMAIL SSH_PUB_KEY; do
    printf '%s=' \"\$k\"
    eval \"printf '%s' \\\"\${$k:-}\\\" \"
    printf '\n'
  done
  # count exported vars (rough estimate)
  env | wc -l
")"
SUB_RC=$?
if [[ ${SUB_RC} -eq 0 ]]; then
  echo "  - Loader sourced successfully." | tee -a "${LOG_FILE}"
  VAR_LINES="$(printf '%s\n' "${LOAD_OUT}" | head -n 4)"
  COUNT_LINE="$(printf '%s\n' "${LOAD_OUT}" | tail -n 1)"
  while IFS='=' read -r K V; do
    [[ -z "${K}" ]] && continue
    echo "    • ${K}: $(mask "${V}")" | tee -a "${LOG_FILE}"
  done <<< "${VAR_LINES}"
  echo "  - Env var count (approx): ${COUNT_LINE}" | tee -a "${LOG_FILE}"
else
  echo "  - Loader failed with code ${SUB_RC}" | tee -a "${LOG_FILE}"
  echo "    Suggest: run prod_env_setup.sh again to re-clean." | tee -a "${LOG_FILE}"
  RC=1
fi

echo | tee -a "${LOG_FILE}"
echo "[+] Extra checks:" | tee -a "${LOG_FILE}"
# Unquoted risky values (heuristic)
UNQUOTED_RISK=$(grep -nE '^[A-Za-z_][A-Za-z0-9_]*=\S*[ ,:@/#~`$&*(){}\[\];<>\\]\S*$' "${ENV_FILE}" | grep -v '"' || true)
[[ -n "${UNQUOTED_RISK}" ]] && { echo "  - Unquoted risky values:" | tee -a "${LOG_FILE}"; echo "${UNQUOTED_RISK}" | tee -a "${LOG_FILE}"; RC=1; } || echo "  - No obvious unquoted risky values." | tee -a "${LOG_FILE}"

echo | tee -a "${LOG_FILE}"
if [[ ${RC} -eq 0 ]]; then
  echo "[✓] Sanity check passed." | tee -a "${LOG_FILE}"
  echo "[i] Log: ${LOG_FILE}"
  exit 0
else
  echo "[-] Issues detected. See log: ${LOG_FILE}" | tee -a "${LOG_FILE}"
  exit 1
fi
