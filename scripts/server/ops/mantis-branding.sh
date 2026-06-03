#!/usr/bin/env bash
#
# mantis-branding.sh — Aplica el branding White-Label de ResolveCore a una
# instancia de MantisBT en el VPS vía SSH:
#   1) Copia el logo oscuro del repo a la web-root de Mantis (images/).
#   2) Escribe rc_footer.php con CSS que oculta «Powered by MantisBT» y los
#      enlaces de soporte integrados.
#   3) Inyecta (idempotente) el bloque de branding en config_inc.php.
#
# Autor:   Francisco Vidal Mateo
# Versión: 1.0 (01-06-2026)
#
# Uso:
#   bash scripts/server/ops/mantis-branding.sh            # dry-run (muestra plan)
#   bash scripts/server/ops/mantis-branding.sh --apply    # ejecuta sobre el VPS
#
# Variables de entorno (con valores por defecto):
#   VPS_USER       usuario SSH           (def: root)
#   VPS_HOST       host del VPS          (def: resolvecore.website)
#   MANTIS_DIR     raíz web de Mantis    (def: /var/www/mantis)
#
set -euo pipefail

# ── Configuración ────────────────────────────────────────────────────────────
VPS_USER="${VPS_USER:-root}"
VPS_HOST="${VPS_HOST:-resolvecore.website}"
MANTIS_DIR="${MANTIS_DIR:-/var/www/mantis}"
MANTIS_CONFIG="${MANTIS_DIR}/config/config_inc.php"
MANTIS_IMAGES="${MANTIS_DIR}/images"
REMOTE_LOGO="${MANTIS_IMAGES}/rc-logo-dark.png"
REMOTE_FAVICON="${MANTIS_IMAGES}/rc-favicon.ico"
REMOTE_FOOTER="${MANTIS_DIR}/config/rc_footer.php"
MARKER="# RC_BRANDING_BLOCK"   # centinela de idempotencia en config_inc.php

# Logo de origen dentro del repo (carpeta del tema WordPress).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SRC_LOGO="${REPO_ROOT}/wordpress/resolvecore-theme/assets/logo/resolvcore-logo-dark.png"
# Favicon de origen: variante simplificada multi-tamano (.ico), nitida a 16/32px.
SRC_FAVICON="${REPO_ROOT}/wordpress/resolvecore-theme/assets/logo/favicon.ico"

APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

# ── Dependencias ─────────────────────────────────────────────────────────────
command -v ssh >/dev/null 2>&1 || { echo "ERROR: falta 'ssh'." >&2; exit 1; }
command -v scp >/dev/null 2>&1 || { echo "ERROR: falta 'scp'." >&2; exit 1; }
[ -f "$SRC_LOGO" ] || { echo "ERROR: no existe el logo de origen: $SRC_LOGO" >&2; exit 1; }
[ -f "$SRC_FAVICON" ] || { echo "ERROR: no existe el favicon de origen: $SRC_FAVICON" >&2; exit 1; }

echo "==> Branding MantisBT ResolveCore"
echo "    Destino : ${VPS_USER}@${VPS_HOST}:${MANTIS_DIR}"
echo "    Logo    : ${SRC_LOGO}"
echo "    Config  : ${MANTIS_CONFIG}"

if [ "$APPLY" -eq 0 ]; then
	echo
	echo "DRY-RUN (no se ha tocado nada). Relanza con --apply para ejecutar:"
	echo "    bash scripts/server/ops/mantis-branding.sh --apply"
	exit 0
fi

# ── 1) Subir el logo y el favicon a /tmp del VPS ─────────────────────────────
echo "==> Subiendo logo y favicon a /tmp del VPS…"
scp "$SRC_LOGO"    "${VPS_USER}@${VPS_HOST}:/tmp/rc-logo-dark.png"
scp "$SRC_FAVICON" "${VPS_USER}@${VPS_HOST}:/tmp/rc-favicon.ico"

# ── 2) Ejecutar el resto en remoto (instalar logo + footer + parchear config) ─
echo "==> Aplicando branding en remoto…"
ssh "${VPS_USER}@${VPS_HOST}" \
	MANTIS_DIR="$MANTIS_DIR" \
	MANTIS_CONFIG="$MANTIS_CONFIG" \
	MANTIS_IMAGES="$MANTIS_IMAGES" \
	REMOTE_LOGO="$REMOTE_LOGO" \
	REMOTE_FAVICON="$REMOTE_FAVICON" \
	REMOTE_FOOTER="$REMOTE_FOOTER" \
	MARKER="$MARKER" \
	'bash -s' <<'REMOTE'
set -euo pipefail

# 2.1 — Logo + favicon: instalar con permisos del servidor web.
install -o www-data -g www-data -m 0644 /tmp/rc-logo-dark.png "$REMOTE_LOGO"
install -o www-data -g www-data -m 0644 /tmp/rc-favicon.ico   "$REMOTE_FAVICON"
rm -f /tmp/rc-logo-dark.png /tmp/rc-favicon.ico
echo "    [ok] logo    -> $REMOTE_LOGO"
echo "    [ok] favicon -> $REMOTE_FAVICON"

# 2.2 — Footer: CSS que oculta «Powered by» + enlaces de soporte de Mantis.
cat > "$REMOTE_FOOTER" <<'PHP'
<?php /* ResolveCore White-Label — inyectado por mantis-branding.sh */ ?>
<style>
.copyright-statement,
#footer .copyright-statement,
.powered-by,
a[href*="mantisbt.org"],
a[href*="mantisbt.com"] { display: none !important; }
</style>
PHP
chown www-data:www-data "$REMOTE_FOOTER"
chmod 0644 "$REMOTE_FOOTER"
echo "    [ok] footer -> $REMOTE_FOOTER"

# 2.3 — config_inc.php: inyectar bloque de branding solo si no existe ya.
if grep -q "$MARKER" "$MANTIS_CONFIG"; then
	echo "    [skip] config_inc.php ya tiene el bloque de branding ($MARKER)"
else
	cp -a "$MANTIS_CONFIG" "${MANTIS_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
	cat >> "$MANTIS_CONFIG" <<PHP

$MARKER  (ResolveCore White-Label — mantis-branding.sh)
\$g_window_title        = 'ResolveCore · Soporte';
\$g_logo_image          = 'images/rc-logo-dark.png';
\$g_logo_url            = 'https://resolvecore.website';
\$g_favicon_image       = 'images/rc-favicon.png';
\$g_copyright_statement = '';
\$g_show_version        = OFF;
\$g_bottom_include_page = '$REMOTE_FOOTER';
# RC_BRANDING_BLOCK_END
PHP
	echo "    [ok] config_inc.php parcheado (backup creado)"
fi

echo "==> Branding aplicado. Limpia la caché de Mantis si procede:"
echo "    rm -f ${MANTIS_DIR}/core/.htaccess 2>/dev/null || true"
REMOTE

echo "==> Hecho."
