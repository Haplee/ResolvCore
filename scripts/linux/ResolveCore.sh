#!/usr/bin/env bash
# =============================================================================
# ResolveCore - Menu Linux
# Menu interactivo para tecnicos ResolveCore en Linux
# =============================================================================

set -uo pipefail

SCRIPT_DIR_EARLY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Pass-through: si llega flag de modulo, invocar directo y salir ──────────
DIAG_FLAGS=()
OPT_FLAGS=()
NIVEL_POSITIONAL=""
# shellcheck disable=SC2034
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
    1. DIAGNOSTICO     Lanza diagnostico.sh.
    2. OPTIMIZACION    Lanza optimizacion.sh.
    3. VULNERABILIDADES Lanza buscar_vulnerabilidades.py (Python).
    4. INFORME         Genera HTML/PDF desde el ultimo JSON y opcionalmente
                       lo adjunta a un ticket MantisBT.
    5. AYUDA           Guia rapida embebida.
    6. SALIR           Cierra el programa.

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
SERVICIOS_DIR="$(dirname "$SCRIPT_DIR")/servicios"
source "$SCRIPT_DIR/../.env" 2>/dev/null

# Colores
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'; MAGENTA='\033[0;35m'; NC='\033[0m'

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
    echo -e "    ${MAGENTA}3.${NC}  [VULNERABILIDADES] - Buscar y corregir CVEs"
    echo -e "                       - Escaneo NVD + CISA KEV + OSV + EPSS"
    echo -e "                       - Audita configuracion y puertos abiertos"
    echo ""
    echo -e "    ${CYAN}4.${NC}  [INFORME]       - Generar HTML/PDF + adjuntar a Mantis"
    echo -e "                       - Lee el ultimo JSON de diagnostico"
    echo -e "                       - Adjunta el PDF al ticket MantisBT (opcional)"
    echo ""
    echo -e "    ${CYAN}5.${NC}  [FACTURA]       - Generar factura PDF + email al cliente"
    echo -e "                       - Asistente interactivo: tecnico, cliente, items"
    echo -e "                       - Sube a Mantis y envia email al cliente"
    echo ""
    echo -e "    ${WHITE}6.${NC}  [SERVICIOS]     - Congelacion / Clonacion de sistemas"
    echo -e "                       - Snapper/BTRFS, registro de imagenes"
    echo ""
    echo -e "    ${CYAN}7.${NC}  [AYUDA]         - Ver guia rapida de uso"
    echo ""
    echo -e "    ${RED}8.${NC}  [SALIR]         - Salir del programa"
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
    VULN="$(dirname "$SCRIPT_DIR")/common/buscar_vulnerabilidades.py"
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

    # Buscar JSON mas reciente en diagnosticos/
    local diag_dir
    diag_dir="$(dirname "$SCRIPT_DIR")/diagnosticos"
    if [[ ! -d "$diag_dir" ]]; then
        echo -e "  ${RED}[X] No hay diagnosticos en $diag_dir${NC}"
        echo -e "  ${YELLOW}    Ejecuta antes la opcion 1 (DIAGNOSTICO)${NC}"
        read -p "  Presiona ENTER..."
        return
    fi

    local latest_json
    latest_json="$(find "$diag_dir" -maxdepth 1 -name '*.json' -printf '%T@ %p\n' 2>/dev/null \
                   | sort -rn | head -1 | cut -d' ' -f2-)"

    if [[ -z "$latest_json" ]]; then
        echo -e "  ${RED}[X] No se encontro ningun JSON en $diag_dir${NC}"
        echo -e "  ${YELLOW}    Ejecuta antes la opcion 1 (DIAGNOSTICO)${NC}"
        read -p "  Presiona ENTER..."
        return
    fi

    echo -e "  ${GRAY}JSON detectado:${NC} $(basename "$latest_json")"
    echo -e "  ${GRAY}    fecha:${NC} $(date -r "$latest_json" '+%Y-%m-%d %H:%M:%S')"
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
    echo -e "  +---------------------------------------------------------------+"
    echo -e "  |  ${WHITE}GENERAR FACTURA AL CLIENTE${NC}                                    |"
    echo -e "  +---------------------------------------------------------------+"
    echo ""

    if ! ensure_python; then
        echo -e "  ${RED}[X] Python3 no disponible${NC}"
        read -p "  Presiona ENTER..."
        return
    fi

    local fac_script
    fac_script="$(dirname "$SCRIPT_DIR")/common/generar_factura.py"
    if [[ ! -f "$fac_script" ]]; then
        echo -e "  ${RED}[X] No encontrado: $fac_script${NC}"
        read -p "  Presiona ENTER..."
        return
    fi

    read -rp "  Generar PDF? (S/n) " gp
    local pdf_flag=""; [[ ! "$gp" =~ ^[nN] ]] && pdf_flag="--pdf"

    read -rp "  Subir factura al ticket MantisBT? (S/n) " up
    local up_flag=""; [[ ! "$up" =~ ^[nN] ]] && up_flag="--upload"

    read -rp "  Enviar factura por email al cliente al finalizar? (S/n) " em
    local em_flag=""; [[ ! "$em" =~ ^[nN] ]] && em_flag="--send-email"

    read -rp "  Abrir HTML en navegador al terminar? (S/n) " ob
    local op_flag=""; [[ ! "$ob" =~ ^[nN] ]] && op_flag="--open"

    echo ""
    echo -e "  ${YELLOW}Lanzando asistente interactivo de factura...${NC}"
    echo ""

    # shellcheck disable=SC2086
    python3 "$fac_script" $pdf_flag $up_flag $em_flag $op_flag \
        || echo -e "  ${YELLOW}[!] Generador termino con avisos${NC}"

    echo ""
    echo -e "  ${GREEN}[OK] Proceso de factura terminado${NC}"
    read -p "  Presiona ENTER para continuar..."
}

# ── Servicios adicionales ────────────────────────────────────────────────────

ensure_congelacion_deps() {
    local missing=()
    command -v btrfs    &>/dev/null || missing+=("btrfs-progs")
    command -v snapper  &>/dev/null || missing+=("snapper")
    command -v jq       &>/dev/null || missing+=("jq")
    [[ ${#missing[@]} -eq 0 ]] && return 0

    echo -e "  ${YELLOW}[!] Instalando dependencias: ${missing[*]}...${NC}"
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y -qq "${missing[@]}" 2>/dev/null
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y -q "${missing[@]}" 2>/dev/null
    elif command -v pacman &>/dev/null; then
        # btrfs-progs se llama igual; snapper igual; jq igual
        sudo pacman -Sy --noconfirm "${missing[@]}" 2>/dev/null
    else
        echo -e "  ${RED}[X] Gestor de paquetes no detectado. Instala manualmente: ${missing[*]}${NC}"
        return 1
    fi

    # Verificar
    local still_missing=()
    command -v btrfs   &>/dev/null || still_missing+=("btrfs-progs")
    command -v snapper &>/dev/null || still_missing+=("snapper")
    command -v jq      &>/dev/null || still_missing+=("jq")
    if [[ ${#still_missing[@]} -gt 0 ]]; then
        echo -e "  ${RED}[X] No se pudo instalar: ${still_missing[*]}${NC}"
        return 1
    fi
    echo -e "  ${GREEN}[OK] Dependencias instaladas${NC}"
}

ensure_clonacion_deps() {
    command -v jq &>/dev/null && return 0
    echo -e "  ${YELLOW}[!] Instalando jq...${NC}"
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y -qq jq 2>/dev/null
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y -q jq 2>/dev/null
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm jq 2>/dev/null
    elif command -v brew &>/dev/null; then
        brew install jq 2>/dev/null
    fi
    command -v jq &>/dev/null || { echo -e "  ${RED}[X] No se pudo instalar jq${NC}"; return 1; }
    echo -e "  ${GREEN}[OK] jq instalado${NC}"
}

run_congelacion() {
    echo ""
    echo -e "  +---------------------------------------------------------------+"
    echo -e "  |  ${WHITE}CONGELACION DE SISTEMAS (Linux - BTRFS/snapper)${NC}              |"
    echo -e "  +---------------------------------------------------------------+"
    echo ""
    if ! ensure_congelacion_deps; then
        read -rp "  Presiona ENTER..." _; return
    fi

    local s="$SERVICIOS_DIR/congelacion/congelacion-linux.sh"
    if [[ ! -f "$s" ]]; then
        echo -e "  ${RED}[X] Script no encontrado: $s${NC}"
        read -rp "  Presiona ENTER..." _; return
    fi

    echo -e "    ${CYAN}1.${NC}  Estado actual (status)"
    echo -e "    ${CYAN}2.${NC}  Configurar snapper (configure)  [root]"
    echo -e "    ${CYAN}3.${NC}  Crear snapshot del estado limpio (snapshot)"
    echo -e "    ${YELLOW}4.${NC}  ROLLBACK — restaurar estado anterior  [root, destructivo]"
    echo -e "    ${GRAY}5.${NC}  Volver"
    echo ""
    read -rp "  Selecciona (1-5): " op
    case "$op" in
        1) bash "$s" --action status ;;
        2) sudo bash "$s" --action configure ;;
        3)
            read -rp "  Etiqueta del snapshot (ENTER = 'estado-limpio'): " etq
            [[ -z "$etq" ]] && etq="estado-limpio"
            sudo bash "$s" --action snapshot --etiqueta "$etq"
            ;;
        4)
            echo -e "  ${YELLOW}[!] ROLLBACK descarta el estado actual del sistema.${NC}"
            read -rp "  Escribe 'SI' para confirmar: " conf
            [[ "$conf" == "SI" ]] && sudo bash "$s" --action rollback --confirm
            ;;
        5) return ;;
        *) echo -e "  ${RED}Opcion no valida${NC}" ;;
    esac
    echo ""
    read -rp "  Presiona ENTER..." _
}

run_clonacion() {
    echo ""
    echo -e "  +---------------------------------------------------------------+"
    echo -e "  |  ${WHITE}CLONACION DE SISTEMAS${NC}                                         |"
    echo -e "  +---------------------------------------------------------------+"
    echo ""
    if ! ensure_clonacion_deps; then
        read -rp "  Presiona ENTER..." _; return
    fi

    local reg="$SERVICIOS_DIR/clonacion/registrar-imagen.sh"
    local ver="$SERVICIOS_DIR/clonacion/verificar-imagen.sh"

    echo -e "    ${CYAN}1.${NC}  Registrar imagen en manifiesto"
    echo -e "    ${CYAN}2.${NC}  Verificar integridad de imagen"
    echo -e "    ${GRAY}3.${NC}  Volver"
    echo ""
    read -rp "  Selecciona (1-3): " op
    case "$op" in
        1)
            read -rp "  Ruta imagen o carpeta Clonezilla: " img
            read -rp "  Nombre del equipo (ej: pc-cliente-01): " equipo
            read -rp "  SO (windows|linux|macos): " so
            read -rp "  Estado (limpio|post-instalacion|produccion): " estado
            read -rp "  Notas (ENTER = ninguna): " notas
            echo ""
            echo -e "  ${YELLOW}Calculando SHA-256...${NC}"
            bash "$reg" --imagen "$img" --equipo "$equipo" --so "$so" \
                        --estado "$estado" --notas "$notas"
            ;;
        2)
            read -rp "  Ruta imagen (o ENTER para buscar por ID): " img
            if [[ -n "$img" ]]; then
                bash "$ver" --imagen "$img"
            else
                read -rp "  ID del manifiesto: " id
                bash "$ver" --id "$id"
            fi
            ;;
        3) return ;;
        *) echo -e "  ${RED}Opcion no valida${NC}" ;;
    esac
    echo ""
    read -rp "  Presiona ENTER..." _
}

run_servicios() {
    while true; do
        show_banner
        echo -e "  +---------------------------------------------------------------+"
        echo -e "  |  ${WHITE}SERVICIOS ADICIONALES${NC}                                         |"
        echo -e "  +---------------------------------------------------------------+"
        echo ""
        echo -e "    ${CYAN}1.${NC}  [CONGELACION]  - Estado de referencia con BTRFS/snapper"
        echo -e "    ${CYAN}2.${NC}  [CLONACION]    - Registrar / verificar imagen de disco"
        echo -e "    ${GRAY}3.${NC}  [VOLVER]       - Menu principal"
        echo ""
        echo -e "  +---------------------------------------------------------------+"
        echo ""
        read -rp "  Selecciona (1-3): " op
        case "$op" in
            1) run_congelacion ;;
            2) run_clonacion ;;
            3) return ;;
            *) echo -e "  ${RED}Opcion no valida${NC}"; sleep 1 ;;
        esac
    done
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

    read -rp "  Selecciona una opcion (1-8): " opcion
    [[ -z "$opcion" ]] && { echo ""; exit 0; }

    case $opcion in
        1) run_diagnostico ;;
        2) run_optimizacion ;;
        3) run_vulnerabilidades ;;
        4) run_informe ;;
        5) run_factura ;;
        6) run_servicios ;;
        7) show_help ;;
        8)
            echo ""
            echo -e "  ${GREEN}Hasta luego!${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo ""
            echo -e "  ${RED}Opcion no valida${NC}"
            read -rp "  Presiona ENTER para continuar..." _
            ;;
    esac
done