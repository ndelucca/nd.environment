#!/usr/bin/env bash

set -euo pipefail

# Presión de memoria en una laptop de 4 GB. Dos cosas: habilitar systemd-oomd (actúa por
# PSI, antes que el OOM killer del kernel, y solo sobre cgroups de la sesión de usuario;
# qué cubre y qué NO en este Spin está medido en README, "Memoria") y afinar los vm.* para
# zram. Los umbrales de oomd los trae systemd-oomd-defaults (packages.txt): sin ese
# paquete el daemon corre pero no vigila nada, por eso este paso solo habilita.

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
# El swap es zram: los defaults del kernel asumen disco. Valores recomendados por
# zram-generator upstream, no medidos acá (README, "Memoria"). Drop-in propio en
# /etc/sysctl.d, sin tocar el del sistema. nd-doctor verifica que estén aplicados.

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
