#!/usr/bin/env bash

set -euo pipefail

# Versión mínima del 06-development.sh de Fedora: solo crea la estructura de dirs de
# desarrollo (para que GOPATH apunte a algo) e imprime versiones. Sin grupos de build
# pesados — build-essential ya vino en packages.txt.

echo "Creando estructura de directorios de desarrollo..."
DEV_DIRS=(
    "${HOME}/dev/go/src"
    "${HOME}/dev/go/bin"
    "${HOME}/dev/go/pkg"
    "${HOME}/dev/node"
    "${HOME}/dev/python"
)
for dir in "${DEV_DIRS[@]}"; do
    mkdir -p "${dir}"
    echo "  creado: ${dir}"
done

# ~/.local/bin (shims + binarios de 02-tools.sh) en PATH para que check_cmd los vea.
export PATH="${HOME}/.local/bin:${PATH}"

# Imprime "<label>: <versión>" si <bin> existe, si no "<label>: NO INSTALADO".
# El resto de args es el comando de versión (se muestra su primera línea).
check_cmd() {
    local bin="$1" label="$2"; shift 2
    if command -v "${bin}" &>/dev/null; then
        echo "${label}: $("$@" 2>&1 | head -n1)"
    else
        echo "${label}: NO INSTALADO"
    fi
}

echo ""
echo "=== Versiones instaladas ==="
check_cmd git   git     git --version
check_cmd tmux  tmux    tmux -V
check_cmd fzf   fzf     fzf --version
check_cmd rg    ripgrep rg --version
check_cmd fd    fd      fd --version
check_cmd bat   bat     bat --version
check_cmd eza   eza     eza --version
check_cmd delta delta   delta --version
check_cmd jq    jq      jq --version

echo ""
echo "Entorno de desarrollo configurado!"
