#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Limpieza básica de un dispositivo Android vía ADB.
#
# Vacía la caché de cada paquete instalado y borra ficheros temporales
# en /data/local/tmp.
#
# OJO: pm clear borra también ajustes de la app (login, preferencias).
#      Por eso la flag --confirm es obligatoria; pedir consentimiento
#      explícito al cliente antes de ejecutarlo.
#
# Uso:
#   bash optimizacion.sh --confirm
#   bash optimizacion.sh <serial> --confirm
#
# Autor:   Francisco Vidal Mateo (FranVi)
# Versión: 2.0
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

if ! command -v adb >/dev/null 2>&1; then
    echo "ERROR: 'adb' no encontrado en el PATH." >&2
    exit 1
fi

# Parseo de args — admite "serial --confirm" o solo "--confirm".
SERIAL=""
CONFIRM=0
for arg in "$@"; do
    case "$arg" in
        --confirm) CONFIRM=1 ;;
        *)         SERIAL="$arg" ;;
    esac
done

if [ "$CONFIRM" -ne 1 ]; then
    echo "Uso: bash $0 [serial] --confirm"
    echo ""
    echo "ATENCIÓN: pm clear vacía también ajustes y sesiones de cada app."
    echo "Confirma con el cliente antes de ejecutarlo."
    exit 0
fi

ADB="adb${SERIAL:+ -s $SERIAL}"

if ! $ADB get-state >/dev/null 2>&1; then
    echo "ERROR: dispositivo no conectado o no autorizado." >&2
    exit 1
fi

# ── Limpieza caché aplicaciones ─────────────────────────────────────────────
# Listamos paquetes y aplicamos pm clear a cada uno. Hay paquetes del
# sistema que rechazan la limpieza; los ignoramos silenciosamente.

echo "[+] Limpiando caché de paquetes instalados..."
$ADB shell pm list packages 2>/dev/null | cut -d: -f2 | while read -r pkg; do
    $ADB shell pm clear "$pkg" >/dev/null 2>&1 || true
done

# ── /data/local/tmp ─────────────────────────────────────────────────────────
echo "[+] Limpiando /data/local/tmp..."
$ADB shell rm -rf /data/local/tmp/* 2>/dev/null || true

echo ""
echo "[+] Optimización Android completada."
