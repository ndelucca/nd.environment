#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=../vars.sh
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"   # provee SETUP_DIR
PKG_FILE="${SETUP_DIR}/packages.txt"

# Tipos MIME que abre Neovide. Fuente única: se usa tanto en el .desktop (como
# línea MimeType, separada por ';') como en el xdg-mime de abajo (args sueltos).
# Agregá un tipo acá una sola vez y queda reflejado en ambos lados.
NEOVIDE_MIMES=(
    text/plain text/markdown text/x-readme
    application/json application/x-yaml text/x-yaml application/toml text/x-toml
    text/x-shellscript application/x-shellscript
    text/x-python text/x-lua text/x-go
    text/x-csrc text/x-chdr text/x-c++src text/x-c++hdr
    text/css application/xml text/xml text/x-sql text/x-makefile
)

# Algunas entradas de packages.txt no están en los repos de Fedora y vienen de un
# COPR. Los habilitamos (idempotente) antes del install masivo para que resuelvan:
#   jhuang6451/nerd-fonts  -> jetbrains-mono-nf (JetBrainsMono Nerd Font)
#   erikreider/swayosd     -> swayosd (OSD de volumen/brillo/caps-lock)
COPRS=(
    "jhuang6451/nerd-fonts"
    "erikreider/swayosd"
)
# dnf5-plugins aporta los subcomandos `copr` y `config-manager` (este último lo usa la
# sección de gh más abajo). Se instala una sola vez acá para no repetirlo en cada uso.
sudo dnf install -y dnf5-plugins
enabled_coprs="$(sudo dnf copr list 2>/dev/null || true)"   # listar una vez, no por COPR
for copr in "${COPRS[@]}"; do
    if ! grep -Fq "${copr}" <<<"${enabled_coprs}"; then
        echo "Habilitando COPR ${copr}..."
        sudo dnf copr enable -y "${copr}"
    fi
done

echo "Instalando paquetes dnf desde ${PKG_FILE}..."
mapfile -t PACKAGES < <(read_pkg_list "${PKG_FILE}")
if ((${#PACKAGES[@]})); then
    sudo dnf install -y "${PACKAGES[@]}"
else
    echo "packages.txt no tiene paquetes; nada que instalar."
fi

if command -v gh &>/dev/null; then
    echo "GitHub CLI ya está instalado."
    echo "Versión: $(gh --version | head -n1)"
else
    echo "Instalando GitHub CLI desde el repo oficial..."

    sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
    sudo dnf install -y gh --repo gh-cli

    echo "GitHub CLI instalado correctamente!"
    echo "Versión: $(gh --version | head -n1)"
fi

# Zed vía su script oficial. No está en dnf: el paquete 'zed' de dnf es el demonio
# de eventos de ZFS, sin relación.
if command -v zed &>/dev/null; then
    echo "Zed ya está instalado."
else
    echo "Instalando Zed desde zed.dev..."
    curl -fsSL https://zed.dev/install.sh | sh
    echo "Zed instalado correctamente!"
fi

# Neovide: cliente GUI de nuestro Neovim. No está en dnf/COPR. El build de Flathub
# corre nvim en un sandbox (no usaría nuestro nvim / LSPs / Go / Node del host), así
# que instalamos el binario oficial de release en ~/.local/bin (mismo enfoque que Zed).
# Solo maneja nuestra config de nvim (el submódulo): es la GUI de nuestro nvim, no un
# tercer editor.
#
# El binario se instala como `neovide-bin`; el lanzador en PATH es el wrapper stoweado
# dotfiles/.local/bin/neovide, que cae a GL por software en GPUs viejas (Neovide
# necesita OpenGL >= 3.2). Ver ese wrapper para detalles. Como no hay paquete que lo
# actualice, re-correr el bootstrap re-baja el binario cuando el release más nuevo
# difiere del instalado (abajo).

# Instala el binario del release <tag> en ~/.local/bin/neovide-bin. Se baja por tag
# (no por `latest`) para que lo instalado sea exactamente la versión que se comparó
# abajo: con `latest` un release publicado entre la consulta a la API y la descarga
# dejaba una versión distinta a la decidida. Upstream no publica checksums de sus
# assets, así que no hay más verificación posible que el TLS de GitHub.
# El asset es un .tar plano (no .tar.gz) con el binario neovide adentro.
install_neovide_bin() {
    local tag="$1" tmp bin
    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp:-}"' RETURN
    curl -fL "https://github.com/neovide/neovide/releases/download/${tag}/neovide-linux-x86_64.tar" \
        -o "${tmp}/neovide.tar"
    tar -xf "${tmp}/neovide.tar" -C "${tmp}"
    bin="$(find "${tmp}" -type f -name neovide | head -n1)"
    [[ -n "${bin}" ]] || { echo "ERROR: no se encontró el binario neovide en el tarball" >&2; return 1; }
    mkdir -p "${HOME}/.local/bin"
    install -m755 "${bin}" "${HOME}/.local/bin/neovide-bin"
}

# Tag del release más nuevo según la API de GitHub (p. ej. "0.16.2"). `|| latest=""`
# desacopla del `set -e`: si curl falla (red caída / rate-limit), queremos latest vacío
# para dejar la instalada en paz, NO abortar.
latest="$(curl -fsSL --max-time 10 https://api.github.com/repos/neovide/neovide/releases/latest 2>/dev/null \
    | jq -r '.tag_name // empty' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)" || latest=""

if command -v neovide-bin &>/dev/null; then
    # Re-fetch solo si el release más nuevo difiere del instalado.
    cur="$(neovide-bin --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
    if [[ -n "${latest}" && "${cur}" != "${latest}" ]]; then
        echo "Neovide ${cur:-?} -> ${latest}: actualizando."
        install_neovide_bin "${latest}"
    else
        echo "Neovide al día (${cur:-instalado})."
    fi
elif [[ -n "${latest}" ]]; then
    echo "Instalando Neovide ${latest} desde el release de GitHub..."
    install_neovide_bin "${latest}"
else
    echo "AVISO: no se pudo consultar el release de Neovide (¿sin red?); se instala en la próxima corrida."
fi

# Icono + entrada .desktop. El .desktop se REGENERA siempre (no solo en la primera
# instalación) para que su línea MimeType refleje NEOVIDE_MIMES — fuente única — también
# en re-corridas. El icono solo se baja si falta (no cambia). Exec=neovide -> el wrapper
# stoweado; bajo Wayland el app_id es "neovide" (lo matchea el `assign ... workspace 3`).
neovide_icon="${HOME}/.local/share/icons/hicolor/scalable/apps/neovide.svg"
if [[ ! -f "${neovide_icon}" ]]; then
    mkdir -p "$(dirname "${neovide_icon}")"
    curl -fsL https://raw.githubusercontent.com/neovide/neovide/main/assets/neovide.svg \
        -o "${neovide_icon}" || true
fi
mkdir -p "${HOME}/.local/share/applications"
neovide_mime_line="$(IFS=';'; echo "${NEOVIDE_MIMES[*]};")"
tee "${HOME}/.local/share/applications/neovide.desktop" >/dev/null <<EOF
[Desktop Entry]
Name=Neovide
GenericName=Text Editor
Comment=No Nonsense Neovim GUI
Exec=neovide %F
Icon=neovide
Type=Application
Categories=Utility;TextEditor;
Terminal=false
StartupWMClass=neovide
MimeType=${neovide_mime_line}
EOF

# Handlers de archivos por defecto. ~/.config/mimeapps.list es un archivo real que el
# sistema y las apps reescriben, así que NO se stowea (chocaría con el --no-folding de
# stow y pisaría los defaults de navegador/nvim ya presentes). Seteamos solo nuestros
# handlers con xdg-mime, que mergea en ese archivo de forma idempotente y deja el resto.
if command -v xdg-mime &>/dev/null; then
    echo "Seteando handlers por defecto (imágenes=Loupe, pdf=Papers, video=mpv)..."
    xdg-mime default org.gnome.Loupe.desktop \
        image/png image/jpeg image/gif image/webp image/bmp image/tiff image/svg+xml
    xdg-mime default org.gnome.Papers.desktop application/pdf
    xdg-mime default mpv.desktop \
        video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo
    xdg-mime default thunar.desktop inode/directory
    # Archivos de texto/código abren en Neovide (GUI nvim) en vez de nvim-en-terminal.
    xdg-mime default neovide.desktop "${NEOVIDE_MIMES[@]}"
fi
