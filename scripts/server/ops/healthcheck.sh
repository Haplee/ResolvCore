#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Healthcheck del VPS.
#
# Comprueba que los servicios clave están vivos y que las webs responden.
# Pensado para lanzarse por cron cada pocos minutos; con --alert manda un
# correo si algo falla.
#
# Uso:
#     bash healthcheck.sh            # solo imprime el resumen
#     bash healthcheck.sh --alert    # además avisa por correo si hay fallos
#
# Cron sugerido (cada 5 min):
#     */5 * * * * root /opt/resolvecore/ops/healthcheck.sh --alert
#
# Exit codes:
#     0  todo OK
#     1  al menos un check ha fallado
# ─────────────────────────────────────────────────────────────────────────────

# Sin -e a propósito: queremos seguir corriendo TODOS los checks aunque uno
# falle, para dar un resumen completo (no abortar en el primer fallo).
set -uo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Requiere root" >&2
    exit 1
fi

[ -r /etc/resolvecore/env ] && source /etc/resolvecore/env

RC_DOMAIN="${RC_DOMAIN:-resolvecore.website}"
MYSQL_CNF="${MYSQL_CNF:-/etc/resolvecore/mysql-backup.cnf}"
ALERT_TO="${ALERT_TO:-fvidalmateo@gmail.com}"
MODO="${1:-}"

FALLOS=0

# Helper: ejecuta el comando en silencio y pinta OK/FAIL según el exit code.
check() {
    local etiqueta="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf '\e[1;32mOK  \e[0m %s\n' "$etiqueta"
    else
        printf '\e[1;31mFAIL\e[0m %s\n' "$etiqueta"
        FALLOS=$((FALLOS + 1))
    fi
}

# ── Servicios systemd ───────────────────────────────────────────────────────
check "nginx activo"   systemctl is-active --quiet nginx
check "php-fpm activo"  systemctl is-active --quiet php8.3-fpm
check "mariadb activo"  systemctl is-active --quiet mariadb

# ── Red y webs ──────────────────────────────────────────────────────────────
check "puertos 80/443" bash -c "ss -ltn | grep -qE ':80 |:443 '"
check "HTTP WordPress"  curl -fsS -o /dev/null "https://${RC_DOMAIN}/wp-login.php"
check "HTTP MantisBT"   curl -fsS -o /dev/null "https://mantis.${RC_DOMAIN}/login_page.php"

# Solo probamos la DB si tenemos credenciales legibles.
[ -r "$MYSQL_CNF" ] && check "MariaDB ping" mysqladmin --defaults-file="$MYSQL_CNF" ping

# Disco: avisamos por debajo del 85% para tener margen antes de que se llene.
check "disco < 85%" bash -c "[[ \$(df / | awk 'NR==2{gsub(/%/,\"\",\$5);print \$5}') -lt 85 ]]"

echo "--- $FALLOS fallo(s) ---"


# ── Alerta por correo ───────────────────────────────────────────────────────
# Solo si nos pasaron --alert, hay fallos y msmtp está instalado. Si no hay
# msmtp simplemente no avisamos (no quiero que el cron pete por eso).

if [ "$MODO" = "--alert" ] && [ "$FALLOS" -gt 0 ] && command -v msmtp >/dev/null; then
    printf 'Subject: [ResolveCore] healthcheck FAIL (%d)\nTo: %s\n\n%d fallo(s) en %s\n' \
        "$FALLOS" "$ALERT_TO" "$FALLOS" "$(hostname)" | msmtp -t
fi

# TODO: registrar histórico en /var/log/resolvecore/health.log para ver
#       patrones (p.ej. si php-fpm se cae siempre a la misma hora).

[ "$FALLOS" -eq 0 ] && exit 0 || exit 1
