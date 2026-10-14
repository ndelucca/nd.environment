#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=../vars.sh
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"   # provee LOCALE, TIMEZONE, KEYMAP, KEYMAP_X11, KEYMAP_X11_VARIANT

echo "Fedora $0"
echo "Configuring locale (${LOCALE}) keymap (${KEYMAP} / x11 ${KEYMAP_X11}${KEYMAP_X11_VARIANT:+ ${KEYMAP_X11_VARIANT}}) and timezone (${TIMEZONE})..."

sudo localectl set-locale "LANG=${LOCALE}"
sudo timedatectl set-timezone "${TIMEZONE}"

# --no-convert en ambos: sin él, cada `set-*-keymap` intenta además derivar el OTRO keymap
# y pisa el que acabamos de setear. Así quedó `VC Keymap: (unset)` durante meses: el
# set-x11-keymap "eu" no tiene equivalente de consola y borraba el us-euro de la línea
# anterior. nd-doctor compara ambos valores contra vars.sh.
sudo localectl --no-convert set-keymap "${KEYMAP}"
# Firma: set-x11-keymap LAYOUT [MODEL [VARIANT [OPTIONS]]]; MODEL vacío = default.
if [[ -n "${KEYMAP_X11_VARIANT}" ]]; then
    sudo localectl --no-convert set-x11-keymap "${KEYMAP_X11}" "" "${KEYMAP_X11_VARIANT}"
else
    sudo localectl --no-convert set-x11-keymap "${KEYMAP_X11}"
fi

# El layout de la sesión sway sale de org.freedesktop.locale1 (lo que acabamos de setear)
# vía el script del Spin /usr/libexec/sway-systemd/locale1-xkb-config, que sway/config.in
# ejecuta en cada arranque/reload. No generamos ningún archivo de teclado. Una versión
# vieja de este setup escribía /usr/share/sway/config.d/10-keyboard.conf a mano (archivo
# que ningún RPM posee); si quedó de aquella época, se retira para no tener dos fuentes.
STRAY="/usr/share/sway/config.d/10-keyboard.conf"
if [[ -f "${STRAY}" ]] && ! rpm -qf "${STRAY}" &>/dev/null; then
    echo "Retirando ${STRAY} (huérfano de una versión vieja del setup; el layout viene de locale1)"
    sudo rm -f "${STRAY}"
fi

echo "Localization - datetime - keyboard configured successfully!"
localectl status | grep -E 'System Locale|Keymap|Layout' || true
timedatectl | grep "Time zone" || true
