#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Restauración del stack desde un backup.
#
# Lee una carpeta de backup generada por backup.sh, verifica los hashes del
# MANIFEST.txt y restaura base de datos + ficheros de WordPress y/o MantisBT.
#
# Es DESTRUCTIVO: sobreescribe las bases y los ficheros actuales. Por eso
# exige --confirm explícito (mismo criterio que los scripts de limpieza).
#
# Uso (como root):
#     bash restore.sh --confirm <dir-backup> <wp|mantis|all>
#
# Ejemplo:
#     bash restore.sh --confirm /var/backups/resolvecore/20260527-125103 all
#
# Exit codes:
#     0  OK
#     1  error de uso / requisitos
#     2  MANIFEST inválido (los .gz no cuadran con los hashes)
#
# Credenciales BBDD: /etc/resolvecore/mysql-backup.cnf
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

log()  { printf '\e[1;32m[+]\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m[!]\e[0m %s\n' "$*"; }
err()  { printf '\e[1;31m[x]\e[0m %s\n' "$*" >&2; }

if [ "$EUID" -ne 0 ]; then
    err "Este script tiene que correr como root."
    exit 1
fi

# El primer argumento SIEMPRE debe ser --confirm. Restaurar pisa datos en
# producción, así que no quiero que se lance sin querer.
if [ "${1:-}" != "--confirm" ]; then
    echo "Uso: $0 --confirm <dir-backup> <wp|mantis|all>"
    echo ""
    echo "ATENCIÓN: sobreescribe BBDD y ficheros actuales. Sin vuelta atrás."
    exit 1
fi

BACKUP_DIR="${2:-}"
TARGET="${3:-all}"

[ -d "$BACKUP_DIR" ]              || { err "No existe la carpeta: $BACKUP_DIR"; exit 1; }
[ -f "$BACKUP_DIR/MANIFEST.txt" ] || { err "Falta MANIFEST.txt en $BACKUP_DIR"; exit 1; }


# ── Verificación de integridad ──────────────────────────────────────────────
# Antes de tocar nada comprobamos que los .gz no estén corruptos. Si el
# hash no cuadra abortamos: mejor no restaurar que restaurar basura.

log "Verificando hashes del MANIFEST..."
( cd "$BACKUP_DIR" \
    && grep -E '^[0-9a-f]{64} ' MANIFEST.txt | sha256sum --check --status ) \
    || { err "MANIFEST inválido — backup corrupto, no continúo."; exit 2; }


# ── Entorno ─────────────────────────────────────────────────────────────────

[ -r /etc/resolvecore/env ] && source /etc/resolvecore/env

WP_DIR="${WP_DIR:-/var/www/wp}"
MANTIS_DIR="${MANTIS_DIR:-/var/www/mantis}"
MYSQL_CNF="${MYSQL_CNF:-/etc/resolvecore/mysql-backup.cnf}"

# Mismo truco que en backup.sh: leemos el nombre real de la DB del config en
# vez de hardcodearlo, por si la instalación lo cambió.
DB_WP=$(grep -oP "DB_NAME'\s*,\s*'\K[^']+" "$WP_DIR/wp-config.php" 2>/dev/null || echo "wp_resolvecore")
DB_MANTIS=$(grep -oP "g_database_name\s*=\s*'\K[^']+" "$MANTIS_DIR/config/config_inc.php" 2>/dev/null || echo "mantisbt")


# ── Funciones de restauración ───────────────────────────────────────────────
# --overwrite en tar para que pise los ficheros existentes sin quejarse.
# El chown final hace falta porque tar conserva el uid del backup.

restaurar_wp() {
    log "Restaurando WordPress (DB=$DB_WP)..."
    gunzip < "$BACKUP_DIR/wp.sql.gz" | mysql --defaults-file="$MYSQL_CNF" "$DB_WP"
    tar -xzf "$BACKUP_DIR/wp-files.tar.gz" -C "$(dirname "$WP_DIR")" --overwrite
    chown -R www-data:www-data "$WP_DIR"
}

restaurar_mantis() {
    log "Restaurando MantisBT (DB=$DB_MANTIS)..."
    gunzip < "$BACKUP_DIR/mantis.sql.gz" | mysql --defaults-file="$MYSQL_CNF" "$DB_MANTIS"
    tar -xzf "$BACKUP_DIR/mantis-files.tar.gz" -C "$(dirname "$MANTIS_DIR")" --overwrite
    chown -R www-data:www-data "$MANTIS_DIR"
}

case "$TARGET" in
    wp)     restaurar_wp ;;
    mantis) restaurar_mantis ;;
    all)    restaurar_wp; restaurar_mantis ;;
    *)      err "Target inválido: $TARGET (usa wp|mantis|all)"; exit 1 ;;
esac

# TODO: tras restaurar WP estaría bien lanzar 'wp cache flush' por si quedan
#       transients viejos apuntando a rutas del backup.

nginx -t && systemctl reload nginx
log "Restore completado (target=$TARGET)"
