# Pruebas de aceptación P1-P13

Una guía por prueba, con el criterio del enunciado (sección 8), lo que se dijo en la presentación (diapositiva 38), el paso a paso, los comandos de verificación con su explicación, el resultado esperado y qué guardar como evidencia (E6, `plantillas/evidencia.md`).

| Prueba | Qué demuestra | Dónde | Estado al 2026-11-02 |
|---|---|---|---|
| [P1](P01-cliente.md) | Un cliente de la Comunidad recibe IPv4, IPv6, DNS y gateway | `prueba01`; sitio con celulares | Aprobada en remoto (9 de 9); celulares en cada SSID en la sustentación |
| [P2](P02-dns.md) | Los servicios responden por nombre, A y AAAA, sin escribir IP | `prueba01` y sw01; sitio con un PC de la Interna | Aprobada en remoto (27 y 12) |
| [P3](P03-aislamiento.md) | La Comunidad no llega a lo clínico ni a la administración | `prueba01` y el registro de kit01 | Aprobada en remoto (17 de 17), con la gestión del AP y del switch; aislamiento entre dos celulares en la sustentación |
| [P4](P04-acceso-local.md) | Biblioteca, videos y registro después del portal | `prueba01` | Aprobada en remoto (10 de 10), con un prerregistro por familia |
| [P5](P05-portal.md) | Un cliente nuevo ve el portal | `prueba01`; sitio con un celular | Aprobada en remoto (8 de 8) |
| [P6](P06-clinica.md) | Un usuario del personal registra y consulta un paciente | sw01 y kit01 (`--remoto`); sitio con un PC de la Interna | Aprobada en remoto (16 de 16) |
| [P7](P07-identidad.md) | Un usuario del dominio entra a `archivos` y a Grafana | sw01, clinica01 y NetBird | Aprobada en remoto (8 y 2); montar `archivos` desde un PC en la sustentación |
| [P8](P08-tiempo.md) | Los equipos toman la hora de kit01 | Remoto | Aprobada (9 de 9) |
| [P9](P09-sin-internet.md) | Sin la WAN todo lo local sigue | Corte simulado en remoto; sitio con el cable | Aprobada en remoto (40 de 40); con el cable en la sustentación |
| [P10](P10-firewall-ipv6.md) | Por IPv6 se llega a comunidad01 y no a clinica01 | `prueba01` | Aprobada en remoto (10 de 10) |
| [P11](P11-restauracion.md) | Se borra un archivo y se recupera del disco USB | Remoto | Aprobada (16 de 16) |
| [P12](P12-reinicio.md) | Un equipo se reinicia y todo vuelve solo | Remoto (las VMs) y sitio (kit01) | Aprobada en remoto reiniciando las dos VMs, todo en verde a los 44 s; kit01 en la sustentación |
| [P13](P13-diagnostico.md) | Una falla inducida aparece en Grafana y en los logs | Remoto | Aprobada (tres fallas) |

Las evidencias están en `docs/evidencias/`, con un índice de las trece.

## Scripts

Cada prueba tiene su script en [`scripts/`](scripts/), para no escribir los comandos a mano. Funcionan en Linux y en macOS (bash 3.2) y comparten [`scripts/comun.sh`](scripts/comun.sh). Cada línea sale como `[ OK ]` o `[FALLA]`, el script termina con el conteo y el código de salida es `0` solo si todo salió bien. La salida completa queda en `salidas/<prueba>-<fecha>.txt` (no se versiona); lo que sirve de evidencia se copia a `docs/evidencias/`.

| Dónde se ejecuta | Pruebas | Qué necesita |
|---|---|---|
| En el cliente, conectado al Wi-Fi del kit | P1, P2, P3, P4, P5, P6, P7 (`smb`), P9, P10 | `bash`, `curl` y `ping`; `dig` opcional (en macOS ya viene); `smbclient` en Linux para P7 |
| En `prueba01`, desde la máquina de control | Los mismos scripts de cliente de la Comunidad (P1, P2, P3, P4, P5, P10) | `./scripts/en-prueba01.sh <script> [argumentos]` |
| En la máquina de control, por NetBird | P2 (`--sw01`), P6 (`--remoto`), P7 (`grafana`, `smb-remoto`), P8, P9 (remoto), P11, P12, P13 | El Ansible del kit (`platform/ansible`, con `~/.config/kitsalud/vault-pass` y `ssh-pass`); en macOS, `brew install ansible` y `sshpass` |

```bash
cd docs/pruebas
./scripts/P01-cliente.sh                          # en un cliente del kit
./scripts/en-prueba01.sh P05-portal.sh --aceptar  # en prueba01, como cliente de la Comunidad
./scripts/en-prueba01.sh --apagar                 # al terminar, sin portal y apagada
```

**En remoto.** `en-prueba01.sh` enciende `prueba01` (la VM de kit01 en la red Comunidad), copia `scripts/` y ejecuta ahí el script; la salida queda también en `salidas/` de la máquina de control. `--sin-portal` le quita la autorización del portal para repetir P5 como cliente nuevo. Para la red Interna se usa sw01: P2 con `--sw01` (DNS, ping y HTTP), P6 con `--remoto` (sw01 abre el 443 de clinica01 y el registro del paciente se hace desde kit01 con la raíz del kit) y P7 con `smb-remoto` (sw01 abre el 445 y los usuarios prueban `archivos` en clinica01). Los modos remotos toman las claves del vault y las pasan sin que queden en el syslog de los equipos (`ANSIBLE_NO_TARGET_SYSLOG`).

Los que cambian algo (P11 borra y restaura un archivo, P12 con `reiniciar` reinicia kit01, P13 detiene un servicio) piden confirmación antes. P12 con `vms` reinicia las dos VMs sin preguntar. Los que necesitan contraseñas (P6, P7) las piden y no las guardan.

**Orden sugerido.** En remoto, P5 (`--sin-portal` antes), P1, P4, P3 y P10 en `prueba01`; P2 en `prueba01` y con `--sw01`; P6, P7, P8 y P12; al final `en-prueba01.sh --apagar`. En el sitio, P1, P5, P4, P3 y P10 con celulares en la Comunidad; P6 y P7 con un PC en la Clínica; P9 con el cable; el reinicio de kit01 al final.

**Datos que se usan en todas.**

| Dato | Valor |
|---|---|
| Comunidad (VLAN 40) | `10.20.40.0/24`, gateway `10.20.40.1`; `fd5a:fc7e:d716:40::/64`, gateway `fe80::1` |
| Interna / Clínica (VLAN 10) | `10.20.10.0/24`, gateway `10.20.10.1`; `fd5a:fc7e:d716:10::/64`, gateway `fe80::1` |
| DNS y NTP del kit | `10.20.20.10` y `fd5a:fc7e:d716:20::10` (`ntp.salud.movil`) |
| clinica01 | `10.20.20.11`, `fd5a:fc7e:d716:20::11` (`pacientes`, `consultas`, `archivos`) |
| comunidad01 | `10.20.20.12`, `fd5a:fc7e:d716:20::12` (`biblioteca`, `videos`, `registro`, `ca`) |
| kit01 por NetBird | `100.90.225.113`, usuario `kitsalud` |
| Usuarios del dominio | `ana.rojas` y `carlos.perez` (`clinicos`), `laura.gomez` (`admins`) |

**Entrar a una VM desde la laptop.** `ssh -J kitsalud@100.90.225.113 kitsalud@10.20.20.11` (clinica01) o `...@10.20.20.12` (comunidad01). Las VMs solo aceptan SSH desde kit01.

**Antes de empezar en el sitio.** Comentar las líneas de `salud.movil` en `/etc/hosts` de la laptop (`sudo sed -i '/salud\.movil/s/^/#/' /etc/hosts`). Si no, los nombres del kit apuntan a `127.0.0.1` y nada abre.
