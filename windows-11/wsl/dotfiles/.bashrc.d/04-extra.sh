# shellcheck shell=bash
# ~/.local/bin al frente del PATH: ahí viven los shims bat/fd y los binarios eza/delta/
# win32yank que instala 02-tools.sh. Debian agrega ~/.local/bin vía ~/.profile solo si
# existe al login, así que lo forzamos acá para no depender de ese orden.
case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) export PATH="${HOME}/.local/bin:${PATH}" ;;
esac

# Entorno de desarrollo de Go
export GOPATH="${HOME}/dev/go"
export PATH="${GOPATH}/bin:${PATH}"
