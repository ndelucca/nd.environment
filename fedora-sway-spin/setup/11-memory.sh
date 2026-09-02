#!/usr/bin/env bash

set -euo pipefail

# Presión de memoria: esta laptop tiene 4 GB (3.5 GB útiles) y el OOM killer del kernel
# ya mató Chromium entero al menos una vez. Este paso ajusta cómo responde el sistema
# cuando la memoria escasea, y saca de encima daemons que no usamos.
#
# systemd-oomd vs. el OOM killer del kernel (por qué preferimos el primero):
#   - El del kernel actúa recién cuando NO queda una página libre. Para entonces el
#     sistema lleva rato en thrashing, y elige la víctima por un heurístico ciego de
#     oom_score: mata el proceso "más grande", o sea el navegador completo.
#   - systemd-oomd vigila la PRESIÓN de memoria (PSI: cuánto tiempo real están los
#     procesos frenados esperando RAM) y actúa antes, por cgroup. Como cada pestaña de
#     Chromium es su propio cgroup bajo la sesión, mata la pestaña en vez del navegador.
#     Solo actúa sobre lo que cuelga de user@.service; nunca sobre servicios del sistema.
#
# Los umbrales los aporta el paquete systemd-oomd-defaults (declarado en packages.txt):
# sin él el daemon corre pero no vigila nada. Por eso este paso solo habilita.

echo "Habilitando systemd-oomd (respuesta a presión de memoria por cgroup)"
if ! rpm -q systemd-oomd-defaults &>/dev/null; then
    echo "  AVISO: systemd-oomd-defaults no está instalado; oomd quedaría sin umbrales."
    echo "  Corré 03-apps.sh (lo instala desde packages.txt) y volvé a este paso."
else
    sudo systemctl enable --now systemd-oomd.service 2>/dev/null \
        || echo "  (no se pudo habilitar ahora; aplica al próximo arranque)"
fi

# rsyslog duplica en /var/log/messages lo que journald ya guarda de forma estructurada:
# dos daemons y dos copias del mismo log. Deshabilitamos el servicio en vez de quitar el
# paquete, para poder volver atrás con un solo `systemctl enable` si alguna vez hace falta
# un /var/log/messages en texto plano.
echo "Deshabilitando rsyslog (journald ya cubre el log del sistema)"
if systemctl list-unit-files rsyslog.service &>/dev/null; then
    sudo systemctl disable --now rsyslog.service 2>/dev/null \
        || echo "  (no se pudo deshabilitar ahora)"
else
    echo "  rsyslog no está instalado; nada que hacer."
fi

# --- Parámetros de VM afinados para zram (no para disco) ---
#
# El swap de esta máquina es zram (3.5 GB, lzo-rle, ~2.5x de compresión): swapear escribe
# a RAM comprimida, no a un plato girando. Los defaults del kernel para vm.* asumen swap
# en DISCO, así que sin esto el kernel prefiere tirar page cache antes que usar un swap
# que en realidad le sale baratísimo. Los tres valores son los que recomienda el propio
# zram-generator upstream.
#
# Drop-in en /etc/sysctl.d/ en vez de tocar 99-sysctl.conf: mismo criterio que el resto
# del setup (override por archivo propio, sin forkear el del sistema).

echo "Aplicando parámetros de VM afinados para zram (/etc/sysctl.d)"

sudo tee /etc/sysctl.d/90-nd-zram.conf >/dev/null <<'SYSCTL'
# Afinado para swap en zram. Ver setup/11-memory.sh y el README (sección "Memoria").

# Cuánto prefiere el kernel swapear vs. reclamar page cache. El default 60 está calibrado
# para disco. Con zram, swapear cuesta una compresión en RAM: conviene hacerlo mucho antes
# que tirar cache que después hay que releer del disco.
vm.swappiness = 180

# Readahead de swap, en potencias de 2 páginas. El default 3 lee 8 páginas por cada fallo,
# apostando a que un seek de disco amortiza traer vecinas. zram es random-access puro: esas
# 7 páginas extra son descompresión y RAM tiradas. 0 = traer solo la página pedida.
vm.page-cluster = 0

# Boost del watermark de reclaim tras fragmentación. Pensado para dar aire a un disco lento;
# con zram detrás solo genera reclaim extra innecesario.
vm.watermark_boost_factor = 0
SYSCTL

# Aplica sin reboot. Si corre sin systemd a mano (bootstrap headless), no es fatal.
sudo sysctl --system >/dev/null 2>&1 \
    || echo "  (no se pudieron aplicar ahora; toman efecto al próximo arranque)"

# Nota: dunst, el stack abrt y low-memory-monitor también salen por memoria/peso muerto,
# pero eso es borrado de paquetes: vive de forma declarativa en remove-packages.txt y lo
# aplica 07-remove-unwanted.sh. Acá solo va lo que es estado de servicios.
