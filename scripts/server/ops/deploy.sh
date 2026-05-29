#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Despliegue de código en el VPS desde el repositorio git.
#
# Hace fetch + reset --hard al branch indicado en /var/www/wp y/o
# /var/www/mantis, corre las migraciones de WordPress y vacía la caché.
#
# Usa un lock con flock para que dos deploys simultáneos no se pisen
# (p.ej. si el cron y yo lanzamos a la vez).
#
# Uso (como root):
#     bash deploy.sh <wp|mantis|all> [branch]
#
# Ejemplos:
#     bash deploy.sh all                # despliega main en los dos
#     bash deploy.sh wp simpleza-270526 # solo WP, branch concreto
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

log()  { printf '\e[1;32m[+]\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m[!]\e[0m %s\n' "$*"; }
err()  { printf '\e[1;31m[x]\e[0m %s\n' "$*" >&2; }

if [ "$EUID" -ne 0 ]; then
    err "Este script tiene que correr como root."
    exit 1
fi

TARGET="${1:-}"
BRANCH="${2:-main}"

[ -n "$TARGET" ] || { echo "Uso: $0 <wp|mantis|all> [branch]"; exit 1; }


# ── Lock anti-concurrencia ──────────────────────────────────────────────────
# flock -n falla al instante si ya hay otro deploy con el lock cogido. Mejor
# eso que dejar dos 'git reset' pisándose a medias.

LOCK_FILE="/var/run/resolvecore-deploy.lock"
exec 9>"$LOCK_FILE"
flock -n 9 || { err "Ya hay otro deploy en curso. Aborto."; exit 1; }


# ── Entorno ─────────────────────────────────────────────────────────────────

[ -r /etc/resolvecore/env ] && source /etc/resolvecore/env

WP_DIR="${WP_DIR:-/var/www/wp}"
MANTIS_DIR="${MANTIS_DIR:-/var/www/mantis}"


# ── Funciones de despliegue ─────────────────────────────────────────────────
# Corremos git como www-data para no dejar ficheros root dentro del docroot
# (rompería los permisos que espera php-fpm).

deploy_wp() {
    [ -d "$WP_DIR/.git" ] || { err "$WP_DIR no es un repo git"; return 1; }
    log "WordPress: fetch + reset a origin/$BRANCH"
    sudo -u www-data git -C "$WP_DIR" fetch origin
    sudo -u www-data git -C "$WP_DIR" reset --hard "origin/$BRANCH"
    # update-db aplica migraciones de plugins/tema si las hubiera.
    sudo -u www-data wp --path="$WP_DIR" core update-db
    sudo -u www-data wp --path="$WP_DIR" cache flush
    log "WordPress actualizado."
}

deploy_mantis() {
    [ -d "$MANTIS_DIR/.git" ] || { err "$MANTIS_DIR no es un repo git"; return 1; }
    log "MantisBT: fetch + reset a origin/$BRANCH"
    sudo -u www-data git -C "$MANTIS_DIR" fetch origin
    sudo -u www-data git -C "$MANTIS_DIR" reset --hard "origin/$BRANCH"
    # NOTE: Mantis no tiene un "update-db" por CLI; si cambia el esquema hay
    #       que entrar a admin/install.php manualmente.
    log "MantisBT actualizado."
}

case "$TARGET" in
    wp)     deploy_wp ;;
    mantis) deploy_mantis ;;
    all)    deploy_wp; deploy_mantis ;;
    *)      err "Target inválido: $TARGET (usa wp|mantis|all)"; exit 1 ;;
esac

nginx -t && systemctl reload nginx && systemctl reload php8.3-fpm
log "Deploy completado (target=$TARGET, branch=$BRANCH)"
