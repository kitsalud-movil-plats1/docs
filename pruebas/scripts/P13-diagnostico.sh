#!/usr/bin/env bash
# P13 - Diagnóstico. Se ejecuta desde la máquina de control (Ansible del kit,
# por NetBird). Induce una falla, espera a que Prometheus la detecte, junta lo
# que se usa para localizarla (alertas, systemctl, journal, logs centrales y el
# síntoma), restaura y comprueba que las alertas se apagan. Mientras corre,
# abrir Grafana (Estado del kit) para la captura.
#   ./P13-diagnostico.sh [dns|postgres]     (por defecto dns)
source "$(dirname "$0")/comun.sh"
exige_ansible
iniciar P13 "Diagnóstico"

FALLA=${1:-dns}
case $FALLA in
  dns)
    EQUIPO=kit01; ROMPER="systemctl stop named"; ARREGLAR="systemctl start named"
    SINTOMA="dig @10.20.20.10 pacientes.$DOMINIO +time=2 +tries=1 | grep -E 'status|connection|timed'"
    CAUSA="systemctl status named --no-pager | head -5; journalctl -u named --since -5min -o cat --no-pager | tail -5; ss -lunp | grep ':53 ' || echo 'nada escucha en el 53/udp'"
    LOG="tail -3 /var/log/kitsalud/kit01/dns.log"
    ;;
  postgres)
    EQUIPO=clinica01; ROMPER="docker stop dhis2-db-1"; ARREGLAR="docker start dhis2-db-1"
    SINTOMA="curl -s -o /dev/null -w 'DHIS2 responde %{http_code}\n' -m 10 http://127.0.0.1:8080/api/system/ping"
    CAUSA="docker ps -a --filter name=dhis2-db --format '{% raw %}{{.Names}} {{.Status}}{% endraw %}'; docker logs --tail 5 dhis2-core-1 2>&1"
    LOG="grep -h -i -E 'postgres|dhis2|database' /var/log/syslog | tail -3"
    ;;
  *) echo "Falla desconocida: $FALLA (dns o postgres)"; exit 2 ;;
esac

alertas() {
  remoto kit01 "curl -s http://127.0.0.1:9090/api/v1/alerts | python3 -c 'import json,sys; [print(a[\"labels\"][\"alertname\"], a[\"labels\"].get(\"equipo\", \"\"), a[\"labels\"].get(\"servicio\", a[\"labels\"].get(\"name\", \"\")), a[\"labels\"].get(\"familia\", \"\"), a[\"state\"]) for a in json.load(sys.stdin)[\"data\"][\"alerts\"]]'"
}

seccion "Antes"
ANTES=$(alertas)
echo "${ANTES:-    (sin alertas)}" | sed 's/^/    /'

seccion "Falla inducida en $EQUIPO: $ROMPER"
confirmar "¿Inducir la falla ahora?" || exit 1
remoto $EQUIPO "$ROMPER" >/dev/null
echo "    $(date '+%H:%M:%S') falla inducida; esperando 75 s a que Prometheus la detecte"
sleep 75

seccion "Lo que ve el administrador"
DURANTE=$(alertas)
echo "$DURANTE" | sed 's/^/    /'
NUEVAS=$(echo "$DURANTE" | grep firing | grep -v -x -F "$ANTES")
if [ -n "$NUEVAS" ]; then bien "Prometheus detectó la falla"; else mal "No apareció ninguna alerta nueva"; fi
echo "    Síntoma:"; remoto $EQUIPO "$SINTOMA" | sed 's/^/      /'
echo "    Causa:"; remoto $EQUIPO "$CAUSA" | sed 's/^/      /'
echo "    Log:"; remoto $EQUIPO "$LOG" | sed 's/^/      /'

seccion "Restauración: $ARREGLAR"
remoto $EQUIPO "$ARREGLAR" >/dev/null
echo "    $(date '+%H:%M:%S') restaurado; esperando 90 s"
sleep 90
DESPUES=$(alertas)
echo "${DESPUES:-    (sin alertas)}" | sed 's/^/    /'
QUEDAN=$(echo "$DESPUES" | grep firing | grep -v -x -F "$ANTES")
if [ -z "$QUEDAN" ]; then bien "Las alertas de la falla se apagaron"; else mal "Siguen alertas de la falla"; fi

nota "Para la evidencia: captura de Estado del kit durante y después, y dos o tres frases con causa, impacto y arreglo"
terminar
