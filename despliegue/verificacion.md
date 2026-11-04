# Comprobación final

Con todos los playbooks aplicados, estas comprobaciones confirman que el kit quedó completo. Todas se hacen en remoto desde la máquina de control, en `kitsalud/platform/ansible`, y cada una dice qué resultado esperar.

## 1. Ansible no tiene nada pendiente

Una segunda ejecución de cualquier playbook termina con `changed=0`, porque todos son idempotentes. Los de kit01 se pueden revisar con `--check --diff`, que no cambia nada.

```bash
for p in comun kit01 red-kit01 dns ntp dhcp portal registros ca nut vms samba publicacion backups; do
  ansible-playbook playbooks/$p.yml --check --diff -l '!pruebas' | grep -A5 'PLAY RECAP'
done
```

Los roles de las aplicaciones y de Grafana (`clinica01.yml`, `comunidad01.yml` y `monitoreo.yml`) consultan las API de DHIS2, Jellyfin y Grafana para decidir qué cambiar, y en `--check` esas consultas no se hacen, así que se detienen con `object of type 'dict' has no attribute`. Esos tres se comprueban con una ejecución normal, que también tiene que terminar en `changed=0`.

**Resultado en el kit (4 de noviembre de 2026).** Los 14 playbooks de la lista terminaron en `changed=0` en los tres equipos, salvo `portal.yml`. PENDIENTE portal.

## 2. Todos los servicios en verde

Prometheus prueba cada servicio por IPv4 y por IPv6. Ninguna sonda debe estar en rojo y ningún equipo caído.

```bash
ansible kit01 -m shell -a "curl -s -G --data-urlencode 'query=probe_success == 0 or up == 0' http://127.0.0.1:9090/api/v1/query"
```

Responde `"result":[]`. En el navegador, `https://monitoreo.salud.movil` muestra el panel **Estado del kit** con **Problemas ahora** en 0. El 2026-11-04 había 44 objetivos, 39 de ellos sondas, todos en verde.

## 3. Los flujos del firewall

`verificar-flujos.yml` prueba cada flujo permitido y bloqueado desde su origen real (kit01, las dos VMs, `prueba01` como cliente de la Comunidad, antes y después de aceptar el portal, y sw01 como equipo de la Interna), en IPv4 e IPv6. Enciende `prueba01` y la apaga al final.

```bash
ansible-playbook playbooks/verificar-flujos.yml
```

Termina con `69 pruebas, todas como se esperaba`, y los contadores de los bloqueos coinciden con las líneas del log.

## 4. Switch y punto de acceso

```bash
# sw01: la configuración aplicada es la del repositorio (salvo la fecha del encabezado)
ssh -J kitsalud@<ip-netbird-de-kit01> admin@10.20.10.2 '/export terse' | tr -d '\r' > /tmp/sw01.rsc
diff <(grep -v '^#' ../../network/switch/sw01.rsc) <(grep -v '^#' /tmp/sw01.rsc)
# ap01: lee su interfaz web desde kit01 sin cambiar nada
(cd ../../network && ./ap/revisar-ap.sh)
```

`diff` no muestra diferencias y `revisar-ap.sh` termina con `17 bien y 0 con falla`.

## 5. La primera copia

Con el disco USB conectado a kit01 se lanza la primera copia a mano, sin esperar al domingo.

```bash
ansible kit01 -b -m shell -a 'systemctl start backup.service; systemctl show -p Result --value backup.service'
```

Responde `success`. `journalctl -u backup -o cat | tail` muestra los cuatro snapshots (`config`, `recursos`, `bd` y `dominio`) y `restic check` sin errores.

## 6. Los servicios por su nombre

Cada nombre del kit tiene que responder en las dos familias. kit01 resuelve con los DNS del sitio, que no conocen `salud.movil`, así que la prueba pregunta a BIND9, sale con las direcciones de kit01 en la Interna y valida HTTPS con la raíz de la CA del kit.

```bash
ssh kitsalud@<ip-netbird-de-kit01> 'bash -s' <<'FIN'
for n in pacientes consultas registro monitoreo biblioteca videos ca; do
  case $n in biblioteca|videos|ca) u=http p=80;; *) u=https p=443;; esac
  for f in 4 6; do
    if [ $f = 4 ]; then o=10.20.10.1; ip=$(dig +short -b $o @10.20.20.10 $n.salud.movil A)
    else o=fd5a:fc7e:d716:10::1; ip="[$(dig +short -b $o @fd5a:fc7e:d716:20::10 $n.salud.movil AAAA)]"; fi
    echo "$n v$f $(curl -s -o /dev/null -w %{http_code} --interface $o --cacert /etc/prometheus/ca-kit.crt \
      --resolve $n.salud.movil:$p:$ip $u://$n.salud.movil/)"
  done
done
FIN
```

Cada línea termina en `200` o en `302`, que es la redirección a la página de inicio de sesión del servicio. El 2026-11-04 respondieron así las 14.

## Errores comunes del despliegue

| Síntoma | Causa | Solución |
|---|---|---|
| `The vault password file ... was not found` | Falta `~/.config/kitsalud/vault-pass` | Crearlo como en la [preparación](preparacion.md) |
| `Decryption failed` | La contraseña del vault no es la del grupo | Pedirla de nuevo por el canal privado del grupo |
| `Using a SSH password instead of a key is not possible because Host Key checking is enabled` | La clave de host de kit01 no está en `known_hosts` | Entrar una vez con `ssh -o StrictHostKeyChecking=accept-new` |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` hacia una VM | La VM se volvió a crear y tiene otra clave de host | `ssh-keygen -R <ip>`. `vms.yml` lo hace solo cuando crea la VM |
| `could not match supplied host pattern` o `the role ... was not found` | Ansible no se ejecutó desde `platform/ansible` y no leyó `ansible.cfg` | Entrar a `kitsalud/platform/ansible` o exportar `ANSIBLE_CONFIG` con la ruta absoluta de ese archivo |
| `red-kit01.yml` falla al consultar Prometheus o al comprobar los flujos entre las VMs | Es el primer despliegue y todavía no existen | Ejecutarlo con `-e kit01_firewall_sondas=false -e '{"kit01_firewall_comprobaciones": []}'` |
| Una VM no descarga paquetes ni imágenes | kit01 todavía no tiene la salida de las VMs a Internet o la WAN del sitio está mal | Revisar `wan` en `host_vars/kit01.yml` y volver a ejecutar `red-kit01.yml` |
| nginx no responde en un sitio después de un playbook cortado | El corte se llevó el handler que recarga nginx | `sudo nginx -t && sudo systemctl reload nginx` en kit01. Los playbooks largos, como `monitoreo.yml` (unos 10 minutos), se ejecutan sin un tiempo límite corto |
| DHIS2 rechaza una contraseña con `Password must not have any generic word` | Su política rechaza palabras como `password`, `admin` o `dhis` | Cambiar esa clave en el vault por una que la política acepte |
| `kinit` o el recurso SMB fallan con la clave correcta | El usuario quedó bloqueado tras 5 intentos fallidos | `sudo samba-tool user unlock <usuario>` en clinica01 o esperar 15 minutos |
| Una pasada de comprobación da `changed` sin motivo | Se editaron archivos de un rol mientras corría, o corrían dos playbooks a la vez sobre la misma VM | Ejecutar un playbook por vez y sin editar sus archivos mientras corre |
