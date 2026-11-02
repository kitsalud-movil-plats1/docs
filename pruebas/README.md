# Pruebas de aceptación P1-P13

Una guía por prueba, con el criterio del enunciado (sección 8), lo que se dijo en la presentación (diapositiva 38), el paso a paso, los comandos de verificación con su explicación, el resultado esperado y qué guardar como evidencia (E6, `plantillas/evidencia.md`).

| Prueba | Qué demuestra | Dónde | Estado al 2026-10-30 |
|---|---|---|---|
| [P1](P01-cliente.md) | Un cliente de la Comunidad recibe IPv4, IPv6, DNS y gateway | Sitio (celular o PC) | IPv4 y portal bien en iPhone y laptop; IPv6 en iPhone; la laptop de Melo no recibe IPv6 por Wi-Fi (usar otro PC) |
| [P2](P02-dns.md) | Los servicios responden por nombre, A y AAAA, sin escribir IP | Sitio (Interna) o remoto | Pendiente de evidencia |
| [P3](P03-aislamiento.md) | La Comunidad no llega a pacientes ni al SSH de kit01 | Sitio (Comunidad) | `curl -4` a pacientes bloqueado; falta IPv6 y el log |
| [P4](P04-acceso-local.md) | Biblioteca, videos y registro después del portal | Sitio (Comunidad) | Biblioteca por IPv4 bien; falta videos y registro |
| [P5](P05-portal.md) | Un cliente nuevo ve el portal, también sin Internet | Sitio (Comunidad) | Bien en iPhone; Fedora necesita abrir el portal a mano; falta sin Internet (con P9) |
| [P6](P06-clinica.md) | Un usuario del personal registra y consulta un paciente | Sitio (Clínica) | Pendiente |
| [P7](P07-identidad.md) | Un usuario del dominio entra a `archivos` y a Grafana | Sitio y NetBird | `archivos` con `ana.rojas` bien (SMB 3.1.1 cifrado); falta Grafana |
| [P8](P08-tiempo.md) | Los equipos toman la hora de kit01 | Remoto y una estación | Pendiente de evidencia |
| [P9](P09-sin-internet.md) | Sin la WAN todo lo local sigue | Sitio | Pendiente |
| [P10](P10-firewall-ipv6.md) | Por IPv6 se llega a comunidad01 y no a clinica01 | Sitio (otro PC) o prueba01 | Verificado con prueba01; falta un cliente real |
| [P11](P11-restauracion.md) | Se borra un archivo y se recupera del disco USB | Remoto | `prueba-p11.txt` listo en `archivos`; primera copia hecha |
| [P12](P12-reinicio.md) | kit01 se reinicia y todo vuelve solo | Sitio (alguien presente) | Pendiente, al final |
| [P13](P13-diagnostico.md) | Una falla inducida aparece en Grafana y en los logs | Remoto | Pendiente de evidencia |

## Scripts

Cada prueba tiene su script en [`scripts/`](scripts/), para no escribir los comandos a mano. Funcionan en Linux y en macOS (bash 3.2) y comparten [`scripts/comun.sh`](scripts/comun.sh). Cada línea sale como `[ OK ]` o `[FALLA]`, el script termina con el conteo y el código de salida es `0` solo si todo salió bien. La salida completa queda en `salidas/<prueba>-<fecha>.txt` (no se versiona); lo que sirve de evidencia se copia a `docs/evidencias/`.

| Dónde se ejecuta | Pruebas | Qué necesita |
|---|---|---|
| En el cliente, conectado al Wi-Fi del kit | P1, P2, P3, P4, P5, P6, P7 (`smb`), P9, P10 | `bash`, `curl` y `ping`; `dig` opcional (en macOS ya viene); `smbclient` en Linux para P7 |
| En la máquina de control, por NetBird | P7 (`grafana`), P8, P11, P12, P13 | El Ansible del kit (`platform/ansible`, con `~/.config/kitsalud/vault-pass` y `ssh-pass`); en macOS, `brew install ansible` y `sshpass` |

```bash
cd docs/pruebas
./scripts/P01-cliente.sh          # por ejemplo
```

Los que cambian algo (P11 borra y restaura un archivo, P12 reinicia kit01, P13 detiene un servicio) piden confirmación antes. Los que necesitan contraseñas (P6, P7) las piden y no las guardan.

**Orden sugerido en el sitio.** P1, P5, P4, P3 y P10 en la Comunidad; P6 y P7 en la Clínica; P9; P12 al final. P2, P8, P11 y P13 se pueden hacer en remoto.

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
