#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Congelación de sistemas Linux
#
# Configura y gestiona la congelación del sistema en equipos Linux mediante
# BTRFS + snapper: snapshots del sistema con rollback automático desde GRUB.
# Permite restaurar un estado de referencia descartando los cambios de la sesión.
#
# Justificación técnica y comparativa de herramientas:
#   docs/tecnica/servicios-adicionales.md (sección 1)
#
# --- STUB / NO IMPLEMENTADO ---
# Este script es scaffolding. La lógica se implementa siguiendo:
#   docs/tareas/implementar-servicios-adicionales.md
#
# Uso (contrato previsto):
#   bash congelacion-linux.sh --action status
#   bash congelacion-linux.sh --action configure
#   bash congelacion-linux.sh --action snapshot --etiqueta "estado-limpio"
#   bash congelacion-linux.sh --action rollback --confirm
#
# Argumentos:
#   --action status|configure|snapshot|rollback
#   --subvol   <ruta>     Subvolumen BTRFS objetivo (default: /)
#   --etiqueta <texto>    Descripción del snapshot (acción snapshot)
#   --confirm             Obligatorio para rollback (descarta el estado actual)
#
# Exit codes (contrato previsto):
#   0  ok
#   1  error de configuración
#   2  btrfs / snapper no disponibles
#   3  acción destructiva (rollback) sin --confirm
#
# Autor:   FranVi / ResolveCore
# Versión: 0.1.0-stub
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

# =============================================================================
# TODO(otro-dia): implementar según docs/tareas/implementar-servicios-adicionales.md
#
#   - Dependencias : command -v btrfs / snapper || exit 2.
#   - status       : listar configs de snapper + último snapshot + subvolumen.
#   - configure    : crear config snapper, fijar límites de retención,
#                    verificar entrada de rollback en GRUB.
#   - snapshot     : crear snapshot etiquetado del estado de referencia.
#   - rollback     : exigir --confirm; snapper rollback; registrar resultado.
#   - Salida       : JSON por stdout ensamblado con jq -n --argjson (esquema
#                    propio del servicio, NO el de diagnóstico).
# =============================================================================

echo "congelacion-linux.sh: STUB no implementado." >&2
echo "Ver docs/tareas/implementar-servicios-adicionales.md" >&2
exit 1
