#!/usr/bin/env bash
# =============================================================================
# ResolveCore — Setup del directorio de descargas para técnicos
#
# Crea /opt/resolvecore-downloads/, copia los scripts de instalación del repo
# y configura nginx para servirlos bajo /downloads/ con HTTP Basic Auth.
#
# Prerrequisitos:
#   - nginx instalado (ya lo instala deploy-ionos.sh)
#   - Apache utils para htpasswd: sudo apt install apache2-utils
#   - Este script ejecutado desde la raíz del repo en el VPS
#
# Uso:
#   sudo bash scripts/server/setup-downloads-dir.sh
# =============================================================================

set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
step() { echo -e "${CYAN}[$1]${NC} $2"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC}  $1"; }
fail() { echo -e "${RED}[X]${NC}  $1" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOWNLOADS_DIR="/opt/resolvecore-downloads"
NGINX_CONF="/etc/nginx/conf.d/rc-downloads.conf"
HTPASSWD_FILE="/etc/nginx/.htpasswd-tecnicos"

[[ $EUID -ne 0 ]] && fail "Ejecuta como root: sudo bash $0"

# ── 1. Crear directorio de descargas ─────────────────────────────────────
step 1 "Creando $DOWNLOADS_DIR..."
mkdir -p "$DOWNLOADS_DIR"
chmod 750 "$DOWNLOADS_DIR"
chown www-data:www-data "$DOWNLOADS_DIR"
ok "Directorio creado"

# ── 2. Copiar scripts de instalación desde el repo ───────────────────────
step 2 "Copiando scripts de instalacion..."

cp "$REPO_ROOT/scripts/servicios/install.ps1" "$DOWNLOADS_DIR/install-servicios.ps1"
cp "$REPO_ROOT/scripts/servicios/install.sh"  "$DOWNLOADS_DIR/install-servicios.sh"
chmod 644 "$DOWNLOADS_DIR/install-servicios.ps1"
chmod 755 "$DOWNLOADS_DIR/install-servicios.sh"
ok "install-servicios.ps1 y install-servicios.sh copiados"

# ── 3. Placeholder para binarios (se suben manualmente) ──────────────────
step 3 "Creando placeholders para binarios..."
for f in "RebootRestoreRx-Setup.exe" "resolvecore-kit.zip"; do
    if [[ ! -f "$DOWNLOADS_DIR/$f" ]]; then
        touch "$DOWNLOADS_DIR/$f.PENDING"
        warn "PENDIENTE: sube manualmente $f a $DOWNLOADS_DIR/"
    else
        ok "$f ya existe"
    fi
done

# ── 4. Apache utils (htpasswd) ────────────────────────────────────────────
step 4 "Verificando apache2-utils (htpasswd)..."
if ! command -v htpasswd &>/dev/null; then
    apt-get install -y -qq apache2-utils 2>/dev/null
    command -v htpasswd &>/dev/null || fail "No se pudo instalar apache2-utils"
    ok "apache2-utils instalado"
else
    ok "htpasswd disponible"
fi

# ── 5. Crear usuario htpasswd ─────────────────────────────────────────────
step 5 "Configurando autenticacion HTTP Basic..."
if [[ ! -f "$HTPASSWD_FILE" ]]; then
    read -rp "  Nombre de usuario para /downloads/ (ej: tecnico): " HTUSER
    htpasswd -c "$HTPASSWD_FILE" "$HTUSER"
    ok "Usuario '$HTUSER' creado en $HTPASSWD_FILE"
else
    warn "$HTPASSWD_FILE ya existe. Para añadir usuario: htpasswd $HTPASSWD_FILE <usuario>"
    ok "Usando htpasswd existente"
fi
chmod 640 "$HTPASSWD_FILE"
chown root:www-data "$HTPASSWD_FILE"

# ── 6. Config nginx ───────────────────────────────────────────────────────
step 6 "Escribiendo snippet nginx: $NGINX_CONF..."
# Genera solo el bloque location — se incluye en el vhost SSL existente.
# NO crea un server{} nuevo para evitar conflicto de ssl_certificate.
cat > "$NGINX_CONF" <<'NGINX'
# ResolveCore — snippet /downloads/ (incluir dentro del server{} SSL existente)
# include /etc/nginx/conf.d/rc-downloads.conf;

location /downloads/ {
    alias /opt/resolvecore-downloads/;
    auth_basic "ResolveCore — Area de tecnicos";
    auth_basic_user_file /etc/nginx/.htpasswd-tecnicos;

    autoindex off;

    add_header Content-Disposition 'attachment';
    add_header X-Content-Type-Options nosniff;
    add_header Cache-Control 'no-cache, no-store, must-revalidate';

    location ~ \.(ps1|sh|zip|exe)$ {
        auth_basic "ResolveCore — Area de tecnicos";
        auth_basic_user_file /etc/nginx/.htpasswd-tecnicos;
    }

    location ~ [^.]\.(ps1|sh|zip|exe)$ {
        return 403;
    }
}
NGINX
ok "Snippet nginx escrito (añadir include al vhost SSL existente)"

# Intentar añadir include al vhost existente si no está ya
VHOST_CONF=""
for _v in /etc/nginx/sites-enabled/resolvecore.conf \
           /etc/nginx/sites-available/resolvecore.conf \
           /etc/nginx/conf.d/resolvecore.conf; do
    [[ -f "$_v" ]] && { VHOST_CONF="$_v"; break; }
done

if [[ -n "$VHOST_CONF" ]]; then
    if ! grep -q 'rc-downloads.conf' "$VHOST_CONF"; then
        # Insertar include antes del último } del server SSL block
        sed -i '/^}/{ /^}/!b; ${s/^}/    include \/etc\/nginx\/conf.d\/rc-downloads.conf;\n}/} ' "$VHOST_CONF" 2>/dev/null \
            || warn "No se pudo auto-insertar include en $VHOST_CONF — añádelo manualmente"
        ok "include añadido a $VHOST_CONF"
    else
        ok "include ya presente en $VHOST_CONF"
    fi
else
    warn "Vhost SSL no encontrado. Añade manualmente dentro del server{} SSL:"
    warn "    include /etc/nginx/conf.d/rc-downloads.conf;"
fi

# ── 7. Validar y recargar nginx ───────────────────────────────────────────
step 7 "Validando config nginx..."
nginx -t 2>&1 && ok "Config válida" || { warn "Error en config nginx — revisa $NGINX_CONF"; }

step 7 "Recargando nginx..."
systemctl reload nginx && ok "nginx recargado" || warn "No se pudo recargar nginx"

# ── 8. Añadir constante WP en wp-config.php ───────────────────────────────
step 8 "Verificando RC_DOWNLOADS_PATH en wp-config.php..."
for _candidate in \
        "${WP_CONFIG_PATH:-}" \
        /var/www/wp/wp-config.php \
        /var/www/html/wp-config.php \
        /var/www/resolvecore.website/wp-config.php; do
    [[ -n "$_candidate" && -f "$_candidate" ]] && { WP_CONFIG="$_candidate"; break; }
done
WP_CONFIG="${WP_CONFIG:-}"
if [[ -f "$WP_CONFIG" ]]; then
    if ! grep -q 'RC_DOWNLOADS_PATH' "$WP_CONFIG"; then
        sed -i "/\/\* That's all, stop editing/i define('RC_DOWNLOADS_PATH', '/opt/resolvecore-downloads');" "$WP_CONFIG"
        ok "RC_DOWNLOADS_PATH añadido a wp-config.php"
    else
        ok "RC_DOWNLOADS_PATH ya existe en wp-config.php"
    fi
else
    warn "wp-config.php no encontrado en $WP_CONFIG"
    warn "Añade manualmente: define('RC_DOWNLOADS_PATH', '/opt/resolvecore-downloads');"
fi

# ── Resumen ───────────────────────────────────────────────────────────────
echo ""
echo -e "  ${CYAN}=======================================================${NC}"
echo -e "   Setup completado"
echo -e "  ${CYAN}=======================================================${NC}"
echo ""
echo -e "  Directorio:   ${GREEN}$DOWNLOADS_DIR${NC}"
echo -e "  Auth:         ${GREEN}$HTPASSWD_FILE${NC}"
echo -e "  nginx conf:   ${GREEN}$NGINX_CONF${NC}"
echo ""
echo -e "  ${YELLOW}PENDIENTE — sube estos ficheros manualmente a $DOWNLOADS_DIR/:${NC}"
echo -e "    - resolvecore-kit.zip       (genera con construir-kit.ps1)"
echo -e "    - RebootRestoreRx-Setup.exe (descarga de horizondatasys.com)"
echo ""
echo -e "  URL de descarga directa (con auth):"
echo -e "    ${GREEN}https://resolvecore.website/downloads/install-servicios.ps1${NC}"
echo -e "    ${GREEN}https://resolvecore.website/downloads/install-servicios.sh${NC}"
echo ""
echo -e "  Página WP para técnicos (autenticados en WP):"
echo -e "    ${GREEN}https://resolvecore.website/tecnicos/${NC}"
echo -e "    (Crea la página en WP y asigna plantilla 'Área de Técnicos')"
echo ""
exit 0
