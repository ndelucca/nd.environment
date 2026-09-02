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

# --no-autoremove: sacar SOLO lo declarado (más sus dependientes, que son inevitables:
# no se puede dejar instalado algo que requiere lo que borramos). Sin este flag dnf5 aplica
# clean_requirements_on_remove=True, o sea un autoremove implícito de las DEPENDENCIAS que
# quedan sin usar — y eso no es auditable por adelantado, porque resuelve contra el estado
# del momento. Es la misma razón por la que el bootstrap no corre `dnf autoremove` (ver
# README, "Decisiones deliberadas"): lo que se borra se declara explícito en
# remove-packages.txt.
#
# No es teórico. Declarando el stack de anaconda + cockpit + agentes de VM, la diferencia
# medida en esta máquina fue:
#     sin el flag : 75 paquetes, 379 MB — incluyendo openssl, flatpak, accountsservice,
#                   clevis-luks, udisks2-btrfs y zenity (todos en uso)
#     con el flag : 17 paquetes,  37 MB — exactamente el stack declarado
# Las dependencias que queden huérfanas se limpian a mano con `dnf autoremove` cuando
# corresponda, revisando la lista antes de aceptarla.
if ((${#TO_REMOVE[@]})); then
    echo "Removing unwanted packages: ${TO_REMOVE[*]}"
    sudo dnf remove -y --no-autoremove "${TO_REMOVE[@]}"
else
    echo "No unwanted packages installed. Nothing to remove."
fi
