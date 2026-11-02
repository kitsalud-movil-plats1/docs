# Evidencias de las pruebas P1-P13

Resultados de las trece pruebas de aceptación del kit, cada una con los comandos, la salida real y su interpretación, en IPv4 y en IPv6. Todas se hicieron en el kit real, en remoto por el acceso de administración (NetBird), con dos equipos que hacen de clientes.

- **`prueba01`** es una máquina virtual de kit01 conectada al puente de la red Comunidad (VLAN 40), la misma red que el SSID abierto `SaludMovil-Comunidad`. Recibe su configuración por DHCPv4 y por los anuncios de IPv6, igual que un celular, y pasa por el portal cautivo.
- **sw01**, el switch del kit, tiene su gestión en la red Interna (VLAN 10), la misma red que el SSID `SaludMovil-Clinica`. Hace las pruebas de la red Interna que RouterOS permite (DNS, ping, conexiones TCP y HTTP).

Lo que solo se ve en el sitio (celulares en cada SSID, el aislamiento entre dos clientes Wi-Fi, un PC de la red Interna, el cable de Internet desconectado y el reinicio de kit01) se demuestra en vivo en la sustentación con los mismos scripts.

| Prueba | Qué demuestra | Cómo se probó | Resultado |
|---|---|---|---|
| [P1](P01-cliente.md) | Un cliente de la Comunidad recibe IPv4, IPv6, DNS y gateway | `prueba01` | Aprobada, 9 de 9 |
| [P2](P02-dns.md) | Los servicios se encuentran por nombre con registros A y AAAA, y hay conectividad extremo a extremo | `prueba01` y sw01 | Aprobada, 39 de 39 |
| [P3](P03-aislamiento.md) | Un invitado no llega a lo clínico ni a la administración, y el intento queda registrado | `prueba01` y el registro de kit01 | Aprobada, 17 de 17 |
| [P4](P04-acceso-local.md) | Un invitado usa la biblioteca, los videos y el formulario de prerregistro | `prueba01` y la base de `clinica01` | Aprobada, 10 de 10 |
| [P5](P05-portal.md) | Un cliente nuevo va al portal cautivo y pasa al aceptar | `prueba01` y kit01 | Aprobada, 8 de 8 |
| [P6](P06-clinica.md) | El personal clínico registra y consulta un paciente | sw01 y kit01 | Aprobada, 16 de 16 |
| [P7](P07-identidad.md) | Los usuarios del directorio entran a los recursos de su grupo | sw01, `clinica01` y la consola de monitoreo | Aprobada, 10 de 10 |
| [P8](P08-tiempo.md) | Los equipos toman la hora de kit01 | VMs, sw01 y `prueba01` | Aprobada, 9 de 9 |
| [P9](P09-sin-internet.md) | Sin Internet todo lo local sigue funcionando | Corte simulado en kit01, con `prueba01` y sw01 | Aprobada, 40 de 40 |
| [P10](P10-firewall-ipv6.md) | Por IPv6 se permite lo público y se bloquea lo clínico | `prueba01` y el registro de kit01 | Aprobada, 10 de 10 |
| [P11](P11-restauracion.md) | Un archivo y una tabla se recuperan de la copia | Kit real y disco USB | Aprobada, 16 de 16 |
| [P12](P12-reinicio.md) | Los servicios vuelven solos después de un reinicio | Reinicio de las dos VMs | Aprobada, 47 de 47, todo en verde a los 44 s |
| [P13](P13-diagnostico.md) | Una falla se detecta y se localiza con el monitoreo y los registros | Tres fallas inducidas | Aprobada, 6 de 6 |

Los scripts dejan la salida completa en `pruebas/salidas/` del equipo que los ejecuta. En cada evidencia está la salida tal como la dio el script, salvo la ruta de ese archivo.
