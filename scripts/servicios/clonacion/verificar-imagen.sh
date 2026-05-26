#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Clonación: verificación de integridad de imagen
#
# Recalcula el SHA-256 de una imagen y lo compara con el valor registrado en el
# manifiesto. Detecta corrupción antes de intentar restaurar bare-metal.
#
# Uso:
#   bash verificar-imagen.sh --imagen <ruta>
#   bash verificar-imagen.sh --manifest <ruta> --id <id>
#
# Argumentos:
#   --imagen   <ruta>     Imagen a verificar (busca por ruta en el manifiesto)
#   --manifest <ruta>     Manifiesto JSON (default: ./imagenes-manifest.json)
#   --id       <id>       Identificador de entrada del manifiesto a verificar
#
# Exit codes:
#   0  imagen íntegra (hash coincide)
#   1  imagen corrupta (hash no coincide)
#   2  imagen o entrada de manifiesto no encontrada
#
# Autor:   FranVi / ResolveCore
# Versión: 1.0.0
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

IMAGEN=""
MANIFEST="./imagenes-manifest.json"
ID=""
TICKET=""

show_help() { sed -n '2,24p' "$0" | sed 's/^# \?//'; exit 0; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --imagen)   IMAGEN="${2:-}";   shift 2 ;;
        --manifest) MANIFEST="${2:-}"; shift 2 ;;
        --id)       ID="${2:-}";       shift 2 ;;
        --ticket)   TICKET="${2:-}"; shift 2 ;;
        -h|--help)  show_help ;;
        *) echo "Argumento desconocido: $1" >&2; exit 2 ;;
    esac
done

if [[ -z "$IMAGEN" && -z "$ID" ]]; then
    echo "Especifica --imagen <ruta> o --id <id>" >&2
    exit 2
fi

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

if [[ ! -f "$MANIFEST" ]]; then
    echo "Manifiesto no encontrado: $MANIFEST" >&2
    exit 2
fi

if ! jq empty "$MANIFEST" 2>/dev/null; then
    echo "Manifiesto corrupto: $MANIFEST" >&2
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

# ── Localizar entrada ───────────────────────────────────────────────────────
ENTRY=""
if [[ -n "$ID" ]]; then
    ENTRY=$(jq --arg id "$ID" '.imagenes[] | select(.id == $id)' "$MANIFEST")
else
    ABS=$(readlink -f "$IMAGEN" 2>/dev/null || realpath "$IMAGEN" 2>/dev/null || echo "$IMAGEN")
    ENTRY=$(jq --arg r1 "$IMAGEN" --arg r2 "$ABS" \
        '.imagenes[] | select(.ruta == $r1 or .ruta == $r2)' "$MANIFEST")
fi

if [[ -z "$ENTRY" ]]; then
    echo "Entrada no encontrada en el manifiesto" >&2
    exit 2
fi

EXPECTED=$(echo "$ENTRY" | jq -r '.hash_sha256')
RUTA=$(echo "$ENTRY"     | jq -r '.ruta')
EQUIPO=$(echo "$ENTRY"   | jq -r '.equipo')

if [[ ! -e "$RUTA" ]]; then
    echo "Imagen registrada pero no existe en disco: $RUTA" >&2
    exit 2
fi

sha256_of() {
    local target="$1"
    if [[ -d "$target" ]]; then
        find "$target" -type f -print0 | LC_ALL=C sort -z \
            | xargs -0 $SHA_CMD 2>/dev/null \
            | $SHA_CMD | awk '{print $1}'
    else
        $SHA_CMD "$target" | awk '{print $1}'
    fi
}

echo "Verificando $RUTA..."
ACTUAL=$(sha256_of "$RUTA")

echo "  equipo:   $EQUIPO"
echo "  esperado: $EXPECTED"
echo "  obtenido: $ACTUAL"

if [[ "$EXPECTED" == "$ACTUAL" ]]; then
    echo "✓ OK — imagen íntegra"
    mantis_note "$TICKET" "ResolveCore Clonacion: verificacion=OK equipo=$EQUIPO ruta=$RUTA hash_ok=${ACTUAL:0:12}..."
    exit 0
else
    echo "✗ CORRUPTA — el hash no coincide" >&2
    mantis_note "$TICKET" "ResolveCore Clonacion: verificacion=CORRUPTA equipo=$EQUIPO ruta=$RUTA esperado=${EXPECTED:0:12}... obtenido=${ACTUAL:0:12}..."
    exit 1
fi
