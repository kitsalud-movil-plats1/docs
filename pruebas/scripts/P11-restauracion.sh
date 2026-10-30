#!/usr/bin/env bash
# P11 - Restauración. Se ejecuta desde la máquina de control (Ansible del kit,
# por NetBird), con el disco USB conectado a kit01. Hace una copia, borra un
# archivo del recurso archivos de clinica01, lo restaura con restic desde el
# disco y comprueba que vuelve igual, con el mismo dueño y permisos.
#   ./P11-restauracion.sh [archivo]      (por defecto prueba-p11.txt)
source "$(dirname "$0")/comun.sh"
exige_ansible
iniciar P11 "Restauración"

ARCHIVO=${1:-prueba-p11.txt}
ORIGEN=/srv/samba/archivos/$ARCHIVO
STAGING=/var/lib/kitsalud/backup/clinica01/archivos/$ARCHIVO
UUID=65308479-a4c6-4315-b83f-8cc61382bdcc
RESTIC="export RESTIC_REPOSITORY=/mnt/backup/restic RESTIC_PASSWORD_FILE=/etc/kitsalud/backup/restic.clave RESTIC_CACHE_DIR=/var/cache/restic"

seccion "1. Estado del archivo"
ANTES=$(remoto clinica01 "stat -c '%u:%g %a %s' $ORIGEN && sha256sum $ORIGEN | cut -c1-64") || { mal "No existe $ORIGEN en clinica01"; terminar; exit 1; }
echo "$ANTES" | sed 's/^/    /'
DUENO_MODO=$(echo "$ANTES" | head -1)
SUMA=$(echo "$ANTES" | tail -1)

seccion "2. Copia con backup.service"
remoto kit01 "systemctl start backup.service; journalctl -u backup.service -o cat --since -5min | grep -E 'Snapshot recursos|no errors|falló'" | sed 's/^/    /'
if remoto kit01 "systemctl is-failed backup.service" | grep -q failed; then mal "backup.service falló"; terminar; exit 1; else bien "Copia hecha"; fi

seccion "3. Borrar el archivo"
confirmar "Se va a borrar $ORIGEN de clinica01. ¿Seguir?" || exit 1
remoto clinica01 "rm -v $ORIGEN" | sed 's/^/    /'
if remoto clinica01 "test -e $ORIGEN" >/dev/null; then mal "El archivo sigue"; else bien "El archivo ya no está en archivos"; fi

seccion "4. Restaurar con restic desde el disco USB"
remoto kit01 "set -e; rm -rf /tmp/p11; mount -o noatime,nodev,nosuid,noexec UUID=$UUID /mnt/backup; trap 'umount /mnt/backup' EXIT; $RESTIC
restic snapshots --tag recursos --compact | tail -4
restic restore latest --tag recursos --include $STAGING --target /tmp/p11
stat -c '%u:%g %a %s' /tmp/p11$STAGING" | sed 's/^/    /'

seccion "5. Devolverlo a clinica01"
LOCAL=$TMP_PRUEBAS/$ARCHIVO
(cd "$ANSIBLE_DIR" && ansible kit01 -b -m fetch -a "src=/tmp/p11$STAGING dest=$LOCAL flat=yes" >/dev/null) || mal "No se pudo traer el archivo de kit01"
DUENO=${DUENO_MODO%% *}
MODO=$(echo "$DUENO_MODO" | awk '{print $2}')
(cd "$ANSIBLE_DIR" && ansible clinica01 -b -m copy -a "src=$LOCAL dest=$ORIGEN owner=${DUENO%%:*} group=${DUENO##*:} mode=0$MODO" >/dev/null) || mal "No se pudo copiar a clinica01"
remoto kit01 "rm -rf /tmp/p11" >/dev/null

seccion "6. Comprobar"
DESPUES=$(remoto clinica01 "stat -c '%u:%g %a %s' $ORIGEN && sha256sum $ORIGEN | cut -c1-64")
echo "$DESPUES" | sed 's/^/    /'
comprobar "Dueño, permisos y tamaño" "$DUENO_MODO" "$(echo "$DESPUES" | head -1)"
comprobar "Contenido (sha256)" "$SUMA" "$(echo "$DESPUES" | tail -1)"
nota "A mano: abrir el archivo por SMB con ana.rojas (P7)"
terminar
