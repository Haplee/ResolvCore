<?php
# ============================================================
# SetDuedate — SLA automático ResolveCore
# Asigna fecha de vencimiento automática según prioridad.
# ============================================================
#
# SLA de ResolveCore (según landing page: respuesta < 2h):
#
# Prioridad MantisBT → Horas hasta vencimiento
# ─────────────────────────────────────────────
# immediate  (60) →  1 hora   (SLA urgente)
# urgent     (50) →  2 horas  (SLA estándar)
# high       (40) →  4 horas
# normal     (30) → 24 horas
# low        (20) → 72 horas
# none       (10) → sin fecha
#
# Activar en: Gestionar → Plugins → SetDuedate → Configuración
#
# Mapeo (en horas, 0 = sin vencimiento):
$g_setduedate_priority_map = [
    60 => 1,    // immediate
    50 => 2,    // urgent
    40 => 4,    // high
    30 => 24,   // normal
    20 => 72,   // low
    10 => 0,    // none
];

# Aplicar solo cuando el ticket es nuevo (estado new):
$g_setduedate_only_on_new = true;

# No sobreescribir si ya tiene fecha asignada manualmente:
$g_setduedate_overwrite = false;
