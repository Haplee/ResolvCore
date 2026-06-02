#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Diagnóstico básico de un dispositivo Android vía ADB.
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
#
# Autor:   Francisco Vidal Mateo (GitHub: Haplee)
# Versión: 2.0
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

# ── Dependencias ────────────────────────────────────────────────────────────

if ! command -v adb >/dev/null 2>&1; then
    echo "ERROR: 'adb' no está instalado o no está en el PATH." >&2
    echo "       En Ubuntu/Debian:   sudo apt install android-tools-adb" >&2
    echo "       En macOS (brew):    brew install android-platform-tools" >&2
    exit 1
fi

# ── Argumentos ────────────────────────────────────────────────────────────────
# [serial]        primer posicional: serial ADB (uso historico)
# [dir]           segundo posicional u --output <dir>: carpeta explicita
# --ticket <N>    organiza la salida en reparaciones/<NNNNN>/diagnostico.json
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
BASE_REP="${RC_REPARACIONES_DIR:-$REPO_ROOT/reparaciones}"
if [[ -n "$OUTPUT_DIR" ]]; then
    DEST_DIR="$OUTPUT_DIR"
elif [[ "$TICKET" =~ ^[0-9]+$ ]]; then
    DEST_DIR="$BASE_REP/$(printf '%05d' "$TICKET")"
else
    DEST_DIR="$BASE_REP/sin-ticket"
    echo "[!] No se ha indicado ticket. Guardando en reparaciones/sin-ticket/"
fi
mkdir -p "$DEST_DIR"

# Si nos pasan serial, hablamos solo con ese dispositivo. Si no, ADB
# escogerá el único conectado (o fallará si hay varios).
ADB="adb${SERIAL:+ -s $SERIAL}"

# Comprobamos que el dispositivo esté autorizado.
if ! $ADB get-state >/dev/null 2>&1; then
    echo "ERROR: dispositivo no conectado o no autorizado." >&2
    echo "       Acepta la huella del PC en el aviso del móvil." >&2
    exit 1
fi

# ── Recogida ────────────────────────────────────────────────────────────────
# Limpiamos \r porque ADB en Windows / Git Bash mete CRLF.

DEVICE=$($ADB shell getprop ro.product.model 2>/dev/null | tr -d '\r\n')
ANDROID=$($ADB shell getprop ro.build.version.release 2>/dev/null | tr -d '\r\n')
SDK=$($ADB shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r\n')

# Batería: nivel + temperatura crudos. La temperatura viene en décimas
# de grado (ej. 285 = 28.5 °C). El informe se encarga de formatearlo.
bat_level=$($ADB shell dumpsys battery 2>/dev/null | awk -F: '/  level:/ {gsub(/ /,"",$2); print $2}')
bat_temp=$($ADB shell dumpsys battery  2>/dev/null | awk -F: '/temperature:/{gsub(/ /,"",$2); print $2}')

# Almacenamiento de /data — formato "TOTAL LIBRE" (en bloques de 1K).
storage=$($ADB shell df /data 2>/dev/null | awk 'NR==2 {print $2" "$4}')

# ── Recogida ampliada (best-effort; cada campo cae a vacio si no responde) ────
fabricante=$($ADB shell getprop ro.product.manufacturer 2>/dev/null | tr -d '\r\n')
marca=$($ADB shell getprop ro.product.brand 2>/dev/null | tr -d '\r\n')
seguridad_patch=$($ADB shell getprop ro.build.version.security_patch 2>/dev/null | tr -d '\r\n')

# IP de wlan0 (red Wi-Fi). Vacio si no hay interfaz/permiso.
ip_local=$($ADB shell ip -o -4 addr show wlan0 2>/dev/null | awk '{print $4}' | head -1 | tr -d '\r\n')

# Top procesos por CPU (toybox top). Guardamos nombre+cpu como array de strings.
procesos_json=""
while IFS= read -r linea; do
    [ -z "$linea" ] && continue
    linea=$(echo "$linea" | tr -d '\r' | sed 's/"/\\"/g')
    [ -n "$procesos_json" ] && procesos_json="$procesos_json,"
    procesos_json="$procesos_json\"$linea\""
done < <($ADB shell top -b -n 1 2>/dev/null | awk 'NR>6 {print $NF" "$(NF-2)}' | head -5)

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

# ── Volcado JSON ────────────────────────────────────────────────────────────
# Blindamos los campos numericos: si el getprop/dumpsys no devolvio nada, un
# valor vacio dejaria el JSON invalido ("nivel": ,). Ponemos 0 por defecto.
SDK=${SDK:-0}
bat_level=${bat_level:-0}
bat_temp=${bat_temp:-0}
procesos_json=${procesos_json:-}

cat > "$FILE" <<EOF
{
  "_meta": {
    "plataforma": "android",
    "hostname": "$DEVICE",
    "version": "2.2"
  },
  "timestamp": "$(date -Iseconds)",
  "dispositivo": "$DEVICE",
  "fabricante": "$fabricante",
  "marca": "$marca",
  "android": "$ANDROID",
  "sdk": $SDK,
  "parche_seguridad": "$seguridad_patch",
  "bateria": {
    "nivel": $bat_level,
    "temp_decimas_grado": $bat_temp
  },
  "almacenamiento_data": "$storage",
  "red": {
    "ip": "$ip_local"
  },
  "procesos_top": [$procesos_json]
}
EOF

if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$FILE" >/dev/null 2>&1 || echo "[!] El JSON generado parece invalido: $FILE" >&2
fi

# ── Resumen legible en terminal ──────────────────────────────────────────────
bat_temp_c=$(awk "BEGIN{printf \"%.1f\", ${bat_temp:-0}/10}")
echo ""
echo "  +----------------- RESUMEN DEL DIAGNOSTICO (Android) -----------------+"
echo "   Dispositivo ..: $marca $DEVICE ($fabricante)"
echo "   Android ......: $ANDROID (SDK $SDK)"
echo "   Parche segur. : ${seguridad_patch:-(desconocido)}"
echo "   Bateria ......: ${bat_level}% / ${bat_temp_c} C"
echo "   Almacen /data : $storage (bloques 1K: total libre)"
[ -n "$ip_local" ] && echo "   Red wlan0 ....: $ip_local"
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
        else
            echo "[!] Fallo al subir (HTTP $http_code): $(cat /tmp/rc_fleet_resp.$$ 2>/dev/null)" >&2
            echo "[!] El JSON local sigue disponible en: $FILE" >&2
        fi
        rm -f /tmp/rc_fleet_resp.$$
    fi
else
    echo "[+] (Subida automática omitida: exporta RC_CLIENT_EMAIL y RC_FLEET_TOKEN para activarla.)"
fi
