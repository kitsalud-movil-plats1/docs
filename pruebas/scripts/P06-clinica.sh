#!/usr/bin/env bash
# P6 - Aplicación clínica. Se ejecuta en un cliente de la Interna (Clínica).
# Revisa que DHIS2 y la consulta de prerregistros responden en IPv4 e IPv6 con
# el certificado del kit, y que una cuenta del personal inicia sesión por la API
# con su rol. El registro y la búsqueda del paciente se hacen en el navegador.
#   ./P06-clinica.sh [usuario]      (por defecto ana.rojas)
# Con --remoto se ejecuta desde la máquina de control: sw01 (Interna) abre el
# 443 de clinica01 y, desde kit01 con la raíz del kit y las claves del vault,
# ana.rojas registra un paciente de prueba en DHIS2, carlos.perez lo encuentra y
# se borra, en IPv4 y en IPv6. Con códigos de prerregistro como argumentos, la
# consulta de prerregistros los busca con ana.rojas.
#   ./P06-clinica.sh --remoto [código...]
source "$(dirname "$0")/comun.sh"
iniciar P06 "Aplicación clínica"

if [ "$1" = --remoto ]; then
  shift
  exige_ansible
  seccion "Desde la Interna (sw01) hacia clinica01"
  # El fetch de RouterOS no completa el TLS de Caddy; que Caddy responda por HTTP
  # en el 443 basta para saber que el firewall deja pasar la conexión
  for ip in 10.20.20.11 "[fd5a:fc7e:d716:20::11]"; do
    R=$(sw01_fetch "http://$ip:443/" "pacientes.$DOMINIO")
    case $R in "status: connecting"|"") mal "sw01 no abre $ip puerto 443 ($R)" ;; *) bien "sw01 abre $ip puerto 443 (Caddy responde: $R)" ;; esac
  done

  # Se ejecuta en kit01. Las claves llegan en variables de entorno y curl las lee
  # de un archivo de configuración, así no quedan en la línea de comandos
  CLINICA=$TMP_PRUEBAS/p06-kit01.sh
  cat > "$CLINICA" <<'FIN'
#!/bin/bash
RAIZ=/etc/kitsalud/ca/raiz.crt
HOY=$(date +%F)
api() {  # api <familia> <usuario> <clave> <método> <ruta> [datos]
  local ip=10.20.20.11
  [ "$1" = 6 ] && ip=fd5a:fc7e:d716:20::11
  [ "$1" = 6 ] && ip="[$ip]"
  curl -s -m 30 --cacert $RAIZ --resolve "pacientes.salud.movil:443:$ip" -K <(printf 'user = "%s:%s"\n' "$2" "$3") \
    -X "$4" -H 'Content-Type: application/json' ${6:+-d "$6"} "https://pacientes.salud.movil$5"
}
valor() { python3 -c "import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1]))" "$1" 2>/dev/null; }
for f in 4 6; do
  echo "SECCION|DHIS2 por IPv$f"
  ME=$(api $f ana.rojas "$DHIS_CLAVE" GET '/api/me?fields=username,userRoles%5Bname%5D')
  echo "$ME" | grep -q '"username":"ana.rojas"' &&
    echo "OK|ana.rojas inicia sesión; roles $(echo "$ME" | valor "','.join(r['name'] for r in d['userRoles'])")" ||
    echo "FALLA|ana.rojas no inicia sesión ($(echo "$ME" | head -c 100))"
  UID_P=P6$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 9)
  DOC="P6-$f-$(date +%s)"
  CUERPO=$(printf '{"trackedEntities":[{"trackedEntity":"%s","trackedEntityType":"TipoPacien1","orgUnit":"KitSalud001",
    "attributes":[{"attribute":"AtrNombre01","value":"Prueba"},{"attribute":"AtrApellid1","value":"P6 IPv%s"},{"attribute":"AtrDocumen1","value":"%s"}],
    "enrollments":[{"program":"ProgAtenPr1","orgUnit":"KitSalud001","enrolledAt":"%s","occurredAt":"%s"}]}]}' "$UID_P" "$f" "$DOC" "$HOY" "$HOY")
  R=$(api $f ana.rojas "$DHIS_CLAVE" POST '/api/tracker?async=false&importStrategy=CREATE' "$CUERPO")
  [ "$(echo "$R" | valor "d['status']")" = OK ] &&
    echo "OK|ana.rojas registra un paciente ficticio ($UID_P, documento $DOC) e inscripción en Atención primaria" ||
    echo "FALLA|ana.rojas no pudo registrar el paciente ($(echo "$R" | head -c 200))"
  B=$(api $f carlos.perez "$DHIS_CLAVE" GET "/api/tracker/trackedEntities?program=ProgAtenPr1&orgUnits=KitSalud001&filter=AtrDocumen1:eq:$DOC&fields=trackedEntity,attributes%5Bvalue%5D")
  echo "$B" | grep -q "\"$UID_P\"" &&
    echo "OK|carlos.perez lo encuentra por documento ($(echo "$B" | valor "' '.join(a['value'] for a in (d.get('trackedEntities') or d.get('instances'))[0]['attributes'])"))" ||
    echo "FALLA|carlos.perez no lo encuentra ($(echo "$B" | head -c 150))"
  R=$(api $f admin "$ADMIN_CLAVE" POST '/api/tracker?async=false&importStrategy=DELETE' "{\"trackedEntities\":[{\"trackedEntity\":\"$UID_P\"}]}")
  [ "$(echo "$R" | valor "d['status']")" = OK ] && echo "OK|Paciente de prueba borrado" || echo "FALLA|No se pudo borrar $UID_P"
done
for f in 4 6; do
  echo "SECCION|Consulta de prerregistros por IPv$f"
  ip=10.20.20.11; [ $f = 6 ] && ip="[fd5a:fc7e:d716:20::11]"
  J=$(mktemp)
  c() { curl -s -m 15 --cacert $RAIZ --resolve "consultas.salud.movil:443:$ip" -b $J -c $J "$@"; }
  CSRF=$(c https://consultas.salud.movil/entrar | grep -oE 'name="csrf" value="[^"]+' | cut -d'"' -f4)
  E=$(c -o /dev/null -w '%{http_code}' --data-urlencode usuario=ana.rojas --data-urlencode "clave@"<(printf %s "$AD_CLAVE") --data-urlencode "csrf=$CSRF" https://consultas.salud.movil/entrar)
  [ "$E" = 302 ] && echo "OK|ana.rojas entra con su usuario del dominio (302)" || echo "FALLA|ana.rojas no entra ($E)"
  for codigo in "$@"; do
    c "https://consultas.salud.movil/?q=$codigo" | grep -q "class=\"codigo\">$codigo<" &&
      echo "OK|El prerregistro $codigo aparece en la consulta" || echo "FALLA|El prerregistro $codigo no aparece"
  done
  rm -f $J
done
FIN
  (cd "$ANSIBLE_DIR" && ansible kit01 -m copy -a "src=$CLINICA dest=/tmp/p06-kit01.sh mode=0600" >/dev/null)
  R=$(remoto kit01 "DHIS_CLAVE='{{ vault_dhis2_usuarios_password }}' ADMIN_CLAVE='{{ vault_dhis2_admin_password }}' AD_CLAVE='{{ vault_samba_usuarios_password }}' bash /tmp/p06-kit01.sh $*; rm -f /tmp/p06-kit01.sh")
  echo "$R" | while IFS='|' read -r tipo texto; do
    case $tipo in SECCION) seccion "$texto (desde kit01)" ;; OK) bien "$texto" ;; FALLA) mal "$texto" ;; *) [ -n "$tipo" ] && nota "$tipo" ;; esac
  done
  BIEN=$((BIEN + $(echo "$R" | grep -c '^OK|'))); MAL=$((MAL + $(echo "$R" | grep -c '^FALLA|')))
  nota "Desde un PC de la Interna se registra un paciente en el navegador en la sustentación"
  terminar
  exit
fi

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
