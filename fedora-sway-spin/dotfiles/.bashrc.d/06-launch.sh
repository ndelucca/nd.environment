# shellcheck shell=bash
# launch <cmd> [args]: lanza una app gráfica desde la terminal en su propia unit transient
# bajo app.slice, como si viniera de rofi. Sin esto hereda el scope del pane de tmux
# (tmux-spawn-*.scope) y, como systemd-oomd mata cgroups HOJA, la app y la shell de ese
# pane caen juntas. assign-cgroups del Spin no lo cubre: solo mueve lo lanzado desde el
# cgroup del compositor. Ver README, "Memoria".
launch() {
    if (($# == 0)); then
        echo "uso: launch <comando> [args]" >&2
        return 2
    fi
    local name
    name="$(systemd-escape "${1##*/}")"
    # --same-dir: rutas relativas siguen valiendo. --collect: si falla no queda una unit
    # en failed colgada. El nombre sigue la convención app-<id>-<n> de assign-cgroups.
    systemd-run --user --quiet --collect --same-dir --slice=app.slice \
        --unit="app-${name}-$$-${RANDOM}" -- "$@"
}
