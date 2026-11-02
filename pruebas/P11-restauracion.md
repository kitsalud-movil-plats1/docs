# P11 - Restauración

## Qué se prueba

**Enunciado.** Se elimina o modifica un recurso y se recupera desde un backup o snapshot.
**Presentación.** Se borra un archivo y se recupera.

kit01 hace una copia semanal con restic al disco USB (R11, D-10), con un snapshot por tipo (`config`, `recursos`, `bd` y `dominio`). La copia conserva dueños numéricos y ACL, así que el archivo restaurado vuelve con su dueño de AD.

## Qué necesitas

SSH a kit01 (NetBird) y a clinica01 a través de kit01. El archivo `prueba-p11.txt` ya está en `archivos` (lo subió `ana.rojas`). El disco USB está conectado.

## Paso a paso

1. Anotar el dueño, los permisos, la ACL y el sha256 del archivo, y guardar una copia en `/root/p11` de clinica01 por si algo falla.
2. Crear una tabla de prueba en `prerregistro` y anotar sus filas y su md5.
3. Hacer una copia ahora, para que el archivo y la tabla estén en el último snapshot.
4. Borrar el archivo de `archivos` y la tabla, y comprobar que ya no están, también por SMB con `ana.rojas`.
5. Montar el disco, restaurar el archivo desde el snapshot `recursos` y sacar el dump de `prerregistro` del snapshot `bd`.
6. Devolver el archivo a `archivos` con su dueño y ACL, y la tabla con `pg_restore`, midiendo el tiempo.
7. Comprobar que volvieron iguales y que `ana.rojas` abre el archivo por SMB.

## Con el script

Se ejecuta en la máquina de control (Ansible del kit, por NetBird), desde `docs/pruebas/`.

```bash
./scripts/P11-restauracion.sh [archivo]
```

Sigue el paso a paso de arriba. Pide confirmación antes de borrar y, si todo sale bien, borra al final la tabla de prueba y la copia de `/root/p11`; con alguna falla las deja para devolver el archivo a mano. La clave de `ana.rojas` la toma del vault. Cada línea sale como `[ OK ]` o `[FALLA]` y todo queda en `salidas/P11-<fecha>.txt`, que sirve de evidencia. Los comandos de abajo son los que usa el script, para ejecutarlos a mano o explicarlos.

## Comandos

```bash
# 1. En kit01, copia ahora (dura unos 30 s)
sudo systemctl start backup.service
journalctl -u backup -o cat -n 20          # Snapshot recursos ... y "no errors were found"

# 2-3. En clinica01
ls -ln /srv/samba/archivos/                 # prueba-p11.txt de 10101:10001
cat /srv/samba/archivos/prueba-p11.txt
sudo rm /srv/samba/archivos/prueba-p11.txt
ls /srv/samba/archivos/                     # vacío

# 4. En kit01, montar y restaurar
sudo -i
mount -o noatime,nodev,nosuid,noexec UUID=65308479-a4c6-4315-b83f-8cc61382bdcc /mnt/backup
export RESTIC_REPOSITORY=/mnt/backup/restic RESTIC_PASSWORD_FILE=/etc/kitsalud/backup/restic.clave RESTIC_CACHE_DIR=/var/cache/restic
restic snapshots --tag recursos
restic ls latest --tag recursos | grep prueba-p11
restic restore latest --tag recursos --include /var/lib/kitsalud/backup/clinica01/archivos/prueba-p11.txt --target /tmp/p11
ls -ln /tmp/p11/var/lib/kitsalud/backup/clinica01/archivos/
umount /mnt/backup

# 5. Copiarlo de vuelta a clinica01 con dueños y ACL
scp -p /tmp/p11/var/lib/kitsalud/backup/clinica01/archivos/prueba-p11.txt kitsalud@10.20.20.11:/tmp/
# en clinica01
sudo cp -a /tmp/prueba-p11.txt /srv/samba/archivos/ && sudo chown 10101:10001 /srv/samba/archivos/prueba-p11.txt

# 6. Comprobar
ls -ln /srv/samba/archivos/ && cat /srv/samba/archivos/prueba-p11.txt
```

## Explicación de los comandos

| Comando | Qué hace |
|---|---|
| `systemctl start backup.service` | Corre la copia: monta el disco, extrae de las VMs, crea los snapshots, aplica la retención y desmonta |
| `mount ... UUID=...` | Monta el disco USB por su UUID; fuera de la copia está desmontado |
| `export RESTIC_...` | Le dice a restic dónde está el repositorio, la clave (solo en kit01) y la caché |
| `restic snapshots --tag recursos` | Lista los snapshots de los recursos SMB, con fecha |
| `restic ls latest --tag recursos` | Muestra los archivos del último snapshot |
| `restic restore ... --include ... --target /tmp/p11` | Extrae solo ese archivo en una carpeta aparte, sin pisar nada |
| `ls -ln` | Muestra los dueños numéricos; `10101:10001` es `ana.rojas` y `clinicos` (RFC2307) |

**Tabla de PostgreSQL.** En clinica01 se crea una tabla de prueba con 1000 filas (`docker exec dhis2-db-1 psql -U dhis -d prerregistro -c "create table p11_prueba as select n, md5(n::text) as texto from generate_series(1, 1000) n"`), se copia y se borra (`drop table p11_prueba`). Para restaurarla, en kit01 con el disco montado `restic dump latest --tag bd /var/lib/kitsalud/backup/clinica01/postgres/prerregistro.dump > /tmp/p11/prerregistro.dump`, se copia a clinica01 y `docker exec -i dhis2-db-1 pg_restore -U dhis -d prerregistro -t p11_prueba < prerregistro.dump`. Se compara `select count(*), md5(string_agg(texto, ',' order by n)) from p11_prueba` antes y después.

**macOS.** El script funciona igual con Ansible y `sshpass` instalados (`brew install ansible` y `brew install hudochenkov/sshpass/sshpass`).

## Si algo falla

- **`El disco de backups ... no está conectado`.** `lsblk -f` en kit01 debe mostrar `kitbackup` con el UUID.
- **`restic` pide la clave.** Faltó el `export` en la misma sesión.

## Evidencia

La salida del script (`salidas/P11-<fecha>.txt`), con el estado del archivo y de la tabla antes de borrar, `restic snapshots` y `restic restore`, las comprobaciones de dueño, ACL, sha256, SMB y filas, y el tiempo de la restauración.
