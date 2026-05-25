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

show_help() { sed -n '2,24p' "$0" | sed 's/^# \?//'; exit 0; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --imagen)   IMAGEN="${2:-}";   shift 2 ;;
        --manifest) MANIFEST="${2:-}"; shift 2 ;;
        --id)       ID="${2:-}";       shift 2 ;;
        -h|--help)  show_help ;;
        *) echo "Argumento desconocido: $1" >&2; exit 2 ;;
    esac
done

if [[ -z "$IMAGEN" && -z "$ID" ]]; then
    echo "Especifica --imagen <ruta> o --id <id>" >&2
    exit 2
fi

if ! command -v jq &>/dev/null; then
    echo "jq no instalado" >&2
    exit 2
fi

SHA_CMD=""
if command -v sha256sum &>/dev/null; then
    SHA_CMD="sha256sum"
elif command -v shasum &>/dev/null; then
    SHA_CMD="shasum -a 256"
else
    echo "Ni sha256sum ni shasum disponibles" >&2
    exit 2
fi

if [[ ! -f "$MANIFEST" ]]; then
    echo "Manifiesto no encontrado: $MANIFEST" >&2
    exit 2
fi

if ! jq empty "$MANIFEST" 2>/dev/null; then
    echo "Manifiesto corrupto: $MANIFEST" >&2
    exit 2
fi

# ── Localizar entrada ───────────────────────────────────────────────────────
ENTRY=""
if [[ -n "$ID" ]]; then
    ENTRY=$(jq --arg id "$ID" '.imagenes[] | select(.id == $id)' "$MANIFEST")
else
    ABS=$(cd "$(dirname "$IMAGEN")" 2>/dev/null && echo "$(pwd)/$(basename "$IMAGEN")" || echo "$IMAGEN")
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
    exit 0
else
    echo "✗ CORRUPTA — el hash no coincide" >&2
    exit 1
fi
