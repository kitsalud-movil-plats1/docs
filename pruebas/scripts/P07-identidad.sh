#!/usr/bin/env bash
# P7 - Identidad. Revisa con usuarios del dominio AD el recurso SMB archivos
# (desde la Clínica) y el login de Grafana por LDAP (por NetBird, sin tocar
# /etc/hosts). Pide las contraseñas; no las guarda.
#   ./P07-identidad.sh smb           recurso archivos (ana.rojas entra, laura.gomez no)
#   ./P07-identidad.sh grafana       Grafana por NetBird (laura.gomez entra, ana.rojas no)
#   ./P07-identidad.sh smb-remoto    desde la máquina de control: sw01 (Interna) abre
#                                    el 445 y los usuarios prueban archivos en clinica01
# Con --vault como segundo argumento, en la máquina de control, las claves de los
# usuarios del dominio salen del vault del kit en vez de pedirse.
source "$(dirname "$0")/comun.sh"
iniciar P07 "Identidad"
MODO=${1:-smb}

if [ "$2" = --vault ]; then
  exige_ansible
  CLAVE_AD=$(cd "$ANSIBLE_DIR" && ansible-vault view inventarios/kit/group_vars/all/vault.yml | python3 -c "import sys,yaml; print(yaml.safe_load(sys.stdin)['vault_samba_usuarios_password'])")
  pedir_clave() { printf '%s' "$CLAVE_AD"; }
fi

if [ "$MODO" = smb-remoto ]; then
  exige_ansible
  seccion "Desde la Interna (sw01) hacia el 445 de clinica01"
  # sw01 no habla SMB; si /tool fetch pasa de "connecting" la conexión TCP se abrió
  for ip in 10.20.20.11 "[fd5a:fc7e:d716:20::11]"; do
    R=$(sw01_fetch "http://$ip:445/" "archivos.$DOMINIO")
    case $R in "status: connecting"|"") mal "sw01 no abre $ip puerto 445 ($R)" ;; *) bien "sw01 abre $ip puerto 445 ($R)" ;; esac
  done
  for ip in 10.20.20.11 fd5a:fc7e:d716:20::11; do
    seccion "archivos por $ip con usuarios del dominio (en clinica01)"
    # smbclient lee la clave de PASSWD; el vault la pone en el comando sin que
    # quede en el syslog
    for u in ana.rojas laura.gomez; do
      R=$(remoto clinica01 "export PASSWD='{{ vault_samba_usuarios_password }}'; S=\$(mktemp); smbclient //archivos.$DOMINIO/archivos -I $ip -U 'AD\\$u' -m SMB3 -c ls >\$S 2>&1; e=\$?; tail -3 \$S; rm -f \$S; echo fin \$e")
      echo "$R" | grep -v '^fin ' | sed 's/^/    /'
      case $u:$(echo "$R" | awk '/^fin /{print $2}') in
        ana.rojas:0) bien "ana.rojas (clinicos) entra a archivos por SMB3" ;;
        ana.rojas:*) mal "ana.rojas no entra a archivos" ;;
        laura.gomez:0) mal "laura.gomez entra a archivos y no debería" ;;
        laura.gomez:*) bien "laura.gomez (admins) no entra a archivos" ;;
      esac
    done
  done
  seccion "Lo que exige el servidor"
  comprobar "Protocolo mínimo del servidor" SMB3 "$(remoto clinica01 "testparm -s --parameter-name='server min protocol' 2>/dev/null")"
  comprobar "Cifrado en archivos" required "$(remoto clinica01 "testparm -s --section-name=archivos --parameter-name='smb encrypt' 2>/dev/null")"
  terminar
  exit
fi

# Lista el recurso con un usuario del dominio; 0 si entra
smb_lista() {  # smb_lista usuario clave
  if [ "$SO" = Darwin ]; then
    local m=$TMP_PRUEBAS/smb-$1
    mkdir -p "$m"
    if mount_smbfs "//AD;$1:$(printf %s "$2" | sed 's/@/%40/g')@archivos.$DOMINIO/archivos" "$m" 2>/dev/null; then
      ls -la "$m" | sed 's/^/    /'; umount "$m"; return 0
    fi
    return 1
  elif command -v smbclient >/dev/null; then
    smbclient "//archivos.$DOMINIO/archivos" -U "AD\\$1%$2" -m SMB3 -c 'ls' 2>&1 | sed 's/^/    /'
    return "${PIPESTATUS[0]}"
  else
    echo "Falta smbclient (paquete samba-client en Fedora, smbclient en Ubuntu)"; exit 2
  fi
}

if [ "$MODO" = smb ]; then
  [ "$(red_actual)" = interna ] || { echo "Conectarse a SaludMovil-Clinica"; exit 2; }
  revisar_hosts
  seccion "archivos con ana.rojas (grupo clinicos)"
  if smb_lista ana.rojas "$(pedir_clave ana.rojas)"; then bien "ana.rojas entra a archivos por SMB3"; else mal "ana.rojas no entra a archivos"; fi
  seccion "archivos con laura.gomez (grupo admins)"
  if smb_lista laura.gomez "$(pedir_clave laura.gomez)"; then mal "laura.gomez entra a archivos y no debería"; else bien "laura.gomez no entra (no es de clinicos)"; fi
  nota "En clinica01, sudo smbstatus -b muestra la sesión con SMB3_11 y el cifrado AES-128-GCM de archivos"
else
  seccion "Grafana por NetBird ($KIT01_NETBIRD)"
  # La raíz está en comunidad01; si el equipo no llega a ella (fuera del kit),
  # se omite la verificación del certificado
  # Fuera del kit, con el Ansible del kit, la raíz se toma de kit01
  if ! RAIZ=$(raiz_kit) && [ -f "$ANSIBLE_DIR/ansible.cfg" ]; then
    RAIZ=$TMP_PRUEBAS/raiz.crt
    remoto kit01 "cat /etc/kitsalud/ca/raiz.crt" > "$RAIZ"
    grep -q 'BEGIN CERTIFICATE' "$RAIZ" && nota "Raíz del kit tomada de kit01" || RAIZ=
  fi
  if [ -n "$RAIZ" ]; then CERT=(--cacert "$RAIZ"); else CERT=(-k); nota "Sin la raíz del kit: no se verifica el certificado"; fi
  grafana() {  # grafana usuario clave → respuesta y código
    curl -s -m 15 "${CERT[@]}" --resolve "monitoreo.$DOMINIO:443:$KIT01_NETBIRD" -u "$1:$2" \
      -w ' %{http_code}' "https://monitoreo.$DOMINIO/api/user"
  }
  R=$(grafana laura.gomez "$(pedir_clave laura.gomez)")
  case $R in *'"login":"laura.gomez"'*' 200') bien "laura.gomez (admins) entra a Grafana; isGrafanaAdmin $(echo "$R" | grep -o '"isGrafanaAdmin":[a-z]*' | cut -d: -f2)" ;; *) mal "laura.gomez no entra a Grafana (${R##* })" ;; esac
  R=$(grafana ana.rojas "$(pedir_clave ana.rojas)")
  case $R in *' 401') bien "ana.rojas (clinicos) no entra a Grafana (401)" ;; *) mal "ana.rojas obtuvo ${R##* } en Grafana" ;; esac
  nota "En kit01: journalctl -u grafana-server --since -10min | grep -i ldap"
fi
terminar
