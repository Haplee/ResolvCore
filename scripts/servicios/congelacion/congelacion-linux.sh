#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Congelación de sistemas Linux
#
# Estado de referencia restaurable vía BTRFS + snapper (ambos GPL).
# Crear snapshot del sistema limpio; restaurar tras cambios no deseados.
#
# Justificación técnica:
#   docs/tecnica/servicios-adicionales.md (sección 1)
#
# Uso:
#   bash congelacion-linux.sh --action status
#   bash congelacion-linux.sh --action configure
#   bash congelacion-linux.sh --action snapshot --etiqueta "estado-limpio"
#   bash congelacion-linux.sh --action rollback --confirm
#
# Argumentos:
#   --action   status|configure|snapshot|rollback
#   --subvol   <ruta>      Subvolumen BTRFS objetivo (default: /)
#   --etiqueta <texto>     Descripción del snapshot (acción snapshot)
#   --confirm              Obligatorio para rollback (descarta el estado actual)
#
# Exit codes:
#   0  ok
#   1  error de configuración
#   2  btrfs / snapper no disponibles
#   3  acción destructiva (rollback) sin --confirm
#
# Autor:   FranVi / ResolveCore
# Versión: 1.0.0
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

ACTION=""
SUBVOL="/"
ETIQUETA="resolvecore-snapshot"
CONFIRM=false

show_help() { sed -n '2,34p' "$0" | sed 's/^# \?//'; exit 0; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --action)   ACTION="${2:-}";   shift 2 ;;
        --subvol)   SUBVOL="${2:-}";   shift 2 ;;
        --etiqueta) ETIQUETA="${2:-}"; shift 2 ;;
        --confirm)  CONFIRM=true;      shift ;;
        -h|--help)  show_help ;;
        *) echo "Argumento desconocido: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$ACTION" ]]; then
    echo "Falta --action (status|configure|snapshot|rollback)" >&2
    exit 1
fi

# ── Deps ────────────────────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
    echo "jq no instalado: sudo apt install jq" >&2
    exit 1
fi

if ! command -v btrfs &>/dev/null; then
    echo "btrfs no instalado (paquete btrfs-progs)" >&2
    exit 2
fi

if ! command -v snapper &>/dev/null; then
    echo "snapper no instalado: sudo apt install snapper" >&2
    exit 2
fi

# Detecta si subvol está sobre BTRFS
fs_type() {
    findmnt -n -o FSTYPE "$1" 2>/dev/null || echo "?"
}

emit_json() {
    # emit_json key1 val1 key2 val2 ...
    local args=()
    while [[ $# -gt 0 ]]; do
        args+=(--arg "$1" "$2")
        shift 2
    done
    # Construir objeto a partir de los pares clave/valor
    local script='. as $in | reduce range(0; ($in | length); 2) as $i ({}; .[$in[$i]] = $in[$i+1])'
    jq -n "${args[@]}" \
        '$ARGS.named' 2>/dev/null || jq -n "${args[@]}" '$ARGS.named'
}

now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

# ── Acciones ────────────────────────────────────────────────────────────────
do_status() {
    local fs cfg last_num last_date last_desc
    fs=$(fs_type "$SUBVOL")
    cfg=$(snapper list-configs 2>/dev/null | tail -n +3 | awk '{print $1}' | head -1)
    last_num=""
    last_date=""
    last_desc=""

    if [[ -n "$cfg" ]]; then
        # Última línea no-header de `snapper list`
        last_line=$(snapper -c "$cfg" list 2>/dev/null | tail -n +4 | tail -1)
        if [[ -n "$last_line" ]]; then
            last_num=$(echo "$last_line" | awk -F'|' '{gsub(/^ +| +$/, "", $1); print $1}')
            last_date=$(echo "$last_line" | awk -F'|' '{gsub(/^ +| +$/, "", $4); print $4}')
            last_desc=$(echo "$last_line" | awk -F'|' '{gsub(/^ +| +$/, "", $6); print $6}')
        fi
    fi

    jq -n \
        --arg action "status" \
        --arg subvol "$SUBVOL" \
        --arg fs "$fs" \
        --arg config "$cfg" \
        --arg num  "$last_num" \
        --arg date "$last_date" \
        --arg desc "$last_desc" \
        --arg ts   "$(now)" \
        '{
            action: $action,
            subvolumen: $subvol,
            fs_type: $fs,
            snapper_config: ($config | select(length > 0)),
            ultimo_snapshot: {
                numero: $num,
                fecha:  $date,
                descripcion: $desc
            },
            fecha_consulta: $ts
        }'
}

do_configure() {
    local fs
    fs=$(fs_type "$SUBVOL")
    if [[ "$fs" != "btrfs" ]]; then
        echo "El subvolumen $SUBVOL no está sobre BTRFS (detectado: $fs)" >&2
        exit 1
    fi

    if [[ $EUID -ne 0 ]]; then
        echo "configure requiere root (sudo)" >&2
        exit 1
    fi

    local cfg="root"
    if [[ "$SUBVOL" != "/" ]]; then
        cfg=$(basename "$SUBVOL")
    fi

    if snapper list-configs 2>/dev/null | awk 'NR>2 {print $1}' | grep -qx "$cfg"; then
        echo "Config snapper '$cfg' ya existe"
    else
        echo "Creando config snapper '$cfg' en $SUBVOL..."
        snapper -c "$cfg" create-config "$SUBVOL"
    fi

    # Retención conservadora: 10 timeline + 10 numbered
    snapper -c "$cfg" set-config \
        TIMELINE_CREATE=yes \
        TIMELINE_LIMIT_HOURLY=5 \
        TIMELINE_LIMIT_DAILY=7 \
        TIMELINE_LIMIT_WEEKLY=2 \
        TIMELINE_LIMIT_MONTHLY=0 \
        TIMELINE_LIMIT_YEARLY=0 \
        NUMBER_LIMIT=10 \
        2>/dev/null || echo "Aviso: no se pudo aplicar retención"

    jq -n \
        --arg action "configure" \
        --arg subvol "$SUBVOL" \
        --arg config "$cfg" \
        --arg ts     "$(now)" \
        '{action: $action, subvolumen: $subvol, snapper_config: $config, fecha: $ts}'
}

do_snapshot() {
    if [[ $EUID -ne 0 ]]; then
        echo "snapshot requiere root (sudo)" >&2
        exit 1
    fi

    local cfg
    cfg=$(snapper list-configs 2>/dev/null | awk 'NR>2 {print $1}' | head -1)
    if [[ -z "$cfg" ]]; then
        echo "No hay config snapper. Ejecuta primero --action configure" >&2
        exit 1
    fi

    local out num
    out=$(snapper -c "$cfg" create --description "$ETIQUETA" --print-number 2>&1)
    num=$(echo "$out" | tail -1)

    jq -n \
        --arg action "snapshot" \
        --arg config "$cfg" \
        --arg num    "$num" \
        --arg desc   "$ETIQUETA" \
        --arg ts     "$(now)" \
        '{action: $action, snapper_config: $config, snapshot_id: $num, descripcion: $desc, fecha: $ts}'
}

do_rollback() {
    if [[ "$CONFIRM" != "true" ]]; then
        echo "✗ rollback requiere --confirm (operación destructiva)" >&2
        exit 3
    fi

    if [[ $EUID -ne 0 ]]; then
        echo "rollback requiere root (sudo)" >&2
        exit 1
    fi

    local cfg
    cfg=$(snapper list-configs 2>/dev/null | awk 'NR>2 {print $1}' | head -1)
    if [[ -z "$cfg" ]]; then
        echo "No hay config snapper. Ejecuta primero --action configure" >&2
        exit 1
    fi

    echo "Ejecutando snapper rollback en config '$cfg'..."
    snapper -c "$cfg" rollback

    jq -n \
        --arg action "rollback" \
        --arg config "$cfg" \
        --arg ts     "$(now)" \
        '{action: $action, snapper_config: $config, fecha: $ts, reinicio_requerido: true}'
}

case "$ACTION" in
    status)    do_status ;;
    configure) do_configure ;;
    snapshot)  do_snapshot ;;
    rollback)  do_rollback ;;
    *) echo "Acción inválida: $ACTION" >&2; exit 1 ;;
esac
