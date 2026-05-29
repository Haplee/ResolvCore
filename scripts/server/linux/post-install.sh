#!/usr/bin/env bash
# Autor:   Francisco Vidal Mateo (GitHub: Haplee)
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Post-instalación para entorno de DESARROLLO Linux.
#
# Monta un stack local parecido al del VPS pero con credenciales de pega,
# más AnyDesk y PowerShell para poder probar los scripts del técnico.
#
# OJO: las contraseñas de BBDD aquí son fijas y triviales (wp_dev / mantis_dev)
#      a propósito — es solo para local. NO usar este script en producción;
#      para el VPS está deploy-ionos.sh.
#
# Uso (como root):
#     bash post-install.sh
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Requiere root" >&2
    exit 1
fi

PHP_VERSION="8.2"


# ── Paquetes ────────────────────────────────────────────────────────────────

echo "[+] Instalando stack web (PHP ${PHP_VERSION}, nginx, MariaDB)..."
apt-get update -q
apt-get install -y -q \
    nginx "php${PHP_VERSION}-fpm" "php${PHP_VERSION}-mysql" "php${PHP_VERSION}-curl" \
    "php${PHP_VERSION}-xml" "php${PHP_VERSION}-mbstring" "php${PHP_VERSION}-zip" \
    "php${PHP_VERSION}-gd" \
    mariadb-server unzip curl wget git


# ── Bases de datos de desarrollo ────────────────────────────────────────────
# Credenciales fijas solo válidas en local (ver aviso de cabecera).

echo "[+] Creando bases de datos de desarrollo..."
mysql -e "CREATE DATABASE IF NOT EXISTS wp_resolvecore; CREATE DATABASE IF NOT EXISTS mantisbt;"
mysql -e "CREATE USER IF NOT EXISTS 'wp'@'localhost' IDENTIFIED BY 'wp_dev'; GRANT ALL ON wp_resolvecore.* TO 'wp'@'localhost';"
mysql -e "CREATE USER IF NOT EXISTS 'mantis'@'localhost' IDENTIFIED BY 'mantis_dev'; GRANT ALL ON mantisbt.* TO 'mantis'@'localhost';"


# ── Código de las aplicaciones ──────────────────────────────────────────────

if [ ! -d /var/www/wp ]; then
    echo "[+] Descargando WordPress..."
    curl -s https://wordpress.org/latest.tar.gz | tar -xz -C /var/www/
    mv /var/www/wordpress /var/www/wp
    chown -R www-data:www-data /var/www/wp
fi

if [ ! -d /var/www/mantis ]; then
    echo "[+] Descargando MantisBT 2.28.1..."
    curl -sL "https://github.com/mantisbt/mantisbt/releases/download/2.28.1/mantisbt-2.28.1.tar.gz" \
        | tar -xz -C /var/www/
    mv /var/www/mantisbt-2.28.1 /var/www/mantis
    chown -R www-data:www-data /var/www/mantis
fi


# ── Herramientas del técnico ────────────────────────────────────────────────
# AnyDesk para el acceso remoto y PowerShell para correr en Linux los mismos
# scripts de diagnóstico que en Windows.

if ! command -v anydesk >/dev/null 2>&1; then
    echo "[+] Instalando AnyDesk..."
    curl -fsSL https://keys.anydesk.com/repos/DEB-GPG-KEY | gpg --dearmor -o /usr/share/keyrings/anydesk.gpg
    echo "deb [signed-by=/usr/share/keyrings/anydesk.gpg] http://deb.anydesk.com/ all main" > /etc/apt/sources.list.d/anydesk.list
    apt-get update -q && apt-get install -y -q anydesk
fi

if ! command -v pwsh >/dev/null 2>&1; then
    echo "[+] Instalando PowerShell..."
    curl -fsSL "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" -o /tmp/ms.deb
    dpkg -i /tmp/ms.deb && apt-get update -q && apt-get install -y -q powershell
fi

systemctl enable --now nginx "php${PHP_VERSION}-fpm" mariadb
echo "[+] Post-install completado."
