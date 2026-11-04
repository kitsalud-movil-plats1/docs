# Gestión de usuarios

Este procedimiento explica cómo dar y quitar acceso a las personas de la brigada. El kit tiene dos tipos de cuentas personales. Las del dominio sirven para los archivos compartidos, la consulta de prerregistros y el monitoreo. Las de DHIS2 sirven para la historia clínica. Además hay cuentas de servicio que no son de personas.

| Cuenta | Para qué sirve | Dónde se gestiona |
|---|---|---|
| Del dominio (`SALUD\<usuario>`) | Recurso `archivos` y consulta de prerregistros para el grupo `clinicos`, recurso `contenido` para `clinicos` y `admins`, monitoreo (Grafana) solo para `admins` | En clinica01, con `samba-tool` o con Ansible |
| De DHIS2 | Registro y consulta de pacientes, con el rol "Personal clínico" o "Administrador" | En DHIS2, con la app Usuarios, la API o Ansible |
| `comunidad` de Jellyfin | Ver los videos, sin contraseña | No se cambia |
| `admin` de Jellyfin | Administrar los videos, solo desde la red Interna | Página de Jellyfin |
| Administración del kit | SSH y `sudo` en kit01, clinica01 y comunidad01 | En cada equipo, con `passwd`, y en el vault de Ansible |

Las cuentas del dominio y las de DHIS2 tienen el mismo nombre para cada persona (por ejemplo `ana.rojas`) y son independientes. Una persona nueva del personal clínico necesita las dos.

**Contraseñas.** El kit usa contraseñas académicas conocidas por el grupo. En el dominio la convención es `password`, porque la política pide 8 caracteres sin complejidad. DHIS2 exige mayúscula, número y símbolo y rechaza palabras genéricas, así que usa `Clave123!`. Antes de una misión real se cambian todas.

## Personas permanentes, con Ansible

Las personas que van a estar en todas las misiones se agregan al inventario de Ansible, desde la máquina de control, en `platform/ansible`. Así quedan con el mismo número de usuario si el dominio se reconstruye y se restaura una copia, y los archivos conservan su dueño.

1. Agregar la persona a `inventarios/kit/group_vars/all/samba.yml`, en `samba_usuarios`, con el siguiente `uid` libre (los usados empiezan en 10101) y sus grupos. El primer grupo es su grupo principal.

   ```yaml
   - { nombre: maria.lopez, nombres: Maria, apellidos: Lopez, uid: 10104, grupos: [clinicos] }
   ```

2. Agregarla a `inventarios/kit/group_vars/all/dhis2.yml`, en `dhis2_usuarios`, con el rol `RolPersCli1` ("Personal clínico") o `RolAdmiKit1` ("Administrador").
3. Aplicar.

   ```bash
   ansible-playbook playbooks/samba.yml
   ansible-playbook playbooks/clinica01.yml
   ```

Las dos cuentas nuevas quedan con la contraseña de la convención. Los playbooks solo crean lo que falta. No cambian la contraseña de una cuenta que ya existe ni borran las que se quitan del inventario, así que esas dos cosas se hacen a mano con los comandos de abajo.

## Usuarios del dominio, en clinica01

En campo, sin la máquina de control, las cuentas se gestionan en clinica01 con `samba-tool`. Una cuenta creada así se agrega después al inventario, con el mismo `uid`, para que no se pierda si el dominio se reconstruye.

```bash
ssh -J <usuario>@10.20.10.1 <usuario>@10.20.20.11
```

| Qué | Comando |
|---|---|
| Ver las cuentas y los grupos | `sudo samba-tool user list` y `sudo samba-tool group listmembers clinicos` |
| Ver los `uid` usados | `for u in $(sudo samba-tool user list); do sudo samba-tool user show $u --attributes=uidNumber; done \| grep uidNumber` |
| Crear una cuenta | `sudo samba-tool user create maria.lopez --given-name=Maria --surname=Lopez` (pide la contraseña) |
| Darle su número de usuario y su grupo principal | `sudo samba-tool user addunixattrs maria.lopez 10104 --gid-number=10001` (10001 es `clinicos` y 10002 es `admins`) |
| Agregarla a un grupo | `sudo samba-tool group addmembers clinicos maria.lopez` y después `sudo net cache flush` |
| Quitarla de un grupo | `sudo samba-tool group removemembers clinicos maria.lopez` y `sudo net cache flush` |
| Cambiar la contraseña | `sudo samba-tool user setpassword maria.lopez` (pide la nueva) |
| Deshabilitar o volver a habilitar | `sudo samba-tool user disable maria.lopez` y `sudo samba-tool user enable maria.lopez` |
| Ver si está bloqueada | `sudo samba-tool user show maria.lopez --attributes=badPwdCount,lockoutTime` |
| Desbloquear | `sudo samba-tool user unlock maria.lopez` |
| Borrar | `sudo samba-tool user delete maria.lopez` |

**Bloqueo.** Después de 5 contraseñas equivocadas la cuenta se bloquea por 15 minutos y se desbloquea sola. `unlock` la libera antes.

**Contraseña anterior.** Después de un cambio, la contraseña anterior sigue sirviendo hasta una hora para entrar a los recursos compartidos, igual que en un dominio de Windows. Para cortar el acceso de inmediato se deshabilita la cuenta.

**Archivos de una cuenta borrada.** Quedan en el recurso con el número de usuario como dueño. Si se crea otra cuenta con el mismo `uid`, esa cuenta pasa a ser la dueña.

**Cómo comprobar el acceso.** En clinica01, con la contraseña en la variable `PASSWD` para que no quede en el historial.

```bash
read -rs PASSWD; export PASSWD
smbclient //archivos.salud.movil/archivos -I 10.20.20.11 -U 'SALUD\maria.lopez' -m SMB3 -c ls
smbclient //archivos.salud.movil/archivos -I fd5a:fc7e:d716:20::11 -U 'SALUD\maria.lopez' -m SMB3 -c ls
unset PASSWD
```

Una cuenta de `clinicos` lista el recurso. Una deshabilitada responde `NT_STATUS_ACCOUNT_DISABLED`, una bloqueada `NT_STATUS_ACCOUNT_LOCKED_OUT` y una que no es de `clinicos` `NT_STATUS_ACCESS_DENIED`. Para la consulta de prerregistros y el monitoreo, la persona entra en `https://consultas.salud.movil` o `https://monitoreo.salud.movil` desde la red Interna.

## Cuentas de DHIS2

En `https://pacientes.salud.movil`, con una cuenta de rol "Administrador", se abre la app **Users**. La interfaz de DHIS2 está en inglés, así que los botones se nombran como aparecen en pantalla.

1. **Crear.** Botón **+**. Se llenan nombre, apellido, usuario y contraseña. En **Roles** va "Personal clínico" (o "Administrador"), en las tres listas de **Organisation units** la unidad del kit, y en **User groups** "Personal clínico". Sin el grupo, la persona entra pero no ve los datos de pacientes.
2. **Cambiar la contraseña.** En la lista, menú de la cuenta, **Edit**, con la nueva contraseña.
3. **Deshabilitar.** Menú de la cuenta, **Disable**. La cuenta no puede entrar, y sus registros siguen en la historia clínica.
4. **Borrar.** Menú de la cuenta, **Delete**. Es preferible deshabilitar, porque así queda claro quién hizo cada registro.

**Cómo comprobar el acceso.** La persona entra en `https://pacientes.salud.movil` y abre la app Capture. Por la API, desde un equipo de la red Interna, con la raíz del kit (pide la contraseña),

```bash
curl -s -o raiz.crt http://ca.salud.movil/raiz.crt
curl -s --cacert raiz.crt -u maria.lopez 'https://pacientes.salud.movil/api/me?fields=username,userRoles%5Bname%5D,userGroups%5Bname%5D'
```

responde con el usuario, el rol "Personal clínico" y el grupo "Personal clínico". Una cuenta deshabilitada responde `401`.

## Monitoreo, videos y administración del kit

- **Monitoreo (Grafana).** Entra quien está en el grupo `admins` del dominio, con su usuario y contraseña del dominio. Para dar acceso, se agrega la persona a `admins`. Si el dominio no responde, se entra con la cuenta local `admin` de Grafana.
- **Videos (Jellyfin).** La comunidad entra con el usuario `comunidad`, sin contraseña. La cuenta `admin` solo funciona desde la red Interna y la administración por NetBird, y su contraseña se cambia en la página de Jellyfin, en **Panel de control**, **Usuarios**.
- **Administración del kit.** Es un solo usuario con `sudo` en kit01, clinica01 y comunidad01. Para cambiar su contraseña se ejecuta `passwd` en cada uno de los tres equipos, y después se actualizan las dos entradas del vault de Ansible (`vault_admin_password` y su hash `vault_admin_password_hash`, generado con `mkpasswd -m sha-512`) con `ansible-vault edit`. Ansible no la cambia en los equipos, y sin actualizar el vault deja de poder conectarse.

## Prueba hecha en el kit

El 4 de noviembre de 2026 se creó una cuenta temporal en cada sistema y se borró al terminar.

| Paso | Resultado |
|---|---|
| Crear `prueba.operacion` en el dominio con `uid` 10199, grupo principal `clinicos` | Creada, con `uidNumber`, `gidNumber` y el grupo |
| Recurso `archivos` por IPv4 y por IPv6 | Lista el recurso en las dos familias |
| Consulta de prerregistros por IPv4 y por IPv6 | Entra (`302` hacia la lista) |
| Monitoreo por IPv4 y por IPv6 | `401`, porque no es de `admins` |
| Deshabilitar y volver a habilitar | `NT_STATUS_ACCOUNT_DISABLED` y después entra |
| Cambiar la contraseña | Entra con la nueva, y con la anterior todavía, por la hora de gracia |
| 5 contraseñas equivocadas | `NT_STATUS_ACCOUNT_LOCKED_OUT`, `badPwdCount` en 5 |
| Desbloquear | Entra |
| Borrar | No queda ninguna cuenta con ese nombre |
| Crear la cuenta de DHIS2 por la API, por IPv4 y por IPv6 | Entra con el rol y el grupo "Personal clínico" |
| Deshabilitar la cuenta de DHIS2 | `401` al entrar |
| Borrar la cuenta de DHIS2 | No queda ninguna cuenta con ese nombre |
