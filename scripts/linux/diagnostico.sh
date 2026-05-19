#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Diagnóstico de sistema Linux
#
# Recoge métricas de hardware, sistema operativo, red y seguridad.
# Genera un archivo JSON compatible con ResolveCore (campo json_raw).
#
# Uso:
#   bash diagnostico.sh
#   bash diagnostico.sh /tmp
#   ssh user@host 'bash -s' < diagnostico.sh
#
# Requisitos opcionales:
#   smartmontools (apt install smartmontools)  — S.M.A.R.T. extendido
#   lm-sensors   (apt install lm-sensors)     — temperatura CPU/GPU
#   nvidia-utils (apt install nvidia-utils)   — GPU NVIDIA
#   pciutils     (apt install pciutils)       — detección GPU
#
# Autor:   FranVi / ResolveCore
# Versión: 3.2.0
#
# Cambios 3.2.0 (S4):
#   - Inyección HTML segura: JSON va dentro de <script type="application/json">
#     en el template y se parsea con JSON.parse(). Antes el JSON se inyectaba
#     como JS literal y un valor con </script> rompía el HTML.
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

# ── Parseo de argumentos ────────────────────────────────────────────────────
INSTALL_DEPS=true
AUTO_INSTALL=false
OUTPUT_DIR=""
SILENT="false"
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -O|--output)            OUTPUT_DIR="${2:-}"; shift 2 ;;
        -S|--silent)            SILENT="true"; shift ;;
        -I|--install|--install-deps) INSTALL_DEPS=true; shift ;;
        -A|--auto-install)      INSTALL_DEPS=true; AUTO_INSTALL=true; shift ;;
        -h|--help)
            cat <<EOF
NAME
    diagnostico.sh - Diagnostico de sistema Linux para ResolveCore

SYNOPSIS
    bash diagnostico.sh [-O <dir>] [-S] [-I] [-A] [-h]

DESCRIPTION
    Recoge metricas de hardware (CPU, RAM, discos con SMART, bateria, GPU,
    temperatura), sistema operativo (version, uptime, actualizaciones,
    integridad de paquetes, plan energia), drivers/modulos, red (latencia,
    DNS, perdida paquetes) y seguridad (firewall, antivirus, SELinux).
    Genera JSON estructurado y un informe HTML autocontenido.

OPTIONS
    -O, --output <dir>          Directorio de salida del JSON/HTML.
                                Default: <repo>/scripts/diagnosticos
    -S, --silent                Suprime salida por consola.
    -I, --install               Detecta paquetes opcionales faltantes y los
                                instala via apt/dnf/yum/pacman/zypper. Pide
                                confirmacion interactiva.
                                (Alias retro-compat: --install-deps)
    -A, --auto-install          Igual que -I sin confirmar.
    -h, --help                  Muestra esta ayuda y sale.

PAQUETES OPCIONALES
    lm-sensors                  Temperatura CPU/GPU.
    smartmontools               S.M.A.R.T. extendido (sectores, horas).
    pciutils                    Deteccion GPU (lspci).
    nvidia-utils                GPU NVIDIA via nvidia-smi.
    jq                          Validacion JSON generado.
    bc, iputils-ping, ufw, iproute2

EXAMPLES
    bash diagnostico.sh
    bash diagnostico.sh -O /tmp
    bash diagnostico.sh -S -O /tmp -I
    sudo bash diagnostico.sh -A -S
    ssh user@host 'bash -s' < diagnostico.sh

EXIT CODES
    0    Diagnostico generado correctamente.
    1    JSON generado no valido (jq empty fallo).
EOF
            exit 0 ;;
        *) POSITIONAL+=("$1"); shift ;;
    esac
done
# Posicionales legacy: bash diagnostico.sh <output_dir> <silent>
[[ -z "$OUTPUT_DIR" && -n "${POSITIONAL[0]:-}" ]] && OUTPUT_DIR="${POSITIONAL[0]}"
[[ -n "${POSITIONAL[1]:-}" ]] && SILENT="${POSITIONAL[1]}"
[[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/diagnosticos"

# ── Colores ──────────────────────────────────────────────────────────────────
if [[ -t 1 ]] && [[ "$SILENT" != "true" ]]; then
    CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    RED='\033[0;31m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'; NC='\033[0m'
else
    CYAN=''; GREEN=''; YELLOW=''; RED=''; WHITE=''; GRAY=''; NC=''
fi

# ── Helpers de salida ───────────────────────────────────────────────────────
header() {
    [[ "$SILENT" == "true" ]] && return
    echo ""
    echo -e "  ┌─────────────────────────────────────────────────────────────────┐"
    echo -e "  │   ${CYAN}ResolveCore — Diagnóstico de Sistema Linux — v3.0.0${NC}        │"
    echo -e "  │   $(date '+%Y-%m-%d %H:%M:%S')                                         │"
    echo -e "  └─────────────────────────────────────────────────────────────────┘"
    echo ""
}

section() { [[ "$SILENT" != "true" ]] && echo -e "  ${CYAN}► $1${NC}"; }
ok()     { [[ "$SILENT" != "true" ]] && echo -e "    ${GREEN}✓ $1${NC}"; }
warn()   { [[ "$SILENT" != "true" ]] && echo -e "    ${YELLOW}⚠ $1${NC}"; }
fail()   { [[ "$SILENT" != "true" ]] && echo -e "    ${RED}✗ $1${NC}"; }

# ── Verificar privilegios ───────────────────────────────────────────────────
is_admin=false
if [[ $EUID -eq 0 ]]; then
    is_admin=true
fi

header
if [[ "$is_admin" == "false" ]] && [[ "$SILENT" != "true" ]]; then
    echo -e "  ${YELLOW}⚠  Sin privilegios de root — algunas métricas serán limitadas.${NC}"
    echo ""
fi

# ── Instalación opcional de dependencias ────────────────────────────────────
# Tabla cmd → paquete por gestor. Si el comando ya existe, no se reinstala.
install_dependencies() {
    local pm="" install_cmd="" update_cmd=""
    if   command -v apt-get  &>/dev/null; then pm="apt";    update_cmd="apt-get update -qq";          install_cmd="apt-get install -y"
    elif command -v dnf      &>/dev/null; then pm="dnf";    update_cmd="dnf -y makecache";            install_cmd="dnf install -y"
    elif command -v yum      &>/dev/null; then pm="yum";    update_cmd="yum -y makecache";            install_cmd="yum install -y"
    elif command -v pacman   &>/dev/null; then pm="pacman"; update_cmd="pacman -Sy --noconfirm";      install_cmd="pacman -S --noconfirm --needed"
    elif command -v zypper   &>/dev/null; then pm="zypper"; update_cmd="zypper refresh";              install_cmd="zypper install -y"
    else
        warn "Gestor de paquetes no soportado. Instala manualmente: lm-sensors smartmontools pciutils jq bc"
        return 1
    fi

    # cmd:apt:dnf:pacman:zypper  (yum hereda dnf)
    local deps=(
        "sensors:lm-sensors:lm_sensors:lm_sensors:sensors"
        "smartctl:smartmontools:smartmontools:smartmontools:smartmontools"
        "lspci:pciutils:pciutils:pciutils:pciutils"
        "jq:jq:jq:jq:jq"
        "bc:bc:bc:bc:bc"
        "ping:iputils-ping:iputils:iputils:iputils"
        "ufw:ufw:ufw:ufw:ufw"
        "ip:iproute2:iproute:iproute2:iproute2"
    )

    local missing=() pkg_to_install=()
    for entry in "${deps[@]}"; do
        IFS=':' read -r cmd p_apt p_dnf p_pac p_zyp <<<"$entry"
        if ! command -v "$cmd" &>/dev/null; then
            local pkg=""
            case "$pm" in
                apt)         pkg="$p_apt" ;;
                dnf|yum)     pkg="$p_dnf" ;;
                pacman)      pkg="$p_pac" ;;
                zypper)      pkg="$p_zyp" ;;
            esac
            missing+=("$cmd")
            pkg_to_install+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        ok "Dependencias: todas presentes"
        return 0
    fi

    section "Dependencias — paquetes faltantes detectados"
    warn "Faltan: ${missing[*]}"
    echo -e "    ${GRAY}Paquetes a instalar (${pm}): ${pkg_to_install[*]}${NC}"

    if [[ "$AUTO_INSTALL" != "true" ]]; then
        read -r -p "    ¿Proceder con la instalación? [y/N] " _ans
        [[ "$_ans" =~ ^[YySs]$ ]] || { warn "Instalación cancelada"; return 1; }
    fi

    local sudo_pfx=""
    [[ "$is_admin" == "false" ]] && sudo_pfx="sudo "
    if [[ "$is_admin" == "false" ]] && ! command -v sudo &>/dev/null; then
        fail "Se requiere root o sudo para instalar paquetes"
        return 1
    fi

    eval "$sudo_pfx$update_cmd" || warn "Fallo en update — continúo con install"
    if eval "$sudo_pfx$install_cmd ${pkg_to_install[*]}"; then
        ok "Paquetes instalados correctamente"
    else
        fail "Error al instalar paquetes"
        return 1
    fi

    # sensors-detect tras instalar lm-sensors (modo no interactivo)
    if [[ " ${missing[*]} " == *" sensors "* ]] && command -v sensors-detect &>/dev/null; then
        ok "Ejecutando sensors-detect --auto"
        eval "${sudo_pfx}sensors-detect --auto" >/dev/null 2>&1 || warn "sensors-detect terminó con avisos"
    fi
}

if [[ "$INSTALL_DEPS" == "true" ]]; then
    install_dependencies
    echo ""
fi

# ── JSON helpers ────────────────────────────────────────────────────────────
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# json_num: emite el valor si es numérico válido, "null" en caso contrario.
# Defensa contra capturas multi-línea (p.ej. `grep -c | echo "0"` con pipefail
# que devuelve "0\n0") que romperían el JSON al interpolarse en un campo numérico.
json_num() {
    local v="$1"
    if [[ "$v" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        printf '%s' "$v"
    else
        printf 'null'
    fi
}

# Verificación de jq como dependencia obligatoria (la usamos para ensamblar JSON).
if ! command -v jq &>/dev/null; then
    echo "  ✗  jq no encontrado. Instala con: sudo apt install jq" >&2
    echo "     O ejecuta: bash $0 -A   (auto-instalación de dependencias)" >&2
    exit 3
fi

# ═════════════════════════════════════════════════════════════════════════════
# 1. HARDWARE
# ═════════════════════════════════════════════════════════════════════════════
section "Hardware — CPU · RAM · Almacenamiento"

# CPU
cpu_cores=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "null")
cpu_threads=$cpu_cores
cpu_mhz=$(grep -m1 "cpu MHz" /proc/cpuinfo 2>/dev/null | awk '{print int($4)}' || echo "null")
cpu_name=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^[ \t]*//' || echo "Unknown")
ok "CPU: $cpu_name — $cpu_cores núcleos / $cpu_threads hilos @ ${cpu_mhz}MHz"

# RAM
ram_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
ram_gb=$((ram_kb / 1024 / 1024))
if [[ "$ram_gb" -eq 0 ]]; then ram_gb="null"; fi
ok "RAM: ${ram_gb}GB"

# Disco principal
disk_gb="null"; disk_type="Unknown"; smart_status="Unknown"; disks_json="[]"
disks_list=""
primary_model=""

if command -v lsblk &>/dev/null; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        d_name=$(echo "$line" | awk '{print $1}')
        d_size=$(echo "$line" | awk '{print $2}')
        d_type=$(echo "$line" | awk '{print $3}')
        d_model=$(echo "$line" | awk '{$1=$2=$3=""; print $0}' | sed 's/^[ \t]*//')

        # Convertir tamaño a GB
        d_gb=0
        if [[ "$d_size" =~ ^[0-9]+$ ]]; then
            d_gb=$((d_size / 1024 / 1024 / 1024))
        fi

        # Determinar tipo
        dtype="Unknown"
        if [[ "$d_type" == "nvme" ]]; then dtype="NVMe"
        elif [[ "$d_type" == "ssd" ]]; then dtype="SSD"
        elif [[ "$d_type" == "hdd" ]]; then dtype="HDD"
        elif [[ "$d_type" == "rom" ]]; then dtype="ROM"
        else dtype="SSD"  # Assume SSD por defecto
        fi

        # SMART status + atributos extendidos
        smart="Unknown"
        smart_attrs_json="null"
        if [[ "$is_admin" == "true" ]] && command -v smartctl &>/dev/null; then
            smart_out=$(smartctl -H "/dev/$d_name" 2>/dev/null)
            if echo "$smart_out" | grep -q "PASSED"; then smart="OK"
            elif echo "$smart_out" | grep -q "FAILED"; then smart="FAILED"
            else smart="WARNING"; fi

            # S.M.A.R.T. extendido: atributos clave para detección de fallos
            smart_a=$(smartctl -A "/dev/$d_name" 2>/dev/null)
            if [[ -n "$smart_a" ]]; then
                _rlc=$(echo "$smart_a" | awk '/Reallocated_Sector_Ct/{print $10}' 2>/dev/null | head -1)
                _cps=$(echo "$smart_a" | awk '/Current_Pending_Sector/{print $10}' 2>/dev/null | head -1)
                _ouc=$(echo "$smart_a" | awk '/Offline_Uncorrectable/{print $10}' 2>/dev/null | head -1)
                _tmp=$(echo "$smart_a" | awk '/Temperature_Celsius/{print $10}' 2>/dev/null | head -1)
                _poh=$(echo "$smart_a" | awk '/Power_On_Hours/{print $10}' 2>/dev/null | head -1)
                # Fallback para NVMe (formato distinto)
                [[ ! "$_tmp" =~ ^[0-9]+$ ]] && _tmp=$(echo "$smart_a" | grep -i 'Temperature:' | grep -oP '\b[0-9]+\b' | head -1)
                [[ ! "$_poh" =~ ^[0-9]+$ ]] && _poh=$(echo "$smart_a" | grep -i 'Power On Hours:' | grep -oP '[0-9,]+' | tr -d ',' | head -1)
                [[ "$_rlc" =~ ^[0-9]+$ ]] || _rlc="null"
                [[ "$_cps" =~ ^[0-9]+$ ]] || _cps="null"
                [[ "$_ouc" =~ ^[0-9]+$ ]] || _ouc="null"
                [[ "$_tmp" =~ ^[0-9]+$ ]] || _tmp="null"
                [[ "$_poh" =~ ^[0-9]+$ ]] || _poh="null"
                smart_attrs_json="{\"reallocated_sectors\":$_rlc,\"pending_sectors\":$_cps,\"uncorrectable_errors\":$_ouc,\"temperatura_c\":$_tmp,\"horas_encendido\":$_poh}"
                [[ "$_rlc" != "null" && "$_rlc" != "0" ]] && warn "Sectores reubicados: $_rlc (riesgo de pérdida de datos)"
                [[ "$_ouc" != "null" && "$_ouc" != "0" ]] && warn "Errores no corregibles: $_ouc (sustitución urgente)"
            fi
        fi

        if [[ -z "$disks_list" ]]; then
            disks_list="{\"modelo\":\"$(json_escape "$d_model")\",\"tipo\":\"$dtype\",\"capacidad_gb\":$d_gb,\"smart\":\"$smart\",\"bus\":\"$d_type\",\"smart_atributos\":$smart_attrs_json}"
            disk_gb=$d_gb
            disk_type="$dtype"
            smart_status="$smart"
            primary_model="$d_model"
        else
            disks_list="$disks_list,{\"modelo\":\"$(json_escape "$d_model")\",\"tipo\":\"$dtype\",\"capacidad_gb\":$d_gb,\"smart\":\"$smart\",\"bus\":\"$d_type\",\"smart_atributos\":$smart_attrs_json}"
        fi
    done < <(lsblk -d -b -o NAME,SIZE,TYPE,MODEL 2>/dev/null | tail -n +2 | grep -E "disk|nvme")
    disks_json="[$disks_list]"
fi

if [[ "$disk_gb" != "null" ]]; then
    ok "Disco principal: $primary_model ($disk_type, ${disk_gb}GB, SMART: $smart_status)"
fi

# Batería — nivel, estado, desgaste y ciclos
battery_json="null"
bat_path=""
for _bp in /sys/class/power_supply/BAT0 /sys/class/power_supply/BAT1 /sys/class/power_supply/BATT /sys/class/power_supply/battery; do
    [[ -d "$_bp" ]] && { bat_path="$_bp"; break; }
done
if [[ -n "$bat_path" ]]; then
    bat_charge=$(cat "$bat_path/capacity" 2>/dev/null || echo "0")
    bat_status=$(cat "$bat_path/status" 2>/dev/null || echo "Unknown")
    bat_desgaste="null"
    bat_ciclos="null"
    # Desgaste: capacidad actual vs diseño
    bat_full=$(cat "$bat_path/charge_full" 2>/dev/null || cat "$bat_path/energy_full" 2>/dev/null || echo "")
    bat_design=$(cat "$bat_path/charge_full_design" 2>/dev/null || cat "$bat_path/energy_full_design" 2>/dev/null || echo "")
    if [[ "$bat_full" =~ ^[0-9]+$ && "$bat_design" =~ ^[0-9]+$ && "$bat_design" -gt 0 ]]; then
        bat_desgaste=$(LC_ALL=C awk "BEGIN{printf \"%.1f\", (1 - $bat_full / $bat_design) * 100}")
    fi
    # Ciclos (disponible en algunos portátiles con driver acpi_battery)
    _cc=$(cat "$bat_path/cycle_count" 2>/dev/null || echo "")
    [[ "$_cc" =~ ^[0-9]+$ ]] && bat_ciclos="$_cc"
    battery_json="{\"presente\":true,\"carga_pct\":$bat_charge,\"estado\":\"$bat_status\",\"desgaste_pct\":$bat_desgaste,\"ciclos\":$bat_ciclos}"
    _bat_msg="Batería: ${bat_charge}% (${bat_status})"
    [[ "$bat_desgaste" != "null" ]] && _bat_msg="$_bat_msg — desgaste: ${bat_desgaste}%"
    ok "$_bat_msg"
    [[ "$bat_desgaste" != "null" ]] && LC_ALL=C awk "BEGIN{if ($bat_desgaste > 80) exit 0; exit 1}" && warn "Desgaste > 80% — considere sustituir la batería"
fi

# ── Temperatura CPU ──────────────────────────────────────────────────────────
cpu_temp="null"
if command -v sensors &>/dev/null; then
    _t=$(sensors 2>/dev/null | grep -E 'Package id 0:|Core 0:|Tdie:|CPU Temp' | grep -oP '\+\K[0-9]+\.[0-9]+' | head -1 || echo "")
    [[ -n "$_t" ]] && cpu_temp="$_t"
fi
if [[ "$cpu_temp" == "null" ]]; then
    for _zone in /sys/class/thermal/thermal_zone*/; do
        _type=$(cat "${_zone}type" 2>/dev/null || echo "")
        if echo "$_type" | grep -qiE "x86_pkg_temp|cpu|acpitz|soc_thermal"; then
            _t=$(cat "${_zone}temp" 2>/dev/null || echo "")
            if [[ "$_t" =~ ^[0-9]+$ && "$_t" -gt 1000 ]]; then
                cpu_temp=$(LC_ALL=C awk "BEGIN{printf \"%.1f\", $_t/1000}")
                break
            fi
        fi
    done
fi
[[ "$cpu_temp" != "null" ]] && ok "Temperatura CPU: ${cpu_temp}°C" || warn "Temperatura CPU: instala lm-sensors (apt install lm-sensors && sensors-detect)"

# ── GPU ───────────────────────────────────────────────────────────────────────
gpu_json="null"
_gpu_found=""
if command -v nvidia-smi &>/dev/null; then
    _gn=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "")
    _gt=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1 || echo "")
    _gv=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | grep -oP '[0-9]+' | head -1 || echo "null")
    if [[ -n "$_gn" ]]; then
        _gpu_found="$_gn"
        [[ "$_gt" =~ ^[0-9]+$ ]] || _gt="null"
        [[ "$_gv" =~ ^[0-9]+$ ]] || _gv="null"
        gpu_json="{\"nombre\":\"$(json_escape "$_gn")\",\"tipo\":\"NVIDIA\",\"vram_mb\":${_gv},\"temperatura_c\":${_gt}}"
        ok "GPU: $_gn (NVIDIA, VRAM: ${_gv:-?}MB, Temp: ${_gt:-?}°C)"
    fi
fi
if [[ -z "$_gpu_found" ]] && command -v lspci &>/dev/null; then
    _gline=$(lspci 2>/dev/null | grep -iE 'VGA compatible|3D controller|Display controller' | head -1 || echo "")
    if [[ -n "$_gline" ]]; then
        _gpu_found=$(echo "$_gline" | sed 's/.*: //')
        _gtype=$(echo "$_gpu_found" | grep -qi nvidia && echo "NVIDIA" || { echo "$_gpu_found" | grep -qi 'amd\|radeon' && echo "AMD" || echo "Intel"; })
        gpu_json="{\"nombre\":\"$(json_escape "$_gpu_found")\",\"tipo\":\"$_gtype\",\"vram_mb\":null,\"temperatura_c\":null}"
        ok "GPU: $_gpu_found"
    fi
fi
[[ -z "$_gpu_found" ]] && warn "GPU: instala pciutils (apt install pciutils) o nvidia-utils"

# ── Espacio en disco ──────────────────────────────────────────────────────────
disk_free_gb="null"; disk_used_pct="null"
_df=$(df -k / 2>/dev/null | awk 'NR==2')
if [[ -n "$_df" ]]; then
    _avail=$(echo "$_df" | awk '{print $4}')
    _pct=$(echo "$_df" | awk '{print $5}' | tr -d '%')
    [[ "$_avail" =~ ^[0-9]+$ ]] && disk_free_gb=$(awk "BEGIN{printf \"%.0f\", $_avail/1048576}")
    [[ "$_pct" =~ ^[0-9]+$ ]] && disk_used_pct="$_pct"
fi
[[ "$disk_free_gb" != "null" ]] && ok "Disco / libre: ${disk_free_gb}GB (uso: ${disk_used_pct}%)"

hardware_json="{
    \"cpu_cores\": $(json_num "$cpu_cores"),
    \"ram_gb\": $(json_num "$ram_gb"),
    \"disk_type\": \"$disk_type\",
    \"disk_gb\": $(json_num "$disk_gb"),
    \"disk_free_gb\": $(json_num "$disk_free_gb"),
    \"disk_uso_pct\": $(json_num "$disk_used_pct"),
    \"smart_status\": \"$smart_status\",
    \"cpu_nombre\": \"$(json_escape "$cpu_name")\",
    \"cpu_hilos\": $(json_num "$cpu_threads"),
    \"cpu_mhz\": $(json_num "$cpu_mhz"),
    \"cpu_temp_c\": $(json_num "$cpu_temp"),
    \"discos\": $disks_json,
    \"bateria\": $battery_json,
    \"gpu\": $gpu_json
}"

# ═════════════════════════════════════════════════════════════════════════════
# 2. SISTEMA OPERATIVO
# ═════════════════════════════════════════════════════════════════════════════
section "Sistema Operativo — Versión · Actualizaciones · Integridad"

os_name="Unknown"; os_version=""; os_arch=""; os_build=""
if [[ -f /etc/os-release ]]; then
    os_name=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d= -f2 | tr -d '"')
    os_version=$(grep "^VERSION_ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
    [[ -z "$os_version" ]] && os_version=$(grep "^VERSION=" /etc/os-release | cut -d= -f2 | tr -d '"')
fi
os_arch=$(uname -m)
os_build=$(uname -r)
uptime_s=$(cat /proc/uptime 2>/dev/null | awk '{print int($1)}' || echo "0")
uptime_h=$(LC_ALL=C awk "BEGIN{printf \"%.1f\", ${uptime_s:-0}/3600}")

ok "OS: $os_name (build $os_build, $os_arch)"
ok "Uptime: ${uptime_h}h"

# Actualizaciones pendientes
# Nota: `grep -c` imprime el conteo (incluido "0") y sale con código 1 si no hay
# matches. Con `pipefail` la sustitución hereda ese exit 1, así que usamos
# `|| true` para no inyectar valores extra. La regex final blinda contra cualquier
# output imprevisto del package manager.
pending_updates="null"
if command -v apt &>/dev/null; then
    # Usa cache local — no ejecuta apt update para evitar efectos secundarios en diagnóstico
    pending_updates=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst' || true)
    ok "Actualizaciones pendientes: ${pending_updates:-0} (caché local)"
elif command -v dnf &>/dev/null; then
    pending_updates=$(dnf check-update --quiet 2>/dev/null | grep -c "^[A-Za-z]" || true)
    ok "Actualizaciones pendientes: ${pending_updates:-0}"
elif command -v yum &>/dev/null; then
    pending_updates=$(yum check-update --quiet 2>/dev/null | grep -c "^[A-Za-z]" || true)
    ok "Actualizaciones pendientes: ${pending_updates:-0}"
elif command -v pacman &>/dev/null; then
    pending_updates=$(pacman -Qu 2>/dev/null | wc -l | xargs || true)
    ok "Actualizaciones pendientes: ${pending_updates:-0}"
fi
[[ "$pending_updates" =~ ^[0-9]+$ ]] || pending_updates=0

# Integridad del sistema (check de paquetes)
sfc_issues=0
if command -v dpkg &>/dev/null; then
    # Solo paquetes con estado distinto de "ii" (correctamente instalado).
    # Filtra cabeceras de dpkg-list (||/, +++, Desired=...) por longitud y formato.
    sfc_issues=$(dpkg -l 2>/dev/null | awk '/^[a-zA-Z]{2,3}[[:space:]]/ && $1 != "ii" {c++} END{print c+0}')
    [[ "$sfc_issues" =~ ^[0-9]+$ ]] || sfc_issues=0
elif command -v rpm &>/dev/null; then
    sfc_issues=$(rpm -Va 2>/dev/null | wc -l || echo "0")
fi
if [[ $sfc_issues -gt 0 ]]; then
    warn "$sfc_issues paquetes con problemas"
else
    ok "Sin paquetes del sistema dañados"
fi

# Plan de energía (Linux equivalente)
power_plan="personalizado"
if [[ -f /sys/class/power_supply/*/status ]]; then
    governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "")
    case "$governor" in
        performance) power_plan="alto_rendimiento" ;;
        powersave)   power_plan="ahorro_energia" ;;
        *)           power_plan="equilibrado" ;;
    esac
    ok "Plan de energía: $power_plan"
fi

sistema_json="{
    \"actualizaciones_pendientes\": $(json_num "$pending_updates"),
    \"nombre\": \"$(json_escape "$os_name")\",
    \"build\": \"$os_build\",
    \"arquitectura\": \"$os_arch\",
    \"uptime_horas\": $(json_num "$uptime_h"),
    \"sfc_archivos_danados\": $(json_num "$sfc_issues"),
    \"plan_energia\": \"$power_plan\"
}"

# ═════════════════════════════════════════════════════════════════════════════
# 3. DRIVERS/MÓDULOS DEL KERNEL
# ═════════════════════════════════════════════════════════════════════════════
section "Drivers — Módulos del kernel · Estado"

stopped_count=0; unsigned_count=0; stopped_list=""; unsigned_list=""

if command -v lsmod &>/dev/null; then
    total_modules=$(lsmod | tail -n +2 | wc -l)
    ok "Módulos cargados: $total_modules"

    # Módulos con errores (dmesg)
    if command -v dmesg &>/dev/null; then
        { error_modules=$(dmesg 2>/dev/null | grep -ic "module.*error\|firmware.*failed" 2>/dev/null); } || error_modules=0
        [[ "$error_modules" =~ ^[0-9]+$ ]] || error_modules=0
        stopped_count=$error_modules
        if [[ $stopped_count -gt 0 ]]; then
            warn "Módulos con errores: $stopped_count"
        fi
    fi

    # Verificar firmas (si está disponible)
    if [[ "$is_admin" == "true" ]] && command -v modinfo &>/dev/null; then
        unsigned_count=0
        while IFS= read -r mod; do
            sig=$(modinfo "$mod" 2>/dev/null | grep "^sig\|^signer" | head -1)
            if [[ -z "$sig" ]]; then
                unsigned_count=$((unsigned_count + 1))
            fi
        done < <(lsmod | tail -n +2 | awk '{print $1}' | head -25)
    fi
    ok "Módulos sin firma: $unsigned_count"
fi

drivers_json="{
    \"detenidos\": $(json_num "$stopped_count"),
    \"sin_firma\": $(json_num "$unsigned_count"),
    \"detenidos_lista\": [],
    \"sin_firma_lista\": []
}"

# ═════════════════════════════════════════════════════════════════════════════
# 4. RED
# ═════════════════════════════════════════════════════════════════════════════
section "Red — Latencia · Pérdida de paquetes · DNS"

latency_ms="null"; packet_loss_pct="null"; dns_servers="[]"; active_iface=""

# Interfaz activa
if command -v ip &>/dev/null; then
    active_iface=$(ip route | grep default | awk '{print $5}' | head -1)
    ok "Interfaz activa: $active_iface"
fi

# DNS
dns_json="[]"
if [[ -f /etc/resolv.conf ]]; then
    dns_servers=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')
    if [[ -n "$dns_servers" ]]; then
        dns_json="["
        first=true
        for dns in $(echo "$dns_servers" | tr ',' ' '); do
            if [[ "$first" == "true" ]]; then
                dns_json="$dns_json\"$dns\""
                first=false
            else
                dns_json="$dns_json, \"$dns\""
            fi
        done
        dns_json="$dns_json]"
        ok "DNS: $dns_servers"
    fi
fi

# Test de latencia (ping)
if command -v ping &>/dev/null; then
    ping_result=$(ping -c 10 -W 2 8.8.8.8 2>/dev/null)
    if [[ -n "$ping_result" ]]; then
        latency_ms=$(echo "$ping_result" | grep "avg" | awk -F'/' '{print int($5)}' || echo "null")
        packet_loss=$(echo "$ping_result" | grep "packet loss" | awk '{print $6}' | tr -d '%')
        packet_loss_pct="${packet_loss:-100}"
        ok "Latencia: ${latency_ms}ms — Pérdida: ${packet_loss_pct}%"
    else
        packet_loss_pct=100
        fail "Sin respuesta de 8.8.8.8 — pérdida de paquetes: 100%"
    fi
fi

red_json="{
    \"latencia_ms\": $(json_num "$latency_ms"),
    \"perdida_paquetes_pct\": $(json_num "$packet_loss_pct"),
    \"dns\": $dns_json,
    \"interfaz\": \"$(json_escape "$active_iface")\"
}"

# ═════════════════════════════════════════════════════════════════════════════
# 5. SEGURIDAD
# ═════════════════════════════════════════════════════════════════════════════
section "Seguridad — Firewall · Antivirus · Actualizaciones"

antivirus_name="null"; firewall_active="false"; defender_active="false"; def_sig_days="null"

# Firewall
if command -v ufw &>/dev/null; then
    ufw_status=$(ufw status 2>/dev/null | head -1)
    if echo "$ufw_status" | grep -q "active"; then
        firewall_active="true"
        ok "Firewall (UFW): activo"
    else
        ok "Firewall (UFW): DESACTIVADO"
    fi
elif command -v firewall-cmd &>/dev/null; then
    if firewall-cmd --state &>/dev/null; then
        firewall_active="true"
        ok "Firewall (firewalld): activo"
    else
        ok "Firewall (firewalld): DESACTIVADO"
    fi
elif command -v iptables &>/dev/null; then
    rules=$(iptables -L 2>/dev/null | grep -c "Chain" || echo "0")
    if [[ $rules -gt 3 ]]; then
        firewall_active="true"
        ok "Firewall (iptables): activo"
    else
        ok "Firewall (iptables): DESACTIVADO"
    fi
fi

# Antivirus (ClamAV)
if command -v clamscan &>/dev/null || command -v clamdscan &>/dev/null; then
    antivirus_name="\"ClamAV\""
    defender_active="true"
    ok "Antivirus detectado: ClamAV"
fi

# SELinux / AppArmor
selinux_status="null"
if command -v getenforce &>/dev/null; then
    selinux_status=$(getenforce 2>/dev/null || echo "Disabled")
    ok "SELinux: $selinux_status"
fi

seguridad_json="{
    \"antivirus\": $antivirus_name,
    \"firewall\": $firewall_active,
    \"uac_habilitado\": null,
    \"defender_activo\": $defender_active,
    \"defender_firma_dias\": $(json_num "$def_sig_days"),
    \"selinux\": \"$(json_escape "$selinux_status")\"
}"

# ═════════════════════════════════════════════════════════════════════════════
# 6. SERVICIOS
# ═════════════════════════════════════════════════════════════════════════════
section "Servicios — Estado de servicios systemd"

servicios_total=0; servicios_activos=0; servicios_detenidos=0
servicios_automaticos_detenidos=0; servicios_criticos_json="[]"

if command -v systemctl &>/dev/null; then
    _st=$(systemctl list-units --type=service --no-pager --no-legend 2>/dev/null | wc -l || echo "0")
    _sa=$(systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | wc -l || echo "0")
    [[ "$_st" =~ ^[0-9]+$ ]] && servicios_total="$_st"
    [[ "$_sa" =~ ^[0-9]+$ ]] && servicios_activos="$_sa"
    servicios_detenidos=$((servicios_total - servicios_activos))

    _svc_inact=$(systemctl list-units --type=service --state=inactive --no-pager --no-legend 2>/dev/null | wc -l || echo "0")
    [[ "$_svc_inact" =~ ^[0-9]+$ ]] && servicios_automaticos_detenidos="$_svc_inact"

    _criticos_list=""
    for _svc in sshd ssh cron crond NetworkManager network mariadb mysql nginx apache2 ufw firewalld; do
        _svc_state=$(systemctl is-active "$_svc" 2>/dev/null || echo "")
        [[ -z "$_svc_state" || "$_svc_state" == "not-found" ]] && continue
        [[ -n "$_criticos_list" ]] && _criticos_list="$_criticos_list,"
        _criticos_list="${_criticos_list}{\"nombre\":\"$_svc\",\"estado\":\"$_svc_state\"}"
        if [[ "$_svc_state" == "active" ]]; then
            ok "Servicio $_svc: activo"
        else
            warn "Servicio $_svc: $_svc_state"
        fi
    done
    [[ -n "$_criticos_list" ]] && servicios_criticos_json="[$_criticos_list]"

    ok "Servicios: $servicios_total total, $servicios_activos activos"
fi

servicios_json="{
    \"total\": $(json_num "$servicios_total"),
    \"activos\": $(json_num "$servicios_activos"),
    \"detenidos\": $(json_num "$servicios_detenidos"),
    \"automaticos_detenidos\": $(json_num "$servicios_automaticos_detenidos"),
    \"criticos\": $servicios_criticos_json
}"

# ═════════════════════════════════════════════════════════════════════════════
# 7. SOFTWARE INSTALADO
# ═════════════════════════════════════════════════════════════════════════════
section "Software instalado — Primeros 50 paquetes"

software_json="[]"; _sw_list=""; _sw_count=0; _max_sw=50

if command -v dpkg-query &>/dev/null; then
    while IFS=' ' read -r _sname _sver && [[ $_sw_count -lt $_max_sw ]]; do
        [[ -z "$_sname" ]] && continue
        [[ -n "$_sw_list" ]] && _sw_list="$_sw_list,"
        _sw_list="${_sw_list}{\"nombre\":\"$(json_escape "$_sname")\",\"version\":\"$(json_escape "$_sver")\"}"
        _sw_count=$((_sw_count + 1))
    done < <(dpkg-query -W --showformat='${Package} ${Version}\n' 2>/dev/null | sort | head -"$_max_sw")
elif command -v rpm &>/dev/null; then
    while IFS=' ' read -r _sname _sver && [[ $_sw_count -lt $_max_sw ]]; do
        [[ -z "$_sname" ]] && continue
        [[ -n "$_sw_list" ]] && _sw_list="$_sw_list,"
        _sw_list="${_sw_list}{\"nombre\":\"$(json_escape "$_sname")\",\"version\":\"$(json_escape "$_sver")\"}"
        _sw_count=$((_sw_count + 1))
    done < <(rpm -qa --queryformat '%{NAME} %{VERSION}\n' 2>/dev/null | sort | head -"$_max_sw")
elif command -v pacman &>/dev/null; then
    while IFS=' ' read -r _sname _sver && [[ $_sw_count -lt $_max_sw ]]; do
        [[ -z "$_sname" ]] && continue
        [[ -n "$_sw_list" ]] && _sw_list="$_sw_list,"
        _sw_list="${_sw_list}{\"nombre\":\"$(json_escape "$_sname")\",\"version\":\"$(json_escape "$_sver")\"}"
        _sw_count=$((_sw_count + 1))
    done < <(pacman -Q 2>/dev/null | head -"$_max_sw")
fi

[[ -n "$_sw_list" ]] && software_json="[$_sw_list]"
ok "Software inventariado: $_sw_count paquetes"

# ═════════════════════════════════════════════════════════════════════════════
# 8. RENDIMIENTO
# ═════════════════════════════════════════════════════════════════════════════
section "Rendimiento — CPU · Memoria · Top procesos"

cpu_uso_pct="null"; mem_uso_pct="null"; top_procs_json="[]"

# Uso CPU: dos lecturas de /proc/stat separadas 0.5s
if [[ -f /proc/stat ]]; then
    _s1=$(awk '/^cpu /{t=$2+$3+$4+$5+$6+$7+$8+$9; i=$5+$6; printf "%d %d", t, i}' /proc/stat 2>/dev/null || echo "0 0")
    sleep 0.5
    _s2=$(awk '/^cpu /{t=$2+$3+$4+$5+$6+$7+$8+$9; i=$5+$6; printf "%d %d", t, i}' /proc/stat 2>/dev/null || echo "0 0")
    _t1=$(echo "$_s1" | awk '{print $1}'); _i1=$(echo "$_s1" | awk '{print $2}')
    _t2=$(echo "$_s2" | awk '{print $1}'); _i2=$(echo "$_s2" | awk '{print $2}')
    if [[ "$_t1" =~ ^[0-9]+$ && "$_t2" =~ ^[0-9]+$ && $((_t2 - _t1)) -gt 0 ]]; then
        cpu_uso_pct=$(LC_ALL=C awk "BEGIN{dt=$_t2-$_t1; di=$_i2-$_i1; printf \"%.1f\", (1-di/dt)*100}")
    fi
fi

# Uso memoria desde /proc/meminfo
_mt=$(grep MemTotal     /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
_ma=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
if [[ "$_mt" =~ ^[0-9]+$ && "$_mt" -gt 0 && "$_ma" =~ ^[0-9]+$ ]]; then
    mem_uso_pct=$(LC_ALL=C awk "BEGIN{printf \"%.1f\", (1 - $_ma/$_mt)*100}")
fi

[[ "$cpu_uso_pct" != "null" ]] && ok "CPU uso: ${cpu_uso_pct}%"
[[ "$mem_uso_pct" != "null" ]] && ok "Memoria uso: ${mem_uso_pct}%"

# Top 5 procesos por RAM
_procs_list=""; _proc_count=0
if command -v ps &>/dev/null; then
    while IFS=' ' read -r _ppid _pmem _pname && [[ $_proc_count -lt 5 ]]; do
        [[ -z "$_ppid" || "$_ppid" == "PID" ]] && continue
        [[ -n "$_procs_list" ]] && _procs_list="$_procs_list,"
        _procs_list="${_procs_list}{\"pid\":$(json_num "$_ppid"),\"memoria_pct\":$(json_num "$_pmem"),\"nombre\":\"$(json_escape "$_pname")\"}"
        _proc_count=$((_proc_count + 1))
    done < <(ps aux --sort=-%mem 2>/dev/null | awk 'NR>1{print $2, $4, $11}' | head -5)
fi
[[ -n "$_procs_list" ]] && top_procs_json="[$_procs_list]"

rendimiento_json="{
    \"cpu_uso_pct\": $(json_num "$cpu_uso_pct"),
    \"memoria_uso_pct\": $(json_num "$mem_uso_pct"),
    \"top_procesos\": $top_procs_json
}"

# ═════════════════════════════════════════════════════════════════════════════
# 9. USUARIOS
# ═════════════════════════════════════════════════════════════════════════════
section "Usuarios — Cuentas locales"

usuarios_json="[]"; _users_list=""; _users_count=0

while IFS=: read -r _uname _ _uid _ _ _home _shell; do
    [[ "$_uid" =~ ^[0-9]+$ ]] || continue
    [[ "$_uid" -lt 1000 || "$_uname" == "nobody" ]] && continue
    _uactive="true"
    echo "$_shell" | grep -qE "nologin|false" && _uactive="false"
    [[ -n "$_users_list" ]] && _users_list="$_users_list,"
    _users_list="${_users_list}{\"nombre\":\"$(json_escape "$_uname")\",\"uid\":$(json_num "$_uid"),\"activo\":$_uactive,\"home\":\"$(json_escape "$_home")\"}"
    _users_count=$((_users_count + 1))
done < /etc/passwd 2>/dev/null || true

[[ -n "$_users_list" ]] && usuarios_json="[$_users_list]"
ok "Usuarios locales: $_users_count"

# ═════════════════════════════════════════════════════════════════════════════
# 10. PLACA BASE
# ═════════════════════════════════════════════════════════════════════════════
section "Placa base — Fabricante · Modelo · BIOS"

placa_fabricante="Unknown"; placa_modelo="Unknown"
bios_version="Unknown"; bios_fecha="Unknown"; uuid_sistema="Unknown"

# Sysfs DMI (no requiere root — disponible en la mayoría de kernels)
[[ -f /sys/class/dmi/id/board_vendor ]] && placa_fabricante=$(cat /sys/class/dmi/id/board_vendor 2>/dev/null || echo "Unknown")
[[ -f /sys/class/dmi/id/board_name   ]] && placa_modelo=$(cat    /sys/class/dmi/id/board_name   2>/dev/null || echo "Unknown")
[[ -f /sys/class/dmi/id/bios_version ]] && bios_version=$(cat    /sys/class/dmi/id/bios_version 2>/dev/null || echo "Unknown")
[[ -f /sys/class/dmi/id/bios_date    ]] && bios_fecha=$(cat      /sys/class/dmi/id/bios_date    2>/dev/null || echo "Unknown")
[[ -f /sys/class/dmi/id/product_uuid ]] && uuid_sistema=$(cat    /sys/class/dmi/id/product_uuid 2>/dev/null || echo "Unknown")

# Complemento con dmidecode si root (puede añadir info no expuesta en sysfs)
if [[ "$is_admin" == "true" ]] && command -v dmidecode &>/dev/null; then
    _dmi_board=$(dmidecode -t baseboard 2>/dev/null || echo "")
    _dmi_bios=$(dmidecode  -t bios      2>/dev/null || echo "")
    _dmi_sys=$(dmidecode   -t system    2>/dev/null || echo "")
    [[ "$placa_fabricante" == "Unknown" ]] && placa_fabricante=$(echo "$_dmi_board" | awk -F': ' '/Manufacturer:/{gsub(/^[ \t]+/,"",$2); print $2; exit}')
    [[ "$placa_modelo"     == "Unknown" ]] && placa_modelo=$(echo     "$_dmi_board" | awk -F': ' '/Product Name:/{gsub(/^[ \t]+/,"",$2); print $2; exit}')
    [[ "$bios_version"     == "Unknown" ]] && bios_version=$(echo     "$_dmi_bios"  | awk -F': ' '/Version:/{gsub(/^[ \t]+/,"",$2); print $2; exit}')
    [[ "$bios_fecha"       == "Unknown" ]] && bios_fecha=$(echo       "$_dmi_bios"  | awk -F': ' '/Release Date:/{gsub(/^[ \t]+/,"",$2); print $2; exit}')
    [[ "$uuid_sistema"     == "Unknown" ]] && uuid_sistema=$(echo     "$_dmi_sys"   | awk -F': ' '/UUID:/{gsub(/^[ \t]+/,"",$2); print $2; exit}')
fi

ok "Placa: $placa_fabricante — $placa_modelo"
ok "BIOS: $bios_version ($bios_fecha)"

placa_base_json="{
    \"fabricante\": \"$(json_escape "$placa_fabricante")\",
    \"producto\": \"$(json_escape "$placa_modelo")\",
    \"version_bios\": \"$(json_escape "$bios_version")\",
    \"fecha_bios\": \"$(json_escape "$bios_fecha")\",
    \"uuid\": \"$(json_escape "$uuid_sistema")\"
}"

# ═════════════════════════════════════════════════════════════════════════════
# 11. METADATA
# ═════════════════════════════════════════════════════════════════════════════
hostname_str=$(hostname 2>/dev/null || echo "unknown")
timestamp=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')

meta_json="{
    \"version\": \"3.2.0\",
    \"plataforma\": \"linux\",
    \"hostname\": \"$(json_escape "$hostname_str")\",
    \"generado_en\": \"$timestamp\",
    \"admin\": $is_admin
}"

# ═════════════════════════════════════════════════════════════════════════════
# OUTPUT JSON
# ═════════════════════════════════════════════════════════════════════════════

mkdir -p "$OUTPUT_DIR" 2>/dev/null
out_file="$OUTPUT_DIR/diagnostico_${hostname_str}_$(date '+%Y%m%d_%H%M%S').json"

# Ensamblaje vía jq -n: cada sección llega como --argjson y jq valida que sea
# JSON bien formado antes de incluirla. Si alguna sección está corrupta, jq -n
# falla con un mensaje que apunta al fragmento problemático en vez de generar
# silenciosamente un fichero inválido.
if ! jq -n \
    --argjson hardware        "$hardware_json" \
    --argjson sistema_operativo "$sistema_json" \
    --argjson drivers         "$drivers_json" \
    --argjson red             "$red_json" \
    --argjson seguridad       "$seguridad_json" \
    --argjson servicios       "$servicios_json" \
    --argjson software        "$software_json" \
    --argjson rendimiento     "$rendimiento_json" \
    --argjson usuarios        "$usuarios_json" \
    --argjson placa_base      "$placa_base_json" \
    --argjson meta            "$meta_json" \
    '{
        hardware: $hardware,
        sistema_operativo: $sistema_operativo,
        drivers: $drivers,
        red: $red,
        seguridad: $seguridad,
        servicios: $servicios,
        software: $software,
        rendimiento: $rendimiento,
        usuarios: $usuarios,
        placa_base: $placa_base,
        _meta: $meta
    }' > "$out_file" 2>/tmp/diagnostico_jq_err.$$; then
    echo -e "  ${RED}✗  jq falló al ensamblar el JSON. Detalle:${NC}" >&2
    cat /tmp/diagnostico_jq_err.$$ >&2 || true
    rm -f /tmp/diagnostico_jq_err.$$
    # Volcar fragmentos a un .debug.json para que el técnico pueda inspeccionar
    debug_file="${out_file%.json}.debug.txt"
    {
        printf '== hardware_json ==\n%s\n\n'      "$hardware_json"
        printf '== sistema_json ==\n%s\n\n'       "$sistema_json"
        printf '== drivers_json ==\n%s\n\n'       "$drivers_json"
        printf '== red_json ==\n%s\n\n'           "$red_json"
        printf '== seguridad_json ==\n%s\n\n'     "$seguridad_json"
        printf '== servicios_json ==\n%s\n\n'     "$servicios_json"
        printf '== software_json ==\n%s\n\n'      "$software_json"
        printf '== rendimiento_json ==\n%s\n\n'   "$rendimiento_json"
        printf '== usuarios_json ==\n%s\n\n'      "$usuarios_json"
        printf '== placa_base_json ==\n%s\n\n'    "$placa_base_json"
        printf '== meta_json ==\n%s\n'            "$meta_json"
    } > "$debug_file"
    echo -e "  ${YELLOW}↳ Fragmentos volcados en: $debug_file${NC}" >&2
    exit 1
fi
rm -f /tmp/diagnostico_jq_err.$$

# Generar informe HTML.
# Inyección segura: template tiene <script type="application/json" id="rc-data">
# __JSON_DATA__</script>. Se sustituye el marker con el JSON crudo previo
# escape de "</" -> "<\/" para que un valor con "</script>" no cierre el tag.
# Bash ${var//pattern/repl} no interpreta &, \ ni regex.
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_tmpl="${_script_dir}/../../reports/informe.html"
_html_file="${out_file%.json}.html"
if [[ -f "$_tmpl" ]]; then
    if grep -q '__JSON_DATA__' "$_tmpl"; then
        _json_escaped=$(sed 's|</|<\\/|g' "$out_file")
        _tmpl_content=$(<"$_tmpl")
        printf '%s\n' "${_tmpl_content//__JSON_DATA__/$_json_escaped}" > "$_html_file"
        # Abrir con navegador (prioriza $BROWSER, luego comunes; xdg-open como último recurso
        # porque el default del sistema puede ser Text Editor).
        _opener=""
        for _b in "${BROWSER:-}" sensible-browser firefox google-chrome chromium chromium-browser brave-browser; do
            [[ -n "$_b" ]] && command -v "$_b" &>/dev/null && { _opener="$_b"; break; }
        done
        if [[ -n "$_opener" ]]; then
            "$_opener" "$_html_file" >/dev/null 2>&1 &
        elif command -v xdg-open &>/dev/null; then
            xdg-open "$_html_file" 2>/dev/null &
        fi
    fi
fi

if [[ "$SILENT" != "true" ]]; then
    echo ""
    echo -e "  ${GRAY}─────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${GREEN}✓  Diagnóstico completado${NC}"
    echo -e "  ${WHITE}📄 JSON: $out_file${NC}"
    [[ -f "$_html_file" ]] && echo -e "  ${CYAN}🌐 HTML: $_html_file${NC}"
    echo ""
    echo -e "  ${GRAY}→ Sube este archivo en ResolveCore: Diagnóstico del equipo → Importar JSON${NC}"
    echo ""
fi

echo "$out_file"
exit 0
