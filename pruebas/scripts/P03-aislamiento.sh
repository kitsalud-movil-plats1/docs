#!/usr/bin/env bash
# P3 - Aislamiento. Se ejecuta en un cliente de la Comunidad que ya aceptó el
# portal. Intenta llegar a lo clínico y a la administración en IPv4 e IPv6;
# todo debe quedar bloqueado (F-20). Con la IP de otro cliente del mismo SSID
# como argumento, revisa también el aislamiento del AP.
#   ./P03-aislamiento.sh [IP de otro cliente de la Comunidad]
source "$(dirname "$0")/comun.sh"
iniciar P03 "Aislamiento"

[ "$(red_actual)" = comunidad ] || { echo "Conectarse a SaludMovil-Comunidad"; exit 2; }
revisar_hosts
exige_portal
TIENE6=1
exige_ipv6 || TIENE6=0

bloqueado_http() {  # bloqueado_http 4|6 url descripción
  local c
  c=$(codigo_http "$1" "$2" --cacert "$(raiz_kit)" -m 5)
  if [ "$c" = 000 ]; then bien "IPv$1 bloqueado: $3"; else mal "IPv$1 responde $c: $3"; fi
}

bloqueado_tcp() {  # bloqueado_tcp 4|6 destino puerto descripción
  if tcp_abre "$1" "$2" "$3"; then mal "IPv$1 abre: $4 ($2 puerto $3)"; else bien "IPv$1 bloqueado: $4 ($2 puerto $3)"; fi
}

for f in 4 6; do
  [ $f = 6 ] && [ $TIENE6 = 0 ] && continue
  seccion "IPv$f"
  bloqueado_http $f "https://pacientes.$DOMINIO/" "DHIS2 (clinica01 443)"
  bloqueado_http $f "https://consultas.$DOMINIO/" "consulta de prerregistros (clinica01 443)"
  bloqueado_tcp $f "archivos.$DOMINIO" 445 "SMB de clinica01"
  bloqueado_http $f "https://monitoreo.$DOMINIO/" "Grafana (kit01 443)"
  bloqueado_tcp $f "ns1.$DOMINIO" 22 "SSH de kit01"
  bloqueado_tcp $f "portal.$DOMINIO" 22 "SSH de kit01 por su IP de la Comunidad"
done
seccion "Interna"
if hace_ping 4 10.20.10.1; then mal "La Interna responde al ping"; else bien "La Interna (10.20.10.1) no responde"; fi

if [ -n "$1" ]; then
  seccion "Aislamiento entre clientes del AP"
  if hace_ping 4 "$1"; then mal "El cliente $1 responde; revisar AP Isolation"; else bien "El cliente $1 no responde (AP Isolation)"; fi
fi

nota "En kit01 los intentos quedan en /var/log/kitsalud/kit01/firewall.log con el prefijo fw-drop F-20"
nota "Origen de esta prueba: $(ipv4_de "$(interfaz)") $(ipv6_globales_de "$(interfaz)" | head -1)"
terminar
