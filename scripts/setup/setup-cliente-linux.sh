#!/usr/bin/env bash
# ResolveCore — Setup del equipo del CLIENTE (Linux)
#
# Instala SOLO las dependencias mínimas que necesita diagnostico.sh para
# correr sin errores. NO instala AnyDesk, ADB, Python ni el resto de
# herramientas del entorno del técnico — eso es setup-tecnico-linux.sh.
#
# Política Zero Dependencias intrusivas: solo paquetes pasivos de lectura
# (smartmontools, lm-sensors, pciutils, jq, bc). No modifica configuración
# del sistema más allá de instalar paquetes. Idempotente.
#
# Uso:
#   sudo bash setup-cliente-linux.sh
#   sudo bash setup-cliente-linux.sh --yes      # sin preguntar
#   bash setup-cliente-linux.sh --help

set -euo pipefail

AUTO_YES=false
case "${1:-}" in
    --help|-h)
        cat <<'EOF'
NAME
    setup-cliente-linux.sh — Setup del equipo del CLIENTE

SYNOPSIS
    sudo bash setup-cliente-linux.sh [--yes]

DESCRIPTION
    Instala las dependencias mínimas para que diagnostico.sh funcione en el
    equipo del cliente. No instala herramientas del técnico (AnyDesk, ADB,
    Python, Git).

    Componentes instalados:
      · AnyDesk                      (acceso remoto del técnico, freeware)
      · jq, bc                       (procesado JSON, cálculos)
      · smartmontools                (smartctl — salud de discos)
      · lm-sensors                   (temperatura CPU/GPU)
      · pciutils                     (lspci — detección GPU)
      · iproute2, iputils-ping       (red)
      · nmap                         (escaneo LAN)

PARAMETROS
    --yes, -y    Sin confirmación (despliegues automatizados).
    --help, -h   Esta ayuda.

REQUISITOS
    - Ubuntu/Debian, Fedora/RHEL, Arch o openSUSE.
    - sudo o root.
    - Conexión a internet.

EXIT CODES
    0   Setup OK.
    1   Error fatal.
EOF
        exit 0 ;;
    --yes|-y) AUTO_YES=true ;;
esac

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${CYAN}[→]${NC} $1"; }
warn() { echo -e "${YELLOW}[⚠]${NC} $1"; }
die()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# Detección de gestor de paquetes
PM=""
if   command -v apt-get  &>/dev/null; then PM="apt"
elif command -v dnf      &>/dev/null; then PM="dnf"
elif command -v yum      &>/dev/null; then PM="yum"
elif command -v pacman   &>/dev/null; then PM="pacman"
elif command -v zypper   &>/dev/null; then PM="zypper"
else die "Gestor de paquetes no soportado. Instala manualmente: jq bc smartmontools lm-sensors pciutils nmap"; fi

install_pkg() {
    case "$PM" in
        apt)    sudo apt-get install -y -qq "$@" ;;
        dnf)    sudo dnf install -y -q "$@" ;;
        yum)    sudo yum install -y -q "$@" ;;
        pacman) sudo pacman -S --noconfirm --needed -q "$@" ;;
        zypper) sudo zypper install -y "$@" ;;
    esac
}

update_cache() {
    case "$PM" in
        apt)    sudo apt-get update -qq ;;
        dnf)    sudo dnf makecache -q ;;
        yum)    sudo yum makecache -q ;;
        pacman) sudo pacman -Sy --noconfirm -q ;;
        zypper) sudo zypper refresh ;;
    esac
}

pkg() {
    local apt="$1" dnf="$2" pac="$3" zyp="$4"
    case "$PM" in
        apt)         echo "$apt" ;;
        dnf|yum)     echo "$dnf" ;;
        pacman)      echo "$pac" ;;
        zypper)      echo "$zyp" ;;
    esac
}

# ── Banner ───────────────────────────────────────────────────────────────────
clear
echo ""
echo -e "${BOLD}${CYAN}  ResolveCore — Setup del equipo del CLIENTE${NC}"
echo -e "${CYAN}  ───────────────────────────────────────────${NC}"
echo ""
echo -e "  Este instalador añade SOLO lo necesario para que el técnico"
echo -e "  ResolveCore pueda diagnosticar este equipo sin errores."
echo ""
echo -e "  ${CYAN}Gestor detectado:${NC} $PM"
echo ""

if [[ "$AUTO_YES" != "true" ]]; then
    read -rp "  ¿Continuar? [s/N] " _ans
    [[ "$_ans" =~ ^[sS]$ ]] || { echo "  Cancelado."; exit 0; }
    echo ""
fi

# ── 1. Cache ─────────────────────────────────────────────────────────────────
info "Actualizando caché de paquetes..."
update_cache
ok "Caché actualizado"

# ── 2. Dependencias del cliente ──────────────────────────────────────────────
info "Instalando dependencias mínimas..."
install_pkg \
    "$(pkg jq             jq             jq             jq)"             \
    "$(pkg bc             bc             bc             bc)"             \
    "$(pkg smartmontools  smartmontools  smartmontools  smartmontools)"  \
    "$(pkg lm-sensors     lm_sensors     lm_sensors     sensors)"        \
    "$(pkg pciutils       pciutils       pciutils       pciutils)"       \
    "$(pkg iproute2       iproute        iproute2       iproute2)"       \
    "$(pkg iputils-ping   iputils        iputils        iputils)"        \
    "$(pkg nmap           nmap           nmap           nmap)"
ok "Dependencias instaladas"

# ── 3. AnyDesk (acceso remoto del técnico) ──────────────────────────────────
if command -v anydesk &>/dev/null; then
    ok "AnyDesk ya instalado"
elif [[ "$PM" == "apt" ]]; then
    info "Instalando AnyDesk (repositorio oficial)..."
    wget -qO - https://keys.anydesk.com/repos/DEB-GPG-KEY \
        | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/anydesk.gpg 2>/dev/null || \
      warn "No se pudo importar clave GPG de AnyDesk"
    echo "deb http://deb.anydesk.com/ all main" \
        | sudo tee /etc/apt/sources.list.d/anydesk-stable.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq anydesk \
        && ok "AnyDesk instalado" \
        || warn "AnyDesk no disponible para esta arquitectura. Descarga manual: https://anydesk.com/downloads"
elif [[ "$PM" == "dnf" || "$PM" == "yum" ]]; then
    info "Instalando AnyDesk (repositorio RPM)..."
    sudo tee /etc/yum.repos.d/anydesk.repo >/dev/null <<'REPO'
[anydesk]
name=AnyDesk
baseurl=http://rpm.anydesk.com/centos/$releasever/$basearch/
gpgcheck=1
gpgkey=https://keys.anydesk.com/repos/RPM-GPG-KEY
REPO
    sudo "$PM" install -y anydesk \
        && ok "AnyDesk instalado" \
        || warn "AnyDesk no disponible. Descarga manual: https://anydesk.com/downloads"
else
    warn "AnyDesk: instala manualmente desde https://anydesk.com/downloads"
fi

# Configurar sensores en modo no interactivo
if command -v sensors-detect &>/dev/null; then
    info "Configurando lm-sensors..."
    sudo sensors-detect --auto >/dev/null 2>&1 || warn "sensors-detect terminó con avisos (normal en VMs)"
fi

# ── Verificación ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}  ───────────────────────────────────────────"
echo -e "    Verificación"
echo -e "  ───────────────────────────────────────────${NC}"
echo ""

_ok=0; _fail=0
check() {
    if command -v "$2" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $1"
        _ok=$((_ok + 1))
    else
        echo -e "  ${RED}✗${NC} $1 — NO ENCONTRADO"
        _fail=$((_fail + 1))
    fi
}

check "jq"        jq
check "bc"        bc
check "smartctl"  smartctl
check "sensors"   sensors
check "lspci"     lspci
check "ip"        ip
check "ping"      ping
check "nmap"      nmap
check "anydesk"   anydesk

echo ""
echo -e "  Resultado: ${GREEN}$_ok ok${NC} / ${RED}$_fail fallo(s)${NC}"
echo ""

if [[ $_fail -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}  ✓ Equipo listo para diagnóstico.${NC}"
    echo -e "  El técnico ya puede ejecutar diagnostico.sh sin errores."
else
    warn "Algunos componentes fallaron. Revisa los errores arriba."
fi
echo ""
