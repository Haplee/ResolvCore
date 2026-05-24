#!/usr/bin/env bash
# =============================================================================
# ResolveCore — healthcheck.sh
#
# Comprueba el estado del stack VPS y reporta OK/FAIL por chequeo. No aborta al
# primer fallo: queremos un resumen completo.
#
# Uso (como root):
#   bash healthcheck.sh         # imprime resultados, exit 0 si todo OK, 1 si ≥1 FAIL
#   bash healthcheck.sh --alert # además envía email vía msmtp si exit != 0
#
# Cron sugerido:
#   */10 * * * * root /opt/resolvecore/ops/healthcheck.sh --alert
# =============================================================================

set -uo pipefail

[[ $EUID -eq 0 ]] || { echo "ERROR: requiere root" >&2; exit 1; }

LOG_DIR=/var/log/resolvecore
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/healthcheck.log"

# No usamos exec >tee aquí porque queremos stdout limpio para email body.
# Se appendea al log al final.

ALERT=false
[[ "${1:-}" == "--alert" ]] && ALERT=true

# Entorno
[[ -r /etc/resolvecore/env ]] && source /etc/resolvecore/env
RC_DOMAIN="${RC_DOMAIN:-resolvecore.es}"
WP_DIR="${WP_DIR:-/var/www/wp}"
MYSQL_CNF="/etc/resolvecore/mysql-backup.cnf"
ALERT_TO="${ALERT_TO:-fvidalmateo@gmail.com}"

RESULTS=()
FAILED=0

# check NAME CMD — ejecuta CMD; OK si exit 0, FAIL si !=0
check() {
    local name="$1"; shift
    local out
    if out=$("$@" 2>&1); then
        RESULTS+=("OK   | $name")
    else
        RESULTS+=("FAIL | $name | $out")
        FAILED=$((FAILED + 1))
    fi
}

# check_eq NAME EXPECTED CMD — OK si stdout == EXPECTED
check_eq() {
    local name="$1" expected="$2"; shift 2
    local out
    out=$("$@" 2>&1) || true
    if [[ "$out" == "$expected" ]]; then
        RESULTS+=("OK   | $name | $out")
    else
        RESULTS+=("FAIL | $name | got='$out' expected='$expected'")
        FAILED=$((FAILED + 1))
    fi
}

# check_num NAME OP THRESHOLD CMD — comparación numérica (OP: -lt|-gt|-le|-ge|-eq)
check_num() {
    local name="$1" op="$2" threshold="$3"; shift 3
    local out ok=false
    out=$("$@" 2>&1) || true
    if [[ "$out" =~ ^[0-9]+$ ]]; then
        case "$op" in
            -lt) [[ "$out" -lt "$threshold" ]] && ok=true ;;
            -gt) [[ "$out" -gt "$threshold" ]] && ok=true ;;
            -le) [[ "$out" -le "$threshold" ]] && ok=true ;;
            -ge) [[ "$out" -ge "$threshold" ]] && ok=true ;;
            -eq) [[ "$out" -eq "$threshold" ]] && ok=true ;;
        esac
    fi
    if $ok; then
        RESULTS+=("OK   | $name | $out (umbral: $op $threshold)")
    else
        RESULTS+=("FAIL | $name | got='$out' umbral '$op $threshold'")
        FAILED=$((FAILED + 1))
    fi
}

# --- Checks ---

check "puertos 80/443 LISTEN" \
    bash -c "ss -ltn '( sport = :80 or sport = :443 )' | grep -q LISTEN"

check_eq "HTTP WP login" "200" \
    curl -fsS -o /dev/null -w '%{http_code}' "https://$RC_DOMAIN/wp-login.php"

check_eq "HTTP Mantis login" "200" \
    curl -fsS -o /dev/null -w '%{http_code}' "https://mantis.$RC_DOMAIN/login_page.php"

if [[ -r "$MYSQL_CNF" ]]; then
    check "MariaDB ping" \
        mysqladmin --defaults-file="$MYSQL_CNF" ping
else
    RESULTS+=("FAIL | MariaDB ping | falta $MYSQL_CNF")
    FAILED=$((FAILED + 1))
fi

check "nginx -t" nginx -t

check "systemctl active (nginx/php-fpm/mariadb)" \
    systemctl is-active --quiet nginx php8.3-fpm mariadb

check "wp-config.php legible y con DB_NAME" \
    bash -c "[[ -r '$WP_DIR/wp-config.php' ]] && grep -q DB_NAME '$WP_DIR/wp-config.php'"

# Espacio disco / (umbral 85%)
check_num "disco / uso% (<85)" -lt 85 \
    bash -c "df --output=pcent / | tail -1 | tr -d ' %'"

# WP-cron: al menos 1 evento programado
check_num "wp cron eventos programados (>0)" -gt 0 \
    sudo -u www-data wp --path="$WP_DIR" cron event list --format=count 2>/dev/null

# rc-tech SLA scan reciente: transient debe existir (puede ser '0', no error)
check "rc-tech SLA transient presente" \
    bash -c "sudo -u www-data wp --path='$WP_DIR' transient get rc_tech_sla_count >/dev/null 2>&1"

# --- Output ---

NOW=$(date -Iseconds)
BODY="ResolveCore healthcheck — $NOW
Host: $(hostname)
RC_DOMAIN: $RC_DOMAIN
Resultado: $([ $FAILED -eq 0 ] && echo 'OK' || echo "FAIL ($FAILED fallos)")

$(printf '%s\n' "${RESULTS[@]}")
"

echo "$BODY" | tee -a "$LOG_FILE"

if $ALERT && [[ $FAILED -gt 0 ]]; then
    if command -v msmtp >/dev/null 2>&1; then
        printf 'Subject: [ResolveCore] healthcheck FAIL (%d) %s\nTo: %s\n\n%s\n' \
            "$FAILED" "$(hostname)" "$ALERT_TO" "$BODY" \
            | msmtp -t || echo "WARN: msmtp falló al enviar alerta" >&2
    else
        echo "WARN: msmtp no instalado — no se envió alerta" >&2
    fi
fi

[[ $FAILED -eq 0 ]] && exit 0 || exit 1
