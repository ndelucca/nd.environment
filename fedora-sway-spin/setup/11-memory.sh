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

# Nota: dunst, el stack abrt y low-memory-monitor también salen por memoria/peso muerto,
# pero eso es borrado de paquetes: vive de forma declarativa en remove-packages.txt y lo
# aplica 07-remove-unwanted.sh. Acá solo va lo que es estado de servicios.
