<?php
# ============================================================
# mailtemplate — Emails HTML · ResolveCore
# ============================================================
#
# Activa emails HTML con la identidad visual de ResolveCore.
# Paleta: fondo #0a0c10, acento #00e5a0, texto #e8eaf0
#
# Tras activar el plugin en MantisBT:
#   Gestionar → Plugins → Mail Template → Configurar
#   → seleccionar la plantilla "resolvecore"
#
# La plantilla HTML se puede personalizar en:
#   plugins/mailtemplate/templates/resolvecore.html
#
# Variables disponibles en la plantilla:
#   {issue_id}       → Número de ticket
#   {issue_summary}  → Resumen del ticket
#   {issue_url}      → Enlace directo al ticket
#   {reporter}       → Nombre del usuario que reportó
#   {assignee}       → Técnico asignado
#   {status}         → Estado actual
#   {priority}       → Prioridad
#   {project}        → Nombre del proyecto

# Formato de email por defecto:
$g_mailtemplate_format = 'html';

# Pie de firma en todos los emails:
$g_mailtemplate_footer = 'ResolveCore · Solución a tus problemas informáticos · https://tudominio.com';
