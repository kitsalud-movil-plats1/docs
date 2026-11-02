#!/usr/bin/env bash
# P6 - Aplicación clínica. Se ejecuta en un cliente de la Interna (Clínica).
# Revisa que DHIS2 y la consulta de prerregistros responden en IPv4 e IPv6 con
# el certificado del kit, y que una cuenta del personal inicia sesión por la API
# con su rol. El registro y la búsqueda del paciente se hacen en el navegador.
#   ./P06-clinica.sh [usuario]      (por defecto ana.rojas)
source "$(dirname "$0")/comun.sh"
iniciar P06 "Aplicación clínica"

USUARIO=${1:-ana.rojas}
[ "$(red_actual)" = interna ] || { echo "Conectarse a SaludMovil-Clinica"; exit 2; }
revisar_hosts
RAIZ=$(raiz_kit) || mal "No se pudo descargar http://ca.$DOMINIO/raiz.crt"
TIENE6=1
exige_ipv6 || TIENE6=0

for f in 4 6; do
  [ $f = 6 ] && [ $TIENE6 = 0 ] && continue
  seccion "IPv$f"
  for url in "https://pacientes.$DOMINIO/" "https://consultas.$DOMINIO/"; do
    c=$(codigo_http $f "$url" --cacert "$RAIZ")
    case $c in 200|302) bien "$url responde $c con el certificado del kit verificado" ;; *) mal "$url responde $c" ;; esac
  done
done

seccion "Inicio de sesión en DHIS2 por la API"
CLAVE=$(pedir_clave "$USUARIO en DHIS2")
ME=$(curl -s -m 15 --cacert "$RAIZ" -u "$USUARIO:$CLAVE" "https://pacientes.$DOMINIO/api/me?fields=username,userRoles%5Bname%5D")
if echo "$ME" | grep -q "\"username\":\"$USUARIO\""; then
  bien "$USUARIO inicia sesión; roles: $(echo "$ME" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | paste -sd, -)"
else
  mal "$USUARIO no inicia sesión ($(echo "$ME" | head -c 120))"
fi

nota "Falta a mano: en https://pacientes.$DOMINIO, Capture → registrar un paciente ficticio con $USUARIO"
nota "y buscarlo con otra cuenta (carlos.perez). Guardar las capturas."
terminar
