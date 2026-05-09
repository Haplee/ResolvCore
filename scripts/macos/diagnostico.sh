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
NAME
    diagnostico.sh - Diagnostico macOS (DEMO STUB v${SCRIPT_VERSION})

SYNOPSIS
    bash diagnostico.sh [OPTIONS]

DESCRIPTION
    Stub que conserva la interfaz CLI completa para que un tecnico pueda
    probarlo en macOS sin depender de la logica final. Implementacion
    completa prevista para fase posterior del TFG. Genera un JSON
    placeholder con esquema minimo coherente al resto de plataformas.

    Para diagnostico real hoy:
        system_profiler -json SPHardwareDataType
        ejecutar el script Linux via contenedor.

OPTIONS
    --local                     Forzar modo local (default).
    --host <ip>                 Modo remoto via SSH.
    --user <name>               Usuario SSH (no root: macOS bloquea root
                                login por defecto).
    --port <n>                  Puerto SSH (default: 22).
    -O, --output <dir>          Directorio salida JSON.
                                Default: ../diagnosticos
    -h, --help                  Muestra esta ayuda y sale.

EXAMPLES
    bash diagnostico.sh
    bash diagnostico.sh -O /tmp
    bash diagnostico.sh --host 192.168.1.10 --user fran
    bash diagnostico.sh --host 192.168.1.10 --user fran --port 2222

EXIT CODES
    0    Stub ejecutado, JSON placeholder generado.

ESTADO
    DEMO. Sin recoleccion real de datos en esta version.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)        MODE="remote"; SSH_HOST="${2:-}"; shift 2 ;;
        --user)        SSH_USER="${2:-}"; shift 2 ;;
        --port)        SSH_PORT="${2:-22}"; shift 2 ;;
        -O|--output)   OUTPUT_DIR="${2:-}"; shift 2 ;;
        --local)       MODE="local"; shift ;;
        -h|--help)     usage; exit 0 ;;
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

# Generar JSON placeholder con esquema mínimo coherente al resto de plataformas.
# Nota: aunque sea stub, se escapan campos string para que un hostname/SSH con
# caracteres especiales no rompa el JSON. Cuando este script salga del estado
# stub, replicar el patrón jq -n de scripts/linux/diagnostico.sh.
mkdir -p "$OUTPUT_DIR"
HOSTNAME_STR="$(hostname 2>/dev/null || echo macos)"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
GENERATED_AT="$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')"
OUT_FILE="${OUTPUT_DIR}/diagnostico_macos_${HOSTNAME_STR}_${TIMESTAMP}.json"

if command -v jq &>/dev/null; then
    jq -n \
        --arg version    "$SCRIPT_VERSION" \
        --arg hostname   "$HOSTNAME_STR" \
        --arg modo       "$MODE" \
        --arg ssh_host   "$SSH_HOST" \
        --arg ssh_user   "$SSH_USER" \
        --arg generado   "$GENERATED_AT" \
        '{
            hardware:          { demo: true },
            sistema_operativo: { demo: true, nombre: "macOS" },
            red:               { demo: true },
            seguridad:         { demo: true },
            _meta: {
                version:     $version,
                plataforma:  "macos",
                stub:        true,
                hostname:    $hostname,
                modo:        $modo,
                ssh_host:    $ssh_host,
                ssh_user:    $ssh_user,
                generado_en: $generado,
                nota:        "Implementacion pendiente. Conserva interfaz CLI para integracion futura."
            }
        }' > "$OUT_FILE"
else
    # Fallback sin jq: escapado manual mínimo para no romper el JSON.
    json_escape() {
        local s="$1"
        s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\t'/\\t}"
        printf '%s' "$s"
    }
    cat > "$OUT_FILE" <<EOF
{
  "hardware":          { "demo": true },
  "sistema_operativo": { "demo": true, "nombre": "macOS" },
  "red":               { "demo": true },
  "seguridad":         { "demo": true },
  "_meta": {
    "version":     "$(json_escape "$SCRIPT_VERSION")",
    "plataforma":  "macos",
    "stub":        true,
    "hostname":    "$(json_escape "$HOSTNAME_STR")",
    "modo":        "$(json_escape "$MODE")",
    "ssh_host":    "$(json_escape "$SSH_HOST")",
    "ssh_user":    "$(json_escape "$SSH_USER")",
    "generado_en": "$(json_escape "$GENERATED_AT")",
    "nota":        "Implementacion pendiente. Conserva interfaz CLI para integracion futura."
  }
}
EOF
fi

echo -e "  ${GREEN}[OK] JSON stub generado: $OUT_FILE${NC}"
echo "$OUT_FILE"
exit 0
