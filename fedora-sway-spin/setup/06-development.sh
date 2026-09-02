#!/usr/bin/env bash

set -euo pipefail

echo "Creando estructura de directorios de desarrollo..."
# Solo el árbol de Go: GOPATH exige esa estructura (la exporta .bashrc.d/04-extra.sh),
# así que el script tiene que crearla. Node y Python no tienen equivalente — sus
# proyectos viven donde uno los clone — y los ~/dev/{node,python} que creábamos antes
# quedaron vacíos meses. Los proyectos van sueltos en ~/dev.
DEV_DIRS=(
    "$HOME/dev/go/src"
    "$HOME/dev/go/bin"
    "$HOME/dev/go/pkg"
)
for dir in "${DEV_DIRS[@]}"; do
    mkdir -p "$dir"
    echo "  creado: $dir"
done

echo "Instalando el grupo c-development..."
sudo dnf group install -y c-development

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
check_cmd go      Go      go version
check_cmd node    Node.js node --version
check_cmd npm     npm     npm --version
check_cmd python3 Python  python3 --version
check_cmd uv      uv      uv --version

echo ""
echo "=== Herramientas de desarrollo ==="
check_cmd gcc  gcc     gcc --version
check_cmd make make    make --version
check_cmd git  git     git --version
check_cmd jq   jq      jq --version
check_cmd rg   ripgrep rg --version
check_cmd fd   fd      fd --version

echo ""
echo "Entorno de desarrollo configurado!"
