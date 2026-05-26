#!/usr/bin/env bash
# =============================================================================
# ResolveCore - Menu macOS
# Menu interactivo para tecnicos ResolveCore en Mac
# =============================================================================

set -uo pipefail

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
    3. INFORME        Genera HTML/PDF desde el ultimo JSON + adjunta a Mantis.
    4. AYUDA          Guia rapida embebida.
    5. SALIR          Cierra el programa.

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
    echo -e "    ${CYAN}3.${NC}  [INFORME]       - Generar HTML/PDF + adjuntar a Mantis"
    echo -e "                       - Lee el ultimo JSON de diagnostico"
    echo -e "                       - Adjunta el PDF al ticket MantisBT (opcional)"
    echo ""
    echo -e "    ${CYAN}4.${NC}  [FACTURA]       - Generar factura PDF + email al cliente"
    echo ""
    echo -e "    ${CYAN}5.${NC}  [AYUDA]         - Ver guia rapida de uso"
    echo ""
    echo -e "    ${RED}6.${NC}  [SALIR]         - Salir del programa"
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

ensure_python() {
    if command -v python3 &>/dev/null; then
        return 0
    fi
    echo -e "  ${YELLOW}[!] Python3 no encontrado.${NC}"
    if command -v brew &>/dev/null; then
        echo -e "  ${CYAN}[>] Instalando python via brew...${NC}"
        brew install python 2>/dev/null
    fi
    command -v python3 &>/dev/null
}

run_informe() {
    echo ""
    echo -e "  +---------------------------------------------------------------+"
    echo -e "  |  ${WHITE}GENERAR INFORME TECNICO${NC}                                       |"
    echo -e "  +---------------------------------------------------------------+"
    echo ""

    if ! ensure_python; then
        echo -e "  ${RED}[X] Python3 no disponible${NC}"
        read -p "  Presiona ENTER..."
        return
    fi

    local gen_script
    gen_script="$(dirname "$SCRIPT_DIR")/common/generar_informe.py"
    if [[ ! -f "$gen_script" ]]; then
        echo -e "  ${RED}[X] No encontrado: $gen_script${NC}"
        read -p "  Presiona ENTER..."
        return
    fi

    local diag_dir
    diag_dir="$(dirname "$SCRIPT_DIR")/diagnosticos"
    if [[ ! -d "$diag_dir" ]]; then
        echo -e "  ${RED}[X] No hay diagnosticos en $diag_dir${NC}"
        echo -e "  ${YELLOW}    Ejecuta antes la opcion 1 (DIAGNOSTICO)${NC}"
        read -p "  Presiona ENTER..."
        return
    fi

    # macOS find no soporta -printf; usamos stat -f
    local latest_json
    latest_json="$(find "$diag_dir" -maxdepth 1 -name '*.json' 2>/dev/null \
                   | xargs -I{} stat -f '%m %N' {} 2>/dev/null \
                   | sort -rn | head -1 | cut -d' ' -f2-)"

    if [[ -z "$latest_json" ]]; then
        echo -e "  ${RED}[X] No se encontro ningun JSON en $diag_dir${NC}"
        echo -e "  ${YELLOW}    Ejecuta antes la opcion 1 (DIAGNOSTICO)${NC}"
        read -p "  Presiona ENTER..."
        return
    fi

    echo -e "  ${GRAY}JSON detectado:${NC} $(basename "$latest_json")"
    echo -e "  ${GRAY}    fecha:${NC} $(stat -f '%Sm' "$latest_json")"
    echo ""

    read -rp "  Usar este JSON? (S/n) " use_latest
    local json_path="$latest_json"
    if [[ "$use_latest" =~ ^[nN] ]]; then
        read -rp "  Ruta al JSON: " custom_json
        if [[ ! -f "$custom_json" ]]; then
            echo -e "  ${RED}[X] Fichero no existe${NC}"
            read -p "  Presiona ENTER..."
            return
        fi
        json_path="$custom_json"
    fi

    read -rp "  Generar PDF tambien? (S/n) " gen_pdf
    local pdf_flag=""
    if [[ ! "$gen_pdf" =~ ^[nN] ]]; then
        pdf_flag="--pdf"
    fi

    read -rp "  Abrir HTML en navegador al terminar? (S/n) " open_b
    local open_flag=""
    if [[ ! "$open_b" =~ ^[nN] ]]; then
        open_flag="--open"
    fi

    local ticket_flag=""
    if [[ -n "$pdf_flag" ]]; then
        read -rp "  ID de ticket MantisBT para adjuntar (ENTER = no adjuntar): " ticket_id
        if [[ "$ticket_id" =~ ^[0-9]+$ ]]; then
            ticket_flag="--ticket $ticket_id"
        fi
    fi

    echo ""
    echo -e "  ${YELLOW}Generando informe...${NC}"
    echo ""

    # shellcheck disable=SC2086
    python3 "$gen_script" --json "$json_path" $pdf_flag $open_flag $ticket_flag \
        || echo -e "  ${YELLOW}[!] Generador termino con avisos${NC}"

    echo ""
    echo -e "  ${GREEN}[OK] Proceso completado${NC}"
    read -p "  Presiona ENTER para continuar..."
}

run_factura() {
    echo ""
    echo -e "  ${WHITE}GENERAR FACTURA AL CLIENTE${NC}"
    echo ""
    if ! ensure_python; then
        echo -e "  ${RED}[X] Python3 no disponible${NC}"; read -p "  Presiona ENTER..."; return
    fi
    local fac_script
    fac_script="$(dirname "$SCRIPT_DIR")/common/generar_factura.py"
    if [[ ! -f "$fac_script" ]]; then
        echo -e "  ${RED}[X] No encontrado: $fac_script${NC}"; read -p "  Presiona ENTER..."; return
    fi
    read -rp "  Generar PDF? (S/n) " gp
    local pdf_flag=""; [[ ! "$gp" =~ ^[nN] ]] && pdf_flag="--pdf"
    read -rp "  Subir al ticket MantisBT? (S/n) " up
    local up_flag=""; [[ ! "$up" =~ ^[nN] ]] && up_flag="--upload"
    read -rp "  Enviar email al cliente? (S/n) " em
    local em_flag=""; [[ ! "$em" =~ ^[nN] ]] && em_flag="--send-email"
    # shellcheck disable=SC2086
    python3 "$fac_script" $pdf_flag $up_flag $em_flag --open \
        || echo -e "  ${YELLOW}[!] Generador termino con avisos${NC}"
    read -p "  Presiona ENTER para continuar..."
}

run_diagnostico() {
    echo ""
    echo -e "  ${YELLOW}Ejecutando diagnostico...${NC}"
    echo ""

    cd "$SCRIPT_DIR" || exit 1
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

    cd "$SCRIPT_DIR" || exit 1
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

    read -p "  Selecciona una opcion (1-6): " opcion
    [[ -z "$opcion" ]] && { echo ""; exit 0; }

    case $opcion in
        1) run_diagnostico ;;
        2) run_optimizacion ;;
        3) run_informe ;;
        4) run_factura ;;
        5) show_help ;;
        6)
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