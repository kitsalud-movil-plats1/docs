<img src="../assets/logo-icesi.png" alt="Universidad Icesi" class="logo" width="160">

# Kit móvil de atención primaria en salud

## Guía de operación

**Proyecto final - Plataformas I - 2026-2** · Organización `kitsalud-movil-plats1`

Esta guía reúne los procedimientos para operar el kit en una misión, desde encenderlo hasta apagarlo, pasando por la revisión diaria, la gestión de las cuentas, los logs, la actualización, el trabajo sin Internet y el cambio de perfil. Está escrita para cualquier integrante de la brigada con el usuario de administración del kit, aunque no lo haya instalado. Cada procedimiento trae los comandos para comprobar que funcionó y el resultado de haberlo probado en el kit real.

| Procedimiento | Para qué |
|---|---|
| [Inicio y apagado](inicio-y-apagado.md) | Encender el kit, apagarlo en orden sin dañar los datos y practicar el corte de energía |
| [Revisión rápida](revision-rapida.md) | Saber en pocos minutos si el kit está bien y, si algo falla, encontrar qué es por el síntoma |
| [Gestión de usuarios](usuarios.md) | Dar, cambiar y quitar acceso en el dominio, en DHIS2 y en la administración del kit |
| [Revisión de logs](logs.md) | Encontrar inicios de sesión fallidos, bloqueos del firewall, direcciones entregadas y consultas al DNS |
| [Actualización](actualizacion.md) | Actualizar paquetes e imágenes en la base, con copia e instantáneas antes |
| [Operación sin Internet](sin-internet.md) | Saber qué sigue funcionando, administrar el kit sin acceso remoto y qué revisar cuando vuelve la conexión |
| [Cambio de perfil por misión](perfiles.md) | Encender solo lo que la misión necesita y volver al perfil de referencia |

## El kit en pocas palabras

| Equipo | Qué es | Dirección |
|---|---|---|
| kit01 | Mini PC que hace de router, firewall, DNS, DHCP, hora, portal cautivo y monitoreo, y donde corren las dos máquinas virtuales | `10.20.10.1` desde la red Interna, `100.90.225.113` por NetBird |
| clinica01 | Historia clínica (DHIS2) con su base de datos, dominio de usuarios, archivos compartidos y consulta de prerregistros | `10.20.20.11` y `fd5a:fc7e:d716:20::11` |
| comunidad01 | Biblioteca, videos y formulario de prerregistro | `10.20.20.12` y `fd5a:fc7e:d716:20::12` |
| sw01 | Switch MikroTik que separa la red Interna y la Comunidad | `10.20.10.2` |
| ap01 | Punto de acceso TP-Link con un Wi-Fi para cada red (`SaludMovil-Clinica` y `SaludMovil-Comunidad`) | `10.20.10.3` |

| Servicio | Dirección |
|---|---|
| Historia clínica (DHIS2) | `https://pacientes.salud.movil` |
| Consulta de prerregistros | `https://consultas.salud.movil` |
| Archivos compartidos | `\\archivos.salud.movil\archivos` y `\\archivos.salud.movil\contenido` |
| Monitoreo (Grafana) | `https://monitoreo.salud.movil` |
| Biblioteca | `http://biblioteca.salud.movil` |
| Videos | `http://videos.salud.movil` |
| Formulario de prerregistro | `https://registro.salud.movil` |
| Raíz de certificados del kit | `http://ca.salud.movil/raiz.crt` |

A clinica01 y comunidad01 se entra por SSH saltando por kit01 (`ssh -J <usuario>@10.20.10.1 <usuario>@10.20.20.11`), porque solo aceptan SSH desde kit01.
