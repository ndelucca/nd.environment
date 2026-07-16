#!/usr/bin/env bash

# Si no es interactiva, no hacer nada.
[[ $- != *i* ]] && return

# OPCIONES DE SHELL
{

    # Anteponer cd a los nombres de directorio automáticamente.
    shopt -s autocd

    # Corregir errores de tipeo durante el tab-completion.
    shopt -s dirspell

    # Corregir errores de tipeo en los argumentos de cd.
    shopt -s cdspell

    # Activar globbing recursivo (habilita ** para recorrer todos los directorios).
    shopt -s globstar

    # Actualizar el tamaño de ventana después de cada comando.
    shopt -s checkwinsize

    # Agregar al final del historial, no sobrescribir.
    shopt -s histappend

    # Guardar comandos multilínea como un solo comando en el historial.
    shopt -s cmdhist

} &>>/dev/null

# Habilitar la expansión de historial con espacio.
# Ej: tipear !!<espacio> reemplaza el !! por el último comando.
bind Space:magic-space

# Completar archivos sin distinguir mayúsculas/minúsculas.
bind "set completion-ignore-case on"

# Mostrar las coincidencias de patrones ambiguos al primer tab.
bind "set show-all-if-ambiguous on"
bind "set show-all-if-unmodified on"

# Agregar la barra final al instante al autocompletar symlinks a directorios.
bind "set mark-symlinked-directories on"

# Completions más lindas.
bind "set colored-stats on"
bind "set colored-completion-prefix on"
bind "set visible-stats on"
# Largo máximo (en caracteres) del prefijo común de una lista de completions que se
# muestra sin modificar.
bind "set completion-prefix-display-length 7"

# PS1: usamos el git-prompt.sh que ya trae el sistema en vez de vendorear una copia. En
# Debian lo provee el paquete git en /usr/lib/git-core/git-sh-prompt; los otros paths
# cubren Fedora y eventuales rutas distintas.
for _gp in \
    /usr/lib/git-core/git-sh-prompt \
    /usr/share/git-core/contrib/completion/git-prompt.sh \
    /etc/bash_completion.d/git-prompt.sh; do
    [[ -f "${_gp}" ]] && { source "${_gp}"; break; }
done
unset _gp

export GIT_PS1_SHOWCOLORHINTS=true
export GIT_PS1_SHOWDIRTYSTATE=true
export GIT_PS1_SHOWSTASHSTATE=true
export GIT_PS1_SHOWUNTRACKEDFILES=true
export GIT_PS1_SHOWUPSTREAM=verbose

# Acento verde unificado del dominio Desktop+Terminal: #387838 (mismo que tmux/prompt de
# Fedora). El branch de git lo colorea __git_ps1 solo (GIT_PS1_SHOWCOLORHINTS), así que no
# definimos un color de branch a mano.
T_STYLE=0
T_MAIN_COLOR="38;2;56;120;56"

C_RUTA="\[\033[${T_STYLE};${T_MAIN_COLOR}m\]"
C_SIMB="\[\033[${T_STYLE};${T_MAIN_COLOR}m\]"
M_END="\[\033[m\]"

RUTA="${C_RUTA}\w${M_END}"
FIRSTLINE="${C_RUTA}>\n${M_END}"
SIMB="${C_SIMB}☯${M_END}"

export GIT_SSH_COMMAND="ssh -i ${HOME}/.ssh/id_ed25519"

# Recortar automáticamente rutas largas en el prompt.
# export PROMPT_DIRTRIM=2

# Usar PROMPT_COMMAND (no PS1) para tener salida con color (ver git-prompt.sh).
export PROMPT_COMMAND="__git_ps1 \"${RUTA}\" \"${FIRSTLINE}${SIMB} \""
export PS1=''

# HISTORIAL

# Agregar al historial al terminar cualquier comando.
export PROMPT_COMMAND="${PROMPT_COMMAND}; history -a;"

# Historial grande. HISTFILESIZE >= HISTSIZE para no truncar el archivo al guardar.
export HISTSIZE=500000
export HISTFILESIZE=500000

# Evitar entradas duplicadas.
export HISTCONTROL="erasedups:ignoreboth"

# No registrar algunos comandos.
export HISTIGNORE="exit:ls:history:clear:pwd"

# Timestamp estándar ISO 8601.
# %F equivale a %Y-%m-%d
# %T equivale a %H:%M:%S (formato 24 horas)
export HISTTIMEFORMAT='%F %T '
