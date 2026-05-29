#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Limpieza básica de un equipo Linux.
#
# Pasa el autoremove de apt, limpia la caché de paquetes, compacta el
# journal de systemd y borra ficheros viejos de /tmp. No toca nada del
# home del usuario aparte de la caché de miniaturas.
#
# Requiere root (sudo) para apt y journalctl.
#
# Uso:
#   sudo bash optimizacion.sh --confirm
#
# Autor:   Francisco Vidal Mateo (FranVi)
# Versión: 2.0
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

# La flag --confirm es a propósito: evita que se ejecute por accidente
# en una sesión SSH si el técnico se equivoca de ventana.
if [ "${1:-}" != "--confirm" ]; then
    echo "Uso: sudo bash $0 --confirm"
    echo ""
    echo "Esto pasa autoremove, vacía caché de apt, journal y /tmp viejo."
    exit 0
fi

info() { echo "[+] $*"; }
warn() { echo "[!] $*" >&2; }

# ── Paquetes huérfanos / caché apt ──────────────────────────────────────────

if command -v apt-get >/dev/null 2>&1; then
    info "Eliminando paquetes huérfanos..."
    apt-get autoremove -y 2>/dev/null || warn "apt autoremove falló (sin permisos?)"

    info "Vaciando caché de apt..."
    apt-get clean 2>/dev/null || warn "apt clean falló"
fi

# ── Journal de systemd ──────────────────────────────────────────────────────
# 30 días es un compromiso razonable: si hay un problema reciente todavía
# se puede investigar, pero no acumulamos GB de logs antiguos.

if command -v journalctl >/dev/null 2>&1; then
    info "Compactando journal (>30 días)..."
    journalctl --vacuum-time=30d 2>/dev/null || warn "journalctl falló"
fi

# ── /tmp ────────────────────────────────────────────────────────────────────
# Solo lo que tenga más de 7 días — algunos servicios usan /tmp con
# ficheros recientes y borrarlos en caliente puede romperlos.

info "Limpiando ficheros antiguos de /tmp (>7 días)..."
find /tmp -maxdepth 1 -mtime +7 -exec rm -rf {} + 2>/dev/null || true

# TODO: añadir snap cleanup si el equipo es Ubuntu y tiene snaps.

echo ""
info "Optimización completada."
