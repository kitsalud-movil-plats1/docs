#!/usr/bin/env bash
# Ejecuta un script de prueba de cliente en prueba01, la VM de kit01 conectada a
# la red Comunidad, como lo haría un celular o un PC de esa red. Se ejecuta desde
# la máquina de control (Ansible del kit, por NetBird). Enciende prueba01 si hace
# falta, copia scripts/ y guarda la salida también en salidas/ de este equipo.
#   ./en-prueba01.sh <script> [argumentos]   por ejemplo ./en-prueba01.sh P01-cliente.sh
#   ./en-prueba01.sh --sin-portal            quita la autorización del portal de prueba01
#   ./en-prueba01.sh --apagar                quita la autorización y apaga prueba01
source "$(dirname "$0")/comun.sh"
exige_ansible
MAC_PRUEBA01=52:54:00:40:00:50

sin_portal() {
  remoto kit01 "nft 'destroy element inet filtro portal_ok { $MAC_PRUEBA01 }'" >/dev/null &&
    echo "prueba01 sin autorización del portal"
}

case $1 in
  "") sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
  --sin-portal) sin_portal; exit ;;
  --apagar)
    sin_portal
    (cd "$ANSIBLE_DIR" && ansible-playbook playbooks/prueba01.yml -e prueba01_estado=apagada >/dev/null) && echo "prueba01 apagada"
    exit ;;
esac
[ -f "$DIR_PRUEBAS/scripts/$1" ] || { echo "No existe scripts/$1"; exit 2; }

(cd "$ANSIBLE_DIR" && ansible-playbook playbooks/prueba01.yml >/dev/null) || { echo "No se pudo encender prueba01"; exit 2; }
(cd "$ANSIBLE_DIR" && ansible prueba01 -m copy -a "src=$DIR_PRUEBAS/scripts dest=/tmp/pruebas/ mode=preserve" >/dev/null) || exit 2
mkdir -p "$DIR_PRUEBAS/salidas"
SCRIPT=$1
SALIDA="$DIR_PRUEBAS/salidas/$(echo "$SCRIPT" | cut -d- -f1)-prueba01-$(date +%Y%m%d-%H%M%S).txt"
shift
# Sin los avisos de Ansible antes del encabezado y sin la ruta de la salida en prueba01
remoto prueba01 "cd /tmp/pruebas && bash scripts/$SCRIPT $* </dev/null" |
  sed -n -e '/^== /,$p' | sed -e 's/ Salida en .*$//' -e 's/non-zero return code$//' | tee "$SALIDA"
E=${PIPESTATUS[0]}
echo "Salida en $SALIDA"
exit "$E"
