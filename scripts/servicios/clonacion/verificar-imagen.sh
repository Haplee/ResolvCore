#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Clonación: verificación de integridad de imagen
#
# Recalcula el hash de una imagen de clonación y lo compara con el valor
# registrado en el manifiesto. Detecta corrupción de la imagen antes de
# intentar una restauración bare-metal.
#
# Justificación técnica:
#   docs/tecnica/servicios-adicionales.md (sección 2)
#
# --- STUB / NO IMPLEMENTADO ---
# Este script es scaffolding. La lógica se implementa siguiendo:
#   docs/tareas/implementar-servicios-adicionales.md
#
# Uso (contrato previsto):
#   bash verificar-imagen.sh --imagen <ruta>
#   bash verificar-imagen.sh --manifest <ruta> --id <id>
#
# Argumentos:
#   --imagen   <ruta>     Imagen a verificar (hash directo contra el manifiesto)
#   --manifest <ruta>     Manifiesto JSON (default: ./imagenes-manifest.json)
#   --id       <id>       Identificador de entrada del manifiesto a verificar
#
# Exit codes (contrato previsto):
#   0  imagen íntegra (el hash coincide)
#   1  imagen corrupta (el hash no coincide)
#   2  imagen o entrada de manifiesto no encontrada
#
# Autor:   FranVi / ResolveCore
# Versión: 0.1.0-stub
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

# =============================================================================
# TODO(otro-dia): implementar según docs/tareas/implementar-servicios-adicionales.md
#
#   - command -v jq sha256sum || exit 2.
#   - Localizar la entrada en el manifiesto (por --id o por la ruta de --imagen).
#   - Recalcular SHA256 de la imagen en disco.
#   - Comparar con el hash registrado: coincide -> exit 0 ; difiere -> exit 1.
#   - Imagen o entrada ausente -> exit 2.
#   - Salida legible: OK / CORRUPTO + hash esperado vs hash obtenido.
# =============================================================================

echo "verificar-imagen.sh: STUB no implementado." >&2
echo "Ver docs/tareas/implementar-servicios-adicionales.md" >&2
exit 1
