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
# Autor:   Francisco Vidal Mateo (FranVi)
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
