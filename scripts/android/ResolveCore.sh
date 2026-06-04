#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Menú del técnico para Android.
#
# Lanzador interactivo para el técnico. Reúne diagnóstico, optimización y
# escaneo de vulnerabilidades del dispositivo Android, llamando a los demás
# scripts de la carpeta. Funciona vía ADB sobre USB o en local con Termux.
#
# Uso:
#   bash ResolveCore.sh                 # menú interactivo (ADB/Termux)
#
# Probado en:  Android 12–14 (ADB), Termux sobre Android 13.
#
# Autor:   Francisco Vidal Mateo (GitHub: Haplee)
# Versión: 2.0
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

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
RED='\033[0;31m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'; MAGENTA='\033[0;35m'; NC='\033[0m'

# Reglas a ancho completo (cadenas fijas: sin calculo de anchura -> nunca se
# desalinean, a diferencia de las cajas con borde derecho del estilo anterior).
RC_RULE="  ==================================================================="
RC_THIN="  -------------------------------------------------------------------"

show_banner() {
    clear
    echo ""
    echo -e "${WHITE}${RC_RULE}${NC}"
    echo -e "  ${WHITE}R E S O L V E C O R E${NC}   ${GRAY}.  Menu de Herramientas (Android)${NC}"
    echo -e "${WHITE}${RC_RULE}${NC}"
    echo -e "   ${GRAY}Fecha:${NC} $(date '+%Y-%m-%d %H:%M')"
    echo ""
}

show_menu() {
    echo -e "  ${WHITE}SELECCIONA UNA OPCION${NC}"
    echo -e "$RC_THIN"
    echo -e "   ${GREEN}[1] Diagnostico${NC}       Analisis completo del dispositivo (hw, apps, seguridad)"
    echo -e "   ${YELLOW}[2] Optimizacion${NC}      Limpieza de cache + acta de acciones (.txt/.json)"
    echo -e "   ${MAGENTA}[3] Vulnerabilidades${NC}  CVE (NVD + KEV + OSV) + riesgo de compromiso"
    echo -e "   ${CYAN}[4] Ayuda${NC}             Guia rapida de uso"
    echo -e "   ${RED}[5] Salir${NC}             Salir del programa"
    echo -e "$RC_THIN"
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

    # 'adb devices' (sin -l) lista una linea por dispositivo terminada en la
    # palabra de estado. Filtramos los que estan en estado "device" y sacamos
    # el serial de la primera columna. Con -l las lineas acaban en
    # "transport_id:N" y el grep "device$" no casaba (lista vacia).
    adb devices | awk 'NR>1 && $2=="device" {print $1}' | while read -r SERIAL; do
        MODEL=$(adb -s "$SERIAL" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
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

# Muestra la probabilidad estimada de compromiso del dispositivo a partir del
# JSON del escaner. Modelo agregado: P(compromiso) = 1 - prod(1 - p_i), con p_i
# por severidad (KEV explotado=0.85, critica>=9.0=0.30, alta 7.0-8.9=0.12,
# resto=0.02). Indicador de exposicion requerido por el registro del TFG.
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
        ALTO)    interp="Exposicion alta: actualizar apps y parche de seguridad con prioridad." ;;
        MEDIO)   interp="Exposicion moderada: planificar actualizaciones." ;;
        BAJO)    interp="Exposicion baja: mantener el dispositivo al dia." ;;
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
        SERIAL=$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')
        if [ -n "$SERIAL" ]; then
            python3 "$VULN" --plataforma android --serial "$SERIAL" --max 300 --salida-json /tmp/rc-vuln-android.json >/dev/null \
                || echo -e "  ${YELLOW}[!] Escaneo termino con avisos${NC}"
        else
            python3 "$VULN" --plataforma android --max 300 --salida-json /tmp/rc-vuln-android.json >/dev/null \
                || echo -e "  ${YELLOW}[!] Escaneo termino con avisos${NC}"
        fi
        echo ""
        echo -e "  ${GREEN}[OK] Escaneo completado${NC}"
        mostrar_riesgo /tmp/rc-vuln-android.json
        desinstalar_vulns_android /tmp/rc-vuln-android.json "$SERIAL"
    else
        echo -e "  ${RED}[X] No encontrado: $VULN${NC}"
    fi
    read -p "  Presiona ENTER para continuar..."
}

# Menu de desinstalacion Android (adb uninstall). Excluye paquetes del sistema
# (com.android.*, com.google.android.*). Nada se desinstala sin seleccion +
# confirmacion explicita.
desinstalar_vulns_android() {
    local json="$1" serial="$2"
    [ -f "$json" ] || return 0
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "  ${YELLOW}[!] jq no disponible: menu de desinstalacion omitido (instala jq).${NC}"
        return 0
    fi

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
        | grep -Ev '^(com\.android\.|com\.google\.android\.|android$)' || true)

    if [ "${#pkgs[@]}" -eq 0 ]; then
        echo -e "  ${GREEN}[OK] Sin apps peligrosas desinstalables (KEV o CVSS>=7.0).${NC}"
        return 0
    fi

    echo ""
    echo -e "  ${YELLOW}APPS VULNERABLES DETECTADAS${NC}"
    echo ""
    local i=1 line p kev cvss n tag
    for line in "${pkgs[@]}"; do
        IFS=$'\t' read -r p kev cvss n <<<"$line"
        tag="   "; [ "$kev" = "true" ] && tag="KEV"
        printf "    %d. [%s] %-40s CVSS %s (%s CVE)\n" "$i" "$tag" "$p" "$cvss" "$n"
        i=$((i + 1))
    done
    echo ""
    echo -e "  ${RED}[!] La desinstalacion es IRREVERSIBLE. Nada se toca sin que lo confirmes.${NC}"
    read -rp "  Numeros a desinstalar separados por coma (ENTER = cancelar): " sel
    [ -z "$sel" ] && { echo "  Cancelado."; return 0; }

    local sel_pkgs=() idx
    for idx in ${sel//,/ }; do
        [[ "$idx" =~ ^[0-9]+$ ]] || continue
        if [ "$idx" -ge 1 ] && [ "$idx" -le "${#pkgs[@]}" ]; then
            IFS=$'\t' read -r p _ _ _ <<<"${pkgs[$((idx - 1))]}"
            sel_pkgs+=("$p")
        fi
    done
    [ "${#sel_pkgs[@]}" -eq 0 ] && { echo "  Seleccion vacia o invalida."; return 0; }

    echo ""
    echo -e "  ${YELLOW}Vas a desinstalar:${NC}"
    printf '    - %s\n' "${sel_pkgs[@]}"
    read -rp "  Escribe 'SI' para confirmar: " conf
    [ "$conf" = "SI" ] || { echo "  Cancelado."; return 0; }

    local adb_cmd="adb"
    [ -n "$serial" ] && adb_cmd="adb -s $serial"
    for p in "${sel_pkgs[@]}"; do
        echo -e "  ${CYAN:-}Desinstalando $p...${NC}"
        $adb_cmd uninstall "$p" 2>/dev/null \
            || $adb_cmd shell pm uninstall --user 0 "$p" 2>/dev/null \
            || echo -e "  ${YELLOW}[!] No se pudo desinstalar $p${NC}"
    done
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
    echo ""
    echo -e "  ${YELLOW}Verificando ADB...${NC}"
    echo ""

    if ! check_adb; then
        read -p "  Presiona ENTER para continuar..."
        return
    fi

    echo ""
    echo -e "  +---------------------------------------------------------------+"
    echo -e "  |  ${WHITE}OPTIMIZACION ANDROID (limpieza de cache)${NC}                     |"
    echo -e "  +---------------------------------------------------------------+"
    echo ""
    echo -e "    ${GREEN}1.${NC}  LIMPIAR cache de apps + /data/local/tmp"
    echo -e "    ${RED}2.${NC}  VOLVER al menu principal"
    echo ""
    echo -e "  +---------------------------------------------------------------+"

    read -p "  Selecciona opcion (1-2): " nivel

    case $nivel in
        1) : ;;   # continuar
        2) return ;;
        *) echo -e "  ${RED}Opcion no valida${NC}"; return ;;
    esac

    # 'pm clear' vacia tambien ajustes y sesiones de cada app (es destructivo):
    # exigimos confirmacion explicita del tecnico antes de pasar --confirm.
    echo ""
    echo -e "  ${YELLOW}[!] ATENCION: esto vacia la cache Y los ajustes/sesiones de cada app.${NC}"
    echo -e "  ${YELLOW}    Confirma con el cliente antes de continuar.${NC}"
    read -rp "  Escribe 'SI' para confirmar: " conf
    if [[ "$conf" != "SI" ]]; then
        echo -e "  ${GRAY}Cancelado.${NC}"
        read -p "  Presiona ENTER para continuar..."
        return
    fi

    echo ""
    echo -e "  ${YELLOW}Ejecutando optimizacion...${NC}"
    echo ""

    cd "$SCRIPT_DIR" || exit 1
    # Pasamos el serial detectado (si lo hay) y la flag --confirm obligatoria.
    SERIAL=$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')
    if [[ -n "$SERIAL" ]]; then
        bash "$SCRIPT_DIR/optimizacion.sh" "$SERIAL" --confirm
    else
        bash "$SCRIPT_DIR/optimizacion.sh" --confirm
    fi

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