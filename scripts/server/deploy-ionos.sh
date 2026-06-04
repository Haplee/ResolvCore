#!/usr/bin/env bash
# Autor:   Francisco Vidal Mateo (GitHub: Haplee)
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Aprovisionamiento inicial del VPS de IONOS.
#
# Deja un Ubuntu recién instalado listo para servir WordPress + MantisBT:
# paquetes, swap, bases de datos, nginx, certificados Let's Encrypt y firewall.
#
# Se ejecuta UNA vez al levantar el servidor. Es idempotente en lo posible
# (IF NOT EXISTS, comprobaciones de carpeta), así que repetirlo no rompe nada.
#
# Uso (como root):
#     bash deploy-ionos.sh <dominio> <email> <usuario-deploy>
#
# Ejemplo:
#     bash deploy-ionos.sh resolvecore.website fvidalmateo@gmail.com franvi
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

log()  { printf '\e[1;32m[+]\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m[!]\e[0m %s\n' "$*"; }
err()  { printf '\e[1;31m[x]\e[0m %s\n' "$*" >&2; }

if [ "$EUID" -ne 0 ]; then
    err "Este script tiene que correr como root."
    exit 1
fi

if [ "$#" -lt 3 ]; then
    echo "Uso: $0 <dominio> <email> <usuario-deploy>"
    exit 1
fi

DOMAIN="$1"
EMAIL="$2"
# shellcheck disable=SC2034  # reservado para el TODO de automatizar wp-config.php
DEPLOY_USER="$3"
PHP_VERSION="8.3"


# ── Paquetes base ───────────────────────────────────────────────────────────
# Stack completo: nginx + PHP-FPM con las extensiones que piden WP y Mantis,
# MariaDB, certbot para TLS y fail2ban/ufw para endurecer el SSH.

log "Instalando paquetes del sistema..."
apt-get update -q
apt-get install -y -q \
    nginx "php${PHP_VERSION}-fpm" "php${PHP_VERSION}-mysql" "php${PHP_VERSION}-curl" \
    "php${PHP_VERSION}-xml" "php${PHP_VERSION}-mbstring" "php${PHP_VERSION}-zip" \
    "php${PHP_VERSION}-gd" \
    mariadb-server certbot python3-certbot-nginx fail2ban ufw unzip curl


# ── Swap ────────────────────────────────────────────────────────────────────
# El VPS más barato de IONOS va corto de RAM; 2G de swap evitan que el
# OOM-killer se cargue mysqld bajo carga.

if [ ! -f /swapfile ]; then
    log "Creando swap de 2G..."
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi


# ── Bases de datos y credenciales ───────────────────────────────────────────
# Generamos las contraseñas al vuelo y las guardamos en /etc/resolvecore/env
# con permisos 600. NUNCA van a git ni se imprimen por pantalla.

mkdir -p /etc/resolvecore
WP_DB_PASS=$(openssl rand -base64 16)
MANTIS_DB_PASS=$(openssl rand -base64 16)

log "Creando bases de datos y usuarios MariaDB..."
mysql -e "CREATE DATABASE IF NOT EXISTS wp_resolvecore;"
mysql -e "CREATE DATABASE IF NOT EXISTS mantisbt;"
mysql -e "CREATE USER IF NOT EXISTS 'wp'@'localhost' IDENTIFIED BY '${WP_DB_PASS}'; GRANT ALL ON wp_resolvecore.* TO 'wp'@'localhost';"
mysql -e "CREATE USER IF NOT EXISTS 'mantis'@'localhost' IDENTIFIED BY '${MANTIS_DB_PASS}'; GRANT ALL ON mantisbt.* TO 'mantis'@'localhost';"

printf 'WP_DB_PASS=%s\nMANTIS_DB_PASS=%s\nRC_DOMAIN=%s\n' \
    "$WP_DB_PASS" "$MANTIS_DB_PASS" "$DOMAIN" > /etc/resolvecore/env
chmod 600 /etc/resolvecore/env


# ── Código de las aplicaciones ──────────────────────────────────────────────
# Solo descargamos si la carpeta no existe, para no pisar una instalación ya
# configurada al re-ejecutar el script.

if [ ! -d /var/www/wp ]; then
    log "Descargando WordPress..."
    curl -s https://wordpress.org/latest.tar.gz | tar -xz -C /var/www/
    mv /var/www/wordpress /var/www/wp
    chown -R www-data:www-data /var/www/wp
fi

if [ ! -d /var/www/mantis ]; then
    log "Descargando MantisBT 2.28.1..."
    curl -sL "https://github.com/mantisbt/mantisbt/releases/download/2.28.1/mantisbt-2.28.1.tar.gz" \
        | tar -xz -C /var/www/
    mv /var/www/mantisbt-2.28.1 /var/www/mantis
    chown -R www-data:www-data /var/www/mantis
fi


# ── Nginx ───────────────────────────────────────────────────────────────────
# Dos server blocks: el dominio principal sirve WordPress, el subdominio
# mantis. sirve MantisBT. Certbot reescribe esto luego para añadir el 443.

log "Configurando nginx..."
cat > /etc/nginx/sites-available/resolvecore <<NGINX
server {
    listen 80; server_name ${DOMAIN} www.${DOMAIN};
    root /var/www/wp; index index.php;
    location / { try_files \$uri \$uri/ /index.php?\$args; }
    location ~ \.php$ { fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock; include fastcgi_params; fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name; }
}
server {
    listen 80; server_name mantis.${DOMAIN};
    root /var/www/mantis; index index.php;
    
    # Corrige bug de MantisBT: \$g_logo_url absoluto -> Mantis antepone su path ->
    # href="/https://dominio" -> nginx 404. No se puede capturar el esquema con
    # ^/(https?://.*) porque merge_slashes (ON por defecto) colapsa // -> / antes
    # del match. El enlace de marca siempre va a la home: hardcodeamos destino.
    location ~ ^/https { return 301 https://${DOMAIN}; }
    
    location / { try_files \$uri \$uri/ /index.php?\$args; }
    location ~ \.php$ { fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock; include fastcgi_params; fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name; }
}
NGINX

ln -sf /etc/nginx/sites-available/resolvecore /etc/nginx/sites-enabled/resolvecore
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx


# ── TLS y firewall ──────────────────────────────────────────────────────────

log "Solicitando certificados TLS..."
certbot --nginx -d "${DOMAIN}" -d "www.${DOMAIN}" -d "mantis.${DOMAIN}" \
    --email "${EMAIL}" --agree-tos --non-interactive

log "Activando firewall (ufw)..."
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'

# TODO: automatizar wp-config.php + config_inc.php tirando de /etc/resolvecore/env
#       para no tener que rellenarlos a mano tras este script.

log "Deploy OK — https://${DOMAIN} | https://mantis.${DOMAIN}"
log "Credenciales guardadas en /etc/resolvecore/env (perms 600)"
