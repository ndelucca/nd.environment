#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=../vars.sh
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"   # provee SETUP_DIR

echo "Actualizando wallpaper del sistema"
sudo cp "${SETUP_DIR}/wallpaper.png" /usr/share/backgrounds/wallpaper.png
sudo cp "${SETUP_DIR}/wallpaper-swaylock.png" /usr/share/backgrounds/wallpaper-swaylock.png

echo "Configuración de SDDM"
echo "Apuntando el tema de SDDM a nuestro wallpaper"
# El tema del Spin (03-sway-fedora) lee su fondo de theme.conf; SDDM lee además, si
# existe, un theme.conf.user al lado, que pisa clave por clave (mecanismo oficial de
# SDDM para personalizar un tema sin tocarlo). Es un archivo del sistema, así que vale
# para todos los usuarios y para el greeter (que corre antes de cualquier login).
# Una versión anterior copiaba nuestro wallpaper SOBRE /usr/share/backgrounds/default.jxl.
# Ese nombre es un symlink al fondo real del release (f44/default/f44-01-day.jxl, del RPM
# f44-backgrounds-base), así que el `cp` pisaba el archivo real: cada update de ese
# paquete lo restauraba en silencio, y el .bak que guardábamos era una copia de la
# versión ya pisada (inútil). Si el archivo real difiere de su RPM, se reinstala el
# paquete (fuente autoritativa) y se tira el .bak.
SDDM_THEME_DIR="/usr/share/sddm/themes/03-sway-fedora"
SDDM_DEFAULT_BG="$(readlink -f /usr/share/backgrounds/default.jxl 2>/dev/null || true)"
bg_pkg="$(rpm -qf "${SDDM_DEFAULT_BG:-/nonexistent}" 2>/dev/null || true)"
# rpm -V sale 1 cuando hay diferencias: sin el `|| true`, pipefail anula el grep.
if [[ -n "${bg_pkg}" ]] && { rpm -V "${bg_pkg}" 2>/dev/null || true; } | grep -qF "${SDDM_DEFAULT_BG}"; then
    echo "Restaurando ${SDDM_DEFAULT_BG} (lo pisaba una versión vieja del setup): reinstalando ${bg_pkg}"
    sudo dnf reinstall -y "${bg_pkg}"
fi
sudo rm -f /usr/share/backgrounds/default.jxl.bak
if sudo test -d "${SDDM_THEME_DIR}"; then
    sudo tee "${SDDM_THEME_DIR}/theme.conf.user" >/dev/null <<'EOF'
# Override de theme.conf (lo escribe setup/02-fonts-wallpaper-sddm-grub.sh).
[General]
background=/usr/share/backgrounds/wallpaper.png
EOF
else
    echo "AVISO: no existe ${SDDM_THEME_DIR}; el Spin cambió de tema de SDDM, revisar."
fi

echo "Creando archivo de configuración de sddm"
# EnableHiDPI va bajo [Wayland] y [X11] (ver `sddm --example-config`); bajo [General]
# es un no-op silencioso. Es la opción general para cualquier máquina: en un panel de
# baja densidad no cambia nada, en uno HiDPI el greeter escala.
sudo tee /etc/sddm.conf.d/ndelucca.conf >/dev/null <<'EOF'
[Autologin]
# User=ndelucca
# Session=sway
[Theme]
EnableAvatars=false
[Wayland]
EnableHiDPI=true
[X11]
EnableHiDPI=true
EOF

echo "Configurando GRUB2"

# En Fedora (desde la 34) el grub.cfg es uno solo, /boot/grub2/grub.cfg, en BIOS y en
# UEFI: /etc/grub2.cfg y /etc/grub2-efi.cfg apuntan ahí, y el grub.cfg de la partición
# EFI es un stub que lo redirige. Una versión anterior escribía la salida de mkconfig en
# /boot/efi/EFI/fedora/grub.cfg cuando había UEFI: eso pisa el stub.
GRUB_CFG="/boot/grub2/grub.cfg"
THEME_DIR="/boot/grub2/themes/breeze"
THEME_FILE="${THEME_DIR}/theme.txt"
REPO_URL="https://github.com/gustawho/grub2-theme-breeze.git"
# Commit fijo del tema: lo que va a /boot como root tiene que ser siempre lo mismo, no
# "lo que haya en main hoy". Para actualizarlo, cambiar el hash a conciencia.
THEME_COMMIT="a2dd860c1fa869a73472167d18bea23c5a0de39b"

if ! sudo test -f "${THEME_FILE}"; then
    # El tmpdir se crea solo en el camino de instalación, así no queda basura en
    # /tmp cuando el tema ya está y este paso es no-op. El fetch corre como usuario
    # (sin sudo); solo la copia a /boot necesita root.
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "${TMP_DIR:-}"' EXIT
    git init -q "${TMP_DIR}/repo"
    git -C "${TMP_DIR}/repo" fetch -q --depth=1 "${REPO_URL}" "${THEME_COMMIT}"
    git -C "${TMP_DIR}/repo" checkout -q FETCH_HEAD
    sudo mkdir -p /boot/grub2/themes
    sudo rm -rf "${THEME_DIR}"
    sudo cp -r "${TMP_DIR}/repo/breeze" "${THEME_DIR}"

    sudo sed -i '/^GRUB_THEME=/d' /etc/default/grub
    echo "GRUB_THEME=\"${THEME_FILE}\"" | sudo tee -a /etc/default/grub >/dev/null

    if ! grep -q '^GRUB_TERMINAL_OUTPUT="gfxterm"' /etc/default/grub; then
        echo 'GRUB_TERMINAL_OUTPUT="gfxterm"' | sudo tee -a /etc/default/grub >/dev/null
    fi

    sudo grub2-mkconfig -o "${GRUB_CFG}"
else
    echo "Tema ya instalado en ${THEME_FILE}"
fi

# Rofi se configura por completo vía dotfiles (~/.config/rofi/, tema nd-dark
# autocontenido). No hace falta clonar colecciones de temas externas.
