#!/usr/bin/env bash

set -euo pipefail

# Updates: se DESCARGAN en background, se instalan a mano (README, "Actualizaciones").
# Los defaults del paquete dnf5-plugin-automatic ya son download_updates=yes /
# apply_updates=no, así que no forkeamos config: solo habilitamos el timer y VERIFICAMOS
# esas dos claves, porque si un default futuro pasara a apply_updates=yes el sistema
# empezaría a auto-instalar en silencio. Override, si hiciera falta: /etc/dnf/automatic.conf.

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
