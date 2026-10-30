#!/usr/bin/env bash
# P12 - Reinicio. Se ejecuta desde la máquina de control (Ansible del kit, por
# NetBird), con alguien en el sitio por si kit01 no vuelve.
#   ./P12-reinicio.sh estado      revisa que todo esté arriba (antes o después)
#   ./P12-reinicio.sh reiniciar   revisa, reinicia kit01, mide cuánto tarda y revisa otra vez
source "$(dirname "$0")/comun.sh"
exige_ansible
iniciar P12 "Reinicio"

SERVICIOS="nftables kea-dhcp4-server kea-dhcp6-server radvd named chrony nginx kitsalud-portal prometheus grafana-server rsyslog netbird libvirtd"

estado() {
  seccion "kit01"
  remoto kit01 "uptime; uname -r" | sed 's/^/    /'
  FALLIDAS=$(remoto kit01 "systemctl --failed --no-legend --plain | awk '{print \$1}'")
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
    D=$(remoto $vm "docker ps -a --format '{% raw %}{{.Names}} {{.Status}}{% endraw %}'")
    echo "$D" | sed 's/^/    /'
    if echo "$D" | grep -v -q -E ' Up '; then mal "Hay contenedores detenidos en $vm"; else bien "Todos los contenedores de $vm arriba"; fi
    FALLIDAS=$(remoto $vm "systemctl --failed --no-legend --plain | awk '{print \$1}'")
    if [ -z "$FALLIDAS" ]; then bien "Sin unidades fallidas en $vm"; else mal "Unidades fallidas en $vm: $(echo $FALLIDAS)"; fi
    if [ $vm = clinica01 ]; then
      A=$(remoto clinica01 "systemctl is-active samba-ad-dc")
      if [ "$A" = active ]; then bien "Samba AD activo"; else mal "Samba AD $A"; fi
    fi
  done
}

if [ "$1" = reiniciar ]; then
  estado
  seccion "Reinicio de kit01"
  confirmar "¿Hay alguien en el sitio y se reinicia kit01 ahora?" || exit 1
  INICIO=$(date +%s)
  (cd "$ANSIBLE_DIR" && ansible kit01 -b -m reboot -a "reboot_timeout=900 post_reboot_delay=60" 2>&1) | sed 's/^/    /'
  bien "kit01 volvió en $(($(date +%s) - INICIO)) s (incluye 60 s de espera para que arranquen las VMs)"
  sleep 60
fi
estado
nota "En el sitio: un celular en la Comunidad vuelve a ver el portal (el set arranca vacío) y después abre la biblioteca"
nota "Matriz de flujos completa: ansible-playbook playbooks/verificar-flujos.yml (desde platform/ansible)"
terminar
