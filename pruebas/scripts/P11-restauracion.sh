#!/usr/bin/env bash
# P11 - Restauración. Se ejecuta desde la máquina de control (Ansible del kit,
# por NetBird), con el disco USB conectado a kit01. Hace una copia, borra un
# archivo del recurso archivos y una tabla de prueba de prerregistro en
# clinica01, los restaura con restic desde el disco y comprueba que vuelven
# iguales (dueño, permisos, ACL, sha256 y filas) y que ana.rojas abre el
# archivo por SMB, midiendo el tiempo. Antes de borrar deja una copia del
# archivo en /root/p11 de clinica01, que se quita solo si todo salió bien.
#   ./P11-restauracion.sh [archivo]      (por defecto prueba-p11.txt)
source "$(dirname "$0")/comun.sh"
exige_ansible
iniciar P11 "Restauración"

ARCHIVO=${1:-prueba-p11.txt}
ORIGEN=/srv/samba/archivos/$ARCHIVO
STAGING=/var/lib/kitsalud/backup/clinica01/archivos/$ARCHIVO
DUMP=/var/lib/kitsalud/backup/clinica01/postgres/prerregistro.dump
UUID=65308479-a4c6-4315-b83f-8cc61382bdcc
RESTIC="export RESTIC_REPOSITORY=/mnt/backup/restic RESTIC_PASSWORD_FILE=/etc/kitsalud/backup/restic.clave RESTIC_CACHE_DIR=/var/cache/restic"
TABLA=p11_prueba
PSQL="docker exec dhis2-db-1 psql -U dhis -d prerregistro -tAc"
# Filas y md5 de la tabla, sin comillas para que pase por Ansible
FIRMA="select count(*) || chr(32) || md5(string_agg(texto, chr(44) order by n)) from $TABLA"
# Dueño, permisos y tamaño; sha256; ACL en una línea
ESTADO="stat -c '%u:%g %a %s' $ORIGEN && sha256sum $ORIGEN | cut -c1-64 && getfacl -cnp $ORIGEN | paste -sd' '"
# El archivo leído por SMB como ana.rojas (clave del vault)
SMB="export PASSWD='{{ vault_samba_usuarios_password }}'; smbclient //archivos.$DOMINIO/archivos -U ana.rojas -m SMB3 -c 'get $ARCHIVO -' 2>/dev/null"

seccion "1. Estado antes de borrar"
ANTES=$(remoto clinica01 "$ESTADO") || { mal "No existe $ORIGEN en clinica01"; terminar; exit 1; }
echo "$ANTES" | sed 's/^/    /'
DUENO_MODO=$(echo "$ANTES" | sed -n 1p)
SUMA=$(echo "$ANTES" | sed -n 2p)
ACL=$(echo "$ANTES" | sed -n 3p)
if remoto clinica01 "install -d -m 700 /root/p11 && cp -a $ORIGEN /root/p11/" >/dev/null; then
  bien "Copia de seguridad del archivo en /root/p11 de clinica01"
else
  mal "No se pudo copiar el archivo a /root/p11"; terminar; exit 1
fi
remoto clinica01 "$PSQL \"drop table if exists $TABLA; create table $TABLA as select n, md5(n::text) as texto from generate_series(1, 1000) n\"" >/dev/null
TABLA_ANTES=$(remoto clinica01 "$PSQL \"$FIRMA\"")
echo "    $TABLA: $TABLA_ANTES (filas y md5)"
comprobar "Tabla de prueba creada" 1000 "${TABLA_ANTES%% *}"

seccion "2. Copia con backup.service"
T0=$(date +%s)
remoto kit01 "systemctl start backup.service; journalctl -u backup.service -o cat --since -5min | grep -E '^Snapshot (recursos|bd)|no errors|falló'" | cut -c1-120 | sed 's/^/    /'
if remoto kit01 "systemctl is-failed backup.service" | grep -qx failed; then mal "backup.service falló"; terminar; exit 1; fi
bien "Copia hecha en $(($(date +%s) - T0)) s"
comprobar "El archivo llegó a kit01 (sha256)" "$SUMA" "$(remoto kit01 "sha256sum $STAGING | cut -c1-64")"

seccion "3. Borrar el archivo y la tabla"
confirmar "Se va a borrar $ORIGEN y la tabla $TABLA de prerregistro en clinica01. ¿Seguir?" || exit 1
remoto clinica01 "rm -v $ORIGEN; $PSQL \"drop table $TABLA\"" | sed 's/^/    /'
if remoto clinica01 "test -e $ORIGEN" >/dev/null; then mal "El archivo sigue"; else bien "El archivo ya no está en archivos"; fi
if remoto clinica01 "$SMB" >/dev/null; then mal "ana.rojas todavía lo ve por SMB"; else bien "ana.rojas ya no lo encuentra por SMB"; fi
if remoto clinica01 "$PSQL \"$FIRMA\"" >/dev/null; then mal "La tabla sigue"; else bien "La tabla $TABLA ya no existe"; fi

seccion "4. Restaurar con restic desde el disco USB"
T0=$(date +%s)
DISCO=$(remoto kit01 "set -e; rm -rf /tmp/p11; install -d -m 700 /tmp/p11
mount -o noatime,nodev,nosuid,noexec UUID=$UUID /mnt/backup; trap 'umount /mnt/backup' EXIT; $RESTIC
restic snapshots --tag recursos --tag bd --latest 1 --compact | sed -n '3,4p'
restic restore latest --tag recursos --include $STAGING --target /tmp/p11 | tail -1
restic dump latest --tag bd $DUMP > /tmp/p11/prerregistro.dump
stat -c '%u:%g %a %s' /tmp/p11$STAGING; getfacl -cnp /tmp/p11$STAGING | paste -sd' '")
echo "$DISCO" | sed 's/^/    /'
comprobar "Dueño y permisos en el disco" "$DUENO_MODO" "$(echo "$DISCO" | tail -2 | head -1)"
comprobar "ACL en el disco" "$ACL" "$(echo "$DISCO" | tail -1)"
if remoto kit01 "mountpoint -q /mnt/backup" >/dev/null; then mal "/mnt/backup quedó montado"; else bien "Disco desmontado otra vez"; fi

seccion "5. Devolverlo a clinica01"
LOCAL=$TMP_PRUEBAS/$ARCHIVO
DUENO=${DUENO_MODO%% *}
MODO=$(echo "$DUENO_MODO" | awk '{print $2}')
(cd "$ANSIBLE_DIR" && ansible kit01 -b -m fetch -a "src=/tmp/p11$STAGING dest=$LOCAL flat=yes" >/dev/null &&
  ansible kit01 -b -m fetch -a "src=/tmp/p11/prerregistro.dump dest=$TMP_PRUEBAS/prerregistro.dump flat=yes" >/dev/null) || mal "No se pudo traer lo restaurado de kit01"
# El archivo nuevo hereda la ACL por defecto de archivos; se compara abajo
(cd "$ANSIBLE_DIR" && ansible clinica01 -b -m copy -a "src=$LOCAL dest=$ORIGEN owner=${DUENO%%:*} group=${DUENO##*:} mode=0$MODO" >/dev/null &&
  ansible clinica01 -b -m copy -a "src=$TMP_PRUEBAS/prerregistro.dump dest=/root/p11/prerregistro.dump mode=0600" >/dev/null) || mal "No se pudo copiar a clinica01"
remoto clinica01 "docker exec -i dhis2-db-1 pg_restore -U dhis -d prerregistro -t $TABLA < /root/p11/prerregistro.dump" >/dev/null || mal "pg_restore falló"
TIEMPO=$(($(date +%s) - T0))
remoto kit01 "rm -rf /tmp/p11" >/dev/null

seccion "6. Comprobar"
DESPUES=$(remoto clinica01 "$ESTADO")
echo "$DESPUES" | sed 's/^/    /'
comprobar "Dueño, permisos y tamaño" "$DUENO_MODO" "$(echo "$DESPUES" | sed -n 1p)"
comprobar "Contenido (sha256)" "$SUMA" "$(echo "$DESPUES" | sed -n 2p)"
comprobar "ACL" "$ACL" "$(echo "$DESPUES" | sed -n 3p)"
comprobar "ana.rojas lo abre por SMB (sha256)" "$SUMA" "$(remoto clinica01 "$SMB | sha256sum | cut -c1-64")"
comprobar "Tabla $TABLA (filas y md5)" "$TABLA_ANTES" "$(remoto clinica01 "$PSQL \"$FIRMA\"")"
nota "Restauración del archivo y la tabla en $TIEMPO s (montar, restic, copiar y pg_restore)"

seccion "7. Limpieza"
if [ "$MAL" -eq 0 ]; then
  remoto clinica01 "$PSQL \"drop table $TABLA\"; rm -rf /root/p11" >/dev/null && bien "Tabla de prueba y /root/p11 borradas"
else
  nota "Con fallas no se limpia. La copia del archivo está en /root/p11 de clinica01:"
  nota "  sudo cp -a /root/p11/$ARCHIVO $ORIGEN"
fi
terminar
