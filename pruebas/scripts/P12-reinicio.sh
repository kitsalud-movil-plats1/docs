#!/usr/bin/env bash
# P12 - Reinicio. Se ejecuta desde la máquina de control (Ansible del kit, por
# NetBird).
#   ./P12-reinicio.sh estado      revisa que todo esté arriba (antes o después)
#   ./P12-reinicio.sh vms         revisa, reinicia clinica01 y comunidad01 a la vez,
#                                 mide en Prometheus cuánto tardan los servicios en
#                                 volver en IPv4 e IPv6 y revisa otra vez (en remoto)
#   ./P12-reinicio.sh reiniciar   revisa, reinicia kit01, mide cuánto tarda y revisa
#                                 otra vez (con alguien en el sitio por si no vuelve)
source "$(dirname "$0")/comun.sh"
exige_ansible
iniciar P12 "Reinicio"

SERVICIOS="nftables kea-dhcp4-server kea-dhcp6-server radvd named chrony nginx kitsalud-portal prometheus grafana-server rsyslog netbird libvirtd"
ROJAS="curl -s 127.0.0.1:9090/api/v1/query --data-urlencode 'query=(probe_success == 0) or (up == 0)' | python3 -c 'import json,sys; print(len(json.load(sys.stdin)[\"data\"][\"result\"]))'"

estado() {
  seccion "kit01"
  remoto kit01 "uptime; uname -r" | sed 's/^/    /'
  FALLIDAS=$(remoto kit01 "systemctl --failed --no-legend --plain | awk '{print \$1}'")
  # La espera de la red falló en un arranque anterior a la red actual del kit y
  # sigue figurando hasta que kit01 se reinicie; después del reinicio sí cuenta
  if [ -z "$KIT01_REINICIADO" ] && echo "$FALLIDAS" | grep -q -x systemd-networkd-wait-online.service; then
    nota "systemd-networkd-wait-online figura fallida desde el último arranque de kit01, anterior a la red actual"
    FALLIDAS=$(echo "$FALLIDAS" | grep -v -x systemd-networkd-wait-online.service)
  fi
  if [ -z "$FALLIDAS" ]; then bien "Sin unidades fallidas en kit01"; else mal "Unidades fallidas en kit01: $(echo $FALLIDAS)"; fi
  for s in $SERVICIOS; do
    A=$(remoto kit01 "systemctl is-active $s")
    if [ "$A" = active ]; then bien "$s activo"; else mal "$s $A"; fi
  done
  V=$(remoto kit01 "virsh -c qemu:///system list --name --state-running")
  for vm in clinica01 comunidad01; do
    if echo "$V" | grep -q -x $vm; then bien "VM $vm en marcha"; else mal "VM $vm no está en marcha"; fi
  done
  remoto kit01 "systemctl list-timers backup.timer --no-pager | head -2" | sed 's/^/    /'
  for vm in clinica01 comunidad01; do
    seccion "$vm"
    remoto $vm "echo encendida desde \$(uptime -s)" | sed 's/^/    /'
    D=$(remoto $vm "docker ps -a --format '{% raw %}{{.Names}} {{.Status}}{% endraw %}'")
    echo "$D" | sed 's/^/    /'
    if echo "$D" | grep -v -q -E ' Up '; then mal "Hay contenedores detenidos en $vm"; else bien "Todos los contenedores de $vm arriba"; fi
    if echo "$D" | grep -q -E 'starting|unhealthy'; then mal "Hay contenedores sin terminar de arrancar en $vm"; fi
    FALLIDAS=$(remoto $vm "systemctl --failed --no-legend --plain | awk '{print \$1}'")
    if [ -z "$FALLIDAS" ]; then bien "Sin unidades fallidas en $vm"; else mal "Unidades fallidas en $vm: $(echo $FALLIDAS)"; fi
    if [ $vm = clinica01 ]; then
      A=$(remoto clinica01 "systemctl is-active samba-ad-dc")
      if [ "$A" = active ]; then bien "Samba AD activo"; else mal "Samba AD $A"; fi
    fi
  done
  seccion "Monitoreo"
  comprobar "Sondas y exporters en rojo" 0 "$(remoto kit01 "$ROJAS")"
}

# Se ejecuta en kit01. Reinicia las dos VMs y sigue en Prometheus (cada 2 s)
# primero la caída y después la vuelta de cada familia. Una familia cuenta como
# recuperada cuando se vio en rojo y vuelve a tener todas sus sondas en verde
MEDIR=$TMP_PRUEBAS/p12-vms.sh
cat > "$MEDIR" <<'FIN'
#!/bin/bash
VMS="clinica01|comunidad01"
cuenta() {  # sondas o exporters en rojo según la consulta
  curl -s 127.0.0.1:9090/api/v1/query --data-urlencode "query=count(($1) == 0) or vector(0)" |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["result"][0]["value"][1])'
}
F4='probe_success{familia="ipv4"}'
F6='probe_success{familia="ipv6"}'
NODO="up{job=\"node\",equipo=~\"$VMS\"}"
TODO='probe_success or up'
INICIO=$(date +%s)
echo "reinicio de clinica01 y comunidad01 a las $(date +%T)"
virsh -c qemu:///system reboot clinica01 >/dev/null && virsh -c qemu:///system reboot comunidad01 >/dev/null || exit 1
visto4= visto6= vistonodo= v4= v6= nodo= total=
while :; do
  t=$(($(date +%s) - INICIO))
  r4=$(cuenta "$F4"); r6=$(cuenta "$F6"); rn=$(cuenta "$NODO")
  [ -z "$visto4" ] && [ "$r4" != 0 ] && visto4=$t && echo "ipv4 en rojo a los $t s ($r4 sondas)"
  [ -z "$visto6" ] && [ "$r6" != 0 ] && visto6=$t && echo "ipv6 en rojo a los $t s ($r6 sondas)"
  [ -z "$vistonodo" ] && [ "$rn" != 0 ] && vistonodo=$t && echo "exporters de las VMs en rojo a los $t s"
  [ -n "$visto4" ] && [ -z "$v4" ] && [ "$r4" = 0 ] && v4=$t && echo "ipv4 en verde a los $t s"
  [ -n "$visto6" ] && [ -z "$v6" ] && [ "$r6" = 0 ] && v6=$t && echo "ipv6 en verde a los $t s"
  [ -n "$vistonodo" ] && [ -z "$nodo" ] && [ "$rn" = 0 ] && nodo=$t && echo "exporters de las VMs en verde a los $t s"
  if [ -n "$v4" ] && [ -n "$v6" ] && [ -n "$nodo" ] && [ "$(cuenta "$TODO")" = 0 ]; then
    echo "todo en verde a los $t s"; exit 0
  fi
  [ "$t" -gt 900 ] && { echo "a los 900 s siguen en rojo $r4 de ipv4, $r6 de ipv6 y $rn exporters"; exit 1; }
  sleep 2
done
FIN

if [ "$1" = vms ]; then
  estado
  seccion "Reinicio de clinica01 y comunidad01"
  (cd "$ANSIBLE_DIR" && ansible kit01 -b -m copy -a "src=$MEDIR dest=/run/p12-vms.sh mode=0700" >/dev/null)
  R=$(remoto kit01 "/run/p12-vms.sh; e=\$?; rm -f /run/p12-vms.sh; exit \$e")
  echo "$R" | sed 's/^/    /'
  for f in ipv4 ipv6; do
    T=$(echo "$R" | sed -n "s/^$f en verde a los \([0-9]*\) s$/\1/p")
    if [ -n "$T" ]; then bien "Sondas $f en verde otra vez a los $T s"; else mal "Las sondas $f no volvieron a verde"; fi
  done
  T=$(echo "$R" | sed -n 's/^todo en verde a los \([0-9]*\) s$/\1/p')
  if [ -n "$T" ]; then bien "Todo en verde a los $T s del reinicio, sin intervención"; else mal "No todo volvió a verde"; fi
  nota "Esperando 30 s para revisar que nada se cae después del arranque"
  sleep 30
elif [ "$1" = reiniciar ]; then
  estado
  seccion "Reinicio de kit01"
  confirmar "¿Hay alguien en el sitio y se reinicia kit01 ahora?" || exit 1
  INICIO=$(date +%s)
  (cd "$ANSIBLE_DIR" && ansible kit01 -b -m reboot -a "reboot_timeout=900 post_reboot_delay=60" 2>&1) | sed 's/^/    /'
  bien "kit01 volvió en $(($(date +%s) - INICIO)) s (incluye 60 s de espera para que arranquen las VMs)"
  KIT01_REINICIADO=1
  sleep 60
fi
estado
[ "$1" = reiniciar ] && nota "En el sitio: un celular en la Comunidad vuelve a ver el portal (el set arranca vacío) y después abre la biblioteca"
nota "Matriz de flujos completa: ansible-playbook playbooks/verificar-flujos.yml (desde platform/ansible)"
terminar
