#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Clonación: alta de imagen en el manifiesto
#
# Registra una imagen de clonación (creada con Clonezilla / FOG / Veeam) en un
# manifiesto JSON. El manifiesto da trazabilidad de qué imagen corresponde a qué
# equipo, fecha, sistema operativo y estado, junto con su hash de integridad.
#
# Herramientas referenciadas (FOSS):
#   - Clonezilla Live (GPL) — clonado puntual vía USB.
#   - FOG Project (GPL)     — despliegue masivo PXE.
#
# Justificación técnica:
#   docs/tecnica/servicios-adicionales.md (sección 2)
#
# Uso:
#   bash registrar-imagen.sh --imagen <ruta> --equipo <nombre> \
#        --so <windows|linux|macos> --estado <limpio|post-instalacion|produccion>
#
# Argumentos:
#   --imagen   <ruta>     Fichero o carpeta de imagen a registrar
#   --equipo   <nombre>   Identificador del equipo de origen
#   --so       <texto>    windows | linux | macos
#   --estado   <texto>    limpio | post-instalacion | produccion
#   --manifest <ruta>     Manifiesto JSON destino (default: ./imagenes-manifest.json)
#   --notas    <texto>    Notas libres opcionales
#
# Exit codes:
#   0  ok
#   1  argumentos inválidos
#   2  imagen no encontrada
#
# Autor:   Francisco Vidal Mateo (GitHub: Haplee)
# Versión: 1.0.0
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

IMAGEN=""
EQUIPO=""
SO=""
ESTADO=""
MANIFEST="./imagenes-manifest.json"
NOTAS=""
TICKET=""

show_help() {
    sed -n '2,33p' "$0" | sed 's/^# \?//'
    exit 0
}

# Normaliza --flag=valor a --flag valor (acepta ambas formas)
NORMALIZED=()
for ARG in "$@"; do
    case "$ARG" in
        --*=*) NORMALIZED+=("${ARG%%=*}" "${ARG#*=}") ;;
        *)     NORMALIZED+=("$ARG") ;;
    esac
done
set -- "${NORMALIZED[@]+"${NORMALIZED[@]}"}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --imagen)   IMAGEN="${2:-}";   shift 2 ;;
        --equipo)   EQUIPO="${2:-}";   shift 2 ;;
        --so)       SO="${2:-}";       shift 2 ;;
        --estado)   ESTADO="${2:-}";   shift 2 ;;
        --manifest) MANIFEST="${2:-}"; shift 2 ;;
        --notas)    NOTAS="${2:-}";    shift 2 ;;
        --ticket)   TICKET="${2:-}"; shift 2 ;;
        -h|--help)  show_help ;;
        *) echo "Argumento desconocido: $1" >&2; exit 1 ;;
    esac
done

# ── Validaciones ────────────────────────────────────────────────────────────
if [[ -z "$IMAGEN" || -z "$EQUIPO" || -z "$SO" || -z "$ESTADO" ]]; then
    echo "Faltan argumentos obligatorios: --imagen --equipo --so --estado" >&2
    exit 1
fi

case "$SO" in
    windows|linux|macos) ;;
    *) echo "Valor de --so inválido: $SO (windows|linux|macos)" >&2; exit 1 ;;
esac

case "$ESTADO" in
    limpio|post-instalacion|produccion) ;;
    *) echo "Valor de --estado inválido: $ESTADO" >&2; exit 1 ;;
esac

# Auto-install jq si falta
if ! command -v jq &>/dev/null; then
    echo "[->] Instalando jq..."
    if command -v apt-get &>/dev/null;  then sudo apt-get install -y -qq jq 2>/dev/null
    elif command -v dnf &>/dev/null;    then sudo dnf install -y -q jq 2>/dev/null
    elif command -v pacman &>/dev/null; then sudo pacman -Sy --noconfirm jq 2>/dev/null
    elif command -v brew &>/dev/null;   then brew install jq 2>/dev/null
    fi
    command -v jq &>/dev/null || { echo "[X] No se pudo instalar jq" >&2; exit 1; }
    echo "[OK] jq instalado"
fi

SHA_CMD=""
if command -v sha256sum &>/dev/null; then
    SHA_CMD="sha256sum"
elif command -v shasum &>/dev/null; then
    SHA_CMD="shasum -a 256"
else
    echo "Ni sha256sum ni shasum disponibles" >&2
    exit 1
fi

if [[ ! -e "$IMAGEN" ]]; then
    echo "Imagen no encontrada: $IMAGEN" >&2
    exit 2
fi

mantis_note() {
    local ticket="$1" text="$2"
    [[ -z "$ticket" ]] && return
    local env_file url="" tok=""
    for env_file in "$(dirname "$0")/../../../scripts/common/.env" \
                    "$(dirname "$0")/../../../.env.example"; do
        [[ -f "$env_file" ]] || continue
        url=$(grep '^MANTIS_URL=' "$env_file" | head -1 | cut -d= -f2- | tr -d "'\"")
        tok=$(grep '^MANTIS_TOKEN=' "$env_file" | head -1 | cut -d= -f2- | tr -d "'\"")
        break
    done
    [[ -z "$url" || -z "$tok" ]] && return
    curl -s -X POST "$url/api/rest/issues/$ticket/notes" \
        -H "Authorization: Bearer $tok" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$text\"}" &>/dev/null \
        && echo "[OK] Nota creada en ticket #$ticket" \
        || echo "[!] No se pudo crear nota en MantisBT"
}

# ── SHA-256 de fichero o de árbol (carpeta Clonezilla) ──────────────────────
sha256_of() {
    local target="$1"
    if [[ -d "$target" ]]; then
        # Carpeta: hash determinista combinando hashes individuales ordenados
        find "$target" -type f -print0 | LC_ALL=C sort -z \
            | xargs -0 $SHA_CMD 2>/dev/null \
            | $SHA_CMD | awk '{print $1}'
    else
        $SHA_CMD "$target" | awk '{print $1}'
    fi
}

echo "Calculando SHA-256 de $IMAGEN..."
HASH=$(sha256_of "$IMAGEN")
if [[ -z "$HASH" ]]; then
    echo "No se pudo calcular el hash de $IMAGEN" >&2
    exit 1
fi

TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
ID=$(printf '%s-%s-%s' "$EQUIPO" "$(date -u '+%Y%m%d%H%M%S')" "$$" \
     | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')

if [[ -d "$IMAGEN" ]]; then
    ABS_PATH=$(cd "$IMAGEN" && pwd)
else
    ABS_PATH=$(cd "$(dirname "$IMAGEN")" && pwd)/$(basename "$IMAGEN")
fi

# ── Manifiesto: crear si no existe, validar si existe ───────────────────────
if [[ ! -f "$MANIFEST" ]]; then
    echo '{"version":"1.0","imagenes":[]}' > "$MANIFEST"
fi

if ! jq empty "$MANIFEST" 2>/dev/null; then
    echo "Manifiesto corrupto: $MANIFEST" >&2
    exit 1
fi

# ── Añadir entrada con jq (sin concatenar strings — regresión 2026-05-09) ───
TMP=$(mktemp "${MANIFEST}.tmp.XXXXXX")
trap 'rm -f "$TMP"' EXIT

jq \
   --arg id     "$ID" \
   --arg equipo "$EQUIPO" \
   --arg so     "$SO" \
   --arg estado "$ESTADO" \
   --arg ruta   "$ABS_PATH" \
   --arg hash   "$HASH" \
   --arg fecha  "$TS" \
   --arg notas  "$NOTAS" \
   '.imagenes += [{
        id:              $id,
        equipo:          $equipo,
        so:              $so,
        estado:          $estado,
        ruta:            $ruta,
        hash_sha256:     $hash,
        fecha_registro:  $fecha,
        notas:           $notas
    }]' "$MANIFEST" > "$TMP" || { echo "Fallo al actualizar manifiesto" >&2; exit 1; }

if ! jq empty "$TMP" 2>/dev/null; then
    echo "Manifiesto temporal corrupto — abortando sin tocar el original" >&2
    exit 1
fi

mv "$TMP" "$MANIFEST"
trap - EXIT

echo "✓ Imagen registrada"
echo "  id:         $ID"
echo "  ruta:       $ABS_PATH"
echo "  hash:       $HASH"
echo "  manifiesto: $MANIFEST"
mantis_note "$TICKET" "ResolveCore Clonacion: imagen_registrada id=$ID equipo=$EQUIPO so=$SO estado=$ESTADO hash=${HASH:0:12}... fecha=$TS"
exit 0
