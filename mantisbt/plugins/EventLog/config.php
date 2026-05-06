<?php
# ============================================================
# EventLog — Auditoría de eventos · ResolveCore
# ============================================================
#
# Registra todos los eventos relevantes de MantisBT:
# login, logout, creación/cierre de tickets, cambios de estado,
# añadir notas, adjuntar archivos, cambios de configuración.
#
# Imprescindible para:
#   - Cumplimiento de trazabilidad (TFG ASIR: seguridad)
#   - Auditoría de acciones del técnico sobre tickets
#   - Detección de accesos no autorizados
#
# Log accesible en: Gestionar → EventLog

# Eventos a registrar (true = registrar):
$g_eventlog_log_login         = true;
$g_eventlog_log_issue_create  = true;
$g_eventlog_log_issue_update  = true;
$g_eventlog_log_issue_delete  = true;
$g_eventlog_log_note_create   = true;
$g_eventlog_log_file_upload   = true;
$g_eventlog_log_config_change = true;
$g_eventlog_log_user_create   = true;
$g_eventlog_log_user_update   = true;

# Retención del log (días, 0 = indefinido):
$g_eventlog_retention_days = 365;
