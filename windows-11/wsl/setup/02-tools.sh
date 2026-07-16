#!/usr/bin/env bash

set -euo pipefail

# Tools de consola que en Debian no vienen con el nombre/paquete esperado. Este script
# es el corazón de las diferencias con Fedora; todo es idempotente (skip si ya está).
#   - bat/fd: el paquete Debian instala batcat/fdfind → creamos shims con el nombre pelado
#     que esperan los aliases y la config de fzf.
#   - eza, delta: pueden no estar en apt (bookworm) → si no están, bajamos el binario
#     estático del release de GitHub a ~/.local/bin.
#   - win32yank: .exe de Windows invocable desde WSL, para el clipboard de tmux.
# ~/.local/bin lo agrega al PATH .bashrc.d/04-extra.sh.

LOCAL_BIN="${HOME}/.local/bin"
mkdir -p "${LOCAL_BIN}"
export PATH="${LOCAL_BIN}:${PATH}"

# have CMD: ¿existe el comando (en PATH o como binario propio en ~/.local/bin)?
have() { command -v "$1" &>/dev/null; }

# --- Shims para binarios renombrados por Debian -----------------------------
# Solo si el binario Debian existe y el nombre pelado no resuelve ya a un binario real
# (p. ej. uno instalado por apt en /usr/bin); así no pisamos un `bat`/`fd` del sistema.
shim() {
    local debian_bin="$1" plain="$2"
    if have "${debian_bin}" && ! have "${plain}"; then
        ln -sf "$(command -v "${debian_bin}")" "${LOCAL_BIN}/${plain}"
        echo "  shim: ${plain} -> $(command -v "${debian_bin}")"
    fi
}
echo "Creando shims bat/fd..."
shim batcat bat
shim fdfind fd

# --- eza (binario estático si no está en apt) -------------------------------
if have eza || [[ -x "${LOCAL_BIN}/eza" ]]; then
    echo "eza ya presente, skip."
else
    echo "Descargando eza a ${LOCAL_BIN}..."
    tmp="$(mktemp -d)"
    curl -fsSL -o "${tmp}/eza.tar.gz" \
        "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz"
    tar -xzf "${tmp}/eza.tar.gz" -C "${tmp}"
    install -m 0755 "${tmp}/eza" "${LOCAL_BIN}/eza"
    rm -rf "${tmp}"
fi

# --- git-delta (binario estático si no está en apt) -------------------------
# El asset de delta lleva la versión en el nombre, así que no hay URL `latest/download`
# estable: resolvemos la URL del release más reciente vía la API de GitHub (con jq).
if have delta || [[ -x "${LOCAL_BIN}/delta" ]]; then
    echo "delta ya presente, skip."
else
    echo "Descargando git-delta a ${LOCAL_BIN}..."
    tmp="$(mktemp -d)"
    url="$(curl -fsSL "https://api.github.com/repos/dandavison/delta/releases/latest" \
        | jq -r '.assets[].browser_download_url
                 | select(endswith("x86_64-unknown-linux-gnu.tar.gz"))' \
        | head -n1)"
    if [[ -z "${url}" ]]; then
        echo "  no se pudo resolver la URL del release de delta" >&2
        rm -rf "${tmp}"; exit 1
    fi
    curl -fsSL -o "${tmp}/delta.tar.gz" "${url}"
    tar -xzf "${tmp}/delta.tar.gz" -C "${tmp}"
    # El tarball extrae a delta-<ver>-x86_64-unknown-linux-gnu/delta.
    install -m 0755 "$(find "${tmp}" -type f -name delta | head -n1)" "${LOCAL_BIN}/delta"
    rm -rf "${tmp}"
fi

# --- win32yank (clipboard de Windows desde WSL) -----------------------------
if have win32yank.exe || [[ -x "${LOCAL_BIN}/win32yank.exe" ]]; then
    echo "win32yank ya presente, skip."
else
    echo "Descargando win32yank a ${LOCAL_BIN}..."
    tmp="$(mktemp -d)"
    curl -fsSL -o "${tmp}/win32yank.zip" \
        "https://github.com/equalsraf/win32yank/releases/latest/download/win32yank-x64.zip"
    unzip -o "${tmp}/win32yank.zip" win32yank.exe -d "${LOCAL_BIN}"
    chmod +x "${LOCAL_BIN}/win32yank.exe"
    rm -rf "${tmp}"
fi

echo "Tools listas."
