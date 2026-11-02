#!/usr/bin/env bash
# P10 - Firewall IPv6. Se ejecuta en un cliente de la Comunidad con IPv6 global
# y el portal aceptado. Por IPv6 debe llegar a comunidad01 (F-09) y no a
# clinica01 ni a la administración de kit01 (F-20); se repite en IPv4 para
# comparar.
#   ./P10-firewall-ipv6.sh
source "$(dirname "$0")/comun.sh"
iniciar P10 "Firewall IPv6"

[ "$(red_actual)" = comunidad ] || { echo "Conectarse a SaludMovil-Comunidad"; exit 2; }
revisar_hosts
exige_ipv6 || { terminar; exit 1; }
exige_portal
RAIZ=$(raiz_kit)

permitido() {  # permitido 4|6 url
  local c
  c=$(codigo_http "$1" "$2" --cacert "$RAIZ")
  if [ "$c" = 200 ] || [ "$c" = 302 ]; then bien "IPv$1 permitido: $2 ($c)"; else mal "IPv$1 debía responder: $2 ($c)"; fi
}
bloqueado() {  # bloqueado 4|6 url
  local c
  c=$(codigo_http "$1" "$2" --cacert "$RAIZ" -m 5)
  if [ "$c" = 000 ]; then bien "IPv$1 bloqueado: $2"; else mal "IPv$1 debía estar bloqueado: $2 ($c)"; fi
}

for f in 6 4; do
  seccion "IPv$f"
  permitido $f "http://biblioteca.$DOMINIO/"
  permitido $f "https://registro.$DOMINIO/"
  bloqueado $f "https://pacientes.$DOMINIO/"
  if [ $f = 6 ]; then bloqueado 6 "http://[fd5a:fc7e:d716:20::11]/"; else bloqueado 4 "http://10.20.20.11/"; fi
  if tcp_abre $f "ns1.$DOMINIO" 22; then mal "IPv$f SSH de kit01 abre"; else bien "IPv$f bloqueado: SSH de kit01"; fi
done

nota "Origen IPv6: $(ipv6_globales_de "$(interfaz)" | head -1)"
nota "En kit01: grep SRC=fd5a:fc7e:d716:0040 /var/log/kitsalud/kit01/firewall.log | tail (fw-drop F-20)"
terminar
