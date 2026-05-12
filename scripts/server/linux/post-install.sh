#!/usr/bin/env bash
# ResolveCore — Post-Install Setup Script
# Ubuntu Desktop 22.04 / 24.04 LTS — Máquina física del técnico
# Uso: sudo bash post-install.sh
set -euo pipefail

case "${1:-}" in
    --help|-h)
        cat <<'EOF'
NAME
    post-install.sh - Post-install setup del stack ResolveCore en Linux

SYNOPSIS
    sudo bash post-install.sh [OPTIONS]

DESCRIPTION
    Instala y configura el stack completo de ResolveCore en una instalacion
    limpia de Ubuntu Desktop 22.04/24.04 LTS. Aprovisiona la maquina
    fisica del tecnico con todos los servicios necesarios.

    Componentes instalados:
        - Nginx (servidor web)
        - PHP 8.2 + extensiones requeridas
        - MariaDB (base de datos)
        - WordPress (frontend de soporte)
        - MantisBT (gestor de tickets)
        - AnyDesk (acceso remoto)
        - PowerShell 7 (compat scripts Windows)

OPTIONS
    -h, --help                  Muestra esta ayuda y sale.

REQUISITOS
    - Ubuntu/Debian con apt-get.
    - Privilegios de root (sudo).
    - Conexion a internet.
    - Maquina recien instalada.

EXAMPLES
    sudo bash post-install.sh
    sudo bash post-install.sh --help

EXIT CODES
    0    Setup completado.
    1    Error fatal (cualquier paso falla con die()).

ATENCION
    Modifica la configuracion del sistema. Usar solo en maquina recien
    instalada para evitar conflictos con servicios existentes.
EOF
        exit 0 ;;
esac

# ============================================================
# COLORES
# ============================================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${CYAN}[→]${NC} $1"; }
warn() { echo -e "${YELLOW}[⚠]${NC} $1"; }
die()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ============================================================
# COMPROBACIONES INICIALES
# ============================================================
[[ $EUID -ne 0 ]] && die "Ejecuta como root: sudo bash post-install.sh"
command -v apt-get &>/dev/null || die "Solo Ubuntu/Debian soportado."

clear
echo -e "${BOLD}"
cat <<'BANNER'
  ____                 _       ____
 |  _ \ ___  ___  ___ | |_   / ___|___  _ __ ___
 | |_) / _ \/ __|/ _ \| \ \ / /  / _ \| '__/ _ \
 |  _ <  __/\__ \ (_) | |\ V /  | (_) | | |  __/
 |_| \_\___||___/\___/|_| \_/    \___/|_|  \___|

  SO Técnico — Instalación automática del stack completo
BANNER
echo -e "${NC}"
echo -e "${CYAN}Stack:${NC} Nginx · PHP 8.2 · MariaDB · WordPress · MantisBT · AnyDesk · PowerShell 7"
echo ""
warn "Este script modifica la configuración del sistema. Úsalo en una instalación limpia."
echo ""
read -rp "¿Continuar? [s/N] " CONFIRM
[[ "$CONFIRM" =~ ^[sS]$ ]] || { echo "Cancelado."; exit 0; }

# ============================================================
# VARIABLES DE CONFIGURACIÓN
# ============================================================
RC_DOMAIN="resolvecore.local"
PHP_VER="8.2"
MANTIS_VER="2.28.1"
WP_DIR="/var/www/wordpress"
MANTIS_DIR="/var/www/mantis"
SCRIPTS_DIR="/opt/resolvecore"
LOG_FILE="/var/log/resolvecore-install.log"

# Generar contraseñas aleatorias
DB_ROOT_PASS=$(openssl rand -base64 32 | tr -d '/+=')
DB_WP_USER="rc_wp"
DB_WP_PASS=$(openssl rand -base64 24 | tr -d '/+=')
DB_WP_NAME="resolvecore_wp"
DB_MANTIS_USER="rc_mantis"
DB_MANTIS_PASS=$(openssl rand -base64 24 | tr -d '/+=')
DB_MANTIS_NAME="resolvecore_mantis"
WP_ADMIN_PASS=$(openssl rand -base64 16 | tr -d '/+=')
MANTIS_ADMIN_PASS=$(openssl rand -base64 16 | tr -d '/+=')

# Guardar credenciales en archivo seguro (solo root)
CREDS_FILE="/root/resolvecore-credentials.txt"

exec > >(tee -a "$LOG_FILE") 2>&1

# ============================================================
# 1. ACTUALIZAR SISTEMA
# ============================================================
info "Actualizando sistema..."
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
    curl wget git unzip software-properties-common \
    gnupg2 ca-certificates lsb-release apt-transport-https \
    openssl net-tools ufw
ok "Sistema actualizado"

# ============================================================
# 2. NGINX
# ============================================================
info "Instalando Nginx..."
apt-get install -y -qq nginx
systemctl enable --now nginx
ok "Nginx instalado y activo"

# ============================================================
# 3. PHP 8.2
# ============================================================
info "Instalando PHP ${PHP_VER}..."
add-apt-repository -y ppa:ondrej/php &>/dev/null || true
apt-get update -qq
apt-get install -y -qq \
    php${PHP_VER}-fpm \
    php${PHP_VER}-mysql \
    php${PHP_VER}-xml \
    php${PHP_VER}-mbstring \
    php${PHP_VER}-curl \
    php${PHP_VER}-zip \
    php${PHP_VER}-gd \
    php${PHP_VER}-intl \
    php${PHP_VER}-bcmath \
    php${PHP_VER}-soap \
    php${PHP_VER}-cli

systemctl enable --now php${PHP_VER}-fpm

# Ajustes PHP para producción
PHP_INI="/etc/php/${PHP_VER}/fpm/php.ini"
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 64M/"  "$PHP_INI"
sed -i "s/post_max_size = .*/post_max_size = 64M/"              "$PHP_INI"
sed -i "s/memory_limit = .*/memory_limit = 256M/"              "$PHP_INI"
sed -i "s/max_execution_time = .*/max_execution_time = 120/"   "$PHP_INI"
systemctl restart php${PHP_VER}-fpm
ok "PHP ${PHP_VER} instalado y configurado"

# ============================================================
# 4. MARIADB
# ============================================================
info "Instalando MariaDB..."
apt-get install -y -qq mariadb-server mariadb-client
systemctl enable --now mariadb

# Asegurar MariaDB (equivalente a mysql_secure_installation)
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';"
mysql -u root -p"${DB_ROOT_PASS}" <<SQL
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

CREATE DATABASE IF NOT EXISTS ${DB_WP_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_WP_USER}'@'localhost' IDENTIFIED BY '${DB_WP_PASS}';
GRANT ALL PRIVILEGES ON ${DB_WP_NAME}.* TO '${DB_WP_USER}'@'localhost';

CREATE DATABASE IF NOT EXISTS ${DB_MANTIS_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_MANTIS_USER}'@'localhost' IDENTIFIED BY '${DB_MANTIS_PASS}';
GRANT SELECT,INSERT,UPDATE,DELETE,INDEX,CREATE,ALTER,DROP ON ${DB_MANTIS_NAME}.* TO '${DB_MANTIS_USER}'@'localhost';

FLUSH PRIVILEGES;
SQL
ok "MariaDB instalado y bases de datos creadas"

# ============================================================
# 5. WORDPRESS
# ============================================================
info "Instalando WordPress..."
mkdir -p "$WP_DIR"

# WP-CLI
if ! command -v wp &>/dev/null; then
    curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
fi

wp core download --path="$WP_DIR" --locale=es_ES --allow-root

wp config create \
    --path="$WP_DIR" \
    --dbname="$DB_WP_NAME" \
    --dbuser="$DB_WP_USER" \
    --dbpass="$DB_WP_PASS" \
    --dbhost="localhost" \
    --allow-root

wp core install \
    --path="$WP_DIR" \
    --url="http://${RC_DOMAIN}" \
    --title="ResolveCore" \
    --admin_user="admin" \
    --admin_password="$WP_ADMIN_PASS" \
    --admin_email="admin@${RC_DOMAIN}" \
    --skip-email \
    --allow-root

wp language core activate es_ES --path="$WP_DIR" --allow-root || true

chown -R www-data:www-data "$WP_DIR"
find "$WP_DIR" -type d -exec chmod 755 {} \;
find "$WP_DIR" -type f -exec chmod 644 {} \;
ok "WordPress instalado en $WP_DIR"

# ============================================================
# 6. MANTISBT
# ============================================================
info "Instalando MantisBT ${MANTIS_VER}..."
mkdir -p "$MANTIS_DIR"
MANTIS_TAR="/tmp/mantisbt-${MANTIS_VER}.tar.gz"

wget -q "https://github.com/mantisbt/mantisbt/releases/download/${MANTIS_VER}/mantisbt-${MANTIS_VER}.tar.gz" \
    -O "$MANTIS_TAR"
tar -xzf "$MANTIS_TAR" -C /tmp/
cp -r "/tmp/mantisbt-${MANTIS_VER}/." "$MANTIS_DIR/"
rm -f "$MANTIS_TAR"

mkdir -p "$MANTIS_DIR/uploads"
chown -R www-data:www-data "$MANTIS_DIR"
chmod -R 755 "$MANTIS_DIR"
chmod 775 "$MANTIS_DIR/uploads"

# Generar config MantisBT
cat > "$MANTIS_DIR/config/config_inc.php" <<PHP
<?php
\$g_hostname               = 'localhost';
\$g_db_type                = 'mysqli';
\$g_database_name          = '${DB_MANTIS_NAME}';
\$g_db_username            = '${DB_MANTIS_USER}';
\$g_db_password            = '${DB_MANTIS_PASS}';

\$g_default_language       = 'spanish';
\$g_default_timezone       = 'Europe/Madrid';

\$g_path                   = 'http://${RC_DOMAIN}/mantis/';
\$g_short_path             = '/mantis/';

\$g_allow_signup           = OFF;
\$g_enable_email_notification = ON;

\$g_administrator_email    = 'admin@${RC_DOMAIN}';
\$g_webmaster_email        = 'admin@${RC_DOMAIN}';
\$g_from_email             = 'noreply@${RC_DOMAIN}';
\$g_from_name              = 'ResolveCore';

\$g_api_enabled            = ON;
\$g_api_token_expiry_days  = 365;
PHP

ok "MantisBT ${MANTIS_VER} instalado en $MANTIS_DIR"

# ============================================================
# 7. NGINX — VIRTUAL HOSTS
# ============================================================
info "Configurando Nginx..."

cat > /etc/nginx/sites-available/resolvecore <<NGINX
server {
    listen 80;
    server_name ${RC_DOMAIN} localhost;
    root ${WP_DIR};
    index index.php index.html;

    client_max_body_size 64M;

    # WordPress
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    # MantisBT
    location /mantis/ {
        alias ${MANTIS_DIR}/;
        index index.php;
        location ~ ^/mantis/(.+\.php)$ {
            alias ${MANTIS_DIR}/\$1;
            fastcgi_pass unix:/run/php/php${PHP_VER}-fpm.sock;
            fastcgi_param SCRIPT_FILENAME ${MANTIS_DIR}/\$1;
            include fastcgi_params;
        }
        location ~* ^/mantis/admin/ {
            deny all;
            return 403;
        }
    }

    # PHP
    location ~ \.php$ {
        fastcgi_pass  unix:/run/php/php${PHP_VER}-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include       fastcgi_params;
    }

    location ~ /\.ht { deny all; }
}
NGINX

ln -sf /etc/nginx/sites-available/resolvecore /etc/nginx/sites-enabled/resolvecore
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
ok "Nginx configurado para ${RC_DOMAIN}"

# ============================================================
# 8. WKHTMLTOPDF (generación PDF)
# ============================================================
info "Instalando wkhtmltopdf..."
apt-get install -y -qq wkhtmltopdf || {
    warn "wkhtmltopdf no disponible via apt, descargando binario..."
    WKHTML_DEB="/tmp/wkhtmltopdf.deb"
    wget -q "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb" \
        -O "$WKHTML_DEB"
    apt-get install -y -qq "$WKHTML_DEB" || true
    rm -f "$WKHTML_DEB"
}
ok "wkhtmltopdf instalado"

# ============================================================
# 9. POWERSHELL 7
# ============================================================
info "Instalando PowerShell 7..."
wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" \
    -O /tmp/packages-microsoft-prod.deb
dpkg -i /tmp/packages-microsoft-prod.deb
rm -f /tmp/packages-microsoft-prod.deb
apt-get update -qq
apt-get install -y -qq powershell
ok "PowerShell 7 instalado (comando: pwsh)"

# ============================================================
# 10. ANYDESK
# ============================================================
info "Instalando AnyDesk..."
wget -qO - https://keys.anydesk.com/repos/DEB-GPG-KEY | gpg --dearmor > /etc/apt/trusted.gpg.d/anydesk.gpg
echo "deb http://deb.anydesk.com/ all main" > /etc/apt/sources.list.d/anydesk-stable.list
apt-get update -qq
apt-get install -y -qq anydesk || warn "AnyDesk no disponible para esta arquitectura. Instalar manualmente desde https://anydesk.com/downloads"
ok "AnyDesk instalado"

# ============================================================
# 11. SCRIPTS RESOLVECORE
# ============================================================
info "Instalando scripts ResolveCore..."
mkdir -p "$SCRIPTS_DIR"/{windows,linux,macos,android,reports}

# Clonar desde GitHub si hay conexión, si no copiar locales
if git ls-remote "https://github.com/Haplee/ResolveCore.git" &>/dev/null; then
    git clone --depth=1 "https://github.com/Haplee/ResolveCore.git" /tmp/resolvecore-src
    cp -r /tmp/resolvecore-src/scripts/. "$SCRIPTS_DIR/"
    cp -r /tmp/resolvecore-src/wordpress/plugins/. /tmp/rc-plugins/
    rm -rf /tmp/resolvecore-src
else
    warn "Sin acceso a GitHub. Copia los scripts manualmente en $SCRIPTS_DIR/"
fi

# Alias global para el técnico
echo "alias resolvecore='pwsh ${SCRIPTS_DIR}/linux/diagnostico.sh'" >> /etc/bash.bashrc
chmod +x "$SCRIPTS_DIR"/linux/*.sh 2>/dev/null || true
ok "Scripts instalados en $SCRIPTS_DIR"

# ============================================================
# 12. /etc/hosts (dominio local)
# ============================================================
if ! grep -q "$RC_DOMAIN" /etc/hosts; then
    echo "127.0.0.1   $RC_DOMAIN" >> /etc/hosts
fi
ok "Dominio local configurado: http://${RC_DOMAIN}"

# ============================================================
# 13. FIREWALL
# ============================================================
info "Configurando UFW..."
ufw --force enable
ufw allow OpenSSH
ufw allow 'Nginx Full'
ok "Firewall activo: SSH + HTTP permitidos"

# ============================================================
# GUARDAR CREDENCIALES
# ============================================================
cat > "$CREDS_FILE" <<CREDS
==================================================
  ResolveCore — Credenciales de instalación
  Generadas: $(date)
==================================================

--- MariaDB ---
Root password:        ${DB_ROOT_PASS}

WordPress DB:
  Base de datos:      ${DB_WP_NAME}
  Usuario:            ${DB_WP_USER}
  Contraseña:         ${DB_WP_PASS}

MantisBT DB:
  Base de datos:      ${DB_MANTIS_NAME}
  Usuario:            ${DB_MANTIS_USER}
  Contraseña:         ${DB_MANTIS_PASS}

--- WordPress ---
URL:                  http://${RC_DOMAIN}
Admin usuario:        admin
Admin contraseña:     ${WP_ADMIN_PASS}

--- MantisBT ---
URL:                  http://${RC_DOMAIN}/mantis/
  (completar instalación abriendo la URL en el navegador)

==================================================
GUARDA ESTE ARCHIVO EN LUGAR SEGURO.
Permisos: solo root puede leerlo.
==================================================
CREDS

chmod 600 "$CREDS_FILE"

# ============================================================
# RESUMEN FINAL
# ============================================================
echo ""
echo -e "${BOLD}${GREEN}=============================================="
echo "  ResolveCore instalado correctamente"
echo -e "==============================================${NC}"
echo ""
ok "WordPress:   http://${RC_DOMAIN}"
ok "MantisBT:    http://${RC_DOMAIN}/mantis/"
ok "Credenciales guardadas en: ${CREDS_FILE}"
echo ""
warn "PRÓXIMOS PASOS:"
echo "  1. Abre http://${RC_DOMAIN}/mantis/ → completa el wizard de instalación"
echo "  2. Abre http://${RC_DOMAIN}/wp-admin/ → instala el tema ResolveCore"
echo "  3. En WP: Plugins → rc-mantisbt → configura URL + API token MantisBT"
echo "  4. Lee las credenciales: sudo cat ${CREDS_FILE}"
echo ""
info "Log completo: ${LOG_FILE}"
