#!/usr/bin/env bash
# =============================================================================
#  ResolveCore — Diagnóstico macOS (DEMO / FASE FUTURA)
#  Versión: 0.1.0-demo
#
#  ESTADO: Stub. La implementación completa está prevista para una fase
#  posterior del TFG. Este archivo conserva la interfaz CLI (argumentos,
#  formato de salida JSON) para que un técnico pueda probarlo en macOS sin
#  depender de la lógica final.
#
#  Para diagnóstico real de macOS hoy: usar 'system_profiler -json SPHardwareDataType'
#  manualmente o ejecutar el script Linux vía contenedor.
#
#  Modos previstos (no implementados):
#    1. Local en el Mac:   bash diagnostico.sh
#    2. Remoto vía SSH:    bash diagnostico.sh --host IP --user usuario
# =============================================================================

set -euo pipefail

SCRIPT_VERSION="0.1.0-demo"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../diagnosticos"

MODE="local"
SSH_HOST=""
SSH_USER=""
SSH_PORT="22"

usage() {
    cat <<EOF
Uso: $0 [opciones]

Opciones (interfaz reservada para implementación futura):
  --host <ip>     Modo remoto vía SSH
  --user <name>   Usuario SSH (no root, macOS bloquea root login)
  --port <n>      Puerto SSH (default: 22)
  --output <dir>  Directorio salida JSON
  --local         Forzar modo local (default)
  -h, --help      Esta ayuda
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)   MODE="remote"; SSH_HOST="${2:-}"; shift 2 ;;
        --user)   SSH_USER="${2:-}"; shift 2 ;;
        --port)   SSH_PORT="${2:-22}"; shift 2 ;;
        --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
        --local)  MODE="local"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) shift ;;
    esac
done

CYAN='\033[0;36m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'

cat <<BANNER

${CYAN}  ┌─────────────────────────────────────────────────────────────────┐
  │   ResolveCore — Diagnóstico macOS (DEMO STUB) — v${SCRIPT_VERSION}       │
  └─────────────────────────────────────────────────────────────────┘${NC}

  ${YELLOW}Este script es un STUB. Implementación pendiente para fase futura.${NC}

  Modo:   ${MODE}
  Salida: ${OUTPUT_DIR}

BANNER

# Detección mínima sólo en local — no rompe en otros SO
if [[ "$MODE" == "local" && "${OSTYPE:-}" != darwin* ]]; then
    echo -e "  ${YELLOW}[!] No se detecta macOS (OSTYPE=${OSTYPE:-unknown}).${NC}"
fi

# Generar JSON placeholder con esquema mínimo coherente al resto de plataformas
mkdir -p "$OUTPUT_DIR"
HOSTNAME_STR="$(hostname 2>/dev/null || echo macos)"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
OUT_FILE="${OUTPUT_DIR}/diagnostico_macos_${HOSTNAME_STR}_${TIMESTAMP}.json"

cat > "$OUT_FILE" <<EOF
{
  "hardware":          { "demo": true },
  "sistema_operativo": { "demo": true, "nombre": "macOS" },
  "red":               { "demo": true },
  "seguridad":         { "demo": true },
  "_meta": {
    "version":     "$SCRIPT_VERSION",
    "plataforma":  "macos",
    "stub":        true,
    "hostname":    "$HOSTNAME_STR",
    "modo":        "$MODE",
    "ssh_host":    "$SSH_HOST",
    "ssh_user":    "$SSH_USER",
    "generado_en": "$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')",
    "nota":        "Implementacion pendiente. Conserva interfaz CLI para integracion futura."
  }
}
EOF

echo -e "  ${GREEN}[OK] JSON stub generado: $OUT_FILE${NC}"
echo "$OUT_FILE"
exit 0
