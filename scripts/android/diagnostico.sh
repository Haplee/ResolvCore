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

SERIAL="${1:-}"
OUTPUT_DIR="${2:-$(dirname "$0")/../diagnosticos}"
mkdir -p "$OUTPUT_DIR"

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

TS=$(date +%Y%m%d_%H%M%S)
DEVICE_SAFE="${DEVICE// /_}"
FILE="$OUTPUT_DIR/diagnostico_android_${DEVICE_SAFE}_${TS}.json"

# ── Volcado JSON ────────────────────────────────────────────────────────────

cat > "$FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "dispositivo": "$DEVICE",
  "android": "$ANDROID",
  "sdk": $SDK,
  "bateria": {
    "nivel": $bat_level,
    "temp_decimas_grado": $bat_temp
  },
  "almacenamiento_data": "$storage"
}
EOF

echo "[+] Diagnóstico Android guardado en:"
echo "    $FILE"
