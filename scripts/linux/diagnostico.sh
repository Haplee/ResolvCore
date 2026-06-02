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

OUTPUT_DIR="${1:-$(dirname "$0")/../diagnosticos}"
mkdir -p "$OUTPUT_DIR"

HOST=$(hostname)
TS=$(date +%Y%m%d_%H%M%S)
FILE="$OUTPUT_DIR/diagnostico_${HOST}_${TS}.json"

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
fi

# ── Volcado JSON ────────────────────────────────────────────────────────────
# Se escribe manual para no depender de jq.

cat > "$FILE" <<EOF
{
  "_meta": {
    "plataforma": "linux",
    "hostname": "$HOST",
    "version": "2.0"
  },
  "timestamp": "$(date -Iseconds)",
  "hostname": "$HOST",
  "os": "$os_name",
  "kernel": "$kernel",
  "uptime_horas": $uptime_horas,
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
  "actualizaciones": {
    "pendientes": $actualizaciones
  }
}
EOF

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
