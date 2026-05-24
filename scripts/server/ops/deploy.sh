#!/usr/bin/env bash
# =============================================================================
# ResolveCore — deploy.sh
#
# Deploy continuo (día-2) del stack ResolveCore en el VPS. Bloquea ejecuciones
# concurrentes con flock.
#
# Uso (como root):
#   bash deploy.sh --target {wp|mantis|rc-tech|all} [--branch main] [--no-restart]
#
# Targets:
#   wp       — pull en $WP_DIR (debe ser repo git) + wp core update-db + cache flush
#   mantis   — pull en $MANTIS_DIR (debe ser repo git); schema upgrade es manual
#   rc-tech  — delega en scripts/server/deploy-rc-tech.sh con el tarball más reciente
#              de /var/cache/resolvecore/builds/rc-tech-*.tar.gz
#   all      — los tres en orden: wp, mantis, rc-tech
#
# Exit codes:
#   0 — OK
#   1 — argumentos o pre-condiciones inválidas
# =============================================================================

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "ERROR: requiere root" >&2; exit 1; }

LOG_DIR=/var/log/resolvecore
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log()  { printf '\e[1;32m[+]\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m[!]\e[0m %s\n' "$*"; }
err()  { printf '\e[1;31m[x]\e[0m %s\n' "$*" >&2; }

TARGET=""
BRANCH="main"
NO_RESTART=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)     TARGET="$2"; shift 2 ;;
        --branch)     BRANCH="$2"; shift 2 ;;
        --no-restart) NO_RESTART=true; shift ;;
        -h|--help)
            sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) err "Opción desconocida: $1"; exit 1 ;;
    esac
done

[[ -z "$TARGET" ]] && { err "--target obligatorio"; exit 1; }

# Lock — impide despliegues solapados
LOCK="/var/run/resolvecore-deploy.lock"
exec 9>"$LOCK"
flock -n 9 || { err "Otro deploy en curso ($LOCK)"; exit 1; }

# Entorno
[[ -r /etc/resolvecore/env ]] && source /etc/resolvecore/env
WP_DIR="${WP_DIR:-/var/www/wp}"
MANTIS_DIR="${MANTIS_DIR:-/var/www/mantis}"
BUILDS_DIR="${BUILDS_DIR:-/var/cache/resolvecore/builds}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

git_sha() {
    sudo -u www-data git -C "$1" rev-parse --short HEAD 2>/dev/null || echo "n/a"
}

deploy_wp() {
    log "[$(date -Iseconds)] === Deploy WordPress ==="
    [[ -d "$WP_DIR/.git" ]] || {
        err "$WP_DIR no es repo git — convertir o desplegar via tarball"
        return 1
    }
    local before after
    before=$(git_sha "$WP_DIR")
    log "  SHA antes: $before"
    sudo -u www-data git -C "$WP_DIR" fetch origin
    sudo -u www-data git -C "$WP_DIR" reset --hard "origin/$BRANCH"
    after=$(git_sha "$WP_DIR")
    log "  SHA después: $after"
    sudo -u www-data wp --path="$WP_DIR" core update-db
    sudo -u www-data wp --path="$WP_DIR" cache flush
}

deploy_mantis() {
    log "[$(date -Iseconds)] === Deploy MantisBT ==="
    [[ -d "$MANTIS_DIR/.git" ]] || {
        err "$MANTIS_DIR no es repo git — saltando"
        return 1
    }
    local before after
    before=$(git_sha "$MANTIS_DIR")
    log "  SHA antes: $before"
    sudo -u www-data git -C "$MANTIS_DIR" fetch origin
    sudo -u www-data git -C "$MANTIS_DIR" reset --hard "origin/$BRANCH"
    after=$(git_sha "$MANTIS_DIR")
    log "  SHA después: $after"
    warn "Schema upgrade manual si schema_version cambió: abrir /admin/install.php"
}

deploy_rc_tech() {
    log "[$(date -Iseconds)] === Deploy rc-tech ==="
    local latest
    latest=$(ls -1t "$BUILDS_DIR"/rc-tech-*.tar.gz 2>/dev/null | head -1 || true)
    [[ -n "$latest" ]] || { err "No hay tarball rc-tech en $BUILDS_DIR"; return 1; }
    log "  Tarball: $latest"
    bash "${SCRIPT_DIR}/../deploy-rc-tech.sh" "$latest"
}

case "$TARGET" in
    wp)      deploy_wp ;;
    mantis)  deploy_mantis ;;
    rc-tech) deploy_rc_tech ;;
    all)     deploy_wp; deploy_mantis; deploy_rc_tech ;;
    *)       err "--target inválido: $TARGET"; exit 1 ;;
esac

# Reload servicios
if ! $NO_RESTART; then
    log "Reload servicios (nginx + php-fpm)…"
    bash "$SCRIPT_DIR/nginx-reload-safe.sh"
    systemctl reload php8.3-fpm
fi

log "Deploy completado (target=$TARGET, branch=$BRANCH)"
