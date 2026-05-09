#!/usr/bin/env bash
# =============================================================================
# ResolveCore - Menu macOS
# Menu interactivo para tecnicos ResolveCore en Mac
# =============================================================================

SCRIPT_DIR_EARLY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DIAG_FLAGS=()
OPT_FLAGS=()
NIVEL_POSITIONAL=""
DIAG_HAS_FLAG=false
OPT_HAS_FLAG=false

show_help() {
    cat <<'EOF'
NAME
    ResolveCore.sh - Menu interactivo de herramientas ResolveCore para macOS

SYNOPSIS
    bash ResolveCore.sh                                          # menu
    bash ResolveCore.sh [-O <dir>] [--host <ip>] [--user <name>]
                        [--port <n>] [--local]                   # forward diagnostico
    bash ResolveCore.sh [--dry-run] [--confirm] [--undo] [NIVEL] # forward optimizacion

DESCRIPTION
    Sin flags: lanza menu TUI (diagnostico, optimizacion, ayuda, salir).
    Con flags de modulo: salta el menu e invoca diagnostico.sh u
    optimizacion.sh con esos flags.

    NOTA: los modulos macOS son STUB (DEMO). Implementacion completa
    pendiente para fase futura del TFG.

OPTIONS DEL LAUNCHER
    -h, --help        Muestra esta ayuda y sale.

FLAGS DE DIAGNOSTICO (forward a diagnostico.sh)
    -O, --output <dir>      Directorio salida JSON.
    --local                 Forzar modo local (default).
    --host <ip>             Modo remoto via SSH.
    --user <name>           Usuario SSH.
    --port <n>              Puerto SSH (default: 22).

FLAGS DE OPTIMIZACION (forward a optimizacion.sh)
    NIVEL                   ligero | estandar | rendimiento | extreme.
    --dry-run               Simula sin aplicar.
    --confirm               Confirma acciones destructivas.
    --undo                  Deshace cambios (cuando se implemente).

MENU
    1. DIAGNOSTICO    Lanza diagnostico.sh.
    2. OPTIMIZACION   Lanza optimizacion.sh.
    3. AYUDA          Guia rapida embebida.
    4. SALIR          Cierra el programa.

REQUISITOS
    - Terminal interactiva (modo menu).
    - bash 3.2+ (preinstalado en macOS).
    - brew install osx-cpu-temp (opcional, diagnostico termico).

EXAMPLES
    bash scripts/macos/ResolveCore.sh
    bash scripts/macos/ResolveCore.sh -O /tmp
    bash scripts/macos/ResolveCore.sh --host 192.168.1.10 --user fran
    bash scripts/macos/ResolveCore.sh --dry-run rendimiento

EXIT CODES
    0    Salida normal o ayuda mostrada.
    1    No es terminal interactiva (modo menu).
    2    Combinacion invalida de flags.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)    show_help; exit 0 ;;
        -O|--output)  DIAG_FLAGS+=("--output" "${2:-}"); DIAG_HAS_FLAG=true; shift 2 ;;
        --host)       DIAG_FLAGS+=("--host" "${2:-}"); DIAG_HAS_FLAG=true; shift 2 ;;
        --user)       DIAG_FLAGS+=("--user" "${2:-}"); DIAG_HAS_FLAG=true; shift 2 ;;
        --port)       DIAG_FLAGS+=("--port" "${2:-}"); DIAG_HAS_FLAG=true; shift 2 ;;
        --local)      DIAG_FLAGS+=("--local"); DIAG_HAS_FLAG=true; shift ;;
        --dry-run)    OPT_FLAGS+=("--dry-run"); OPT_HAS_FLAG=true; shift ;;
        --confirm)    OPT_FLAGS+=("--confirm"); OPT_HAS_FLAG=true; shift ;;
        --undo)       OPT_FLAGS+=("--undo"); OPT_HAS_FLAG=true; shift ;;
        ligero|estandar|rendimiento|extreme) NIVEL_POSITIONAL="$1"; OPT_HAS_FLAG=true; shift ;;
        *) shift ;;
    esac
done

if [[ "$DIAG_HAS_FLAG" == "true" && "$OPT_HAS_FLAG" == "true" ]]; then
    echo "[X] Flags de diagnostico y optimizacion son mutuamente exclusivos." >&2
    exit 2
fi
if [[ "$DIAG_HAS_FLAG" == "true" ]]; then
    exec bash "$SCRIPT_DIR_EARLY/diagnostico.sh" "${DIAG_FLAGS[@]}"
fi
if [[ "$OPT_HAS_FLAG" == "true" ]]; then
    OPT_CMD=(bash "$SCRIPT_DIR_EARLY/optimizacion.sh" "${OPT_FLAGS[@]}")
    [[ -n "$NIVEL_POSITIONAL" ]] && OPT_CMD+=("$NIVEL_POSITIONAL")
    exec "${OPT_CMD[@]}"
fi

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
        1) nivel_opt="ligero" ;;
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