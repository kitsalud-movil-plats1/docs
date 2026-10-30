#!/usr/bin/env bash
# P5 - Portal cautivo. Se ejecuta en un cliente nuevo de la Comunidad (que no
# aceptó). Revisa que todo el HTTP va al portal en IPv4 e IPv6 y que el HTTPS
# se rechaza. Con --aceptar hace lo mismo que el botón Acepto y revisa que
# después pasa y que el portal muestra el menú.
#   ./P05-portal.sh [--aceptar]
source "$(dirname "$0")/comun.sh"
iniciar P05 "Portal cautivo"

[ "$(red_actual)" = comunidad ] || { echo "Conectarse a SaludMovil-Comunidad"; exit 2; }
revisar_hosts
PORTAL="http://portal.$DOMINIO/"

destino() {  # destino 4|6 url → código y Location
  curl -"$1" -s -o /dev/null -m 8 -w '%{http_code} %{redirect_url}' "$2" 2>/dev/null
}

seccion "Antes de aceptar"
R4=$(destino 4 http://neverssl.com/)
if [ "$R4" = "302 $PORTAL" ]; then
  bien "IPv4 http://neverssl.com va al portal ($R4)"
  R6=$(destino 6 "http://biblioteca.$DOMINIO/")
  if [ "$R6" = "302 $PORTAL" ]; then bien "IPv6 http://biblioteca.$DOMINIO va al portal"; else mal "IPv6 no va al portal ($R6); revisar que el equipo tenga IPv6 (P1)"; fi
  C=$(codigo_http 4 https://example.com/ -m 5)
  if [ "$C" = 000 ]; then bien "El HTTPS sin aceptar se rechaza"; else mal "El HTTPS sin aceptar responde $C"; fi
  if curl -s -m 8 "$PORTAL" | grep -q "Acepto"; then bien "$PORTAL muestra las condiciones con el botón Acepto"; else mal "$PORTAL no muestra las condiciones"; fi
else
  nota "Este equipo ya está autorizado (neverssl.com respondió $R4). Para repetir la prueba hay que"
  nota "quitar su MAC en kit01: sudo nft delete element inet filtro portal_ok { <MAC> }"
  if curl -s -m 8 "$PORTAL" | grep -q "Ya tiene acceso"; then bien "$PORTAL muestra el menú a un equipo autorizado"; else mal "$PORTAL no muestra el menú"; fi
fi

if [ "$1" = --aceptar ]; then
  seccion "Aceptar"
  comprobar "POST /aceptar (lo mismo que tocar Acepto)" 303 "$(curl -4 -s -o /dev/null -m 8 -w '%{http_code}' -X POST "${PORTAL}aceptar")"
  sleep 1
  comprobar "IPv4 http://biblioteca.$DOMINIO después de aceptar" 200 "$(codigo_http 4 "http://biblioteca.$DOMINIO/")"
  [ -n "$(ipv6_globales_de "$(interfaz)")" ] && comprobar "IPv6 http://biblioteca.$DOMINIO después de aceptar" 200 "$(codigo_http 6 "http://biblioteca.$DOMINIO/")"
  if curl -s -m 8 "$PORTAL" | grep -q "Ya tiene acceso"; then bien "$PORTAL ahora muestra el menú"; else mal "$PORTAL no muestra el menú"; fi
fi

nota "En kit01: sudo nft list set inet filtro portal_ok y grep -v Blackbox /var/log/nginx/portal.log | tail"
terminar
