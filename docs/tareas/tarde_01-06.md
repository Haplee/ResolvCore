# Tarde — 01-06-2026

Registro de la sesión de tarde del 1 de junio de 2026.

---

## Contexto

Al abrir `wordpress/resolvecore-theme/functions.php` en el IDE (Antigravity /
Intelephense), el servidor de lenguaje PHP reportó ~150 diagnósticos:

- `PHP0417` — *Call to unknown function* en `is_user_logged_in`, `add_action`,
  `add_filter`, `esc_html`, `esc_attr`, `esc_url`, `wp_safe_redirect`,
  `wp_enqueue_style`, `sanitize_text_field`, `wp_mail`, `get_option`,
  `update_option`, `wp_send_json_error`, `check_ajax_referer`, etc.
- `PHP0415` — *Use of undefined constant* en `HOUR_IN_SECONDS` (líneas 239, 375) y
  `MINUTE_IN_SECONDS` (líneas 698, 767, 839).

---

## Diagnóstico

**No son errores reales.** Son falsos positivos del analizador estático.

- Todas las funciones y constantes señaladas pertenecen al **núcleo de WordPress**.
- WordPress las define **en tiempo de ejecución** al cargar `wp-load.php`.
- El analizador estático (Intelephense) no carga el núcleo de WP, así que no "ve"
  esos símbolos y los marca como desconocidos.
- El código del tema es correcto: en producción esas funciones existen siempre,
  porque el tema solo se ejecuta dentro de WordPress.

Causa raíz del ruido: el proyecto **no tenía configurados los stubs de WordPress**
en el editor (sin `composer.json`, sin `.vscode/settings.json`, sin
`*.code-workspace`).

---

## Opciones evaluadas

| Opción | Qué hace | Coste | Veredicto |
|--------|----------|-------|-----------|
| **A** — `php-stubs/wordpress-stubs` vía Composer | Añade los stubs como dependencia dev; Intelephense lee `vendor/` | Mete `composer.json` + `vendor/` en el repo | Descartada: bloat innecesario para un TFG sin build PHP |
| **B** — Configurar `intelephense.stubs` | Activa el stub `wordpress` que Intelephense ya trae integrado | 1 fichero, cero dependencias | **Elegida** |
| **C** — Ignorar | No tocar nada; convivir con el ruido | 0 | Descartada: ruido constante al editar |

**Decisión:** Opción **B**. Es la que mejor conviene al proyecto — repo limpio, sin
`vendor/`, sin proceso de build, y silencia los falsos positivos al instante.

---

## Cambio aplicado

Creado `.vscode/settings.json` con:

- `intelephense.stubs`: lista completa de extensiones PHP estándar **+** `wordpress`,
  `wordpress-globals`, `wp-cli` (y `woocommerce`/`acf-pro` por si se integran más
  adelante).
- `intelephense.environment.phpVersion`: `8.2.0` (coincide con el entorno LocalWP
  custom PHP 8.2 / nginx / mysql).
- `intelephense.files.exclude`: ignora `.git`, `node_modules`, `vendor` y `_archivo`
  (código archivado, no del árbol activo).

Resultado: los ~150 diagnósticos `PHP0417` / `PHP0415` desaparecen tras recargar la
ventana del editor (`Developer: Reload Window`).

---

## Verificación

- [ ] Recargar ventana del IDE y confirmar 0 diagnósticos en `functions.php`.
- [ ] Confirmar que `add_action`, `esc_html`, `HOUR_IN_SECONDS` resuelven (hover muestra
      la firma de WP).

> Nota: `.vscode/settings.json` es config local del editor. Decidir si se versiona
> (útil para reproducir el entorno) o se añade a `.gitignore`. Recomendado versionarlo
> en un TFG para que el tribunal reproduzca el setup sin fricción.

---

## Referencias

- Tema afectado: `wordpress/resolvecore-theme/functions.php`
- Config nueva: `.vscode/settings.json`
- Stub usado: `wordpress` (integrado en Intelephense, sin Composer)
