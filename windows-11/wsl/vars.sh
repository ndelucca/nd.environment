#!/usr/bin/env bash
#
# Única fuente de verdad (SSOT) para el layout de este entorno y para valores que de
# otra forma quedarían duplicados entre los scripts de setup. Mismo patrón que
# fedora-sway-spin/vars.sh: se hace source (no se ejecuta) y deriva las rutas desde su
# PROPIA ubicación vía BASH_SOURCE, así todo script que lo haga source comparte las
# mismas rutas sin repetir la receta de descubrimiento.

# Las variables las consumen los scripts que hacen source, no este archivo: SC2034
# ("appears unused") es un falso positivo acá.
# shellcheck disable=SC2034

# --- Layout del repo (descubierto una sola vez, acá) ---
WSL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # windows-11/wsl/
WIN_DIR="$(cd "${WSL_DIR}/.." && pwd)"                     # windows-11/
REPO_DIR="$(cd "${WSL_DIR}/../.." && pwd)"                 # raíz del repo
SETUP_DIR="${WSL_DIR}/setup"
DOTFILES_DIR="${WSL_DIR}/dotfiles"

# --- Valores de usuario (versionados a propósito, definidos una vez) ---
# Mismos valores que fedora-sway-spin/vars.sh: es la misma persona y el mismo repo.
# No hay TIMEZONE (WSL hereda la hora de Windows) ni keymap/output/geoloc (son desktop).
LOCALE="en_US.UTF-8"

GIT_NAME="ndelucca"
GIT_EMAIL="ndelucca@protonmail.com"

# Cuenta de GitHub dueña del remote origin de este repo (la usa 01-git.sh para pasar
# origin a SSH).
GITHUB_USER="ndelucca"

# Filtra una lista de paquetes (un nombre por línea), salteando comentarios y líneas en
# blanco. Mismo helper que Fedora; lo consume 00-packages.sh.
read_pkg_list() { grep -vE '^[[:space:]]*(#|$)' "$1"; }
