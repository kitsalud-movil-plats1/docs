# P5 - Portal cautivo

## Qué se prueba

**Enunciado.** Un cliente nuevo es redirigido al portal cautivo.
**Presentación.** Un cliente nuevo ve el portal, también sin Internet.

Sin aceptar, nftables manda todo el HTTP del cliente a nginx en kit01, que lo lleva a `http://portal.salud.movil`; el HTTPS se rechaza (D-22, F-08). Al tocar Acepto, el servicio agrega la MAC del equipo al set `portal_ok` por 8 h. `http://portal.salud.movil` muestra el menú a quien ya aceptó.

## Qué necesitas

Un equipo que no haya aceptado (o que vuelva con otra MAC). Un iPhone con dirección privada rotativa o una laptop que olvidó la red cuentan como nuevos.

## Paso a paso

1. Conectar el equipo a `SaludMovil-Comunidad`.
2. **iPhone y Android.** El sistema abre solo la ventana del portal.
3. **PC.** Abrir `http://neverssl.com` o `http://portal.salud.movil`. En Fedora, el aviso "You need to log in" abre `https://fedoraproject.org/static/hotspot.txt` y no carga, porque el navegador fuerza HTTPS en ese sitio; se ignora y se abre el portal a mano.
4. Leer las condiciones y tocar **Acepto**. Aparece el menú.
5. Abrir otra vez `http://portal.salud.movil`; ahora muestra el menú directamente.
6. Repetir los pasos 1 a 4 con la WAN desconectada (con P9).

## Con el script

Se ejecuta en un cliente nuevo de la Comunidad, desde `docs/pruebas/`.

```bash
./scripts/P05-portal.sh [--aceptar]
```

Revisa que el HTTP va al portal en IPv4 e IPv6 y que el HTTPS se rechaza; con `--aceptar` hace lo mismo que el botón Acepto y comprueba que después pasa y que el portal muestra el menú. Si el equipo ya estaba autorizado, lo dice. Cada línea sale como `[ OK ]` o `[FALLA]` y todo queda en `salidas/P05-<fecha>.txt`, que sirve de evidencia. Los comandos de abajo son los que usa el script, para ejecutarlos a mano o explicarlos.

## Comandos de verificación

**En un PC sin aceptar.**

| Comando | Qué muestra | Esperado |
|---|---|---|
| `curl -4 -I http://neverssl.com` | Que cualquier HTTP se desvía al portal | `302` con `Location: http://portal.salud.movil/` |
| `curl -6 -I http://biblioteca.salud.movil` | Lo mismo por IPv6 | `302` hacia el portal |
| `curl -4 -m 5 -I https://example.com` | Que el HTTPS se rechaza enseguida | `Connection refused` o reset |
| `curl -4 -s -X POST -o /dev/null -w "%{http_code}\n" http://portal.salud.movil/aceptar` | Lo mismo que tocar Acepto | `303` |
| `curl -4 -I http://biblioteca.salud.movil` después de aceptar | Que ya pasa | `200` |

**En kit01 (remoto).**

| Comando | Qué muestra |
|---|---|
| `sudo nft list set inet filtro portal_ok` | Las MAC autorizadas y cuánto les queda |
| `grep -v Blackbox /var/log/nginx/portal.log \| tail` | Las visitas al portal; los `GET /hotspot-detect.html` (iPhone) o `/static/hotspot.txt` (Fedora) con `302` son la detección automática del sistema |
| `journalctl -u kitsalud-portal -n 20` | `autorizada <MAC> desde <IP>` al aceptar |

**macOS.** Igual que el iPhone, abre solo la ventana del portal (Asistente de red cautiva) al conectarse. Si no aparece, abrir `http://neverssl.com` en Safari. Los `curl` son iguales.

## Si algo falla

- **"refused to connect" en `portal.salud.movil`.** Revisar `/etc/hosts` del equipo; si el nombre apunta a `127.0.0.1`, comentarlo.
- **El iPhone dice "no internet connection" y no abre nada.** Es el problema de sw01 en la VLAN 40 (ver P1).
- **No vuelve a pedir el portal.** El equipo conserva la MAC y sigue autorizado 8 h. Para repetir la prueba, en kit01 `sudo nft delete element inet filtro portal_ok { <MAC> }`.

## Evidencia

Captura de la ventana del portal en el celular y del menú después de aceptar; salida de los `curl` antes y después; el set `portal_ok` y las líneas de `portal.log`. La misma captura con la WAN desconectada.
