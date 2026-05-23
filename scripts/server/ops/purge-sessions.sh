#!/usr/bin/env bash
# =============================================================================
# ResolveCore — purge-sessions.sh
#
# Limpieza periódica de sesiones y datos efímeros:
#   - WP: transients expirados + session tokens de wp_usermeta caducados
#   - Mantis: filas viejas en mantis_user_session_table (>30d sin actividad)
#   - rc-tech: ficheros en uploads/rc-tech/tmp/ con mtime > 1 día
#
# Uso (como root):
#   bash purge-sessions.sh
#
# Cron sugerido:
#   30 4 * * 0 root /opt/resolvecore/ops/purge-sessions.sh
# =============================================================================

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "ERROR: requiere root" >&2; exit 1; }

LOG_DIR=/var/log/resolvecore
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/purge-sessions.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log()  { printf '\e[1;32m[+]\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m[!]\e[0m %s\n' "$*"; }

# Entorno
[[ -r /etc/resolvecore/env ]] && source /etc/resolvecore/env
WP_DIR="${WP_DIR:-/var/www/wp}"
MYSQL_CNF="/etc/resolvecore/mysql-backup.cnf"

log "[$(date -Iseconds)] Purge inicio"

# --- WordPress: transients expirados ---
log "WP: borrar transients expirados"
sudo -u www-data wp --path="$WP_DIR" transient delete --expired || \
    warn "  wp transient delete falló"

# --- WordPress: session tokens caducados ---
# Itera wp_usermeta donde meta_key='session_tokens', unserialize, filtra expiration<now,
# escribe de vuelta. Si queda vacío, elimina la fila.
log "WP: purgar session tokens caducados"
sudo -u www-data wp --path="$WP_DIR" eval '
$now = time();
global $wpdb;
$rows = $wpdb->get_results( "SELECT umeta_id, user_id, meta_value FROM {$wpdb->usermeta} WHERE meta_key = \"session_tokens\"" );
$cleaned = 0; $deleted_rows = 0;
foreach ( $rows as $r ) {
    $tokens = maybe_unserialize( $r->meta_value );
    if ( ! is_array( $tokens ) ) { continue; }
    $orig = count( $tokens );
    foreach ( $tokens as $hash => $data ) {
        if ( ! is_array( $data ) || empty( $data["expiration"] ) || $data["expiration"] < $now ) {
            unset( $tokens[ $hash ] );
        }
    }
    if ( count( $tokens ) === $orig ) { continue; }
    if ( empty( $tokens ) ) {
        $wpdb->delete( $wpdb->usermeta, [ "umeta_id" => $r->umeta_id ] );
        $deleted_rows++;
    } else {
        update_user_meta( $r->user_id, "session_tokens", $tokens );
    }
    $cleaned++;
}
echo "  usuarios limpiados: $cleaned, filas eliminadas: $deleted_rows\n";
' || warn "  wp eval session_tokens falló"

# --- Mantis: sesiones >30d ---
if [[ -r "$MYSQL_CNF" ]]; then
    log "Mantis: borrar sesiones >30d"
    # Detectar nombre de DB Mantis (fallback a 'mantisbt')
    DB_MANTIS_NAME="mantisbt"
    [[ -r /var/www/mantis/config/config_inc.php ]] && {
        real=$(grep -oP "\\\$g_database_name\s*=\s*'\K[^']+" /var/www/mantis/config/config_inc.php || true)
        [[ -n "$real" ]] && DB_MANTIS_NAME="$real"
    }
    mysql --defaults-file="$MYSQL_CNF" "$DB_MANTIS_NAME" \
        -e "DELETE FROM mantis_user_session_table WHERE last_active < UNIX_TIMESTAMP(NOW() - INTERVAL 30 DAY);" \
        || warn "  mantis_user_session_table no existe o query falló"
else
    warn "Falta $MYSQL_CNF — se omite purga de Mantis"
fi

# --- rc-tech: tmp/ con mtime > 1 día ---
RC_TMP="$WP_DIR/wp-content/uploads/rc-tech/tmp"
if [[ -d "$RC_TMP" ]]; then
    log "rc-tech: borrar tmp/ con mtime > 1d"
    find "$RC_TMP" -type f -mtime +1 -delete 2>/dev/null || true
fi

log "Purge completado"
