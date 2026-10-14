#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=../vars.sh
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"   # provee SESSION_SERVICES

# Habilita las units de usuario del entorno. Dos convenciones (detalle en el README,
# sección "Tareas croneadas" y "Daemons de sesión"):
#   - TIMERS: cualquier `nd-*.timer` que haya en el directorio (units nuestras, stoweadas).
#   - DAEMONS DE SESIÓN: la lista SESSION_SERVICES de vars.sh (kanshi, wlsunset,
#     swayosd-server, swaync). Van por systemd y no por `exec` de sway/config para que haya
#     un único dueño de cada recurso y Restart=on-failure si se caen. La misma lista la
#     verifica nd-doctor.
# stow deja los archivos; habilitarlos (symlinks en *.target.wants/) es trabajo de
# systemctl, así que va acá, después del stow.

UNIT_DIR="${HOME}/.config/systemd/user"

# Guard: sin user manager (bootstrap por ssh/TTY sin login de systemd) no hay a quién
# hablarle. Avisar y salir 0; las units quedan listas para la próxima corrida.
if ! systemctl --user show-environment >/dev/null 2>&1; then
    echo "systemd --user no disponible (¿sin sesión de usuario?); salteando enable de units."
    exit 0
fi

# Las units de sesión tienen PartOf/WantedBy=graphical-session.target y ExecCondition
# sobre WAYLAND_DISPLAY: fuera de una sesión gráfica solo las habilitamos (sin --now), si
# no el start falla y la unit queda en failed hasta el próximo login.
if [[ "$(systemctl --user is-active graphical-session.target 2>/dev/null)" == "active" ]]; then
    NOW="--now"
else
    NOW=""
    echo "Sin sesión gráfica activa: se habilitan las units sin arrancarlas (arrancan al próximo login)."
fi

systemctl --user daemon-reload

# --- Timers propios (nd-*.timer) ---
shopt -s nullglob
timers=("${UNIT_DIR}"/nd-*.timer)
shopt -u nullglob

if ((${#timers[@]} == 0)); then
    echo "No hay timers nd-*.timer en ${UNIT_DIR}. Nada que habilitar."
else
    # enable --now es idempotente: re-habilitar/re-arrancar un timer ya activo es inofensivo.
    for timer in "${timers[@]}"; do
        name="$(basename "${timer}")"
        echo "Habilitando ${name}"
        # shellcheck disable=SC2086  # NOW vacío = sin flag, a propósito
        systemctl --user enable ${NOW} "${name}"
    done
fi

# --- Daemons de sesión ---
for svc in "${SESSION_SERVICES[@]}"; do
    if ! systemctl --user cat "${svc}" >/dev/null 2>&1; then
        echo "AVISO: ${svc} no existe (¿paquete no instalado / stow no corrido?); salteando."
        continue
    fi

    # Si quedó una instancia suelta de una sesión previa (p. ej. del `exec` que sway hacía
    # antes), el start choca por el recurso compartido y la unit queda en failed. Matamos
    # la suelta y limpiamos el estado failed antes de arrancar la de systemd.
    proc="${svc%.service}"
    if [[ -n "${NOW}" ]]; then
        pkill -x "${proc}" 2>/dev/null || true
    fi
    systemctl --user reset-failed "${svc}" 2>/dev/null || true

    echo "Habilitando ${svc}"
    # shellcheck disable=SC2086
    systemctl --user enable ${NOW} "${svc}"
done
