#!/usr/bin/env bash
# ResolveCore — Setup del entorno del técnico (Linux)
#
# Instala todas las dependencias para ejecutar los scripts de diagnóstico,
# optimización y análisis de vulnerabilidades. NO instala el stack servidor
# (WordPress / MantisBT / Nginx / MariaDB — eso es scripts/server/linux/post-install.sh).
#
# Uso:
#   bash setup-tecnico-linux.sh
#   bash setup-tecnico-linux.sh --help
#
# Requiere: Ubuntu/Debian, Fedora/RHEL, Arch o openSUSE. Conexión a internet.

set -euo pipefail

# ── Ayuda ────────────────────────────────────────────────────────────────────
case "${1:-}" in
    --help|-h)
        cat <<'EOF'
NAME
    setup-tecnico-linux.sh — Setup del entorno del técnico ResolveCore

SYNOPSIS
    bash setup-tecnico-linux.sh [--help]

DESCRIPTION
    Instala en la máquina del técnico todo lo necesario para ejecutar:
      · diagnostico.sh / optimizacion.sh (Linux)
      · diagnostico.sh / optimizacion.sh (Android vía ADB)
      · buscar_vulnerabilidades.py
      · ResolveCore.sh (menú)

    Componentes instalados:
      · Herramientas base:  git, curl, wget, unzip, jq, bc
      · Diagnóstico:        smartmontools, lm-sensors, pciutils, iproute2,
                            iputils-ping, ufw
      · Android:            adb (Android Debug Bridge)
      · Vulnerabilidades:   python3
      · Acceso remoto:      AnyDesk

REQUISITOS
    - Ubuntu/Debian, Fedora/RHEL/CentOS, Arch/Manjaro o openSUSE.
    - sudo o root.
    - Conexión a internet.

EXIT CODES
    0   Setup completado.
    1   Error fatal (gestor de paquetes no soportado, fallo de instalación).
EOF
        exit 0 ;;
esac

# ── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${CYAN}[→]${NC} $1"; }
warn() { echo -e "${YELLOW}[⚠]${NC} $1"; }
die()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ── Detección de gestor de paquetes ─────────────────────────────────────────
PM=""
if   command -v apt-get  &>/dev/null; then PM="apt"
elif command -v dnf      &>/dev/null; then PM="dnf"
elif command -v yum      &>/dev/null; then PM="yum"
elif command -v pacman   &>/dev/null; then PM="pacman"
elif command -v zypper   &>/dev/null; then PM="zypper"
else die "Gestor de paquetes no soportado. Instala manualmente las dependencias."; fi

install_pkg() {
    case "$PM" in
        apt)    sudo apt-get install -y -qq "$@" ;;
        dnf)    sudo dnf install -y -q   "$@" ;;
        yum)    sudo yum install -y -q   "$@" ;;
        pacman) sudo pacman -S --noconfirm --needed -q "$@" ;;
        zypper) sudo zypper install -y   "$@" ;;
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

# Nombre del paquete por gestor: apt:dnf:pacman:zypper
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
echo -e "${BOLD}"
cat <<'BANNER'
  ____                 _       ____
 |  _ \ ___  ___  ___ | |_   / ___|___  _ __ ___
 | |_) / _ \/ __|/ _ \| \ \ / /  / _ \| '__/ _ \
 |  _ <  __/\__ \ (_) | |\ V /  | (_) | | |  __/
 |_| \_\___||___/\___/|_| \_/    \___/|_|  \___|

  Setup del Técnico — Linux
BANNER
echo -e "${NC}"
echo -e "${CYAN}Gestor detectado:${NC} $PM"
echo ""
warn "Este script instala paquetes en el sistema. Solo para la máquina del técnico."
echo ""
read -rp "¿Continuar? [s/N] " _confirm
[[ "$_confirm" =~ ^[sS]$ ]] || { echo "Cancelado."; exit 0; }
echo ""

# ── 1. Actualizar cache ──────────────────────────────────────────────────────
info "Actualizando caché de paquetes..."
update_cache
ok "Caché actualizado"

# ── 2. Herramientas base ─────────────────────────────────────────────────────
info "Instalando herramientas base..."
install_pkg git curl wget unzip \
    "$(pkg jq            jq            jq            jq)" \
    "$(pkg bc            bc            bc            bc)"
ok "Herramientas base instaladas"

# ── 3. Dependencias de diagnóstico ───────────────────────────────────────────
info "Instalando dependencias de diagnóstico..."
install_pkg \
    "$(pkg smartmontools  smartmontools  smartmontools  smartmontools)" \
    "$(pkg lm-sensors     lm_sensors     lm_sensors     sensors)"      \
    "$(pkg pciutils       pciutils       pciutils       pciutils)"      \
    "$(pkg iproute2       iproute        iproute2       iproute2)"      \
    "$(pkg iputils-ping   iputils        iputils        iputils)"       \
    "$(pkg ufw            ufw            ufw            ufw)"           \
    "$(pkg nmap           nmap           nmap           nmap)"

# sensors-detect en modo automático para registrar los sensores disponibles
if command -v sensors-detect &>/dev/null; then
    info "Configurando lm-sensors..."
    sudo sensors-detect --auto >/dev/null 2>&1 || warn "sensors-detect terminó con avisos (normal en VMs)"
fi
ok "Dependencias de diagnóstico instaladas"

# ── 4. Python 3 (buscar_vulnerabilidades.py) ─────────────────────────────────
info "Verificando Python 3..."
if ! command -v python3 &>/dev/null; then
    install_pkg "$(pkg python3 python3 python python3)"
fi
_pyver=$(python3 --version 2>&1 | grep -oP '\d+\.\d+' | head -1 || echo "?")
ok "Python $_pyver instalado"

# ── 5. ADB (diagnóstico Android) ─────────────────────────────────────────────
info "Instalando ADB (Android Debug Bridge)..."
_adb_pkg="$(pkg android-tools-adb android-tools android-tools android-tools)"
if install_pkg "$_adb_pkg" 2>/dev/null; then
    ok "ADB instalado"
else
    warn "ADB no disponible vía gestor. Instalando desde SDK Platform Tools..."
    _adb_zip="/tmp/platform-tools-latest-linux.zip"
    wget -q "https://dl.google.com/android/repository/platform-tools-latest-linux.zip" \
        -O "$_adb_zip" || { warn "No se pudo descargar ADB. Instala manualmente."; }
    if [[ -f "$_adb_zip" ]]; then
        sudo unzip -q -o "$_adb_zip" -d /opt/
        sudo ln -sf /opt/platform-tools/adb /usr/local/bin/adb
        rm -f "$_adb_zip"
        ok "ADB instalado en /opt/platform-tools/"
    fi
fi

# Reglas udev para ADB sin root
# `ATTR{idVendor}=="*"` es sintaxis inválida en udev (los patrones glob solo
# funcionan en KERNEL=, NAME=, SYMLINK=, no en ATTR{}). Se usa la lista oficial
# de vendor IDs Android publicada por Google.
if [[ -d /etc/udev/rules.d ]] && [[ ! -f /etc/udev/rules.d/51-android.rules ]]; then
    info "Configurando reglas udev para ADB..."
    # Vendor IDs Android (lista no exhaustiva — los más comunes).
    # Fuente: https://developer.android.com/studio/run/device#VendorIds
    _android_vendors=(
        "0bb4"  # HTC / Google Pixel
        "18d1"  # Google
        "04e8"  # Samsung
        "22b8"  # Motorola
        "12d1"  # Huawei
        "2717"  # Xiaomi
        "05c6"  # Qualcomm (genérico, OnePlus / muchos chinos)
        "0fce"  # Sony
        "1004"  # LG
        "2a70"  # OnePlus
        "2b4c"  # Realme
        "19d2"  # ZTE
        "0e8d"  # MediaTek (genérico)
    )
    {
        echo '# ResolveCore — reglas ADB Android (generadas por setup-tecnico-linux.sh)'
        for vid in "${_android_vendors[@]}"; do
            printf 'SUBSYSTEM=="usb", ATTR{idVendor}=="%s", MODE="0666", GROUP="plugdev"\n' "$vid"
        done
    } | sudo tee /etc/udev/rules.d/51-android.rules >/dev/null
    sudo udevadm control --reload-rules 2>/dev/null || true
    sudo udevadm trigger 2>/dev/null || true
    sudo usermod -aG plugdev "$USER" 2>/dev/null || true
    ok "Reglas udev ADB configuradas (${#_android_vendors[@]} vendors — reinicia sesión)"
fi

# ── 6. AnyDesk ───────────────────────────────────────────────────────────────
info "Instalando AnyDesk..."
if command -v anydesk &>/dev/null; then
    ok "AnyDesk ya instalado"
elif [[ "$PM" == "apt" ]]; then
    wget -qO - https://keys.anydesk.com/repos/DEB-GPG-KEY \
        | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/anydesk.gpg 2>/dev/null
    echo "deb http://deb.anydesk.com/ all main" \
        | sudo tee /etc/apt/sources.list.d/anydesk-stable.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq anydesk && ok "AnyDesk instalado" \
        || warn "AnyDesk no disponible para esta arquitectura. Descarga manual: https://anydesk.com/downloads"
elif [[ "$PM" == "dnf" || "$PM" == "yum" ]]; then
    sudo tee /etc/yum.repos.d/anydesk.repo >/dev/null <<'REPO'
[anydesk]
name=AnyDesk
baseurl=http://rpm.anydesk.com/centos/$releasever/$basearch/
gpgcheck=1
gpgkey=https://keys.anydesk.com/repos/RPM-GPG-KEY
REPO
    sudo "$PM" install -y anydesk && ok "AnyDesk instalado" \
        || warn "AnyDesk no disponible. Descarga manual: https://anydesk.com/downloads"
else
    warn "AnyDesk: instala manualmente desde https://anydesk.com/downloads"
fi

# ── 7. Scripts ResolveCore ────────────────────────────────────────────────────
SCRIPTS_DIR="$HOME/.resolvecore"
info "Instalando scripts ResolveCore en $SCRIPTS_DIR..."

LOCAL_REPO=$(cd "$(dirname "$0")/../.." && pwd)

if [[ -d "$LOCAL_REPO/scripts" ]] && [[ "$LOCAL_REPO" != "$SCRIPTS_DIR" ]]; then
    mkdir -p "$SCRIPTS_DIR"
    cp -r "$LOCAL_REPO/"* "$SCRIPTS_DIR/" 2>/dev/null || true
    chmod +x "$SCRIPTS_DIR"/scripts/linux/*.sh \
             "$SCRIPTS_DIR"/scripts/android/*.sh \
             "$SCRIPTS_DIR"/scripts/common/*.py 2>/dev/null || true
    ok "Scripts copiados automáticamente desde $LOCAL_REPO a $SCRIPTS_DIR"
elif git ls-remote "https://github.com/Haplee/ResolveCore.git" &>/dev/null; then
    if [[ -d "$SCRIPTS_DIR/.git" ]]; then
        git -C "$SCRIPTS_DIR" pull --quiet
        ok "Scripts actualizados desde GitHub"
    else
        git clone --depth=1 --quiet "https://github.com/Haplee/ResolveCore.git" "$SCRIPTS_DIR"
        ok "Scripts clonados en $SCRIPTS_DIR"
    fi
    chmod +x "$SCRIPTS_DIR"/scripts/linux/*.sh \
             "$SCRIPTS_DIR"/scripts/android/*.sh \
             "$SCRIPTS_DIR"/scripts/common/*.py 2>/dev/null || true
else
    warn "No se encontró copia local y no hay acceso a GitHub. Copia manualmente a $SCRIPTS_DIR/"
fi

# ── 8. Aliases en ~/.bashrc ───────────────────────────────────────────────────
info "Configurando aliases..."
_ALIAS_BLOCK="# ResolveCore aliases"
if ! grep -q "$_ALIAS_BLOCK" "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" <<ALIASES

$_ALIAS_BLOCK
alias resolvecore='bash ${SCRIPTS_DIR}/scripts/linux/ResolveCore.sh'
alias rc-diag='bash ${SCRIPTS_DIR}/scripts/linux/diagnostico.sh'
alias rc-opt='bash ${SCRIPTS_DIR}/scripts/linux/optimizacion.sh'
alias rc-vuln='python3 ${SCRIPTS_DIR}/scripts/common/buscar_vulnerabilidades.py'
ALIASES
    ok "Aliases añadidos a ~/.bashrc"
else
    ok "Aliases ya presentes en ~/.bashrc"
fi

# ── 9. Verificación final ─────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}══════════════════════════════════════════"
echo "  Verificación del entorno"
echo -e "══════════════════════════════════════════${NC}"
echo ""

_ok=0; _fail=0
check() {
    local label="$1" cmd="$2"
    if command -v "$cmd" &>/dev/null; then
        local ver
        ver=$(${3:-$cmd --version} 2>&1 | head -1 | grep -oP '[\d]+\.[\d.]+' | head -1 || echo "ok")
        echo -e "  ${GREEN}✓${NC} $label ($ver)"
        _ok=$((_ok + 1))
    else
        echo -e "  ${RED}✗${NC} $label — NO ENCONTRADO"
        _fail=$((_fail + 1))
    fi
}

check "jq"            jq
check "git"           git
check "python3"       python3
check "smartctl"      smartctl   "smartctl --version"
check "sensors"       sensors    "sensors --version"
check "lspci"         lspci      "lspci --version"
check "adb"           adb        "adb --version"
check "nmap"          nmap       "nmap --version"
check "anydesk"       anydesk    "anydesk --version"
check "curl"          curl
check "wget"          wget

echo ""
echo -e "  Resultado: ${GREEN}$_ok ok${NC} / ${RED}$_fail fallo(s)${NC}"
echo ""

if [[ $_fail -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}  ✓ Entorno listo. Ejecuta: source ~/.bashrc${NC}"
    echo -e "  Luego: ${CYAN}resolvecore${NC}"
else
    warn "Algunos componentes no se instalaron. Revisa los errores arriba."
fi
echo ""
