#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=../vars.sh
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"   # provee REPO_DIR, GIT_NAME, GIT_EMAIL, GITHUB_USER

# Scope --global (~/.gitconfig) a propósito: WSL es single-user y no queremos depender de
# sudo ni tocar /etc para esto. (En Fedora el scope es --system porque ahí sí se busca la
# misma identidad para todo usuario incluido root.) Un repo puede overridear con --local.
git config --global user.name "${GIT_NAME}"
git config --global user.email "${GIT_EMAIL}"
git config --global pull.rebase true
git config --global push.default simple
git config --global core.autocrlf false
git config --global core.commentchar ";"
git config --global color.ui true
git config --global alias.st status

# git-delta como pager de diffs. Solo cambia cómo se VEN los diffs (git diff/show/log -p)
# y el diff interactivo (add -p), no el comportamiento de git. El binario `delta` lo
# garantiza 02-tools.sh (apt o binario en ~/.local/bin). Tema Dracula: el código se
# colorea con la paleta del dominio "editores" aunque corra en la terminal.
git config --global core.pager "delta"
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.line-numbers true
git config --global delta.side-by-side false
git config --global delta.syntax-theme "Dracula"

echo "Changing .git origin to ssh"
git -C "${REPO_DIR}" remote set-url origin "ssh://git@github.com/${GITHUB_USER}/$(basename "${REPO_DIR}").git"
