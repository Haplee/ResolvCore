#!/usr/bin/env bash
# =============================================================================
# ResolveCore — Despliegue completo en VPS Ionos (Ubuntu 24.04 LTS)
#
# Monta el stack ResolveCore en un VPS Linux S de Ionos:
#   - nginx + PHP-FPM 8.3 + MariaDB
#   - WordPress en <DOMINIO>            (tema + plugin rc-mantisbt)
#   - MantisBT 2.28.1 en mantis.<DOMINIO>
#   - HTTPS Let's Encrypt para los 3 dominios
#   - Hardening: ufw, fail2ban, ssh sin root + sin password, swap 2 GB
#
# IDEMPOTENTE: re-ejecutable sin romper nada (skip steps ya completados).
#
# Uso (como root):
#   bash deploy-ionos.sh \
#       --domain resolvecore.es \
#       --email  admin@resolvecore.es \
#       --user   franvi \
#       --ssh-pubkey "ssh-ed25519 AAAA... user@host"
#
# Variables sensibles se piden interactivamente si no se pasan por env:
#   WP_DB_PASS, MANTIS_DB_PASS, ADMIN_PASS_DEFAULT
# =============================================================================

set -uo pipefail

# ─── Args ────────────────────────────────────────────────────────────────────
DOMAIN=""
ADMIN_EMAIL=""
DEPLOY_USER=""
SSH_PUBKEY=""
WP_VERSION="latest"
MANTIS_VERSION="2.28.1"
PHP_VERSION="8.3"
SKIP_LETSENCRYPT=false
SKIP_SSH_HARDENING=false

usage() {
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain)              DOMAIN="$2"; shift 2 ;;
        --email)               ADMIN_EMAIL="$2"; shift 2 ;;
        --user)                DEPLOY_USER="$2"; shift 2 ;;
        --ssh-pubkey)          SSH_PUBKEY="$2"; shift 2 ;;
        --skip-letsencrypt)    SKIP_LETSENCRYPT=true; shift ;;
        --skip-ssh-hardening)  SKIP_SSH_HARDENING=true; shift ;;
        -h|--help)             usage 0 ;;
        *) echo "Opción desconocida: $1" >&2; usage 1 ;;
    esac
done

[[ -z "$DOMAIN" || -z "$ADMIN_EMAIL" || -z "$DEPLOY_USER" ]] && {
    echo "ERROR: --domain, --email, --user son obligatorios" >&2
    usage 1
}

[[ "$(id -u)" -ne 0 ]] && { echo "ERROR: ejecutar como root" >&2; exit 1; }

MANTIS_DOMAIN="mantis.${DOMAIN}"
WP_DIR="/var/www/wp"
MANTIS_DIR="/var/www/mantis"
WP_SCHEME="https"
$SKIP_LETSENCRYPT && WP_SCHEME="http"

# ─── Helpers ─────────────────────────────────────────────────────────────────
log()  { printf '\e[1;32m[+]\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m[!]\e[0m %s\n' "$*"; }
err()  { printf '\e[1;31m[x]\e[0m %s\n' "$*" >&2; }

ask_pass() {
    local var="$1" prompt="$2"
    if [[ -z "${!var:-}" ]]; then
        read -rsp "$prompt: " "$var"
        echo
        export "$var"
    fi
}

# ─── Pre-checks ──────────────────────────────────────────────────────────────
log "Verificando sistema..."
. /etc/os-release
[[ "$ID" != "ubuntu" ]] && warn "Probado sólo en Ubuntu. Detectado: $ID $VERSION_ID"

# ─── 1. Actualización del sistema ────────────────────────────────────────────
log "Actualizando paquetes del sistema..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get -y upgrade -qq

# ─── 2. Instalar stack LEMP + utilidades ─────────────────────────────────────
log "Instalando nginx + PHP ${PHP_VERSION} + MariaDB + certbot..."
apt-get install -y -qq \
    nginx mariadb-server \
    php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-xml php${PHP_VERSION}-curl php${PHP_VERSION}-gd \
    php${PHP_VERSION}-zip php${PHP_VERSION}-intl php${PHP_VERSION}-cli \
    php${PHP_VERSION}-bcmath \
    certbot python3-certbot-nginx \
    unzip git ufw fail2ban curl wget

# ─── 3. Usuario non-root + SSH key ───────────────────────────────────────────
if ! id "$DEPLOY_USER" &>/dev/null; then
    log "Creando usuario '$DEPLOY_USER'..."
    adduser --disabled-password --gecos "" "$DEPLOY_USER"
    usermod -aG sudo "$DEPLOY_USER"
else
    log "Usuario '$DEPLOY_USER' ya existe"
fi

if [[ -n "$SSH_PUBKEY" ]]; then
    log "Configurando SSH key para '$DEPLOY_USER'..."
    install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
    if ! grep -qF "$SSH_PUBKEY" "/home/$DEPLOY_USER/.ssh/authorized_keys" 2>/dev/null; then
        echo "$SSH_PUBKEY" >> "/home/$DEPLOY_USER/.ssh/authorized_keys"
    fi
    chown "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh/authorized_keys"
    chmod 600 "/home/$DEPLOY_USER/.ssh/authorized_keys"
fi

# ─── 4. Hardening SSH ────────────────────────────────────────────────────────
if $SKIP_SSH_HARDENING; then
    warn "SKIP: hardening SSH no aplicado (--skip-ssh-hardening)"
else
    log "Hardening SSH (sin root + sin password)..."
    SSHD=/etc/ssh/sshd_config
    [[ -f "$SSHD.bak" ]] || cp "$SSHD" "$SSHD.bak"
    sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/'      "$SSHD"
    sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' "$SSHD"
    sed -i 's/^#*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' "$SSHD"
    systemctl restart ssh
fi

# ─── 5. Firewall ufw ─────────────────────────────────────────────────────────
log "Configurando firewall..."
ufw allow OpenSSH       >/dev/null
ufw allow 'Nginx Full'  >/dev/null
ufw --force enable      >/dev/null
systemctl enable --now fail2ban >/dev/null

# ─── 6. Swap 2 GB (vital para VPS S 2GB) ─────────────────────────────────────
if [[ ! -f /swapfile ]]; then
    log "Creando swap 2 GB..."
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null
    swapon /swapfile
    grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
else
    log "Swap ya configurado"
fi

# ─── 7. MariaDB — DBs + usuarios ─────────────────────────────────────────────
log "Configurando MariaDB..."
ask_pass WP_DB_PASS     "Contraseña para usuario MySQL 'wp_user'"
ask_pass MANTIS_DB_PASS "Contraseña para usuario MySQL 'mantis_user'"

mysql <<SQL
CREATE DATABASE IF NOT EXISTS wp_resolvecore CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS mantisbt        CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'wp_user'@'localhost'     IDENTIFIED BY '${WP_DB_PASS}';
CREATE USER IF NOT EXISTS 'mantis_user'@'localhost' IDENTIFIED BY '${MANTIS_DB_PASS}';

GRANT ALL ON wp_resolvecore.* TO 'wp_user'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE, INDEX, CREATE, ALTER, DROP
      ON mantisbt.* TO 'mantis_user'@'localhost';

FLUSH PRIVILEGES;
SQL

# ─── 8. WordPress core ───────────────────────────────────────────────────────
if [[ ! -f "$WP_DIR/wp-settings.php" ]]; then
    log "Descargando WordPress core..."
    mkdir -p "$WP_DIR"
    cd /tmp
    wget -q "https://wordpress.org/${WP_VERSION}.tar.gz" -O wordpress.tar.gz
    tar -xzf wordpress.tar.gz
    cp -a wordpress/. "$WP_DIR/"
    rm -rf wordpress wordpress.tar.gz
else
    log "WordPress ya instalado en $WP_DIR"
fi

# ─── 9. wp-config.php (con SALT generados + integración Mantis) ──────────────
if [[ ! -f "$WP_DIR/wp-config.php" ]]; then
    log "Generando wp-config.php..."
    SALTS=$(curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/ || true)
    if [[ -z "$SALTS" ]]; then
        warn "No se pudieron obtener SALT de api.wordpress.org — generando localmente"
        SALTS=$(for k in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY \
                         AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
            printf "define( '%s', '%s' );\n" "$k" "$(openssl rand -hex 32)"
        done)
    fi

    cat > "$WP_DIR/wp-config.php" <<EOF
<?php
define( 'DB_NAME',     'wp_resolvecore' );
define( 'DB_USER',     'wp_user' );
define( 'DB_PASSWORD', '${WP_DB_PASS}' );
define( 'DB_HOST',     'localhost' );
define( 'DB_CHARSET',  'utf8mb4' );
define( 'DB_COLLATE',  '' );

${SALTS}

\$table_prefix = 'wp_';

define( 'WP_DEBUG', false );
define( 'WP_ENVIRONMENT_TYPE', 'production' );

define( 'WP_HOME',    '${WP_SCHEME}://${DOMAIN}' );
define( 'WP_SITEURL', '${WP_SCHEME}://${DOMAIN}' );

// Integración MantisBT
define( 'RC_MANTIS_URL',        '${WP_SCHEME}://${MANTIS_DOMAIN}' );
define( 'RC_MANTIS_TOKEN',      'REPLACE_AFTER_MANTIS_SETUP' );
define( 'RC_MANTIS_PROJECT_ID', 1 );

if ( ! defined( 'ABSPATH' ) ) define( 'ABSPATH', __DIR__ . '/' );
require_once ABSPATH . 'wp-settings.php';
EOF
    chmod 640 "$WP_DIR/wp-config.php"
else
    log "wp-config.php ya existe — no se sobrescribe"
fi

# ─── 10. Tema + plugin del repo ──────────────────────────────────────────────
REPO_PATH="${REPO_PATH:-/opt/resolvecore-source}"
if [[ -d "$REPO_PATH/wordpress/resolvecore-theme" ]]; then
    log "Desplegando tema + plugin desde $REPO_PATH..."
    rsync -a --delete "$REPO_PATH/wordpress/resolvecore-theme/"  "$WP_DIR/wp-content/themes/resolvecore-theme/"
    rsync -a --delete "$REPO_PATH/wordpress/plugins/rc-mantisbt/" "$WP_DIR/wp-content/plugins/rc-mantisbt/"
else
    warn "REPO_PATH=$REPO_PATH no contiene wordpress/. Sube tema y plugin manualmente:"
    warn "  scp -r wordpress/resolvecore-theme       ${DEPLOY_USER}@<IP>:/tmp/"
    warn "  scp -r wordpress/plugins/rc-mantisbt     ${DEPLOY_USER}@<IP>:/tmp/"
    warn "  mv /tmp/resolvecore-theme  $WP_DIR/wp-content/themes/"
    warn "  mv /tmp/rc-mantisbt        $WP_DIR/wp-content/plugins/"
fi

chown -R www-data:www-data "$WP_DIR"
find "$WP_DIR" -type d -exec chmod 755 {} +
find "$WP_DIR" -type f -exec chmod 644 {} +
chmod 640 "$WP_DIR/wp-config.php"

# ─── 11. MantisBT 2.28.1 ─────────────────────────────────────────────────────
if [[ ! -f "$MANTIS_DIR/admin/install.php" ]]; then
    log "Descargando MantisBT ${MANTIS_VERSION}..."
    mkdir -p "$MANTIS_DIR"
    cd /tmp
    wget -q "https://github.com/mantisbt/mantisbt/releases/download/${MANTIS_VERSION}/mantisbt-${MANTIS_VERSION}.tar.gz"
    tar -xzf "mantisbt-${MANTIS_VERSION}.tar.gz"
    cp -a "mantisbt-${MANTIS_VERSION}/." "$MANTIS_DIR/"
    rm -rf "mantisbt-${MANTIS_VERSION}" "mantisbt-${MANTIS_VERSION}.tar.gz"
    mkdir -p "$MANTIS_DIR/uploads"
else
    log "MantisBT ya instalado en $MANTIS_DIR"
fi

chown -R www-data:www-data "$MANTIS_DIR"
chmod 755 "$MANTIS_DIR/uploads"

# ─── 12. Nginx vhosts ────────────────────────────────────────────────────────
log "Generando vhosts nginx..."

cat > /etc/nginx/sites-available/resolvecore.conf <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};
    root ${WP_DIR};
    index index.php index.html;

    client_max_body_size 25M;
    access_log /var/log/nginx/${DOMAIN}.access.log;
    error_log  /var/log/nginx/${DOMAIN}.error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
        fastcgi_read_timeout 60s;
    }

    # Bloqueos de seguridad
    location ~ /\.(ht|git|env) { deny all; return 404; }
    location = /xmlrpc.php     { deny all; return 404; }
    location ~* /wp-config\.php { deny all; return 404; }

    # Cache estáticos
    location ~* \.(?:css|js|jpg|jpeg|gif|png|svg|webp|woff2?|ttf|ico)\$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
}
NGINX

cat > /etc/nginx/sites-available/mantis.conf <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${MANTIS_DOMAIN};
    root ${MANTIS_DIR};
    index index.php;

    client_max_body_size 10M;
    access_log /var/log/nginx/${MANTIS_DOMAIN}.access.log;
    error_log  /var/log/nginx/${MANTIS_DOMAIN}.error.log;

    location / { try_files \$uri \$uri/ =404; }

    location ~ \.php\$ {
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # Bloqueo /admin/ tras instalación inicial — descomentar:
    # location ~* ^/admin/(?!check\.php|check_install\.php) { deny all; return 404; }

    location ~ /\.(ht|git) { deny all; return 404; }
    location ~* config_inc\.php { deny all; return 404; }
}
NGINX

ln -sf /etc/nginx/sites-available/resolvecore.conf /etc/nginx/sites-enabled/resolvecore.conf
ln -sf /etc/nginx/sites-available/mantis.conf      /etc/nginx/sites-enabled/mantis.conf
rm -f /etc/nginx/sites-enabled/default

if nginx -t 2>/dev/null; then
    systemctl reload nginx
    log "Nginx recargado"
else
    err "nginx -t falló — revisar /etc/nginx/sites-available/*.conf"
    nginx -t
    exit 1
fi

# ─── 13. Tuning PHP-FPM para VPS S (2 GB RAM) ────────────────────────────────
log "Tuning PHP-FPM (pool www) para 2 GB RAM..."
POOL=/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
sed -i 's/^pm = .*/pm = ondemand/'                  "$POOL"
sed -i 's/^pm.max_children = .*/pm.max_children = 8/' "$POOL"
sed -i 's/^;pm.process_idle_timeout = .*/pm.process_idle_timeout = 10s/' "$POOL"
sed -i 's/^;pm.max_requests = .*/pm.max_requests = 500/' "$POOL"

PHP_INI=/etc/php/${PHP_VERSION}/fpm/php.ini
sed -i 's/^memory_limit = .*/memory_limit = 256M/'        "$PHP_INI"
sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 25M/' "$PHP_INI"
sed -i 's/^post_max_size = .*/post_max_size = 25M/'       "$PHP_INI"
sed -i 's/^max_execution_time = .*/max_execution_time = 60/' "$PHP_INI"
systemctl restart php${PHP_VERSION}-fpm

# ─── 14. Let's Encrypt ───────────────────────────────────────────────────────
if $SKIP_LETSENCRYPT; then
    warn "SKIP: Let's Encrypt no aplicado (--skip-letsencrypt). Para emitir luego:"
    warn "    certbot --nginx --non-interactive --agree-tos -m ${ADMIN_EMAIL} \\"
    warn "        -d ${DOMAIN} -d www.${DOMAIN} -d ${MANTIS_DOMAIN} --redirect"
else
    log "Comprobando DNS antes de pedir certificados..."
    SERVER_IP=$(curl -fsSL https://api.ipify.org || hostname -I | awk '{print $1}')
    DOMAIN_IP=$(getent ahostsv4 "${DOMAIN}" 2>/dev/null | awk 'NR==1{print $1}')
    if [[ "$DOMAIN_IP" != "$SERVER_IP" ]]; then
        warn "DNS ${DOMAIN} apunta a '${DOMAIN_IP:-<vacío>}' pero VPS es '${SERVER_IP}'."
        warn "Configura A records y re-ejecuta con --skip-letsencrypt=false. Saltando."
    else
        log "Solicitando certificados Let's Encrypt..."
        if ! certbot certificates 2>/dev/null | grep -q "${DOMAIN}"; then
            certbot --nginx --non-interactive --agree-tos \
                -m "${ADMIN_EMAIL}" \
                -d "${DOMAIN}" -d "www.${DOMAIN}" -d "${MANTIS_DOMAIN}" \
                --redirect || warn "Certbot falló — revisar DNS y reintentar"
        else
            log "Certificados ya emitidos para ${DOMAIN}"
        fi
    fi
fi

# ─── 15. Cron MantisBT (notificaciones email) ────────────────────────────────
CRON=/etc/cron.d/mantis-resolvecore
cat > "$CRON" <<CRON
# ResolveCore — Mantis cron jobs
MAILTO=""
*/5 * * * * www-data /usr/bin/php ${MANTIS_DIR}/scripts/send_emails.php >/dev/null 2>&1
0   2 * * * www-data /usr/bin/php ${MANTIS_DIR}/admin/schema.php       >/dev/null 2>&1
CRON
chmod 644 "$CRON"

# ─── 16. Resumen final ───────────────────────────────────────────────────────
cat <<DONE

╔══════════════════════════════════════════════════════════════════╗
║  DESPLIEGUE RESOLVECORE — COMPLETADO                            ║
╠══════════════════════════════════════════════════════════════════╣
║  Sitio WP        https://${DOMAIN}
║  Admin WP        https://${DOMAIN}/wp-admin/install.php  (paso final manual)
║  MantisBT        https://${MANTIS_DOMAIN}
║  Mantis install  https://${MANTIS_DOMAIN}/admin/install.php
║
║  PRÓXIMOS PASOS (orden estricto):
║    1. Abrir https://${DOMAIN}/wp-admin/install.php
║       → completar wizard WP (título, admin user, password)
║       → activar tema 'ResolveCore' + plugin 'rc-mantisbt'
║
║    2. Abrir https://${MANTIS_DOMAIN}/admin/install.php
║       → DB: mantisbt / mantis_user / <MANTIS_DB_PASS>
║       → admin login default: administrator / root (CAMBIAR INMEDIATO)
║
║    3. En Mantis: Gestionar > Proyectos > "Incidencias" (ID=1)
║       Aplicar custom fields:
║         mysql -uroot -p mantisbt < ${REPO_PATH:-/opt/resolvecore-source}/mantisbt/sql/resolvecore-setup.sql
║
║    4. Crear API token en Mantis > Mi cuenta > API Tokens
║       Editar ${WP_DIR}/wp-config.php:
║         define('RC_MANTIS_TOKEN', '<TOKEN_AQUI>');
║
║    5. WP Admin > Ajustes > MantisBT > marcar "Activar integración"
║
║    6. Test: enviar formulario contacto en https://${DOMAIN}
║       → ticket debe aparecer en https://${MANTIS_DOMAIN}
║
║  HARDENING ADICIONAL (después del install wizard de Mantis):
║    - Editar /etc/nginx/sites-available/mantis.conf
║      → descomentar location ~* ^/admin/ ...
║    - systemctl reload nginx
╚══════════════════════════════════════════════════════════════════╝

DONE
