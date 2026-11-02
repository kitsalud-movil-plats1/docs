# P4 - Acceso público local

**Fecha.** 2026-11-02, 16:55 (hora de Colombia) · **Entorno.** Kit real, en remoto por NetBird · **Versión.** `docs` `ddb5f1f`, `network` `1133967`, `platform` `025b11c`, `apps` `3969c3b`, `observability` `43b7ed6`

## Qué se prueba

El mismo cliente de la prueba de aislamiento accede a la biblioteca y al formulario locales según la política definida.

**Cómo se probó.** `prueba01`, la máquina virtual conectada a la red Comunidad, con el portal aceptado, ejecutó `./scripts/en-prueba01.sh P04-acceso-local.sh --enviar`. Abre la biblioteca, los videos, el formulario de prerregistro y la página de la CA del kit en IPv4 y en IPv6, verifica el certificado del formulario con la raíz del kit y envía un prerregistro de prueba por cada familia, lo mismo que llenar el formulario en el navegador. Después se comprobó en `clinica01` que los dos prerregistros llegaron a la base de datos y se borraron.

## Comandos y salida

```
== P04 - Acceso público local
Fecha 2026-11-02 16:55:45 -0500 · equipo prueba01 · Linux

## IPv4
  [ OK ]  IPv4 biblioteca (Kiwix) (200)
  [ OK ]  IPv4 videos (Jellyfin) (302)
  [ OK ]  IPv4 registro, certificado del kit verificado (200)
  [ OK ]  IPv4 página de la CA (200)

## IPv6
  [ OK ]  IPv6 biblioteca (Kiwix) (200)
  [ OK ]  IPv6 videos (Jellyfin) (302)
  [ OK ]  IPv6 registro, certificado del kit verificado (200)
  [ OK ]  IPv6 página de la CA (200)

## Certificado de registro
    subject: [NONE]
    issuer: O=Kit de salud movil; CN=Kit de salud movil - comunidad01
    SSL certificate verify ok.

## Prerregistro por IPv4
  [ OK ]  IPv4 prerregistro enviado, código DPDV

## Prerregistro por IPv6
  [ OK ]  IPv6 prerregistro enviado, código E66T
          Los códigos se buscan desde la Clínica en https://consultas.salud.movil

Resultado: 10 bien y 0 con falla.
```

**Los prerregistros en la base de `clinica01`.**

```
$ docker exec dhis2-db-1 psql -U dhis -d prerregistro -c "select codigo, nombres, apellidos, motivo, creado, atendido from prerregistros where codigo in ('DPDV','E66T')"
 codigo | nombres | apellidos | motivo  |       creado        | atendido
--------+---------+-----------+---------+---------------------+----------
 DPDV   | Prueba  | P4 IPv4   | CONTROL | 2026-11-02 21:55:45 | f
 E66T   | Prueba  | P4 IPv6   | CONTROL | 2026-11-02 21:55:45 | f
(2 rows)
```

La hora de la base está en UTC (16:55 en Colombia). Desde la Clínica, `ana.rojas` encontró después los dos códigos en la consulta de prerregistros, por IPv4 y por IPv6.

### IPv4

La biblioteca (Kiwix), la página de la CA y el formulario respondieron 200, y los videos (Jellyfin) 302, que es la redirección de Jellyfin a su página de inicio. El formulario se abrió por HTTPS con el certificado verificado y el prerregistro enviado por IPv4 quedó guardado con el código `DPDV`.

### IPv6

Los mismos servicios respondieron igual por IPv6 y el prerregistro enviado por IPv6 quedó guardado con el código `E66T`.

## Interpretación

Después de aceptar el portal, un invitado usa todos los servicios públicos del kit en las dos familias. El certificado del formulario lo emitió la CA intermedia de `comunidad01` y se verificó con la raíz del kit, así que el navegador no muestra advertencias cuando la raíz está instalada. El certificado no tiene sujeto (`subject: [NONE]`) porque identifica el servicio por su nombre alternativo, como hacen los certificados actuales. El formulario de la Comunidad escribe en la base de `clinica01` sin que el invitado llegue a `clinica01`, porque quien se conecta a la base es el servidor de la Comunidad, con un usuario que solo puede insertar.

## Resultado

Aprobada. 10 comprobaciones bien y ninguna falla, y los dos prerregistros llegaron a la Clínica. En la sustentación se repite con un celular en el SSID de la Comunidad, llenando el formulario en el navegador.
