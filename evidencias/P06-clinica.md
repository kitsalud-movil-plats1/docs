# P6 - Aplicación clínica

**Entorno.** Kit real, en remoto por NetBird

## Qué se prueba

Un usuario autorizado accede al sistema de pacientes y registra o consulta un dato.

**Cómo se probó.** Con `./scripts/P06-clinica.sh --remoto VT6Y KMUJ`, desde la máquina de control. Primero sw01, el switch del kit, que tiene su gestión en la red Interna, abre el puerto 443 de `clinica01` en IPv4 y en IPv6, lo que muestra que la red Interna llega a la historia clínica. El cliente HTTP de sw01 no completa el TLS del servidor web de `clinica01`, así que el registro y la consulta se hicieron desde kit01 con `curl`, con la raíz de la CA del kit para verificar el certificado y las claves tomadas del almacén cifrado del kit, sin escribirlas en ningún archivo ni registro. En cada familia, `ana.rojas` (personal clínico) inicia sesión en DHIS2, registra un paciente ficticio con su inscripción en el programa "Atención primaria", `carlos.perez` lo busca por su documento y al final el administrador lo borra. Después `ana.rojas` entra con su usuario del dominio a la consulta de prerregistros y busca los dos códigos enviados desde la red Comunidad (`VT6Y` y `KMUJ`).

## Comandos y salida

```
== P06 - Aplicación clínica

## Desde la Interna (sw01) hacia clinica01
  [ OK ]  sw01 abre 10.20.20.11 puerto 443 (Caddy responde: failure: Fetch failed with status 400)
  [ OK ]  sw01 abre [fd5a:fc7e:d716:20::11] puerto 443 (Caddy responde: failure: Fetch failed with status 400)

## DHIS2 por IPv4 (desde kit01)
  [ OK ]  ana.rojas inicia sesión; roles Personal clínico
  [ OK ]  ana.rojas registra un paciente ficticio (P6GevAUMI4c, documento P6-4-1793934828) e inscripción en Atención primaria
  [ OK ]  carlos.perez lo encuentra por documento (Prueba P6 IPv4 P6-4-1793934828)
  [ OK ]  Paciente de prueba borrado

## DHIS2 por IPv6 (desde kit01)
  [ OK ]  ana.rojas inicia sesión; roles Personal clínico
  [ OK ]  ana.rojas registra un paciente ficticio (P6uQtbaHfe1, documento P6-6-1793934829) e inscripción en Atención primaria
  [ OK ]  carlos.perez lo encuentra por documento (Prueba P6 IPv6 P6-6-1793934829)
  [ OK ]  Paciente de prueba borrado

## Consulta de prerregistros por IPv4 (desde kit01)
  [ OK ]  ana.rojas entra con su usuario del dominio (302)
  [ OK ]  El prerregistro VT6Y aparece en la consulta
  [ OK ]  El prerregistro KMUJ aparece en la consulta

## Consulta de prerregistros por IPv6 (desde kit01)
  [ OK ]  ana.rojas entra con su usuario del dominio (302)
  [ OK ]  El prerregistro VT6Y aparece en la consulta
  [ OK ]  El prerregistro KMUJ aparece en la consulta
          Desde un PC de la Interna se registra un paciente en el navegador en la sustentación

Resultado: 16 bien y 0 con falla.
```

### IPv4

Por `10.20.20.11`, `ana.rojas` inició sesión con el rol "Personal clínico", registró al paciente `P6GevAUMI4c` y `carlos.perez` lo encontró con sus datos. En la consulta de prerregistros, `ana.rojas` entró con su contraseña del dominio y encontró los dos códigos.

### IPv6

Por `fd5a:fc7e:d716:20::11` se repitió lo mismo con el paciente `P6uQtbaHfe1`. sw01 abrió también el 443 por IPv6 y Caddy respondió.

## Interpretación

El personal clínico registra y consulta pacientes en DHIS2 con su propia cuenta y su rol, en las dos familias, y lo que registra una persona lo encuentra otra del mismo grupo porque los datos del programa están compartidos con "Personal clínico". La consulta de prerregistros usa el directorio del kit, así que la misma persona entra con su usuario del dominio y ve lo que la comunidad envió desde el formulario. Todo se hizo por HTTPS con el certificado verificado contra la raíz del kit. Los dos pacientes de prueba se borraron al final.

## Resultado

Aprobada. 16 comprobaciones bien y ninguna falla. En la sustentación se repite desde un PC de la red Interna, registrando un paciente en el navegador.
