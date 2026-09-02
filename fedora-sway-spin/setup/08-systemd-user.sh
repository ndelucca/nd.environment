#!/usr/bin/env bash

set -euo pipefail

# Habilita las units de usuario del entorno: los timers de las tareas croneadas y los
# daemons de sesión que preferimos dejar en manos de systemd.
#
# Las units propias viven versionadas en dotfiles/.config/systemd/user/ y las symlinkea
# stow junto con el resto de .config (04-stow.sh). stow deja los archivos, pero
# habilitarlos (crear los symlinks en timers.target.wants/ o graphical-session.target.wants/)
# es trabajo de systemctl, así que va acá, después del stow.
#
# Dos convenciones distintas:
#   - TIMERS: se habilita cualquier `nd-*.timer` que aparezca en el directorio. Agregar
#     una tarea = soltar su .service + .timer con prefijo `nd-` y re-correr el bootstrap.
#   - DAEMONS: lista explícita más abajo. Son units que trae un PAQUETE (no nuestras), así
#     que no hay glob que las descubra: van nombradas a mano, con su porqué.

UNIT_DIR="${HOME}/.config/systemd/user"

# Daemons de sesión que arranca systemd en vez de un `exec` de sway/config.
#
# swaync: el paquete trae swaync.service con Type=dbus, BusName=org.freedesktop.Notifications
# y archivos de activación por D-Bus. Mientras sway lo lanzaba con
# `exec_always pkill -x swaync; exec swaync`, cada reload soltaba el nombre del bus y una
# notificación que llegara en esa ventana activaba la unit por D-Bus, chocando con la
# instancia recién lanzada por sway ("An instance of SwayNotificationCenter is already
# running!" -> exit 1 -> failed). Dejándoselo a systemd hay un único dueño posible del
# nombre. La unit es WantedBy=graphical-session.target, así que arranca con la sesión.
SESSION_SERVICES=(
    "swaync.service"
)

# Guard: sin sesión de usuario (p. ej. bootstrap headless) no hay user manager
# al que hablarle. Avisar y salir 0 para no romper el bootstrap; las units
# quedan listas para la próxima corrida dentro de una sesión gráfica.
if ! systemctl --user show-environment >/dev/null 2>&1; then
    echo "systemd --user no disponible (¿sin sesión de usuario?); salteando enable de units."
    exit 0
fi

systemctl --user daemon-reload

# --- Timers propios (nd-*.timer) ---
shopt -s nullglob
timers=("${UNIT_DIR}"/nd-*.timer)
shopt -u nullglob

if ((${#timers[@]} == 0)); then
    echo "No hay timers nd-*.timer en ${UNIT_DIR}. Nada que habilitar."
else
    # enable --now es idempotente: re-habilitar/re-arrancar un timer ya activo es
    # inofensivo, así reaplicar el bootstrap en una máquina configurada no molesta.
    for timer in "${timers[@]}"; do
        name="$(basename "${timer}")"
        echo "Habilitando ${name}"
        systemctl --user enable --now "${name}"
    done
fi

# --- Daemons de sesión provistos por paquetes ---
for svc in "${SESSION_SERVICES[@]}"; do
    if ! systemctl --user cat "${svc}" >/dev/null 2>&1; then
        echo "AVISO: ${svc} no existe (¿paquete no instalado?); salteando."
        continue
    fi

    # El daemon puede estar corriendo suelto de una sesión previa (p. ej. el `exec swaync`
    # que sway hacía antes de este cambio). Si queda vivo fuera del cgroup de la unit, el
    # start choca por el nombre de D-Bus y la unit vuelve a quedar en failed. Lo matamos
    # antes para que systemd arranque el suyo limpio.
    proc="${svc%.service}"
    pkill -x "${proc}" 2>/dev/null || true

    # Una unit que quedó en failed de un arranque anterior no se recupera sola: sin este
    # reset-failed el enable --now no la reintenta.
    systemctl --user reset-failed "${svc}" 2>/dev/null || true

    echo "Habilitando ${svc}"
    systemctl --user enable --now "${svc}"
done
