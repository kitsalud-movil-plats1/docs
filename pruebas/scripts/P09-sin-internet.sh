#!/usr/bin/env bash
# P9 - Pérdida de Internet. Se ejecuta en un cliente de la Comunidad o de la
# Clínica mientras el cable WAN de kit01 está desconectado. Revisa que los
# nombres y servicios del kit siguen en IPv4 e IPv6 y que lo externo falla.
#   ./P09-sin-internet.sh
source "$(dirname "$0")/comun.sh"
iniciar P09 "Pérdida de Internet"

RED=$(red_actual)
[ "$RED" = otra ] && { echo "Conectarse a una red del kit"; exit 2; }
revisar_hosts
nota "Red $RED. Esta prueba vale con el cable WAN de kit01 desconectado."
RAIZ=$(raiz_kit)

seccion "Lo externo falla"
if [ -z "$(resolver google.com A)" ]; then bien "google.com no resuelve"; else nota "google.com resuelve; ¿la WAN sigue conectada?"; fi
if [ "$(codigo_http 4 https://www.google.com/ -m 5)" = 000 ]; then bien "https://www.google.com no responde"; else mal "Hay salida a Internet; desconectar la WAN"; fi

seccion "DNS del kit"
for n in pacientes biblioteca registro portal; do
  [ -n "$(resolver $n.$DOMINIO A)" ] && [ -n "$(resolver $n.$DOMINIO AAAA)" ] && bien "$n.$DOMINIO resuelve A y AAAA" || mal "$n.$DOMINIO no resuelve"
done

seccion "Servicios"
servicio() {  # servicio 4|6 url esperado
  local c
  c=$(codigo_http "$1" "$2" --cacert "$RAIZ")
  if echo " $3 " | grep -q " $c "; then bien "IPv$1 $2 ($c)"; else mal "IPv$1 $2 (esperado $3, obtenido $c)"; fi
}
for f in 4 6; do
  if [ $f = 6 ] && [ -z "$(ipv6_globales_de "$(interfaz)")" ]; then nota "Sin IPv6 global; se omite IPv6 (ver P1)"; continue; fi
  if [ "$RED" = comunidad ]; then
    servicio $f "http://biblioteca.$DOMINIO/" "200 302"
    servicio $f "http://videos.$DOMINIO/" "200 302"
    servicio $f "https://registro.$DOMINIO/" "200 302"
    servicio $f "http://portal.$DOMINIO/" 200
  else
    servicio $f "https://pacientes.$DOMINIO/" "200 302"
    servicio $f "https://consultas.$DOMINIO/" "200 302"
    servicio $f "http://biblioteca.$DOMINIO/" 200
    if tcp_abre $f "archivos.$DOMINIO" 445; then bien "IPv$f SMB de archivos (445) abre"; else mal "IPv$f SMB de archivos (445) no abre"; fi
  fi
done
[ "$RED" = comunidad ] && nota "Un 302 en la Comunidad significa que el equipo no ha aceptado el portal; el portal funciona igual"

nota "A mano: conectar un equipo nuevo a la Comunidad y ver el portal; buscar el paciente de P6 en DHIS2."
nota "En kit01, al volver la WAN: chronyc tracking (estrato 10 durante el corte) y systemctl --failed"
terminar
