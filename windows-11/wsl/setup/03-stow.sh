#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=../vars.sh
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"   # provee DOTFILES_DIR
STOW_DIR="${DOTFILES_DIR}"

# --- Cablear ~/.bashrc para cargar ~/.bashrc.d/*.sh -------------------------
# Fedora hace este source por default; Debian NO. Sin esto, los dotfiles stoweados en
# ~/.bashrc.d nunca se cargarían. Append idempotente protegido por un marcador.
BASHRC="${HOME}/.bashrc"
MARKER="# nd-environment: load ~/.bashrc.d"
touch "${BASHRC}"
if ! grep -qF "${MARKER}" "${BASHRC}"; then
    echo "Cableando ${BASHRC} -> ~/.bashrc.d/*.sh"
    cat >> "${BASHRC}" <<'EOF'

# nd-environment: load ~/.bashrc.d
if [ -d "$HOME/.bashrc.d" ]; then
    for rc in "$HOME"/.bashrc.d/*.sh; do [ -f "$rc" ] && . "$rc"; done
    unset rc
fi
EOF
else
    echo "${BASHRC} ya cableado, skip."
fi

# --- Respaldar archivos reales pre-existentes que bloquearían el stow ---------
# stow no pisa un target que sea un archivo real (no symlink). En una WSL nueva
# ~/.bashrc.d o ~/.config pueden ya tener copias reales (de un setup previo o defaults);
# las movemos a *.pre-stow.bak para que stow pueda crear el symlink. Idempotente: en
# re-runs los targets ya son symlinks y este paso no hace nada.
for pkg in .bashrc.d .config; do
    pkgdir="${STOW_DIR}/${pkg}"
    [[ -d "${pkgdir}" ]] || continue
    while IFS= read -r src; do
        rel="${src#"${pkgdir}/"}"
        target="${HOME}/${pkg}/${rel}"
        if [[ -f "${target}" && ! -L "${target}" ]]; then
            echo "Backup de archivo real pre-existente: ${target} -> ${target}.pre-stow.bak"
            mv -f "${target}" "${target}.pre-stow.bak"
        fi
    done < <(find "${pkgdir}" -type f)
done

# --- Limpiar symlinks obsoletos dejados por dotfiles renombrados/eliminados -
# stow -R no elimina los links cuyo origen ya no existe en el paquete. Borra cualquier
# symlink roto que apunte de vuelta a este repo para que renames/eliminaciones se reflejen.
for pkg in .bashrc.d .config; do
    [[ -d "${HOME}/${pkg}" ]] || continue
    while IFS= read -r link; do
        target="$(readlink -m "${link}")"
        if [[ "${target}" == "${STOW_DIR}/"* && ! -e "${link}" ]]; then
            echo "Removing stale symlink: ${link}"
            rm -f "${link}"
        fi
    done < <(find "${HOME}/${pkg}" -type l)
done

# --- Stow de los dotfiles ---------------------------------------------------
# --no-folding symlinkea los archivos individualmente (dirs reales) en lugar de foldear
# directorios enteros — así lo que las apps escriben en ~/.config queda fuera del repo.
# -R (restow) reaplica limpio en una máquina ya configurada. Sin templates (no hay .in)
# y sin paquete .local (los binarios de ~/.local/bin los crea 02-tools.sh, no se stowean).
for pkg in .bashrc.d .config; do
    mkdir -p "${HOME}/${pkg}"
    stow -R --no-folding -d "${STOW_DIR}" -t "${HOME}/${pkg}" "${pkg}"
done

echo "Dotfiles stoweados."
