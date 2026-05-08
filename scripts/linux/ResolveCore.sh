#!/bin/bash
# =============================================================================
# ResolveCore - Menu Linux
# Menu interactivo para tecnicos ResolveCore en Linux
# =============================================================================

SCRIPT_DIR_EARLY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Pass-through: si llega flag de modulo, invocar directo y salir ──────────
DIAG_FLAGS=()
OPT_FLAGS=()
NIVEL_POSITIONAL=""
PARSE_DONE=false
ARGS_REMAIN=()

show_help() {
    cat <<'EOF'
NAME
    ResolveCore.sh - Menu interactivo de herramientas ResolveCore para Linux

SYNOPSIS
    bash ResolveCore.sh                                       # menu
    bash ResolveCore.sh [-O <dir>] [-S] [-I|-A]               # forward diagnostico
    bash ResolveCore.sh [--dry-run] [--undo] [NIVEL]          # forward optimizacion

DESCRIPTION
    Sin flags: lanza menu TUI (diagnostico, optimizacion, ayuda, salir).
    Con flags de modulo: salta el menu e invoca diagnostico.sh u
    optimizacion.sh con esos flags. Util para automatizacion.

OPTIONS DEL LAUNCHER
    -h, --help        Muestra esta ayuda y sale.

FLAGS DE DIAGNOSTICO (forward a diagnostico.sh)
    -O, --output <dir>      Directorio salida JSON/HTML.
    -S, --silent            Sin salida por consola.
    -I, --install           Instala paquetes opcionales (lm-sensors,
                            smartmontools, pciutils, jq, bc, ufw, ping).
                            Pide confirmacion.
    -A, --auto-install      Igual que -I sin confirmar.

FLAGS DE OPTIMIZACION (forward a optimizacion.sh)
    NIVEL                   ligero | estandar | rendimiento | extreme
                            (default: estandar).
    --dry-run               Simula sin aplicar.
    --undo                  Restaura sysctl y servicios.

MENU
    1. DIAGNOSTICO    Lanza diagnostico.sh.
    2. OPTIMIZACION   Lanza optimizacion.sh.
    3. AYUDA          Guia rapida embebida.
    4. SALIR          Cierra el programa.

REQUISITOS
    - Terminal interactiva para el menu (no pipes).
    - bash 4+ (cualquier distro moderna).
    - sudo para optimizacion.

EXAMPLES
    # Menu interactivo
    bash scripts/linux/ResolveCore.sh

    # Pass-through diagnostico
    bash scripts/linux/ResolveCore.sh -A
    bash scripts/linux/ResolveCore.sh -O /tmp -S

    # Pass-through optimizacion
    sudo bash scripts/linux/ResolveCore.sh --dry-run rendimiento
    sudo bash scripts/linux/ResolveCore.sh --undo

    # Equivalente directo
    bash scripts/linux/diagnostico.sh -A
    sudo bash scripts/linux/optimizacion.sh ligero

EXIT CODES
    0    Salida normal o ayuda mostrada.
    1    No es terminal interactiva (modo menu).
    2    Combinacion invalida de flags (diag + opt).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help; exit 0 ;;
        # Diagnostico flags
        -O|--output)            DIAG_FLAGS+=("--output" "${2:-}"); shift 2 ;;
        -S|--silent)            DIAG_FLAGS+=("--silent"); shift ;;
        -I|--install|--install-deps) DIAG_FLAGS+=("--install"); shift ;;
        -A|--auto-install)      DIAG_FLAGS+=("--auto-install"); shift ;;
        # Optimizacion flags
        --dry-run)              OPT_FLAGS+=("--dry-run"); shift ;;
        --undo)                 OPT_FLAGS+=("--undo"); shift ;;
        ligero|estandar|rendimiento|extreme) NIVEL_POSITIONAL="$1"; shift ;;
        *) ARGS_REMAIN+=("$1"); shift ;;
    esac
done

if [[ ${#DIAG_FLAGS[@]} -gt 0 && (${#OPT_FLAGS[@]} -gt 0 || -n "$NIVEL_POSITIONAL") ]]; then
    echo "[X] Flags de diagnostico y optimizacion son mutuamente exclusivos." >&2
    exit 2
fi
if [[ ${#DIAG_FLAGS[@]} -gt 0 ]]; then
    exec bash "$SCRIPT_DIR_EARLY/diagnostico.sh" "${DIAG_FLAGS[@]}"
fi
if [[ ${#OPT_FLAGS[@]} -gt 0 || -n "$NIVEL_POSITIONAL" ]]; then
    OPT_CMD=(bash "$SCRIPT_DIR_EARLY/optimizacion.sh" "${OPT_FLAGS[@]}")
    [[ -n "$NIVEL_POSITIONAL" ]] && OPT_CMD+=("$NIVEL_POSITIONAL")
    exec "${OPT_CMD[@]}"
fi

if [[ ! -t 0 ]]; then
    echo "Este script debe ejecutarse en una terminal interactiva"
    echo "Ejemplo: bash scripts/linux/ResolveCore.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../.env" 2>/dev/null

# Colores
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'; NC='\033[0m'

show_banner() {
    clear
    echo ""
    echo -e "  +---------------------------------------------------------------+"
    echo -e "  |                    ${WHITE}RESOLVECORE${NC}                                |"
    echo -e "  |              ${GRAY}Menu de Herramientas - Linux${NC}                   |"
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
    echo -e "    ${GREEN}1.${NC}  [DIAGNOSTICO]   - Analisis completo del sistema Linux"
    echo -e "                       - Recoge hardware, software, red, seguridad"
    echo -e "                       - Genera archivo JSON para ResolveCore"
    echo ""
    echo -e "    ${YELLOW}2.${NC}  [OPTIMIZACION]  - Optimizar rendimiento del sistema"
    echo -e "                       - Niveles: Basico, Estandar, Rendimiento"
    echo -e "                       - Incluye limpieza, servicios, kernel"
    echo ""
    echo -e "    \033[0;35m3.${NC}  [VULNERABILIDADES] - Buscar y corregir CVEs"
    echo -e "                       - Escaneo NVD + CISA KEV + OSV + EPSS"
    echo -e "                       - Audita configuracion y puertos abiertos"
    echo ""
    echo -e "    ${CYAN}4.${NC}  [AYUDA]         - Ver guia rapida de uso"
    echo ""
    echo -e "    ${RED}5.${NC}  [SALIR]         - Salir del programa"
    echo ""
    echo -e "  +---------------------------------------------------------------+"
    echo ""
}

show_help() {
    echo ""
    echo -e "  ${WHITE}================================================================${NC}"
    echo -e "  ${WHITE}GUIA RAPIDA DE RESOLVECORE - LINUX${NC}"
    echo -e "  ${WHITE}================================================================${NC}"
    echo ""
    echo -e "  ${GREEN}[DIAGNOSTICO]${NC}"
    echo -e "  Cuando usarlo:"
    echo -e "    - Nuevo cliente o equipo desconocido"
    echo -e "    - Problemas de rendimiento o estabilidad"
    echo -e "    - Para crear historial del equipo en ResolveCore"
    echo ""
    echo -e "  Resultado:"
    echo -e "    - Genera archivo JSON con todos los datos del sistema"
    echo -e "    - Se guarda en: diagnosticos/diagnostico_<hostname>_<fecha>.json"
    echo -e "    - Importar en ResolveCore: Diagnostico > Importar JSON"
    echo ""
    echo -e "  ================================================================="
    echo ""
    echo -e "  ${YELLOW}[OPTIMIZACION]${NC}"
    echo -e "  Cuando usarlo:"
    echo -e "    - Equipo lento o con bajo rendimiento"
    echo -e "    - Mantenimiento preventivo periodico"
    echo -e "    - Despues de instalar Linux limpio"
    echo ""
    echo -e "  Niveles:"
    echo -e "    - Basico: Limpieza, servicios basicos"
    echo -e "    - Estandar: Optimizacion completa (recomendado)"
    echo -e "    - Rendimiento: Mayor optimizacion, puede afectar estabilidad"
    echo ""
    echo -e "  ================================================================="
    echo ""
    read -p "  Presiona ENTER para volver al menu..."
}

get_system_analysis() {
    echo ""
    echo -e "  +---------------------------------------------------------------+"
    echo -e "  |  ANALISIS DEL SISTEMA - SUGERENCIAS                         |"
    echo -e "  +---------------------------------------------------------------+"
    echo ""

    # Check disk space
    DISC_FREE=$(df / | tail -1 | awk '{print $4}')
    if [[ "$DISC_FREE" =~ ^([0-9]+) ]]; then
        if [ "$DISC_FREE" -lt 10000 ]; then
            echo -e "  ${RED}[X] POCO ESPACIO: ${DISC_FREE}KB libre${NC}"
        elif [ "$DISC_FREE" -lt 20000 ]; then
            echo -e "  ${YELLOW}[!] ESPACIO BAJO: ${DISC_FREE}KB libre${NC}"
        fi
    fi

    # Check memory
    if command -v free &> /dev/null; then
        MEM_USED=$(free | grep Mem | awk '{print $3/$2 * 100}')
        MEM_INT=${MEM_USED%.*}
        if [ "$MEM_INT" -gt 90 ]; then
            echo -e "  ${RED}[X] MEMORIA ALTA: ${MEM_USED}%${NC}"
        elif [ "$MEM_INT" -gt 80 ]; then
            echo -e "  ${YELLOW}[!] MEMORIA: ${MEM_USED}%${NC}"
        fi
    fi

    # Check CPU load
    LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    if (( $(echo "$LOAD > 5" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "  ${YELLOW}[!] CPU ALTA: $LOAD${NC}"
    fi

    # Check updates (Debian/Ubuntu)
    if command -v apt &> /dev/null; then
        UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable 2>/dev/null || echo 0)
        if [ "$UPDATES" -gt 0 ]; then
            echo -e "  ${CYAN}[>] ACTUALIZACIONES: $UPDATES${NC}"
        fi
    fi

    # Check services
    if systemctl is-active --quiet snapd 2>/dev/null; then
        :
    fi

    echo ""
    echo -e "  ACCIONES RECOMENDADAS:"
    echo -e "    1. Ejecutar DIAGNOSTICO para analisis completo"
    echo -e "    2. Ejecutar OPTIMIZACION para mejorar rendimiento"
    echo ""

    echo -e "  +---------------------------------------------------------------+"
    echo ""
}

ensure_python() {
    if command -v python3 &>/dev/null; then
        return 0
    fi
    echo -e "  ${YELLOW}[!] Python3 no encontrado. Intentando instalar...${NC}"
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq 2>/dev/null
        sudo apt-get install -y python3 2>/dev/null
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y python3 2>/dev/null
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm python 2>/dev/null
    fi
    command -v python3 &>/dev/null
}

run_vulnerabilidades() {
    VULN="$(dirname "$SCRIPT_DIR")/buscar_vulnerabilidades.py"
    if ! ensure_python; then
        echo -e "  ${RED}[X] No se pudo instalar Python3 automaticamente${NC}"
        read -p "  Presiona ENTER..."
        return
    fi
    if [ -f "$VULN" ]; then
        echo ""
        echo -e "  ${YELLOW}Ejecutando escaneo de vulnerabilidades...${NC}"
        echo ""
        python3 "$VULN" 2>&1 || echo -e "  ${YELLOW}[!] Escaneo termino con avisos${NC}"
        echo ""
        echo -e "  ${GREEN}[OK] Escaneo completado${NC}"
    else
        echo -e "  ${RED}[X] No encontrado: $VULN${NC}"
    fi
    read -p "  Presiona ENTER para continuar..."
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
        echo -e "  ${RED}[!] Se requieren permisos de root${NC}"
        echo -e "  Ejecuta el script con: sudo bash scripts/linux/ResolveCore.sh"
        echo ""
        read -p "  Presiona ENTER para continuar..."
        return
    fi

    echo ""
    echo -e "  +---------------------------------------------------------------+"
    echo -e "  |  ${WHITE}SELECCIONA NIVEL DE OPTIMIZACION:${NC}                            |"
    echo -e "  +---------------------------------------------------------------+"
    echo ""
    echo -e "    ${GREEN}1.${NC}  BASICO       - Limpieza basica y servicios esenciales"
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
    echo -e "    1. Reinicia el equipo para aplicar cambios"
    echo -e "    2. Verifica que todo funcione correctamente"
    echo -e "    3. Si hay problemas: bash optimizacion.sh -Undo"
    echo ""
    read -p "  Presiona ENTER para continuar..."
}

# Programa principal
while true; do
    show_banner
    show_menu

    read -p "  Selecciona una opcion (1-5): " opcion
    [[ -z "$opcion" ]] && { echo ""; exit 0; }

    case $opcion in
        1) run_diagnostico ;;
        2) run_optimizacion ;;
        3) run_vulnerabilidades ;;
        4) show_help ;;
        5)
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