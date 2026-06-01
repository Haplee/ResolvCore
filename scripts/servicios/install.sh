#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Bootstrap de los servicios adicionales en Linux.
#
# Instala las dependencias que necesitan la congelación y la clonación antes
# de poder usarlas:
#   - btrfs-progs, snapper  (congelación BTRFS)
#   - jq                    (clonación + parseo de JSON)
#   - curl                  (integración con MantisBT)
#
# Uso:
#   curl -fsSL https://resolvecore.website/install.sh | sudo bash   # remoto
#   bash scripts/servicios/install.sh                               # local
#
# Exit codes: 0 OK · 1 error · 2 dependencia crítica no instalable.
#
# Probado en:  Ubuntu 22.04 / 24.04, Debian 12.
#
# Autor:   Francisco Vidal Mateo (GitHub: Haplee)
# Versión: 2.0
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
step() { echo -e "${CYAN}[$1]${NC} $2"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC}  $1"; }
fail() { echo -e "${RED}[X]${NC}  $1" >&2; exit 1; }

echo ""
echo -e "  ${CYAN}=======================================================${NC}"
echo -e "   ResolveCore - Instalacion de servicios adicionales"
echo -e "  ${CYAN}=======================================================${NC}"
echo ""

# Detectar gestor de paquetes
PKG_MGR=""
if command -v apt-get &>/dev/null; then PKG_MGR="apt"
elif command -v dnf &>/dev/null;   then PKG_MGR="dnf"
elif command -v pacman &>/dev/null; then PKG_MGR="pacman"
elif command -v brew &>/dev/null;   then PKG_MGR="brew"
fi

pkg_install() {
    case "$PKG_MGR" in
        apt)    sudo apt-get install -y -qq "$@" 2>/dev/null ;;
        dnf)    sudo dnf install -y -q "$@" 2>/dev/null ;;
        pacman) sudo pacman -Sy --noconfirm "$@" 2>/dev/null ;;
        brew)   brew install "$@" 2>/dev/null ;;
        *)      warn "Gestor de paquetes no detectado. Instala manualmente: $*"; return 1 ;;
    esac
}

# ── 1. Actualizar índice de paquetes ─────────────────────────────────────
step 1 "Actualizando indice de paquetes..."
case "$PKG_MGR" in
    apt) sudo apt-get update -qq 2>/dev/null && ok "apt update" ;;
    dnf) sudo dnf check-update -q 2>/dev/null; ok "dnf check-update" ;;
    *)   ok "Skipped (no apt/dnf)" ;;
esac

# ── 2. jq ────────────────────────────────────────────────────────────────
step 2 "Verificando jq..."
if ! command -v jq &>/dev/null; then
    step 2 "Instalando jq..."
    pkg_install jq
    command -v jq &>/dev/null && ok "jq instalado" || fail "No se pudo instalar jq"
else
    ok "jq ya disponible ($(jq --version))"
fi

# ── 3. curl ──────────────────────────────────────────────────────────────
step 3 "Verificando curl..."
if ! command -v curl &>/dev/null; then
    step 3 "Instalando curl..."
    pkg_install curl
    command -v curl &>/dev/null && ok "curl instalado" || warn "curl no disponible — integracion MantisBT desactivada"
else
    ok "curl ya disponible"
fi

# ── 4. btrfs-progs ───────────────────────────────────────────────────────
step 4 "Verificando btrfs-progs (congelacion)..."
if ! command -v btrfs &>/dev/null; then
    step 4 "Instalando btrfs-progs..."
    pkg_install btrfs-progs
    command -v btrfs &>/dev/null && ok "btrfs-progs instalado" \
        || warn "btrfs-progs no disponible — congelacion solo funciona en sistemas BTRFS"
else
    ok "btrfs ya disponible"
fi

# ── 5. snapper ───────────────────────────────────────────────────────────
step 5 "Verificando snapper..."
if ! command -v snapper &>/dev/null; then
    step 5 "Instalando snapper..."
    pkg_install snapper
    command -v snapper &>/dev/null && ok "snapper instalado" \
        || warn "snapper no disponible — congelacion no operativa"
else
    ok "snapper ya disponible ($(snapper --version 2>/dev/null | head -1))"
fi

# ── 6. Verificar filesystem raíz ─────────────────────────────────────────
step 6 "Verificando filesystem raiz..."
ROOT_FS=$(findmnt -n -o FSTYPE / 2>/dev/null || echo "desconocido")
if [[ "$ROOT_FS" == "btrfs" ]]; then
    ok "Filesystem raiz: BTRFS — congelacion totalmente operativa"
else
    warn "Filesystem raiz: $ROOT_FS (no BTRFS)"
    warn "Congelacion requiere BTRFS. Reinstala Ubuntu con BTRFS o usa una particion BTRFS separada."
fi

# ── Resumen ──────────────────────────────────────────────────────────────
echo ""
echo -e "  ${CYAN}=======================================================${NC}"
echo -e "   Instalacion completada"
echo -e "  ${CYAN}=======================================================${NC}"
echo ""
echo -e "  Ejecuta el menu de tecnicos:"
echo -e "    ${GREEN}bash scripts/linux/ResolveCore.sh${NC}"
echo -e "  O directamente los servicios:"
echo -e "    ${GREEN}bash scripts/servicios/congelacion/congelacion-linux.sh --action status${NC}"
echo ""
exit 0
