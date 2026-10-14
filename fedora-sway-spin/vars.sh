#!/usr/bin/env bash
#
# Única fuente de verdad (SSOT) para el layout del repo y para valores que de otra
# forma quedarían duplicados entre los scripts de setup y los templates.
#
# Se hace source (no se ejecuta). Como deriva las rutas desde su PROPIA ubicación vía
# BASH_SOURCE, todo script que lo haga source comparte las mismas rutas — no hace falta
# repetir la receta de descubrimiento en cada script. Los consumidores solo necesitan:
#     source "$(dirname "${BASH_SOURCE[0]}")/<...>/vars.sh"

# Las variables las consumen los scripts que hacen source, no este archivo: SC2034
# ("appears unused") es un falso positivo acá.
# shellcheck disable=SC2034

# --- Layout del repo (descubierto una sola vez, acá) ---
SWAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # fedora-sway-spin/
REPO_DIR="$(cd "${SWAY_DIR}/.." && pwd)"                    # raíz del repo
SETUP_DIR="${SWAY_DIR}/setup"
DOTFILES_DIR="${SWAY_DIR}/dotfiles"

# --- Valores de usuario / deployment (versionados a propósito, definidos una vez) ---
TIMEZONE="America/Argentina/Buenos_Aires"
LOCALE="en_US.UTF-8"

# Layout de teclado. KEYMAP es el keymap de CONSOLA (vconsole); KEYMAP_X11 (+ variante
# opcional, vacío = ninguna) es el layout xkb de Wayland/XWayland. Los tres los aplica
# 01-locale-datetime-keyboard.sh con localectl y ahí termina la cadena: sway toma el layout
# de org.freedesktop.locale1 vía el script del Spin (`locale1-xkb-config`, exec_always en
# sway/config.in). No hay un segundo render del layout en ningún dotfile.
KEYMAP="us-euro"
KEYMAP_X11="eu"
KEYMAP_X11_VARIANT=""

# Geolocalización para wlsunset (luz nocturna). Se renderiza en el generado
# sway/config.d/10-wlsunset.conf por 04-stow.sh. Buenos Aires.
LATITUDE="-34.6"
LONGITUDE="-58.4"

# Nombres de los outputs tal como los reporta `swaymsg -t get_outputs` (coinciden con los
# conectores DRM de /sys/class/drm/card*-<nombre>). NO se autodetectan: son valores por
# máquina. Única fuente para sway (workspaces + lid switch) y kanshi (perfiles). Si cambiás
# de máquina, monitor o puerto, actualizá acá y re-corré 04-stow.sh. nd-doctor verifica
# que ambos conectores existan en el kernel, así un nombre equivocado no falla en silencio
# (pasó: decía eDP-1 y esta laptop expone el panel como LVDS-1; kanshi no matcheaba ningún
# perfil y el lid switch no hacía nada). INTERNAL = panel; EXTERNAL = monitor del dock.
OUTPUT_INTERNAL="LVDS-1"
OUTPUT_EXTERNAL="HDMI-A-1"

# Offset X (px) del panel interno en el perfil `docked` de kanshi: equivale al
# ancho del monitor externo ubicado a su IZQUIERDA (OUTPUT_EXTERNAL). kanshi no puede
# hacer aritmética ni posicionamiento relativo, así que el valor vive acá en lugar de
# estar hardcodeado en kanshi/config. Ajustar si el ancho del monitor externo difiere.
DOCK_LEFT_WIDTH="1920"

# Daemons de sesión que arranca systemd --user (NO un `exec` de sway/config): un único
# dueño de cada recurso (nombre de D-Bus, gamma control, output management) y
# Restart=on-failure si se caen. Lo consumen 08-systemd-user.sh (enable --now) y nd-doctor
# (is-active). kanshi y swaync traen su unit en el paquete; wlsunset (template .in, por las
# coordenadas) y swayosd-server son units nuestras en dotfiles/.config/systemd/user/.
SESSION_SERVICES=(
    "kanshi.service"
    "wlsunset.service"
    "swayosd-server.service"
    "swaync.service"
)

# Filtra una lista de paquetes (un nombre por línea), salteando comentarios y líneas en
# blanco. Fuente única del patrón, compartida por 03-apps.sh y 07-remove-unwanted.sh.
read_pkg_list() { grep -vE '^[[:space:]]*(#|$)' "$1"; }

GIT_NAME="ndelucca"
GIT_EMAIL="ndelucca@protonmail.com"

# Cuenta de GitHub dueña del remote origin de este repo (la usa 00-git-bash.sh para pasar
# origin a SSH). Separada de GIT_NAME porque el nombre de autor de commits y el handle de
# la cuenta son hechos distintos, aunque hoy coincidan.
GITHUB_USER="ndelucca"
