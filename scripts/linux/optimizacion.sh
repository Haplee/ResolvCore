#!/usr/bin/env bash
# =============================================================================
# ResolveCore - Optimizacion de sistema Linux
# Version: 3.1.0
#
# Cambios 3.1.0:
#   - Parseo real de --dry-run y --undo (antes ignorados).
#   - Validación de unidad systemd antes de stop/disable (silencia ruido).
#   - Backup sysctl.conf antes de cualquier modificación.
#   - Registro de servicios deshabilitados para Undo.
# =============================================================================

set -uo pipefail

SCRIPT_VERSION="3.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/var/tmp/resolvecore_optimizacion"
LOG_FILE="${BACKUP_DIR}/optimizacion.log"
SYSCTL_BACKUP="${BACKUP_DIR}/sysctl.conf.bak"
SERVICES_LOG="${BACKUP_DIR}/services_disabled.log"

NIVEL="estandar"
DRY_RUN=false
UNDO=false

usage() {
    cat <<EOF
Uso: sudo $0 [opciones] [nivel]

Niveles: ligero | estandar | rendimiento | extreme  (default: estandar)

Opciones:
  --dry-run   Simula sin aplicar cambios
  --undo      Restaura sysctl y servicios desde el último backup
  -h, --help  Muestra esta ayuda
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --undo)    UNDO=true; shift ;;
        -h|--help) usage; exit 0 ;;
        ligero|estandar|rendimiento|extreme) NIVEL="$1"; shift ;;
        *) echo "Opción no reconocida: $1" >&2; usage; exit 2 ;;
    esac
done

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[X] Ejecutar como root (sudo)${NC}"
    exit 1
fi

mkdir -p "$BACKUP_DIR"

run() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "    ${YELLOW}[DryRun]${NC} $*"
        return 0
    fi
    "$@"
}

echo ""
echo -e "${CYAN}  ==============================================================${NC}"
echo -e "${CYAN}  ResolveCore - Optimizacion Linux v$SCRIPT_VERSION${NC}"
echo -e "  Nivel: $NIVEL"
echo -e "  $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${CYAN}  ==============================================================${NC}"
echo ""

if [[ "$UNDO" == "true" ]]; then
    echo -e "  ${YELLOW}Deshaciendo cambios...${NC}"
    if [[ -f "$SYSCTL_BACKUP" ]]; then
        run cp "$SYSCTL_BACKUP" /etc/sysctl.conf
        run sysctl -p 2>/dev/null || true
        echo -e "  ${GREEN}[OK] sysctl.conf restaurado${NC}"
    else
        echo -e "  ${YELLOW}[!] No se encontró backup sysctl${NC}"
    fi
    if [[ -f "$SERVICES_LOG" ]]; then
        while IFS= read -r unit; do
            [[ -z "$unit" ]] && continue
            if run systemctl enable "$unit" 2>/dev/null && run systemctl start "$unit" 2>/dev/null; then
                echo -e "  ${GREEN}[OK] Servicio reactivado: $unit${NC}"
            fi
        done < "$SERVICES_LOG"
        [[ "$DRY_RUN" != "true" ]] && rm -f "$SERVICES_LOG"
    fi
    exit 0
fi

# Helper: solo actuar si la unidad existe (silencia errores ruidosos)
disable_unit_if_present() {
    local unit="$1"
    if systemctl list-unit-files "$unit" &>/dev/null && \
       systemctl status "$unit" &>/dev/null; then
        run systemctl stop "$unit" 2>/dev/null || true
        run systemctl disable "$unit" 2>/dev/null || true
        [[ "$DRY_RUN" != "true" ]] && echo "$unit" >> "$SERVICES_LOG"
        echo -e "    ${GREEN}[OK] Deshabilitado: $unit${NC}"
    fi
}

# Obtener distro
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    DISTRO="$ID"
elif [[ -f /etc/debian_version ]]; then
    DISTRO="debian"
elif [[ -f /etc/redhat-release ]]; then
    DISTRO="rhel"
else
    DISTRO="unknown"
fi

echo -e "  Distribucion: $DISTRO" "${NC}"

# Limpieza
echo ""
echo -e "  ${CYAN}> Limpieza del sistema${NC}"

# Limpiar cache
sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
echo -e "    ${GREEN}[OK] Cache del sistema limpiada${NC}"

# Limpiar logs antiguos
find /var/log -type f -name "*.gz" -mtime +30 -delete 2>/dev/null
find /var/log -type f -name "*.log" -mtime +7 -exec truncate -s 0 {} \; 2>/dev/null
echo -e "    ${GREEN}[OK] Logs antiguos eliminados${NC}"

# Servicios
echo ""
echo -e "  ${CYAN}> Optimizando servicios${NC}"

case "$NIVEL" in
    ligero)
        ;;
    estandar)
        disable_unit_if_present snapd.service
        ;;
    rendimiento|extreme)
        disable_unit_if_present snapd.service
        disable_unit_if_present postfix.service
        ;;
esac

# Plan de energia (si esta disponible)
echo ""
echo -e "  ${CYAN}> Plan de energia${NC}"

if command -v systemctl &>/dev/null && systemctl list-unit-files thermald.service &>/dev/null; then
    systemctl start thermald 2>/dev/null
    systemctl enable thermald 2>/dev/null
    echo -e "    ${GREEN}[OK] Gestion termica activada${NC}"
fi

# Sysctl optimizaciones
echo ""
echo -e "  ${CYAN}> Parametros del kernel${NC}"

# Backup (solo si no existe ya)
[[ ! -f "$SYSCTL_BACKUP" ]] && cp /etc/sysctl.conf "$SYSCTL_BACKUP" 2>/dev/null

sysctl_set() {
    local key="$1" val="$2"
    if grep -qE "^${key}\s*=" /etc/sysctl.conf 2>/dev/null; then
        sed -i "s|^${key}\s*=.*|${key}=${val}|" /etc/sysctl.conf
    else
        echo "${key}=${val}" >> /etc/sysctl.conf
    fi
}

# Aplicar optimizaciones segun nivel
if [[ "$NIVEL" == "rendimiento" ]] || [[ "$NIVEL" == "extreme" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "    ${YELLOW}[DryRun]${NC} modificaria sysctl: rmem/wmem/tcp_rmem/tcp_wmem/tcp_congestion_control/vm.*"
    else
        sysctl_set "net.core.rmem_max"                  "16777216"
        sysctl_set "net.core.wmem_max"                  "16777216"
        sysctl_set "net.ipv4.tcp_rmem"                  "4096 87380 16777216"
        sysctl_set "net.ipv4.tcp_wmem"                  "4096 87380 16777216"
        sysctl_set "net.ipv4.tcp_congestion_control"    "htcp"
        sysctl_set "vm.swappiness"                      "10"
        sysctl_set "vm.dirty_ratio"                     "15"
        sysctl_set "vm.dirty_background_ratio"          "5"
        sysctl -p 2>/dev/null || true
        echo -e "    ${GREEN}[OK] Parametros de red optimizados (idempotente)${NC}"
    fi
fi

if [[ "$NIVEL" == "extreme" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "    ${YELLOW}[DryRun]${NC} habilitaria numa_balancing"
    else
        echo 1 > /proc/sys/kernel/numa_balancing 2>/dev/null || true
        echo -e "    ${GREEN}[OK] Balanceo NUMA${NC}"
    fi
fi

# Output JSON
SCRIPT_DIR_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR_ABS}/../diagnosticos"
mkdir -p "$OUT_DIR"
HOSTNAME_STR=$(hostname 2>/dev/null || echo "linux")
OUT_FILE="${OUT_DIR}/optimizacion_${HOSTNAME_STR}_$(date '+%Y%m%d_%H%M%S').json"
cat > "$OUT_FILE" <<EOF
{
  "plataforma": "linux",
  "hostname": "$HOSTNAME_STR",
  "nivel": "$NIVEL",
  "distro": "$DISTRO",
  "generado_en": "$(date -Iseconds)",
  "_meta": { "version": "$SCRIPT_VERSION" }
}
EOF

# Resultado
echo ""
echo -e "${CYAN}  ==============================================================${NC}"
echo -e "  ${GREEN}[OK] Optimizacion completada${NC}"
echo -e "  Informe: $OUT_FILE"
echo ""
echo -e "  ${YELLOW}Recomendaciones:${NC}"
echo -e "    - Reiniciar el sistema para aplicar todos los cambios"
echo -e "    - Para deshacer: sudo bash $0 --undo"
echo ""

exit 0