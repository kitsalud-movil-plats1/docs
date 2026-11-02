# P7 - Identidad

**Fecha.** 2026-11-02, de 17:11 a 17:13 (hora de Colombia) · **Entorno.** Kit real, en remoto por NetBird · **Versión.** `docs` `ddb5f1f`, `network` `1133967`, `platform` `025b11c`, `apps` `3969c3b`, `observability` `43b7ed6`

## Qué se prueba

Un usuario del directorio inicia sesión en al menos un recurso administrativo.

**Cómo se probó.** Con dos recursos que usan el directorio del kit (Samba AD en `clinica01`). El recurso compartido `archivos` solo admite al grupo `clinicos`, y la consola de monitoreo (Grafana) solo al grupo `admins`. Con `./scripts/P07-identidad.sh smb-remoto`, sw01 (red Interna) abre el puerto 445 de `clinica01` en IPv4 y en IPv6, y `ana.rojas` (`clinicos`) y `laura.gomez` (`admins`) entran a `archivos` por cada familia con `smbclient`, ejecutado en `clinica01` porque sw01 no habla SMB. Con `./scripts/P07-identidad.sh grafana --vault`, las dos cuentas inician sesión en Grafana por el acceso de administración remota (NetBird), con el certificado verificado con la raíz del kit. Las claves salen del almacén cifrado del kit y no se escriben en ningún registro.

## Comandos y salida

**Recurso compartido `archivos`.**

```
== P07 - Identidad
Fecha 2026-11-02 17:11:44 -0500 · equipo melo-laptop · Linux

## Desde la Interna (sw01) hacia el 445 de clinica01
  [ OK ]  sw01 abre 10.20.20.11 puerto 445 (status: requesting)
  [ OK ]  sw01 abre [fd5a:fc7e:d716:20::11] puerto 445 (status: requesting)

## archivos por 10.20.20.11 con usuarios del dominio (en clinica01)
      prueba-p11.txt                      N        4  Mon Nov  2 10:48:59 2026

    		123268672 blocks of size 1024. 115727044 blocks available
  [ OK ]  ana.rojas (clinicos) entra a archivos por SMB3
    tree connect failed: NT_STATUS_ACCESS_DENIED
  [ OK ]  laura.gomez (admins) no entra a archivos

## archivos por fd5a:fc7e:d716:20::11 con usuarios del dominio (en clinica01)
      prueba-p11.txt                      N        4  Mon Nov  2 10:48:59 2026

    		123268672 blocks of size 1024. 115727044 blocks available
  [ OK ]  ana.rojas (clinicos) entra a archivos por SMB3
    tree connect failed: NT_STATUS_ACCESS_DENIED
  [ OK ]  laura.gomez (admins) no entra a archivos

## Lo que exige el servidor
  [ OK ]  Protocolo mínimo del servidor (SMB3)
  [ OK ]  Cifrado en archivos (required)

Resultado: 8 bien y 0 con falla.
```

**Consola de monitoreo.**

```
== P07 - Identidad
Fecha 2026-11-02 17:12:56 -0500 · equipo melo-laptop · Linux

## Grafana por NetBird (100.90.225.113)
          Raíz del kit tomada de kit01
  [ OK ]  laura.gomez (admins) entra a Grafana; isGrafanaAdmin false
  [ OK ]  ana.rojas (clinicos) no entra a Grafana (401)
          En kit01: journalctl -u grafana-server --since -10min | grep -i ldap

Resultado: 2 bien y 0 con falla.
```

### IPv4

sw01 abrió el 445 de `10.20.20.11`. Por esa dirección, `ana.rojas` listó el recurso `archivos` (contiene `prueba-p11.txt`) y `laura.gomez` recibió `NT_STATUS_ACCESS_DENIED`. En Grafana, por el túnel de administración, `laura.gomez` entró y `ana.rojas` recibió 401.

### IPv6

sw01 abrió el 445 de `fd5a:fc7e:d716:20::11` y por esa dirección el resultado fue el mismo, `ana.rojas` entra y `laura.gomez` no.

## Interpretación

Las cuentas del directorio sirven en más de un recurso y cada recurso deja entrar solo al grupo que corresponde. `ana.rojas`, del personal clínico, abre los archivos compartidos y no la consola de monitoreo; `laura.gomez`, de administración, abre la consola y no los archivos clínicos. Los archivos exigen SMB3 y cifrado, así que viajan cifrados aunque la red sea local.

## Resultado

Aprobada. 10 comprobaciones bien y ninguna falla (8 en los archivos y 2 en la consola). En la sustentación se monta `archivos` desde un PC de la red Interna con un usuario del dominio.
