#!/usr/bin/env bash
# =============================================================================
# ResolveCore — restore.sh
#
# Restaura un backup creado por backup.sh. Verifica MANIFEST.txt (SHA256) antes
# de tocar nada.
#
# Uso (como root):
#   bash restore.sh --from /var/backups/resolvecore/<ts> --target {wp|mantis|all} --confirm
#
# Exit codes:
#   0 — restore OK
#   1 — argumentos inválidos / falta root
#   2 — fallo de verificación MANIFEST
# =============================================================================

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "ERROR: requiere root" >&2; exit 1; }

LOG_DIR=/var/log/resolvecore
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/restore.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log()  { printf '\e[1;32m[+]\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m[!]\e[0m %s\n' "$*"; }
err()  { printf '\e[1;31m[x]\e[0m %s\n' "$*" >&2; }

FROM=""
TARGET=""
CONFIRM=false

usage() {
    sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-1}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --from)    FROM="$2"; shift 2 ;;
        --target)  TARGET="$2"; shift 2 ;;
        --confirm) CONFIRM=true; shift ;;
        -h|--help) usage 0 ;;
        *) err "Opción desconocida: $1"; usage 1 ;;
    esac
done

[[ -z "$FROM" || -z "$TARGET" ]] && { err "--from y --target son obligatorios"; usage 1; }
[[ "$CONFIRM" == "true" ]]      || { err "Falta --confirm (operación destructiva)"; exit 1; }
[[ -d "$FROM" ]]                || { err "Directorio no existe: $FROM"; exit 1; }

case "$TARGET" in
    wp|mantis|all) ;;
    *) err "--target inválido: $TARGET (wp|mantis|all)"; exit 1 ;;
esac

# Entorno
[[ -r /etc/resolvecore/env ]] && source /etc/resolvecore/env
WP_DIR="${WP_DIR:-/var/www/wp}"
MANTIS_DIR="${MANTIS_DIR:-/var/www/mantis}"
MYSQL_CNF="/etc/resolvecore/mysql-backup.cnf"

[[ -r "$MYSQL_CNF" ]] || { err "Falta $MYSQL_CNF"; exit 1; }
[[ -r "$FROM/MANIFEST.txt" ]] || { err "Falta MANIFEST.txt en $FROM"; exit 1; }

# Verificar MANIFEST (solo líneas con sha256sum, ignora cabeceras de tamaños)
log "Verificando MANIFEST.txt (SHA256)…"
(
    cd "$FROM"
    grep -E '^[0-9a-f]{64} ' MANIFEST.txt | sha256sum --check --status
) || { err "MANIFEST inválido — abortando"; exit 2; }
log "MANIFEST OK"

# Detectar nombres reales DBs (fallback)
DB_WP_NAME="wp_resolvecore"
DB_MANTIS_NAME="mantisbt"
if [[ -r "$WP_DIR/wp-config.php" ]]; then
    real=$(grep -oP "define\(\s*'DB_NAME'\s*,\s*'\K[^']+" "$WP_DIR/wp-config.php" || true)
    [[ -n "$real" ]] && DB_WP_NAME="$real"
fi
if [[ -r "$MANTIS_DIR/config/config_inc.php" ]]; then
    real=$(grep -oP "\\\$g_database_name\s*=\s*'\K[^']+" "$MANTIS_DIR/config/config_inc.php" || true)
    [[ -n "$real" ]] && DB_MANTIS_NAME="$real"
fi

WP_PARENT=$(dirname "$WP_DIR")
MANTIS_PARENT=$(dirname "$MANTIS_DIR")

restore_wp() {
    log "Restaurando WordPress…"
    gunzip < "$FROM/wp.sql.gz" | mysql --defaults-file="$MYSQL_CNF" "$DB_WP_NAME"
    tar -xzf "$FROM/wp-files.tar.gz" -C "$WP_PARENT" --overwrite
    chown -R www-data:www-data "$WP_DIR"
}

restore_mantis() {
    log "Restaurando MantisBT…"
    gunzip < "$FROM/mantisbt.sql.gz" | mysql --defaults-file="$MYSQL_CNF" "$DB_MANTIS_NAME"
    tar -xzf "$FROM/mantis-files.tar.gz" -C "$MANTIS_PARENT" --overwrite
    chown -R www-data:www-data "$MANTIS_DIR"
}

case "$TARGET" in
    wp)     restore_wp ;;
    mantis) restore_mantis ;;
    all)    restore_wp; restore_mantis ;;
esac

# Reload nginx (los ficheros pueden incluir cambios en config sites-enabled vía symlink)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$SCRIPT_DIR/nginx-reload-safe.sh" ]]; then
    bash "$SCRIPT_DIR/nginx-reload-safe.sh"
else
    warn "nginx-reload-safe.sh no encontrado — recarga manual con: nginx -t && systemctl reload nginx"
fi

log "Restore completado desde $FROM (target=$TARGET)"
