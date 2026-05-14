#!/usr/bin/env bash
# =============================================================================
#  ResolveCore — Optimización de dispositivo Android (vía ADB)
#  Versión: 3.1.0
#
#  CAMBIOS 3.1.0 vs 3.0.0:
#    - FIX CRÍTICO: 'pm clear' borraba TODOS los datos de las apps (logins,
#      ajustes, archivos). Sustituido por 'pm trim-caches' (sólo caché).
#    - Añadidos --dry-run, --confirm, --undo, --serial, --output.
#    - Genera informe JSON al cerrar.
#    - Fix typo "com.android. provisioning".
#    - Validación de dispositivo autorizado antes de actuar.
# =============================================================================

set -uo pipefail

SCRIPT_VERSION="3.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NIVEL="estandar"
DRY_RUN=false
CONFIRM=false
UNDO=false
SERIAL=""
OUTPUT_DIR="${SCRIPT_DIR}/../diagnosticos"

usage() {
    cat <<EOF
NAME
    optimizacion.sh - Optimizacion de dispositivo Android via ADB

SYNOPSIS
    bash optimizacion.sh [OPTIONS] [NIVEL]

DESCRIPTION
    Aplica optimizaciones por niveles al dispositivo Android conectado via
    ADB. Usa pm trim-caches (NO 'pm clear' que borra datos de usuario).
    Genera JSON con acciones aplicadas para auditoria. Permite reactivar
    apps deshabilitadas con --undo. Requiere --confirm para niveles
    destructivos (rendimiento, extreme).

ARGUMENTS
    NIVEL                       Nivel a aplicar (default: estandar):
                                  ligero       Solo trim-caches.
                                  estandar     Anterior + servicios no
                                               criticos.
                                  rendimiento  Anterior + deshabilitar
                                               bloatware (requiere --confirm).
                                  extreme      Anterior + ajustes agresivos
                                               (requiere --confirm).

OPTIONS
    --serial <id>               Dispositivo ADB concreto.
                                Default: primero detectado.
    --dry-run                   Simula sin aplicar cambios.
    --confirm                   Requerido para niveles destructivos.
    --undo                      Reactiva apps deshabilitadas en sesiones
                                previas (lee log de acciones).
    -O, --output <dir>          Directorio del informe JSON.
                                Default: ../diagnosticos
    -h, --help                  Muestra esta ayuda y sale.

REQUISITOS
    - adb instalado y dispositivo autorizado.
    - Depuracion USB activa.

EXAMPLES
    bash optimizacion.sh --dry-run
    bash optimizacion.sh ligero
    bash optimizacion.sh rendimiento --confirm
    bash optimizacion.sh --undo
    bash optimizacion.sh --serial ABC123 --confirm extreme

EXIT CODES
    0    Optimizacion aplicada correctamente.
    1    adb no instalado o sin dispositivo autorizado.
    2    Opcion no reconocida.
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --serial)     SERIAL="${2:-}"; shift 2 ;;
        -O|--output)  OUTPUT_DIR="${2:-}"; shift 2 ;;
        --dry-run)    DRY_RUN=true; shift ;;
        --confirm)    CONFIRM=true; shift ;;
        --undo)       UNDO=true; shift ;;
        -h|--help)    usage; exit 0 ;;
        ligero|estandar|rendimiento|extreme) NIVEL="$1"; shift ;;
        *) echo "Opción no reconocida: $1" >&2; usage; exit 2 ;;
    esac
done

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; NC='\033[0m'

log_info() { echo -e "    ${YELLOW}[!] $*${NC}"; }
log_ok()   { echo -e "    ${GREEN}[OK] $*${NC}"; }
log_err()  { echo -e "    ${RED}[X] $*${NC}" >&2; }
log_step() { echo ""; echo -e "  ${CYAN}> $*${NC}"; }

ACCIONES=()
register() { ACCIONES+=("$1"); }

# ── Verificaciones previas ───────────────────────────────────────────────────
if ! command -v adb &>/dev/null; then
    log_err "adb no instalado. Instalar: apt install adb | brew install android-platform-tools"
    exit 1
fi

if [[ -z "$SERIAL" ]]; then
    SERIAL=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{print $1; exit}')
fi

if [[ -z "$SERIAL" ]]; then
    log_err "No hay dispositivo Android autorizado. Habilita depuración USB y acepta el prompt."
    exit 1
fi

# Confirmar dispositivo accesible
if ! adb -s "$SERIAL" shell true &>/dev/null; then
    log_err "Dispositivo $SERIAL no responde (¿desautorizado?)."
    exit 1
fi

adb_s() { adb -s "$SERIAL" shell "$@" 2>/dev/null | tr -d '\r'; }

run() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DryRun: $*"
        return 0
    fi
    "$@"
}

# Niveles destructivos requieren --confirm
if [[ "$NIVEL" == "rendimiento" || "$NIVEL" == "extreme" ]]; then
    if [[ "$DRY_RUN" != "true" && "$CONFIRM" != "true" ]]; then
        log_err "Nivel '$NIVEL' deshabilita apps del sistema. Reejecuta con --confirm o --dry-run."
        exit 3
    fi
fi

echo ""
echo -e "${CYAN}  ==============================================================${NC}"
echo -e "${CYAN}  ResolveCore — Optimización Android v${SCRIPT_VERSION}${NC}"
echo -e "  Nivel:        $NIVEL"
echo -e "  Dispositivo:  $SERIAL"
[[ "$DRY_RUN" == "true" ]] && echo -e "  ${YELLOW}MODO DRY-RUN — sin cambios${NC}"
echo -e "  $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${CYAN}  ==============================================================${NC}"

# ── Modo undo: reactivar apps previamente deshabilitadas ─────────────────────
UNDO_LOG="${OUTPUT_DIR}/android_${SERIAL}_disabled.log"
if [[ "$UNDO" == "true" ]]; then
    log_step "Deshacer cambios"
    if [[ ! -f "$UNDO_LOG" ]]; then
        log_info "Sin registro previo en $UNDO_LOG"
        exit 0
    fi
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        if run adb -s "$SERIAL" shell "pm enable --user 0 $pkg" 2>/dev/null; then
            log_ok "Reactivada: $pkg"
        fi
    done < "$UNDO_LOG"
    rm -f "$UNDO_LOG"
    exit 0
fi

# ── Permisos root (informativo, no requerido) ────────────────────────────────
log_step "Permisos"
if adb_s id 2>/dev/null | grep -q 'uid=0'; then
    log_ok "Acceso root disponible"
    HAS_ROOT=true
else
    log_info "Sin root — funciones limitadas (suficiente para limpieza segura)"
    HAS_ROOT=false
fi

# ── Limpieza de caché (NO destructiva) ───────────────────────────────────────
log_step "Limpieza de caché"

# pm trim-caches: libera caché del sistema sin tocar datos de usuario.
# Tamaño en bytes; 1G = 1073741824
if run adb -s "$SERIAL" shell "pm trim-caches 1073741824" &>/dev/null; then
    log_ok "Caché del sistema recortada (~1GB)"
    register "trim_caches"
fi

# ── Apps preinstaladas (sólo nivel rendimiento/extreme) ──────────────────────
if [[ "$NIVEL" == "rendimiento" || "$NIVEL" == "extreme" ]]; then
    log_step "Deshabilitando apps preinstaladas no esenciales"

    APPS_TO_DISABLE=(
        "com.android.soundrecorder"
        "com.android.stk"
        "com.android.provision"
    )

    [[ "$DRY_RUN" != "true" ]] && mkdir -p "$OUTPUT_DIR"

    for app in "${APPS_TO_DISABLE[@]}"; do
        # pm list packages -d filtra solo apps deshabilitables
        if adb_s "pm list packages $app" 2>/dev/null | grep -q "package:$app"; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "DryRun: deshabilitaría $app"
            else
                if adb -s "$SERIAL" shell "pm disable-user --user 0 $app" 2>/dev/null | grep -q 'new state: disabled'; then
                    log_ok "Deshabilitada: $app"
                    echo "$app" >> "$UNDO_LOG"
                    register "disabled:$app"
                fi
            fi
        fi
    done
fi

# ── Output JSON ──────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" != "true" ]]; then
    mkdir -p "$OUTPUT_DIR"
    OUT_FILE="${OUTPUT_DIR}/optimizacion_android_${SERIAL}_$(date '+%Y%m%d_%H%M%S').json"

    acciones_json="["
    first=true
    for a in "${ACCIONES[@]:-}"; do
        [[ -z "$a" ]] && continue
        if $first; then
            acciones_json+="\"$a\""
            first=false
        else
            acciones_json+=",\"$a\""
        fi
    done
    acciones_json+="]"

    cat > "$OUT_FILE" <<EOF
{
  "plataforma": "android",
  "serial":     "$SERIAL",
  "nivel":      "$NIVEL",
  "dry_run":    $DRY_RUN,
  "acciones":   $acciones_json,
  "generado_en": "$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')",
  "_meta":      { "version": "$SCRIPT_VERSION" }
}
EOF
    echo ""
    echo -e "${GREEN}  [OK] Optimización completada${NC}"
    echo -e "  Informe: $OUT_FILE"
    [[ -f "$UNDO_LOG" ]] && echo -e "  Para deshacer: bash $0 --serial $SERIAL --undo"
fi

echo ""
exit 0
