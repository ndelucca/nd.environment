#!/usr/bin/env bash

# Si no es interactiva, no hacer nada.
[[ $- != *i* ]] && return

# Si la versión de bash es mala, no hacer nada.
((BASH_VERSINFO[0] < 4)) && return

# A diferencia de Fedora, NO gateamos por TERM=foot: en WSL la terminal externa es
# Windows Terminal (xterm-256color), así que arrancamos tmux en cualquier terminal
# interactiva que no esté ya dentro de tmux/screen.
if command -v tmux &>>/dev/null \
    && [[ ! "${TERM}" =~ screen ]] \
    && [[ ! "${TERM}" =~ tmux ]] \
    && [[ -z "${TMUX}" ]]; then
    # Sesión ÚNICA compartida llamada "forest": abrir otra terminal NO da un shell fresco,
    # attachea a la misma sesión (mismas ventanas/panes).
    #
    # Al CREARLA de cero abrimos 3 ventanas, todas en ~/dev (fallback a ~ si no existe).
    # Si la sesión ya existe (otra terminal la creó), solo se attachea sin tocar ventanas.
    if ! tmux has-session -t forest 2>/dev/null; then
        START_DIR="${HOME}/dev"
        [[ -d "${START_DIR}" ]] || START_DIR="${HOME}"
        tmux new-session -d -s forest -c "${START_DIR}"
        tmux new-window  -t forest   -c "${START_DIR}"
        tmux new-window  -t forest   -c "${START_DIR}"
        tmux select-window -t 'forest:{start}'   # foco en la primera ventana
    fi
    # -2 asume 256 colores.
    exec tmux -2 attach-session -t forest
fi
