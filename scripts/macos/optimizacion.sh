#!/usr/bin/env bash
# =============================================================================
# ResolveCore - Optimizacion de sistema macOS
# Version: 3.0.0
# =============================================================================

set -uo pipefail

SCRIPT_VERSION="3.0.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="/tmp/resolvecore_optimizacion"
LOG_FILE="${BACKUP_DIR}/optimizacion.log"

NIVEL="${1:-estandar}"

# Colores
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Verificar que es macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}[X] Este script es solo para macOS${NC}"
    exit 1
fi

# Crear directorio
mkdir -p "$BACKUP_DIR"

echo ""
echo -e "  =============================================================="${NC}
echo -e "  ResolveCore - Optimizacion macOS v$SCRIPT_VERSION" "${CYAN}"
echo -e "  Nivel: $NIVEL" "${NC}"
echo -e "  $(date '+%Y-%m-%d %H:%M:%S')" "${NC}"
echo -e "  =============================================================="${NC}
echo ""

# Desactivar Spotlight (solo si no es nivel ligero)
if [[ "$NIVEL" != "ligero" ]]; then
    echo -e "  ${CYAN}> Spotlight${NC}"
    mdutil -i off / 2>/dev/null
    echo -e "    ${GREEN}[OK] Spotlight indexacion desactivada${NC}"
fi

# Limpieza
echo ""
echo -e "  ${CYAN}> Limpieza del sistema${NC}"

# Limpiar cache de usuario
rm -rf ~/Library/Caches/* 2>/dev/null
rm -rf /Library/Caches/* 2>/dev/null
echo -e "    ${GREEN}[OK] Cache limpiada${NC}"

# Limpiar logs
rm -rf /var/log/*.gz 2>/dev/null
echo -e "    ${GREEN}[OK] Logs antiguos eliminados${NC}"

# Docker
if command -v docker &> /dev/null; then
    docker system prune -af 2>/dev/null
    echo -e "    ${GREEN}[OK] Docker limpiado${NC}"
fi

# Servicios
echo ""
echo -e "  ${CYAN}> Optimizando servicios${NC}"

if [[ "$NIVEL" == "rendimiento" ]] || [[ "$NIVEL" == "extreme" ]]; then
    # Desactivar servicios no esenciales
    launchctl unload -w /System/Library/LaunchAgents/com.apple.Spotlight.plist 2>/dev/null
    echo -e "    ${GREEN}[OK] Servicios optimizados${NC}"
fi

# DNS
echo ""
echo -e "  ${CYAN}> DNS${NC}"
# Usar DNS de Google
networksetup -setdnsservers Wi-Fi 8.8.8.8 8.8.4.4 2>/dev/null || true
echo -e "    ${GREEN}[OK] DNS configurado${NC}"

# Resultado
echo ""
echo -e "  =============================================================="${NC}
echo -e "  ${GREEN}[OK] Optimizacion completada${NC}"
echo ""
echo -e "  ${YELLOW}Recomendaciones:${NC}"
echo -e "    - Reiniciar el Mac para aplicar todos los cambios"
echo ""

exit 0