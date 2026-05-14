#!/usr/bin/env bash
# =============================================================================
# ResolveCore — Bootstrap MantisBT 2.28.1
#
# Descarga el bundle oficial MantisBT 2.28.1 desde GitHub Releases y lo
# extrae en <repo>/mantisbt-2.28.1/ (gitignored).
#
# Uso:
#   bash scripts/bootstrap-mantis.sh           # idempotente: salta si ya existe
#   bash scripts/bootstrap-mantis.sh --force   # re-descarga aunque exista
#   bash scripts/bootstrap-mantis.sh --check   # solo verifica integridad
#
# Requisitos: curl o wget, tar, sha256sum (opcional pero recomendado).
# =============================================================================

set -euo pipefail

MANTIS_VERSION="2.28.1"
MANTIS_TARBALL="mantisbt-${MANTIS_VERSION}.tar.gz"
MANTIS_URL="https://github.com/mantisbt/mantisbt/releases/download/${MANTIS_VERSION}/${MANTIS_TARBALL}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${REPO_ROOT}/mantisbt-${MANTIS_VERSION}"
SHA256_FILE="${REPO_ROOT}/mantisbt/mantis-${MANTIS_VERSION}.sha256"
SENTINEL="${TARGET_DIR}/admin/install.php"

FORCE=false
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)  FORCE=true; shift ;;
        --check)  CHECK_ONLY=true; shift ;;
        -h|--help)
            sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "Opción desconocida: $1" >&2; exit 2 ;;
    esac
done

# ── Helpers ──────────────────────────────────────────────────────────────────
info()  { printf '  \033[0;36m▸\033[0m %s\n' "$*"; }
ok()    { printf '  \033[0;32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[1;33m!\033[0m %s\n' "$*"; }
fail()  { printf '  \033[0;31m✗\033[0m %s\n' "$*" >&2; }

require_tool() {
    command -v "$1" >/dev/null 2>&1 || {
        fail "Falta '$1'. Instálalo y reintenta."; exit 1;
    }
}

# ── Verificar dependencias ──────────────────────────────────────────────────
if command -v curl >/dev/null 2>&1; then
    DOWNLOADER="curl"
elif command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget"
else
    fail "Necesitas curl o wget."; exit 1
fi
require_tool tar

# ── Modo --check ─────────────────────────────────────────────────────────────
if [[ "$CHECK_ONLY" == "true" ]]; then
    if [[ -f "$SENTINEL" ]]; then
        ok "MantisBT ${MANTIS_VERSION} presente en ${TARGET_DIR}"
        exit 0
    else
        fail "MantisBT ${MANTIS_VERSION} no instalado (falta ${SENTINEL})"
        exit 1
    fi
fi

# ── Idempotencia ─────────────────────────────────────────────────────────────
if [[ -f "$SENTINEL" && "$FORCE" != "true" ]]; then
    ok "MantisBT ${MANTIS_VERSION} ya está instalado en ${TARGET_DIR}"
    info "Usa --force para re-descargar."
    exit 0
fi

if [[ -d "$TARGET_DIR" && "$FORCE" == "true" ]]; then
    warn "Eliminando instalación previa (--force)…"
    rm -rf "$TARGET_DIR"
fi

# ── Descarga ────────────────────────────────────────────────────────────────
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
TMP_TARBALL="${TMP_DIR}/${MANTIS_TARBALL}"

info "Descargando ${MANTIS_URL}"
case "$DOWNLOADER" in
    curl) curl -fsSL --retry 3 -o "$TMP_TARBALL" "$MANTIS_URL" ;;
    wget) wget --tries=3 -qO "$TMP_TARBALL" "$MANTIS_URL" ;;
esac
ok "Descarga completada ($(du -h "$TMP_TARBALL" | cut -f1))"

# ── Verificación SHA256 (opcional) ──────────────────────────────────────────
if [[ -f "$SHA256_FILE" ]] && command -v sha256sum >/dev/null 2>&1; then
    EXPECTED="$(awk 'NR==1 {print $1}' "$SHA256_FILE")"
    if [[ -n "$EXPECTED" && "$EXPECTED" != "TODO" ]]; then
        ACTUAL="$(sha256sum "$TMP_TARBALL" | awk '{print $1}')"
        if [[ "$EXPECTED" != "$ACTUAL" ]]; then
            fail "SHA256 no coincide."
            fail "  esperado: $EXPECTED"
            fail "  obtenido: $ACTUAL"
            exit 1
        fi
        ok "SHA256 verificado"
    else
        warn "${SHA256_FILE} contiene 'TODO' — saltando verificación."
    fi
else
    warn "Sin SHA256 file (mantisbt/mantis-${MANTIS_VERSION}.sha256). Confiando en TLS."
fi

# ── Extracción ──────────────────────────────────────────────────────────────
info "Extrayendo en ${REPO_ROOT}/"
tar -xzf "$TMP_TARBALL" -C "$REPO_ROOT"

if [[ ! -f "$SENTINEL" ]]; then
    fail "Extracción incorrecta — falta ${SENTINEL}"
    exit 1
fi

ok "MantisBT ${MANTIS_VERSION} listo en ${TARGET_DIR}"
echo ""
info "Siguientes pasos: ver docs/mantis-integration.md sección 'Instalación MantisBT en VPS'."
