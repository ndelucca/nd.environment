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
  (idempotentes). Valores por máquina en `vars.sh` (única fuente de verdad); el hardware
  (monitores, sensores de temperatura) se autodetecta. Nota sobre el sensor de temperatura
  de waybar: `04-stow.sh` emite **todos** los `temp*_input` del sistema como array (CPU
  primero) y waybar usa el primero que exista, así un reordenamiento de los índices
  `hwmonN` por parte del kernel entre reboots ya no rompe la lectura. La lista
  autoritativa de paquetes dnf vive en `setup/packages.txt` (lo de abajo es un resumen
  conceptual del stack, no el manifiesto).
- **Dotfiles:** GNU **stow** `--no-folding` symlinkea `dotfiles/{.bashrc.d,.config,.local}`
  a `~`. Configs con valores variables se generan desde templates `.in`: `04-stow.sh`
  los renderiza (sed/jq) con los valores de `vars.sh` ANTES de stowear, y el resultado
  queda git-ignorado; solo se versiona el `.in`.
- **Config de Sway en capas:** usamos el `include` con `layered-include` del Spin. Los
  defaults del Spin viven en `/usr/share/sway/config.d/*`; nosotros override por
  **mismo nombre de archivo** en `~/.config/sway/config.d/`. **No** forkeamos archivos
  del sistema.
- **nvim:** submódulo aparte (`git@github.com:ndelucca/nvim.git`), gestionado con
  `vim.pack` nativo (sin gestor de plugins externo). `bootstraping.sh` corre
  `git submodule update --init --recursive`; si clonaste sin `--recurse-submodules`,
  ese paso lo trae igual.

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
- **swaync lo arranca systemd, no sway** (`swaync.service`, habilitado por
  `08-systemd-user.sh`). Antes iba con `exec_always pkill -x swaync; exec swaync` en
  `sway/config` y eso creaba un race: el paquete trae la unit con `Type=dbus` +
  `BusName=org.freedesktop.Notifications` **y** archivos de activación por D-Bus, así que
  cada `reload` de sway soltaba el nombre del bus y una notificación que llegara en esa
  ventana activaba la unit, chocando con la instancia recién lanzada por sway
  (`An instance of SwayNotificationCenter is already running!` → exit 1 → `failed`). Es la
  misma pelea por el nombre de D-Bus que ya había dado dunst, pero swaync contra sí mismo.
  Con la unit hay un único dueño posible, y de yapa `systemctl --user reload swaync`
  recarga config y CSS. **No volver a poner un `exec` de swaync en `sway/config`.**
- **Teclas de medios vs. volumen/brillo (no confundir):** las *de medios*
  (play/pause/next/prev → `playerctl`) **las provee el Spin tal cual**
  (`/usr/share/sway/config.d/60-bindings-media.conf`) y **NO** las override-amos: no hay
  un `60-bindings-media.conf` nuestro, a propósito. Las de *volumen* y *brillo* sí: las
  override-amos por mismo nombre de archivo para enrutarlas por **swayosd** (OSD en
  pantalla). Si las media keys dejaran de andar, es deriva del Spin → lo chequea
  `nd-doctor`.
- **Deriva del Spin:** como varios daemons (waybar, swayidle, agente polkit) y el
  `include` en capas dependen de archivos del Spin que NO controlamos, si una versión
  futura los renombra/elimina las cosas fallan en silencio. Correr **`nd-doctor`** (en
  `~/.local/bin`, también al final del bootstrap) chequea que esas suposiciones sigan
  válidas tras una actualización del sistema.
- **`nd-doctor` cubre dos bloques**, no solo el Spin: (1) los archivos del Spin de arriba
  y (2) las suposiciones del entorno propio que también fallan calladas — que `~/.bashrc`
  (viene de `/etc/skel`, no lo versionamos) siga cargando `~/.bashrc.d`, que el dueño del
  bus `org.freedesktop.Notifications` sea **swaync** y no otro daemon, que los timers
  `nd-*` estén activos, que **no haya units de usuario en `failed`**, y que stow no haya
  dejado symlinks rotos apuntando al repo. El chequeo de units caídas se sumó justamente
  porque el del bus de notificaciones tenía un punto ciego: preguntaba *quién es dueño del
  nombre* y daba OK mientras `swaync.service` estaba en `failed` al lado. Los
  chequeos que necesitan sesión gráfica se **saltean** (no fallan) en bootstrap headless.
- kanshi arranca por `exec_always` en `sway/config` (el `kanshi.service` está disabled).
- **Multi-monitor:** los nombres de output viven en `vars.sh`
  (`OUTPUT_INTERNAL`/`OUTPUT_EXTERNAL`, única fuente de verdad); tanto `sway/config` como
  `kanshi/config` se generan desde ahí. Si cambiás de monitor o de puerto, corré
  `swaymsg -t get_outputs` para ver los nombres reales y actualizá esos dos valores en
  `vars.sh` (más `DOCK_LEFT_WIDTH`), luego re-corré `04-stow.sh`.

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
  `systemd-oomd-defaults` (declarado en `packages.txt` — **sin ese paquete el daemon
  corre pero no vigila nada**). Por qué preferirlo al OOM killer del kernel: el del
  kernel actúa recién cuando no queda una página libre, o sea después de un buen rato de
  thrashing, y elige la víctima por un heurístico ciego de `oom_score` — mata el proceso
  más grande, que es el navegador completo. `systemd-oomd` mira la **presión** de memoria
  (PSI) y actúa antes, **por cgroup**: como cada pestaña de Chromium es su propio cgroup
  bajo la sesión, mata la pestaña, no el navegador. Solo toca lo que cuelga de
  `user@.service`; nunca servicios del sistema.
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
  que recomienda el propio zram-generator upstream.

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
- El mismo paso habilita además los **daemons de sesión que provee un paquete** y que
  preferimos dejar en manos de systemd en vez de un `exec` de `sway/config` — hoy
  `swaync.service`. Como no son units nuestras, no hay glob que las descubra: van en el
  array `SESSION_SERVICES` del script, nombradas a mano y con su porqué. Antes de
  habilitarlas el script mata el proceso suelto (`pkill -x`) y hace `reset-failed`: si
  quedó una instancia viva fuera del cgroup de la unit, el `start` choca por el nombre de
  D-Bus y la unit vuelve a `failed`.
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
  más nuevo (API de GitHub) difiere del instalado.
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
- **Llave SSH sin passphrase** y `GIT_SSH_COMMAND` exportado en `.bashrc.d/01-ps1.sh` en
  vez de un `~/.ssh/config`. Es una decisión de comodidad tomada a conciencia: LUKS cubre
  el disco apagado, y el riesgo residual (laptop robada con la sesión abierta) se acepta.
  No re-proponer passphrase + agente sin que haya cambiado esa premisa.
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
