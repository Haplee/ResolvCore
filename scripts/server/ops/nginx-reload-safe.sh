#!/usr/bin/env bash
# Autor:   Francisco Vidal Mateo (GitHub: Haplee)
# =============================================================================
# ResolveCore — nginx-reload-safe.sh
#
# Valida la configuración de nginx con `nginx -t` y, solo si pasa, recarga el
# servicio. Verifica que el daemon sigue activo tras el reload.
#
# Uso (como root):
#   bash nginx-reload-safe.sh
#
# Exit codes:
#   0 — reload OK
#   1 — error de root, config inválida o nginx inactivo post-reload
# =============================================================================

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "ERROR: requiere root" >&2; exit 1; }

LOG_DIR=/var/log/resolvecore
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/nginx-reload-safe.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log()  { printf '\e[1;32m[+]\e[0m %s\n' "$*"; }
err()  { printf '\e[1;31m[x]\e[0m %s\n' "$*" >&2; }

log "[$(date -Iseconds)] Validando configuración nginx…"
if ! nginx -t; then
    err "nginx -t falló — abortando reload"
    exit 1
fi

log "Recargando nginx…"
systemctl reload nginx

if ! systemctl is-active --quiet nginx; then
    err "nginx no está activo tras el reload"
    exit 1
fi

log "nginx recargado correctamente"
