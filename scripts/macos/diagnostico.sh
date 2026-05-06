#!/usr/bin/env bash
# =============================================================================
#  ResolveCore — Diagnóstico de sistema macOS
#  Versión: 2.1.0
#
#  Modos de uso:
#    1. Local en el Mac:  bash diagnostico_macos.sh
#    2. Remoto vía SSH:   bash diagnostico_macos.sh --host IP --user usuario
#
#  Requisitos en el Mac:
#    · Para modo remoto: SSH activado (Ajustes → General → Compartir → Sesión remota)
#    · Para sensores de temperatura: brew install osx-cpu-temp
# =============================================================================

set -uo pipefail

SCRIPT_VERSION="3.0.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../diagnosticos"

# ── Argumentos ────────────────────────────────────────────────────────────────

MODE="local"          # local | remote
SSH_HOST=""
SSH_USER=""
SSH_PORT="22"

while [[ $# -gt 0 ]]; do
    case $1 in
        --host)   MODE="remote"; SSH_HOST="$2";   shift 2 ;;
        --user)   SSH_USER="$2";                   shift 2 ;;
        --port)   SSH_PORT="$2";                   shift 2 ;;
        --output) OUTPUT_DIR="$2";                 shift 2 ;;
        --local)  MODE="local";                    shift ;;
        *) shift ;;
    esac
done

# ── Configurar modo de ejecución ──────────────────────────────────────────────

if [[ "$MODE" == "remote" ]]; then
    # Validar que se proporcionó host
    if [[ -z "$SSH_HOST" ]]; then
        echo "Error: modo remoto requiere --host IP"
        exit 1
    fi

    # Si no se pasó --user, pedirlo
    if [[ -z "$SSH_USER" ]]; then
        echo ''
        echo -e "\033[1;33m  ⚠  No se especificó --user. macOS bloquea el login como root por defecto.\033[0m"
        echo -e "\033[0;90m  Usa el nombre de usuario del Mac (el que aparece en Ajustes → Usuarios).\033[0m"
        echo ''
        read -rp "  Usuario del Mac: " SSH_USER
        echo ''
    fi

    SSH_DEST="${SSH_USER}@${SSH_HOST}"
    SSH_SOCKET="/tmp/resolvecore_mac_$$"
    SSH_OPTS="-p ${SSH_PORT} -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o ControlPath=${SSH_SOCKET}"
fi

# ── Colores ───────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'; NC='\033[0m'

step() { echo -e "${CYAN}  ► $1${NC}"; }
ok()   { echo -e "${GREEN}    ✓ $1${NC}"; }
warn() { echo -e "${YELLOW}    ⚠ $1${NC}"; }
fail() { echo -e "${RED}    ✗ $1${NC}"; }

# ── Helper: ejecutar comando (local o remoto) ───────────────────────────────
# mac(): ejecuta en el Mac (local o vía SSH) y devuelve salida limpia
# mac_raw(): igual pero preserva saltos de línea (para parsing multi-línea)

if [[ "$MODE" == "remote" ]]; then
    mac() {
        local result
        result=$(ssh $SSH_OPTS "$SSH_DEST" "$@" 2>/dev/null)
        echo "$result" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    }
    mac_raw() {
        ssh $SSH_OPTS "$SSH_DEST" "$@" 2>/dev/null | tr -d '\r'
    }
else
    # Modo local: usa bash -c para ejecutar cadenas de comandos correctamente
    mac() {
        local result
        result=$(bash -c "$1" 2>/dev/null)
        echo "$result" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    }
    mac_raw() {
        bash -c "$1" 2>/dev/null
    }
fi

# ── Helpers JSON ──────────────────────────────────────────────────────────────

json_str() {
    local v="${1:-}"
    [[ -z "$v" || "$v" == "null" ]] && { echo "null"; return; }
    # Escape: backslash, comillas, newlines
    v="${v//\\/\\\\}"; v="${v//\"/\\\"}"; v="${v//$'\n'/ }"
    echo "\"$v\""
}

json_num() {
    local v="${1:-}"
    [[ "$v" =~ ^-?[0-9]+([.][0-9]+)?$ ]] && echo "$v" || echo "null"
}

json_bool() { [[ "${1:-false}" == "true" ]] && echo "true" || echo "false"; }

# ── Conexión y Header ────────────────────────────────────────────────────────

echo ''
echo -e "${CYAN}  ┌─────────────────────────────────────────────────────────────────┐${NC}"
if [[ "$MODE" == "remote" ]]; then
    echo -e "${WHITE}  │   ResolveCore — Diagnóstico macOS (SSH) — v${SCRIPT_VERSION}              │${NC}"
    echo -e "${GRAY}  │   $(date '+%Y-%m-%d %H:%M:%S')   → ${SSH_DEST}:${SSH_PORT}${NC}"
else
    echo -e "${WHITE}  │   ResolveCore — Diagnóstico macOS (Local) — v${SCRIPT_VERSION}             │${NC}"
    echo -e "${GRAY}  │   $(date '+%Y-%m-%d %H:%M:%S')   → ejecución local${NC}"
fi
echo -e "${CYAN}  └─────────────────────────────────────────────────────────────────┘${NC}"
echo ''

# Solo para modo remoto: establecer conexión SSH
if [[ "$MODE" == "remote" ]]; then
    step "Conectando con ${SSH_DEST}:${SSH_PORT} ..."
    echo -e "${GRAY}  (introduce la contraseña cuando se pida — solo será necesaria una vez)${NC}"
    echo ''

    # Fichero temporal para capturar errores SSH
    SSH_ERR=$(mktemp)

    # SSH con ControlMaster para reutilizar sesión
    ssh \
        -p "${SSH_PORT}" \
        -o ConnectTimeout=10 \
        -o StrictHostKeyChecking=no \
        -o NumberOfPasswordPrompts=1 \
        -o ControlMaster=yes \
        -o ControlPath="${SSH_SOCKET}" \
        -o ControlPersist=300 \
        "$SSH_DEST" "echo '  ✓  Autenticado correctamente'" \
        2>"$SSH_ERR"

    ssh_exit=$?
    ssh_err=$(cat "$SSH_ERR"); rm -f "$SSH_ERR"

    if [[ $ssh_exit -ne 0 ]]; then
        echo ''
        fail "No se pudo autenticar en ${SSH_DEST}:${SSH_PORT}"
        echo ''

        if echo "$ssh_err" | grep -qi 'Connection refused'; then
            warn "SSH no está activo en el Mac."
            warn "Actívalo: Ajustes → General → Compartir → Sesión remota → ON"
        elif echo "$ssh_err" | grep -qi 'No route to host\|unreachable\|timed out'; then
            warn "El Mac (${SSH_HOST}) no es accesible."
            warn "Comprueba que la IP es correcta y el Mac está en la misma red."
        elif echo "$ssh_err" | grep -qi 'Permission denied'; then
            warn "Autenticación fallida. Causas posibles:"
            warn "  1) Contraseña incorrecta"
            warn "  2) El usuario '${SSH_USER}' no existe en el Mac"
            warn "  3) El Mac solo admite clave pública"
            warn "       → Genera clave: ssh-keygen -t ed25519"
            warn "       → Copia al Mac: ssh-copy-id ${SSH_DEST}"
        elif echo "$ssh_err" | grep -qi 'Host key verification failed'; then
            warn "La huella del host cambió."
            warn "Elimina la entrada: ssh-keygen -R ${SSH_HOST}"
        else
            warn "Error SSH: $ssh_err"
        fi
        echo ''
        exit 1
    fi

    ok "Conexión SSH establecida"
    # Cerrar socket al salir
    trap 'ssh -S "${SSH_SOCKET}" -O exit "${SSH_DEST}" 2>/dev/null; rm -f "${SSH_SOCKET}"' EXIT
    echo ''
fi

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
HOSTNAME_VAL=$(mac "hostname -s 2>/dev/null" || echo "macos_device")
OUTPUT_FILE="${OUTPUT_DIR}/diagnostico_${HOSTNAME_VAL}_${TIMESTAMP}.json"


# ═════════════════════════════════════════════════════════════════════════════
# 1. HARDWARE — CPU · RAM · GPU · Disco · Batería · Temperatura
# ═════════════════════════════════════════════════════════════════════════════

step 'Hardware — CPU · RAM · GPU · Almacenamiento · Batería'

# CPU (compatible Intel y Apple Silicon)
cpu_name=$(mac "sysctl -n machdep.cpu.brand_string 2>/dev/null")
[[ -z "$cpu_name" ]] && cpu_name=$(mac "sysctl -n hw.model 2>/dev/null")
cpu_cores=$(mac "sysctl -n hw.physicalcpu 2>/dev/null")
cpu_threads=$(mac "sysctl -n hw.logicalcpu 2>/dev/null")

# Frecuencia
cpu_mhz='null'
cpu_freq_raw=$(mac "sysctl -n hw.cpufrequency_max 2>/dev/null")
if [[ -n "$cpu_freq_raw" && "$cpu_freq_raw" =~ ^[0-9]+$ ]]; then
    cpu_mhz=$(( cpu_freq_raw / 1000000 ))
fi

# Detectar arquitectura
arch=$(mac "uname -m 2>/dev/null")
if [[ "$arch" == "arm64" ]]; then
    chip_family="Apple Silicon"
    # Para Apple Silicon, obtener nombre del chip vía system_profiler
    if [[ -z "$cpu_name" || "$cpu_name" == "null" ]]; then
        cpu_name=$(mac_raw "system_profiler SPHardwareDataType 2>/dev/null" | grep -i 'Chip:' | sed 's/.*Chip: //' | xargs)
    fi
else
    chip_family="Intel"
fi

ok "CPU: ${cpu_name:-desconocido} (${chip_family}) — ${cpu_cores:-?} cores / ${cpu_threads:-?} threads"

# RAM
ram_bytes=$(mac "sysctl -n hw.memsize 2>/dev/null")
ram_gb=0
[[ -n "$ram_bytes" && "$ram_bytes" =~ ^[0-9]+$ ]] && ram_gb=$(( ram_bytes / 1073741824 ))
ok "RAM: ${ram_gb}GB"

# GPU (vía system_profiler)
step 'Detectando GPU...'
gpu_info=$(mac_raw "system_profiler SPDisplaysDataType 2>/dev/null")
gpu_name=$(echo "$gpu_info" | grep 'Chipset Model:' | head -1 | sed 's/.*Chipset Model: //' | xargs)
gpu_vram=$(echo "$gpu_info" | grep 'VRAM ' | head -1 | sed 's/.*: //' | xargs)
[[ -z "$gpu_vram" ]] && gpu_vram=$(echo "$gpu_info" | grep 'Total Available Graphics Memory:' | head -1 | sed 's/.*: //' | xargs)
[[ -n "$gpu_name" ]] && ok "GPU: ${gpu_name} (VRAM: ${gpu_vram:-unified/shared})" || warn "GPU: no detectada"

# ── Disco ─────────────────────────────────────────────────────────────────────

disk_gb='null'; disk_type='Unknown'; smart_status='Unknown'; disk_model=''

root_disk=$(mac 'diskutil info / 2>/dev/null | grep "Part of Whole" | awk "{print \$NF}"' | xargs)
root_disk="${root_disk:-disk0}"

disk_info=$(mac_raw "diskutil info /dev/${root_disk}")

disk_model=$(echo "$disk_info" | grep 'Device / Media Name' | sed 's/.*: //' | xargs)
# diskutil en Apple Silicon reporta el tamaño con formato "X.X GB (N Bytes)"
# Extraer primero en GB directamente, fallback a Bytes
disk_gb_raw=$(echo "$disk_info" | grep 'Disk Size' | awk '{for(i=1;i<=NF;i++) if($i~/^[0-9]+\.[0-9]+$/ && $(i+1)=="GB") print $i}' | head -1)
if [[ -n "$disk_gb_raw" && "$disk_gb_raw" =~ ^[0-9] ]]; then
    disk_gb=$(printf '%.0f' "$disk_gb_raw")
else
    # Fallback: extraer Bytes
    disk_bytes=$(echo "$disk_info" | grep 'Disk Size' | awk '{for(i=1;i<=NF;i++) if($i=="Bytes") print $(i-1)}' | tr -d '(' | head -1)
    [[ -n "$disk_bytes" && "$disk_bytes" =~ ^[0-9]+$ ]] && disk_gb=$(( disk_bytes / 1073741824 ))
fi

protocol=$(echo "$disk_info" | grep 'Protocol:' | awk '{print $2}')
if echo "$protocol" | grep -qi 'nvme\|pcie'; then disk_type='NVMe'
elif echo "$protocol" | grep -qi 'sata';        then disk_type='SSD'
else disk_type='SSD'
fi

ok "Disco: ${disk_model:-desconocido} (${disk_type}, ${disk_gb}GB)"

# SMART básico + atributos extendidos
smart_status='Unknown'
smart_attrs_json='null'

_smart_raw=$(mac "command -v smartctl >/dev/null 2>&1 && sudo smartctl -H /dev/${root_disk} 2>/dev/null || echo no_smartmontools")
if echo "$_smart_raw" | grep -q 'no_smartmontools'; then
    warn "SMART: brew install smartmontools para habilitar S.M.A.R.T."
elif echo "$_smart_raw" | grep -q 'PASSED'; then smart_status='OK'; ok "SMART: OK"
elif echo "$_smart_raw" | grep -q 'FAILED'; then smart_status='FAILED'; warn "SMART: FAILED — disco en estado crítico"
else smart_status='Unknown'; warn "SMART: Unknown"
fi

if [[ "$smart_status" != "Unknown" ]]; then
    smart_a=$(mac "sudo smartctl -A /dev/${root_disk} 2>/dev/null")
    if [[ -n "$smart_a" ]]; then
        _rlc=$(echo "$smart_a" | awk '/Reallocated_Sector_Ct/{print $10}' | head -1)
        _cps=$(echo "$smart_a" | awk '/Current_Pending_Sector/{print $10}' | head -1)
        _ouc=$(echo "$smart_a" | awk '/Offline_Uncorrectable/{print $10}' | head -1)
        _tmp=$(echo "$smart_a" | awk '/Temperature_Celsius/{print $10}' | head -1)
        _poh=$(echo "$smart_a" | awk '/Power_On_Hours/{print $10}' | head -1)
        [[ ! "$_tmp" =~ ^[0-9]+$ ]] && _tmp=$(echo "$smart_a" | grep -i 'Temperature:' | grep -oP '\b[0-9]+\b' | head -1)
        [[ ! "$_poh" =~ ^[0-9]+$ ]] && _poh=$(echo "$smart_a" | grep -i 'Power On Hours:' | grep -oP '[0-9,]+' | tr -d ',' | head -1)
        [[ "$_rlc" =~ ^[0-9]+$ ]] || _rlc="null"
        [[ "$_cps" =~ ^[0-9]+$ ]] || _cps="null"
        [[ "$_ouc" =~ ^[0-9]+$ ]] || _ouc="null"
        [[ "$_tmp" =~ ^[0-9]+$ ]] || _tmp="null"
        [[ "$_poh" =~ ^[0-9]+$ ]] || _poh="null"
        smart_attrs_json="{\"reallocated_sectors\":$_rlc,\"pending_sectors\":$_cps,\"uncorrectable_errors\":$_ouc,\"temperatura_c\":$_tmp,\"horas_encendido\":$_poh}"
        [[ "$_tmp" != "null" ]] && ok "Disco temp: ${_tmp}°C — Horas encendido: ${_poh:-?}h"
    fi
fi

# Espacio libre en disco raíz
disk_free_gb=$(mac "df -k / 2>/dev/null | awk 'NR==2{printf \"%.0f\", \$4/1048576}'")
disk_used_pct=$(mac "df / 2>/dev/null | awk 'NR==2{print \$5}' | tr -d '%'")
ok "Disco libre: ${disk_free_gb}GB (uso: ${disk_used_pct}%)"

battery_json='null'

# Detectar si es portátil o sobremesa
is_laptop=$(mac "system_profiler SPHardwareDataType 2>/dev/null | grep -c 'MacBook'")

if [[ "$is_laptop" -gt 0 ]]; then
    # pmset para porcentaje y estado
    bat_raw=$(mac_raw "pmset -g batt 2>/dev/null")

    # Extraer porcentaje
    bat_pct=$(echo "$bat_raw" | grep -oE '[0-9]+%' | head -1 | tr -d '%')

    # Estado (charging/discharging/charged)
    bat_status=$(echo "$bat_raw" | sed 's/.*; //' | awk '{print $1}' | head -1 | xargs)

    # Info detallada vía system_profiler
    bat_sp=$(mac_raw "system_profiler SPPowerDataType 2>/dev/null")

    bat_cycles=$(echo "$bat_sp" | grep 'Cycle Count' | awk '{print $NF}')
    bat_health_pct=$(echo "$bat_sp" | grep 'Maximum Capacity' | grep -oE '[0-9]+')
    bat_condition=$(echo "$bat_sp" | grep 'Condition' | awk '{print $NF}')
    bat_temp=$(echo "$bat_sp" | grep 'Temperature' | grep -oE '[0-9]+\.[0-9]+' | head -1)

    if [[ -n "$bat_pct" ]]; then
        battery_json="{\"presente\":true,\"carga_pct\":$(json_num "$bat_pct"),\"estado\":$(json_str "$bat_status"),\"ciclos\":$(json_num "$bat_cycles"),\"salud_pct\":$(json_num "$bat_health_pct"),\"condicion\":$(json_str "$bat_condition"),\"temperatura_c\":$(json_num "$bat_temp")}"
        ok "Batería: ${bat_pct}% (${bat_status:-?}), ciclos: ${bat_cycles:-?}, salud: ${bat_health_pct:-?}%"
    else
        battery_json='{"presente":false}'
        warn "Batería: no se pudo obtener información"
    fi
else
    battery_json='{"presente":false}'
    ok "Equipo de sobremesa (sin batería)"
fi


# ── Temperatura CPU ────────────────────────────────────────────────────────────

cpu_temp='null'
cpu_temp_raw=$(mac "osx-cpu-temp 2>/dev/null" | grep -oE '[0-9]+\.[0-9]+' | head -1)
[[ -z "$cpu_temp_raw" ]] && cpu_temp_raw=$(mac "istats cpu temp --value-only 2>/dev/null")
[[ -n "$cpu_temp_raw" && "$cpu_temp_raw" =~ ^[0-9] ]] && cpu_temp="$cpu_temp_raw"

if [[ "$cpu_temp" != "null" ]]; then
    ok "Temperatura CPU: ${cpu_temp}°C"
else
    warn "Temperatura CPU: instala 'osx-cpu-temp' (brew install osx-cpu-temp)"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 2. SISTEMA OPERATIVO
# ═════════════════════════════════════════════════════════════════════════════

step 'Sistema Operativo — Versión · SIP · Actualizaciones · Uptime'

os_name=$(mac "sw_vers -productName 2>/dev/null")
os_version=$(mac "sw_vers -productVersion 2>/dev/null")
os_build=$(mac "sw_vers -buildVersion 2>/dev/null")
kernel=$(mac "uname -r 2>/dev/null")
arch=$(mac "uname -m 2>/dev/null")

# Uptime vía sysctl kern.boottime
boot_time=$(mac "sysctl -n kern.boottime 2>/dev/null" | grep -oE '[0-9]{10}' | head -1)
uptime_h='null'
if [[ -n "$boot_time" && "$boot_time" =~ ^[0-9]+$ ]]; then
    current_time=$(date +%s)
    uptime_seconds=$(( current_time - boot_time ))
    uptime_h=$(echo "scale=1; $uptime_seconds / 3600" | bc 2>/dev/null || echo "null")
fi

ok "OS: ${os_name} ${os_version} (build ${os_build})"
ok "Kernel: ${kernel} — Arch: ${arch}"
[[ "$uptime_h" != "null" ]] && ok "Uptime: ${uptime_h}h" || warn "Uptime: no disponible"

# Actualizaciones pendientes
step 'Buscando actualizaciones...'
pending_updates=$(mac "softwareupdate -l 2>&1 | grep -c 'Label:'" || echo "0")
[[ "$pending_updates" =~ ^[0-9]+$ ]] && ok "Actualizaciones pendientes: ${pending_updates}" || warn "No se pudo verificar actualizaciones"

# SIP (System Integrity Protection)
sip_status=$(mac "csrutil status 2>/dev/null" | grep -oE 'enabled|disabled' | head -1)
[[ -z "$sip_status" ]] && sip_status='unknown'
[[ "$sip_status" == "disabled" ]] && \
    warn "SIP: DESACTIVADO — riesgo de seguridad" || ok "SIP: ${sip_status:-habilitado}"

# Time Machine
tm_last=$(mac "tmutil latestbackup 2>/dev/null" | xargs)
tm_status=$(mac "tmutil status 2>/dev/null" | grep 'Running' | awk '{print $3}' | tr -d ';')
if [[ -n "$tm_last" ]]; then
    ok "Time Machine: último backup → $(basename "$tm_last")"
else
    warn "Time Machine: sin backup reciente o no configurado"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 3. RED — Interfaz · WiFi · DNS · Latencia
# ═════════════════════════════════════════════════════════════════════════════

step 'Red — WiFi · Latencia · DNS'

latency_ms='null'; packet_loss_pct='null'; dns_json='[]'
wifi_ssid=''; wifi_signal='null'; default_iface=''

# Interfaz por defecto
default_iface=$(mac_raw "route -n get default 2>/dev/null" | grep 'interface:' | awk '{print $2}')

# WiFi info vía airport
wifi_info=$(mac_raw "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null")
wifi_ssid=$(echo "$wifi_info" | grep ' SSID:' | awk '{print $2}')
wifi_signal=$(echo "$wifi_info" | grep 'agrCtlRSSI:' | awk '{print $2}')

if [[ -n "$wifi_ssid" ]]; then
    ok "WiFi: ${wifi_ssid} (RSSI: ${wifi_signal:-?} dBm)"
else
    ok "Interfaz activa: ${default_iface:-desconocida} (Ethernet/OTRO)"
fi

# DNS via scutil
dns_list=$(mac_raw "scutil --dns 2>/dev/null" | grep 'nameserver\[' | awk '{print $3}' | sort -u | awk '{printf "\"%s\",", $1}' | sed 's/,$//')
[[ -n "$dns_list" ]] && dns_json="[${dns_list}]"

# Ping para latencia (timeout 5 segundos, 5 paquetes)
ping_out=$(mac_raw "ping -c 5 -t 5 8.8.8.8 2>/dev/null")
if [[ -n "$ping_out" && "$ping_out" =~ "round-trip" ]]; then
    latency_ms=$(echo "$ping_out" | grep 'round-trip' | awk -F'/' '{print $5}' | xargs)
    packet_loss_pct=$(echo "$ping_out" | grep 'packet loss' | awk '{gsub(/%/,""); print $7}')
    ok "Latencia: ${latency_ms:-?}ms — Pérdida: ${packet_loss_pct:-0}%"
else
    packet_loss_pct='100'
    warn "Sin respuesta de 8.8.8.8 (posiblemente sin internet)"
fi

# Bluetooth
bt_info=$(mac_raw "system_profiler SPBluetoothDataType 2>/dev/null" | head -20)
bt_status=$(echo "$bt_info" | grep 'State:' | head -1 | awk '{print $2}')
[[ -n "$bt_status" ]] && ok "Bluetooth: ${bt_status}" || ok "Bluetooth: no detectado"

# ═════════════════════════════════════════════════════════════════════════════
# 4. SEGURIDAD — Firewall · FileVault · Gatekeeper · XProtect · SIP
# ═════════════════════════════════════════════════════════════════════════════

step 'Seguridad — Firewall · FileVault · Gatekeeper · XProtect'

firewall='false'; filevault='false'; gatekeeper='false'; xprotect_version=''

# Firewall ALF
fw_val=$(mac "/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null")
[[ "$fw_val" =~ enabled ]] && firewall='true'
ok "Firewall: $([ "$firewall" == 'true' ] && echo 'activo' || echo 'INACTIVO — RIESGO')"

# FileVault
fv_status=$(mac "fdesetup status 2>/dev/null")
[[ "$fv_status" =~ On|Enabled ]] && filevault='true'
ok "FileVault: $([ "$filevault" == 'true' ] && echo 'habilitado' || echo 'DESHABILITADO — RIESGO')"

# Gatekeeper
gk_status=$(mac "spctl --status 2>/dev/null")
[[ "$gk_status" =~ enabled|assessments ]] && gatekeeper='true'
ok "Gatekeeper: $([ "$gatekeeper" == 'true' ] && echo 'habilitado' || echo 'DESHABILITADO — RIESGO')"

# XProtect
xprotect_version=$(mac "defaults read /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Resources/XProtect.meta.plist Version 2>/dev/null")
[[ -n "$xprotect_version" ]] && ok "XProtect: versión ${xprotect_version}" || warn "XProtect: no detectado"

# Usuarios administradores
sudo_users=$(mac "dscl . -read /Groups/admin GroupMembership 2>/dev/null" | sed 's/GroupMembership: //')
[[ -n "$sudo_users" ]] && ok "Admins: ${sudo_users}" || warn "No se pudieron obtener admins"

# ═════════════════════════════════════════════════════════════════════════════
# 5. OUTPUT JSON
# ═════════════════════════════════════════════════════════════════════════════

mkdir -p "$OUTPUT_DIR"

# Asegurar que las variables numéricas tengan valores válidos
[[ ! "$disk_used_pct" =~ ^[0-9]+$ ]] && disk_used_pct='null' || disk_used_pct="$disk_used_pct"

cat > "$OUTPUT_FILE" << EOF
{
  "hardware": {
    "cpu_cores":      $(json_num "$cpu_cores"),
    "ram_gb":         $(json_num "$ram_gb"),
    "disk_type":      $(json_str "$disk_type"),
    "disk_gb":        $(json_num "$disk_gb"),
    "disk_free_gb":   $(json_num "$disk_free_gb"),
    "disk_uso_pct":   $(json_num "$disk_used_pct"),
    "smart_status":   $(json_str "$smart_status"),
    "smart_atributos": $smart_attrs_json,
    "cpu_nombre":     $(json_str "$cpu_name"),
    "cpu_familia":    $(json_str "$chip_family"),
    "cpu_hilos":      $(json_num "$cpu_threads"),
    "cpu_mhz":        $(json_num "$cpu_mhz"),
    "cpu_temp_c":     $(json_num "$cpu_temp"),
    "disco_modelo":   $(json_str "$disk_model"),
    "gpu":            $(json_str "$gpu_name"),
    "gpu_vram":       $(json_str "$gpu_vram"),
    "bateria":        $battery_json
  },
  "sistema_operativo": {
    "actualizaciones_pendientes": $(json_num "$pending_updates"),
    "nombre":       $(json_str "${os_name} ${os_version}"),
    "version":      $(json_str "$os_version"),
    "build":        $(json_str "$os_build"),
    "kernel":       $(json_str "$kernel"),
    "arquitectura": $(json_str "$arch"),
    "uptime_horas": $(json_num "$uptime_h"),
    "sip":          $(json_str "$sip_status"),
    "time_machine_ultimo": $(json_str "$tm_last")
  },
  "red": {
    "latencia_ms":          $(json_num "$latency_ms"),
    "perdida_paquetes_pct": $(json_num "$packet_loss_pct"),
    "dns":        $dns_json,
    "interfaz":   $(json_str "$default_iface"),
    "wifi_ssid":  $(json_str "$wifi_ssid"),
    "wifi_rssi_dbm": $(json_num "$wifi_signal"),
    "bluetooth":  $(json_str "$bt_status")
  },
  "seguridad": {
    "antivirus":        null,
    "firewall":         $firewall,
    "filevault":        $filevault,
    "gatekeeper":       $gatekeeper,
    "xprotect_version": $(json_str "$xprotect_version"),
    "sip":              $(json_str "$sip_status"),
    "admins":           $(json_str "$sudo_users")
  },
  "_meta": {
    "version":    "3.0.0",
    "plataforma": "macos",
    "hostname":   $(json_str "$HOSTNAME_VAL"),
    "modo":       $(json_str "$MODE"),
    "ssh_host":   $(json_str "$SSH_HOST"),
    "generado_en": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
    "root":       false
  }
}
EOF

# Generar informe HTML
_tmpl="${SCRIPT_DIR}/../informe.html"
_html_file="${OUTPUT_FILE%.json}.html"
if [[ -f "$_tmpl" ]]; then
    _split=$(grep -n '__JSON_DATA__' "$_tmpl" | head -1 | cut -d: -f1)
    if [[ -n "$_split" ]]; then
        {
            head -n "$((_split - 1))" "$_tmpl"
            printf 'const RAW = '
            cat "$OUTPUT_FILE"
            printf ';\n'
            tail -n +"$((_split + 1))" "$_tmpl"
        } > "$_html_file"
        open "$_html_file" 2>/dev/null &
    fi
fi

echo ''
echo -e "${GRAY}  ─────────────────────────────────────────────────────────────────${NC}"
echo -e "${GREEN}  ✓  Diagnóstico macOS completado${NC}"
echo -e "${WHITE}  📄 JSON: $OUTPUT_FILE${NC}"
[[ -f "$_html_file" ]] && echo -e "${CYAN}  🌐 HTML: $_html_file${NC}"
echo ''
echo -e "${GRAY}  → Sube este archivo en ResolveCore: Diagnóstico del equipo → Importar JSON${NC}"
echo ''
