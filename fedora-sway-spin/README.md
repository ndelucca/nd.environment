# Fedora Sway Spin — entorno de Naza

Configuración personal sobre **Fedora Sway Spin**. Este README documenta la
**intención, la situación y las reglas** del setup, para no tener que re-investigar
decisiones ya tomadas. Para los pasos de instalación generales, ver el
[`README.md` de la raíz](../README.md).

## Intención

Un escritorio **Wayland-first**, cohesivo (familia GTK/Adwaita), moderno y
**reproducible**, que se **apoya en el Spin** en vez de pelearse con él. La idea es
tocar el sistema lo mínimo: heredar lo que el Spin ya resuelve bien y solo override /
agregar lo propio, de forma declarativa y versionada.

## Cómo está armado (situación)

- **Instalación:** `bootstraping.sh` corre los pasos `setup/NN-*.sh` en orden
  (idempotentes). Valores por máquina en `vars.sh` (única fuente de verdad: timezone,
  teclado, coordenadas, **nombres de output**, identidad git, lista de daemons de sesión).
  Los outputs **no** se autodetectan; `nd-doctor` verifica que los declarados existan como
  conectores DRM, porque un nombre equivocado (pasó: `eDP-1` en una laptop que expone
  `LVDS-1`) deja a kanshi sin perfil y al lid switch sin efecto, sin ningún error. Lo único
  que sí se autodetecta es el sensor de temperatura de waybar: `04-stow.sh` emite **todos** los `temp*_input` del sistema como array (CPU
  primero) y waybar usa el primero que exista, así un reordenamiento de los índices
  `hwmonN` por parte del kernel entre reboots ya no rompe la lectura. La lista
  autoritativa de paquetes dnf vive en `setup/packages.txt` (lo de abajo es un resumen
  conceptual del stack, no el manifiesto).
- **Dotfiles:** GNU **stow** `--no-folding` symlinkea `dotfiles/{.bashrc.d,.config,.local}`
  a `~`. Configs con valores variables se generan desde templates `.in`: `04-stow.sh`
  los renderiza (sed/jq) con los valores de `vars.sh` ANTES de stowear, y el resultado
  queda git-ignorado; solo se versiona el `.in`. `nd-doctor` verifica que cada render
  contenga los valores actuales de `vars.sh` (editar `vars.sh` sin re-correr `04-stow.sh`
  dejaba el render viejo sin que nadie lo viera). El `settings.json` de Zed es el caso
  especial: template encima de una **allowlist** de claves que Zed escribe en runtime
  (`ZED_RUNTIME_KEYS` en `04-stow.sh`, hoy solo `ssh_connections`); cualquier otra clave
  que no esté en el `.in` desaparece en la próxima corrida, así sacar un setting del
  template realmente lo saca.
- **Config de Sway en capas:** usamos el `include` con `layered-include` del Spin. Los
  defaults del Spin viven en `/usr/share/sway/config.d/*`; nosotros override por
  **mismo nombre de archivo** en `~/.config/sway/config.d/`. **No** forkeamos archivos
  del sistema.
- **nvim:** submódulo aparte (`git@github.com:ndelucca/nvim.git`), gestionado con
  `vim.pack` nativo (sin gestor de plugins externo). `bootstraping.sh` corre
  `git submodule update --init --recursive`; si clonaste sin `--recurse-submodules`,
  ese paso lo trae igual.

## Dónde vive cada cosa (documentación)

Un hecho se escribe **una vez**, acá. Los otros lugares apuntan a esta sección, no la
repiten:
- **Este README** = intención, situación, decisiones y su porqué. Fuente de verdad.
- **`CLAUDE.md` (raíz)** = solo reglas de comportamiento para el agente (qué no
  re-proponer, qué flags no sacar, convenciones de commits) + "leé el README".
- **Comentarios en scripts/configs** = qué hace esa línea y el porqué corto, con un
  "ver README, sección X" si el porqué es largo. No ensayos.
- **`vars.sh`** = valores. Los comentarios ahí dicen quién consume cada valor.
Si al tocar algo hay que editar el mismo párrafo en dos lugares, uno de los dos sobra.

## Reglas / decisiones (lo que conviene recordar)

### Wayland / compositor
- Stack 100% Wayland-nativo: sway, foot, waybar, swaync, swaylock, swayidle (del Spin),
  kanshi, wlsunset, swayosd, grim+slurp+swappy, wl-clipboard+cliphist, swaybg.
- **rofi = `rofi` 2.0** = el fork *rofi-wayland* ya mainline. Corre **nativo en
  Wayland**, NO es el viejo rofi X11. No migrar "por ser X11".
- **No** seteamos `MOZ_ENABLE_WAYLAND` / `GDK_BACKEND` etc.: en Fedora 44 son
  innecesarios (Firefox/GTK ya van a Wayland). Evitar ese cruft.
- `$lock_timeout` / `$screen_timeout` (en `sway/config`) **los consume el
  `90-swayidle.conf` del Spin** (están definidos antes del `include`). No son variables
  muertas.
- **waybar lo arranca el Spin** vía `swaybar_command waybar` en su `90-bar.conf`. Por
  eso no hay `exec waybar` en nuestra config, y está bien.
- **Daemons de sesión = systemd user units, no `exec` de sway.** kanshi, wlsunset,
  swayosd-server y swaync los arranca `systemd --user` (lista `SESSION_SERVICES` en
  `vars.sh`, habilitada por `08-systemd-user.sh`; kanshi y swaync traen su unit en el
  paquete, `wlsunset.service.in` y `swayosd-server.service` son nuestras). Motivo: el
  patrón `exec_always pkill -x X; exec X` que había antes tenía dos fallas. (1) Race en
  cada `reload`: la instancia nueva arrancaba mientras la vieja todavía soltaba su recurso
  (nombre de D-Bus en swaync y swayosd, gamma control en wlsunset) y una de las dos moría;
  en swaync además chocaba con la activación por D-Bus de su propia unit (`An instance of
  SwayNotificationCenter is already running!` → `failed`). (2) Sin supervisión: el
  2026-10-13 kanshi, wlsunset y swayosd-server llevaban horas muertos sin log ni aviso, y
  `nd-doctor` daba 10/10. Con systemd hay un único dueño posible de cada recurso,
  `Restart=on-failure`, `PartOf=graphical-session.target`, y el doctor pregunta
  `is-active`. El propio Spin lo recomienda (`/etc/sway/config.d/10-systemd-cgroups.conf`).
  **No volver a poner un `exec` de estos daemons en `sway/config`.** Los watchers de
  cliphist (`wl-paste --watch`) sí quedan como `exec` simple: no tienen recurso exclusivo.
- **Layout de teclado: una sola cadena.** `vars.sh` → `01-locale-datetime-keyboard.sh`
  (`localectl --no-convert set-keymap` / `set-x11-keymap`) → `org.freedesktop.locale1` →
  `sway/config.in` ejecuta el script del Spin `locale1-xkb-config --oneshot` en cada
  arranque/reload. No hay archivo de teclado nuestro ni en `~/.config` ni en `/usr/share`
  (una versión vieja escribía `/usr/share/sway/config.d/10-keyboard.conf` a mano; `01-...`
  lo retira si lo encuentra y `nd-doctor` acusa cualquier archivo sin dueño RPM ahí). El
  `--no-convert` importa: sin él, `set-x11-keymap eu` borraba el keymap de consola.
- **Teclas de medios vs. volumen/brillo (no confundir):** las *de medios*
  (play/pause/next/prev → `playerctl`) **las provee el Spin tal cual**
  (`/usr/share/sway/config.d/60-bindings-media.conf`) y **NO** las override-amos: no hay
  un `60-bindings-media.conf` nuestro, a propósito. Las de *volumen* y *brillo* sí: las
  override-amos por mismo nombre de archivo para enrutarlas por **swayosd** (OSD en
  pantalla). Si las media keys dejaran de andar, es deriva del Spin → lo chequea
  `nd-doctor`.
- **`nd-doctor`** (en `~/.local/bin`, también al final del bootstrap) chequea tres
  bloques y **salta** (no falla) lo que necesita sesión gráfica: (1) **archivos del Spin**
  de los que dependemos sin controlarlos (waybar, swayidle, polkit, media keys, include en
  capas, `locale1-xkb-config`, `assign-cgroups`), porque si una versión futura los renombra
  todo falla en silencio; (2) **lo que `vars.sh` y el bootstrap prometen**: outputs
  declarados existen como conectores DRM, los configs renderizados desde `.in` llevan los
  valores actuales de `vars.sh`, keymaps/timezone/locale siguen como los seteó
  `01-...`, los `vm.*` del drop-in de sysctl están aplicados, el fondo de SDDM va por
  `theme.conf.user` y `default.jxl` sigue siendo el del RPM, el último `dnf upgrade` no
  tiene más de 14 días, systemd-oomd y
  `dnf5-automatic.timer` activos, rsyslog inactivo, y los `SESSION_SERVICES` `active`;
  (3) **integridad del despliegue**: `~/.bashrc` (viene de `/etc/skel`, no se versiona)
  carga `~/.bashrc.d`, el dueño de `org.freedesktop.Notifications` es swaync, timers
  `nd-*` activos, ninguna unit de usuario en `failed`, sin symlinks rotos hacia el repo y
  sin archivos sin dueño RPM en `/usr/share/sway/config.d`. El bloque (2) se agregó
  después de que el doctor diera "todo en orden" con tres daemons muertos y un nombre de
  output inexistente: chequeaba al Spin, nunca al propio setup.
- **Multi-monitor:** los nombres de output viven en `vars.sh`
  (`OUTPUT_INTERNAL`/`OUTPUT_EXTERNAL`, única fuente de verdad); tanto `sway/config` como
  `kanshi/config` se generan desde ahí. En esta laptop (Acer Aspire 5742, i915) el panel es
  **`LVDS-1`**, no `eDP-1`. Si cambiás de máquina, monitor o puerto, corré
  `swaymsg -t get_outputs` (o `ls /sys/class/drm`) y actualizá esos dos valores (más
  `DOCK_LEFT_WIDTH`), luego re-corré `04-stow.sh`. `nd-doctor` acusa un nombre inexistente.

### Toolkit y theming
- Familia **GTK / Adwaita-dark** en todo (GTK3 + GTK4 coordinados, cursor Adwaita 24
  replicado a XWayland por `environment.d/cursor.conf`).
- **Qt:** no se puede sacar 100% del Spin (entra por `lxqt-policykit` que arranca el
  Spin, `sddm`, `gstreamer-qt6`, `kf6-*`, `qtwebengine`). En vez de eso lo dejamos
  **cubierto como baseline**: `qt6ct` + `environment.d/qt.conf`
  (`QT_QPA_PLATFORM=wayland;xcb`, `QT_QPA_PLATFORMTHEME=qt6ct`) + `qt6ct/qt6ct.conf`
  (Fusion + paleta oscura + diálogos GTK). Así cualquier app Qt (incluido el diálogo de
  polkit) sale dark + Wayland. No reemplazamos el agente polkit del Spin.
- **Paletas (2 dominios):** el toolkit (GTK/Adwaita-dark) es el baseline, y el color de
  acento se divide en dos dominios deliberados, no por descuido:
  1. **Desktop + Terminal** (waybar, rofi, swaync, swayosd, swaylock, foot, tmux, prompt
     bash) → verde unificado `#387838` (el de tmux).
  2. **Editores** (nvim + Zed) → **Dracula** (púrpura), igual en ambos para que el editor
     sea su propia superficie de foco, consistente entre sí aunque distinta del escritorio.
  Cada herramienta replica el hex a mano en su config (no hay SSOT de color); es deuda
  conocida y aceptada (cada herramienta usa una sintaxis distinta). waybar además usa
  unos pocos colores *semánticos de estado* (cargando, screenshare, muteado, etc.),
  aparte del acento a propósito; sus valores viven en el `@define-color` de
  `waybar/style.css` (no se enumeran acá para que esta nota no quede desactualizada).

### Login / sesión
- **SDDM lo trae el Spin** (`reason: Group`); nosotros **solo lo configuramos**
  (`02-...sh` escribe `/etc/sddm.conf.d/ndelucca.conf` + wallpaper, no lo instala).
  Su greeter corre en **Wayland** (`sddm-wayland-sway`, `DisplayServer=wayland`). Es
  Qt pero pre-sesión: se deja como está.
- **Wallpaper del greeter vía `theme.conf.user`** del tema del Spin
  (`/usr/share/sddm/themes/03-sway-fedora/`): SDDM lee ese archivo al lado de
  `theme.conf` y pisa clave por clave; es su mecanismo oficial y vale para todos los
  usuarios. Antes copiábamos nuestro wallpaper sobre `default.jxl`, que es un **symlink**
  al fondo real del release (`f44/default/f44-01-day.jxl`, RPM `f44-backgrounds-base`):
  el `cp` pisaba el archivo real, cada update del paquete lo restauraba en silencio, y el
  `.bak` que guardábamos era copia de la versión ya pisada. `02-...sh` reinstala el
  paquete si el archivo real difiere de su RPM, y `nd-doctor` lo verifica (resolviendo
  el symlink, no mirando el paquete del symlink). Nota: `setup/wallpaper.png` es en
  realidad un JPEG con extensión `.png`; sway y SDDM lo cargan por contenido, así que
  funciona, pero el nombre miente.
- `EnableHiDPI` va bajo `[Wayland]` y `[X11]` en `sddm.conf.d`; bajo `[General]` (donde
  estuvo) SDDM lo ignora sin avisar. Es una opción general para cualquier máquina: no
  hace nada en un panel de baja densidad, escala el greeter en uno HiDPI.
- **GRUB: `grub2-mkconfig` siempre a `/boot/grub2/grub.cfg`**, BIOS o UEFI. Desde Fedora
  34 ese es el único `grub.cfg` real (`/etc/grub2-efi.cfg` apunta ahí) y el de la
  partición EFI es un stub que lo redirige; escribir ahí lo pisa. El tema breeze se baja
  por **commit fijo** (`THEME_COMMIT` en `02-...sh`) y sin sudo; solo la copia a `/boot`
  es root.
- **Agente polkit:** lo arranca el Spin (`/usr/share/sway/config.d/95-autostart-policykit-agent.conf`
  → `lxqt-policykit-agent`). Se deja (queda pintado por qt6ct).

### Audio / red
- **Audio = PipeWire** (+ `pipewire-pulse` + wireplumber). NO PulseAudio. El módulo
  `pulseaudio` de waybar usa la capa de compat — es lo correcto.
- Red = NetworkManager (`nmcli`, script `nd-fixed-ip`).

### Memoria
Esta laptop tiene **4 GB** (3.5 GB útiles) y el OOM killer del kernel ya mató Chromium
entero al menos una vez. Dos frentes, ambos declarativos:

- **`systemd-oomd` habilitado** (`setup/11-memory.sh`), con los umbrales del paquete
  `systemd-oomd-defaults` (declarado en `packages.txt`; **sin ese paquete el daemon corre
  pero no vigila nada**). Qué hace **de verdad** en este Spin, medido con `oomctl`: vigila
  la **presión** de memoria (PSI) de `user@1000.service/app.slice` (y de `system.slice`) y,
  pasado el umbral por 20 s, mata el **cgroup** hijo que más reclama; el chequeo por uso de
  swap está sin cgroups monitoreados, así que no actúa. La granularidad es **la app, no
  la pestaña**: `assign-cgroups.py` del Spin mueve a su propio scope solo el PID principal
  de cada ventana nueva, y el zygote de Chromium con todos sus renderers queda en
  `session-N.scope`, el mismo cgroup que sway, que oomd **no** monitorea. O sea: si la
  presión viene de las pestañas, oomd no la ve y actúa el OOM killer del kernel (que mata
  el proceso más grande, normalmente un renderer: una pestaña); si oomd actúa sobre
  `app.slice`, el candidato es el scope de Chromium y muere el navegador entero. La
  ventaja real sobre el kernel es que actúa **antes** (por PSI, no cuando no queda una
  página) y solo sobre lo que cuelga de la sesión de usuario, nunca servicios del sistema.
  Una versión anterior de este README afirmaba "cada pestaña es su propio cgroup; mata la
  pestaña, no el navegador": era falso.
- **oomd elige entre cgroups hoja, y lo lanzado desde la terminal hereda el del pane.**
  `assign-cgroups.py` solo mueve lo que nace en el cgroup del compositor (rofi, binds).
  Una app lanzada desde una shell queda en el scope de ese pane de tmux
  (`app-foot.slice/tmux-spawn-<uuid>.scope`; tmux ≥ 3.4 crea uno por pane), y como oomd
  recorre hasta las hojas, ese scope es el candidato: cae la app **y la shell del pane**,
  no todo tmux. Para lanzar una app gráfica desde la terminal sin ese acople está
  `launch <cmd>` (`dotfiles/.bashrc.d/06-launch.sh`): `systemd-run --user` en una unit
  `app-<cmd>-<n>` bajo `app.slice`, como si viniera de rofi.
- **Peso muerto fuera:** `rsyslog` deshabilitado (duplicaba en `/var/log/messages` lo que
  journald ya guarda estructurado) — deshabilitado, no desinstalado, para poder volver
  con un `systemctl enable`. Y `dunst` / `abrt` / `low-memory-monitor` desinstalados vía
  `remove-packages.txt` (ver "Apps que NO queremos").
- **zram ya viene del Spin** (3.5 GB, lzo-rle) y está bien como está: no lo tocamos.
- **Los `vm.*` del kernel sí los afinamos** (`11-memory.sh` → `/etc/sysctl.d/90-nd-zram.conf`),
  porque sus defaults asumen swap en **disco** y acá el swap es zram (~2.5× de compresión):
  `vm.swappiness=180` (swapear a RAM comprimida sale mucho más barato que tirar page cache
  que después hay que releer del disco), `vm.page-cluster=0` (el default lee 8 páginas de
  readahead por fallo apostando a amortizar un seek; zram es random-access puro, esas 7
  páginas extra son descompresión tirada) y `vm.watermark_boost_factor=0`. Son los valores
  que recomienda el propio zram-generator upstream, **no medidos acá**: en uso normal hay
  ~1.5 GB en zram comprimidos a ~0.7 GB. Si alguna vez se afina, hacerlo con datos
  (`zramctl`, `/proc/pressure/memory`), no por intuición. `nd-doctor` verifica que los
  valores del drop-in sean los que corren.

### Actualizaciones
- **Se descargan solas, se instalan a mano.** `setup/12-auto-updates.sh` habilita
  `dnf5-automatic.timer` (paquete `dnf5-plugin-automatic`): baja los updates en background
  para que el `dnf upgrade` de siempre corra casi instantáneo, pero **no instala nada** —
  el sistema no cambia a espaldas nuestras.
- **No forkeamos ningún config**: los defaults del paquete
  (`/usr/share/dnf5/dnf5-plugins/automatic.conf`) ya son exactamente los que queremos
  (`download_updates=yes`, `apply_updates=no`, `emit_via=stdio`), así que el script solo
  habilita el timer. Lo que sí hace es **verificar esas dos claves** y abortar si
  `apply_updates` dejara de ser `no`: un cambio de default río arriba convertiría esto en
  auto-instalación silenciosa. Para overridear algo va `/etc/dnf/automatic.conf`, no el
  archivo de `/usr/share`.
- **Sin notificación de escritorio, a propósito:** no queremos un aviso más; alcanza con
  que la descarga esté hecha para cuando uno decida actualizar. El resultado queda en el
  journal (`journalctl -u dnf5-automatic`).
- **Cadencia: 14 días como máximo**, y la vigila `nd-doctor` (días desde la última
  transacción `dnf update/upgrade` del historial). "A mano" sin umbral terminó en un mes
  entero sin instalar nada (2026-09-13 → 2026-10-13). Es el único recordatorio: no hay
  timer ni notificación, a propósito.
- El timer corre 06:00 con hasta 1 h de retraso aleatorio y `Persistent=true`, así que en
  una laptop apagada a esa hora el chequeo se recupera en el próximo arranque.

### Tareas croneadas (systemd user)
- Las tareas personales recurrentes corren como **systemd *user* units**, no atadas al
  arranque de la shell. Las units viven versionadas en `dotfiles/.config/systemd/user/` y
  las symlinkea **stow** junto con el resto de `.config`.
- Habilitarlas (crear los symlinks en `timers.target.wants/`) es trabajo de `systemctl`,
  no de stow: lo hace `setup/08-systemd-user.sh` después del stow, con
  `daemon-reload` + `enable --now`. **Convención:** habilita cualquier `nd-*.timer` del
  directorio. Agregar una tarea = soltar su `.service` + `.timer` con prefijo `nd-` y
  re-correr el bootstrap.
- El mismo paso habilita los **daemons de sesión** (`SESSION_SERVICES` en `vars.sh`; ver
  "Daemons de sesión" arriba). Si la unit ya está activa no la toca (re-correr el
  bootstrap no reinicia daemons sanos). Si no, antes de arrancarla mata la instancia
  suelta que pueda haber quedado (`pkill -x`) y hace `reset-failed`, porque una instancia
  viva fuera del cgroup de la unit hace fallar el `start`. Si no hay `graphical-session.target` activo
  (bootstrap por TTY/ssh), solo hace `enable`, sin `--now`: las units tienen
  `ExecCondition` sobre `WAYLAND_DISPLAY` y arrancan en el próximo login gráfico.
- No usa `loginctl enable-linger`: alcanza con la sesión gráfica activa. El paso de setup
  saltea sin romper si corre sin user manager (bootstrap headless).
- **`nd-public-ip`**: chequea la IP pública al iniciar sesión y cada hora
  (`nd-public-ip.timer` → `.service` → `nd-public-ip check`). Si cambió, avisa por
  **notificación de escritorio** (`notify-send` → swaync); ya no muestra alerta en la
  terminal. Aceptar la IP nueva con `nd-public-ip update`. El alias `myip` sigue usando
  `nd-public-ip show`.

### Fuentes
- **Regla: solo JetBrainsMono Nerd Font** en toda la UI (terminal, GTK, barras,
  launcher, lock). La trae el COPR `jhuang6451/nerd-fonts` (`jetbrains-mono-nf`).
- **Fallbacks de fontconfig** (automáticos, sin config): `google-noto-color-emoji-fonts`
  (emoji a color, no la monocromática) + `google-noto-sans-cjk-vf-fonts` (CJK). JetBrainsMono
  no cubre emoji/CJK; sin estos, web/chat con emoji o texto no-latino sale como tofu.

### Shell / CLI
- **Listados con `eza`** (ls moderno): los alias `ll`/`la`/`l` apuntan a eza (íconos Nerd
  Font + colores + dirs primero). `ls` pelado se deja como GNU ls a propósito (scripts y
  memoria muscular). `tree` se mantiene aunque `eza --tree` lo cubra.
- **`fzf`** cableado en `dotfiles/.bashrc.d/05-fzf.sh`: `Ctrl-R` (historial difuso a
  pantalla completa), `Ctrl-T`/`Alt-C`/`**<tab>`. Usa `fd` como fuente y el acento verde
  del dominio terminal. Se carga después de las completions (orden de glob de `bashrc.d`).
- **`bat`** (cat con sintaxis): declarado en `packages.txt` para reproducibilidad. **No**
  se aliasa a `cat` a propósito (`cat` queda plano para pipes/scripts); se usa como comando
  aparte. Config en `dotfiles/.config/bat/config`: `--paging=never` (sin pager) y
  `--style=plain` (cat coloreado: solo sintaxis, sin números/header/grid).
- **`git-delta`** como `core.pager` (configurado en `00-git-bash.sh`, scope `--system`):
  `git diff/show/log -p` legibles. Solo cambia cómo se VEN los diffs, no el comportamiento
  de git. Tema de sintaxis **Dracula** (el código se colorea con la paleta del dominio
  *editores*, aunque corra en la terminal).

### Editores
- **nvim** (terminal) + **Neovide** (GUI del *mismo* nvim) + **Zed**.
- Neovide se instala desde el **binario oficial de release** a `~/.local/bin/neovide-bin`
  (en `03-apps.sh`), NO por flatpak (el flatpak corre nvim en sandbox y no usaría el
  nvim / LSPs / toolchains del host). Comparte la config del submódulo nvim. Como no hay
  paquete que lo actualice, re-correr el bootstrap re-baja el binario cuando el release
  más nuevo (API de GitHub) difiere del instalado; se baja por tag, no por `latest`, así
  lo instalado es exactamente la versión comparada. Upstream no publica checksums.
- **"Reproducible" acá significa misma forma, no mismo estado:** Zed se auto-actualiza,
  Neovide sigue al último release y los COPR avanzan. Dos bootstraps dan la misma
  configuración con versiones distintas de esas tres cosas, a sabiendas. Lo que se puede
  fijar sin crear una tarea de mantenimiento (el tema de GRUB) está fijado por commit.
- **Zed NO se re-chequea en el bootstrap** (a diferencia de Neovide): `03-apps.sh` solo lo
  instala si falta. No es un olvido — Zed trae **auto-update propio** y se actualiza solo,
  así que un chequeo nuestro contra la API sería redundante. Neovide necesita el suyo
  justamente porque el binario de release no se auto-actualiza.
- El comando `neovide` en PATH es un **wrapper** (`dotfiles/.local/bin/neovide`): Neovide
  necesita **OpenGL >= 3.2** y en GPUs viejas (este Aspire 5742 tiene Intel Ironlake, tope
  GL 2.1) el contexto GL falla (`EGL_BAD_MATCH`). El wrapper detecta la versión de GL con
  `glxinfo` y cae a **render por software** (llvmpipe) solo si hace falta; en hardware
  capaz no toca nada. Trade-off en esta laptop: anda pero por CPU (no acelerado).

### Apps por defecto
- Terminal foot · launcher rofi · imágenes **Loupe** · PDF **Papers** · video **mpv** ·
  archivos **Thunar** · navegadores firefox/chromium. Los handlers se setean con
  `xdg-mime` al final de `03-apps.sh` (escriben en `~/.config/mimeapps.list`, que **no**
  se stowea porque es un archivo real que el sistema reescribe; lo que no seteamos —p. ej.
  http→chromium— se respeta como esté). Los archivos de texto/código (text/plain incluido,
  ver `NEOVIDE_MIMES`) abren en **Neovide**, no en nvim-en-terminal.
- **PWAs** vía `chromium --app=` (Spotify, ChatGPT, WhatsApp, Gmail) en `05-webapps.sh`
  — sin Electron. La lista vive en el array `WEBAPPS`; sacar un servicio de ahí borra su
  lanzador en la próxima corrida (prune declarativo).

### Navegador / Chromium
- Chromium se configura de forma declarativa vía **enterprise policies** (JSON en
  `/etc/chromium/policies/`). Es el único mecanismo overwrite-safe que expone: el perfil
  (`Preferences`/`Local State`) lo reescribe en runtime, así que **no** se stowea ni
  versiona. Fuente versionada: `setup/chromium-policies/{managed,recommended}.json`;
  las despliega `09-chromium-policies.sh` con sudo (como la conf de SDDM), validando con
  `jq` antes de copiar (un JSON inválido lo ignora Chromium **en silencio**).
- Dos niveles: **`managed/`** = forzado y grisado en `chrome://settings` (privacidad /
  anti-nag: telemetría off, sin tab promocional, sin nag de navegador por defecto, sign-in
  prompts off). **`recommended/`** = defaults que el usuario puede cambiar en la UI (inicio
  = restaurar sesión, botón home, y barra de bookmarks en off → **visible solo en la
  pestaña nueva vacía**, comportamiento nativo de Chromium).
- Instalamos en un archivo propio (`nd-policies.json`) para **coexistir** con el
  `disable-ai.json` que trae el RPM de Fedora (no lo tocamos).
- **Sync de cuenta Google: imposible en Chromium.** Google deshabilitó las APIs de
  Sync/Sign-in para todos los builds de Chromium en 2021. Gmail/Drive/etc. andan como webs
  normales (la PWA de Gmail sigue funcionando); solo el sync de bookmarks/passwords/historial
  a la cuenta requeriría sumar Google Chrome aparte.
- Verificar lo aplicado en `chrome://policy` (botón *Reload policies*).

### Apps que NO queremos
- Se borran de forma declarativa: la lista vive en `setup/remove-packages.txt`, borrado
  idempotente por `setup/07-remove-unwanted.sh` (cableado en `bootstraping.sh`).
- Además de las apps sueltas, la lista saca tres cosas que venían del Spin y **pesaban
  sin dar nada** en una máquina de 4 GB (ver "Memoria"): **`dunst`** (competía con swaync
  por el nombre de D-Bus `org.freedesktop.Notifications` — el journal lo registraba en
  cada arranque), el stack **`abrt`** (4 daemons de reporte de crashes, uno de ellos
  vigilando un log de Xorg que en Wayland no existe) y **`low-memory-monitor`** (su
  función la cubre systemd-oomd). Basta listar `abrt`: dnf arrastra addons, GUI y
  `libreport` como dependencias.
- **También sale lo que el live image dejó y no aplica a esta máquina:** los agentes de
  invitado de VM (`virtualbox-guest-additions`, `open-vm-tools`, `spice-vdagent`) — esto es
  bare metal, `systemd-detect-virt` dice `none`, pero venían con units habilitadas
  (`vboxservice`, `vmtoolsd`) y autostarts colgando de `graphical-session.target` —, el
  stack del instalador **Anaconda** (`anaconda-core` + `libreport-anaconda` + `dracut-live`,
  que arrastra `anaconda-live/-tui/-webui`, `kdump-anaconda-addon` y el jueguito
  `slitherer`), y **cockpit** (entró solo arrastrado por `anaconda-webui`).
- **`07-remove-unwanted.sh` usa `dnf remove --no-autoremove`, y es importante.** Por
  default dnf5 aplica `clean_requirements_on_remove=True`, o sea un *autoremove implícito*
  de las dependencias que quedan sin usar — justo lo que la sección "Decisiones
  deliberadas" dice que no queremos. No es teórico: declarando el stack de Anaconda +
  cockpit + agentes de VM, la diferencia medida fue **75 paquetes / 379 MB sin el flag**
  (incluyendo `openssl`, `flatpak`, `accountsservice`, `clevis-luks`, `udisks2-btrfs` y
  `zenity`, todos en uso) contra **17 paquetes / 37 MB con el flag** — exactamente lo
  declarado más sus dependientes, que son inevitables. Los dependientes sí vienen siempre:
  no se puede dejar instalado algo que requiere lo que borramos.

### Decisiones deliberadas (lo que NO hacemos, y por qué)
Cosas que un review razonable marcaría como "huecos" y que están así **a propósito**.
Anotadas para no volver a discutirlas cada vez.

- **Sin backup ni snapshots**, aunque el disco sea btrfs sobre LUKS (el escenario ideal
  para snapper). El motivo: **la máquina es reemplazable y este repo la reconstruye**. No
  se guardan datos personales ni sensibles en las PCs con este setup — son de uso y
  trabajo, y lo que importa vive en repos git remotos. Agregar snapper/restic sería
  proteger un estado que deliberadamente no tiene valor único.
- **Llave SSH sin passphrase**, `~/.ssh/id_ed25519`, sin `~/.ssh/config` ni
  `GIT_SSH_COMMAND` (ssh ya prueba ese archivo por defecto; el `GIT_SSH_COMMAND` que había
  no agregaba nada). Es una decisión de comodidad tomada a conciencia: LUKS cubre el disco
  apagado, y el riesgo residual (laptop robada con la sesión abierta) se acepta. No
  re-proponer passphrase + agente sin que haya cambiado esa premisa.
- **Sin contenedores** (podman/docker) instalados: no hacen falta hoy y en 4 GB de RAM no
  salen gratis.
- **Sin `dnf autoremove` en el bootstrap.** La limpieza de huérfanos se hace **a mano y
  una vez** cuando corresponde (p. ej. tras subir de versión de Fedora, que suele dejar
  cosas como `f43-backgrounds-base` colgadas). No va en un paso automático porque
  `autoremove` resuelve contra el estado del momento y no es auditable por adelantado:
  lo que se quiere borrar siempre se declara explícito en `remove-packages.txt`. Por eso
  mismo `07-remove-unwanted.sh` pasa `--no-autoremove` (ver "Apps que NO queremos"): sin
  ese flag el propio `dnf remove` hacía un autoremove implícito por la puerta de atrás,
  que es exactamente lo que este punto quiere evitar.
