#!/usr/bin/env bash
# =============================================================================
# ResolveCore — Configuración de correo saliente con SPF/DKIM/DMARC
#
# Instala y configura Postfix + OpenDKIM en el VPS para que los correos de
# confirmación de ticket (wp_mail) lleguen a la bandeja de entrada y no a spam.
#
# Uso:
#   sudo bash scripts/server/setup-mail-dkim.sh --domain resolvecore.es
#   sudo bash scripts/server/setup-mail-dkim.sh --domain resolvecore.es --selector rc
#   sudo bash scripts/server/setup-mail-dkim.sh --domain resolvecore.es --check
#
#   # Relay saliente vía smarthost — necesario en VPS que bloquean el puerto 25
#   # saliente (Ionos lo hace por defecto). Pide usuario y contraseña del buzón
#   # de forma interactiva; la contraseña NO se pasa por la línea de comandos.
#   sudo bash scripts/server/setup-mail-dkim.sh --domain resolvecore.es \
#        --relayhost smtp.ionos.es:587
#
# Tras ejecutarlo, imprime los 3 registros DNS (SPF/DKIM/DMARC) que hay que
# crear en el panel de Ionos. Ver docs/tecnica/correo-dkim.md.
#
# Requisitos: Debian/Ubuntu, root, apt.
# =============================================================================

set -euo pipefail

DOMAIN=""
SELECTOR="rc"
CHECK_ONLY=false
RELAYHOST=""

# ── Helpers ──────────────────────────────────────────────────────────────────
info()  { printf '  \033[0;36m▸\033[0m %s\n' "$*"; }
ok()    { printf '  \033[0;32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[1;33m!\033[0m %s\n' "$*"; }
fail()  { printf '  \033[0;31m✗\033[0m %s\n' "$*" >&2; }

# ── Args ─────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain)    DOMAIN="${2:-}"; shift 2 ;;
        --selector)  SELECTOR="${2:-}"; shift 2 ;;
        --relayhost) RELAYHOST="${2:-}"; shift 2 ;;
        --check)     CHECK_ONLY=true; shift ;;
        -h|--help)
            sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) fail "Opción desconocida: $1"; exit 2 ;;
    esac
done

if [[ -z "$DOMAIN" ]]; then
    fail "Falta --domain <dominio>. Ej: --domain resolvecore.es"
    exit 2
fi

if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    fail "Dominio no válido: $DOMAIN"
    exit 2
fi

if [[ ! "$SELECTOR" =~ ^[a-zA-Z0-9]+$ ]]; then
    fail "Selector no válido (solo alfanumérico): $SELECTOR"
    exit 2
fi

if [[ -n "$RELAYHOST" && ! "$RELAYHOST" =~ ^[a-zA-Z0-9.-]+:[0-9]+$ ]]; then
    fail "Relayhost no válido. Formato esperado HOST:PUERTO. Ej: smtp.ionos.es:587"
    exit 2
fi

KEY_DIR="/etc/opendkim/keys/${DOMAIN}"
PRIVATE_KEY="${KEY_DIR}/${SELECTOR}.private"
PUBLIC_TXT="${KEY_DIR}/${SELECTOR}.txt"

# ── Modo --check ─────────────────────────────────────────────────────────────
if [[ "$CHECK_ONLY" == "true" ]]; then
    info "Verificando configuración para ${DOMAIN}…"
    [[ -f "$PRIVATE_KEY" ]] && ok "Clave DKIM presente: $PRIVATE_KEY" || fail "Falta clave DKIM"
    systemctl is-active --quiet opendkim && ok "opendkim activo" || fail "opendkim inactivo"
    systemctl is-active --quiet postfix  && ok "postfix activo"  || fail "postfix inactivo"
    [[ -f "$PUBLIC_TXT" ]] && { echo ""; info "Registro DKIM TXT:"; cat "$PUBLIC_TXT"; }
    exit 0
fi

# ── Comprobaciones previas ───────────────────────────────────────────────────
if [[ "$(id -u)" -ne 0 ]]; then
    fail "Ejecuta como root (sudo)."
    exit 1
fi
command -v apt-get >/dev/null 2>&1 || { fail "Este script requiere apt (Debian/Ubuntu)."; exit 1; }

# ── Instalación de paquetes ──────────────────────────────────────────────────
info "Instalando postfix, opendkim y opendkim-tools…"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq postfix opendkim opendkim-tools
ok "Paquetes instalados"

# ── Generación de la clave DKIM ──────────────────────────────────────────────
mkdir -p "$KEY_DIR"
if [[ -f "$PRIVATE_KEY" ]]; then
    warn "Clave DKIM ya existe en ${PRIVATE_KEY} — se conserva."
else
    info "Generando clave DKIM 2048 bits (selector: ${SELECTOR})…"
    opendkim-genkey --bits=2048 --selector="$SELECTOR" --domain="$DOMAIN" --directory="$KEY_DIR"
    ok "Clave generada en ${KEY_DIR}"
fi
chown -R opendkim:opendkim /etc/opendkim
chmod 600 "$PRIVATE_KEY"

# ── Configuración de OpenDKIM ────────────────────────────────────────────────
info "Escribiendo /etc/opendkim.conf…"
cat > /etc/opendkim.conf <<EOF
# Generado por ResolveCore setup-mail-dkim.sh
Syslog                  yes
UMask                   002
Mode                    sv
OversignHeaders         From
Canonicalization        relaxed/simple
SubDomains              no
KeyTable                /etc/opendkim/KeyTable
SigningTable            refile:/etc/opendkim/SigningTable
ExternalIgnoreList      /etc/opendkim/TrustedHosts
InternalHosts           /etc/opendkim/TrustedHosts
Socket                  inet:8891@localhost
PidFile                 /run/opendkim/opendkim.pid
UserID                  opendkim
EOF

cat > /etc/opendkim/KeyTable <<EOF
${SELECTOR}._domainkey.${DOMAIN} ${DOMAIN}:${SELECTOR}:${PRIVATE_KEY}
EOF

cat > /etc/opendkim/SigningTable <<EOF
*@${DOMAIN} ${SELECTOR}._domainkey.${DOMAIN}
EOF

cat > /etc/opendkim/TrustedHosts <<EOF
127.0.0.1
localhost
::1
${DOMAIN}
EOF

chown -R opendkim:opendkim /etc/opendkim
ok "OpenDKIM configurado"

# ── Conectar Postfix a OpenDKIM ──────────────────────────────────────────────
info "Conectando Postfix al milter OpenDKIM…"
postconf -e "milter_default_action = accept"
postconf -e "milter_protocol = 6"
postconf -e "smtpd_milters = inet:localhost:8891"
postconf -e "non_smtpd_milters = inet:localhost:8891"
# myhostname usa el subdominio mail.* a propósito: si fuese el dominio raíz,
# Postfix lo metería en mydestination y entregaría LOCALMENTE el correo a
# buzones del dominio (p.ej. tecnicos@dominio), que en realidad viven en el
# proveedor de correo externo — rebotaría con "unknown user".
postconf -e "myhostname = mail.${DOMAIN}"
ok "Postfix configurado"

# ── Relay saliente vía smarthost ─────────────────────────────────────────────
# Muchos proveedores de VPS (Ionos incluido) bloquean el puerto 25 saliente.
# Sin relay, el correo se queda en cola con "Connection timed out". La solución
# es enviar autenticado por el smarthost SMTP del proveedor (puerto 587).
if [[ -n "$RELAYHOST" ]]; then
    RELAY_HOST_PART="${RELAYHOST%:*}"
    RELAY_PORT_PART="${RELAYHOST##*:}"
    RELAY_BRACKET="[${RELAY_HOST_PART}]:${RELAY_PORT_PART}"

    info "Configurando relay saliente vía ${RELAYHOST}"
    info "El correo saldrá autenticado por ese smarthost (evita el bloqueo del puerto 25)."
    printf '  Usuario SMTP (buzón completo, p.ej. tecnicos@%s): ' "$DOMAIN"
    read -r SMTP_USER
    printf '  Contraseña SMTP (no se mostrará): '
    read -rs SMTP_PASS
    echo ""

    if [[ -z "$SMTP_USER" || -z "$SMTP_PASS" ]]; then
        fail "Usuario o contraseña vacíos — relay no configurado."
        exit 1
    fi

    umask 077
    printf '%s %s:%s\n' "$RELAY_BRACKET" "$SMTP_USER" "$SMTP_PASS" > /etc/postfix/sasl_passwd
    unset SMTP_PASS
    postmap /etc/postfix/sasl_passwd
    chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db

    postconf -e "relayhost = ${RELAY_BRACKET}"
    postconf -e "smtp_sasl_auth_enable = yes"
    postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
    postconf -e "smtp_sasl_security_options = noanonymous"
    postconf -e "smtp_tls_security_level = encrypt"
    # Sin el dominio raíz en mydestination: el correo a buzones del dominio
    # sale por el relay en lugar de intentar entrega local.
    postconf -e "mydestination = localhost.localdomain, localhost"
    ok "Relay saliente configurado"
fi

# ── Reinicio de servicios ────────────────────────────────────────────────────
info "Reiniciando servicios…"
systemctl enable opendkim postfix >/dev/null 2>&1 || true
systemctl restart opendkim
systemctl restart postfix
systemctl is-active --quiet opendkim && ok "opendkim activo" || { fail "opendkim no arrancó"; exit 1; }
systemctl is-active --quiet postfix  && ok "postfix activo"  || { fail "postfix no arrancó"; exit 1; }

# ── Registros DNS a crear ────────────────────────────────────────────────────
SERVER_IP="$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || echo 'TU_IP_VPS')"

echo ""
echo "============================================================================="
echo " REGISTROS DNS — créalos en el panel de Ionos para ${DOMAIN}"
echo "============================================================================="
echo ""
echo " 1) SPF  — Tipo TXT, Host: @ (raíz)"
echo "    v=spf1 a mx ip4:${SERVER_IP} ~all"
if [[ -n "$RELAYHOST" ]]; then
    echo "    OJO: el correo sale por el relay ${RELAY_HOST_PART}. Añade el include"
    echo "    SPF de tu proveedor. Ionos:  ...ip4:${SERVER_IP} include:_spf-eu.ionos.com ~all"
    echo "    Si ya hay un TXT SPF del proveedor, FUSIONA — no crees un segundo."
fi
echo ""
echo " 2) DKIM — Tipo TXT, Host: ${SELECTOR}._domainkey"
echo "    (valor entre comillas del fichero ${PUBLIC_TXT}):"
echo ""
sed 's/^/    /' "$PUBLIC_TXT"
echo ""
echo " 3) DMARC — Tipo TXT, Host: _dmarc"
echo "    v=DMARC1; p=quarantine; rua=mailto:postmaster@${DOMAIN}; fo=1"
echo ""
echo "============================================================================="
info "Verifica tras propagar DNS:  dig +short TXT ${SELECTOR}._domainkey.${DOMAIN}"
info "Prueba de entrega:          envía un correo de test a https://www.mail-tester.com"
info "Detalle completo:           docs/tecnica/correo-dkim.md"
if [[ -n "$RELAYHOST" ]]; then
    echo ""
    info "Relay activo. Prueba el envío saliente:"
    info "  echo test | sendmail tu-correo@gmail.com  &&  tail -n5 /var/log/mail.log"
    info "Busca 'status=sent' y 'relay=${RELAY_HOST_PART}'. Si ves 'SASL"
    info "authentication failed', revisa usuario/contraseña en /etc/postfix/sasl_passwd."
fi
