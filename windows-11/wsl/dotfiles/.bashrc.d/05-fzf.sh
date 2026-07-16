#!/usr/bin/env bash
# shellcheck shell=bash
# fzf: keybindings + completado. Se carga después de 03-completions.sh (orden de glob de
# ~/.bashrc.d/*), así los binds de fzf quedan por encima de los defaults de readline.
#
# Qué agrega:
#   Ctrl-R  -> búsqueda difusa a pantalla completa sobre el historial (HISTSIZE grande).
#   Ctrl-T  -> insertar ruta de archivo (fuzzy, vía fd) en la línea de comando.
#   Alt-C   -> cd a un subdirectorio (fuzzy, vía fd).
#   **<tab> -> completado difuso (cd **<tab>, ssh **<tab>, etc.).

# Solo interactivas.
[[ $- != *i* ]] && return

# fzf reciente emite toda la integración con `fzf --bash`. Si esa flag no existe (Debian
# con fzf viejo), caemos a sourcear los archivos del paquete (rutas de Debian, distintas
# a las de Fedora). Las guardas evitan romper la shell si una versión mueve las rutas.
if command -v fzf &>/dev/null && fzf --bash &>/dev/null; then
    eval "$(fzf --bash)"
else
    for _fzf in \
        /usr/share/doc/fzf/examples/key-bindings.bash \
        /usr/share/bash-completion/completions/fzf \
        /usr/share/doc/fzf/examples/completion.bash; do
        # shellcheck source=/dev/null
        [[ -f "${_fzf}" ]] && source "${_fzf}"
    done
    unset _fzf
fi

# Usar fd como fuente: respeta .gitignore, salta .git y es más rápido que find. En Debian
# el binario es fdfind, pero 02-tools.sh crea el shim `fd` en ~/.local/bin. Si fd no está,
# fzf cae a su walker interno igual.
if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
    export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
fi

# Acento verde #387838 del dominio Desktop+Terminal (igual que tmux/prompt).
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --info=inline
--color=fg+:#ffffff,bg+:#1a1a1a,hl:#387838,hl+:#6cb66c
--color=prompt:#387838,pointer:#387838,marker:#387838,spinner:#387838,header:#387838'
