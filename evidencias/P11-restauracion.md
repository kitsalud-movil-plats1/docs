# P11 - Restauración

**Fecha.** 2026-11-02, de 10:46 a 11:10 (hora de Colombia) · **Entorno.** Kit real, en remoto por NetBird · **Versión.** `platform` `d655908`, `docs` `085fe07` (script `pruebas/scripts/P11-restauracion.sh`)

## Qué se prueba

Se elimina o modifica un recurso y se recupera desde un backup o snapshot (P11). Se borran un archivo del recurso `archivos` y una tabla de prueba de la base `prerregistro` en clinica01, y se recuperan con restic desde el disco USB de kit01 (R11, D-10, sección 10.6).

## Comandos y salida

Se ejecutó `./scripts/P11-restauracion.sh` desde `docs/pruebas/` en la máquina de control. La salida completa es la siguiente.

```
== P11 - Restauración
Fecha 2026-11-02 10:46:45 -0500 · equipo melo-laptop · Linux

## 1. Estado antes de borrar
    10101:10001 660 4
    17e682f060b5f8e47ea04c5c4855908b0a5ad612022260fe50e11ecb0cc0ab76
    user::rw- group::rwx	#effective:rw- group:10001:rwx	#effective:rw- mask::rw- other::---
  [ OK ]  Copia de seguridad del archivo en /root/p11 de clinica01
    p11_prueba: 1000 5aa14879f8bb492bd62f332c5310d7c1 (filas y md5)
  [ OK ]  Tabla de prueba creada (1000)

## 2. Copia con backup.service
    Snapshot recursos: /var/lib/kitsalud/backup/clinica01/archivos /var/lib/kitsalud/backup/clinica01/contenido
    Snapshot bd: /var/lib/kitsalud/backup/clinica01/postgres/dhis2.dump /var/lib/kitsalud/backup/clinica01/postgres/prerregi
    no errors were found
  [ OK ]  Copia hecha en 31 s
  [ OK ]  El archivo llegó a kit01 (sha256) (17e682f060b5f8e47ea04c5c4855908b0a5ad612022260fe50e11ecb0cc0ab76)

## 3. Borrar el archivo y la tabla
    removed '/srv/samba/archivos/prueba-p11.txt'
    DROP TABLE
  [ OK ]  El archivo ya no está en archivos
  [ OK ]  ana.rojas ya no lo encuentra por SMB
  [ OK ]  La tabla p11_prueba ya no existe

## 4. Restaurar con restic desde el disco USB
    42ae3f3a  2026-11-02 10:47:33  kit01  recursos
    78f152e0  2026-11-02 10:47:34  kit01  bd
    Summary: Restored 7 / 1 files/dirs (4 B / 4 B) in 0:00
    10101:10001 660 4
    user::rw- group::rwx	#effective:rw- group:10001:rwx	#effective:rw- mask::rw- other::---
  [ OK ]  Dueño y permisos en el disco (10101:10001 660 4)
  [ OK ]  ACL en el disco (user::rw- group::rwx	#effective:rw- group:10001:rwx	#effective:rw- mask::rw- other::--- )
  [ OK ]  Disco desmontado otra vez

## 5. Devolverlo a clinica01

## 6. Comprobar
    10101:10001 660 4
    17e682f060b5f8e47ea04c5c4855908b0a5ad612022260fe50e11ecb0cc0ab76
    user::rw- group::rwx	#effective:rw- group:10001:rwx	#effective:rw- mask::rw- other::---
  [ OK ]  Dueño, permisos y tamaño (10101:10001 660 4)
  [ OK ]  Contenido (sha256) (17e682f060b5f8e47ea04c5c4855908b0a5ad612022260fe50e11ecb0cc0ab76)
  [ OK ]  ACL (user::rw- group::rwx	#effective:rw- group:10001:rwx	#effective:rw- mask::rw- other::--- )
  [ OK ]  ana.rojas lo abre por SMB (sha256) (17e682f060b5f8e47ea04c5c4855908b0a5ad612022260fe50e11ecb0cc0ab76)
  [ OK ]  Tabla p11_prueba (filas y md5) (1000 5aa14879f8bb492bd62f332c5310d7c1)
          Restauración del archivo y la tabla en 68 s (montar, restic, copiar y pg_restore)

## 7. Limpieza
  [ OK ]  Tabla de prueba y /root/p11 borradas

Resultado: 16 bien y 0 con falla.
```

Registro de la copia en kit01 (`journalctl -u backup.service`), con los cuatro snapshots de esta pasada.

```
10:47:25 backup-kit: Disco 65308479-a4c6-4315-b83f-8cc61382bdcc montado en /mnt/backup
10:47:26 backup-kit: clinica01: extrayendo por fd5a:fc7e:d716:20::11
10:47:31 backup-kit: comunidad01: extrayendo por fd5a:fc7e:d716:20::12
10:47:33 backup-kit: snapshot 1e96e958 saved      (config, 3896 archivos, 16 MiB)
10:47:34 backup-kit: snapshot 42ae3f3a saved      (recursos, 857,8 MiB, 1,8 KiB nuevos)
10:47:35 backup-kit: snapshot 78f152e0 saved      (bd, 1,4 MiB)
10:47:35 backup-kit: snapshot 7032189a saved      (dominio, 1,6 MiB)
10:47:38 systemd: Finished backup.service
```

### IPv4 e IPv6

La extracción salió por IPv6 hacia las dos VMs, que es la primera dirección que prueba `backup-kit`. Si IPv6 no responde, pasa a IPv4; ese cambio se probó en el laboratorio virtual (PR platform#45). La restauración trabaja con archivos y no depende de la familia.

## Interpretación

El archivo volvió con el mismo contenido (sha256), el mismo dueño de AD (`ana.rojas`, 10101, y `clinicos`, 10001), los mismos permisos y la misma ACL. La ACL ya venía bien en el disco, antes de devolverlo, así que restic la conserva, y `ana.rojas` lo volvió a abrir por SMB. La tabla volvió desde el dump de `prerregistro` con las mismas 1000 filas y el mismo md5. Entre montar el disco y terminar `pg_restore` pasaron 68 s, casi todo en las conexiones por NetBird desde la máquina de control; restic restauró el archivo en menos de un segundo. La fecha de modificación del archivo devuelto es la de la restauración, porque el script lo copia de nuevo a `archivos`.

## Resultado

Aprobada. 16 comprobaciones bien y ninguna falla, y al final no quedó la tabla de prueba ni la copia temporal, y el disco quedó desmontado.
