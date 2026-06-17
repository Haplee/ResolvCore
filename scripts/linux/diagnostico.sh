#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Diagnóstico básico de un equipo Linux.
#
# Recoge métricas de hardware y sistema operativo y las vuelca en un JSON
# que luego procesa el técnico para generar el informe.
#
# Uso:
#   bash diagnostico.sh                          # salida en ../diagnosticos
#   bash diagnostico.sh /tmp                     # salida en /tmp
#   ssh user@host 'bash -s' < diagnostico.sh     # remoto sin instalar nada
#
# Probado en:  Ubuntu 22.04 / 24.04, Debian 12.
#
# Autor:   Francisco Vidal Mateo (GitHub: Haplee)
# Versión: 2.0
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

# Forzamos locale C para todo el script: en un sistema en español (es_ES) el
# printf de awk emite la coma como separador decimal ("120,5") y eso rompe el
# JSON ("uptime_horas": 120,5 -> 'Expecting property name'). Con LC_ALL=C el
# separador es siempre el punto y el JSON queda valido.
export LC_ALL=C

# ── Argumentos ────────────────────────────────────────────────────────────────
# --output <dir>  carpeta de salida explicita (back-compat / CI)
# --ticket <N>    organiza la salida en diagnosticos/tickets/<NNNNN>/diagnostico.json
# Tambien acepta un dir posicional (uso historico: bash diagnostico.sh /tmp).
OUTPUT_DIR=""
TICKET=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            echo "Uso: bash $0 [--output <dir>] [--ticket <N>] [dir]"
            echo ""
            echo "Genera un diagnostico del sistema en JSON."
            echo "  --output <dir>   carpeta de salida explicita (back-compat / CI)"
            echo "  --ticket <N>     organiza la salida en diagnosticos/tickets/<NNNNN>/"
            echo "  [dir]            dir posicional de salida (uso historico)"
            exit 0 ;;
        --output)  OUTPUT_DIR="${2:-}"; shift 2 ;;
        --ticket)  TICKET="${2:-}";     shift 2 ;;
        --silent|--install|--auto-install) shift ;;   # aceptados, sin efecto aqui
        *) [[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="$1"; shift ;;
    esac
done

HOST=$(hostname)
TS=$(date +%Y%m%d_%H%M%S)

# ── Resolucion de carpeta de salida (organizada por ticket) ──────────────────
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE_REP="${RC_REPARACIONES_DIR:-$REPO_ROOT/diagnosticos/tickets}"
if [[ -n "$OUTPUT_DIR" ]]; then
    DEST_DIR="$OUTPUT_DIR"
    FILE="$DEST_DIR/diagnostico_${HOST}_${TS}.json"
elif [[ "$TICKET" =~ ^[0-9]+$ ]]; then
    DEST_DIR="$BASE_REP/$(printf '%05d' "$TICKET")/linux"
    FILE="$DEST_DIR/diagnostico.json"
    if [[ -f "$FILE" ]]; then
        n=2
        while [[ -f "$DEST_DIR/diagnostico_v$n.json" ]]; do n=$((n + 1)); done
        FILE="$DEST_DIR/diagnostico_v$n.json"
        echo "[i] Ya existia diagnostico.json; guardando como $(basename "$FILE")"
    fi
else
    DEST_DIR="$BASE_REP/sin-ticket/linux"
    FILE="$DEST_DIR/diagnostico_${HOST}_${TS}.json"
    echo "[!] No se ha indicado ticket. Guardando en diagnosticos/tickets/sin-ticket/linux/"
fi
mkdir -p "$DEST_DIR"

# ── Helpers ──────────────────────────────────────────────────────────────────

info() { echo "[+] $*"; }
warn() { echo "[!] $*" >&2; }

info "Recogiendo métricas de $HOST..."

# ── CPU ──────────────────────────────────────────────────────────────────────
# Cogemos el primer "model name" — en CPUs con varios sockets se repite
# por cada core y para el informe basta con uno.

cpu_model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
cpu_cores=$(nproc)
cpu_load=$(awk '{print $1}' /proc/loadavg)    # carga 1 minuto
cpu_load5=$(awk '{print $2}' /proc/loadavg)   # carga 5 minutos
cpu_load15=$(awk '{print $3}' /proc/loadavg)  # carga 15 minutos

# Uso global de CPU = 100 - %idle de la segunda muestra de top (la primera es
# acumulada desde el arranque y no refleja el momento actual). Best-effort.
cpu_uso=$(top -bn2 -d 0.3 2>/dev/null | awk '/%Cpu/{u=100-$8} END{if(u!="")printf "%.1f",u}')

# Temperatura: 'sensors' si esta; si no, la primera thermal_zone de tipo x86/cpu.
cpu_temp=""
if command -v sensors >/dev/null 2>&1; then
    cpu_temp=$(sensors 2>/dev/null | awk '/^(Tctl|Package id 0|Tdie|Core 0)/{gsub(/[+°C]/,"",$NF); print $NF; exit}')
fi
if [ -z "$cpu_temp" ] && [ -r /sys/class/thermal/thermal_zone0/temp ]; then
    tz=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
    [ -n "$tz" ] && cpu_temp=$(awk "BEGIN{v=$tz; if(v>1000) v=v/1000; printf \"%.1f\", v}")
fi

# ── Memoria ─────────────────────────────────────────────────────────────────
# /proc/meminfo da KiB. Convertimos a GB con dos decimales.

mem_total=$(awk '/^MemTotal/    {printf "%.2f", $2/1048576}' /proc/meminfo)
mem_libre=$(awk '/^MemAvailable/{printf "%.2f", $2/1048576}' /proc/meminfo)
mem_usado=$(awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} END{printf "%.2f",(t-a)/1048576}' /proc/meminfo)
swap_total=$(awk '/^SwapTotal/{printf "%.2f", $2/1048576}' /proc/meminfo)
swap_libre=$(awk '/^SwapFree/ {printf "%.2f", $2/1048576}' /proc/meminfo)

# ── Disco raíz ──────────────────────────────────────────────────────────────

disk_usado=$(df -h  / | awk 'NR==2 {print $3}')
disk_libre=$(df -h  / | awk 'NR==2 {print $4}')
disk_porcentaje=$(df / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
inodos_uso=$(df -i / 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')

# Todos los sistemas de ficheros reales (excluye tmpfs/devtmpfs/overlay).
discos_json=""
while read -r fs _ usado libre pct punto; do
    [ -z "$punto" ] && continue
    pct=${pct%\%}
    fs=$(echo "$fs" | sed 's/"/\\"/g'); punto=$(echo "$punto" | sed 's/"/\\"/g')
    [ -n "$discos_json" ] && discos_json="$discos_json,"
    discos_json="$discos_json{\"dispositivo\":\"$fs\",\"punto\":\"$punto\",\"usado\":\"$usado\",\"libre\":\"$libre\",\"porcentaje_uso\":${pct:-0}}"
done < <(df -hPx tmpfs -x devtmpfs -x overlay -x squashfs 2>/dev/null | tail -n +2)

# ── Sistema operativo ───────────────────────────────────────────────────────

if [ -r /etc/os-release ]; then
    os_name=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
else
    os_name=$(uname -s)
fi

kernel=$(uname -r)
uptime_horas=$(awk '{printf "%.1f", $1/3600}' /proc/uptime)

# ── Actualizaciones pendientes (Debian/Ubuntu) ──────────────────────────────
# apt-get -s upgrade simula sin tocar nada; cada "Inst " es un paquete
# pendiente. Si no hay apt-get o falla devolvemos 0.

actualizaciones=0
actualizaciones_seg=0
if command -v apt-get >/dev/null 2>&1; then
    apt_sim=$(apt-get -s upgrade 2>/dev/null)
    actualizaciones=$(echo "$apt_sim" | grep -c '^Inst' || true)
    # Las de seguridad llevan el repo *-security en la linea Inst.
    actualizaciones_seg=$(echo "$apt_sim" | grep '^Inst' | grep -ci 'security' || true)
elif command -v dnf >/dev/null 2>&1; then
    actualizaciones=$(dnf -q check-update 2>/dev/null | grep -c '^[a-zA-Z0-9]' || true)
    actualizaciones_seg=$(dnf -q --security check-update 2>/dev/null | grep -c '^[a-zA-Z0-9]' || true)
fi

# ── Recogida ampliada (cada bloque tolera fallo: no aborta el diagnostico) ────

# Ultimo arranque (para el informe). Vacio si 'uptime -s' no esta.
ultimo_arranque=$(uptime -s 2>/dev/null || echo "")

# Servicios criticos. cups = cola de impresion: SIEMPRE se reporta, nunca se toca.
# OJO: systemctl is-active devuelve exit!=0 para servicios no activos (imprime
# 'inactive' y sale con 3). Un 'cmd || echo desconocido' concatenaba ambos con
# un salto de linea DENTRO del string ("inactive\ndesconocido") y rompia el JSON
# (Invalid control character). Capturamos la salida tal cual y solo caemos a
# 'desconocido' si viene vacia.
servicios_json=""
for s in ssh cron cups systemd-journald NetworkManager; do
    estado=$(systemctl is-active "$s" 2>/dev/null)
    [ -z "$estado" ] && estado="desconocido"
    [ -n "$servicios_json" ] && servicios_json="$servicios_json,"
    servicios_json="$servicios_json{\"nombre\":\"$s\",\"estado\":\"$estado\"}"
done

# Unidades systemd en estado failed (array de nombres). Senal directa de averia.
servicios_fallidos_json=""
while read -r unidad; do
    [ -z "$unidad" ] && continue
    unidad=$(echo "$unidad" | sed 's/"/\\"/g')
    [ -n "$servicios_fallidos_json" ] && servicios_fallidos_json="$servicios_fallidos_json,"
    servicios_fallidos_json="$servicios_fallidos_json\"$unidad\""
done < <(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}')

# Top procesos por CPU (nombre/cpu/mem). comm no suele llevar espacios.
procesos_json=""
while read -r pcpu pmem pcomm; do
    [ -z "$pcomm" ] && continue
    pcpu=${pcpu:-0}; pmem=${pmem:-0}
    [ -n "$procesos_json" ] && procesos_json="$procesos_json,"
    procesos_json="$procesos_json{\"nombre\":\"$pcomm\",\"cpu\":$pcpu,\"mem\":$pmem}"
done < <(ps -eo %cpu,%mem,comm --sort=-%cpu 2>/dev/null | tail -n +2 | head -10)

# Top procesos por MEMORIA (complementa el de CPU: a veces el problema es RAM).
procesos_mem_json=""
while read -r pmem pcpu pcomm; do
    [ -z "$pcomm" ] && continue
    pmem=${pmem:-0}; pcpu=${pcpu:-0}
    [ -n "$procesos_mem_json" ] && procesos_mem_json="$procesos_mem_json,"
    procesos_mem_json="$procesos_mem_json{\"nombre\":\"$pcomm\",\"mem\":$pmem,\"cpu\":$pcpu}"
done < <(ps -eo %mem,%cpu,comm --sort=-%mem 2>/dev/null | tail -n +2 | head -10)

# Paquetes instalados (recuento). dpkg en Debian/Ubuntu, rpm en Fedora/RHEL.
paquetes_instalados=0
if command -v dpkg-query >/dev/null 2>&1; then
    paquetes_instalados=$(dpkg-query -f '.\n' -W 2>/dev/null | wc -l)
elif command -v rpm >/dev/null 2>&1; then
    paquetes_instalados=$(rpm -qa 2>/dev/null | wc -l)
fi

# Usuarios con sesion abierta (array de nombres unicos).
usuarios_json=""
while read -r u; do
    [ -z "$u" ] && continue
    [ -n "$usuarios_json" ] && usuarios_json="$usuarios_json,"
    usuarios_json="$usuarios_json\"$u\""
done < <(who 2>/dev/null | awk '{print $1}' | sort -u)

# GPU (modelo). lspci si esta disponible; vacio si no.
gpu_modelo=""
if command -v lspci >/dev/null 2>&1; then
    gpu_modelo=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | sed 's/^[^:]*: //; s/"/\\"/g')
fi

# Red: IP/gateway/DNS + puertos en escucha.
ip_local=$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | head -1)
gateway=$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}')

# Interfaces de red (nombre/mac/ip). Excluye loopback.
interfaces_json=""
while read -r _ iface rest; do
    iface=${iface%:}
    [ "$iface" = "lo" ] && continue
    [ -z "$iface" ] && continue
    mac=$(cat "/sys/class/net/$iface/address" 2>/dev/null | tr -d '\n')
    ip_if=$(ip -4 -o addr show dev "$iface" 2>/dev/null | awk '{print $4}' | head -1)
    [ -n "$interfaces_json" ] && interfaces_json="$interfaces_json,"
    interfaces_json="$interfaces_json{\"nombre\":\"$iface\",\"mac\":\"$mac\",\"ip\":\"$ip_if\"}"
done < <(ip -o link show 2>/dev/null | awk -F': ' '{print $1" "$2}')

# Conexiones TCP establecidas (recuento).
conexiones_estab=$(ss -tnH state established 2>/dev/null | wc -l)
dns_json=""
while read -r d; do
    [ -z "$d" ] && continue
    [ -n "$dns_json" ] && dns_json="$dns_json,"
    dns_json="$dns_json\"$d\""
done < <(grep -h '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}')
puertos_escucha=$(ss -tlnH 2>/dev/null | awk '{print $4}' | sed 's/.*://' \
                  | grep -E '^[0-9]+$' | sort -un | paste -sd, -)

# Seguridad: firewall (ufw/iptables).
firewall="false"
if command -v ufw >/dev/null 2>&1; then
    ufw status 2>/dev/null | grep -qi "Status: active" && firewall="true"
elif command -v iptables >/dev/null 2>&1; then
    # Si hay alguna regla mas alla de las cadenas por defecto, lo damos por activo.
    [ "$(iptables -S 2>/dev/null | grep -vc '^-P')" -gt 0 ] 2>/dev/null && firewall="true"
fi

# Login root por SSH (PermitRootLogin). 'true' si esta explicitamente permitido.
ssh_root_login="null"
if [ -r /etc/ssh/sshd_config ]; then
    prl=$(grep -iE '^\s*PermitRootLogin' /etc/ssh/sshd_config 2>/dev/null | tail -1 | awk '{print tolower($2)}')
    case "$prl" in
        yes|prohibit-password|without-password) ssh_root_login="true" ;;
        no) ssh_root_login="false" ;;
        *) ssh_root_login="null" ;;
    esac
fi

# MAC: AppArmor (Debian/Ubuntu) o SELinux (Fedora/RHEL). "" si ninguno.
mac_lsm=""
if command -v aa-status >/dev/null 2>&1 && aa-status --enabled 2>/dev/null; then
    mac_lsm="apparmor"
elif command -v getenforce >/dev/null 2>&1; then
    ge=$(getenforce 2>/dev/null)
    [ -n "$ge" ] && mac_lsm="selinux:$(echo "$ge" | tr 'A-Z' 'a-z')"
fi

# fail2ban activo y reinicio pendiente (tras updates de kernel/libc).
fail2ban="false"
[ "$(systemctl is-active fail2ban 2>/dev/null)" = "active" ] && fail2ban="true"
reinicio_requerido="false"
[ -f /var/run/reboot-required ] && reinicio_requerido="true"

# SMART de cada disco fisico (array). Requiere smartctl + permiso; [] si no.
disco_smart_json=""
if command -v smartctl >/dev/null 2>&1; then
    while read -r disk; do
        [ -z "$disk" ] && continue
        sm=$(smartctl -H "/dev/$disk" 2>/dev/null | grep -iE 'overall-health|SMART Health Status' \
             | awk -F: '{gsub(/^[ \t]+/,"",$2); print $2}')
        [ -z "$sm" ] && sm="desconocido"
        [ -n "$disco_smart_json" ] && disco_smart_json="$disco_smart_json,"
        disco_smart_json="$disco_smart_json{\"dispositivo\":\"$disk\",\"salud\":\"$sm\"}"
    done < <(lsblk -dn -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}')
fi

# Bateria (solo portatiles). null si no hay BAT*.
bateria_json="null"
bat_path=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
if [ -n "$bat_path" ]; then
    bnivel=$(cat "$bat_path/capacity" 2>/dev/null | tr -d '\n')
    bestado=$(cat "$bat_path/status" 2>/dev/null | tr -d '\n')
    bateria_json="{\"nivel\":${bnivel:-0},\"estado\":\"${bestado:-Desconocido}\"}"
fi

# Blindaje de arrays/cadenas vacias para que el JSON quede valido.
servicios_json=${servicios_json:-}
servicios_fallidos_json=${servicios_fallidos_json:-}
procesos_json=${procesos_json:-}
procesos_mem_json=${procesos_mem_json:-}
interfaces_json=${interfaces_json:-}
usuarios_json=${usuarios_json:-}
discos_json=${discos_json:-}
disco_smart_json=${disco_smart_json:-}
dns_json=${dns_json:-}
puertos_escucha=${puertos_escucha:-}

# ── Volcado JSON ────────────────────────────────────────────────────────────
# Se escribe manual para no depender de jq. Blindamos los campos numericos:
# si algun comando fallo y dejo la variable vacia, ponemos 0 para no romper el
# JSON con un valor ausente ("campo": ,).
cpu_cores=${cpu_cores:-0}
cpu_load=${cpu_load:-0}
cpu_load5=${cpu_load5:-0}
cpu_load15=${cpu_load15:-0}
cpu_uso=${cpu_uso:-null}
cpu_temp=${cpu_temp:-null}
mem_total=${mem_total:-0}
mem_libre=${mem_libre:-0}
mem_usado=${mem_usado:-0}
swap_total=${swap_total:-0}
swap_libre=${swap_libre:-0}
uptime_horas=${uptime_horas:-0}
disk_porcentaje=${disk_porcentaje:-0}
inodos_uso=${inodos_uso:-0}
actualizaciones=${actualizaciones:-0}
actualizaciones_seg=${actualizaciones_seg:-0}
paquetes_instalados=${paquetes_instalados:-0}
conexiones_estab=${conexiones_estab:-0}

cat > "$FILE" <<EOF
{
  "_meta": {
    "plataforma": "linux",
    "hostname": "$HOST",
    "version": "4.0"
  },
  "timestamp": "$(date -Iseconds)",
  "hostname": "$HOST",
  "os": "$os_name",
  "kernel": "$kernel",
  "uptime_horas": $uptime_horas,
  "sistema": {
    "nombre": "$os_name",
    "kernel": "$kernel",
    "uptime_horas": $uptime_horas,
    "ultimo_arranque": "$ultimo_arranque",
    "reinicio_requerido": $reinicio_requerido
  },
  "cpu": {
    "modelo": "$cpu_model",
    "cores": $cpu_cores,
    "carga_1min": $cpu_load,
    "carga_5min": $cpu_load5,
    "carga_15min": $cpu_load15,
    "uso_pct": $cpu_uso,
    "temperatura_c": $cpu_temp
  },
  "ram": {
    "total_gb": $mem_total,
    "libre_gb": $mem_libre,
    "usado_gb": $mem_usado,
    "swap_total_gb": $swap_total,
    "swap_libre_gb": $swap_libre
  },
  "disco": {
    "usado": "$disk_usado",
    "libre": "$disk_libre",
    "porcentaje_uso": $disk_porcentaje
  },
  "discos": [$discos_json],
  "inodos": {
    "porcentaje_uso": $inodos_uso
  },
  "disco_smart": [$disco_smart_json],
  "actualizaciones": {
    "pendientes": $actualizaciones,
    "seguridad": $actualizaciones_seg
  },
  "paquetes": {
    "instalados": $paquetes_instalados
  },
  "servicios_criticos": [$servicios_json],
  "servicios_fallidos": [$servicios_fallidos_json],
  "procesos_top": [$procesos_json],
  "procesos_top_mem": [$procesos_mem_json],
  "bateria": $bateria_json,
  "gpu": "$gpu_modelo",
  "usuarios_conectados": [$usuarios_json],
  "red": {
    "ip": "$ip_local",
    "gateway": "$gateway",
    "dns": [$dns_json],
    "interfaces": [$interfaces_json],
    "puertos_escucha": [$puertos_escucha],
    "conexiones_estab": $conexiones_estab
  },
  "seguridad": {
    "firewall": $firewall,
    "ssh_root_login": $ssh_root_login,
    "mac_lsm": "$mac_lsm",
    "fail2ban_activo": $fail2ban,
    "reinicio_requerido": $reinicio_requerido
  }
}
EOF

# Validacion: si el JSON salio malformado avisamos (no abortamos: el fichero
# local ya esta escrito y el tecnico puede revisarlo).
if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$FILE" >/dev/null 2>&1 || warn "El JSON generado parece invalido: $FILE"
fi

# ── Resumen legible en terminal ──────────────────────────────────────────────
echo ""
echo "  +-------------------- RESUMEN DEL DIAGNOSTICO --------------------+"
echo "   Equipo .......: $HOST"
echo "   Sistema ......: $os_name ($kernel)"
echo "   Uptime .......: ${uptime_horas} h"
echo "   CPU ..........: $cpu_model (${cpu_cores} cores, carga ${cpu_load}/${cpu_load5}/${cpu_load15}, uso ${cpu_uso}%, ${cpu_temp} C)"
echo "   RAM ..........: ${mem_libre} GB libres de ${mem_total} GB  ·  swap ${swap_libre}/${swap_total} GB"
echo "   Disco / .....: ${disk_libre} libres (${disk_porcentaje}% usado, inodos ${inodos_uso}%)"
[ -n "$gpu_modelo" ] && echo "   GPU ..........: $gpu_modelo"
[ -n "$ip_local" ] && echo "   Red ..........: IP ${ip_local} | GW ${gateway} | con.estab ${conexiones_estab} | puertos ${puertos_escucha:-(ninguno)}"
echo "   Firewall .....: $firewall  ·  fail2ban $fail2ban  ·  MAC ${mac_lsm:-(ninguno)}  ·  SSH root $ssh_root_login"
echo "   Updates ......: ${actualizaciones} pendientes (${actualizaciones_seg} de seguridad)"
[ "$reinicio_requerido" = "true" ] && echo "   [!] Reinicio requerido (actualización de kernel/libc pendiente de aplicar)"
echo "   Servicios ....: $(echo "$servicios_json" | grep -o '"nombre":"[^"]*","estado":"[^"]*"' | sed 's/"nombre":"//;s/","estado":"/=/;s/"//' | paste -sd' ' -)"
[ -n "$servicios_fallidos_json" ] && echo "   [!] Servicios FALLIDOS: $(echo "$servicios_fallidos_json" | sed 's/"//g')"
echo "   Paquetes .....: ${paquetes_instalados} instalados"
echo "   Top procesos (CPU):"
ps -eo %cpu,%mem,comm --sort=-%cpu 2>/dev/null | tail -n +2 | head -5 \
    | awk '{printf "     - %-20s cpu=%s%% mem=%s%%\n", $3, $1, $2}'
echo "   Top procesos (MEM):"
ps -eo %mem,%cpu,comm --sort=-%mem 2>/dev/null | tail -n +2 | head -5 \
    | awk '{printf "     - %-20s mem=%s%% cpu=%s%%\n", $3, $1, $2}'
echo "  +-----------------------------------------------------------------+"
echo ""

info "Diagnóstico guardado en:"
echo "    $FILE"

# ── Subida automática a WordPress (Fase 5) ──────────────────────────────────
# Variables de entorno (todas opcionales salvo email+token para activar):
#   RC_CLIENT_EMAIL  email del cliente (obligatorio para subir)
#   RC_FLEET_TOKEN   token Bearer del endpoint de flota (obligatorio para subir)
#   RC_FLEET_URL     endpoint REST (def: https://resolvecore.website/wp-json/rc/v1/fleet)
#   RC_TICKET_ID     id de ticket Mantis a asociar (opcional)
# Un fallo de red avisa pero NO rompe el script: el JSON local ya está a salvo.

RC_CLIENT_EMAIL="${RC_CLIENT_EMAIL:-}"
RC_FLEET_TOKEN="${RC_FLEET_TOKEN:-}"
RC_FLEET_URL="${RC_FLEET_URL:-https://resolvecore.website/wp-json/rc/v1/fleet}"
RC_TICKET_ID="${RC_TICKET_ID:-}"

if [ -n "$RC_CLIENT_EMAIL" ] && [ -n "$RC_FLEET_TOKEN" ]; then
    if ! command -v curl >/dev/null 2>&1; then
        warn "curl no disponible: no se puede subir el diagnóstico (JSON local en $FILE)."
    else
        info "Subiendo diagnóstico a $RC_FLEET_URL ..."
        # Envolvemos el JSON del diagnóstico en el sobre que espera el endpoint.
        # El fichero ya es un objeto JSON válido, así que se incrusta tal cual.
        # RC_TICKET_ID solo se incrusta si es un entero: si trae basura (p. ej.
        # '}, "x": {') rompería o inyectaría campos en el JSON enviado al endpoint.
        ticket_field=""
        if [[ "$RC_TICKET_ID" =~ ^[0-9]+$ ]]; then
            ticket_field="\"ticket_id\": ${RC_TICKET_ID},"
        fi
        # Escapamos el email para JSON (backslash y comilla doble) y le quitamos
        # saltos de línea/CR, para que un valor con comillas no rompa el objeto.
        email_esc=$(printf '%s' "$RC_CLIENT_EMAIL" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')
        payload="{\"client_email\": \"${email_esc}\", ${ticket_field} \"diagnostico\": $(cat "$FILE")}"

        http_code=$(curl -sS -o /tmp/rc_fleet_resp.$$ -w '%{http_code}' \
            -X POST "$RC_FLEET_URL" \
            -H "Authorization: Bearer ${RC_FLEET_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "$payload" --max-time 15 || echo "000")

        if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
            info "Subida OK: $(cat /tmp/rc_fleet_resp.$$)"
            # El score 0-100 lo calcula el servidor (rc_fleet_score() en rc-fleet)
            # y viene en la respuesta; aquí solo se extrae y se muestra.
            score=$(sed -n 's/.*"score":[[:space:]]*\([0-9][0-9]*\).*/\1/p' /tmp/rc_fleet_resp.$$ | head -1)
            if [ -n "$score" ]; then
                info "Puntuación de salud (servidor): ${score}/100"
            fi
        else
            warn "Fallo al subir (HTTP $http_code): $(cat /tmp/rc_fleet_resp.$$ 2>/dev/null)"
            warn "El JSON local sigue disponible en: $FILE"
        fi
        rm -f /tmp/rc_fleet_resp.$$
    fi
else
    info "(Subida automática omitida: exporta RC_CLIENT_EMAIL y RC_FLEET_TOKEN para activarla.)"
fi
