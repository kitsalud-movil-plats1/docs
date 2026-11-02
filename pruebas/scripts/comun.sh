#!/usr/bin/env bash
# Funciones comunes de los scripts de las pruebas P1-P13 (docs/pruebas).
# Funcionan en Linux y en macOS, que trae bash 3.2: sin arreglos asociativos,
# sin mapfile y sin el comando timeout. Cada script guarda su salida en
# docs/pruebas/salidas/, que sirve de evidencia (E6).

DOMINIO=salud.movil
KIT01_NETBIRD=${KIT01_NETBIRD:-100.90.225.113}
SO=$(uname -s)
DIR_PRUEBAS=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# Ansible del kit (platform/ansible), para las pruebas que se hacen en remoto
ANSIBLE_DIR=${ANSIBLE_DIR:-$DIR_PRUEBAS/../../platform/ansible}
TMP_PRUEBAS=$(mktemp -d "${TMPDIR:-/tmp}/kitsalud-prueba.XXXXXX")
trap 'rm -rf "$TMP_PRUEBAS"' EXIT
BIEN=0
MAL=0

# Encabezado y copia de todo lo que sale a salidas/<prueba>-<fecha>.txt
iniciar() {
  mkdir -p "$DIR_PRUEBAS/salidas"
  SALIDA="$DIR_PRUEBAS/salidas/$1-$(date +%Y%m%d-%H%M%S).txt"
  exec > >(tee "$SALIDA") 2>&1
  echo "== $1 - $2"
  echo "Fecha $(date '+%Y-%m-%d %H:%M:%S %z') · equipo $(hostname) · $SO"
}

seccion() { echo; echo "## $*"; }
bien() { echo "  [ OK ]  $*"; BIEN=$((BIEN + 1)); }
mal() { echo "  [FALLA] $*"; MAL=$((MAL + 1)); }
nota() { echo "          $*"; }

# Compara lo obtenido con lo esperado: comprobar "descripción" esperado obtenido
comprobar() {
  if [ "$2" = "$3" ]; then bien "$1 ($3)"; else mal "$1 (esperado $2, obtenido ${3:-nada})"; fi
}

terminar() {
  echo
  echo "Resultado: $BIEN bien y $MAL con falla. Salida en $SALIDA"
  [ "$MAL" -eq 0 ]
}

confirmar() {
  local r
  read -r -p "$1 [s/N] " r
  [ "$r" = "s" ] || [ "$r" = "S" ]
}

pedir_clave() {
  local c
  read -r -s -p "Contraseña de $1: " c
  echo >&2
  printf '%s' "$c"
}

# ---------- Configuración del equipo ----------

interfaz() {
  if [ "$SO" = Darwin ]; then
    route -n get default 2>/dev/null | awk '/interface:/{print $2}'
  else
    ip route show default | awk '{for (i = 1; i <= NF; i++) if ($i == "dev") {print $(i + 1); exit}}'
  fi
}

ipv4_de() {
  if [ "$SO" = Darwin ]; then ipconfig getifaddr "$1"; else ip -4 -o addr show dev "$1" | awk '{split($4, a, "/"); print a[1]; exit}'; fi
}

ipv6_globales_de() {
  if [ "$SO" = Darwin ]; then
    ifconfig "$1" | awk '/inet6 / && $2 !~ /^fe80/ {print $2}'
  else
    ip -6 -o addr show dev "$1" scope global | awk '{split($4, a, "/"); print a[1]}'
  fi
}

gateway4() {
  if [ "$SO" = Darwin ]; then route -n get default 2>/dev/null | awk '/gateway:/{print $2}'; else ip route show default | awk '{print $3; exit}'; fi
}

gateway6() {
  if [ "$SO" = Darwin ]; then
    netstat -rn -f inet6 | awk '$1 == "default" {sub(/%.*/, "", $2); print $2; exit}'
  else
    ip -6 route show default | awk '{print $3; exit}'
  fi
}

servidores_dns() {
  if [ "$SO" = Darwin ]; then
    scutil --dns | awk '/nameserver\[/{print $3}' | sort -u
  elif command -v resolvectl >/dev/null; then
    resolvectl dns "$1" 2>/dev/null | cut -d: -f2- | tr ' ' '\n' | grep -v '^$'
  else
    awk '/^nameserver/{print $2}' /etc/resolv.conf
  fi
}

# Volcado de la configuración, para la evidencia
mostrar_configuracion() {
  if [ "$SO" = Darwin ]; then
    ifconfig "$1"; netstat -rn -f inet | grep default; netstat -rn -f inet6 | grep default; scutil --dns | grep nameserver | sort -u
  else
    ip addr show dev "$1"; ip route; ip -6 route; command -v resolvectl >/dev/null && resolvectl status "$1"
  fi
}

# Red del kit en la que está el equipo, por su IPv4
red_actual() {
  case $(ipv4_de "$(interfaz)") in
    10.20.40.*) echo comunidad ;;
    10.20.10.*) echo interna ;;
    *) echo otra ;;
  esac
}

# ---------- Red ----------

# Direcciones de un nombre. resolver <nombre> A|AAAA
resolver() {
  if command -v dig >/dev/null; then
    dig +short "$2" "$1" | grep -E '^[0-9a-fA-F:.]+$'
  elif [ "$SO" = Darwin ]; then
    if [ "$2" = A ]; then dscacheutil -q host -a name "$1" | awk '/^ip_address/{print $2}'; else dscacheutil -q host -a name "$1" | awk '/^ipv6_address/{print $2}'; fi
  else
    if [ "$2" = A ]; then getent ahostsv4 "$1" | awk '{print $1}' | sort -u; else getent ahostsv6 "$1" | awk '{print $1}' | sort -u; fi
  fi
}

# Responde al ping. hace_ping 4|6 <destino>
hace_ping() {
  if [ "$SO" = Darwin ]; then
    if [ "$1" = 4 ]; then ping -c 3 -t 6 "$2" >/dev/null 2>&1; else ping6 -c 3 -i 1 "$2" >/dev/null 2>&1; fi
  else
    ping -"$1" -c 3 -W 2 "$2" >/dev/null 2>&1
  fi
}

# Código HTTP de una URL (000 si no hubo conexión). codigo_http 4|6 <url> [opciones de curl]
codigo_http() {
  local fam=$1 url=$2
  shift 2
  curl -"$fam" -s -o /dev/null -m 8 -w '%{http_code}' "$@" "$url" 2>/dev/null
}

# Abre una conexión TCP en 5 s. tcp_abre 4|6 <nombre o IP> <puerto>
tcp_abre() {
  local ip=$2
  case $ip in
    *[a-z]*) ip=$(resolver "$2" "$([ "$1" = 4 ] && echo A || echo AAAA)" | head -1) ;;
  esac
  [ -n "$ip" ] || return 1
  if [ "$SO" = Darwin ]; then
    nc -"$1" -z -G 5 -w 5 "$ip" "$3" >/dev/null 2>&1
  else
    timeout 5 bash -c "exec 3<>/dev/tcp/$ip/$3" >/dev/null 2>&1
  fi
}

# Raíz de la CA del kit, para comprobar los certificados sin -k
raiz_kit() {
  local f=$TMP_PRUEBAS/raiz.crt
  [ -s "$f" ] || curl -s -m 8 -o "$f" "http://ca.$DOMINIO/raiz.crt"
  [ -s "$f" ] && echo "$f"
}

# Avisa si el equipo no tiene IPv6 global y devuelve 1
exige_ipv6() {
  if [ -z "$(ipv6_globales_de "$(interfaz)")" ]; then
    mal "El equipo no tiene IPv6 global; las pruebas IPv6 no son válidas (ver P1)"
    return 1
  fi
}

# Avisa si el equipo de la Comunidad no aceptó el portal
exige_portal() {
  local c
  c=$(codigo_http 4 "http://biblioteca.$DOMINIO/")
  if [ "$c" = 302 ]; then
    mal "El equipo no aceptó el portal; abrir http://portal.$DOMINIO y tocar Acepto"
    return 1
  fi
}

# Avisa si un nombre del kit está en /etc/hosts
revisar_hosts() {
  if grep -q -E "^[^#].*\.$DOMINIO" /etc/hosts 2>/dev/null; then
    mal "/etc/hosts tiene nombres de $DOMINIO; comentarlos antes de probar"
    grep -E "^[^#].*\.$DOMINIO" /etc/hosts | sed 's/^/          /'
  fi
}

# ---------- Equipos del kit (remoto, con el Ansible del kit) ----------

# Ejecuta un comando en un equipo del kit y muestra solo su salida.
# remoto <equipo> <comando>. Necesita ~/.config/kitsalud/vault-pass y ssh-pass
remoto() {
  (cd "$ANSIBLE_DIR" && ansible "$1" -b -m shell -a "$2" 2>&1) | sed '1{/ | /d;}'
  return "${PIPESTATUS[0]}"
}

exige_ansible() {
  if [ ! -f "$ANSIBLE_DIR/ansible.cfg" ] || ! command -v ansible >/dev/null; then
    echo "Esta prueba usa el Ansible del kit (platform/ansible) desde la máquina de control." >&2
    exit 2
  fi
}
