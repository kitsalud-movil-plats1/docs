#!/usr/bin/env bash
# P1 - Cliente comunitario. Se ejecuta en el cliente (Linux o macOS) conectado
# al Wi-Fi del kit. Revisa que recibió IPv4, IPv6, gateway y DNS del kit y que
# el gateway responde en las dos familias.
#   ./P01-cliente.sh
source "$(dirname "$0")/comun.sh"
iniciar P01 "Cliente comunitario"

IF=$(interfaz)
RED=$(red_actual)
case $RED in
  comunidad) N=40 ;;
  interna) N=10 ;;
  *) echo "El equipo no está en una red del kit (IPv4 $(ipv4_de "$IF"))"; exit 2 ;;
esac
nota "Interfaz $IF, red $RED (VLAN $N)"

seccion "Configuración recibida"
mostrar_configuracion "$IF" | sed 's/^/    /'

seccion "IPv4 (Kea DHCPv4)"
IP4=$(ipv4_de "$IF")
case $IP4 in
  10.20.$N.1[0-9][0-9]|10.20.$N.2[0-9][0-9]) bien "Dirección $IP4 del rango del kit" ;;
  *) mal "Dirección $IP4 fuera del rango 10.20.$N.x del kit" ;;
esac
comprobar "Gateway IPv4" "10.20.$N.1" "$(gateway4)"
if hace_ping 4 "10.20.$N.1"; then bien "El gateway responde al ping IPv4"; else mal "El gateway no responde al ping IPv4"; fi

seccion "IPv6 (SLAAC con el anuncio de radvd)"
IP6=$(ipv6_globales_de "$IF" | grep -i "^fd5a:fc7e:d716:$N:" | head -1)
if [ -n "$IP6" ]; then bien "Dirección $IP6 del prefijo fd5a:fc7e:d716:$N::/64"; else mal "Sin dirección del prefijo fd5a:fc7e:d716:$N::/64"; fi
comprobar "Gateway IPv6" "fe80::1" "$(gateway6)"
if hace_ping 6 "fe80::1%$IF"; then bien "El gateway responde al ping IPv6 (fe80::1%$IF)"; else mal "El gateway no responde al ping IPv6"; fi

seccion "DNS (DHCPv4 y DHCPv6 stateless)"
DNS=$(servidores_dns "$IF")
nota "Servidores: $(echo $DNS)"
if echo "$DNS" | grep -q -x "10.20.20.10"; then bien "DNS IPv4 del kit (10.20.20.10)"; else mal "Falta el DNS IPv4 del kit (10.20.20.10)"; fi
if echo "$DNS" | grep -q -i -x "fd5a:fc7e:d716:20::10"; then bien "DNS IPv6 del kit (fd5a:fc7e:d716:20::10)"; else mal "Falta el DNS IPv6 del kit (fd5a:fc7e:d716:20::10)"; fi
comprobar "Resuelve portal.$DOMINIO" "10.20.40.1" "$(resolver portal.$DOMINIO A | head -1)"

revisar_hosts
terminar
