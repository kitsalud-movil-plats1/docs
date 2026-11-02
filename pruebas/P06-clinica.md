# P6 - Aplicación clínica

## Qué se prueba

**Enunciado.** Un usuario autorizado accede al sistema de pacientes y registra o consulta un dato.
**Presentación.** Se registra y consulta un paciente ficticio.

DHIS2 2.42 en clinica01, publicado por Caddy en `https://pacientes.salud.movil` solo para la Interna (F-05). Las cuentas del personal son locales de DHIS2: `ana.rojas` y `carlos.perez` (Personal clínico) y `laura.gomez` (Administrador).

## Qué necesitas

Un PC o celular en `SaludMovil-Clinica`, con la raíz del kit instalada (`http://ca.salud.movil`), y la contraseña de las cuentas del personal en DHIS2.

## Paso a paso

1. Conectarse a la Clínica y abrir `https://pacientes.salud.movil`.
2. Entrar con `ana.rojas`.
3. Abrir **Capture** → la unidad del kit → el programa de atención primaria → **Registrar** un paciente ficticio (nombre, documento inventado, fecha de nacimiento) y guardar un evento de consulta.
4. Cerrar la sesión, entrar con `carlos.perez` y **buscar** al paciente por nombre o documento.
5. Opcional, unir con P4. Abrir `https://consultas.salud.movil` y marcar como atendido el prerregistro de la Comunidad.

## Con el script

Se ejecuta en un cliente de la Clínica, desde `docs/pruebas/`.

```bash
./scripts/P06-clinica.sh [usuario]
```

Revisa que DHIS2 y la consulta de prerregistros responden en IPv4 e IPv6 con el certificado del kit y que la cuenta (por defecto `ana.rojas`) inicia sesión por la API y tiene su rol. Pide la contraseña y no la guarda. El registro y la búsqueda del paciente se hacen en el navegador. Cada línea sale como `[ OK ]` o `[FALLA]` y todo queda en `salidas/P06-<fecha>.txt`, que sirve de evidencia. Los comandos de abajo son los que usa el script, para ejecutarlos a mano o explicarlos.

## Comandos de verificación

| Comando | Qué muestra | Esperado |
|---|---|---|
| `curl -4 -I https://pacientes.salud.movil` y `curl -6 -I ...` | Que DHIS2 responde por las dos familias con el certificado del kit | `200` o `302` hacia el login |
| `curl -s -u ana.rojas:<clave> "https://pacientes.salud.movil/api/me?fields=username,userRoles[name]"` | Que la cuenta existe y su rol | `"username":"ana.rojas"`, rol Personal clínico |
| `curl -s -u carlos.perez:<clave> "https://pacientes.salud.movil/api/trackedEntities?program=ProgAtenPr1&orgUnits=KitSalud001&filter=<atributo>:like:<nombre>"` | Que el paciente registrado se encuentra con otra cuenta | El paciente aparece |
| Desde la Comunidad, `curl -k -m 5 https://pacientes.salud.movil` | Que solo la Interna llega | Timeout (es P3) |

`/api/me` es la API de DHIS2 que devuelve la cuenta con la que se autentica. La búsqueda por API es opcional; la interfaz basta como evidencia.

**En clinica01 (remoto).** `docker ps` muestra `dhis2-core-1` y `dhis2-db-1` en `healthy`; `docker logs --since 10m dhis2-core-1` muestra la creación del evento.

**macOS.** Igual en Safari o Chrome, con la raíz del kit instalada (ver P4). Los `curl` son iguales.

## Si algo falla

- **No abre.** Revisar que el equipo esté en la Clínica (`10.20.10.x`) y que la raíz esté instalada. En Grafana, **Estado del kit** dice si la sonda de `pacientes` está en rojo.
- **"Invalid login".** Tras 5 intentos fallidos DHIS2 bloquea la cuenta unos minutos.

## Evidencia

Capturas del registro y de la búsqueda con la otra cuenta; salida de los `curl` IPv4 e IPv6.
