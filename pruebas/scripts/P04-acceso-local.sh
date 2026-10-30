#!/usr/bin/env bash
# P4 - Acceso público local. Se ejecuta en el mismo cliente de la Comunidad de
# P3, con el portal aceptado. Revisa que la biblioteca, los videos, el registro
# y la CA responden en IPv4 e IPv6 (F-09), y el registro con el certificado del
# kit. El prerregistro se llena desde el navegador.
#   ./P04-acceso-local.sh
source "$(dirname "$0")/comun.sh"
iniciar P04 "Acceso público local"

[ "$(red_actual)" = comunidad ] || nota "No está en la Comunidad; la prueba vale desde SaludMovil-Comunidad"
revisar_hosts
exige_portal
RAIZ=$(raiz_kit) || mal "No se pudo descargar http://ca.$DOMINIO/raiz.crt"
TIENE6=1
exige_ipv6 || TIENE6=0

permitido() {  # permitido 4|6 url esperado descripción [opciones de curl]
  local fam=$1 url=$2 esperado=$3 desc=$4 c
  shift 4
  c=$(codigo_http "$fam" "$url" "$@")
  if echo " $esperado " | grep -q " $c "; then bien "IPv$fam $desc ($c)"; else mal "IPv$fam $desc (esperado $esperado, obtenido $c)"; fi
}

for f in 4 6; do
  [ $f = 6 ] && [ $TIENE6 = 0 ] && continue
  seccion "IPv$f"
  permitido $f "http://biblioteca.$DOMINIO/" 200 "biblioteca (Kiwix)"
  permitido $f "http://videos.$DOMINIO/" "200 302" "videos (Jellyfin)"
  permitido $f "https://registro.$DOMINIO/" 200 "registro, certificado del kit verificado" --cacert "$RAIZ"
  permitido $f "http://ca.$DOMINIO/" 200 "página de la CA"
done

seccion "Certificado de registro"
curl -s -m 8 --cacert "$RAIZ" -v -o /dev/null "https://registro.$DOMINIO/" 2>&1 | grep -E "subject:|issuer:|SSL certificate verify" | sed 's/^\* */    /'

nota "Falta a mano: llenar un prerregistro en https://registro.$DOMINIO, anotar el código y verlo desde la Clínica en https://consultas.$DOMINIO"
terminar
