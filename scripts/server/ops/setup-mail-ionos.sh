#!/usr/bin/env bash
#
# setup-mail-ionos.sh — Configura el correo saliente del VPS vía msmtp + IONOS.
#
# WordPress (wp_mail) usa la función mail() de PHP, que necesita un binario
# tipo sendmail. Aquí instalamos msmtp y lo cableamos como sendmail apuntando
# al relay SMTP de IONOS, autenticado con un buzón del dominio. Sin esto los
# emails de activación de cuenta y de «He olvidado mi contraseña» no salen.
#
# La contraseña se pasa por argumento (NO se versiona en el repo) y queda solo
# en /etc/msmtprc con permisos 0640 root:www-data.
#
# Uso (como root en el VPS):
#   bash setup-mail-ionos.sh <buzon-completo> '<password>' [host] [puerto]
# Ejemplo:
#   bash setup-mail-ionos.sh no-reply@resolvecore.website 'MiClave' smtp.ionos.es 587
#
# Tras ejecutarlo, prueba el envío con:
#   echo -e "Subject: prueba\n\nhola" | msmtp -a default tu-correo-personal@gmail.com

set -euo pipefail

MAILBOX="${1:-}"
PASSWORD="${2:-}"
HOST="${3:-smtp.ionos.es}"
PORT="${4:-587}"

if [ -z "$MAILBOX" ] || [ -z "$PASSWORD" ]; then
	echo "Uso: $0 <buzon-completo> '<password>' [host] [puerto]" >&2
	echo "Ej.: $0 no-reply@resolvecore.website 'MiClave' smtp.ionos.es 587" >&2
	exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
	echo "Este script debe ejecutarse como root." >&2
	exit 1
fi

# 1) Instala msmtp (cliente SMTP) si falta.
if ! command -v msmtp >/dev/null 2>&1; then
	echo "[+] Instalando msmtp…"
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -qq
	apt-get install -y -qq msmtp msmtp-mta ca-certificates
else
	echo "[=] msmtp ya instalado."
fi

# 2) Escribe /etc/msmtprc (config global). Contiene la password → 0640 root:www-data.
echo "[+] Escribiendo /etc/msmtprc…"
cat > /etc/msmtprc <<EOF
# Generado por setup-mail-ionos.sh — relay SMTP de IONOS para wp_mail().
defaults
auth           on
tls            on
tls_starttls   on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        ionos
host           ${HOST}
port           ${PORT}
from           ${MAILBOX}
user           ${MAILBOX}
password       ${PASSWORD}

account default : ionos
EOF

# www-data (PHP-FPM) tiene que poder leerlo para autenticar el relay.
chown root:www-data /etc/msmtprc
chmod 0640 /etc/msmtprc

# Log legible/escribible por msmtp lanzado desde www-data.
touch /var/log/msmtp.log
chown root:www-data /var/log/msmtp.log
chmod 0660 /var/log/msmtp.log

# 3) Apunta PHP (CLI + FPM 8.3) a msmtp como sendmail.
SENDMAIL_PATH="/usr/bin/msmtp -t -i"
for INI_DIR in /etc/php/8.3/fpm/conf.d /etc/php/8.3/cli/conf.d; do
	if [ -d "$INI_DIR" ]; then
		echo "[+] sendmail_path en ${INI_DIR}/99-resolvecore-mail.ini"
		cat > "${INI_DIR}/99-resolvecore-mail.ini" <<EOF
; ResolveCore — enrutar mail() a msmtp (relay IONOS)
sendmail_path = "${SENDMAIL_PATH}"
EOF
	fi
done

# 4) Recarga PHP-FPM para tomar el sendmail_path.
if systemctl is-active --quiet php8.3-fpm; then
	echo "[+] Recargando php8.3-fpm…"
	systemctl reload php8.3-fpm
fi

echo "[✓] Correo configurado. From = ${MAILBOX} vía ${HOST}:${PORT}."
echo "    Prueba:  echo -e 'Subject: prueba\\n\\nhola' | msmtp -a default TU_CORREO_PERSONAL"
echo "    Asegúrate de que admin_email de WordPress = ${MAILBOX} (filtro wp_mail_from ya lo usa de From)."
