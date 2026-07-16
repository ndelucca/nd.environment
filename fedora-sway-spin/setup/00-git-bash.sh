#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=../vars.sh
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"   # provee REPO_DIR, GIT_NAME, GIT_EMAIL, GITHUB_USER

# Scope --system (/etc/gitconfig) a propósito: soy el único usuario de mis máquinas y
# quiero la MISMA identidad de git en todo repo y para todo usuario (incluido root),
# sin depender de un ~/.gitconfig por cuenta. Un repo puede overridear con config local.
sudo git config --system user.name "${GIT_NAME}"
sudo git config --system user.email "${GIT_EMAIL}"
sudo git config --system pull.rebase true
sudo git config --system push.default simple
sudo git config --system core.autocrlf false
sudo git config --system core.commentchar ";"
sudo git config --system core.editor "nvim"
sudo git config --system color.ui true
sudo git config --system alias.st status

# git-delta como pager de diffs (paquete git-delta, binario /usr/bin/delta — visible
# también para root, por eso va en scope --system). Solo cambia cómo se VEN los diffs
# (git diff/show/log -p) y el diff interactivo (add -p), no el comportamiento de git.
# Tema de sintaxis Dracula: el código se colorea con la paleta del dominio "editores"
# (igual que nvim/Zed), aunque corra en la terminal.
sudo git config --system core.pager "delta"
sudo git config --system interactive.diffFilter "delta --color-only"
sudo git config --system delta.navigate true
sudo git config --system delta.line-numbers true
sudo git config --system delta.side-by-side false
sudo git config --system delta.syntax-theme "Dracula"

echo "Changing .git origin to ssh"
git -C "${REPO_DIR}" remote set-url origin "ssh://git@github.com/${GITHUB_USER}/$(basename "${REPO_DIR}").git"
