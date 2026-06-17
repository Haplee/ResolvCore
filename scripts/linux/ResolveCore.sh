#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Menú del técnico para Linux.
#
# Lanzador interactivo que el técnico abre en el equipo del cliente. Reúne en
# un solo menú el diagnóstico, la optimización, el escaneo de vulnerabilidades
# y los servicios adicionales (congelación / clonación), llamando a los demás
# scripts de la carpeta. Auto-instala Python si falta para el módulo de CVEs.
#
# Uso:
#   bash ResolveCore.sh                 # menú interactivo
#
# Probado en:  Ubuntu 22.04 / 24.04, Debian 12.
#
# Autor:   Francisco Vidal Mateo (GitHub: Haplee)
# Versión: 2.0
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

SCRIPT_DIR_EARLY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Pass-through: si llega flag de modulo, invocar directo y salir ──────────
DIAG_FLAGS=()
NIVEL_POSITIONAL=""
OPT_REQUESTED=0
OPT_DRYRUN=0
OPT_UNDO=0
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
    NIVEL                   ligero | estandar | rendimiento | extreme.
                            optimizacion.sh aplica una limpieza unica con acta
                            (.txt/.json); 'extreme' ademas activa --stop-hogs
                            (detiene procesos de alto consumo no criticos).
                            Siempre se pasa --confirm.
    --dry-run / --undo      No implementados en optimizacion.sh: se rechazan.
                            Usa --confirm [--stop-hogs] directamente.

MENU
    1. DIAGNOSTICO     Lanza diagnostico.sh (genera JSON + resumen en pantalla).
    2. OPTIMIZACION    Lanza optimizacion.sh.
    3. VULNERABILIDADES Lanza buscar_vulnerabilidades.py (Python).
    4. INFORME         Genera una plantilla .txt (apartados en blanco) desde el
                       ultimo JSON; el tecnico la rellena y la sube a MantisBT.
    5. SERVICIOS       Congelacion / Clonacion de sistemas.
    6. AYUDA           Guia rapida embebida.
    7. SALIR           Cierra el programa.

    (La facturacion se gestiona desde MantisBT, no desde este menu.)

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

    # Pass-through optimizacion (siempre con --confirm)
    sudo bash scripts/linux/ResolveCore.sh rendimiento
    sudo bash scripts/linux/ResolveCore.sh extreme      # ademas --stop-hogs

    # Equivalente directo
    bash scripts/linux/diagnostico.sh -A
    sudo bash scripts/linux/optimizacion.sh --confirm

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
        --dry-run)              OPT_DRYRUN=1; OPT_REQUESTED=1; shift ;;
        --undo)                 OPT_UNDO=1; OPT_REQUESTED=1; shift ;;
        ligero|estandar|rendimiento|extreme) NIVEL_POSITIONAL="$1"; OPT_REQUESTED=1; shift ;;
        *) ARGS_REMAIN+=("$1"); shift ;;
    esac
done

if [[ ${#DIAG_FLAGS[@]} -gt 0 && "$OPT_REQUESTED" == "1" ]]; then
    echo "[X] Flags de diagnostico y optimizacion son mutuamente exclusivos." >&2
    exit 2
fi
if [[ ${#DIAG_FLAGS[@]} -gt 0 ]]; then
    exec bash "$SCRIPT_DIR_EARLY/diagnostico.sh" "${DIAG_FLAGS[@]}"
fi
if [[ "$OPT_REQUESTED" == "1" ]]; then
    # optimizacion.sh aplica una limpieza unica con acta: solo soporta
    # --confirm/--stop-hogs/--ticket. --dry-run/--undo NO estan implementados:
    # se rechazan (no aplicar limpieza real ante un --dry-run).
    if [[ "$OPT_DRYRUN" == "1" || "$OPT_UNDO" == "1" ]]; then
        echo "[X] --dry-run/--undo no estan implementados en optimizacion.sh." >&2
        echo "    Ejecuta: sudo bash optimizacion.sh --confirm [--stop-hogs] [--ticket N]" >&2
        exit 2
    fi
    # El nivel elegido se traduce: 'extreme' activa --stop-hogs (detiene los
    # procesos de mayor consumo no criticos). --confirm es obligatorio.
    OPT_CMD=(bash "$SCRIPT_DIR_EARLY/optimizacion.sh" --confirm)
    [[ "$NIVEL_POSITIONAL" == "extreme" ]] && OPT_CMD+=(--stop-hogs)
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

# Ticket de MantisBT de la sesion. Se pide una vez al inicio y se reutiliza para
# que diagnostico e informe se guarden juntos en diagnosticos/tickets/<ticket>/.
TICKET_SESION=""
read_ticket_sesion() {
    echo ""
    read -rp "  Numero de ticket MantisBT para esta reparacion (ENTER = sin ticket): " t
    if [[ "$t" =~ ^[0-9]+$ ]]; then
        TICKET_SESION="$t"
        printf "  [i] Sesion asociada al ticket #%s. Salidas en diagnosticos/tickets/%05d/\n" "$t" "$t"
    else
        TICKET_SESION=""
        if [[ -n "$t" ]]; then
            echo "  [!] '$t' no es un numero de ticket valido; sesion sin ticket."
        else
            echo "  [i] Sesion sin ticket (salidas en diagnosticos/tickets/sin-ticket/)."
        fi
    fi
    sleep 1
}

# Colores
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'; MAGENTA='\033[0;35m'; NC='\033[0m'

# Reglas a ancho completo (cadenas fijas: sin calculo de anchura -> nunca se
# desalinean, a diferencia de las cajas con borde derecho del estilo anterior).
RC_RULE="  ==================================================================="
RC_THIN="  -------------------------------------------------------------------"

show_banner() {
    clear
    echo ""
    echo -e "${WHITE}${RC_RULE}${NC}"
    echo -e "  ${WHITE}R E S O L V E C O R E${NC}   ${GRAY}.  Menu de Herramientas (Linux)${NC}"
    echo -e "${WHITE}${RC_RULE}${NC}"
    echo -e "   ${GRAY}Equipo:${NC} $(hostname)    ${GRAY}Usuario:${NC} $(whoami)    ${GRAY}Fecha:${NC} $(date '+%Y-%m-%d %H:%M')"
    echo ""
}

show_menu() {
    echo -e "  ${WHITE}SELECCIONA UNA OPCION${NC}"
    echo -e "$RC_THIN"
    echo -e "   ${GREEN}[1] Diagnostico${NC}       Analisis completo del sistema (hw, red, seguridad) -> JSON"
    echo -e "   ${YELLOW}[2] Optimizacion${NC}      Limpieza + acta de acciones (.txt cliente / .json tecnico)"
    echo -e "   ${MAGENTA}[3] Vulnerabilidades${NC}  CVE (NVD + CISA KEV + OSV) + riesgo de compromiso"
    echo -e "   ${CYAN}[4] Informe${NC}           Plantilla .txt para rellenar a mano (sube a MantisBT)"
    echo -e "   ${WHITE}[5] Servicios${NC}         Congelacion / Clonacion de sistemas"
    echo -e "   ${CYAN}[6] Ayuda${NC}             Guia rapida de uso"
    echo -e "   ${RED}[7] Salir${NC}             Salir del programa"
    echo -e "$RC_THIN"
    echo -e "   ${GRAY}(La facturacion se gestiona desde MantisBT, no desde este menu.)${NC}"
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

    # Check failed systemd units
    if command -v systemctl &> /dev/null; then
        FAILED_UNITS=$(systemctl --failed --no-legend --plain 2>/dev/null | awk 'NF{c++} END{print c+0}')
        if [ "${FAILED_UNITS:-0}" -gt 0 ]; then
            echo -e "  ${RED}[X] SERVICIOS FALLIDOS: ${FAILED_UNITS} unidad(es) systemd en estado failed${NC}"
        fi
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

# Menu de desinstalacion a partir del JSON del escaner. cups (impresion) y los
# componentes criticos del sistema se excluyen SIEMPRE. Nada se desinstala sin
# seleccion explicita + confirmacion.
desinstalar_vulns() {
    local json="$1"
    [ -f "$json" ] || return 0
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "  ${YELLOW}[!] jq no disponible: menu de desinstalacion omitido (instala jq).${NC}"
        return 0
    fi

    local excl='cups|linux-image|linux-headers|systemd|libc6?|grub|coreutils|bash'
    local pkgs=()
    mapfile -t pkgs < <(jq -r '
        [.avisos[] | select(.kev==true or (.cvss!=null and .cvss>=7.0))]
        | group_by(.paquete)
        | map({paquete: .[0].paquete,
               kev:    (any(.[]; .kev==true)),
               cvss:   (map(.cvss // 0) | max),
               n:      length})
        | sort_by([(.kev | not), (- .cvss)])
        | .[] | "\(.paquete)\t\(.kev)\t\(.cvss)\t\(.n)"' "$json" 2>/dev/null \
        | grep -Ev "^($excl)\b" || true)

    if [ "${#pkgs[@]}" -eq 0 ]; then
        echo -e "  ${GREEN}[OK] Sin software peligroso desinstalable (KEV o CVSS>=7.0).${NC}"
        return 0
    fi

    echo ""
    echo -e "  ${YELLOW}+---------------------------------------------------------------+${NC}"
    echo -e "  ${YELLOW}|  SOFTWARE VULNERABLE DETECTADO                                |${NC}"
    echo -e "  ${YELLOW}+---------------------------------------------------------------+${NC}"
    echo ""
    local i=1 line p kev cvss n tag
    for line in "${pkgs[@]}"; do
        IFS=$'\t' read -r p kev cvss n <<<"$line"
        tag="   "; [ "$kev" = "true" ] && tag="KEV"
        printf "    %d. [%s] %-35s CVSS %s (%s CVE)\n" "$i" "$tag" "$p" "$cvss" "$n"
        i=$((i + 1))
    done
    echo ""
    echo -e "  ${RED}[!] La desinstalacion es IRREVERSIBLE. Nada se toca sin que lo confirmes.${NC}"
    read -rp "  Numeros a desinstalar separados por coma (ENTER = cancelar): " sel
    [ -z "$sel" ] && { echo -e "  ${GRAY}Cancelado. No se desinstalo nada.${NC}"; return 0; }

    local sel_pkgs=() idx
    for idx in ${sel//,/ }; do
        [[ "$idx" =~ ^[0-9]+$ ]] || continue
        if [ "$idx" -ge 1 ] && [ "$idx" -le "${#pkgs[@]}" ]; then
            IFS=$'\t' read -r p _ _ _ <<<"${pkgs[$((idx - 1))]}"
            sel_pkgs+=("$p")
        fi
    done
    [ "${#sel_pkgs[@]}" -eq 0 ] && { echo -e "  ${GRAY}Seleccion vacia o invalida.${NC}"; return 0; }

    echo ""
    echo -e "  ${YELLOW}Vas a desinstalar:${NC}"
    printf '    - %s\n' "${sel_pkgs[@]}"
    read -rp "  Escribe 'SI' para confirmar: " conf
    [ "$conf" = "SI" ] || { echo -e "  ${GRAY}Cancelado. No se desinstalo nada.${NC}"; return 0; }

    local PM=""
    if command -v apt-get >/dev/null 2>&1; then PM="apt-get remove -y"
    elif command -v dnf >/dev/null 2>&1; then PM="dnf remove -y"
    elif command -v pacman >/dev/null 2>&1; then PM="pacman -R --noconfirm"
    fi
    if [ -z "$PM" ]; then
        echo -e "  ${RED}[X] Gestor de paquetes no detectado. Desinstala manualmente.${NC}"
        return 0
    fi
    for p in "${sel_pkgs[@]}"; do
        echo -e "  ${CYAN}Desinstalando $p...${NC}"
        sudo $PM "$p" || echo -e "  ${YELLOW}[!] Fallo al desinstalar $p${NC}"
    done
}

# Muestra la probabilidad estimada de compromiso del equipo a partir del JSON
# del escaner. Modelo agregado de exposicion: P(compromiso) = 1 - prod(1 - p_i),
# con p_i por severidad de cada CVE (KEV explotado=0.85, critica>=9.0=0.30,
# alta 7.0-8.9=0.12, resto=0.02). Asi un solo CVE explotado dispara el riesgo y
# muchos altos tambien saturan hacia el 100%. Es el indicador que el TFG pide.
mostrar_riesgo() {
    local json="$1"
    [ -f "$json" ] || return
    local linea
    linea=$(python3 - "$json" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    print("0.0|MINIMO|0|0|0|0|0"); raise SystemExit
vulns = d.get("vulnerabilidades", [])
# Fuente unica: si el escaner ya calculo 'riesgo', lo usamos tal cual.
r = d.get("riesgo")
if r:
    f = r.get("factores", {})
    print("%s|%s|%d|%d|%d|%d|%d" % (
        r.get("probabilidad_compromiso_pct", 0), r.get("nivel", "MINIMO"),
        f.get("kev", 0), f.get("criticas", 0), f.get("altas", 0), f.get("otras", 0), len(vulns)))
    raise SystemExit
pno = 1.0
nk = nc = na = no = 0
for v in vulns:
    c = v.get("cvss")
    if v.get("kev"):
        p = 0.85; nk += 1
    elif c is not None and c >= 9.0:
        p = 0.30; nc += 1
    elif c is not None and c >= 7.0:
        p = 0.12; na += 1
    else:
        p = 0.02; no += 1
    pno *= (1.0 - p)
prob = round((1.0 - pno) * 100, 1)
nivel = ("CRITICO" if prob >= 80 else "ALTO" if prob >= 50 else
         "MEDIO" if prob >= 25 else "BAJO" if prob >= 5 else "MINIMO")
print("%.1f|%s|%d|%d|%d|%d|%d" % (prob, nivel, nk, nc, na, no, len(vulns)))
PY
)
    local prob nivel nk nc na no ntot
    IFS='|' read -r prob nivel nk nc na no ntot <<< "$linea"
    local col="$GREEN"
    case "$nivel" in CRITICO|ALTO) col="$RED" ;; MEDIO|BAJO) col="$YELLOW" ;; esac
    local interp
    case "$nivel" in
        CRITICO) interp="Compromiso muy probable: hay CVE explotados activamente. Actuar de inmediato." ;;
        ALTO)    interp="Exposicion alta: parchear/actualizar con prioridad." ;;
        MEDIO)   interp="Exposicion moderada: planificar actualizaciones." ;;
        BAJO)    interp="Exposicion baja: mantener el sistema al dia." ;;
        *)       interp="Sin indicios relevantes de compromiso." ;;
    esac
    echo ""
    echo -e "  ${WHITE}+============== EVALUACION DE RIESGO DE COMPROMISO ==============+${NC}"
    echo -e "   Probabilidad estimada de compromiso : ${col}${prob}%  [${nivel}]${NC}"
    echo -e "   Vulnerabilidades explotadas (KEV) ..: ${nk}"
    echo -e "   Criticas (CVSS >= 9.0) .............: ${nc}"
    echo -e "   Altas (CVSS 7.0-8.9) ...............: ${na}"
    echo -e "   Otras / informativas ...............: ${no}   (total ${ntot})"
    echo -e "   ${GRAY}${interp}${NC}"
    echo -e "  ${WHITE}+===============================================================+${NC}"
    echo ""
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
        # stdout (JSON completo) al fichero; el progreso va por stderr y se ve.
        # --max 300: Linux va por OSV (sin rate limit), asi cubrimos muchos mas
        # paquetes que el default de 20 sin que el escaneo secuencial se eternice.
        python3 "$VULN" --plataforma linux --max 300 --salida-json /tmp/rc-vuln.json >/dev/null \
            || echo -e "  ${YELLOW}[!] Escaneo termino con avisos${NC}"
        echo ""
        echo -e "  ${GREEN}[OK] Escaneo completado${NC}"
        mostrar_riesgo /tmp/rc-vuln.json
        desinstalar_vulns /tmp/rc-vuln.json
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

    # Buscar JSON mas reciente. Con ticket de sesion se prioriza
    # diagnosticos/tickets/<ticket>/; si no, la carpeta legacy scripts/diagnosticos.
    local repo_root base_rep diag_dir
    repo_root="$(cd "$(dirname "$SCRIPT_DIR")/.." && pwd)"
    base_rep="${RC_REPARACIONES_DIR:-$repo_root/diagnosticos/tickets}"
    if [[ -n "$TICKET_SESION" ]] && compgen -G "$base_rep/$(printf '%05d' "$TICKET_SESION")/linux/*.json" >/dev/null 2>&1; then
        diag_dir="$base_rep/$(printf '%05d' "$TICKET_SESION")/linux"
    else
        diag_dir="$(dirname "$SCRIPT_DIR")/diagnosticos"
    fi
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

    read -rp "  Usar este JSON para pre-rellenar la cabecera? (S/n) " use_latest
    local json_path="$latest_json"
    if [[ "$use_latest" =~ ^[nN] ]]; then
        read -rp "  Ruta al JSON (ENTER = ninguno): " custom_json
        if [[ -n "$custom_json" && ! -f "$custom_json" ]]; then
            echo -e "  ${RED}[X] Fichero no existe${NC}"
            read -p "  Presiona ENTER..."
            return
        fi
        json_path="$custom_json"
    fi

    echo ""
    echo -e "  ${YELLOW}Generando plantilla de informe (.txt)...${NC}"
    echo ""

    local gen_args=()
    [[ -n "$json_path" ]] && gen_args+=(--json "$json_path")
    [[ -n "$TICKET_SESION" ]] && gen_args+=(--ticket "$TICKET_SESION" --plataforma linux)
    if [[ ${#gen_args[@]} -gt 0 ]]; then
        python3 "$gen_script" "${gen_args[@]}" \
            || echo -e "  ${YELLOW}[!] Generador termino con avisos${NC}"
    else
        python3 "$gen_script" \
            || echo -e "  ${YELLOW}[!] Generador termino con avisos${NC}"
    fi

    echo ""
    echo -e "  ${CYAN}[i] Rellena los apartados a mano y sube tu el informe a MantisBT.${NC}"
    echo -e "  ${GREEN}[OK] Proceso completado${NC}"
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

    echo -e "    ${CYAN}1.${NC} Estado actual                  (status)"
    echo -e "    ${CYAN}2.${NC} Configurar snapper             (configure)   [root]"
    echo -e "    ${CYAN}3.${NC} Crear snapshot estado limpio   (snapshot)"
    echo -e "    ${YELLOW}4.${NC} ROLLBACK - restaurar anterior  (rollback)    [root, destructivo]"
    echo -e "    ${GRAY}5.${NC} Volver"
    echo ""
    # Bucle hasta opcion valida: ENTER vacio u opcion invalida re-preguntan.
    local op=""
    while true; do
        read -rp "  Selecciona (1-5): " op
        case "$op" in
            1) bash "$s" --action status; break ;;
            2) sudo bash "$s" --action configure; break ;;
            3)
                read -rp "  Etiqueta del snapshot (ENTER = 'estado-limpio'): " etq
                [[ -z "$etq" ]] && etq="estado-limpio"
                sudo bash "$s" --action snapshot --etiqueta "$etq"
                break ;;
            4)
                echo -e "  ${YELLOW}[!] ROLLBACK descarta el estado actual del sistema.${NC}"
                read -rp "  Escribe 'SI' para confirmar: " conf
                [[ "$conf" == "SI" ]] && sudo bash "$s" --action rollback --confirm
                break ;;
            5) return ;;
            *) echo -e "  ${RED}Opcion no valida. Introduce 1-5.${NC}" ;;
        esac
    done
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

    # Manifiesto en una ruta estable y COMPARTIDA entre registrar y verificar.
    # Sin esto, cada script usaba "./imagenes-manifest.json" relativo al CWD y
    # 'verificar' no encontraba lo que 'registrar' habia escrito desde otra ruta.
    local repo_root manifest_dir manifest
    repo_root="$(dirname "$(dirname "$SCRIPT_DIR")")"
    manifest_dir="${RC_REPARACIONES_DIR:-$repo_root/reparaciones}"
    manifest="$manifest_dir/imagenes-manifest.json"
    mkdir -p "$manifest_dir"

    echo -e "    ${CYAN}1.${NC} Registrar imagen en manifiesto"
    echo -e "    ${CYAN}2.${NC} Verificar integridad de imagen"
    echo -e "    ${GRAY}3.${NC} Volver"
    echo ""
    echo -e "  ${GRAY}Manifiesto: $manifest${NC}"
    # Bucle hasta opcion valida: ENTER vacio u opcion invalida re-preguntan.
    local op=""
    while true; do
    read -rp "  Selecciona (1-3): " op
    case "$op" in
        1)
            read -rp "  Ruta imagen o carpeta Clonezilla: " img
            # Validar aqui: si la ruta va vacia o no existe, no llamamos al
            # script (evita el confuso "Faltan argumentos obligatorios").
            if [[ -z "$img" ]]; then
                echo -e "  ${RED}[X] Debes indicar la ruta de la imagen.${NC}"
            elif [[ ! -e "$img" ]]; then
                echo -e "  ${RED}[X] No existe: $img${NC}"
            else
                read -rp "  Nombre del equipo (ej: pc-cliente-01): " equipo
                read -rp "  SO (windows|linux|macos): " so
                read -rp "  Estado (limpio|post-instalacion|produccion): " estado
                read -rp "  Notas (ENTER = ninguna): " notas
                echo ""
                echo -e "  ${YELLOW}Calculando SHA-256...${NC}"
                bash "$reg" --imagen "$img" --equipo "$equipo" --so "$so" \
                            --estado "$estado" --notas "$notas" --manifest "$manifest"
            fi
            break ;;
        2)
            read -rp "  Ruta imagen (o ENTER para buscar por ID): " img
            if [[ -n "$img" ]]; then
                bash "$ver" --imagen "$img" --manifest "$manifest"
            else
                read -rp "  ID del manifiesto: " id
                bash "$ver" --id "$id" --manifest "$manifest"
            fi
            break ;;
        3) return ;;
        *) echo -e "  ${RED}Opcion no valida. Introduce 1-3.${NC}" ;;
    esac
    done
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
    if [[ -n "$TICKET_SESION" ]]; then
        bash "$SCRIPT_DIR/diagnostico.sh" --ticket "$TICKET_SESION"
    else
        bash "$SCRIPT_DIR/diagnostico.sh"
    fi

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
    echo -e "  |  ${WHITE}OPTIMIZACION DEL SISTEMA (Linux)${NC}                             |"
    echo -e "  +---------------------------------------------------------------+"
    echo ""
    echo -e "    ${GREEN}1.${NC}  EJECUTAR limpieza + acta de acciones"
    echo -e "    ${RED}2.${NC}  VOLVER al menu principal"
    echo ""
    echo -e "  ${GRAY}(Vacia cache/temporales y registra un acta .txt/.json. Excluye servicios criticos.)${NC}"
    echo -e "  +---------------------------------------------------------------+"

    # Bucle hasta opcion valida: ENTER vacio u opcion invalida re-preguntan.
    local opt=""
    while true; do
        read -rp "  Selecciona opcion (1-2): " opt
        case "$opt" in
            1) break ;;
            2) return ;;
            *) echo -e "  ${RED}Opcion no valida. Introduce 1 o 2.${NC}" ;;
        esac
    done

    echo ""
    echo -e "  ${YELLOW}Ejecutando optimizacion...${NC}"
    echo ""

    cd "$SCRIPT_DIR" || exit 1
    # optimizacion.sh exige --confirm (evita ejecuciones accidentales por SSH).
    bash "$SCRIPT_DIR/optimizacion.sh" --confirm

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
show_banner
read_ticket_sesion
while true; do
    show_banner
    show_menu

    read -rp "  Selecciona una opcion (1-7): " opcion
    # ENTER vacio NO cierra el programa: re-muestra el menu. Solo se sale con [7].
    if [[ -z "$opcion" ]]; then
        echo -e "  ${YELLOW}Introduce una opcion (1-7).${NC}"
        sleep 1
        continue
    fi

    case $opcion in
        1) run_diagnostico ;;
        2) run_optimizacion ;;
        3) run_vulnerabilidades ;;
        4) run_informe ;;
        5) run_servicios ;;
        6) show_help ;;
        7)
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