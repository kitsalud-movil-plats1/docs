<img src="../assets/logo-icesi.png" alt="Universidad Icesi" class="logo" width="160">

# Kit móvil de atención primaria en salud

## Guía de despliegue

**Proyecto final - Plataformas I - 2026-2** · Organización `kitsalud-movil-plats1`

Esta guía lleva el kit desde equipos recién sacados de la caja hasta todos sus servicios funcionando, y explica cómo reconstruir una máquina virtual cuando se pierde. Está escrita para un administrador que conoce Linux y no participó en la instalación. Casi todo lo hace Ansible desde una máquina de control, así que la guía dice qué ejecutar, en qué orden, por qué ese orden y cómo comprobar cada paso antes de seguir. Cada parte trae los paquetes que instala, los servicios que quedan activos y los archivos de configuración que escribe.

| Parte | Para qué |
|---|---|
| [Preparación](preparacion.md) | Dejar lista la máquina de control con Ansible, los repositorios y los secretos |
| [Equipos de red](red-fisica.md) | Conectar los equipos y configurar el switch y el punto de acceso |
| [kit01](kit01.md) | Instalar Ubuntu en el mini PC y desplegar la red, el firewall y los servicios del host |
| [Máquinas virtuales](maquinas-virtuales.md) | Crear clinica01 y comunidad01 y desplegar sus aplicaciones, la publicación, las copias y el monitoreo |
| [Orden de inicio](orden-de-inicio.md) | Qué arranca primero cuando se enciende el kit y de qué depende cada servicio |
| [Comprobación final](verificacion.md) | Confirmar que el kit quedó completo y resolver los errores más comunes del despliegue |
| [Reconstruir una máquina virtual](reconstruir-vm.md) | Volver a crear una VM desde cero, con el resultado de haberlo hecho en el kit |

## Las fases del despliegue

PENDIENTE diagrama de fases

## El kit en pocas palabras

| Equipo | Qué es | Dirección |
|---|---|---|
| kit01 | Mini PC Beelink EQi12 que hace de router, firewall, DNS, DHCP, hora, portal cautivo, logs, monitoreo y copias, y donde corren las dos máquinas virtuales | `10.20.10.1` desde la red Interna, `100.90.225.113` por NetBird |
| clinica01 | Máquina virtual con la historia clínica (DHIS2) y su base de datos, el dominio de usuarios, los archivos compartidos y la consulta de prerregistros | `10.20.20.11` y `fd5a:fc7e:d716:20::11` |
| comunidad01 | Máquina virtual con la biblioteca, los videos y el formulario de prerregistro | `10.20.20.12` y `fd5a:fc7e:d716:20::12` |
| sw01 | Switch MikroTik CCR2004 que separa la red Interna y la Comunidad | `10.20.10.2` |
| ap01 | Punto de acceso TP-Link TL-WA801ND con un Wi-Fi para cada red | `10.20.10.3` |
