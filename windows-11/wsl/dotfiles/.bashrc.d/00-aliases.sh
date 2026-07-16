# shellcheck shell=bash
# eza (ls moderno): íconos Nerd Font + colores + directorios primero. `ls` pelado se deja
# como GNU ls a propósito (scripts/memoria muscular); solo se repuntan los listados a mano.
# En Debian `eza` lo provee 02-tools.sh (apt o binario en ~/.local/bin).
alias ll='eza -l --icons=auto --group-directories-first'
alias la='eza -la --icons=auto --group-directories-first'
alias l='eza --icons=auto --group-directories-first'

# IP pública (resolver simple por curl, sin depender de nd-public-ip, que es desktop de
# Fedora) + IP local. Si no hay red, external queda vacío.
alias myip='printf "external: %s\nlocal:    %s\n" "$(curl -fsS --max-time 3 https://ifconfig.me 2>/dev/null)" "$(hostname -I)"'
