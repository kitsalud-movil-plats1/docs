# P7 - Identidad

## Qué se prueba

**Enunciado.** Un usuario del directorio inicia sesión en al menos un recurso administrativo.
**Presentación.** Un usuario del dominio entra a Grafana y a archivos.

Samba AD (`ad.salud.movil`) en clinica01. El recurso SMB `archivos` solo admite al grupo `clinicos` y exige cifrado (SMB3). Grafana usa LDAPS contra el mismo dominio: `admins` entra como Admin y los demás no entran.

## Qué necesitas

Un PC en la Clínica para `archivos`, y NetBird para Grafana (F-01 solo deja entrar a Grafana desde las IP de administración y NetBird; todavía no hay IP de administración reservadas). La contraseña de los usuarios de prueba del dominio.

## Paso a paso

**Recurso `archivos`.**

1. En la Clínica, abrir el explorador de archivos. Linux: `smb://archivos.salud.movil/archivos`. Windows: `\\archivos.salud.movil\archivos`.
2. Entrar con `ana.rojas` (dominio `AD`). Crear un archivo.
3. Intentar con `laura.gomez`. No entra, porque no es de `clinicos`.

**Grafana.**

1. Con NetBird activo en la laptop, abrir `https://monitoreo.salud.movil` (en la laptop de Melo, la línea de `monitoreo` en `/etc/hosts` apunta a `100.90.225.113`).
2. Entrar con `laura.gomez`. Entra como Admin y ve **Estado del kit**.
3. Intentar con `ana.rojas`. No entra.

## Con el script

Se ejecuta desde `docs/pruebas/`; `smb` en un cliente de la Clínica y `grafana` en un equipo con NetBird.

```bash
./scripts/P07-identidad.sh smb
./scripts/P07-identidad.sh grafana
```

`smb` lista `archivos` con `ana.rojas` y espera el rechazo de `laura.gomez`; `grafana` entra a Grafana por NetBird (sin tocar `/etc/hosts`) con `laura.gomez` y espera el rechazo de `ana.rojas`. Pide las contraseñas y no las guarda. Cada línea sale como `[ OK ]` o `[FALLA]` y todo queda en `salidas/P07-<fecha>.txt`, que sirve de evidencia. Los comandos de abajo son los que usa el script, para ejecutarlos a mano o explicarlos.

## Comandos de verificación

| Comando | Qué muestra | Esperado |
|---|---|---|
| `smbclient //archivos.salud.movil/archivos -U AD/ana.rojas -m SMB3 -c 'ls'` | Que el usuario del dominio entra y lista | Lista los archivos |
| `smbclient //archivos.salud.movil/archivos -U AD/laura.gomez -m SMB3 -c 'ls'` | Que otro grupo no entra | `NT_STATUS_ACCESS_DENIED` |
| En clinica01, `sudo smbstatus -b` y `sudo smbstatus -S` | La sesión con su uid, versión y cifrado | `10101` (ana.rojas), `SMB3_11`, `archivos` con `AES-128-GCM` |
| En clinica01, `sudo tail /var/log/samba/auth.log` (o `/var/log/kitsalud/clinica01/auth.log` en kit01) | El inicio de sesión aceptado y el rechazado | `NT_STATUS_OK` para ana.rojas |
| `kinit ana.rojas@AD.SALUD.MOVIL` y `klist` (opcional, con `krb5-workstation`) | Que el dominio emite un ticket Kerberos | Un ticket `krbtgt/AD.SALUD.MOVIL` |
| En kit01, `journalctl -u grafana-server --since -10m \| grep -i login` | El login de Grafana por LDAP | Login de `laura.gomez` |

`smbclient` viene en `samba-client` (Fedora). `-m SMB3` exige la versión 3, la que soporta cifrado.

**macOS.** En Finder, Ir → Conectarse al servidor (⌘K) → `smb://archivos.salud.movil/archivos`, usuario `AD\ana.rojas`. En la terminal, `smbutil view //'AD;ana.rojas'@archivos.salud.movil` lista los recursos; el script monta `archivos` con `mount_smbfs` y lo desmonta al terminar. `kinit ana.rojas@AD.SALUD.MOVIL` y `klist` vienen con el sistema.

## Si algo falla

- **`archivos` no aparece.** El equipo no está en la Clínica, o tiene `archivos.salud.movil` en `/etc/hosts`.
- **Grafana no abre por la Interna.** Es lo esperado sin IP de administración; usar NetBird.

## Evidencia

Captura del recurso abierto con `ana.rojas` y del rechazo de `laura.gomez`; la línea de `smbstatus` con el cifrado; captura de Grafana con `laura.gomez` como Admin y el rechazo de `ana.rojas`.
