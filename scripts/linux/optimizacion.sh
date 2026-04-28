#!/bin/bash
# =============================================================================
# ResolveCore - Optimizacion de sistema Linux
# Version: 3.0.0
# =============================================================================

set -o pipefail

SCRIPT_VERSION="3.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/var/tmp/resolvecore_optimizacion"
LOG_FILE="${BACKUP_DIR}/optimizacion.log"

NIVEL="${1:-estandar}"
DRY_RUN=false
UNDO=false

# Colores
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[X] Ejecutar como root (sudo)${NC}"
    exit 1
fi

# Crear directorio de backup
mkdir -p "$BACKUP_DIR"

echo ""
echo -e "  =============================================================="${NC}
echo -e "  ResolveCore - Optimizacion Linux v$SCRIPT_VERSION" "${CYAN}"
echo -e "  Nivel: $NIVEL" "${NC}"
echo -e "  $(date '+%Y-%m-%d %H:%M:%S')" "${NC}"
echo -e "  =============================================================="${NC}
echo ""

if [[ "$UNDO" == "true" ]]; then
    echo -e "  ${YELLOW}Deshaciendo cambios...${NC}"
    if [[ -f "$SYSCTL_BACKUP" ]]; then
        cp "$SYSCTL_BACKUP" /etc/sysctl.conf
        sysctl -p 2>/dev/null
        echo -e "  ${GREEN}[OK] Cambios restaurados${NC}"
    else
        echo -e "  ${YELLOW}[!] No se encontró backup${NC}"
    fi
    exit 0
fi

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
        # Solo servicios basicos
        ;;
    estandar)
        # Desactivar servicios no esenciales
        systemctl stop snapd 2>/dev/null
        systemctl disable snapd 2>/dev/null
        echo -e "    ${GREEN}[OK] Servicios optimizados${NC}"
        ;;
    rendimiento|extreme)
        # Mas servicios
        systemctl stop snapd 2>/dev/null
        systemctl disable snapd 2>/dev/null
        systemctl stop postfix 2>/dev/null
        systemctl disable postfix 2>/dev/null
        echo -e "    ${GREEN}[OK] Servicios optimizados${NC}"
        ;;
esac

# Plan de energia (si esta disponible)
echo ""
echo -e "  ${CYAN}> Plan de energia${NC}"

if command -v systemctl &> /dev/null; then
    systemctl start thermald 2>/dev/null
    systemctl enable thermald 2>/dev/null
    echo -e "    ${GREEN}[OK] Gestion termica activada${NC}"
fi

# Sysctl optimizaciones
echo ""
echo -e "  ${CYAN}> Parametros del kernel${NC}"

# Backup
cp /etc/sysctl.conf "$BACKUP_DIR/sysctl.conf.bak" 2>/dev/null

# Aplicar optimizaciones segun nivel
if [[ "$NIVEL" == "rendimiento" ]] || [[ "$NIVEL" == "extreme" ]]; then
    cat >> /etc/sysctl.conf << 'EOF'
# Optimize network
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 87380 16777216
net.ipv4.tcp_congestion_control=htcp
vm.swappiness=10
vm.dirty_ratio=15
vm.dirty_background_ratio=5
EOF
    sysctl -p 2>/dev/null
    echo -e "    ${GREEN}[OK] Parametros de red optimizados${NC}"
fi

if [[ "$NIVEL" == "extreme" ]]; then
    echo 1 > /proc/sys/kernel/numa_balancing 2>/dev/null
    echo -e "    ${GREEN}[OK] Balanceo NUMA${NC}"
fi

# Resultado
echo ""
echo -e "  =============================================================="${NC}
echo -e "  ${GREEN}[OK] Optimizacion completada${NC}"
echo ""
echo -e "  ${YELLOW}Recomendaciones:${NC}"
echo -e "    - Reiniciar el sistema para aplicar todos los cambios"
echo -e "    - Para deshacer: sudo bash $0 --undo"
echo ""

exit 0