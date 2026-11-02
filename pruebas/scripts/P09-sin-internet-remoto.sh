#!/usr/bin/env bash
# P9 - Pérdida de Internet, simulada en remoto. Se ejecuta desde la máquina de
# control (Ansible del kit, por NetBird). Una tabla de nftables temporal corta
# la salida a Internet de todo el kit sin cortar NetBird, y se borra sola a los
# 15 minutos aunque el script no termine. Durante el corte comprueba los
# servicios desde kit01, desde la red Interna (sw01), desde la Comunidad
# (prueba01, con el portal) y desde las VMs, en IPv4 e IPv6.
#   ./P09-sin-internet-remoto.sh
source "$(dirname "$0")/comun.sh"
exige_ansible
iniciar P09 "Pérdida de Internet (simulada en remoto)"

WAN=enp170s0
DNS_SITIO="192.168.215.20, 192.168.215.30"   # los usa NetBird para encontrar su servidor
TABLA=prueba_sin_internet
CORTE=$TMP_PRUEBAS/corte.nft
cat > "$CORTE" <<FIN
# Corte de Internet para P9. Se borra con "nft delete table inet $TABLA"
table inet $TABLA {
	# Nadie del kit sale a Internet (clientes de la Interna y la Comunidad, y las VMs)
	chain forward {
		type filter hook forward priority filter - 10; policy accept;
		oifname "$WAN" counter drop
	}
	# kit01 sin DNS hacia afuera (reenviadores y raíz), sin NTP y sin apt.
	# Quedan el túnel de NetBird (UDP), su HTTPS y el DNS del sitio
	chain output {
		type filter hook output priority filter - 10; policy accept;
		oifname "$WAN" meta l4proto { tcp, udp } th dport 53 ip daddr != { $DNS_SITIO } counter drop
		oifname "$WAN" udp dport 123 counter drop
		oifname "$WAN" tcp dport 80 counter drop
	}
}
FIN

PSQL="docker exec dhis2-db-1 psql -U dhis -d prerregistro -tAc"
MAC_PRUEBA01=52:54:00:40:00:50

# Una URL desde un equipo del kit: código HTTP o "sin conexión"
http() {  # http <equipo> <4|6> <url> [opciones de curl]
  local eq=$1 f=$2 url=$3; shift 3
  remoto "$eq" "curl -$f -s -o /dev/null -m 8 -w '%{http_code}' $* '$url' || true" | tail -1 | sed 's/^000$/sin conexión/'
}

# Como comprobar, pero acepta cualquiera de varios valores
en() {  # en "descripción" "valor1 valor2" obtenido
  if echo " $2 " | grep -q " $3 "; then bien "$1 ($3)"; else mal "$1 (esperado $2, obtenido ${3:-nada})"; fi
}

seccion "1. Antes del corte"
ROJAS="curl -s 127.0.0.1:9090/api/v1/query --data-urlencode 'query=(probe_success == 0) or (up == 0)' | python3 -c 'import json,sys; print(len(json.load(sys.stdin)[\"data\"][\"result\"]))'"
comprobar "Sondas en rojo" 0 "$(remoto kit01 "$ROJAS")"
comprobar "clinica01 llega a Internet (https://www.google.com)" 200 "$(http clinica01 4 https://www.google.com)"
(cd "$ANSIBLE_DIR" && ansible-playbook playbooks/prueba01.yml >/dev/null 2>&1) && bien "prueba01 encendida (Comunidad)" || mal "No se pudo encender prueba01"
remoto kit01 "nft 'destroy element inet filtro portal_ok { $MAC_PRUEBA01 }'" >/dev/null
bien "prueba01 sin el portal aceptado"

seccion "2. Corte de Internet"
(cd "$ANSIBLE_DIR" && ansible kit01 -b -m copy -a "src=$CORTE dest=/run/$TABLA.nft mode=0600" >/dev/null)
remoto kit01 "nft -c -f /run/$TABLA.nft && nft -f /run/$TABLA.nft && systemd-run --quiet --collect --on-active=900 --unit=fin-$TABLA nft delete table inet $TABLA && date +%T" | sed 's/^/    corte aplicado a las /'
comprobar "Tabla del corte activa" "table inet $TABLA" "$(remoto kit01 "nft list tables | grep $TABLA")"
bien "NetBird sigue: esta máquina de control sigue entrando a kit01"
nota "Se borra sola a los 15 min (fin-$TABLA.timer). Esperando 60 s"
sleep 60

seccion "3. Lo externo falla"
comprobar "clinica01 hacia https://www.google.com" "sin conexión" "$(http clinica01 4 https://www.google.com)"
comprobar "prueba01 hacia https://www.google.com" "sin conexión" "$(http prueba01 4 https://www.google.com)"
EXTERNO=$(remoto kit01 "dig @10.20.20.10 prueba-p9-\$(date +%s).wikipedia.org +time=3 +tries=1 | grep -oE 'status: [A-Z]+|timed out' | head -1")
if echo "$EXTERNO" | grep -qE 'SERVFAIL|timed out'; then bien "Un nombre externo no resuelve ($EXTERNO)"; else mal "Un nombre externo resolvió ($EXTERNO)"; fi
echo "    Contadores del corte:"; remoto kit01 "nft list table inet $TABLA | grep -oE '(oifname|udp|tcp|meta).*packets [0-9]+'" | sed 's/^/      /'

seccion "4. DNS y hora del kit"
for n in pacientes consultas biblioteca videos registro portal archivos; do
  r=$(remoto kit01 "echo \$(dig @10.20.20.10 +short A $n.$DOMINIO | tail -1) \$(dig @fd5a:fc7e:d716:20::10 +short AAAA $n.$DOMINIO | tail -1)")
  if [ "$(echo "$r" | wc -w)" = 2 ]; then bien "$n.$DOMINIO A y AAAA ($r)"; else mal "$n.$DOMINIO no resuelve ($r)"; fi
done
remoto kit01 "chronyc tracking | grep -E 'Stratum|Leap status'" | sed 's/^/    kit01 /'
comprobar "clinica01 toma la hora de kit01" "^*" "$(remoto clinica01 "chronyc -N sources | grep ntp.salud.movil | cut -c1-2")"

seccion "5. Servicios de la Clínica y red Interna"
# HTTPS de clinica01 desde kit01, con la raíz del kit (el fetch de RouterOS no
# negocia el TLS de Caddy)
for ip in 10.20.20.11 "[fd5a:fc7e:d716:20::11]"; do
  comprobar "DHIS2 por $ip" 200 "$(remoto kit01 "curl -s -o /dev/null -m 8 -w '%{http_code}' --cacert /etc/kitsalud/ca/raiz.crt --resolve 'pacientes.$DOMINIO:443:$ip' https://pacientes.$DOMINIO/dhis-web-login/ || true" | tail -1)"
  comprobar "Consulta de prerregistros por $ip" 200 "$(remoto kit01 "curl -s -o /dev/null -m 8 -w '%{http_code}' --cacert /etc/kitsalud/ca/raiz.crt --resolve 'consultas.$DOMINIO:443:$ip' https://consultas.$DOMINIO/entrar || true" | tail -1)"
done
# Desde sw01, que está en la red Interna, la biblioteca por HTTP
for f in 10.20.20.12 "[fd5a:fc7e:d716:20::12]"; do
  comprobar "sw01 (Interna) llega a la biblioteca por $f" "status: finished" "$(sw01_fetch "http://$f/" "biblioteca.$DOMINIO")"
done
SMB=$(remoto clinica01 "export PASSWD='{{ vault_samba_usuarios_password }}'; smbclient //archivos.$DOMINIO/archivos -U ana.rojas -m SMB3 -c ls >/dev/null 2>&1 && echo abre || echo falla")
comprobar "Recurso archivos por SMB con ana.rojas" abre "$SMB"

seccion "6. Comunidad (prueba01)"
for f in 4 6; do
  comprobar "IPv$f biblioteca sin aceptar el portal (redirige)" 302 "$(http prueba01 $f "http://biblioteca.$DOMINIO/")"
done
remoto prueba01 "curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Host: portal.$DOMINIO' http://10.20.40.1/aceptar" | tail -1 | grep -q 303 && bien "Portal aceptado sin Internet" || mal "No se pudo aceptar el portal"
remoto prueba01 "curl -s -m 8 -o /tmp/raiz-kit.crt http://ca.$DOMINIO/raiz.crt" >/dev/null
for f in 4 6; do
  en "IPv$f biblioteca" "200 302" "$(http prueba01 $f "http://biblioteca.$DOMINIO/")"
  en "IPv$f videos" "200 302" "$(http prueba01 $f "http://videos.$DOMINIO/")"
  en "IPv$f registro (HTTPS con la raíz del kit)" "200 302" "$(http prueba01 $f "https://registro.$DOMINIO/" --cacert /tmp/raiz-kit.crt)"
done
CODIGO=$(remoto prueba01 "curl -s -m 10 --cacert /tmp/raiz-kit.crt -d nombres=Prueba -d apellidos=SinInternet -d tipo_documento=NINGUNO -d motivo=CONTROL -d autoriza_datos=si https://registro.$DOMINIO/ | grep -oE 'class=\"codigo\"[^>]*>[A-Z0-9]{4}' | grep -oE '[A-Z0-9]{4}\$'")
CODIGO=$(echo "$CODIGO" | tail -1)
if [ -n "$CODIGO" ] && [ "$(remoto clinica01 "$PSQL \"select count(*) from prerregistros where codigo = '$CODIGO'\"")" = 1 ]; then
  bien "Prerregistro enviado sin Internet y guardado en clinica01 (código $CODIGO)"
else
  mal "El prerregistro no se guardó (código '${CODIGO}')"
fi

seccion "7. Estado general durante el corte"
comprobar "Sondas en rojo" 0 "$(remoto kit01 "$ROJAS")"
comprobar "Unidades fallidas en kit01" 0 "$(remoto kit01 "systemctl --failed --no-legend | grep -vc systemd-networkd-wait-online || true" | tail -1)"

seccion "8. Fin del corte"
comprobar "Tabla del corte borrada" 0 "$(remoto kit01 "nft delete table inet $TABLA; systemctl stop fin-$TABLA.timer 2>/dev/null; rm -f /run/$TABLA.nft; nft list tables | grep -c $TABLA || true" | tail -1)"
sleep 5
comprobar "clinica01 llega a Internet otra vez" 200 "$(http clinica01 4 https://www.google.com)"
[ -n "$CODIGO" ] && remoto clinica01 "$PSQL \"delete from prerregistros where codigo = '$CODIGO' and apellidos = 'SinInternet'\"" >/dev/null && bien "Prerregistro de prueba borrado"
remoto kit01 "nft 'destroy element inet filtro portal_ok { $MAC_PRUEBA01 }'; virsh -c qemu:///system shutdown prueba01" >/dev/null && bien "prueba01 sin portal y apagándose"
terminar
