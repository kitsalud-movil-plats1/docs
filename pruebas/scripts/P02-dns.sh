#!/usr/bin/env bash
# P2 - DNS. Se ejecuta en un cliente de la Interna (Clínica). Revisa los
# registros A y AAAA de los servicios, la delegación del dominio AD, las zonas
# inversas, el ping por nombre y el acceso HTTP por nombre en las dos familias.
#   ./P02-dns.sh
source "$(dirname "$0")/comun.sh"
iniciar P02 "DNS"

revisar_hosts
[ "$(red_actual)" = interna ] || nota "El ping por nombre (F-22) solo se permite desde la Interna; aquí puede fallar"

seccion "Registros A y AAAA"
# nombre ipv4 ipv6
while read -r nombre v4 v6; do
  comprobar "A    $nombre.$DOMINIO" "$v4" "$(resolver "$nombre.$DOMINIO" A | head -1)"
  comprobar "AAAA $nombre.$DOMINIO" "$v6" "$(resolver "$nombre.$DOMINIO" AAAA | head -1)"
done <<EOF
biblioteca 10.20.20.12 fd5a:fc7e:d716:20::12
videos 10.20.20.12 fd5a:fc7e:d716:20::12
registro 10.20.20.12 fd5a:fc7e:d716:20::12
ca 10.20.20.12 fd5a:fc7e:d716:20::12
pacientes 10.20.20.11 fd5a:fc7e:d716:20::11
consultas 10.20.20.11 fd5a:fc7e:d716:20::11
archivos 10.20.20.11 fd5a:fc7e:d716:20::11
ntp 10.20.20.10 fd5a:fc7e:d716:20::10
monitoreo 10.20.20.10 fd5a:fc7e:d716:20::10
portal 10.20.40.1 fd5a:fc7e:d716:40::1
EOF

if command -v dig >/dev/null; then
  seccion "Servidor del kit, delegación AD e inversas (dig)"
  R=$(dig A pacientes.$DOMINIO @10.20.20.10)
  if echo "$R" | grep -q "flags:.* aa"; then bien "Respuesta autoritativa del DNS del kit por IPv4 (bandera aa)"; else mal "El DNS del kit por IPv4 no respondió como autoritativo"; fi
  comprobar "Consulta al DNS del kit por IPv6" "fd5a:fc7e:d716:20::11" "$(dig +short AAAA pacientes.$DOMINIO @fd5a:fc7e:d716:20::10)"
  SRV=$(dig +short SRV _ldap._tcp.ad.$DOMINIO)
  if echo "$SRV" | grep -q "dc01.ad.$DOMINIO"; then bien "Delegación a Samba AD (_ldap._tcp.ad.$DOMINIO → dc01)"; else mal "Sin respuesta SRV de ad.$DOMINIO"; fi
  comprobar "Inversa IPv4 de 10.20.20.12" "comunidad01.$DOMINIO." "$(dig +short -x 10.20.20.12)"
  comprobar "Inversa IPv6 de fd5a:fc7e:d716:20::12" "comunidad01.$DOMINIO." "$(dig +short -x fd5a:fc7e:d716:20::12)"
else
  nota "Sin dig: se omiten la bandera aa, la delegación y las inversas (instalar bind-utils o dnsutils)"
fi

seccion "Extremo a extremo por nombre"
if hace_ping 4 biblioteca.$DOMINIO; then bien "ping IPv4 a biblioteca.$DOMINIO"; else mal "ping IPv4 a biblioteca.$DOMINIO"; fi
if exige_ipv6; then
  if hace_ping 6 biblioteca.$DOMINIO; then bien "ping IPv6 a biblioteca.$DOMINIO"; else mal "ping IPv6 a biblioteca.$DOMINIO"; fi
fi
comprobar "HTTP IPv4 a http://biblioteca.$DOMINIO" 200 "$(codigo_http 4 http://biblioteca.$DOMINIO/)"
comprobar "HTTP IPv6 a http://biblioteca.$DOMINIO" 200 "$(codigo_http 6 http://biblioteca.$DOMINIO/)"

terminar
