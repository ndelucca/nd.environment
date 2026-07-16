#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=../vars.sh
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"   # provee SETUP_DIR, LOCALE, read_pkg_list

# --- Paquetes apt -----------------------------------------------------------
echo "Instalando paquetes de packages.txt..."
sudo apt-get update
# read_pkg_list filtra comentarios/blancos; la lista sin comillas se expande en args.
# shellcheck disable=SC2046
sudo apt-get install -y $(read_pkg_list "${SETUP_DIR}/packages.txt")

# --- Locale -----------------------------------------------------------------
# WSL Debian arranca con un locale mínimo; generamos en_US.UTF-8 para que las Nerd Fonts
# y cualquier salida UTF-8 rendericen bien. Idempotente: descomentar + locale-gen no
# molesta si ya está generado.
echo "Generando locale ${LOCALE}..."
sudo sed -i "s/^# *${LOCALE} /${LOCALE} /" /etc/locale.gen
sudo locale-gen
sudo update-locale "LANG=${LOCALE}"

echo "Paquetes y locale listos."
