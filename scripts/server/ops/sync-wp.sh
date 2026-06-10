#!/usr/bin/env bash
# Autor:   Francisco Vidal Mateo (GitHub: Haplee)
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Sync de tema + plugins al docroot de WordPress en el VPS.
#
# Autodetecta el modelo de despliegue:
#   - Modelo B: repo en /opt/resolvecore-source → rsync a /var/www/wp/wp-content
#   - Modelo A: /var/www/wp es un repo git → reset --hard directo
#
# Sincroniza el tema y TODOS los plugins rc-* (rc-core, rc-mantisbt, rc-tech,
# rc-fleet), vacía la caché de WP y recarga PHP-FPM + nginx.
#
# Uso (como root):
#     bash sync-wp.sh [branch]
#
# Ejemplos:
#     bash sync-wp.sh              # sincroniza main
#     bash sync-wp.sh simpleza-270526
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

log()  { printf '\e[1;32m[+]\e[0m %s\n' "$*"; }
err()  { printf '\e[1;31m[x]\e[0m %s\n' "$*" >&2; }

if [ "$EUID" -ne 0 ]; then
    err "Este script tiene que correr como root."
    exit 1
fi

BRANCH="${1:-main}"
WP_DIR="/var/www/wp"
PLUGINS=(rc-core rc-mantisbt rc-tech rc-fleet)

# Repo canónico configurable; autodetecta entre los candidatos del VPS.
# Prioridad: SOURCE_DIR del entorno > -repo (origin/HEAD) > -git > -source.
SOURCE_DIR="${SOURCE_DIR:-}"
if [ -z "${SOURCE_DIR}" ]; then
    for cand in /opt/resolvecore-repo /opt/resolvecore-git /opt/resolvecore-source; do
        if [ -d "${cand}/.git" ]; then SOURCE_DIR="${cand}"; break; fi
    done
fi

if [ -n "${SOURCE_DIR}" ] && [ -d "${SOURCE_DIR}/.git" ]; then
    log "Modelo B (source repo + rsync) — ${SOURCE_DIR} @ branch ${BRANCH}"
    # Si el fetch falla (red caída, credenciales), NO hacemos reset --hard: el
    # script no usa 'set -e', así que sin esta guarda haríamos rollback contra
    # refs obsoletos, potencialmente a una revisión incorrecta en producción.
    if ! git -C "${SOURCE_DIR}" fetch origin; then
        err "git fetch falló en ${SOURCE_DIR}: abortando sin tocar el árbol."
        exit 1
    fi
    git -C "${SOURCE_DIR}" reset --hard "origin/${BRANCH}"

    rsync -a --delete \
        "${SOURCE_DIR}/wordpress/resolvecore-theme/" \
        "${WP_DIR}/wp-content/themes/resolvecore-theme/"

    for p in "${PLUGINS[@]}"; do
        if [ -d "${SOURCE_DIR}/wordpress/plugins/${p}" ]; then
            rsync -a --delete \
                "${SOURCE_DIR}/wordpress/plugins/${p}/" \
                "${WP_DIR}/wp-content/plugins/${p}/"
            log "plugin sincronizado: ${p}"
        fi
    done

    chown -R www-data:www-data "${WP_DIR}/wp-content/themes" "${WP_DIR}/wp-content/plugins"

elif [ -d "${WP_DIR}/.git" ]; then
    log "Modelo A (git docroot) — branch ${BRANCH}"
    if ! sudo -u www-data git -C "${WP_DIR}" fetch origin; then
        err "git fetch falló en ${WP_DIR}: abortando sin tocar el árbol."
        exit 1
    fi
    sudo -u www-data git -C "${WP_DIR}" reset --hard "origin/${BRANCH}"

else
    err "Ningún modelo detectado: ni ${SOURCE_DIR}/.git ni ${WP_DIR}/.git existen."
    exit 1
fi

sudo -u www-data wp --path="${WP_DIR}" cache flush 2>/dev/null || true
# Autodetectamos el servicio php-fpm (la versión no siempre es 8.3 según el VPS).
PHP_FPM=$(systemctl list-units --type=service --plain --no-legend 'php*-fpm.service' 2>/dev/null | awk '{print $1}' | head -1)
PHP_FPM="${PHP_FPM:-php8.3-fpm}"
systemctl reload "$PHP_FPM" nginx
log "Sync completado (branch=${BRANCH})."
