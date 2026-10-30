#!/usr/bin/env bash
# P7 - Identidad. Revisa con usuarios del dominio AD el recurso SMB archivos
# (desde la Clínica) y el login de Grafana por LDAP (por NetBird, sin tocar
# /etc/hosts). Pide las contraseñas; no las guarda.
#   ./P07-identidad.sh smb       recurso archivos (ana.rojas entra, laura.gomez no)
#   ./P07-identidad.sh grafana   Grafana por NetBird (laura.gomez entra, ana.rojas no)
source "$(dirname "$0")/comun.sh"
iniciar P07 "Identidad"
MODO=${1:-smb}

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
  if RAIZ=$(raiz_kit); then CERT=(--cacert "$RAIZ"); else CERT=(-k); nota "Sin acceso a ca.$DOMINIO: no se verifica el certificado"; fi
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
