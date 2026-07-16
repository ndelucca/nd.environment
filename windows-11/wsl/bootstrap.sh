#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=vars.sh
source "$(dirname "${BASH_SOURCE[0]}")/vars.sh"   # provee REPO_DIR, SETUP_DIR, ...
LOG_FILE="${HOME}/.cache/bootstrap-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$(dirname "${LOG_FILE}")"

# Entorno CLI-only para WSL (Debian): terminal + tools de consola, nada de escritorio.
STEPS=(
    "00-packages.sh"
    "01-git.sh"
    "02-tools.sh"
    "03-stow.sh"
    "04-development.sh"
)

declare -a OK_STEPS=()
declare -a FAILED_STEPS=()

log() { echo "[bootstrap] $*" | tee -a "${LOG_FILE}"; }

# stow es prerequisito de 03-stow.sh; el resto de los paquetes los maneja 00-packages.sh.
sudo apt-get update
sudo apt-get install -y stow

for step in "${STEPS[@]}"; do
    file="${SETUP_DIR}/${step}"

    if [[ ! -f "${file}" ]]; then
        log "SKIP ${step} (not found)"
        FAILED_STEPS+=("${step} (missing)")
        continue
    fi

    log "RUN  ${step}"
    if bash "${file}" 2>&1 | tee -a "${LOG_FILE}"; then
        OK_STEPS+=("${step}")
    else
        log "FAIL ${step}"
        FAILED_STEPS+=("${step}")
    fi
done

echo
log "===== Bootstrap summary ====="
for s in "${OK_STEPS[@]:-}"; do [[ -n "${s}" ]] && log "  OK    ${s}"; done
for s in "${FAILED_STEPS[@]:-}"; do [[ -n "${s}" ]] && log "  FAIL  ${s}"; done
log "Full log: ${LOG_FILE}"

if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
    log "Some steps failed. Re-run ./windows-11/wsl/bootstrap.sh to retry (steps are idempotent)."
    exit 1
fi

log "Done. Abrí una terminal nueva para tomar el profile (~/.bashrc.d)."
