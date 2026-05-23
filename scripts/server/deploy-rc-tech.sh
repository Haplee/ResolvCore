#!/usr/bin/env bash
# deploy-rc-tech.sh — Despliega rc-tech v0.1.0 en /var/www/wp del VPS Ionos.
# Idempotente. Sin --confirm-destructive porque no borra nada (solo añade plugin).
#
# Uso (en el VPS):
#   sudo bash deploy-rc-tech.sh /tmp/rc-tech-0.1.0.tar.gz
#
# Pasos:
#   1) Extrae tarball en /var/www/wp/wp-content/plugins/rc-tech/
#   2) Ajusta ownership www-data:www-data + perms 0644/0755
#   3) wp plugin activate rc-tech
#   4) Verifica cron rc_tech_sla_check programado
#   5) Crea capability rc_tech para el rol administrator (lo hace el activation hook)

set -uo pipefail

TARBALL="${1:-/tmp/rc-tech-0.1.0.tar.gz}"
WP_ROOT="/var/www/wp"
PLUGINS_DIR="${WP_ROOT}/wp-content/plugins"
TARGET_DIR="${PLUGINS_DIR}/rc-tech"

command -v wp >/dev/null || { echo "ERROR: wp-cli no instalado"; exit 1; }
[[ -r "$TARBALL" ]] || { echo "ERROR: tarball ilegible: $TARBALL"; exit 1; }
[[ -d "$WP_ROOT" ]] || { echo "ERROR: WP root no existe: $WP_ROOT"; exit 1; }

echo "==> Extrayendo $TARBALL → $PLUGINS_DIR"
# Si existe versión previa, hacer backup con timestamp
if [[ -d "$TARGET_DIR" ]]; then
    BAK="${TARGET_DIR}.bak.$(date +%Y%m%d-%H%M%S)"
    echo "    rc-tech previo detectado → backup en $BAK"
    mv "$TARGET_DIR" "$BAK"
fi
tar -xzf "$TARBALL" -C "$PLUGINS_DIR"

echo "==> Ajustando permisos"
chown -R www-data:www-data "$TARGET_DIR"
find "$TARGET_DIR" -type d -exec chmod 0755 {} \;
find "$TARGET_DIR" -type f -exec chmod 0644 {} \;

echo "==> Activando plugin"
sudo -u www-data wp --path="$WP_ROOT" plugin activate rc-tech

echo "==> Verificando cron"
sudo -u www-data wp --path="$WP_ROOT" cron event list | grep rc_tech || echo "  (cron no encontrado, revisar activación)"

echo "==> Verificando tabla wp_rc_tech_alerts"
sudo -u www-data wp --path="$WP_ROOT" db query "SHOW TABLES LIKE 'wp_rc_tech_alerts'"

echo "==> Listo. Abrir: https://$(hostname -f)/wp-admin/admin.php?page=rc-tech"
