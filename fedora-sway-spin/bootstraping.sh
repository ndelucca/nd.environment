#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=vars.sh
source "$(dirname "${BASH_SOURCE[0]}")/vars.sh"   # provee REPO_DIR, SETUP_DIR, ...
LOG_FILE="${HOME}/.cache/bootstrap-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$(dirname "${LOG_FILE}")"

STEPS=(
    "00-git-bash.sh"
    "01-locale-datetime-keyboard.sh"
    "02-fonts-wallpaper-sddm-grub.sh"
    "03-apps.sh"
    "04-stow.sh"
    "05-webapps.sh"
    "06-development.sh"
    "07-remove-unwanted.sh"
    "08-systemd-user.sh"
    "09-chromium-policies.sh"
    "10-power.sh"
    "11-memory.sh"
    "12-auto-updates.sh"
)

declare -a OK_STEPS=()
declare -a FAILED_STEPS=()

log() { echo "[bootstrap] $*" | tee -a "${LOG_FILE}"; }

sudo dnf install -y stow

log "Initializing git submodules..."
git -C "${REPO_DIR}" submodule update --init --recursive 2>&1 | tee -a "${LOG_FILE}"

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

# Chequeo de suposiciones sobre el Spin (informativo, no aborta el bootstrap). Se invoca
# por ruta del repo porque ~/.local/bin puede no estar en PATH en esta shell todavía.
echo
log "===== Spin assumptions check (nd-doctor) ====="
"${DOTFILES_DIR}/.local/bin/nd-doctor" 2>&1 | tee -a "${LOG_FILE}" || true

if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
    log "Some steps failed. Re-run ./fedora-sway-spin/bootstraping.sh to retry (steps are idempotent)."
    exit 1
fi

log "Done."
