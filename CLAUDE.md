# CLAUDE.md — nd.environment

Repo de configuración de entornos personales de Naza. Foco actual:
`fedora-sway-spin/` (Fedora Sway Spin). También existe `windows-11/`.

**Antes de proponer cambios o re-investigar, leé `fedora-sway-spin/README.md`.** Ahí
están la intención, la situación, las decisiones y su porqué. Este archivo NO repite esos
hechos (ver README, "Dónde vive cada cosa"): acá van solo las reglas de comportamiento para
el agente.

## Cómo trabajar acá
- Filosofía: Wayland-first, cohesión GTK/Adwaita, reproducible, **apoyarse en el Spin** y
  tocar el sistema lo mínimo. Un hecho se documenta una vez, en el README; scripts y
  configs llevan el qué y un porqué corto con puntero al README, no ensayos.
- Valores por máquina en `vars.sh`; dotfiles por stow `--no-folding`; configs variables
  desde templates `.in` (solo el `.in` se versiona). Sway hereda el `config.d` del Spin y
  override por mismo nombre de archivo en `~/.config/sway/config.d/`; no se forkean ni
  escriben archivos del sistema.
- Verificá contra la máquina viva (`swaymsg`, `systemctl`, `oomctl`, `/sys`) antes de
  afirmar algo en docs. El README ya tuvo afirmaciones falsas por no hacerlo.
- Si algo deriva (daemon muerto, valor que no coincide), primero preguntate si
  `nd-doctor` debería haberlo visto, y agregale el chequeo.

## Reglas duras (decisiones tomadas; NO re-proponer, detalle y porqué en el README)
- Daemons de sesión (kanshi, wlsunset, swayosd-server, swaync) van por systemd user
  units (`SESSION_SERVICES` en `vars.sh`). **No agregar `exec`/`exec_always` de esos
  daemons en `sway/config`.**
- Layout de teclado: solo vía `localectl` (01) + `locale1-xkb-config` del Spin. No generar
  archivos de teclado.
- `07-remove-unwanted.sh` usa `dnf remove --no-autoremove`. **No sacar el flag.**
- Sin backup/snapshots, llave SSH sin passphrase, sin contenedores, sin `dnf autoremove`
  automático: deliberado (README, "Decisiones deliberadas").
- Fuentes: solo JetBrainsMono Nerd Font. Editores: nvim + Neovide (binario, no flatpak) +
  Zed. Apps por defecto y PWAs según README; `mimeapps.list` no se stowea.
- Hechos ya verificados que no hace falta re-chequear: rofi 2.0 es nativo Wayland; audio
  es PipeWire; SDDM y el agente polkit los trae/arranca el Spin; waybar lo arranca el
  `90-bar.conf` del Spin; `power-profiles-daemon` es `tuned-ppd`.

## Convenciones
- No firmar commits ni agregar "Co-Authored-By: Claude" / "Generated with Claude Code".
- Comentarios/docs en español; código y configs en inglés cuando corresponde.
