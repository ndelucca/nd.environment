# wsl

Entorno **CLI-only** para una WSL de la familia Debian/Ubuntu (apt): pone a punto la terminal y las herramientas de
consola que uso en `fedora-sway-spin` (bash, tmux, fzf, git+delta, eza/bat/fd/ripgrep/jq)
y **nada de escritorio**. Mantiene la misma filosofía que los otros entornos del repo: un
bootstrap idempotente que orquesta pasos numerados, una lista declarativa de paquetes y
configs versionadas stoweadas con GNU Stow.

> Vive bajo `windows-11/` porque WSL corre sobre Windows, pero internamente es un clon
> reducido del enfoque bash + stow de Fedora, no del enfoque PowerShell de `windows-11`.

## Qué instala

| Pieza            | Detalle                                                            |
| ---------------- | ------------------------------------------------------------------ |
| `bootstrap.sh`   | Instala stow y corre `setup/NN-*.sh` en orden (idempotente)        |
| `00-packages.sh` | `apt` de `packages.txt` + genera el locale `en_US.UTF-8`           |
| `01-git.sh`      | Identidad git **`--global`** + delta como pager + origin a SSH     |
| `02-tools.sh`    | Shims `bat`/`fd`, binarios `eza`/`delta`, `win32yank.exe`          |
| `03-stow.sh`     | Cablea `~/.bashrc` → `~/.bashrc.d/*.sh` + stow de los dotfiles     |
| `04-development.sh` | Crea `~/dev/{go,node,python}` e imprime versiones               |

## Diferencias con Fedora

Una WSL apt (Debian/Ubuntu) no es Fedora, así que algunas cosas se adaptan en vez de
copiarse tal cual:

- **`~/.bashrc` no carga `~/.bashrc.d/` solo** (Fedora sí) → lo cablea `03-stow.sh` con un
  bloque idempotente protegido por marcador.
- **Nombres de binarios**: Debian instala `batcat`/`fdfind` → `02-tools.sh` crea shims
  `bat`/`fd` en `~/.local/bin`.
- **`eza` y `git-delta`** pueden no estar en apt (bookworm) → si faltan, se baja el binario
  estático del release de GitHub a `~/.local/bin`.
- **Clipboard**: no hay Wayland → tmux copia con `win32yank.exe` + OSC-52 (Windows Terminal).
- **nvim**: **no está incluido todavía**. La estructura queda lista para sumarlo después
  (otro paso de setup + dotfiles bajo `dotfiles/.config/nvim`).

## Setup

Dentro de WSL (probado en Ubuntu noble), con el repo clonado en el **filesystem de
Linux** (`~`, no `/mnt/c`, por performance):

```bash
git clone https://github.com/ndelucca/nd.environment.git "${HOME}/nd.environment"
cd "${HOME}/nd.environment"
./windows-11/wsl/bootstrap.sh
```

El bootstrap es idempotente: re-correrlo actualiza paquetes, re-stowea dotfiles y no
duplica el bloque de `~/.bashrc`. Después, **abrí una terminal nueva** para tomar el
profile (autoentra a tmux sesión `forest`).

## SSH (manual, por máquina)

Las claves SSH no están en el repo. En cada WSL nueva:

```bash
ssh-keygen -t ed25519 -C "ndelucca@protonmail.com"
cat ~/.ssh/id_ed25519.pub   # agregarla en GitHub → Settings → SSH keys
```

`GIT_SSH_COMMAND` (en `.bashrc.d/01-ps1.sh`) ya apunta a `~/.ssh/id_ed25519`.
