#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=../vars.sh
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"   # provee SETUP_DIR
REMOVE_FILE="${SETUP_DIR}/remove-packages.txt"

# Leer la lista de paquetes a sacar (read_pkg_list saltea comentarios/líneas en blanco).
mapfile -t WANTED_GONE < <(read_pkg_list "${REMOVE_FILE}")

# Actuar solo sobre paquetes realmente instalados, así esto es idempotente y dnf no
# falla con los que ya no están.
TO_REMOVE=()
for pkg in "${WANTED_GONE[@]}"; do
    if rpm -q "${pkg}" &>/dev/null; then
        TO_REMOVE+=("${pkg}")
    fi
done

# --no-autoremove: sacar SOLO lo declarado (más sus dependientes, inevitables). Sin el
# flag dnf5 hace un autoremove implícito de dependencias que no es auditable por adelantado
# (medido: 75 paquetes / 379 MB vs 17 / 37 MB, llevándose openssl y flatpak). NO sacarlo.
# Detalle en README, "Apps que NO queremos" y "Decisiones deliberadas".
if ((${#TO_REMOVE[@]})); then
    echo "Removing unwanted packages: ${TO_REMOVE[*]}"
    sudo dnf remove -y --no-autoremove "${TO_REMOVE[@]}"
else
    echo "No unwanted packages installed. Nothing to remove."
fi
