<?php
# ============================================================
# Reminder — Avisos de tickets sin atender · ResolveCore
# ============================================================
#
# Envía recordatorio por email cuando un ticket lleva X horas
# sin cambio de estado. Garantiza el SLA < 2h prometido.
#
# Configurar el cron en el VPS:
#   # Cada hora, comprueba tickets sin atender
#   0 * * * * www-data php /var/www/mantis/scripts/reminder.php
#
# ── Intervalos de aviso ───────────────────────────────────────
# Tiempo sin actividad antes de enviar recordatorio (en horas):
$g_reminder_thresholds = [
    'immediate' => 0.5,   // 30 min → aviso urgente
    'urgent'    => 1,     // 1 hora
    'high'      => 2,     // 2 horas
    'normal'    => 12,    // 12 horas
    'low'       => 48,    // 48 horas
];

# A quién avisar (nivel mínimo de acceso en el proyecto):
# 55 = DEVELOPER, 70 = MANAGER
$g_reminder_notify_threshold = 55;

# Incluir al asignado actual en el aviso:
$g_reminder_notify_handler = true;
