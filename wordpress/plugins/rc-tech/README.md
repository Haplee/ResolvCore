# rc-tech — Panel Técnico ResolveCore

Plugin WordPress que añade un panel unificado en `wp-admin` para que los técnicos gestionen tickets MantisBT con menos clicks, alertas SLA proactivas y vista priorizada.

> **Nota sobre el informe PDF (inactivo).** La quick-action **PDF** (`RC_Tech_Report::generate()`, HTML→PDF wkhtmltopdf) es código **legacy y NO forma parte del flujo actual**. El informe que recibe el cliente es la plantilla `.txt` que el técnico rellena a mano y sube a MantisBT él mismo (decisión del autor, 2026-06-02). El código se conserva por referencia; mantenerlo **no implica reactivar el PDF**. Requisitos y endpoint marcados abajo con _(inactivo)_.

## Requisitos

- WordPress ≥ 6.0, PHP ≥ 8.0
- Plugin `rc-mantisbt` activado y configurado (URL + token)
- Plugin `rc-fleet` opcional (habilita columna "Host score" + lookup en quick-action PDF)
- MantisBT 2.28+ con plugin `SetDueDate` activado (alimenta `due_date` para el SLA)
- `shell_exec` habilitado en PHP para la quick-action **PDF** _(inactivo — ver nota arriba; no se requiere en el flujo actual)_

## Instalación

1. Copiar carpeta a `wp-content/plugins/rc-tech/`.
2. Activar desde **Plugins** → la activación crea `wp_rc_tech_alerts` y programa los cron `rc_tech_sla_check` (5min) y `rc_tech_gc_alerts` (diario).
3. Abrir **Panel Técnico** en el menú lateral del admin.

## Endpoints REST

Namespace: `wp-json/rc-tech/v1/`

| Ruta | Método | Función |
|---|---|---|
| `/queue` | GET | Cola priorizada (cache transient 30s) |
| `/timeline/{id}` | GET | Mantis history+notes mezclado con últimos 5 diagnósticos fleet |
| `/alerts` | GET | Últimas 50 alertas SLA disparadas |
| `/export.csv` | GET | Exporta cola actual en CSV (BOM UTF-8) |
| `/action/assign_me` | POST | Asigna ticket al técnico actual |
| `/action/resolve` | POST | Marca status=resolved + nota opcional |
| `/action/diag_note` | POST | Nota privada "inicio diagnóstico" |
| `/action/pdf` _(inactivo)_ | POST | **Legacy, fuera del flujo actual.** Genera informe con `RC_Tech_Report::generate()` (HTML→PDF wkhtmltopdf, fallback HTML) y autoadjunta a Mantis. El flujo real usa plantilla `.txt` a mano. |

Auth: cookie WP + `X-WP-Nonce`. Capacidad requerida: `rc_tech` (añadida automáticamente al rol `administrator` en activación).

## Smoke tests

Ver `docs/tecnica/rc-tech-panel.md` (en breve) para procedimiento end-to-end por fase.

Rápido:

```bash
wp plugin activate rc-tech
wp cron event list | grep rc_tech
wp cron event run rc_tech_sla_check
tail -f wp-content/debug.log | grep '\[rc-tech\]'
```

## Add-ons

`includes/addon-telegram.example.php` — engancha `rc_tech_alert_fired` para enviar a Telegram. Copiar a `wp-content/mu-plugins/` y definir `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID` en `wp-config.php`.
