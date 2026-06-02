#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Diagnóstico básico de un equipo Linux.
#
# Recoge métricas de hardware y sistema operativo y las vuelca en un JSON
# que luego procesa el técnico para generar el informe.
#
# Uso:
#   bash diagnostico.sh                          # salida en ../diagnosticos
#   bash diagnostico.sh /tmp                     # salida en /tmp
#   ssh user@host 'bash -s' < diagnostico.sh     # remoto sin instalar nada
#
# Probado en:  Ubuntu 22.04 / 24.04, Debian 12.
#
# Autor:   Francisco Vidal Mateo (GitHub: Haplee)
# Versión: 2.0
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

# Forzamos locale C para todo el script: en un sistema en español (es_ES) el
# printf de awk emite la coma como separador decimal ("120,5") y eso rompe el
# JSON ("uptime_horas": 120,5 -> 'Expecting property name'). Con LC_ALL=C el
# separador es siempre el punto y el JSON queda valido.
export LC_ALL=C

# ── Argumentos ────────────────────────────────────────────────────────────────
# --output <dir>  carpeta de salida explicita (back-compat / CI)
# --ticket <N>    organiza la salida en reparaciones/<NNNNN>/diagnostico.json
# Tambien acepta un dir posicional (uso historico: bash diagnostico.sh /tmp).
OUTPUT_DIR=""
TICKET=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)  OUTPUT_DIR="${2:-}"; shift 2 ;;
        --ticket)  TICKET="${2:-}";     shift 2 ;;
        --silent|--install|--auto-install) shift ;;   # aceptados, sin efecto aqui
        *) [[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="$1"; shift ;;
    esac
done

HOST=$(hostname)
TS=$(date +%Y%m%d_%H%M%S)

# ── Resolucion de carpeta de salida (organizada por ticket) ──────────────────
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE_REP="${RC_REPARACIONES_DIR:-$REPO_ROOT/reparaciones}"
if [[ -n "$OUTPUT_DIR" ]]; then
    DEST_DIR="$OUTPUT_DIR"
    FILE="$DEST_DIR/diagnostico_${HOST}_${TS}.json"
elif [[ "$TICKET" =~ ^[0-9]+$ ]]; then
    DEST_DIR="$BASE_REP/$(printf '%05d' "$TICKET")"
    FILE="$DEST_DIR/diagnostico.json"
    if [[ -f "$FILE" ]]; then
        n=2
        while [[ -f "$DEST_DIR/diagnostico_v$n.json" ]]; do n=$((n + 1)); done
        FILE="$DEST_DIR/diagnostico_v$n.json"
        echo "[i] Ya existia diagnostico.json; guardando como $(basename "$FILE")"
    fi
else
    DEST_DIR="$BASE_REP/sin-ticket"
    FILE="$DEST_DIR/diagnostico_${HOST}_${TS}.json"
    echo "[!] No se ha indicado ticket. Guardando en reparaciones/sin-ticket/"
fi
mkdir -p "$DEST_DIR"

# ── Helpers ──────────────────────────────────────────────────────────────────

info() { echo "[+] $*"; }
warn() { echo "[!] $*" >&2; }

info "Recogiendo métricas de $HOST..."

# ── CPU ──────────────────────────────────────────────────────────────────────
# Cogemos el primer "model name" — en CPUs con varios sockets se repite
# por cada core y para el informe basta con uno.

cpu_model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
cpu_cores=$(nproc)
cpu_load=$(awk '{print $1}' /proc/loadavg)   # carga 1 minuto

# ── Memoria ─────────────────────────────────────────────────────────────────
# /proc/meminfo da KiB. Convertimos a GB con dos decimales.

mem_total=$(awk '/MemTotal/    {printf "%.2f", $2/1048576}' /proc/meminfo)
mem_libre=$(awk '/MemAvailable/{printf "%.2f", $2/1048576}' /proc/meminfo)

# ── Disco raíz ──────────────────────────────────────────────────────────────

disk_usado=$(df -h  / | awk 'NR==2 {print $3}')
disk_libre=$(df -h  / | awk 'NR==2 {print $4}')
disk_porcentaje=$(df / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')

# ── Sistema operativo ───────────────────────────────────────────────────────

if [ -r /etc/os-release ]; then
    os_name=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
else
    os_name=$(uname -s)
fi

kernel=$(uname -r)
uptime_horas=$(awk '{printf "%.1f", $1/3600}' /proc/uptime)

# ── Actualizaciones pendientes (Debian/Ubuntu) ──────────────────────────────
# apt-get -s upgrade simula sin tocar nada; cada "Inst " es un paquete
# pendiente. Si no hay apt-get o falla devolvemos 0.

actualizaciones=0
if command -v apt-get >/dev/null 2>&1; then
    actualizaciones=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst' || true)
elif command -v dnf >/dev/null 2>&1; then
    actualizaciones=$(dnf -q check-update 2>/dev/null | grep -c '^[a-zA-Z0-9]' || true)
fi

# ── Recogida ampliada (cada bloque tolera fallo: no aborta el diagnostico) ────

# Ultimo arranque (para el informe). Vacio si 'uptime -s' no esta.
ultimo_arranque=$(uptime -s 2>/dev/null || echo "")

# Servicios criticos. cups = cola de impresion: SIEMPRE se reporta, nunca se toca.
servicios_json=""
for s in ssh cron cups systemd-journald NetworkManager; do
    estado=$(systemctl is-active "$s" 2>/dev/null || echo "desconocido")
    [ -n "$servicios_json" ] && servicios_json="$servicios_json,"
    servicios_json="$servicios_json{\"nombre\":\"$s\",\"estado\":\"$estado\"}"
done

# Top procesos por CPU (nombre/cpu/mem). comm no suele llevar espacios.
procesos_json=""
while read -r pcpu pmem pcomm; do
    [ -z "$pcomm" ] && continue
    pcpu=${pcpu:-0}; pmem=${pmem:-0}
    [ -n "$procesos_json" ] && procesos_json="$procesos_json,"
    procesos_json="$procesos_json{\"nombre\":\"$pcomm\",\"cpu\":$pcpu,\"mem\":$pmem}"
done < <(ps -eo %cpu,%mem,comm --sort=-%cpu 2>/dev/null | tail -n +2 | head -10)

# Red: IP/gateway/DNS + puertos en escucha.
ip_local=$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | head -1)
gateway=$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}')
dns_json=""
while read -r d; do
    [ -z "$d" ] && continue
    [ -n "$dns_json" ] && dns_json="$dns_json,"
    dns_json="$dns_json\"$d\""
done < <(grep -h '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}')
puertos_escucha=$(ss -tlnH 2>/dev/null | awk '{print $4}' | sed 's/.*://' \
                  | grep -E '^[0-9]+$' | sort -un | paste -sd, -)

# Seguridad: firewall (ufw/iptables).
firewall="false"
if command -v ufw >/dev/null 2>&1; then
    ufw status 2>/dev/null | grep -qi "Status: active" && firewall="true"
elif command -v iptables >/dev/null 2>&1; then
    # Si hay alguna regla mas alla de las cadenas por defecto, lo damos por activo.
    [ "$(iptables -S 2>/dev/null | grep -vc '^-P')" -gt 0 ] 2>/dev/null && firewall="true"
fi

# SMART del primer disco (requiere smartctl; null si no disponible o sin permiso).
smart_status="null"
if command -v smartctl >/dev/null 2>&1; then
    disk=$(lsblk -dn -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1; exit}')
    if [ -n "$disk" ]; then
        sm=$(smartctl -H "/dev/$disk" 2>/dev/null | grep -i 'overall-health' \
             | awk -F: '{gsub(/^[ \t]+/,"",$2); print $2}')
        [ -n "$sm" ] && smart_status="\"$sm\""
    fi
fi

# Blindaje de arrays/cadenas vacias para que el JSON quede valido.
servicios_json=${servicios_json:-}
procesos_json=${procesos_json:-}
dns_json=${dns_json:-}
puertos_escucha=${puertos_escucha:-}

# ── Volcado JSON ────────────────────────────────────────────────────────────
# Se escribe manual para no depender de jq. Blindamos los campos numericos:
# si algun comando fallo y dejo la variable vacia, ponemos 0 para no romper el
# JSON con un valor ausente ("campo": ,).
cpu_cores=${cpu_cores:-0}
cpu_load=${cpu_load:-0}
mem_total=${mem_total:-0}
mem_libre=${mem_libre:-0}
uptime_horas=${uptime_horas:-0}
disk_porcentaje=${disk_porcentaje:-0}
actualizaciones=${actualizaciones:-0}

cat > "$FILE" <<EOF
{
  "_meta": {
    "plataforma": "linux",
    "hostname": "$HOST",
    "version": "3.1"
  },
  "timestamp": "$(date -Iseconds)",
  "hostname": "$HOST",
  "os": "$os_name",
  "kernel": "$kernel",
  "uptime_horas": $uptime_horas,
  "sistema": {
    "nombre": "$os_name",
    "kernel": "$kernel",
    "uptime_horas": $uptime_horas,
    "ultimo_arranque": "$ultimo_arranque"
  },
  "cpu": {
    "modelo": "$cpu_model",
    "cores": $cpu_cores,
    "carga_1min": $cpu_load
  },
  "ram": {
    "total_gb": $mem_total,
    "libre_gb": $mem_libre
  },
  "disco": {
    "usado": "$disk_usado",
    "libre": "$disk_libre",
    "porcentaje_uso": $disk_porcentaje
  },
  "disco_smart": $smart_status,
  "actualizaciones": {
    "pendientes": $actualizaciones
  },
  "servicios_criticos": [$servicios_json],
  "procesos_top": [$procesos_json],
  "red": {
    "ip": "$ip_local",
    "gateway": "$gateway",
    "dns": [$dns_json],
    "puertos_escucha": [$puertos_escucha]
  },
  "seguridad": {
    "firewall": $firewall
  }
}
EOF

# Validacion: si el JSON salio malformado avisamos (no abortamos: el fichero
# local ya esta escrito y el tecnico puede revisarlo).
if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$FILE" >/dev/null 2>&1 || warn "El JSON generado parece invalido: $FILE"
fi

# ── Resumen legible en terminal ──────────────────────────────────────────────
echo ""
echo "  +-------------------- RESUMEN DEL DIAGNOSTICO --------------------+"
echo "   Equipo .......: $HOST"
echo "   Sistema ......: $os_name ($kernel)"
echo "   Uptime .......: ${uptime_horas} h"
echo "   CPU ..........: $cpu_model (${cpu_cores} cores, carga 1min ${cpu_load})"
echo "   RAM ..........: ${mem_libre} GB libres de ${mem_total} GB"
echo "   Disco / .....: ${disk_libre} libres (${disk_porcentaje}% usado)"
[ -n "$ip_local" ] && echo "   Red ..........: IP ${ip_local} | GW ${gateway} | puertos ${puertos_escucha:-(ninguno)}"
echo "   Firewall .....: $firewall"
echo "   Updates ......: ${actualizaciones} pendientes"
echo "   Servicios ....: $(echo "$servicios_json" | grep -o '"nombre":"[^"]*","estado":"[^"]*"' | sed 's/"nombre":"//;s/","estado":"/=/;s/"//' | paste -sd' ' -)"
echo "   Top procesos (CPU):"
ps -eo %cpu,%mem,comm --sort=-%cpu 2>/dev/null | tail -n +2 | head -5 \
    | awk '{printf "     - %-20s cpu=%s%% mem=%s%%\n", $3, $1, $2}'
echo "  +-----------------------------------------------------------------+"
echo ""

info "Diagnóstico guardado en:"
echo "    $FILE"

# ── Subida automática a WordPress (Fase 5) ──────────────────────────────────
# Variables de entorno (todas opcionales salvo email+token para activar):
#   RC_CLIENT_EMAIL  email del cliente (obligatorio para subir)
#   RC_FLEET_TOKEN   token Bearer del endpoint de flota (obligatorio para subir)
#   RC_FLEET_URL     endpoint REST (def: https://resolvecore.website/wp-json/rc/v1/fleet)
#   RC_TICKET_ID     id de ticket Mantis a asociar (opcional)
# Un fallo de red avisa pero NO rompe el script: el JSON local ya está a salvo.

RC_CLIENT_EMAIL="${RC_CLIENT_EMAIL:-}"
RC_FLEET_TOKEN="${RC_FLEET_TOKEN:-}"
RC_FLEET_URL="${RC_FLEET_URL:-https://resolvecore.website/wp-json/rc/v1/fleet}"
RC_TICKET_ID="${RC_TICKET_ID:-}"

if [ -n "$RC_CLIENT_EMAIL" ] && [ -n "$RC_FLEET_TOKEN" ]; then
    if ! command -v curl >/dev/null 2>&1; then
        warn "curl no disponible: no se puede subir el diagnóstico (JSON local en $FILE)."
    else
        info "Subiendo diagnóstico a $RC_FLEET_URL ..."
        # Envolvemos el JSON del diagnóstico en el sobre que espera el endpoint.
        # El fichero ya es un objeto JSON válido, así que se incrusta tal cual.
        ticket_field=""
        [ -n "$RC_TICKET_ID" ] && ticket_field="\"ticket_id\": ${RC_TICKET_ID},"
        payload="{\"client_email\": \"${RC_CLIENT_EMAIL}\", ${ticket_field} \"diagnostico\": $(cat "$FILE")}"

        http_code=$(curl -sS -o /tmp/rc_fleet_resp.$$ -w '%{http_code}' \
            -X POST "$RC_FLEET_URL" \
            -H "Authorization: Bearer ${RC_FLEET_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "$payload" --max-time 15 || echo "000")

        if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
            info "Subida OK: $(cat /tmp/rc_fleet_resp.$$)"
        else
            warn "Fallo al subir (HTTP $http_code): $(cat /tmp/rc_fleet_resp.$$ 2>/dev/null)"
            warn "El JSON local sigue disponible en: $FILE"
        fi
        rm -f /tmp/rc_fleet_resp.$$
    fi
else
    info "(Subida automática omitida: exporta RC_CLIENT_EMAIL y RC_FLEET_TOKEN para activarla.)"
fi
