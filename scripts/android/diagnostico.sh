#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Diagnóstico completo de un dispositivo Android vía ADB.
#
# Requiere:
#   · adb instalado en la máquina del técnico.
#   · Depuración USB activada en el móvil (o ADB inalámbrico).
#   · Dispositivo conectado y autorizado.
#
# Uso:
#   bash diagnostico.sh                          # primer dispositivo
#   bash diagnostico.sh <serial>                 # dispositivo concreto
#   bash diagnostico.sh <serial> /tmp            # salida en /tmp
#   bash diagnostico.sh --ticket 42              # diagnosticos/tickets/00042/diagnostico.json
#
# Modelo de salida: PLANO (las claves cuelgan de la raiz, no de hardware{}).
# Cada bloque es best-effort: si una metrica falla, el resto se completa igual
# y el campo cae a "" o a su valor por defecto blindado para no romper el JSON.
#
# Autor:   Francisco Vidal Mateo (GitHub: Haplee)
# Versión: 3.0
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

# ── Dependencias ────────────────────────────────────────────────────────────

if ! command -v adb >/dev/null 2>&1; then
    echo "ERROR: 'adb' no está instalado o no está en el PATH." >&2
    echo "       En Ubuntu/Debian:   sudo apt install android-tools-adb" >&2
    echo "       En macOS (brew):    brew install android-platform-tools" >&2
    exit 1
fi

# Fuerza punto decimal: en locales es_ES el awk emite coma y rompe el JSON.
export LC_ALL=C

# ── Argumentos ────────────────────────────────────────────────────────────────
# [serial]        primer posicional: serial ADB (uso historico)
# [dir]           segundo posicional u --output <dir>: carpeta explicita
# --ticket <N>    organiza la salida en diagnosticos/tickets/<NNNNN>/diagnostico.json
SERIAL=""
OUTPUT_DIR=""
TICKET=""
_pos=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ticket) TICKET="${2:-}"; shift 2 ;;
        --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
        *)
            if [[ $_pos -eq 0 ]]; then SERIAL="$1"
            elif [[ -z "$OUTPUT_DIR" ]]; then OUTPUT_DIR="$1"; fi
            _pos=$((_pos + 1)); shift ;;
    esac
done

# Resolucion de carpeta de salida (organizada por ticket).
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE_REP="${RC_REPARACIONES_DIR:-$REPO_ROOT/diagnosticos/tickets}"
if [[ -n "$OUTPUT_DIR" ]]; then
    DEST_DIR="$OUTPUT_DIR"
elif [[ "$TICKET" =~ ^[0-9]+$ ]]; then
    DEST_DIR="$BASE_REP/$(printf '%05d' "$TICKET")/android"
else
    DEST_DIR="$BASE_REP/sin-ticket/android"
    echo "[!] No se ha indicado ticket. Guardando en diagnosticos/tickets/sin-ticket/android/"
fi
mkdir -p "$DEST_DIR"

# Si nos pasan serial, hablamos solo con ese dispositivo. Si no, ADB
# escogerá el único conectado (o fallará si hay varios).
# Validamos el serial: se interpola en la cadena $ADB que luego se ejecuta, así
# que un serial con metacaracteres (`;`, `$()`...) permitiría inyección de
# comandos en la máquina del técnico.
if [ -n "${SERIAL:-}" ] && ! printf '%s' "$SERIAL" | grep -Eq '^[A-Za-z0-9._:-]+$'; then
    echo "ERROR: serial ADB inválido (solo letras, dígitos y . _ : -)." >&2
    exit 1
fi
ADB="adb${SERIAL:+ -s $SERIAL}"

# Comprobamos que el dispositivo esté autorizado.
if ! $ADB get-state >/dev/null 2>&1; then
    echo "ERROR: dispositivo no conectado o no autorizado." >&2
    echo "       Acepta la huella del PC en el aviso del móvil." >&2
    exit 1
fi

# ── Helpers ──────────────────────────────────────────────────────────────────
# prop: lee un getprop y limpia CRLF (ADB en Windows/Git Bash mete CRLF).
prop() { $ADB shell getprop "$1" 2>/dev/null | tr -d '\r\n'; }
# json_escape: escapa comillas y barras para meter strings libres en el JSON.
json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
# adb_vivo: true si el dispositivo sigue en estado "device" (no se ha caído el
# cable USB ni el Wi-Fi a mitad de la recogida).
adb_vivo() { [ "$($ADB get-state 2>/dev/null | tr -d '\r\n')" = "device" ]; }

# ── Identidad del dispositivo ────────────────────────────────────────────────
DEVICE=$(prop ro.product.model)
fabricante=$(prop ro.product.manufacturer)
marca=$(prop ro.product.brand)
modelo_interno=$(prop ro.product.device)
hardware=$(prop ro.hardware)
ANDROID=$(prop ro.build.version.release)
SDK=$(prop ro.build.version.sdk)
build_id=$(prop ro.build.display.id)
fingerprint=$(prop ro.build.fingerprint)
seguridad_patch=$(prop ro.build.version.security_patch)
kernel=$($ADB shell uname -r 2>/dev/null | tr -d '\r\n')

# Uptime del dispositivo (segundos -> horas).
uptime_s=$($ADB shell cat /proc/uptime 2>/dev/null | awk '{print $1}' | tr -d '\r')
uptime_horas=$(awk "BEGIN{printf \"%.1f\", ${uptime_s:-0}/3600}")

# Si el dispositivo se ha desconectado a mitad, abortamos en vez de seguir
# emitiendo ceros falsos que corromperían las métricas del JSON.
if ! adb_vivo; then
    echo "ERROR: dispositivo desconectado durante la recogida. JSON incompleto." >&2
    exit 1
fi

# ── Batería (completa) ───────────────────────────────────────────────────────
# Capturamos dumpsys battery una sola vez y troceamos. La temperatura viene en
# decimas de grado (340 = 34.0 °C); el voltaje en mV.
BATT=$($ADB shell dumpsys battery 2>/dev/null | tr -d '\r')
# OJO: usamos coincidencia EXACTA del primer campo ($1=="voltage:") en vez de
# /voltage:/, porque dumpsys battery incluye lineas como "Max charging voltage:"
# que tambien contienen la subcadena y, al casar dos lineas, metian un valor
# multilinea ("5000000\n4125") que rompia el JSON. $1== ignora la indentacion.
bat_level=$(echo "$BATT"  | awk '$1=="level:"{print $2; exit}')
bat_temp=$(echo "$BATT"   | awk '$1=="temperature:"{print $2; exit}')
bat_volt=$(echo "$BATT"   | awk '$1=="voltage:"{print $2; exit}')
bat_tech=$(echo "$BATT"   | awk '$1=="technology:"{print $2; exit}')
bat_status_n=$(echo "$BATT" | awk '$1=="status:"{print $2; exit}')
bat_health_n=$(echo "$BATT" | awk '$1=="health:"{print $2; exit}')

# Mapeo de codigos numericos de dumpsys battery a texto legible.
case "${bat_status_n:-0}" in
    2) bat_estado="Cargando" ;; 3) bat_estado="Descargando" ;;
    4) bat_estado="No carga" ;; 5) bat_estado="Llena" ;; *) bat_estado="Desconocido" ;;
esac
case "${bat_health_n:-0}" in
    2) bat_salud="Buena" ;; 3) bat_salud="Sobrecalentada" ;; 4) bat_salud="Agotada" ;;
    5) bat_salud="Sobretension" ;; 6) bat_salud="Fallo" ;; 7) bat_salud="Fria" ;;
    *) bat_salud="Desconocida" ;;
esac

# Fuente de alimentacion actual.
if   echo "$BATT" | grep -qi 'AC powered: true';       then bat_fuente="ac"
elif echo "$BATT" | grep -qi 'USB powered: true';      then bat_fuente="usb"
elif echo "$BATT" | grep -qi 'Wireless powered: true'; then bat_fuente="wireless"
else bat_fuente="bateria"; fi

# Ciclos de carga (best-effort; suele requerir root o no exponerse -> null).
bat_ciclos=$($ADB shell cat /sys/class/power_supply/battery/cycle_count 2>/dev/null | tr -d '\r\n')

# ── CPU ──────────────────────────────────────────────────────────────────────
cpu_cores=$($ADB shell cat /proc/cpuinfo 2>/dev/null | grep -c '^processor')
cpu_load=$($ADB shell cat /proc/loadavg 2>/dev/null | awk '{print $1}' | tr -d '\r')
cpu_modelo=$(prop ro.soc.model); [ -z "$cpu_modelo" ] && cpu_modelo=$(prop ro.board.platform)
# Uso global de CPU desde la linea TOTAL de dumpsys cpuinfo (best-effort).
cpu_uso=$($ADB shell dumpsys cpuinfo 2>/dev/null | tr -d '\r' \
    | awk '/TOTAL:/{sub(/%.*/,""); gsub(/[^0-9.]/,""); print; exit}')

# ── RAM ──────────────────────────────────────────────────────────────────────
MEM=$($ADB shell cat /proc/meminfo 2>/dev/null | tr -d '\r')
mem_total_kb=$(echo "$MEM" | awk '/^MemTotal/{print $2}')
mem_avail_kb=$(echo "$MEM" | awk '/^MemAvailable/{print $2}')
ram_total_gb=$(awk "BEGIN{printf \"%.1f\", ${mem_total_kb:-0}/1048576}")
ram_libre_gb=$(awk "BEGIN{printf \"%.1f\", ${mem_avail_kb:-0}/1048576}")

# ── Almacenamiento ───────────────────────────────────────────────────────────
# /data (espacio de apps y usuario). df en bloques de 1K: total used avail use%.
DF_DATA=$($ADB shell df /data 2>/dev/null | tr -d '\r' | awk 'NR==2{print $2,$3,$4,$5}')
data_total=$(echo "$DF_DATA" | awk '{print $1}')
data_avail=$(echo "$DF_DATA" | awk '{print $3}')
data_usep=$(echo "$DF_DATA"  | awk '{gsub(/%/,"",$4); print $4}')
data_total_gb=$(awk "BEGIN{printf \"%.1f\", ${data_total:-0}/1048576}")
data_libre_gb=$(awk "BEGIN{printf \"%.1f\", ${data_avail:-0}/1048576}")
# Legacy: cadena "TOTAL LIBRE" en bloques 1K (consumida por generar_informe).
storage="${data_total:-0} ${data_avail:-0}"

# ── Pantalla ─────────────────────────────────────────────────────────────────
pant_res=$($ADB shell wm size 2>/dev/null | tr -d '\r' | awk -F': ' '/Physical size/{print $2; exit}')
[ -z "$pant_res" ] && pant_res=$($ADB shell wm size 2>/dev/null | tr -d '\r' | awk -F': ' '/size/{print $2; exit}')
pant_dpi=$($ADB shell wm density 2>/dev/null | tr -d '\r' | awk -F': ' '/Physical density/{print $2; exit}')

# ── Red ──────────────────────────────────────────────────────────────────────
# IP de wlan0 (Wi-Fi) y best-effort de la interfaz de datos moviles.
ip_local=$($ADB shell ip -o -4 addr show wlan0 2>/dev/null | awk '{print $4}' | head -1 | tr -d '\r')
ip_movil=$($ADB shell ip -o -4 addr show 2>/dev/null | tr -d '\r' \
    | awk '$2!="lo" && $2!="wlan0"{print $4; exit}')
mac_wifi=$($ADB shell cat /sys/class/net/wlan0/address 2>/dev/null | tr -d '\r\n')

# Datos de la asociacion Wi-Fi actual (SSID/RSSI/velocidad) desde dumpsys wifi.
WIFI=$($ADB shell dumpsys wifi 2>/dev/null | tr -d '\r' | grep -m1 'SSID:')
# El [^B] evita capturar el BSSID (que tambien contiene la subcadena "SSID:").
wifi_ssid=$(echo "$WIFI" | sed -n 's/.*[^B]SSID: \([^,]*\),.*/\1/p' | tr -d '"')
wifi_rssi=$(echo "$WIFI" | sed -n 's/.*RSSI: \(-\{0,1\}[0-9]\{1,\}\).*/\1/p')
wifi_speed=$(echo "$WIFI" | sed -n 's/.*Link speed: \([0-9]\{1,\}\)Mbps.*/\1/p')

# Operador movil y tipo de red. En dual-SIM estas props vienen separadas por
# coma ("Orange," / "LTE,Unknown"): nos quedamos con el primer valor no vacio.
red_operador=$(prop gsm.operator.alpha); [ -z "$red_operador" ] && red_operador=$(prop gsm.sim.operator.alpha)
red_operador=$(echo "$red_operador" | awk -F, '{for(i=1;i<=NF;i++) if($i!=""){print $i; exit}}')
red_tipo=$(prop gsm.network.type | awk -F, '{print $1}')

# ── Seguridad ────────────────────────────────────────────────────────────────
sec_cifrado=$(prop ro.crypto.state)
sec_selinux=$($ADB shell getenforce 2>/dev/null | tr -d '\r\n')
sec_vbs=$(prop ro.boot.verifiedbootstate)
sec_locked=$(prop ro.boot.flash.locked)
case "$sec_locked" in 1) sec_locked_bool=true ;; 0) sec_locked_bool=false ;; *) sec_locked_bool=null ;; esac
# Deteccion de root: presencia del binario su en el PATH del dispositivo.
su_path=$($ADB shell 'command -v su' 2>/dev/null | tr -d '\r\n')
[ -n "$su_path" ] && root_bool=true || root_bool=false
# ADB inalambrico activo si hay puerto TCP de adb configurado.
adb_port=$(prop service.adb.tcp.port)
[ -n "$adb_port" ] && adbwifi_bool=true || adbwifi_bool=false

# ── Apps instaladas ──────────────────────────────────────────────────────────
apps_total=$($ADB shell pm list packages 2>/dev/null | tr -d '\r' | grep -c 'package:')
apps_terceros=$($ADB shell pm list packages -3 2>/dev/null | tr -d '\r' | grep -c 'package:')
apps_desh=$($ADB shell pm list packages -d 2>/dev/null | tr -d '\r' | grep -c 'package:')

# ── Térmico ──────────────────────────────────────────────────────────────────
# Maximo de las thermal_zone del sistema. Normalizamos: si el valor es grande
# (>1000) viene en mili-grados (38500 = 38.5 °C); si no, ya esta en °C.
term_raw=$($ADB shell 'cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null' \
    | tr -d '\r' | grep -E '^-?[0-9]+$' | sort -n | tail -1)
if [ -n "$term_raw" ]; then
    term_max_c=$(awk "BEGIN{v=${term_raw}; if(v>1000) v=v/1000; printf \"%.1f\", v}")
else
    term_max_c=null
fi

# ── Procesos top por CPU (toybox top) ────────────────────────────────────────
procesos_json=""
while IFS= read -r linea; do
    [ -z "$linea" ] && continue
    linea=$(echo "$linea" | tr -d '\r' | sed 's/"/\\"/g')
    [ -n "$procesos_json" ] && procesos_json="$procesos_json,"
    procesos_json="$procesos_json\"$linea\""
done < <($ADB shell top -b -n 1 2>/dev/null | awk 'NR>6 {print $NF" "$(NF-2)}' | head -8)

# ── Nombre del fichero de salida ─────────────────────────────────────────────
TS=$(date +%Y%m%d_%H%M%S)
DEVICE_SAFE="${DEVICE// /_}"
if [[ "$TICKET" =~ ^[0-9]+$ && -z "$OUTPUT_DIR" ]]; then
    # Modo ticket: nombre fijo, con sufijo _vN si ya existe.
    FILE="$DEST_DIR/diagnostico.json"
    if [[ -f "$FILE" ]]; then
        n=2
        while [[ -f "$DEST_DIR/diagnostico_v$n.json" ]]; do n=$((n + 1)); done
        FILE="$DEST_DIR/diagnostico_v$n.json"
        echo "[i] Ya existia diagnostico.json; guardando como $(basename "$FILE")"
    fi
else
    FILE="$DEST_DIR/diagnostico_android_${DEVICE_SAFE}_${TS}.json"
fi

# ── Blindaje de campos ───────────────────────────────────────────────────────
# Numericos vacios romperian el JSON ("nivel": ,). Ponemos 0 / null segun toque.
SDK=${SDK:-0}
bat_level=${bat_level:-0}
bat_temp=${bat_temp:-0}
bat_volt=${bat_volt:-0}
bat_ciclos=${bat_ciclos:-null}
cpu_cores=${cpu_cores:-0}
cpu_load=${cpu_load:-0}
cpu_uso=${cpu_uso:-null}
data_usep=${data_usep:-0}
pant_dpi=${pant_dpi:-0}
wifi_rssi=${wifi_rssi:-null}
wifi_speed=${wifi_speed:-null}
apps_total=${apps_total:-0}
apps_terceros=${apps_terceros:-0}
apps_desh=${apps_desh:-0}
procesos_json=${procesos_json:-}

# Strings libres -> escapados para el JSON.
bat_tech_e=$(json_escape "$bat_tech")
fingerprint_e=$(json_escape "$fingerprint")
build_id_e=$(json_escape "$build_id")
cpu_modelo_e=$(json_escape "$cpu_modelo")
pant_res_e=$(json_escape "$pant_res")
wifi_ssid_e=$(json_escape "$wifi_ssid")
red_operador_e=$(json_escape "$red_operador")

bat_temp_c=$(awk "BEGIN{printf \"%.1f\", ${bat_temp:-0}/10}")

# ── Volcado JSON (modelo plano) ──────────────────────────────────────────────
cat > "$FILE" <<EOF
{
  "_meta": {
    "plataforma": "android",
    "hostname": "$DEVICE",
    "version": "3.0"
  },
  "timestamp": "$(date -Iseconds)",
  "dispositivo": "$DEVICE",
  "fabricante": "$fabricante",
  "marca": "$marca",
  "modelo_interno": "$modelo_interno",
  "hardware": "$hardware",
  "android": "$ANDROID",
  "sdk": $SDK,
  "build": "$build_id_e",
  "fingerprint": "$fingerprint_e",
  "parche_seguridad": "$seguridad_patch",
  "kernel": "$kernel",
  "uptime_horas": $uptime_horas,
  "bateria": {
    "nivel": $bat_level,
    "temp_decimas_grado": $bat_temp,
    "temp_c": $bat_temp_c,
    "estado": "$bat_estado",
    "salud": "$bat_salud",
    "voltaje_mv": $bat_volt,
    "tecnologia": "$bat_tech_e",
    "fuente": "$bat_fuente",
    "ciclos": $bat_ciclos
  },
  "cpu": {
    "modelo": "$cpu_modelo_e",
    "cores": $cpu_cores,
    "carga_1min": $cpu_load,
    "uso_pct": $cpu_uso
  },
  "ram": {
    "total_gb": $ram_total_gb,
    "libre_gb": $ram_libre_gb
  },
  "almacenamiento": {
    "data_total_gb": $data_total_gb,
    "data_libre_gb": $data_libre_gb,
    "data_porcentaje_uso": $data_usep
  },
  "almacenamiento_data": "$storage",
  "pantalla": {
    "resolucion": "$pant_res_e",
    "densidad_dpi": $pant_dpi
  },
  "red": {
    "ip": "$ip_local",
    "ip_movil": "$ip_movil",
    "mac_wifi": "$mac_wifi",
    "wifi_ssid": "$wifi_ssid_e",
    "wifi_rssi_dbm": $wifi_rssi,
    "wifi_velocidad_mbps": $wifi_speed,
    "operador": "$red_operador_e",
    "tipo_red": "$red_tipo"
  },
  "seguridad": {
    "cifrado": "$sec_cifrado",
    "selinux": "$sec_selinux",
    "verified_boot": "$sec_vbs",
    "bootloader_bloqueado": $sec_locked_bool,
    "root_detectado": $root_bool,
    "adb_wifi": $adbwifi_bool
  },
  "apps": {
    "total": $apps_total,
    "terceros": $apps_terceros,
    "deshabilitadas": $apps_desh
  },
  "termico": {
    "temp_max_c": $term_max_c
  },
  "procesos_top": [$procesos_json]
}
EOF

if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$FILE" >/dev/null 2>&1 || echo "[!] El JSON generado parece invalido: $FILE" >&2
fi

# ── Resumen legible en terminal ──────────────────────────────────────────────
echo ""
echo "  +----------------- RESUMEN DEL DIAGNOSTICO (Android) -----------------+"
echo "   Dispositivo ..: $marca $DEVICE ($fabricante)"
echo "   Android ......: $ANDROID (SDK $SDK)  ·  build ${build_id:-?}  ·  kernel ${kernel:-?}"
echo "   Parche segur. : ${seguridad_patch:-(desconocido)}"
echo "   Uptime .......: ${uptime_horas} h"
echo "   Bateria ......: ${bat_level}% / ${bat_temp_c} C  ·  $bat_estado  ·  salud $bat_salud  ·  ${bat_volt} mV"
echo "   CPU ..........: ${cpu_modelo:-?}  ·  ${cpu_cores} cores  ·  carga ${cpu_load}  ·  uso ${cpu_uso}%"
echo "   RAM ..........: ${ram_libre_gb} GB libres / ${ram_total_gb} GB"
echo "   Almacen /data : ${data_libre_gb} GB libres / ${data_total_gb} GB  (uso ${data_usep}%)"
echo "   Pantalla .....: ${pant_res:-?}  @ ${pant_dpi} dpi"
echo "   Termico ......: ${term_max_c} C (max)"
echo "   Apps .........: ${apps_total} total  ·  ${apps_terceros} de terceros  ·  ${apps_desh} deshabilitadas"
echo "   Seguridad ....: cifrado=${sec_cifrado:-?}  selinux=${sec_selinux:-?}  vbs=${sec_vbs:-?}  root=${root_bool}"
[ -n "$ip_local" ]    && echo "   Red wlan0 ....: $ip_local  ·  SSID ${wifi_ssid:-?}  ·  RSSI ${wifi_rssi} dBm  ·  ${wifi_speed} Mbps"
[ -n "$red_operador" ] && echo "   Movil ........: $red_operador  ·  ${red_tipo:-?}"
echo "  +---------------------------------------------------------------------+"
echo ""

echo "[+] Diagnóstico Android guardado en:"
echo "    $FILE"

# ── Subida automática a WordPress (Fase 5) ──────────────────────────────────
# Igual que el agente Linux: exporta RC_CLIENT_EMAIL y RC_FLEET_TOKEN para
# publicar en el endpoint de flota. RC_FLEET_URL y RC_TICKET_ID son opcionales.

RC_CLIENT_EMAIL="${RC_CLIENT_EMAIL:-}"
RC_FLEET_TOKEN="${RC_FLEET_TOKEN:-}"
RC_FLEET_URL="${RC_FLEET_URL:-https://resolvecore.website/wp-json/rc/v1/fleet}"
RC_TICKET_ID="${RC_TICKET_ID:-}"

if [ -n "$RC_CLIENT_EMAIL" ] && [ -n "$RC_FLEET_TOKEN" ]; then
    if ! command -v curl >/dev/null 2>&1; then
        echo "[!] curl no disponible: no se sube el diagnóstico (JSON local en $FILE)." >&2
    else
        echo "[+] Subiendo diagnóstico a $RC_FLEET_URL ..."
        ticket_field=""
        [ -n "$RC_TICKET_ID" ] && ticket_field="\"ticket_id\": ${RC_TICKET_ID},"
        payload="{\"client_email\": \"${RC_CLIENT_EMAIL}\", ${ticket_field} \"diagnostico\": $(cat "$FILE")}"

        http_code=$(curl -sS -o /tmp/rc_fleet_resp.$$ -w '%{http_code}' \
            -X POST "$RC_FLEET_URL" \
            -H "Authorization: Bearer ${RC_FLEET_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "$payload" --max-time 15 || echo "000")

        if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
            echo "[+] Subida OK: $(cat /tmp/rc_fleet_resp.$$)"
            # El score 0-100 lo calcula el servidor (rc_fleet_score() en rc-fleet)
            # y viene en la respuesta; aquí solo se extrae y se muestra.
            score=$(sed -n 's/.*"score":[[:space:]]*\([0-9][0-9]*\).*/\1/p' /tmp/rc_fleet_resp.$$ | head -1)
            if [ -n "$score" ]; then
                echo "[+] Puntuación de salud (servidor): ${score}/100"
            fi
        else
            echo "[!] Fallo al subir (HTTP $http_code): $(cat /tmp/rc_fleet_resp.$$ 2>/dev/null)" >&2
            echo "[!] El JSON local sigue disponible en: $FILE" >&2
        fi
        rm -f /tmp/rc_fleet_resp.$$
    fi
else
    echo "[+] (Subida automática omitida: exporta RC_CLIENT_EMAIL y RC_FLEET_TOKEN para activarla.)"
fi
