#!/usr/bin/env bash
# =============================================================================
#  ResolveCore — Optimización macOS (DEMO / FASE FUTURA)
#  Versión: 0.1.0-demo
#
#  ESTADO: Stub. Implementación completa pendiente.
#  La versión 3.0.0 anterior aplicaba cambios destructivos sin --confirm
#  (mdutil off, rm -rf ~/Library/Caches, networksetup -setdnsservers, etc.).
#  Se reduce a stub hasta diseñar el flujo de undo y los niveles correctamente.
#
#  Niveles previstos: ligero | estandar | rendimiento | extreme
#  Opciones previstas: --dry-run, --confirm, --undo
# =============================================================================

set -euo pipefail

SCRIPT_VERSION="0.1.0-demo"
NIVEL="estandar"
DRY_RUN=false

usage() {
    cat <<EOF
Uso: sudo $0 [opciones] [nivel]

Niveles: ligero | estandar | rendimiento | extreme  (default: estandar)
Opciones (reservadas):
  --dry-run    Simula sin aplicar
  --confirm    Confirma acciones destructivas
  --undo       Deshace cambios
  -h, --help   Esta ayuda

ESTADO: STUB. Sin acciones reales en esta versión.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --confirm) shift ;;
        --undo)    shift ;;
        -h|--help) usage; exit 0 ;;
        ligero|estandar|rendimiento|extreme) NIVEL="$1"; shift ;;
        *) shift ;;
    esac
done

YELLOW='\033[1;33m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'; NC='\033[0m'

if [[ "${OSTYPE:-}" != darwin* ]]; then
    echo -e "  ${YELLOW}[!] No se detecta macOS. Stub continúa de todos modos.${NC}"
fi

cat <<BANNER

${CYAN}  ==============================================================
  ResolveCore — Optimización macOS (DEMO STUB) v${SCRIPT_VERSION}
  Nivel: ${NIVEL}   DryRun: ${DRY_RUN}
  $(date '+%Y-%m-%d %H:%M:%S')
  ==============================================================${NC}

  ${YELLOW}Este script es un STUB. No aplica cambios reales.${NC}
  ${YELLOW}Implementación completa pendiente para fase futura del TFG.${NC}

  Plan previsto por nivel:
    ligero       — limpieza ~/Library/Caches con confirmación
    estandar     — anterior + revisión de LaunchAgents
    rendimiento  — anterior + ajustes de DNS y energía
    extreme      — anterior + recomendaciones avanzadas
BANNER

echo ""
echo -e "  ${GREEN}[OK] Stub ejecutado. Sin efectos en el sistema.${NC}"
echo ""
exit 0
