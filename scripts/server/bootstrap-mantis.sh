#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Descarga de la distribución de MantisBT.
#
# Baja el tarball oficial de MantisBT y lo descomprime junto al repo, para
# tenerlo disponible en local sin meter sus fuentes en git.
#
# No requiere root (escribe dentro del repo, no en /var/www).
#
# Uso:
#     bash bootstrap-mantis.sh            # descarga si no existe ya
#     bash bootstrap-mantis.sh --force    # borra y vuelve a descargar
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# Versión fijada a propósito: así el TFG es reproducible y no se rompe si
# upstream saca una versión con cambios de esquema.
MANTIS_VERSION="2.28.1"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${REPO_ROOT}/mantisbt-${MANTIS_VERSION}"
DOWNLOAD_URL="https://github.com/mantisbt/mantisbt/releases/download/${MANTIS_VERSION}/mantisbt-${MANTIS_VERSION}.tar.gz"

# --force borra lo descargado antes para forzar una descarga limpia.
[ "${1:-}" = "--force" ] && rm -rf "$TARGET_DIR"

if [ -d "$TARGET_DIR" ]; then
    echo "Ya existe $TARGET_DIR (usa --force para volver a descargar)."
    exit 0
fi

echo "Descargando MantisBT ${MANTIS_VERSION}..."

# Trabajamos en un tmp y limpiamos con trap pase lo que pase (éxito o error).
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Aceptamos curl o wget: no todas las máquinas traen los dos.
if command -v curl >/dev/null; then
    curl -fL "$DOWNLOAD_URL" -o "$TMP_DIR/mantis.tar.gz"
elif command -v wget >/dev/null; then
    wget -q "$DOWNLOAD_URL" -O "$TMP_DIR/mantis.tar.gz"
else
    echo "Se requiere curl o wget para descargar." >&2
    exit 1
fi

tar -xzf "$TMP_DIR/mantis.tar.gz" -C "$REPO_ROOT"
echo "MantisBT ${MANTIS_VERSION} disponible en $TARGET_DIR"
