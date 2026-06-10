#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Optimización de un dispositivo Android vía ADB con acta.
#
# Limpia la caché de las apps (SIN borrar datos ni sesiones), borra temporales
# de /data/local/tmp, libera memoria cerrando procesos en segundo plano
# (am kill-all, análogo a SysMain/drop_caches), detecta apps de alto consumo en
# segundo plano y deja constancia de todo lo realizado en un acta para técnico y
# cliente:
#   diagnosticos/tickets/<NNNNN>/android/optimizacion.txt   (legible, para el cliente)
#   diagnosticos/tickets/<NNNNN>/android/optimizacion.json  (estructurado, técnico/flota)
#
# CAMBIO v3.0: ya NO se usa 'pm clear' (que borraba logins/ajustes de cada app).
# Ahora 'pm trim-caches' limpia solo la caché y conserva los datos del usuario.
#
# Uso:
#   bash optimizacion.sh --confirm
#   bash optimizacion.sh <serial> --confirm
#   bash optimizacion.sh --confirm --ticket 42
#   bash optimizacion.sh --confirm --stop-hogs   # ademas fuerza-cierra top consumidores
#
# Autor:   Francisco Vidal Mateo (GitHub: Haplee)
# Versión: 3.1
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail
export LC_ALL=C

if ! command -v adb >/dev/null 2>&1; then
    echo "ERROR: 'adb' no encontrado en el PATH." >&2
    exit 1
fi

# ── Argumentos ────────────────────────────────────────────────────────────────
SERIAL=""
CONFIRM=0
TICKET=""
OUTPUT_DIR=""
STOP_HOGS=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --confirm)   CONFIRM=1; shift ;;
        --stop-hogs) STOP_HOGS=1; shift ;;
        --ticket)    TICKET="${2:-}"; shift 2 ;;
        --output)    OUTPUT_DIR="${2:-}"; shift 2 ;;
        *)           SERIAL="$1"; shift ;;
    esac
done

if [ "$CONFIRM" -ne 1 ]; then
    echo "Uso: bash $0 [serial] --confirm [--ticket N] [--stop-hogs]"
    echo ""
    echo "Limpia SOLO la caché de las apps (pm trim-caches): conserva logins y datos."
    echo "Con --stop-hogs ademas fuerza el cierre de las apps de mayor consumo."
    exit 0
fi

# Validamos el serial antes de interpolarlo en $ADB: un serial con
# metacaracteres permitiría inyección de comandos al ejecutar $ADB.
if [ -n "${SERIAL:-}" ] && ! printf '%s' "$SERIAL" | grep -Eq '^[A-Za-z0-9._:-]+$'; then
    echo "ERROR: serial ADB inválido (solo letras, dígitos y . _ : -)." >&2
    exit 1
fi
ADB="adb${SERIAL:+ -s $SERIAL}"

if ! $ADB get-state >/dev/null 2>&1; then
    echo "ERROR: dispositivo no conectado o no autorizado." >&2
    exit 1
fi

DEVICE=$($ADB shell getprop ro.product.model 2>/dev/null | tr -d '\r\n')
[ -z "$DEVICE" ] && DEVICE="android"
DEVICE_SAFE="${DEVICE// /_}"

info() { echo "[+] $*"; }
warn() { echo "[!] $*" >&2; }
# adb_vivo: true si el dispositivo sigue en estado "device" (cable/Wi-Fi vivos).
adb_vivo() { [ "$($ADB get-state 2>/dev/null | tr -d '\r\n')" = "device" ]; }

# ── Resolucion de carpeta de salida (organizada por ticket) ──────────────────
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE_REP="${RC_REPARACIONES_DIR:-$REPO_ROOT/diagnosticos/tickets}"
if [[ -n "$OUTPUT_DIR" ]]; then
    DEST_DIR="$OUTPUT_DIR"
elif [[ "$TICKET" =~ ^[0-9]+$ ]]; then
    DEST_DIR="$BASE_REP/$(printf '%05d' "$TICKET")/android"
else
    DEST_DIR="$BASE_REP/sin-ticket/android"
    echo "[!] No se ha indicado ticket. Guardando acta en diagnosticos/tickets/sin-ticket/android/"
fi
mkdir -p "$DEST_DIR"

# ── Registro de acciones ─────────────────────────────────────────────────────
ACCIONES_JSON=""; ACCIONES_TXT=""; HALLAZGOS_JSON=""
N_OK=0; N_FALLO=0; PASO_N=0
N_DETECTADOS=0; N_DETENIDOS=0

esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

registra() {
    local paso="$1" desc="$2" estado="$3" resultado="$4"
    PASO_N=$((PASO_N + 1))
    [ "$estado" = "ok" ] && N_OK=$((N_OK + 1))
    [ "$estado" = "fallo" ] && N_FALLO=$((N_FALLO + 1))
    [ -n "$ACCIONES_JSON" ] && ACCIONES_JSON="$ACCIONES_JSON,"
    ACCIONES_JSON="$ACCIONES_JSON{\"paso\":\"$(esc "$paso")\",\"descripcion\":\"$(esc "$desc")\",\"resultado\":\"$(esc "$resultado")\",\"estado\":\"$estado\"}"
    local marca="OK"; [ "$estado" = "fallo" ] && marca="FALLO"; [ "$estado" = "omitido" ] && marca="OMITIDO"
    local linea; linea=$(printf ' %2d. %-44s %s (%s)' "$PASO_N" "$desc" "$marca" "$resultado")
    ACCIONES_TXT="${ACCIONES_TXT}${linea}"$'\n'
    info "$desc ... $marca ($resultado)"
}

# Si el dispositivo se ha desconectado antes de empezar a actuar, abortamos en
# vez de registrar una cascada de pasos "fallo" que ensucian el acta.
if ! adb_vivo; then
    echo "ERROR: dispositivo desconectado antes de la optimización. Acta no generada." >&2
    exit 1
fi

# ── 1. Limpieza de caché de apps (SIN borrar datos) ─────────────────────────
# pm trim-caches pide al sistema liberar caché hasta el tamano indicado; con un
# valor enorme equivale a "vacía toda la caché posible". Conserva logins/ajustes.
info "Limpiando caché de aplicaciones (pm trim-caches, conserva datos)..."
if $ADB shell pm trim-caches 9999999999999 >/dev/null 2>&1; then
    registra "trim_caches" "Limpieza de caché de apps (conserva datos)" "ok" "caché liberada"
else
    registra "trim_caches" "Limpieza de caché de apps" "fallo" "el sistema rechazó trim-caches"
fi

# ── 2. /data/local/tmp ──────────────────────────────────────────────────────
# Hacemos 'cd' y borramos con ./*: si el directorio está vacío el glob no casa
# y algunos shells de Android pasan '*' literal a rm (registrando un falso
# "fallo"). El '|| true' interno absorbe ese caso para no marcar error espurio.
if $ADB shell 'cd /data/local/tmp && rm -rf ./* 2>/dev/null; true' >/dev/null 2>&1; then
    registra "tmp" "Borrado de /data/local/tmp" "ok" "temporales eliminados"
else
    registra "tmp" "Borrado de /data/local/tmp" "fallo" "sin permiso o inaccesible"
fi

# ── 3. Liberación de memoria RAM (análogo a SysMain/drop_caches) ────────────
# Android no expone preload/Prefetch/swappiness sin root. El análogo accesible
# vía ADB es 'am kill-all': cierra los procesos en SEGUNDO PLANO (no las apps en
# primer plano ni los servicios del sistema) liberando RAM al momento. Es
# TRANSITORIO (el sistema re-arranca lo que necesite) y no requiere revertir.
info "Liberando memoria (am kill-all, cierra procesos en segundo plano)..."
# RAM disponible en KiB vía /proc/meminfo del dispositivo (best-effort).
mem_disp_kb() { $ADB shell cat /proc/meminfo 2>/dev/null | tr -d '\r' | awk '/^MemAvailable:/{print $2; exit}'; }
ram_antes=$(mem_disp_kb)
if $ADB shell am kill-all >/dev/null 2>&1; then
    ram_despues=$(mem_disp_kb)
    if [[ "$ram_antes" =~ ^[0-9]+$ && "$ram_despues" =~ ^[0-9]+$ ]]; then
        dif_ram=$((ram_despues - ram_antes)); [ "$dif_ram" -lt 0 ] && dif_ram=0
        res_ram=$(awk "BEGIN{k=$dif_ram; if(k>=1048576) printf \"%.2f GB de RAM liberada\", k/1048576; else printf \"%.1f MB de RAM liberada\", k/1024}")
    else
        res_ram="procesos en segundo plano cerrados"
    fi
    registra "liberar_ram" "Liberación de memoria (cierra apps en 2.º plano)" "ok" "$res_ram"
else
    registra "liberar_ram" "Liberación de memoria" "fallo" "el sistema rechazó am kill-all"
fi

# ── 4. Detección de apps de alto consumo en 2.º plano ───────────────────────
# Parseamos el bloque "Estimated power use (mAh)" de batterystats. Las lineas
# por app vienen como "UID uXXXX: NN ( ... )". Resolvemos UID->paquete con
# 'pm list packages -U' (best-effort; si no, mostramos el UID crudo).
info "Detectando apps de alto consumo de batería en segundo plano..."

# Mapa uid->paquete (una sola pasada). Formato de salida: "package:com.x uid:10123".
# 'declare -A' falla en bash < 4 (Termux en Android antiguo). Si no hay arrays
# asociativos, saltamos el mapa y caemos al fallback "uid_<n>" más abajo, en vez
# de abortar el script con un error de subíndice bajo 'set -u'.
HAS_ASSOC=1
declare -A UID2PKG 2>/dev/null || HAS_ASSOC=0
if [ "$HAS_ASSOC" -eq 1 ]; then
    while IFS= read -r linea; do
        pkg=$(echo "$linea" | sed -n 's/^package:\([^ ]*\).*/\1/p')
        uid=$(echo "$linea" | sed -n 's/.*uid:\([0-9]*\).*/\1/p')
        [ -n "$pkg" ] && [ -n "$uid" ] && UID2PKG[$uid]="$pkg"
    done < <($ADB shell pm list packages -U 2>/dev/null | tr -d '\r')
fi

# Top consumidores del bloque de energia estimada (excluye lineas de sistema
# como Screen/Cell/Idle: solo nos quedamos con las que empiezan por "Uid ").
while IFS= read -r linea; do
    linea=$(echo "$linea" | tr -d '\r')
    # Ej: "    Uid u0a123: 45.2 ( cpu=... )"
    uref=$(echo "$linea" | sed -n 's/.*Uid u\([0-9a-z]*\):.*/\1/p')
    mah=$(echo "$linea"  | sed -n 's/.*: \([0-9][0-9.]*\).*/\1/p')
    [ -z "$uref" ] && continue
    [ -z "$mah" ] && continue
    # u0aNNN -> uid 10000+NNN ; uNN -> uid NN (apps de sistema)
    case "$uref" in
        0a*) uidnum=$((10000 + ${uref#0a})) ;;
        *)   uidnum="$uref" ;;
    esac
    nombre="${UID2PKG[$uidnum]:-uid_$uref}"
    N_DETECTADOS=$((N_DETECTADOS + 1))
    accion_h="reportado"
    # Solo paramos apps de terceros (UID >= 10000), con --stop-hogs, y NUNCA
    # paquetes de sistema (com.android.*, android, Play Services/GSF): forzar su
    # cierre puede dejar el teléfono inestable.
    es_sistema=0
    case "$nombre" in
        com.android.*|android|com.google.android.gms|com.google.android.gsf|*.systemui) es_sistema=1 ;;
    esac
    if [ "$STOP_HOGS" -eq 1 ] && [ "$es_sistema" -eq 0 ] && [ "$uidnum" -ge 10000 ] 2>/dev/null && [ "$nombre" != "uid_$uref" ]; then
        if $ADB shell am force-stop "$nombre" >/dev/null 2>&1; then
            accion_h="detenido"; N_DETENIDOS=$((N_DETENIDOS + 1))
        fi
    fi
    [ -n "$HALLAZGOS_JSON" ] && HALLAZGOS_JSON="$HALLAZGOS_JSON,"
    HALLAZGOS_JSON="$HALLAZGOS_JSON{\"nombre\":\"$(esc "$nombre")\",\"tipo\":\"bateria\",\"detalle\":\"${mah} mAh estimados\",\"accion\":\"$accion_h\"}"
    info "  - $nombre: ${mah} mAh -> $accion_h"
    [ "$N_DETECTADOS" -ge 8 ] && break
done < <($ADB shell dumpsys batterystats --charged 2>/dev/null | tr -d '\r' \
         | awk '/Estimated power use/{f=1} f && /Uid u/{print} /Estimated power use/{next}')

if [ "$N_DETECTADOS" -eq 0 ]; then
    info "  (sin datos de consumo por app; batterystats no expuso el desglose)"
fi
if [ "$STOP_HOGS" -ne 1 ] && [ "$N_DETECTADOS" -gt 0 ]; then
    info "  (solo reporte; usa --stop-hogs para forzar su cierre)"
fi

# ── Acta JSON ────────────────────────────────────────────────────────────────
TS=$(date +%Y%m%d_%H%M%S)
if [[ "$TICKET" =~ ^[0-9]+$ && -z "$OUTPUT_DIR" ]]; then
    JSON_FILE="$DEST_DIR/optimizacion.json"; TXT_FILE="$DEST_DIR/optimizacion.txt"
    if [[ -f "$JSON_FILE" ]]; then
        n=2; while [[ -f "$DEST_DIR/optimizacion_v$n.json" ]]; do n=$((n + 1)); done
        JSON_FILE="$DEST_DIR/optimizacion_v$n.json"; TXT_FILE="$DEST_DIR/optimizacion_v$n.txt"
        echo "[i] Ya existia optimizacion.json; guardando como $(basename "$JSON_FILE")"
    fi
else
    JSON_FILE="$DEST_DIR/optimizacion_android_${DEVICE_SAFE}_${TS}.json"
    TXT_FILE="$DEST_DIR/optimizacion_android_${DEVICE_SAFE}_${TS}.txt"
fi
ticket_str="sin-ticket"; [[ "$TICKET" =~ ^[0-9]+$ ]] && ticket_str=$(printf '%05d' "$TICKET")

cat > "$JSON_FILE" <<EOF
{
  "_meta": {
    "plataforma": "android",
    "hostname": "$DEVICE",
    "version": "1.0",
    "tipo": "optimizacion"
  },
  "timestamp": "$(date -Iseconds)",
  "ticket": "$ticket_str",
  "dispositivo": "$DEVICE",
  "acciones": [$ACCIONES_JSON],
  "hallazgos_consumo": [$HALLAZGOS_JSON],
  "resumen": {
    "espacio_liberado_mb": null,
    "acciones_ok": $N_OK,
    "acciones_fallidas": $N_FALLO,
    "consumidores_detectados": $N_DETECTADOS,
    "consumidores_detenidos": $N_DETENIDOS
  }
}
EOF

if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$JSON_FILE" >/dev/null 2>&1 || warn "El JSON del acta parece invalido: $JSON_FILE"
fi

# ── Acta TXT (legible para el cliente) ───────────────────────────────────────
{
    echo "  +-------------------------------------------------------------+"
    echo "  |              ACTA DE OPTIMIZACION - ResolveCore             |"
    echo "  +-------------------------------------------------------------+"
    echo ""
    echo "  Dispositivo: $DEVICE"
    echo "  Fecha .....: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "  Ticket ....: $ticket_str"
    echo ""
    echo "  ACCIONES REALIZADAS"
    printf '%s' "$ACCIONES_TXT"
    echo ""
    echo "  APPS DE ALTO CONSUMO EN SEGUNDO PLANO"
    if [ "$N_DETECTADOS" -eq 0 ]; then
        echo "    (sin desglose de consumo disponible)"
    else
        echo "$HALLAZGOS_JSON" | grep -o '"nombre":"[^"]*"[^}]*"accion":"[^"]*"' \
            | sed 's/"nombre":"//; s/","tipo":"[^"]*","detalle":"/  ->  /; s/","accion":"/  [/; s/"$/]/' \
            | sed 's/^/    - /'
    fi
    echo ""
    echo "  RESUMEN"
    echo "    Acciones correctas ....: $N_OK"
    echo "    Acciones con fallo ....: $N_FALLO"
    echo "    Consumidores detectados: $N_DETECTADOS (detenidos: $N_DETENIDOS)"
    echo ""
    echo "  Nota: la limpieza conserva los datos y sesiones de tus apps (solo caché)."
    echo "  Este acta es un registro automatico de la intervencion realizada."
    echo "  +-------------------------------------------------------------+"
} > "$TXT_FILE"

# ── Resumen en terminal ──────────────────────────────────────────────────────
echo ""
echo "  +----------------- OPTIMIZACION ANDROID COMPLETADA -----------------+"
echo "   Dispositivo ..........: $DEVICE"
echo "   Acciones .............: $N_OK OK / $N_FALLO fallos"
echo "   Consumidores .........: $N_DETECTADOS detectados / $N_DETENIDOS detenidos"
echo "  +-------------------------------------------------------------------+"
echo ""
info "Acta guardada en:"
echo "    $TXT_FILE"
echo "    $JSON_FILE"

# ── Subida automática a WordPress (Fase 5) ──────────────────────────────────
RC_CLIENT_EMAIL="${RC_CLIENT_EMAIL:-}"
RC_FLEET_TOKEN="${RC_FLEET_TOKEN:-}"
RC_FLEET_URL="${RC_FLEET_URL:-https://resolvecore.website/wp-json/rc/v1/fleet}"
RC_TICKET_ID="${RC_TICKET_ID:-}"

if [ -n "$RC_CLIENT_EMAIL" ] && [ -n "$RC_FLEET_TOKEN" ]; then
    if ! command -v curl >/dev/null 2>&1; then
        warn "curl no disponible: no se sube el acta (fichero local en $JSON_FILE)."
    else
        info "Subiendo acta de optimización a $RC_FLEET_URL ..."
        ticket_field=""
        [ -n "$RC_TICKET_ID" ] && ticket_field="\"ticket_id\": ${RC_TICKET_ID},"
        payload="{\"client_email\": \"${RC_CLIENT_EMAIL}\", ${ticket_field} \"optimizacion\": $(cat "$JSON_FILE")}"
        http_code=$(curl -sS -o /tmp/rc_fleet_opt.$$ -w '%{http_code}' \
            -X POST "$RC_FLEET_URL" \
            -H "Authorization: Bearer ${RC_FLEET_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "$payload" --max-time 15 || echo "000")
        if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
            info "Subida OK: $(cat /tmp/rc_fleet_opt.$$)"
        else
            warn "Fallo al subir (HTTP $http_code): $(cat /tmp/rc_fleet_opt.$$ 2>/dev/null)"
            warn "El acta local sigue disponible en: $JSON_FILE"
        fi
        rm -f /tmp/rc_fleet_opt.$$
    fi
else
    info "(Subida automática omitida: exporta RC_CLIENT_EMAIL y RC_FLEET_TOKEN para activarla.)"
fi
