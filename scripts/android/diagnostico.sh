#!/usr/bin/env bash
# =============================================================================
#  ResolveCore — Diagnóstico de dispositivo Android (vía ADB)
#  Versión: 1.0.0
#
#  Genera diagnostico_android_<serial>_<timestamp>.json compatible con ResolveCore.
#
#  Requisitos:
#    · adb instalado en la máquina del técnico  (apt install adb / brew install android-platform-tools)
#    · Depuración USB (o ADB inalámbrico) habilitada en el dispositivo
#    · Dispositivo conectado y autorizado
#
#  Uso:
#    bash diagnostico_android.sh                         # primer dispositivo detectado
#    bash diagnostico_android.sh <serial>                # dispositivo concreto
#    bash diagnostico_android.sh --output /tmp           # directorio de salida
#    bash diagnostico_android.sh <serial> --output /tmp
# =============================================================================

set -uo pipefail

SCRIPT_VERSION="2.0.0"
SERIAL=""
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
OUTPUT_DIR="${SCRIPT_DIR}/../diagnosticos"

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        -*) shift ;;
        *)  [[ -z "$SERIAL" ]] && SERIAL="$1"; shift ;;
    esac
done

# ── Colores ───────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'; NC='\033[0m'

step() { echo -e "${CYAN}  ► $1${NC}"; }
ok()   { echo -e "${GREEN}    ✓ $1${NC}"; }
warn() { echo -e "${YELLOW}    ⚠ $1${NC}"; }
fail() { echo -e "${RED}    ✗ $1${NC}"; }

# ── Verificar ADB ─────────────────────────────────────────────────────────────

if ! command -v adb &>/dev/null; then
    fail "adb no encontrado. Instálalo con:  apt install adb  |  brew install android-platform-tools"
    exit 1
fi

# Seleccionar dispositivo
if [[ -z "$SERIAL" ]]; then
    SERIAL=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{print $1; exit}')
fi

if [[ -z "$SERIAL" ]]; then
    fail "No se encontró ningún dispositivo Android conectado y autorizado."
    fail "Pasos: Ajustes → Opciones de desarrollador → Depuración USB → Aceptar en el dispositivo"
    exit 1
fi

echo ''
echo -e "${CYAN}  ┌─────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${WHITE}  │   ResolveCore — Diagnóstico Android — v${SCRIPT_VERSION}                  │${NC}"
echo -e "${GRAY}  │   $(date '+%Y-%m-%d %H:%M:%S')   Serial: ${SERIAL}${NC}"
echo -e "${CYAN}  └─────────────────────────────────────────────────────────────────┘${NC}"
echo ''

# Shorthand para adb shell
adb_s() { adb -s "$SERIAL" shell "$@" 2>/dev/null | tr -d '\r'; }
adb_getprop() { adb_s getprop "$1" 2>/dev/null | xargs; }

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
OUTPUT_FILE="${OUTPUT_DIR}/diagnostico_android_${SERIAL}_${TIMESTAMP}.json"

# ── Helpers JSON ──────────────────────────────────────────────────────────────

json_str() {
    local v="${1:-}"
    [[ -z "$v" ]] && { echo "null"; return; }
    v="${v//\\/\\\\}"; v="${v//\"/\\\"}"; v="${v//$'\n'/ }"
    echo "\"$v\""
}

json_num() {
    local v="${1:-}"
    [[ "$v" =~ ^-?[0-9]+([.][0-9]+)?$ ]] && echo "$v" || echo "null"
}

json_bool() { [[ "${1:-false}" == "true" ]] && echo "true" || echo "false"; }

# ═════════════════════════════════════════════════════════════════════════════
# 1. INFORMACIÓN DEL DISPOSITIVO
# ═════════════════════════════════════════════════════════════════════════════

step 'Dispositivo — Fabricante · Modelo · Android version'

manufacturer=$(adb_getprop ro.product.manufacturer)
model=$(adb_getprop ro.product.model)
device_name=$(adb_getprop ro.product.name)
brand=$(adb_getprop ro.product.brand)
android_version=$(adb_getprop ro.build.version.release)
sdk_version=$(adb_getprop ro.build.version.sdk)
build_number=$(adb_getprop ro.build.display.id)
kernel=$(adb_s uname -r 2>/dev/null | head -1 || echo '')
architecture=$(adb_getprop ro.product.cpu.abi)

ok "Dispositivo: ${manufacturer} ${model} (${brand})"
ok "Android: ${android_version} (SDK ${sdk_version})"
ok "Build: ${build_number}"

# ═════════════════════════════════════════════════════════════════════════════
# 2. HARDWARE — CPU · RAM · Almacenamiento
# ═════════════════════════════════════════════════════════════════════════════

step 'Hardware — CPU · RAM · Almacenamiento'

# CPU
cpu_name=$(adb_s cat /proc/cpuinfo | grep -i 'hardware\|model name\|Processor' | head -1 | cut -d: -f2 | xargs || echo '')
cpu_cores=$(adb_s nproc 2>/dev/null || adb_s grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo '')
[[ -z "$cpu_name" ]] && cpu_name="$(adb_getprop ro.board.platform)"
ok "CPU: ${cpu_name} — ${cpu_cores} núcleos"

# RAM
ram_total_kb=$(adb_s grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo '0')
ram_gb=$(echo "scale=1; ${ram_total_kb:-0} / 1048576" | bc 2>/dev/null || echo '')
ram_gb_int=$(( (${ram_total_kb:-0} + 524288) / 1048576 ))
ok "RAM: ${ram_gb_int}GB"

# Almacenamiento (almacenamiento interno /data)
storage_json='null'
df_out=$(adb_s df /data 2>/dev/null | awk 'NR==2')
if [[ -n "$df_out" ]]; then
    st_total=$(echo "$df_out" | awk '{print $2}')
    st_used=$(echo "$df_out" | awk '{print $3}')
    st_free=$(echo "$df_out" | awk '{print $4}')
    # Los valores pueden estar en KB o con sufijos (K, M, G)
    to_gb() {
        local v="${1:-0}"
        if   echo "$v" | grep -qE 'G$'; then echo "${v%G}"
        elif echo "$v" | grep -qE 'M$'; then echo "$(echo "scale=2; ${v%M}/1024" | bc 2>/dev/null || echo 0)"
        elif echo "$v" | grep -qE 'K$'; then echo "$(echo "scale=2; ${v%K}/1048576" | bc 2>/dev/null || echo 0)"
        elif [[ "$v" =~ ^[0-9]+$ ]];    then echo "$(echo "scale=2; $v/1048576" | bc 2>/dev/null || echo 0)"
        else echo "0"; fi
    }
    st_total_gb=$(to_gb "$st_total")
    st_used_gb=$(to_gb "$st_used")
    st_free_gb=$(to_gb "$st_free")
    storage_json="{\"total_gb\":${st_total_gb},\"usado_gb\":${st_used_gb},\"libre_gb\":${st_free_gb}}"
    ok "Almacenamiento interno /data: total=${st_total_gb}GB usado=${st_used_gb}GB"
fi

# SD card
sd_present='false'
if adb_s ls /sdcard/Android &>/dev/null; then sd_present='true'; ok "Tarjeta SD: presente"; fi

# ═════════════════════════════════════════════════════════════════════════════
# 3. BATERÍA
# ═════════════════════════════════════════════════════════════════════════════

step 'Batería — Nivel · Temperatura · Ciclos'

battery_json='null'
bat_raw=$(adb_s dumpsys battery 2>/dev/null || echo '')

if [[ -n "$bat_raw" ]]; then
    bat_level=$(echo "$bat_raw" | grep -i 'level:' | awk '{print $2}' | head -1 || echo '')
    bat_status=$(echo "$bat_raw" | grep -i 'status:' | awk '{print $2}' | head -1 || echo '')
    bat_health=$(echo "$bat_raw" | grep -i 'health:' | awk '{print $2}' | head -1 || echo '')
    bat_temp_raw=$(echo "$bat_raw" | grep -i 'temperature:' | awk '{print $2}' | head -1 || echo '')
    bat_voltage_raw=$(echo "$bat_raw" | grep -i 'voltage:' | awk '{print $2}' | head -1 || echo '')
    bat_tech=$(echo "$bat_raw" | grep -i 'technology:' | awk '{print $2}' | head -1 || echo '')
    bat_plugged=$(echo "$bat_raw" | grep -i 'plugged:' | awk '{print $2}' | head -1 || echo '')

    # Temperatura en décimas de grado → grados
    bat_temp='null'
    [[ -n "$bat_temp_raw" && "$bat_temp_raw" =~ ^[0-9]+$ ]] && bat_temp=$(echo "scale=1; $bat_temp_raw/10" | bc 2>/dev/null || echo 'null')

    # Voltage en mV → V
    bat_voltage='null'
    [[ -n "$bat_voltage_raw" && "$bat_voltage_raw" =~ ^[0-9]+$ ]] && bat_voltage=$(echo "scale=2; $bat_voltage_raw/1000" | bc 2>/dev/null || echo 'null')

    # Ciclos (disponible en algunos ROMs via batterystats)
    bat_cycles='null'
    bat_cycles_raw=$(adb_s dumpsys batterystats 2>/dev/null | grep -i 'Charge cycles' | grep -oP '[0-9]+' | head -1 || echo '')
    [[ -n "$bat_cycles_raw" ]] && bat_cycles="$bat_cycles_raw"

    # Estado: 1=unknown, 2=charging, 3=discharging, 4=not charging, 5=full
    bat_status_str='unknown'
    case "$bat_status" in
        2) bat_status_str='cargando' ;;
        3) bat_status_str='descargando' ;;
        4) bat_status_str='no_carga' ;;
        5) bat_status_str='completa' ;;
    esac

    # Salud: 1=unknown, 2=good, 3=overheat, 4=dead, 5=overvoltage, 7=cold
    bat_health_str='unknown'
    case "$bat_health" in
        2) bat_health_str='buena' ;;
        3) bat_health_str='sobrecalentamiento' ;;
        4) bat_health_str='deteriorada' ;;
        5) bat_health_str='sobrevoltaje' ;;
        7) bat_health_str='fría' ;;
    esac

    # Capacidad de diseño y desgaste (algunos fabricantes exponen estos archivos)
    bat_desgaste='null'
    bat_full_cap=$(adb_s 'cat /sys/class/power_supply/battery/charge_full 2>/dev/null || cat /sys/class/power_supply/Battery/charge_full 2>/dev/null || echo ""' | head -1 || echo '')
    bat_design_cap=$(adb_s 'cat /sys/class/power_supply/battery/charge_full_design 2>/dev/null || cat /sys/class/power_supply/Battery/charge_full_design 2>/dev/null || echo ""' | head -1 || echo '')
    if [[ "$bat_full_cap" =~ ^[0-9]+$ && "$bat_design_cap" =~ ^[0-9]+$ && "$bat_design_cap" -gt 0 ]]; then
        bat_desgaste=$(awk "BEGIN{v=(1 - $bat_full_cap / $bat_design_cap) * 100; printf \"%.1f\", (v<0?0:v)}")
        ok "Desgaste batería: ${bat_desgaste}%"
    fi

    # Ciclos — más métodos según fabricante
    [[ -z "$bat_cycles_raw" ]] && bat_cycles_raw=$(adb_s 'cat /sys/class/power_supply/battery/cycle_count 2>/dev/null || echo ""' | head -1 || echo '')
    [[ -z "$bat_cycles_raw" ]] && bat_cycles_raw=$(adb_s 'cat /sys/class/power_supply/Battery/cycle_count 2>/dev/null || echo ""' | head -1 || echo '')
    [[ "$bat_cycles_raw" =~ ^[0-9]+$ ]] && bat_cycles="$bat_cycles_raw"

    battery_json="{\"carga_pct\":$(json_num "$bat_level"),\"estado\":$(json_str "$bat_status_str"),\"salud\":$(json_str "$bat_health_str"),\"temperatura_c\":${bat_temp},\"voltaje_v\":${bat_voltage},\"ciclos\":${bat_cycles},\"desgaste_pct\":${bat_desgaste},\"tecnologia\":$(json_str "$bat_tech"),\"enchufado\":$(json_bool "$([ "$bat_plugged" != "0" ] && echo true || echo false)")}"

    ok "Batería: ${bat_level}% (${bat_status_str}, salud: ${bat_health_str})"
    [[ "$bat_temp" != 'null' ]] && ok "Temperatura batería: ${bat_temp}°C"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 4. RED
# ═════════════════════════════════════════════════════════════════════════════

# Temperatura CPU desde thermal zones
cpu_temp='null'
for zone in $(adb_s ls /sys/class/thermal/ 2>/dev/null | grep thermal_zone); do
    tz_type=$(adb_s "cat /sys/class/thermal/$zone/type 2>/dev/null" | xargs || echo '')
    if echo "$tz_type" | grep -qiE 'cpu|soc|tsens|bcl-skin|cpu0-die|cpu-0-0'; then
        t=$(adb_s "cat /sys/class/thermal/$zone/temp 2>/dev/null" | xargs || echo '')
        if [[ "$t" =~ ^[0-9]+$ && "$t" -gt 0 ]]; then
            if [[ "$t" -gt 1000 ]]; then
                cpu_temp=$(awk "BEGIN{printf \"%.1f\", $t/1000}")
            else
                cpu_temp="$t"
            fi
            break
        fi
    fi
done
[[ "$cpu_temp" != "null" ]] && ok "Temperatura CPU: ${cpu_temp}°C"

# Nivel de parche de seguridad y estado del bootloader
sec_patch=$(adb_getprop ro.build.version.security_patch)
bootloader_state=$(adb_getprop ro.boot.verifiedbootstate)
bootloader_locked='true'
[[ "$bootloader_state" == "orange" || "$bootloader_state" == "yellow" ]] && bootloader_locked='false'
[[ "$bootloader_locked" == "false" ]] && warn "Bootloader: DESBLOQUEADO — riesgo de seguridad"

step 'Red — WiFi · IP · Latencia'

wifi_ssid=''
wifi_ip=''
wifi_signal='null'
latency_ms='null'
packet_loss='null'

# WiFi info
wifi_raw=$(adb_s dumpsys wifi 2>/dev/null | grep -E 'SSID|rssi|ipAddress' | head -10 || echo '')
wifi_ssid=$(echo "$wifi_raw" | grep -oP 'SSID: [^,]+' | head -1 | cut -d' ' -f2 || echo '')
wifi_ip=$(adb_s ip route 2>/dev/null | grep -oP 'src \K[0-9.]+' | head -1 || echo '')
wifi_signal_raw=$(echo "$wifi_raw" | grep -oP 'rssi: -[0-9]+' | grep -oP -- '-[0-9]+' | head -1 || echo '')
[[ -n "$wifi_signal_raw" ]] && wifi_signal="$wifi_signal_raw"

ok "WiFi SSID: ${wifi_ssid:-<no conectado>}  IP: ${wifi_ip:-<sin IP>}"

# Ping desde el dispositivo
ping_out=$(adb_s ping -c 5 -W 2 8.8.8.8 2>/dev/null || echo '')
if [[ -n "$ping_out" ]]; then
    latency_ms=$(echo "$ping_out" | grep -oP 'avg = [\d.]+' | grep -oP '[\d.]+' || \
                 echo "$ping_out" | grep -oP '[\d.]+/[\d.]+/[\d.]+' | cut -d/ -f2 || echo 'null')
    packet_loss=$(echo "$ping_out" | grep -oP '\d+(?=% packet loss)' || echo 'null')
    ok "Latencia: ${latency_ms}ms — Pérdida: ${packet_loss}%"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 5. SEGURIDAD
# ═════════════════════════════════════════════════════════════════════════════

step 'Seguridad — Bloqueo · Cifrado · Fuentes desconocidas · Root'

# Cifrado
encryption=$(adb_getprop ro.crypto.state)
encryption_type=$(adb_getprop ro.crypto.type)
encrypted='false'
[[ "$encryption" == 'encrypted' ]] && encrypted='true'
ok "Cifrado: ${encryption} (${encryption_type:-file-based})"

# Fuentes desconocidas (instalar APKs de fuentes externas)
unknown_sources='false'
us_val=$(adb_s settings get secure install_non_market_apps 2>/dev/null | xargs || echo '0')
[[ "$us_val" == '1' ]] && unknown_sources='true'
[[ "$unknown_sources" == 'true' ]] && warn "Fuentes desconocidas: HABILITADO — riesgo de seguridad" \
                                     || ok "Fuentes desconocidas: deshabilitado"

# Modo desarrollador
dev_mode='false'
dev_val=$(adb_s settings get global development_settings_enabled 2>/dev/null | xargs || echo '0')
[[ "$dev_val" == '1' ]] && dev_mode='true'
[[ "$dev_mode" == 'true' ]] && warn "Modo desarrollador: ACTIVO" || ok "Modo desarrollador: inactivo"

# Root (busca binarios su comunes)
rooted='false'
for su_path in /system/bin/su /system/xbin/su /sbin/su /system/su /data/local/su; do
    if adb_s "[ -f $su_path ] && echo found" 2>/dev/null | grep -q found; then
        rooted='true'; break
    fi
done
if adb_s which su 2>/dev/null | grep -qE '/su$'; then rooted='true'; fi
[[ "$rooted" == 'true' ]] && warn "Root detectado: DISPOSITIVO ROOTEADO" || ok "Root: no detectado"

# SELinux
selinux=$(adb_s getenforce 2>/dev/null | xargs || echo 'unknown')
ok "SELinux: ${selinux}"

# Bloqueo de pantalla (requiere permisos; intento)
screen_lock='unknown'
lock_val=$(adb_s settings get system screen_lock_type 2>/dev/null | xargs || echo '')
[[ -z "$lock_val" ]] && lock_val=$(adb_s settings get secure lockscreen.password_type 2>/dev/null | xargs || echo '')

# ═════════════════════════════════════════════════════════════════════════════
# 6. APLICACIONES
# ═════════════════════════════════════════════════════════════════════════════

step 'Aplicaciones — Recuento instaladas'

apps_total='null'
apps_user='null'
apps_system='null'

apps_all=$(adb_s pm list packages 2>/dev/null | wc -l | xargs || echo '')
apps_u=$(adb_s pm list packages -3 2>/dev/null | wc -l | xargs || echo '')  # -3 = third-party
apps_s=$(adb_s pm list packages -s 2>/dev/null | wc -l | xargs || echo '')  # -s = system

[[ "$apps_all" =~ ^[0-9]+$ ]] && apps_total="$apps_all"
[[ "$apps_u" =~ ^[0-9]+$ ]]   && apps_user="$apps_u"
[[ "$apps_s" =~ ^[0-9]+$ ]]   && apps_system="$apps_s"

ok "Apps instaladas: ${apps_total} (usuario: ${apps_user}, sistema: ${apps_system})"

# ═════════════════════════════════════════════════════════════════════════════
# 7. OUTPUT JSON
# ═════════════════════════════════════════════════════════════════════════════

mkdir -p "$OUTPUT_DIR"

cat > "$OUTPUT_FILE" << EOF
{
  "hardware": {
    "cpu_cores":    $(json_num "$cpu_cores"),
    "ram_gb":       $(json_num "$ram_gb_int"),
    "disk_type":    "Flash",
    "disk_gb":      null,
    "smart_status": "N/A",
    "cpu_nombre":   $(json_str "$cpu_name"),
    "cpu_temp_c":   $(json_num "$cpu_temp"),
    "almacenamiento": ${storage_json},
    "sd_presente":  ${sd_present},
    "bateria":      ${battery_json}
  },
  "sistema_operativo": {
    "actualizaciones_pendientes": null,
    "nombre":         "Android",
    "version":        $(json_str "$android_version"),
    "build":          $(json_str "$build_number"),
    "sdk":            $(json_num "$sdk_version"),
    "kernel":         $(json_str "$kernel"),
    "arquitectura":   $(json_str "$architecture"),
    "parche_seguridad": $(json_str "$sec_patch")
  },
  "red": {
    "latencia_ms":          $(json_num "$latency_ms"),
    "perdida_paquetes_pct": $(json_num "$packet_loss"),
    "dns":       [],
    "interfaz":  "wifi",
    "wifi_ssid": $(json_str "$wifi_ssid"),
    "wifi_ip":   $(json_str "$wifi_ip"),
    "wifi_rssi_dbm": $(json_num "$wifi_signal")
  },
  "seguridad": {
    "antivirus":             null,
    "firewall":              false,
    "cifrado":               ${encrypted},
    "tipo_cifrado":          $(json_str "$encryption_type"),
    "fuentes_desconocidas":  ${unknown_sources},
    "modo_desarrollador":    ${dev_mode},
    "rooteado":              ${rooted},
    "selinux":               $(json_str "$selinux"),
    "bootloader_bloqueado":  ${bootloader_locked}
  },
  "aplicaciones": {
    "total":   $(json_num "$apps_total"),
    "usuario": $(json_num "$apps_user"),
    "sistema": $(json_num "$apps_system")
  },
  "dispositivo": {
    "fabricante": $(json_str "$manufacturer"),
    "modelo":     $(json_str "$model"),
    "nombre":     $(json_str "$device_name"),
    "marca":      $(json_str "$brand"),
    "serial":     $(json_str "$SERIAL")
  },
  "_meta": {
    "version":    "$SCRIPT_VERSION",
    "plataforma": "android",
    "hostname":   $(json_str "${manufacturer}_${model}"),
    "generado_en": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
    "root":       false
  }
}
EOF

echo ''
echo -e "${GRAY}  ─────────────────────────────────────────────────────────────────${NC}"
echo -e "${GREEN}  ✓  Diagnóstico Android completado${NC}"
echo -e "${WHITE}  📄 $OUTPUT_FILE${NC}"
echo ''
echo -e "${GRAY}  → Sube este archivo en ResolveCore: Diagnóstico del equipo → Importar JSON${NC}"
echo ''
