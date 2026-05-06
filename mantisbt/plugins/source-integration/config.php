<?php
# ============================================================
# source-integration — Configuración ResolveCore
# Este archivo se copia al directorio del plugin en el servidor.
# ============================================================
#
# La configuración principal se hace en MantisBT:
#   Gestionar → Repositorios → Crear repositorio
#
# Tipo:     GitHub
# Nombre:   ResolveCore
# URL:      https://github.com/Haplee/ResolveCore
# Branch:   main
#
# Webhook en GitHub (Settings → Webhooks → Add webhook):
#   Payload URL:  https://tudominio.com/mantis/plugin.php?page=Source/checkin
#   Content type: application/json
#   Secret:       [generar con: php -r "echo bin2hex(random_bytes(20));"]
#   Events:       Just the push event
#
# ── Comportamiento en commits ─────────────────────────────────
# Para vincular un commit a un ticket, usar en el mensaje:
#
#   fix #42: corregir bug en diagnóstico Windows
#   refs #17, #18: actualizar scripts Linux
#
# Palabras clave configurables abajo:
$g_source_integration_commit_fix_regex = '(?:fix(?:e[sd])?|close[sd]?|resolve[sd]?) #(\d+)';
$g_source_integration_commit_ref_regex = '(?:refs?|see|for|re) #(\d+)';

# ── Estado del ticket al hacer fix ───────────────────────────
# 80 = RESOLVED en MantisBT
$g_source_integration_resolve_status = 80;
