# windows-11

Entorno paralelo a `fedora-sway-spin`, para una maquina Windows 11. Mantiene la
misma filosofia: un bootstrap idempotente que orquesta pasos numerados, una lista
declarativa de paquetes y configs versionadas.

## Equivalencias con Fedora

| Fedora (`fedora-sway-spin`)      | Windows (`windows-11`)                                |
| -------------------------------- | ----------------------------------------------------- |
| `bootstraping.sh`                | `bootstrap.ps1`                                        |
| `dnf` + `packages.txt`           | `winget` (`packages.json`) + `scoop` (`scoop-packages.txt`) |
| GNU Stow                         | stub de `$PROFILE` + symlinks (Developer Mode)        |
| bash + `.bashrc.d/`              | PowerShell 7 + `dotfiles/powershell/profile.d/`       |
| PS1 + `__git_ps1`                | Starship (`starship.toml`)                            |
| foot (`foot.ini`)                | Windows Terminal (`settings.json`)                    |
| tmux                             | paneles de Windows Terminal (sin sesiones persistentes) |
| nvim (submodulo)                 | el mismo submodulo, linkeado a `%LOCALAPPDATA%\nvim`  |
| Zed (`settings.json.in` + jq merge) | igual: `dotfiles\zed` mergeado a `%APPDATA%\Zed`    |
| (terminal dentro de WSL)         | `wsl/` — clon reducido bash + stow (ver mas abajo)    |

## Setup

Requiere **PowerShell 7** (`pwsh`). Si solo tenes Windows PowerShell 5.1, instala
PowerShell 7 con `winget install Microsoft.PowerShell` y reabri la terminal.

```powershell
git clone --recurse-submodules https://github.com/ndelucca/nd.environment.git "$HOME\nd.environment"
cd "$HOME\nd.environment"
pwsh -File .\windows-11\bootstrap.ps1
```

Para que los symlinks funcionen sin admin, habilita **Developer Mode**
(Settings -> Privacy & security -> For developers). Si no, el bootstrap copia los
configs en lugar de linkearlos (funciona igual, pero hay que reejecutar tras
editar un config).

Despues del bootstrap, **abri una terminal nueva** para tomar el profile.

## SSH (manual, por maquina)

Las claves SSH no estan en el repo. En cada maquina nueva:

```powershell
ssh-keygen -t ed25519 -C "ndelucca@protonmail.com"
Get-Content "$HOME\.ssh\id_ed25519.pub"   # agregarla en GitHub -> Settings -> SSH keys
```

## WSL

WSL es una terminal aparte (Linux, no PowerShell) y tiene su propio entorno
**CLI-only** en [`wsl/`](wsl/README.md): un clon reducido del enfoque bash + stow de
Fedora que pone a punto bash, tmux, fzf, git+delta y las tools de consola, sin nada de
escritorio. Se provisiona desde adentro de WSL con `./windows-11/wsl/bootstrap.sh`.

Lo relevante:

- Performance: mantener los repos en el filesystem de Linux (`~`), no en `/mnt/c`.
- El clipboard de tmux usa `win32yank.exe` + OSC-52 (Windows Terminal), sin Wayland.
- nvim todavia no esta incluido en `wsl/` (queda como trabajo futuro).
