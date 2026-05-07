#!/bin/bash
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
# Versión: 3.0.0
# ─────────────────────────────────────────────────────────────────────────────

set -o pipefail

# ── Parseo de argumentos ────────────────────────────────────────────────────
INSTALL_DEPS=false
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

hardware_json="\"hardware\": {
    \"cpu_cores\": $cpu_cores,
    \"ram_gb\": $ram_gb,
    \"disk_type\": \"$disk_type\",
    \"disk_gb\": $disk_gb,
    \"disk_free_gb\": $disk_free_gb,
    \"disk_uso_pct\": $disk_used_pct,
    \"smart_status\": \"$smart_status\",
    \"cpu_nombre\": \"$(json_escape "$cpu_name")\",
    \"cpu_hilos\": $cpu_threads,
    \"cpu_mhz\": $cpu_mhz,
    \"cpu_temp_c\": $cpu_temp,
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
pending_updates="null"
if command -v apt &>/dev/null; then
    # Usa cache local — no ejecuta apt update para evitar efectos secundarios en diagnóstico
    pending_updates=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst' || echo "0")
    ok "Actualizaciones pendientes: $pending_updates (caché local)"
elif command -v dnf &>/dev/null; then
    pending_updates=$(dnf check-update --quiet 2>/dev/null | grep -c "^[A-Za-z]" || echo "0")
    ok "Actualizaciones pendientes: $pending_updates"
elif command -v yum &>/dev/null; then
    pending_updates=$(yum check-update --quiet 2>/dev/null | grep -c "^[A-Za-z]" || echo "0")
    ok "Actualizaciones pendientes: $pending_updates"
elif command -v pacman &>/dev/null; then
    pending_updates=$(pacman -Qu 2>/dev/null | wc -l | xargs || echo "0")
    ok "Actualizaciones pendientes: $pending_updates"
fi

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

sistema_json="\"sistema_operativo\": {
    \"actualizaciones_pendientes\": $pending_updates,
    \"nombre\": \"$(json_escape "$os_name")\",
    \"build\": \"$os_build\",
    \"arquitectura\": \"$os_arch\",
    \"uptime_horas\": $uptime_h,
    \"sfc_archivos_danados\": $sfc_issues,
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

drivers_json="\"drivers\": {
    \"detenidos\": $stopped_count,
    \"sin_firma\": $unsigned_count,
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

red_json="\"red\": {
    \"latencia_ms\": $latency_ms,
    \"perdida_paquetes_pct\": $packet_loss_pct,
    \"dns\": $dns_json,
    \"interfaz\": \"$active_iface\"
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

seguridad_json="\"seguridad\": {
    \"antivirus\": $antivirus_name,
    \"firewall\": $firewall_active,
    \"uac_habilitado\": null,
    \"defender_activo\": $defender_active,
    \"defender_firma_dias\": $def_sig_days,
    \"selinux\": \"$selinux_status\"
}"

# ═════════════════════════════════════════════════════════════════════════════
# 6. METADATA
# ═════════════════════════════════════════════════════════════════════════════
hostname_str=$(hostname 2>/dev/null || echo "unknown")
timestamp=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')

meta_json="\"_meta\": {
    \"version\": \"3.0.0\",
    \"plataforma\": \"linux\",
    \"hostname\": \"$hostname_str\",
    \"generado_en\": \"$timestamp\",
    \"admin\": $is_admin
}"

# ═════════════════════════════════════════════════════════════════════════════
# OUTPUT JSON
# ═════════════════════════════════════════════════════════════════════════════

mkdir -p "$OUTPUT_DIR" 2>/dev/null
out_file="$OUTPUT_DIR/diagnostico_${hostname_str}_$(date '+%Y%m%d_%H%M%S').json"

cat > "$out_file" <<EOF
{
    $hardware_json,
    $sistema_json,
    $drivers_json,
    $red_json,
    $seguridad_json,
    $meta_json
}
EOF

if command -v jq &>/dev/null; then
    if ! jq empty "$out_file" 2>/dev/null; then
        echo -e "  ${RED}✗  JSON generado no válido. Revisa la salida.${NC}" >&2
        exit 1
    fi
fi

# Generar informe HTML
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_tmpl="${_script_dir}/../informe.html"
_html_file="${out_file%.json}.html"
if [[ -f "$_tmpl" ]]; then
    _split=$(grep -n '__JSON_DATA__' "$_tmpl" | head -1 | cut -d: -f1)
    if [[ -n "$_split" ]]; then
        {
            head -n "$((_split - 1))" "$_tmpl"
            printf 'const RAW = '
            cat "$out_file"
            printf ';\n'
            tail -n +"$((_split + 1))" "$_tmpl"
        } > "$_html_file"
        # Abrir con navegador (prioriza $BROWSER, luego comunes; xdg-open como último recurso
        # porque el default del sistema puede ser Text Editor).
        _opener=""
        for _b in "$BROWSER" sensible-browser firefox google-chrome chromium chromium-browser brave-browser; do
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
