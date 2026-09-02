#!/usr/bin/env bash

set -euo pipefail

# Descarga anticipada de updates (NO instalación automática).
#
# Decisión: los updates se DESCARGAN en background y se instalan a mano. Así el
# `dnf upgrade` de siempre corre casi instantáneo (los paquetes ya están en caché) sin
# que el sistema cambie por su cuenta a espaldas nuestras. No hay notificación de
# escritorio a propósito: no queremos un aviso más, solo que la descarga esté hecha.
#
# El paquete dnf5-plugin-automatic (declarado en packages.txt) ya trae exactamente esos
# defaults en /usr/share/dnf5/dnf5-plugins/automatic.conf:
#     download_updates = yes   apply_updates = no   emit_via = stdio
# así que NO forkeamos ningún config — mismo criterio que con el resto del sistema: si el
# default ya es el que queremos, solo habilitamos el timer. Lo que sí hacemos es
# VERIFICAR esas dos claves, porque si una versión futura del paquete cambiara el default
# a apply_updates=yes el sistema empezaría a auto-instalar en silencio.
#
# El timer corre a las 06:00 con hasta 1 h de retraso aleatorio y Persistent=true, así que
# en una laptop apagada a esa hora el chequeo se recupera en el próximo arranque.

DEFAULTS_CONF="/usr/share/dnf5/dnf5-plugins/automatic.conf"
OVERRIDE_CONF="/etc/dnf/automatic.conf"

if ! rpm -q dnf5-plugin-automatic &>/dev/null; then
    echo "dnf5-plugin-automatic no está instalado; corré 03-apps.sh primero."
    exit 0
fi

# get_setting <clave> — valor efectivo: gana el override de /etc si define la clave.
get_setting() {
    local key="$1" val=""
    local f
    for f in "${DEFAULTS_CONF}" "${OVERRIDE_CONF}"; do
        [[ -r "${f}" ]] || continue
        # Última asignación no comentada gana dentro de cada archivo.
        local hit
        hit="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "${f}" 2>/dev/null | tail -n1)" || true
        [[ -n "${hit}" ]] && val="$(sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//' <<<"${hit}")"
    done
    printf '%s' "${val}"
}

apply="$(get_setting apply_updates)"
download="$(get_setting download_updates)"
echo "dnf5-automatic: download_updates=${download:-?} apply_updates=${apply:-?}"

if [[ "${apply}" != "no" ]]; then
    echo "  ERROR: apply_updates='${apply}' — el sistema instalaría updates solo." >&2
    echo "  Poné 'apply_updates = no' bajo [commands] en ${OVERRIDE_CONF} y re-corré." >&2
    exit 1
fi
if [[ "${download}" != "yes" ]]; then
    echo "  AVISO: download_updates='${download}' — no se descargaría nada por adelantado."
    echo "  Poné 'download_updates = yes' bajo [commands] en ${OVERRIDE_CONF}."
fi

echo "Habilitando dnf5-automatic.timer (descarga diaria, sin instalar)"
sudo systemctl enable --now dnf5-automatic.timer 2>/dev/null \
    || echo "  (no se pudo habilitar ahora; aplica al próximo arranque)"
