#!/usr/bin/env bash
# =============================================================================
# ResolveCore - Menu Android
# Menu interactivo para tecnicos ResolveCore en Android
# =============================================================================

SCRIPT_DIR_EARLY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DIAG_FLAGS=()
OPT_FLAGS=()
NIVEL_POSITIONAL=""

show_help() {
    cat <<'EOF'
NAME
    ResolveCore.sh - Menu interactivo de herramientas ResolveCore para Android

SYNOPSIS
    bash ResolveCore.sh                                          # menu
    bash ResolveCore.sh [-O <dir>] [SERIAL]                      # forward diagnostico
    bash ResolveCore.sh [--serial <id>] [--dry-run] [--confirm]
                        [--undo] [NIVEL]                         # forward optimizacion

DESCRIPTION
    Sin flags: lanza menu TUI (diagnostico, optimizacion, ayuda, salir).
    Con flags de modulo: salta el menu e invoca diagnostico.sh u
    optimizacion.sh con esos flags. Util para automatizacion.

OPTIONS DEL LAUNCHER
    -h, --help        Muestra esta ayuda y sale.

FLAGS DE DIAGNOSTICO (forward a diagnostico.sh)
    -O, --output <dir>      Directorio salida JSON.
    SERIAL                  Numero de serie ADB (posicional).

FLAGS DE OPTIMIZACION (forward a optimizacion.sh)
    NIVEL                   ligero | estandar | rendimiento | extreme.
    --serial <id>           Dispositivo ADB concreto.
    --dry-run               Simula sin aplicar.
    --confirm               Requerido para niveles destructivos.
    --undo                  Reactiva apps deshabilitadas.

MENU
    1. DIAGNOSTICO    Lanza diagnostico.sh.
    2. OPTIMIZACION   Lanza optimizacion.sh.
    3. AYUDA          Guia rapida embebida.
    4. SALIR          Cierra el programa.

REQUISITOS
    - Terminal interactiva (modo menu).
    - adb instalado y dispositivo autorizado.

EXAMPLES
    # Menu
    bash scripts/android/ResolveCore.sh

    # Pass-through diagnostico
    bash scripts/android/ResolveCore.sh -O /tmp ABC123

    # Pass-through optimizacion
    bash scripts/android/ResolveCore.sh --dry-run rendimiento
    bash scripts/android/ResolveCore.sh --serial ABC123 --confirm extreme

EXIT CODES
    0    Salida normal o ayuda mostrada.
    1    No es terminal interactiva (modo menu).
    2    Combinacion invalida de flags.
EOF
}

DIAG_HAS_SERIAL_OR_OUTPUT=false
OPT_HAS_FLAG=false
SERIAL_POS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help; exit 0 ;;
        -O|--output)  DIAG_FLAGS+=("--output" "${2:-}"); DIAG_HAS_SERIAL_OR_OUTPUT=true; shift 2 ;;
        --serial)     OPT_FLAGS+=("--serial" "${2:-}"); OPT_HAS_FLAG=true; shift 2 ;;
        --dry-run)    OPT_FLAGS+=("--dry-run"); OPT_HAS_FLAG=true; shift ;;
        --confirm)    OPT_FLAGS+=("--confirm"); OPT_HAS_FLAG=true; shift ;;
        --undo)       OPT_FLAGS+=("--undo"); OPT_HAS_FLAG=true; shift ;;
        ligero|estandar|rendimiento|extreme) NIVEL_POSITIONAL="$1"; OPT_HAS_FLAG=true; shift ;;
        *) SERIAL_POS="$1"; DIAG_HAS_SERIAL_OR_OUTPUT=true; shift ;;
    esac
done

if [[ "$DIAG_HAS_SERIAL_OR_OUTPUT" == "true" && "$OPT_HAS_FLAG" == "true" ]]; then
    echo "[X] Flags de diagnostico y optimizacion son mutuamente exclusivos." >&2
    exit 2
fi
if [[ "$DIAG_HAS_SERIAL_OR_OUTPUT" == "true" ]]; then
    DIAG_CMD=(bash "$SCRIPT_DIR_EARLY/diagnostico.sh" "${DIAG_FLAGS[@]}")
    [[ -n "$SERIAL_POS" ]] && DIAG_CMD+=("$SERIAL_POS")
    exec "${DIAG_CMD[@]}"
fi
if [[ "$OPT_HAS_FLAG" == "true" ]]; then
    OPT_CMD=(bash "$SCRIPT_DIR_EARLY/optimizacion.sh" "${OPT_FLAGS[@]}")
    [[ -n "$NIVEL_POSITIONAL" ]] && OPT_CMD+=("$NIVEL_POSITIONAL")
    exec "${OPT_CMD[@]}"
fi

if [[ ! -t 0 ]]; then
    echo "Este script debe ejecutarse en una terminal interactiva"
    echo "Ejemplo: bash scripts/android/ResolveCore.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colores
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'; NC='\033[0m'

show_banner() {
    clear
    echo ""
    echo -e "  +---------------------------------------------------------------+"
    echo -e "  |                    ${WHITE}RESOLVECORE${NC}                                |"
    echo -e "  |              ${GRAY}Menu de Herramientas - Android${NC}              |"
    echo -e "  +---------------------------------------------------------------+"
    echo ""
    echo -e "  ${GRAY}Fecha:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

show_menu() {
    echo -e "  +---------------------------------------------------------------+"
    echo -e "  |  ${WHITE}SELECCIONA UNA OPCION:${NC}                                        |"
    echo -e "  +---------------------------------------------------------------+"
    echo ""
    echo -e "    ${GREEN}1.${NC}  [DIAGNOSTICO]   - Analisis completo del dispositivo Android"
    echo -e "                       - Recoge hardware, software, apps, seguridad"
    echo -e "                       - Genera archivo JSON para ResolveCore"
    echo ""
    echo -e "    ${YELLOW}2.${NC}  [OPTIMIZACION]  - Optimizar rendimiento del Android"
    echo -e "                       - Niveles: Basico, Estandar"
    echo -e "                       - Incluye limpieza, apps, permisos"
    echo ""
    echo -e "    \033[0;35m3.${NC}  [VULNERABILIDADES] - Buscar CVEs (NVD + KEV + OSV)"
    echo -e "                       - Audita patch de seguridad y apps"
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
    echo -e "  ${WHITE}GUIA RAPIDA DE RESOLVECORE - ANDROID${NC}"
    echo -e "  ${WHITE}================================================================${NC}"
    echo ""
    echo -e "  ${GREEN}[DIAGNOSTICO]${NC}"
    echo -e "  Cuando usarlo:"
    echo -e "    - Nuevo cliente o dispositivo desconocido"
    echo -e "    - Problemas de rendimiento o aplicaciones"
    echo -e "    - Para crear historial del dispositivo en ResolveCore"
    echo ""
    echo -e "  Requisitos:"
    echo -e "    - ADB instalado en el PC (apt install adb / brew install android-platform-tools)"
    echo -e "    - Depuracion USB habilitada en el dispositivo"
    echo -e "    - Dispositivo conectado y autorizado"
    echo ""
    echo -e "  Resultado:"
    echo -e "    - Genera archivo JSON con todos los datos del dispositivo"
    echo -e "    - Se guarda en: diagnosticos/diagnostico_<serial>_<fecha>.json"
    echo -e "    - Importar en ResolveCore: Diagnostico > Importar JSON"
    echo ""
    echo -e "  ================================================================="
    echo ""
    echo -e "  ${YELLOW}[OPTIMIZACION]${NC}"
    echo -e "  Cuando usarlo:"
    echo -e "    - Dispositivo lento"
    echo -e "    - Mucho espacio usado"
    echo -e "    - Muchas apps en segundo plano"
    echo ""
    echo -e "  Niveles:"
    echo -e "    - Basico: Limpieza de cache"
    echo -e "    - Estandar: Limpieza y optimizacion (recomendado)"
    echo ""
    echo -e "  ================================================================="
    echo ""
    read -p "  Presiona ENTER para volver al menu..."
}

check_adb() {
    if ! command -v adb &> /dev/null; then
        echo -e "  ${RED}[X] ADB no esta instalado${NC}"
        echo -e "  ${GRAY}Instala ADB:${NC}"
        echo -e "    Linux: sudo apt install adb"
        echo -e "    Mac: brew install android-platform-tools"
        echo -e "    Windows: Descarga Android SDK Platform Tools"
        return 1
    fi

    if ! adb devices | grep -q "device$"; then
        echo -e "  ${RED}[X] No hay dispositivos conectados${NC}"
        echo -e "  ${GRAY}Pasos:${NC}"
        echo -e "    1. Activa Depuracion USB en el dispositivo"
        echo -e "    2. Conecta el dispositivo al PC"
        echo -e "    3. Autoriza la conexion en el dispositivo"
        return 1
    fi

    DEVICE_COUNT=$(adb devices | grep -c "device$")
    echo -e "  ${GREEN}[OK] Dispositivo(s) conectado(s): ${DEVICE_COUNT}${NC}"
    return 0
}

show_devices() {
    echo ""
    echo -e "  ${CYAN}Dispositivos conectados:${NC}"
    echo -e "  ${GRAY}-------------------------------------------${NC}"

    adb devices -l | grep "device$" | while read line; do
        SERIAL=$(echo $line | awk '{print $1}')
        MODEL=$(adb -s $SERIAL shell getprop ro.product.model 2>/dev/null | tr -d '\r')
        echo -e "  ${WHITE}$SERIAL${NC} - $MODEL"
    done

    echo -e "  ${GRAY}-------------------------------------------${NC}"
    echo ""
}

ensure_deps() {
    local need=()
    command -v python3 &>/dev/null || need+=("python3")
    command -v adb &>/dev/null || need+=("adb")
    if [ ${#need[@]} -eq 0 ]; then return 0; fi
    echo -e "  ${YELLOW}[!] Faltan: ${need[*]}. Intentando instalar...${NC}"
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq 2>/dev/null
        for p in "${need[@]}"; do
            [ "$p" = "adb" ] && p="android-tools-adb"
            sudo apt-get install -y "$p" 2>/dev/null
        done
    elif command -v brew &>/dev/null; then
        for p in "${need[@]}"; do
            [ "$p" = "adb" ] && p="android-platform-tools"
            brew install "$p" 2>/dev/null
        done
    elif command -v dnf &>/dev/null; then
        for p in "${need[@]}"; do
            sudo dnf install -y "$p" 2>/dev/null
        done
    fi
    command -v python3 &>/dev/null && command -v adb &>/dev/null
}

run_vulnerabilidades() {
    VULN="$(dirname "$SCRIPT_DIR")/buscar_vulnerabilidades.py"
    if ! ensure_deps; then
        echo -e "  ${RED}[X] No se pudieron instalar las dependencias automaticamente${NC}"
        read -p "  Presiona ENTER..."
        return
    fi
    if ! check_adb; then
        read -p "  Presiona ENTER para continuar..."
        return
    fi
    if [ -f "$VULN" ]; then
        echo ""
        echo -e "  ${YELLOW}Ejecutando escaneo de vulnerabilidades Android...${NC}"
        echo ""
        SERIAL=$(adb devices | grep "device$" | head -n1 | awk '{print $1}')
        if [ -n "$SERIAL" ]; then
            python3 "$VULN" --platform A --serial "$SERIAL" 2>&1 || echo -e "  ${YELLOW}[!] Escaneo termino con avisos${NC}"
        else
            python3 "$VULN" --platform A 2>&1 || echo -e "  ${YELLOW}[!] Escaneo termino con avisos${NC}"
        fi
        echo ""
        echo -e "  ${GREEN}[OK] Escaneo completado${NC}"
    else
        echo -e "  ${RED}[X] No encontrado: $VULN${NC}"
    fi
    read -p "  Presiona ENTER para continuar..."
}

run_diagnostico() {
    echo ""
    echo -e "  ${YELLOW}Verificando ADB...${NC}"
    echo ""

    if ! check_adb; then
        read -p "  Presiona ENTER para continuar..."
        return
    fi

    show_devices

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
    echo ""
    echo -e "  ${YELLOW}Verificando ADB...${NC}"
    echo ""

    if ! check_adb; then
        read -p "  Presiona ENTER para continuar..."
        return
    fi

    echo ""
    echo -e "  +---------------------------------------------------------------+"
    echo -e "  |  ${WHITE}SELECCIONA NIVEL DE OPTIMIZACION:${NC}                            |"
    echo -e "  +---------------------------------------------------------------+"
    echo ""
    echo -e "    ${GREEN}1.${NC}  BASICO       - Limpieza de cache"
    echo -e "    ${YELLOW}2.${NC}  ESTANDAR     - Limpieza y optimizacion (recomendado)"
    echo -e "    ${RED}3.${NC}  VOLVER al menu principal"
    echo ""
    echo -e "  +---------------------------------------------------------------+"

    read -p "  Selecciona opcion (1-3): " nivel

    case $nivel in
        1) nivel_opt="ligero" ;;
        2) nivel_opt="estandar" ;;
        3) return ;;
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
    echo -e "    1. Reinicia el dispositivo"
    echo -e "    2. Verifica que todo funcione correctamente"
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