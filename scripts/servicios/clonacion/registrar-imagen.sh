#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ResolveCore — Clonación: alta de imagen en el manifiesto
#
# Registra una imagen de clonación (creada con Clonezilla / FOG / Veeam) en un
# manifiesto JSON. El manifiesto da trazabilidad de qué imagen corresponde a qué
# equipo, fecha, sistema operativo y estado, junto con su hash de integridad.
#
# Justificación técnica:
#   docs/tecnica/servicios-adicionales.md (sección 2)
#
# --- STUB / NO IMPLEMENTADO ---
# Este script es scaffolding. La lógica se implementa siguiendo:
#   docs/tareas/implementar-servicios-adicionales.md
#
# Uso (contrato previsto):
#   bash registrar-imagen.sh --imagen <ruta> --equipo <nombre> \
#        --so <windows|linux|macos> --estado <limpio|post-instalacion|produccion>
#
# Argumentos:
#   --imagen   <ruta>     Fichero o carpeta de imagen a registrar
#   --equipo   <nombre>   Identificador del equipo de origen
#   --so       <texto>    Sistema operativo de la imagen
#   --estado   <texto>    limpio | post-instalacion | produccion
#   --manifest <ruta>     Manifiesto JSON destino (default: ./imagenes-manifest.json)
#
# Exit codes (contrato previsto):
#   0  ok
#   1  argumentos inválidos
#   2  imagen no encontrada
#
# Autor:   FranVi / ResolveCore
# Versión: 0.1.0-stub
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

# =============================================================================
# TODO(otro-dia): implementar según docs/tareas/implementar-servicios-adicionales.md
#
#   - Validar argumentos obligatorios (--imagen, --equipo, --so, --estado).
#   - command -v jq sha256sum || exit 1.
#   - Verificar que la ruta de --imagen existe || exit 2.
#   - Calcular hash SHA256 de la imagen.
#   - Crear/actualizar el manifiesto con jq -n --argjson — NUNCA concatenar
#     strings (ver regresión 2026-05-09 en docs/defensa/auditoria-mejoras.md, S3).
#   - Cada entrada: id, equipo, so, estado, ruta, hash, fecha_registro.
# =============================================================================

echo "registrar-imagen.sh: STUB no implementado." >&2
echo "Ver docs/tareas/implementar-servicios-adicionales.md" >&2
exit 1
