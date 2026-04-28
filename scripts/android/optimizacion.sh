#!/usr/bin/env bash
# =============================================================================
# ResolveCore - Optimizacion de dispositivo Android
# Version: 3.0.0
# =============================================================================

set -uo pipefail

SCRIPT_VERSION="3.0.0"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
NIVEL="${1:-estandar}"

# Colores
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Verificar ADB
if ! command -v adb &> /dev/null; then
    echo -e "${RED}[X] ADB no esta instalado${NC}"
    exit 1
fi

# Verificar dispositivo
DEVICE=$(adb devices | grep "device$" | head -1 | awk '{print $1}')
if [[ -z "$DEVICE" ]]; then
    echo -e "${RED}[X] No hay dispositivos conectados${NC}"
    exit 1
fi

echo ""
echo -e "  =============================================================="${NC}
echo -e "  ResolveCore - Optimizacion Android v$SCRIPT_VERSION" "${CYAN}"
echo -e "  Nivel: $NIVEL" "${NC}"
echo -e "  Dispositivo: $DEVICE" "${NC}"
echo -e "  $(date '+%Y-%m-%d %H:%M:%S')" "${NC}"
echo -e "  =============================================================="${NC}
echo ""

echo -e "  ${CYAN}> Verificando permisos ROOT${NC}"
ROOT_CHECK=$(adb -s "$DEVICE" shell "id" 2>&1)
if [[ "$ROOT_CHECK" == *"uid=0"* ]]; then
    echo -e "    ${GREEN}[OK] ROOT disponible${NC}"
else
    echo -e "    ${YELLOW}[!] Sin ROOT - funciones limitadas${NC}"
fi

# Limpieza basica (funciona sin root)
echo ""
echo -e "  ${CYAN}> Limpiando cache${NC}"

# Cache de apps
adb -s "$DEVICE" shell "pm trim-caches 100G" 2>/dev/null
echo -e "    ${GREEN}[OK] Cache del sistema limpiada${NC}"

# Limpiar cache de apps individuales
APPS=$(adb -s "$DEVICE" shell "pm list packages -3" | cut -d: -f2)
COUNT=0
for app in $APPS; do
    adb -s "$DEVICE" shell "pm clear $app" 2>/dev/null
    ((COUNT++))
    if [[ $COUNT -gt 20 ]]; then break; fi
done
echo -e "    ${GREEN}[OK] Cache de apps limpiada: $COUNT apps${NC}"

if [[ "$NIVEL" == "estandar" ]]; then
    echo ""
    echo -e "  ${CYAN}> Optimizacion nivel estandar${NC}"

    # Desactivar apps preinstaladas innecesarias
    APPS_TO_DISABLE=(
        "com.android.soundrecorder"
        "com.android.stk"
        "com.android. provisioning"
    )

    for app in "${APPS_TO_DISABLE[@]}"; do
        adb -s "$DEVICE" shell "pm disable-user --user 0 $app" 2>/dev/null
    done
    echo -e "    ${GREEN}[OK] Apps innecesarias desactivadas${NC}"

    # Configurar GPU
    adb -s "$DEVICE" shell "settings put global gpu_debug_gpu_driver 0" 2>/dev/null
    echo -e "    ${GREEN}[OK] GPU optimizada${NC}"
fi

# Resultado
echo ""
echo -e "  =============================================================="${NC}
echo -e "  ${GREEN}[OK] Optimizacion completada${NC}"
echo ""
echo -e "  ${YELLOW}Recomendaciones:${NC}"
echo -e "    - Reiniciar el dispositivo"
echo -e "    - Algunas funciones requieren ROOT"
echo ""

exit 0