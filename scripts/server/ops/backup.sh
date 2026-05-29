#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Backup completo del stack del VPS.
#
# Hace un dump comprimido de las dos bases (WordPress y MantisBT) y un
# tar.gz de los ficheros de cada uno. Todo va a:
#     /var/backups/resolvecore/<YYYYMMDD-HHMMSS>/
#
# Al final genera un MANIFEST.txt con SHA256 de los archivos — el script
# de restauración lo verifica antes de tocar nada.
#
# Retención: 14 días. Más que eso ocupa demasiado y el VPS solo tiene
# disco para lo justo. Ajustar abajo si hace falta.
#
# Uso (como root):
#     bash backup.sh
#
# Cron sugerido:
#     0 3 * * * root /opt/resolvecore/ops/backup.sh
#
# Credenciales BBDD: /etc/resolvecore/mysql-backup.cnf (perms 600).
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: este script tiene que correr como root." >&2
    exit 1
fi

# ── Logging ─────────────────────────────────────────────────────────────────

LOG_DIR=/var/log/resolvecore
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/backup.log"

# Duplicamos stdout/stderr al log para tener histórico sin perder la
# salida en pantalla cuando se lanza a mano.
exec > >(tee -a "$LOG_FILE") 2>&1

log()  { printf '\e[1;32m[+]\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m[!]\e[0m %s\n' "$*"; }
err()  { printf '\e[1;31m[x]\e[0m %s\n' "$*" >&2; }


# ── Entorno ─────────────────────────────────────────────────────────────────
# /etc/resolvecore/env lo crea deploy-ionos.sh. Si no existe usamos los
# defaults (que coinciden con el deploy estándar).

[ -r /etc/resolvecore/env ] && source /etc/resolvecore/env

WP_DIR="${WP_DIR:-/var/www/wp}"
MANTIS_DIR="${MANTIS_DIR:-/var/www/mantis}"
MYSQL_CNF="/etc/resolvecore/mysql-backup.cnf"
BACKUP_ROOT="/var/backups/resolvecore"

[ -r "$MYSQL_CNF" ] || { err "Falta $MYSQL_CNF (credenciales MariaDB)"; exit 1; }

# Detectamos los nombres reales de las DBs en vez de hardcodearlos —
# así sobrevive a renombrados en la instalación.
DB_WP="wp_resolvecore"
DB_MANTIS="mantisbt"

if [ -r "$WP_DIR/wp-config.php" ]; then
    real=$(grep -oP "define\(\s*'DB_NAME'\s*,\s*'\K[^']+" "$WP_DIR/wp-config.php" || true)
    [ -n "$real" ] && DB_WP="$real"
fi

if [ -r "$MANTIS_DIR/config/config_inc.php" ]; then
    real=$(grep -oP "\\\$g_database_name\s*=\s*'\K[^']+" "$MANTIS_DIR/config/config_inc.php" || true)
    [ -n "$real" ] && DB_MANTIS="$real"
fi


# ── Carpeta destino ─────────────────────────────────────────────────────────

TS=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/$TS"
mkdir -p "$BACKUP_DIR"
log "[$(date -Iseconds)] Backup -> $BACKUP_DIR"


# ── Dumps de base de datos ──────────────────────────────────────────────────
# --single-transaction evita lockear la tabla en bases InnoDB.

log "Dump MariaDB: $DB_WP"
mysqldump --defaults-file="$MYSQL_CNF" --single-transaction "$DB_WP" \
    | gzip > "$BACKUP_DIR/wp.sql.gz"

log "Dump MariaDB: $DB_MANTIS"
mysqldump --defaults-file="$MYSQL_CNF" --single-transaction "$DB_MANTIS" \
    | gzip > "$BACKUP_DIR/mantis.sql.gz"


# ── Tarballs de ficheros ────────────────────────────────────────────────────
# Excluimos cachés porque ocupan mucho y se regeneran solas.

log "Tar files WordPress"
tar -czf "$BACKUP_DIR/wp-files.tar.gz" \
    --exclude="$(basename "$WP_DIR")/wp-content/cache" \
    -C "$(dirname "$WP_DIR")" \
    "$(basename "$WP_DIR")"

log "Tar files MantisBT"
tar -czf "$BACKUP_DIR/mantis-files.tar.gz" \
    --exclude="$(basename "$MANTIS_DIR")/cache" \
    -C "$(dirname "$MANTIS_DIR")" \
    "$(basename "$MANTIS_DIR")"


# ── MANIFEST con hashes ─────────────────────────────────────────────────────

log "Generando MANIFEST.txt..."
( cd "$BACKUP_DIR" && sha256sum ./*.gz > MANIFEST.txt )


# ── Retención ──────────────────────────────────────────────────────────────
# 14 días: compromiso espacio / recuperación. Si hay que cambiarlo se
# edita aquí.

log "Limpiando backups con más de 14 días..."
find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime +14 -exec rm -rf {} +

log "Backup completado ($(du -sh "$BACKUP_DIR" | cut -f1))"
