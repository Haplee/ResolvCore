#!/usr/bin/env bash
# =============================================================================
# ResolveCore — backup.sh
#
# Backup completo del stack VPS: dumps MariaDB (WordPress + MantisBT) + tarballs
# de ficheros + config crítica (nginx, php, wp-config, mantis config) +
# MANIFEST.txt con SHA256.
#
# Destino: /var/backups/resolvecore/<YYYYMMDD-HHMMSS>/
# Retención: 14 días (borrado automático al final).
#
# Credenciales MariaDB: /etc/resolvecore/mysql-backup.cnf (perms 600).
#
# Uso (como root):
#   bash backup.sh
#
# Cron sugerido (en /etc/cron.d/resolvecore):
#   0 3 * * * root /opt/resolvecore/ops/backup.sh
# =============================================================================

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "ERROR: requiere root" >&2; exit 1; }

LOG_DIR=/var/log/resolvecore
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/backup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log()  { printf '\e[1;32m[+]\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m[!]\e[0m %s\n' "$*"; }
err()  { printf '\e[1;31m[x]\e[0m %s\n' "$*" >&2; }

# Entorno
[[ -r /etc/resolvecore/env ]] && source /etc/resolvecore/env
WP_DIR="${WP_DIR:-/var/www/wp}"
MANTIS_DIR="${MANTIS_DIR:-/var/www/mantis}"
BACKUP_ROOT="/var/backups/resolvecore"
MYSQL_CNF="/etc/resolvecore/mysql-backup.cnf"

# Pre-checks
[[ -r "$MYSQL_CNF" ]] || { err "Falta $MYSQL_CNF (credenciales MariaDB)"; exit 1; }
command -v mysqldump >/dev/null || { err "mysqldump no instalado"; exit 1; }
command -v gzip >/dev/null      || { err "gzip no instalado"; exit 1; }
command -v sha256sum >/dev/null || { err "sha256sum no instalado"; exit 1; }

# Detectar nombres reales de DBs (fallback a defaults conocidos)
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

TS=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/$TS"
mkdir -p "$BACKUP_DIR"
log "[$(date -Iseconds)] Backup → $BACKUP_DIR"

# Dumps
log "Dump MariaDB: $DB_WP_NAME"
mysqldump --defaults-file="$MYSQL_CNF" --single-transaction --routines --triggers "$DB_WP_NAME" \
    | gzip > "$BACKUP_DIR/wp.sql.gz"

log "Dump MariaDB: $DB_MANTIS_NAME"
mysqldump --defaults-file="$MYSQL_CNF" --single-transaction --routines --triggers "$DB_MANTIS_NAME" \
    | gzip > "$BACKUP_DIR/mantisbt.sql.gz"

# Tarballs (-C para que rutas dentro del tar sean relativas)
WP_BASE=$(basename "$WP_DIR")
WP_PARENT=$(dirname "$WP_DIR")
MANTIS_BASE=$(basename "$MANTIS_DIR")
MANTIS_PARENT=$(dirname "$MANTIS_DIR")

log "Tar files WordPress"
tar -czf "$BACKUP_DIR/wp-files.tar.gz" \
    --exclude="$WP_BASE/wp-content/cache" \
    --exclude="$WP_BASE/wp-content/uploads/rc-tech/tmp" \
    -C "$WP_PARENT" "$WP_BASE"

log "Tar files MantisBT"
tar -czf "$BACKUP_DIR/mantis-files.tar.gz" \
    --exclude="$MANTIS_BASE/cache" \
    -C "$MANTIS_PARENT" "$MANTIS_BASE"

log "Tar config (/etc + wp-config + mantis config)"
tar -czf "$BACKUP_DIR/etc-config.tar.gz" \
    /etc/nginx/sites-available \
    /etc/php \
    "$WP_DIR/wp-config.php" \
    "$MANTIS_DIR/config/config_inc.php" 2>/dev/null || \
    warn "Algún path en etc-config no existe — se omitió"

# Manifest con SHA256 + tamaños
log "Generando MANIFEST.txt"
(
    cd "$BACKUP_DIR"
    sha256sum -- *.gz > MANIFEST.txt
    {
        echo ""
        echo "# Tamaños:"
        ls -la -- *.gz
    } >> MANIFEST.txt
)

# Retención: 14 días
log "Limpiando backups > 14 días"
find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime +14 -exec rm -rf {} +

log "Backup completado: $BACKUP_DIR ($(du -sh "$BACKUP_DIR" | cut -f1))"
