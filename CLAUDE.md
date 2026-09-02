# CLAUDE.md — nd.environment

Repo de configuración de entornos personales de Naza. Foco actual:
`fedora-sway-spin/` (Fedora Sway Spin). También existe `windows-11/`.

**Antes de proponer cambios o re-investigar, leé `fedora-sway-spin/README.md`** — ahí
está la intención, la situación y las reglas completas. Resumen de hechos durables para
no re-chequear:

## Filosofía
- Wayland-first; cohesión GTK/Adwaita; reproducible; **apoyarse en el Spin**, tocar el
  sistema lo mínimo.
- Install: `bootstraping.sh` corre `setup/NN-*.sh` (idempotentes). Valores por máquina
  en `vars.sh`. Dotfiles por **stow** `--no-folding`; configs variables desde templates
  `.in` (solo el `.in` se versiona; el generado es git-ignored).
- Sway: heredar `/usr/share/sway/config.d/*` del Spin, override por mismo nombre en
  `~/.config/sway/config.d/`. No forkear archivos del sistema.
- nvim: submódulo (`ndelucca/nvim`), `vim.pack` nativo.

## Hechos que ya verifiqué (no re-investigar)
- **rofi = 2.0 (rofi-wayland), nativo Wayland.** No es el viejo X11.
- **Audio = PipeWire** (no PulseAudio).
- **SDDM lo trae el Spin**; solo lo configuramos; greeter corre en Wayland.
- **Agente polkit (`lxqt-policykit`) lo arranca el Spin**; lo dejamos (pintado por qt6ct).
- **No se puede sacar Qt 100%** del Spin → lo cubrimos como baseline con qt6ct dark.
- `$lock_timeout`/`$screen_timeout` los consume el `90-swayidle.conf` del Spin (no son
  variables muertas). **waybar lo arranca el `90-bar.conf` del Spin.**
- **Notificaciones = swaync** (dunst desinstalado: competía por el nombre de D-Bus).
- **Power profiles = `tuned-ppd`**, no `power-profiles-daemon` (que no está instalado);
  es quien expone `org.freedesktop.UPower.PowerProfiles` para el módulo de waybar.
- **RAM = 4 GB.** `systemd-oomd` habilitado (`11-memory.sh`) + `systemd-oomd-defaults`;
  `rsyslog` deshabilitado; `abrt`/`dunst`/`low-memory-monitor` desinstalados.
- **Updates: se descargan solos, se instalan a mano** (`dnf5-automatic.timer` vía
  `12-auto-updates.sh`). Los defaults del paquete ya son download-only: no forkeamos config.
- **`nd-doctor` chequea dos bloques:** archivos del Spin + suposiciones propias
  (`~/.bashrc` carga `~/.bashrc.d`, dueño del bus de notificaciones, timers `nd-*`,
  symlinks rotos). Saltea (no falla) lo que necesita sesión gráfica.

## Reglas
- **Fuentes: solo JetBrainsMono Nerd Font** en toda la UI (detalle en el README).
- Editores: nvim + **Neovide** (GUI del mismo nvim, binario a `~/.local/bin`, NO flatpak)
  + Zed.
- Apps por defecto: foot, rofi, Loupe (img), Papers (pdf), mpv (video), Thunar (files),
  firefox/chromium. Handlers seteados con `xdg-mime` en `03-apps.sh` (NO se stowea
  `mimeapps.list`: es archivo real que el sistema reescribe).
- PWAs vía `chromium --app=` (no Electron): Spotify, ChatGPT, WhatsApp, Gmail
  (array `WEBAPPS` en `05-webapps.sh`; sacar uno borra su lanzador en la próxima corrida).
- Apps no deseadas → `setup/remove-packages.txt` + `setup/07-remove-unwanted.sh`.
- **Decisiones deliberadas — NO re-proponer** (detalle en el README, sección "Decisiones
  deliberadas"): sin backup/snapshots (la máquina es reemplazable y este repo la
  reconstruye; no se guardan datos sensibles), llave SSH sin passphrase a conciencia, sin
  contenedores, y sin `dnf autoremove` automático en el bootstrap.

## Convenciones
- No firmar commits ni agregar "Co-Authored-By: Claude" / "Generated with Claude Code".
- Comentarios/docs en español; código y configs en inglés cuando corresponde.
