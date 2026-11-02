# P4 - Acceso público local

## Qué se prueba

**Enunciado.** El mismo cliente de P3 accede a la biblioteca y al formulario locales según la política definida.
**Presentación.** Biblioteca, videos y registro después del portal.

F-09 es la única excepción de la Comunidad hacia la red de servidores: con el portal aceptado, los puertos 80 y 443 de comunidad01. Los prerregistros se guardan en PostgreSQL de clinica01 por F-11, sin que el cliente toque clinica01.

## Qué necesitas

El mismo equipo de P3, en la Comunidad y con el portal aceptado. Para `registro` sin aviso, instalar antes la raíz del kit desde `http://ca.salud.movil`.

## Paso a paso

1. Abrir `http://portal.salud.movil` y entrar a cada ícono del menú.
2. En la biblioteca, abrir un artículo de Wikipedia Médica.
3. En videos, entrar como `comunidad` y reproducir un video.
4. En registro, llenar un prerregistro con datos ficticios y anotar el código.
5. Desde la Clínica, abrir `https://consultas.salud.movil` y ver que el prerregistro llegó (une P4 con P6).

## Con el script

Se ejecuta en el mismo cliente de la Comunidad, desde `docs/pruebas/`.

```bash
./scripts/P04-acceso-local.sh
```

Revisa biblioteca, videos, registro (verificando el certificado con la raíz del kit, sin `-k`) y la CA en IPv4 e IPv6, y muestra quién firmó el certificado de registro. El prerregistro se llena a mano. Cada línea sale como `[ OK ]` o `[FALLA]` y todo queda en `salidas/P04-<fecha>.txt`, que sirve de evidencia. Los comandos de abajo son los que usa el script, para ejecutarlos a mano o explicarlos.

## Comandos de verificación

| Comando o acción | Qué muestra | Esperado |
|---|---|---|
| `curl -4 -I http://biblioteca.salud.movil` y `curl -6 -I ...` | Kiwix en comunidad01 | `200 OK` (cabecera `Via: 1.1 Caddy`) |
| `curl -4 -I http://videos.salud.movil` y `curl -6 -I ...` | Jellyfin | `200` o `302` hacia `/web/` |
| `curl -4 -I https://registro.salud.movil` y `curl -6 -I ...` | Formulario por HTTPS con el certificado del kit (sin `-k`, si la raíz está instalada) | `200 OK` |
| `curl -4 -I http://ca.salud.movil` | La página de la raíz del kit | `200 OK` |
| Enviar el formulario | Que se guarda | Muestra un código corto |
| En la Clínica, `https://consultas.salud.movil` | Que el registro llegó a clinica01 | Aparece con el código anotado |

`-I` pide solo las cabeceras, suficiente para ver el código de respuesta.

**En kit01 (remoto).** `sudo nft list set inet filtro portal_ok` muestra la MAC del cliente en el set de autorizados; sin ella F-09 no lo deja pasar.

**macOS.** Los `curl` son iguales. Para instalar la raíz, abrir `raiz.crt` (se agrega a Acceso a Llaveros), buscar **Kit de salud movil - Raiz**, abrirla y en Confiar elegir **Confiar siempre**; o en la terminal `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain raiz.crt`.

## Si algo falla

- **Todo redirige al portal.** El equipo no está en `portal_ok`. Abrir `http://portal.salud.movil` y tocar Acepto.
- **`registro` muestra aviso de certificado.** Falta la raíz del kit. Seguir las instrucciones de `http://ca.salud.movil`.
- **El formulario no guarda.** En comunidad01, `docker logs formularios-app-1`; F-11 hacia el 5432 de clinica01.

## Evidencia

Capturas de la biblioteca, un video reproduciéndose y el código del prerregistro desde el celular; salida de los `curl` IPv4 e IPv6; la captura de `consultas` con el registro.
