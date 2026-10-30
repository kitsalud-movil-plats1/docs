#!/usr/bin/env bash
# P8 - Tiempo. Se ejecuta desde la máquina de control (Ansible del kit, por
# NetBird). Revisa que kit01 sirve la hora y que clinica01 y comunidad01 la
# toman de él. Con --estacion revisa además el desfase de este equipo contra
# ntp.salud.movil, sin cambiar su hora (el equipo tiene que estar en el kit).
#   ./P08-tiempo.sh [--estacion]
source "$(dirname "$0")/comun.sh"
exige_ansible
iniciar P08 "Tiempo"

seccion "kit01, servidor NTP"
T=$(remoto kit01 "chronyc tracking")
echo "$T" | sed 's/^/    /'
ESTRATO=$(echo "$T" | awk -F': ' '/^Stratum/{print $2}')
if echo "$T" | grep -q "Leap status *: Normal"; then bien "kit01 sincronizado (estrato $ESTRATO; 10 indica modo orphan, sin Internet)"; else mal "kit01 no está sincronizado"; fi
C=$(remoto kit01 "chronyc -n clients")
echo "$C" | sed 's/^/    /'
for ip in 10.20.20.11 fd5a:fc7e:d716:20::12; do
  if echo "$C" | grep -q "^$ip "; then bien "kit01 atiende a $ip"; else nota "$ip no aparece en chronyc clients (puede usar la otra familia)"; fi
done

for vm in clinica01 comunidad01; do
  seccion "$vm, cliente"
  S=$(remoto $vm "chronyc -n sources; chronyc tracking")
  echo "$S" | sed 's/^/    /'
  if echo "$S" | grep -q -E '^\^\* (10\.20\.20\.10|fd5a:fc7e:d716:20::10)'; then bien "$vm usa kit01 como fuente (^*)"; else mal "$vm no tiene a kit01 como fuente elegida"; fi
  DESFASE=$(echo "$S" | awk -F': ' '/^System time/{print $2}')
  nota "Desfase de $vm con kit01: $DESFASE"
done

if [ "$1" = --estacion ]; then
  seccion "Esta estación contra ntp.$DOMINIO"
  if [ "$SO" = Darwin ]; then
    sntp "ntp.$DOMINIO" 2>&1 | sed 's/^/    /' && bien "sntp obtuvo la hora de ntp.$DOMINIO" || mal "sntp no obtuvo respuesta"
  else
    sudo chronyd -Q "server ntp.$DOMINIO iburst" 2>&1 | sed 's/^/    /' && bien "chronyd -Q obtuvo la hora de ntp.$DOMINIO" || mal "chronyd -Q no obtuvo respuesta"
  fi
fi

nota "sw01: /system ntp client print (status synchronized, servidor 10.20.20.10)"
terminar
