#!/usr/bin/env bash
# =============================================================================
# ResolveCore - Menu macOS
# Menu interactivo para tecnicos ResolveCore en Mac
# =============================================================================

if [[ ! -t 0 ]]; then
    echo "Este script debe ejecutarse en una terminal interactiva"
    echo "Ejemplo: bash scripts/macos/ResolveCore.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colores
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'; NC='\033[0m'
MAGENTA='\033[0;35m'

show_banner() {
    clear
    echo ""
    echo -e "  +---------------------------------------------------------------+"
    echo -e "  |                    ${WHITE}RESOLVECORE${NC}                                |"
    echo -e "  |              ${GRAY}Menu de Herramientas - macOS${NC}                   |"
    echo -e "  +---------------------------------------------------------------+"
    echo ""
    echo -e "  ${GRAY}Equipo:${NC} $(hostname)"
    echo -e "  ${GRAY}Usuario:${NC} $(whoami)"
    echo -e "  ${GRAY}Fecha:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

show_menu() {
    echo -e "  +---------------------------------------------------------------+"
    echo -e "  |  ${WHITE}SELECCIONA UNA OPCION:${NC}                                        |"
    echo -e "  +---------------------------------------------------------------+"
    echo ""
    echo -e "    ${GREEN}1.${NC}  [DIAGNOSTICO]   - Analisis completo del sistema macOS"
    echo -e "                       - Recoge hardware, software, red, seguridad"
    echo -e "                       - Genera archivo JSON para ResolveCore"
    echo ""
    echo -e "    ${YELLOW}2.${NC}  [OPTIMIZACION]  - Optimizar rendimiento del Mac"
    echo -e "                       - Niveles: Basico, Estandar, Rendimiento"
    echo -e "                       - Incluye limpieza, servicios, preferences"
    echo ""
    echo -e "    ${CYAN}3.${NC}  [AYUDA]         - Ver guia rapida de uso"
    echo ""
    echo -e "    ${RED}4.${NC}  [SALIR]         - Salir del programa"
    echo ""
    echo -e "  +---------------------------------------------------------------+"
    echo ""
}

show_help() {
    echo ""
    echo -e "  ${WHITE}================================================================${NC}"
    echo -e "  ${WHITE}GUIA RAPIDA DE RESOLVECORE - macOS${NC}"
    echo -e "  ${WHITE}================================================================${NC}"
    echo ""
    echo -e "  ${GREEN}[DIAGNOSTICO]${NC}"
    echo -e "  Cuando usarlo:"
    echo -e "    - Nuevo cliente o Mac desconocido"
    echo -e "    - Problemas de rendimiento o estabilidad"
    echo -e "    - Para crear historial del equipo en ResolveCore"
    echo ""
    echo -e "  Resultado:"
    echo -e "    - Genera archivo JSON con todos los datos del sistema"
    echo -e "    - Se guarda en: diagnosticos/diagnostico_<hostname>_<fecha>.json"
    echo -e "    - Importar en ResolveCore: Diagnostico > Importar JSON"
    echo ""
    echo -e "  Requisitos:"
    echo -e "    - Para temperatura: brew install osx-cpu-temp"
    echo ""
    echo -e "  ================================================================="
    echo ""
    echo -e "  ${YELLOW}[OPTIMIZACION]${NC}"
    echo -e "  Cuando usarlo:"
    echo -e "    - Mac lento o con bajo rendimiento"
    echo -e "    - Mantenimiento preventivo periodico"
    echo -e "    - Despues de instalar macOS limpio"
    echo ""
    echo -e "  Niveles:"
    echo -e "    - Basico: Limpieza basica"
    echo -e "    - Estandar: Optimizacion completa (recomendado)"
    echo -e "    - Rendimiento: Mayor optimizacion"
    echo ""
    echo -e "  ================================================================="
    echo ""
    read -p "  Presiona ENTER para volver al menu..."
}

get_system_summary() {
    echo ""
    echo -e "  ${CYAN}Resumen rapido del equipo:${NC}"
    echo -e "  ${GRAY}-------------------------------------------${NC}"

    # CPU
    echo -e "  ${WHITE}CPU:${NC} $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Apple Silicon')"

    # RAM
    RAM_TOTAL=$(sysctl -n hw.memsize | awk '{print $1/1024/1024/1024 " GB"}')
    echo -e "  ${WHITE}RAM:${NC} ${RAM_TOTAL}"

    # Disco
    DISC_FREE=$(df -h / | tail -1 | awk '{print $4}')
    echo -e "  ${WHITE}Disco libre:${NC} ${DISC_FREE}"

    # OS
    OS_NAME=$(sw_vers -productName)
    OS_VER=$(sw_vers -productVersion)
    echo -e "  ${WHITE}macOS:${NC} ${OS_NAME} ${OS_VER}"

    echo -e "  ${GRAY}-------------------------------------------${NC}"
    echo ""
}

run_diagnostico() {
    echo ""
    echo -e "  ${YELLOW}Ejecutando diagnostico...${NC}"
    echo ""

    cd "$SCRIPT_DIR"
    bash "$SCRIPT_DIR/diagnostico.sh"

    echo ""
    echo -e "  ${GREEN}[OK] Diagnostico completado${NC}"
    echo ""
    echo -e "  ${CYAN}Siguiente paso:${NC}"
    echo -e "    1. Copia el archivo JSON generado"
    echo -e "    2. Ve a ResolveCore > Diagnostico del equipo"
    echo -e "    3. Importa el archivo JSON"
    echo ""
    read -p "  Presiona ENTER para continuar..."
}

run_optimizacion() {
    if [[ $EUID -ne 0 ]]; then
        echo ""
        echo -e "  ${RED}[!] Se requieren permisos de administrador${NC}"
        echo -e "  Ejecuta el script con: sudo bash scripts/macos/ResolveCore.sh"
        echo ""
        read -p "  Presiona ENTER para continuar..."
        return
    fi

    echo ""
    echo -e "  +---------------------------------------------------------------+"
    echo -e "  |  ${WHITE}SELECCIONA NIVEL DE OPTIMIZACION:${NC}                            |"
    echo -e "  +---------------------------------------------------------------+"
    echo ""
    echo -e "    ${GREEN}1.${NC}  BASICO       - Limpieza basica"
    echo -e "    ${YELLOW}2.${NC}  ESTANDAR     - Optimizacion completa (recomendado)"
    echo -e "    ${MAGENTA}3.${NC}  RENDIMIENTO - Mayor optimizacion"
    echo -e "    ${RED}4.${NC}  VOLVER al menu principal"
    echo ""
    echo -e "  +---------------------------------------------------------------+"

    read -p "  Selecciona opcion (1-4): " nivel

    case $nivel in
        1) nivel_opt="basico" ;;
        2) nivel_opt="estandar" ;;
        3) nivel_opt="rendimiento" ;;
        4) return ;;
        *) echo -e "  ${RED}Opcion no valida${NC}"; return ;;
    esac

    echo ""
    echo -e "  ${YELLOW}Ejecutando optimizacion...${NC}"
    echo ""

    cd "$SCRIPT_DIR"
    bash "$SCRIPT_DIR/optimizacion.sh" "$nivel_opt"

    echo ""
    echo -e "  ${GREEN}[OK] Optimizacion completada${NC}"
    echo ""
    echo -e "  ${CYAN}Siguiente paso:${NC}"
    echo -e "    1. Reinicia el Mac para aplicar cambios"
    echo -e "    2. Verifica que todo funcione correctamente"
    echo -e "    3. Si hay problemas: bash optimizacion.sh -Undo"
    echo ""
    read -p "  Presiona ENTER para continuar..."
}

# Programa principal
while true; do
    show_banner
    show_menu

    read -p "  Selecciona una opcion (1-4): " opcion
    [[ -z "$opcion" ]] && { echo ""; exit 0; }

    case $opcion in
        1) run_diagnostico ;;
        2) run_optimizacion ;;
        3) show_help ;;
        4)
            echo ""
            echo -e "  ${GREEN}Hasta luego!${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo ""
            echo -e "  ${RED}Opcion no valida${NC}"
            read -p "  Presiona ENTER para continuar..."
            ;;
    esac
done