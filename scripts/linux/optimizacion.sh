#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Optimización de un equipo Linux con acta de acciones.
#
# Pasa el autoremove de apt, limpia la caché de paquetes, compacta el journal
# de systemd, borra ficheros viejos de /tmp y purga snaps antiguos. Mide el
# espacio liberado en cada paso y detecta procesos de alto consumo.
#
# Deja constancia de TODO lo realizado en un acta para técnico y cliente:
#   diagnosticos/tickets/<NNNNN>/linux/optimizacion.txt   (legible, para el cliente)
#   diagnosticos/tickets/<NNNNN>/linux/optimizacion.json  (estructurado, técnico/flota)
#
# Requiere root (sudo) para apt y journalctl.
#
# Uso:
#   sudo bash optimizacion.sh --confirm                 # optimiza + acta
#   sudo bash optimizacion.sh --confirm --ticket 42     # acta en diagnosticos/tickets/00042/
#   sudo bash optimizacion.sh --confirm --stop-hogs     # ademas detiene top consumidores
#
# Autor:   Francisco Vidal Mateo (GitHub: Haplee)
# Versión: 3.0
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail
export LC_ALL=C   # punto decimal en awk; sin esto el JSON se rompe en es_ES.

# ── Argumentos ────────────────────────────────────────────────────────────────
# --confirm     obligatorio: evita ejecuciones accidentales por SSH.
# --ticket <N>  organiza el acta en diagnosticos/tickets/<NNNNN>/optimizacion.{txt,json}
# --output <d>  carpeta de salida explicita (CI / back-compat)
# --stop-hogs   ademas de detectar, DETIENE los procesos top no criticos.
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
        *) shift ;;
    esac
done

if [ "$CONFIRM" -ne 1 ]; then
    echo "Uso: sudo bash $0 --confirm [--ticket N] [--stop-hogs]"
    echo ""
    echo "Esto pasa autoremove, vacía caché de apt, journal, /tmp viejo y snaps."
    echo "Con --stop-hogs ademas detiene los procesos de mayor consumo (no criticos)."
    exit 0
fi

HOST=$(hostname)
info() { echo "[+] $*"; }
warn() { echo "[!] $*" >&2; }

# ── Resolucion de carpeta de salida (organizada por ticket) ──────────────────
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE_REP="${RC_REPARACIONES_DIR:-$REPO_ROOT/diagnosticos/tickets}"
if [[ -n "$OUTPUT_DIR" ]]; then
    DEST_DIR="$OUTPUT_DIR"
elif [[ "$TICKET" =~ ^[0-9]+$ ]]; then
    DEST_DIR="$BASE_REP/$(printf '%05d' "$TICKET")/linux"
else
    DEST_DIR="$BASE_REP/sin-ticket/linux"
    echo "[!] No se ha indicado ticket. Guardando acta en diagnosticos/tickets/sin-ticket/linux/"
fi
mkdir -p "$DEST_DIR"

# ── Registro de acciones (acumula JSON + texto legible) ──────────────────────
# Cada accion deja: paso, descripcion, resultado y estado (ok|fallo|omitido).
ACCIONES_JSON=""        # fragmentos {...} separados por coma
ACCIONES_TXT=""         # lineas legibles para el acta .txt
HALLAZGOS_JSON=""       # procesos/consumidores detectados
N_OK=0; N_FALLO=0
LIBERADO_KB=0           # acumulado de espacio liberado en KiB
PASO_N=0

esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# registra <paso> <descripcion> <estado ok|fallo|omitido> <resultado>
registra() {
    local paso="$1" desc="$2" estado="$3" resultado="$4"
    PASO_N=$((PASO_N + 1))
    [ "$estado" = "ok" ] && N_OK=$((N_OK + 1))
    [ "$estado" = "fallo" ] && N_FALLO=$((N_FALLO + 1))
    [ -n "$ACCIONES_JSON" ] && ACCIONES_JSON="$ACCIONES_JSON,"
    ACCIONES_JSON="$ACCIONES_JSON{\"paso\":\"$(esc "$paso")\",\"descripcion\":\"$(esc "$desc")\",\"resultado\":\"$(esc "$resultado")\",\"estado\":\"$estado\"}"
    local marca="OK"; [ "$estado" = "fallo" ] && marca="FALLO"; [ "$estado" = "omitido" ] && marca="OMITIDO"
    # OJO: $(...) come el \n final; anadimos el salto con $'\n' para que el acta
    # .txt liste una accion por linea (si no, salen todas pegadas).
    local linea; linea=$(printf ' %2d. %-44s %s (%s)' "$PASO_N" "$desc" "$marca" "$resultado")
    ACCIONES_TXT="${ACCIONES_TXT}${linea}"$'\n'
    info "$desc ... $marca ($resultado)"
}

# Espacio libre de / en KiB (para medir antes/despues de cada limpieza).
libre_kb() { df -Pk / 2>/dev/null | awk 'NR==2{print $4}'; }
# Formatea KiB a una cadena legible (MB/GB).
fmt_kb() { awk "BEGIN{k=$1; if(k<0)k=0; if(k>=1048576) printf \"%.2f GB\", k/1048576; else printf \"%.1f MB\", k/1024}"; }

# ── 1. Paquetes huérfanos / caché apt ───────────────────────────────────────
if command -v apt-get >/dev/null 2>&1; then
    antes=$(libre_kb)
    if apt-get autoremove -y >/dev/null 2>&1; then
        apt-get clean >/dev/null 2>&1 || true
        despues=$(libre_kb); dif=$((despues - antes)); [ "$dif" -lt 0 ] && dif=0
        LIBERADO_KB=$((LIBERADO_KB + dif))
        registra "apt_clean" "Paquetes huérfanos y caché de apt" "ok" "$(fmt_kb "$dif") liberados"
    else
        registra "apt_clean" "Paquetes huérfanos y caché de apt" "fallo" "sin permisos o apt ocupado"
    fi
else
    registra "apt_clean" "Limpieza de apt" "omitido" "apt-get no presente"
fi

# ── 2. Journal de systemd (>30 días) ────────────────────────────────────────
if command -v journalctl >/dev/null 2>&1; then
    antes=$(libre_kb)
    if journalctl --vacuum-time=30d >/dev/null 2>&1; then
        despues=$(libre_kb); dif=$((despues - antes)); [ "$dif" -lt 0 ] && dif=0
        LIBERADO_KB=$((LIBERADO_KB + dif))
        registra "journal" "Compactado del journal (>30 días)" "ok" "$(fmt_kb "$dif") liberados"
    else
        registra "journal" "Compactado del journal" "fallo" "sin permisos"
    fi
else
    registra "journal" "Compactado del journal" "omitido" "journalctl no presente"
fi

# ── 3. /tmp antiguo (>7 días) ───────────────────────────────────────────────
antes=$(libre_kb)
find /tmp -maxdepth 1 -mtime +7 -exec rm -rf {} + 2>/dev/null || true
despues=$(libre_kb); dif=$((despues - antes)); [ "$dif" -lt 0 ] && dif=0
LIBERADO_KB=$((LIBERADO_KB + dif))
registra "tmp" "Borrado de /tmp antiguo (>7 días)" "ok" "$(fmt_kb "$dif") liberados"

# ── 4. Snaps antiguos (revisiones deshabilitadas) ───────────────────────────
if command -v snap >/dev/null 2>&1; then
    antes=$(libre_kb)
    # Elimina revisiones deshabilitadas (las que ya no se usan tras actualizar).
    snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}' | while read -r nombre rev; do
        snap remove "$nombre" --revision="$rev" >/dev/null 2>&1 || true
    done
    despues=$(libre_kb); dif=$((despues - antes)); [ "$dif" -lt 0 ] && dif=0
    LIBERADO_KB=$((LIBERADO_KB + dif))
    registra "snap" "Purga de revisiones snap antiguas" "ok" "$(fmt_kb "$dif") liberados"
else
    registra "snap" "Purga de snaps" "omitido" "snap no presente"
fi

# ── 5. Detección de procesos de alto consumo ────────────────────────────────
# Reutiliza el mismo muestreo que el diagnostico (CPU y memoria). Servicios
# criticos NUNCA se tocan, ni con --stop-hogs.
CRITICOS="ssh sshd cron crond systemd-journald NetworkManager systemd init dbus-daemon"
N_DETECTADOS=0; N_DETENIDOS=0

info "Detectando procesos de alto consumo..."
# Top 5 por CPU con uso > 5%. Formato: pid %cpu %mem comm
while read -r pid pcpu pmem comm; do
    [ -z "$comm" ] && continue
    # Umbral: solo nos interesan los que realmente cargan el equipo.
    over=$(awk "BEGIN{print ($pcpu>5.0)?1:0}")
    [ "$over" -ne 1 ] && continue
    N_DETECTADOS=$((N_DETECTADOS + 1))
    accion_h="reportado"
    es_critico=0
    for c in $CRITICOS; do [ "$comm" = "$c" ] && es_critico=1 && break; done
    if [ "$STOP_HOGS" -eq 1 ] && [ "$es_critico" -eq 0 ]; then
        if kill -TERM "$pid" 2>/dev/null; then
            accion_h="detenido"; N_DETENIDOS=$((N_DETENIDOS + 1))
        fi
    fi
    [ -n "$HALLAZGOS_JSON" ] && HALLAZGOS_JSON="$HALLAZGOS_JSON,"
    HALLAZGOS_JSON="$HALLAZGOS_JSON{\"nombre\":\"$(esc "$comm")\",\"tipo\":\"cpu\",\"detalle\":\"pid $pid, cpu ${pcpu}%, mem ${pmem}%\",\"accion\":\"$accion_h\"}"
    info "  - $comm (pid $pid): cpu ${pcpu}% mem ${pmem}% -> $accion_h"
done < <(ps -eo pid,%cpu,%mem,comm --sort=-%cpu 2>/dev/null | tail -n +2 | head -5)

if [ "$N_DETECTADOS" -eq 0 ]; then
    info "  (sin procesos por encima del umbral de CPU)"
fi
if [ "$STOP_HOGS" -ne 1 ] && [ "$N_DETECTADOS" -gt 0 ]; then
    info "  (solo reporte; usa --stop-hogs para detenerlos)"
fi

# ── Acta JSON ────────────────────────────────────────────────────────────────
LIBERADO_MB=$(awk "BEGIN{printf \"%.1f\", $LIBERADO_KB/1024}")
TS=$(date +%Y%m%d_%H%M%S)
if [[ "$TICKET" =~ ^[0-9]+$ && -z "$OUTPUT_DIR" ]]; then
    JSON_FILE="$DEST_DIR/optimizacion.json"
    TXT_FILE="$DEST_DIR/optimizacion.txt"
    if [[ -f "$JSON_FILE" ]]; then
        n=2; while [[ -f "$DEST_DIR/optimizacion_v$n.json" ]]; do n=$((n + 1)); done
        JSON_FILE="$DEST_DIR/optimizacion_v$n.json"; TXT_FILE="$DEST_DIR/optimizacion_v$n.txt"
        echo "[i] Ya existia optimizacion.json; guardando como $(basename "$JSON_FILE")"
    fi
else
    JSON_FILE="$DEST_DIR/optimizacion_${HOST}_${TS}.json"
    TXT_FILE="$DEST_DIR/optimizacion_${HOST}_${TS}.txt"
fi
ticket_str="sin-ticket"; [[ "$TICKET" =~ ^[0-9]+$ ]] && ticket_str=$(printf '%05d' "$TICKET")

cat > "$JSON_FILE" <<EOF
{
  "_meta": {
    "plataforma": "linux",
    "hostname": "$HOST",
    "version": "1.0",
    "tipo": "optimizacion"
  },
  "timestamp": "$(date -Iseconds)",
  "ticket": "$ticket_str",
  "acciones": [$ACCIONES_JSON],
  "hallazgos_consumo": [$HALLAZGOS_JSON],
  "resumen": {
    "espacio_liberado_mb": $LIBERADO_MB,
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
    echo "  Equipo ....: $HOST"
    echo "  Fecha .....: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "  Ticket ....: $ticket_str"
    echo ""
    echo "  ACCIONES REALIZADAS"
    printf '%s' "$ACCIONES_TXT"
    echo ""
    echo "  PROCESOS DE ALTO CONSUMO DETECTADOS"
    if [ "$N_DETECTADOS" -eq 0 ]; then
        echo "    (ninguno por encima del umbral)"
    else
        echo "$HALLAZGOS_JSON" | grep -o '"nombre":"[^"]*"[^}]*"accion":"[^"]*"' \
            | sed 's/"nombre":"//; s/","tipo":"[^"]*","detalle":"/  ->  /; s/","accion":"/  [/; s/"$/]/' \
            | sed 's/^/    - /'
    fi
    echo ""
    echo "  RESUMEN"
    echo "    Espacio liberado ......: ${LIBERADO_MB} MB"
    echo "    Acciones correctas ....: $N_OK"
    echo "    Acciones con fallo ....: $N_FALLO"
    echo "    Consumidores detectados: $N_DETECTADOS (detenidos: $N_DETENIDOS)"
    echo ""
    echo "  Este acta es un registro automatico de la intervencion realizada."
    echo "  +-------------------------------------------------------------+"
} > "$TXT_FILE"

# ── Resumen en terminal ──────────────────────────────────────────────────────
echo ""
echo "  +----------------- OPTIMIZACION COMPLETADA -----------------+"
echo "   Espacio liberado .....: ${LIBERADO_MB} MB"
echo "   Acciones .............: $N_OK OK / $N_FALLO fallos"
echo "   Consumidores .........: $N_DETECTADOS detectados / $N_DETENIDOS detenidos"
echo "  +-----------------------------------------------------------+"
echo ""
info "Acta guardada en:"
echo "    $TXT_FILE"
echo "    $JSON_FILE"

# ── Subida automática a WordPress (Fase 5) ──────────────────────────────────
# Igual que el diagnostico: exporta RC_CLIENT_EMAIL y RC_FLEET_TOKEN para subir
# el acta. El endpoint la distingue por la clave "optimizacion".
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
