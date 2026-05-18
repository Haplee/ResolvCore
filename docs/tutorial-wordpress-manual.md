# Tutorial — Montaje manual de la web ResolveCore en WordPress

> Guía paso a paso para construir la web pública de ResolveCore **a mano**, módulo a módulo, sin builders ni automatismos. Sirve como manual de despliegue y como evidencia técnica para el TFG.
>
> **Autor:** Francisco Vidal Mateo · TFG ASIR 2025/26
> **Última actualización:** 2026-05-17
> **Tiempo estimado total:** 4–6 h (primera vez), ~1 h (re-instalación)

---

## Índice

1. [Antes de empezar — requisitos y materiales](#1-antes-de-empezar)
2. [Módulo 1 — Entorno local (LocalWP)](#módulo-1--entorno-local-localwp)
3. [Módulo 2 — Instalación y activación del tema `resolvecore-theme`](#módulo-2--tema-resolvecore-theme)
4. [Módulo 3 — Páginas y menús (Home, Docs, Changelog, Contacto)](#módulo-3--páginas-y-menús)
5. [Módulo 4 — Plugin `rc-mantisbt` (integración con MantisBT)](#módulo-4--plugin-rc-mantisbt)
6. [Módulo 5 — Configuración segura de credenciales en `wp-config.php`](#módulo-5--credenciales-en-wp-configphp)
7. [Módulo 6 — Formulario de contacto AJAX y pruebas end-to-end](#módulo-6--formulario-de-contacto-ajax)
8. [Módulo 7 — Backup y despliegue a producción](#módulo-7--backup-y-despliegue)
9. [Checklist final + capturas obligatorias](#checklist-final)
10. [Troubleshooting](#troubleshooting)

---

## 1. Antes de empezar

### Materiales necesarios

| Recurso | Descripción | Dónde se obtiene |
|---------|-------------|------------------|
| LocalWP | Stack WordPress local (NGINX + PHP 8.2 + MariaDB) | <https://localwp.com> |
| MantisBT 2.27 LTS | Bug tracker — se instala aparte (ver `mantisbt/`) | Repo del proyecto |
| Repositorio ResolvCore | Tema + plugin | `C:\Users\franc\proyecto\ResolvCore` |
| Editor | VS Code / Antigravity / similar | — |

### Estructura que debes obtener al final

```
LocalWP site/wp-content/
├── themes/
│   └── resolvecore-theme/       ← Módulo 2
└── plugins/
    └── rc-mantisbt/             ← Módulo 4
```

### Carpeta de capturas

Crea ya el directorio donde guardarás las evidencias:

```
docs/capturas/tutorial-wordpress/
├── 01-localwp/
├── 02-tema/
├── 03-paginas/
├── 04-plugin/
├── 05-config/
├── 06-formulario/
└── 07-backup/
```

> **Norma del proyecto** (`CLAUDE.md`): cada paso documentado debe ir acompañado de una captura PNG en `docs/capturas/`. Nombrado: `NN_descripcion.png`.

---

## Módulo 1 — Entorno local (LocalWP)

> **Objetivo:** WordPress arrancando en `https://resolvecore-dev.local` con admin accesible.

### Paso 1.1 — Instalar LocalWP

1. Descarga LocalWP desde <https://localwp.com> (versión Windows).
2. Ejecuta el instalador como administrador. Acepta los valores por defecto.
3. La primera vez te pedirá crear una cuenta gratuita — sáltalo con "Skip".

📸 **Captura 1.1** → `docs/capturas/tutorial-wordpress/01-localwp/01_localwp_instalado.png`

### Paso 1.2 — Crear el sitio

1. Pulsa **Create a new site** → **Create a new site** (no "Add Existing").
2. Rellena:
   - **Site name:** `ResolveCore Dev`
   - **Local site domain:** `resolvecore-dev.local`
3. Pulsa **Custom** (no "Preferred") y define:
   - **PHP:** 8.2.x
   - **Web Server:** NGINX
   - **Database:** MariaDB 10.6+
4. Credenciales de WordPress:
   - **Username:** `admin`
   - **Password:** `resolvecore-dev` *(efímera, solo dev)*
   - **Email:** el del proyecto.
5. Pulsa **Add Site**. Tarda 1–2 minutos en provisionarse.

📸 **Captura 1.2** → `02_localwp_sitio_creado.png`

### Paso 1.3 — Verificar acceso

1. En LocalWP, con el sitio seleccionado, pulsa **Open site** (frontend) y **WP Admin** (backend).
2. El admin debería abrirse en `https://resolvecore-dev.local/wp-admin`.
3. Verifica versión de WordPress: **Escritorio → Acerca de WordPress** → debe ser ≥ 6.4.

📸 **Captura 1.3** → `03_localwp_wp_admin.png`

### Paso 1.4 — Localizar la carpeta del sitio

Pulsa **Go to site folder** en LocalWP. Apunta esta ruta — la usarás todo el tutorial.

```
<LocalSites>/resolvecore-dev/app/public/
```

> **Criterio de hecho:** al abrir `https://resolvecore-dev.local` ves la home de WordPress por defecto.

---

## Módulo 2 — Tema `resolvecore-theme`

> **Objetivo:** la home pasa de "Hello world" al landing oscuro de ResolveCore.

### Paso 2.1 — Copiar el tema

Tienes dos opciones; usa **B** si planeas iterar sobre el código.

**Opción A — Copia simple:**

```powershell
Copy-Item -Recurse `
  "C:\Users\franc\proyecto\ResolvCore\wordpress\resolvecore-theme" `
  "<LocalSites>\resolvecore-dev\app\public\wp-content\themes\resolvecore-theme"
```

**Opción B — Enlace simbólico (recomendado para desarrollo):**

```powershell
New-Item -ItemType SymbolicLink `
  -Path "<LocalSites>\resolvecore-dev\app\public\wp-content\themes\resolvecore-theme" `
  -Target "C:\Users\franc\proyecto\ResolvCore\wordpress\resolvecore-theme"
```

> Para crear symlinks en Windows necesitas PowerShell como administrador o tener activado el "Modo desarrollador".

### Paso 2.2 — Activar el tema

1. WP Admin → **Apariencia → Temas**.
2. Busca **ResolveCore** en la lista. Pasa el ratón → **Activar**.
3. Visita la home (`https://resolvecore-dev.local`): debería mostrarse el landing oscuro con el hero "Solución a tus problemas informáticos".

📸 **Captura 2.1** → `02-tema/01_tema_activado.png`
📸 **Captura 2.2** → `02-tema/02_home_landing.png`

### Paso 2.3 — Validar componentes del tema

El tema expone tres plantillas. Comprueba cada una:

| Archivo | URL esperada | Qué debes ver |
|---------|--------------|---------------|
| `front-page.php` | `/` | Hero + pricing + formulario |
| `page-docs.php` | `/docs/` (tras crear la página) | Layout con sidebar |
| `page-changelog.php` | `/changelog/` (tras crear la página) | Timeline de versiones |

Las dos últimas requieren crear la página primero — lo haces en el Módulo 3.

> **Criterio de hecho:** la home pública usa el tema ResolveCore con colores oscuros (`--rc-bg: #0a0c10`).

---

## Módulo 3 — Páginas y menús

> **Objetivo:** estructura navegable: Home, Docs, Changelog, Contacto.

### Paso 3.1 — Crear la página Documentación

1. WP Admin → **Páginas → Añadir nueva**.
2. **Título:** `Documentación`
3. En el panel derecho, **Plantilla** → selecciona `Docs`. *(Si no aparece, asegúrate de que `page-docs.php` está en el tema activo.)*
4. **Permalink:** `docs`.
5. Publica.

📸 **Captura 3.1** → `03-paginas/01_pagina_docs.png`

### Paso 3.2 — Crear la página Changelog

1. **Páginas → Añadir nueva**.
2. **Título:** `Changelog`
3. **Plantilla:** `Changelog`.
4. **Permalink:** `changelog`.
5. Publica.

### Paso 3.3 — Crear la página Contacto

1. **Páginas → Añadir nueva**.
2. **Título:** `Contacto`
3. Plantilla: **Por defecto** (el formulario lo inyecta el shortcode del plugin en el Módulo 4).
4. **Permalink:** `contacto`.
5. Publica vacía por ahora — la rellenas en el Módulo 6.

### Paso 3.4 — Configurar la página principal

1. **Ajustes → Lectura**.
2. **Tu portada muestra:** "Una página estática" → selecciona la página que use `front-page.php` (o deja "Tu última entrada" si ya se está renderizando el landing; depende de tu instalación).
3. Guarda.

### Paso 3.5 — Crear el menú principal

1. **Apariencia → Menús → Crear un menú nuevo**.
2. **Nombre del menú:** `Principal`
3. Marca dos casillas en "Ubicación del tema":
   - ✅ Menú principal
   - ❌ Menú pie de página *(crearás otro)*
4. Añade las páginas: Inicio, Documentación, Changelog, Contacto.
5. Guarda.

### Paso 3.6 — Crear el menú del footer

1. **Apariencia → Menús → Crear un menú nuevo**.
2. **Nombre:** `Footer`
3. **Ubicación:** ✅ Menú pie de página.
4. Añade: Documentación, Changelog, Contacto, enlace externo a `https://github.com/Haplee/ResolvCore`.
5. Guarda.

📸 **Captura 3.2** → `03-paginas/02_menus_configurados.png`

> **Criterio de hecho:** el header del landing muestra los cuatro enlaces y todos resuelven a la página correcta.

---

## Módulo 4 — Plugin `rc-mantisbt`

> **Objetivo:** crear un ticket en MantisBT cada vez que se envía el formulario de contacto.

### Pre-requisito — MantisBT operativo

Debes tener MantisBT 2.27 instalado y accesible con un token API. Si no es el caso, sigue antes [`docs/mantis-integration.md`](mantis-integration.md) y la sección "INFRA-04" del planning del sprint anterior.

Necesitas tener a mano:

- URL base de MantisBT (ej. `https://mantis.resolvecore.com` o `http://localhost:8989`).
- API Token (MantisBT → **Mi cuenta → API Tokens → Crear token**).
- ID numérico del proyecto en MantisBT (visible en la URL al editar el proyecto: `manage_proj_edit_page.php?project_id=1`).

📸 **Captura 4.1** → `04-plugin/01_mantis_token_creado.png`

### Paso 4.1 — Copiar el plugin

```powershell
Copy-Item -Recurse `
  "C:\Users\franc\proyecto\ResolvCore\wordpress\plugins\rc-mantisbt" `
  "<LocalSites>\resolvecore-dev\app\public\wp-content\plugins\rc-mantisbt"
```

*(O symlink como en 2.1, opción B.)*

### Paso 4.2 — Activar el plugin

1. WP Admin → **Plugins**.
2. Busca **ResolveCore — MantisBT Integration**.
3. **Activar**.

📸 **Captura 4.2** → `04-plugin/02_plugin_activado.png`

### Paso 4.3 — Configuración inicial vía panel

> Esto es solo para validar conectividad. Las credenciales **finales** las moverás a `wp-config.php` en el Módulo 5.

1. **Ajustes → MantisBT** (aparece tras activar el plugin).
2. Rellena:
   - **Activar integración:** ✅
   - **URL de MantisBT:** `https://mantis.resolvecore.com`
   - **API Token:** *(pega el token)*
   - **ID del Proyecto:** `1` *(o el que toque)*
3. Guarda.
4. Pulsa **Verificar conexión con MantisBT**. Debe responder `Conexión OK. Proyectos disponibles: N`.

📸 **Captura 4.3** → `04-plugin/03_test_conexion_ok.png`

> **Criterio de hecho:** el botón "Verificar conexión" devuelve OK con el número correcto de proyectos.

---

## Módulo 5 — Credenciales en `wp-config.php`

> **Objetivo:** sacar el token API de la base de datos (`wp_options`) y meterlo en `wp-config.php`. Es un requisito de seguridad de `CLAUDE.md` ("nunca almacenar tokens sin cifrar en opciones de WordPress").

### Paso 5.1 — Editar `wp-config.php`

Abre `<LocalSites>\resolvecore-dev\app\public\wp-config.php`. Justo **antes** de la línea:

```php
/* That's all, stop editing! Happy publishing. */
```

añade el bloque:

```php
// ── ResolveCore · Integración MantisBT ────────────────────────────────────────
define( 'RC_MANTIS_URL',   'https://mantis.resolvecore.com' );
define( 'RC_MANTIS_TOKEN', 'pega-aqui-el-token-real' );
```

Guarda.

### Paso 5.2 — Limpiar el token de la BBDD

1. Vuelve a **Ajustes → MantisBT** en WP Admin.
2. Verás un aviso: *"Token duplicado. RC_MANTIS_TOKEN está definida en wp-config.php..."*.
3. **Vacía** el campo "API Token" en el formulario y guarda. Ahora ya no queda copia en claro en la BBDD.

📸 **Captura 5.1** → `05-config/01_wp_config_constantes.png` *(sin mostrar el token real — usa `••••`)*.
📸 **Captura 5.2** → `05-config/02_aviso_token_duplicado.png`

### Paso 5.3 — Re-verificar conexión

Pulsa **Verificar conexión con MantisBT** otra vez. Debe seguir respondiendo OK, ahora usando la constante en lugar del valor de la BBDD.

> **Criterio de hecho:** el plugin sigue funcionando aunque el campo del formulario esté vacío, porque las constantes tienen prioridad (`rc_mantis_get_token()` en `wp-config.php` > `wp_options`).

---

## Módulo 6 — Formulario de contacto AJAX

> **Objetivo:** un visitante envía el formulario en `/contacto` y se crea un ticket en MantisBT con sus datos.

### Paso 6.1 — Insertar el formulario en la página

El tema ya inyecta el formulario en `front-page.php`. Para la página `/contacto` tienes dos opciones:

**Opción A — Página dedicada:** edita la página **Contacto** y pega en el editor de bloques (modo HTML) el snippet siguiente:

```html
<form id="rc-contact-form" method="post" class="rc-form">
  <label>Nombre <input type="text" name="name" required></label>
  <label>Email <input type="email" name="email" required></label>
  <label>Tipo
    <select name="type">
      <option value="soporte">Soporte técnico</option>
      <option value="bug">Reporte de bug</option>
      <option value="colaboracion">Colaboración</option>
      <option value="licencia">Licencia</option>
      <option value="otro">Otro</option>
    </select>
  </label>
  <label>Mensaje <textarea name="message" required></textarea></label>
  <input type="hidden" name="action" value="rc_contact_submit">
  <?php wp_nonce_field( 'rc_contact', '_rc_nonce' ); ?>
  <button type="submit">Enviar</button>
</form>
```

**Opción B — Usar el del landing:** si el formulario del `front-page.php` te basta, deja `/contacto` con un enlace anchor a `/#contacto`.

### Paso 6.2 — Verificar el handler AJAX

El `functions.php` del tema ya registra el handler `rc_contact_submit`. Confírmalo:

```powershell
Select-String -Path "<LocalSites>\resolvecore-dev\app\public\wp-content\themes\resolvecore-theme\functions.php" `
  -Pattern "rc_contact_submit"
```

Debes ver al menos dos coincidencias: `add_action( 'wp_ajax_nopriv_rc_contact_submit', ... )` y `function rc_contact_submit_handler()`.

### Paso 6.3 — Test end-to-end manual

1. Visita `https://resolvecore-dev.local/contacto` *(o `/#contacto` si usas Opción B)*.
2. Rellena el formulario con datos ficticios:
   - **Nombre:** `Test Manual`
   - **Email:** `test@example.org`
   - **Tipo:** `soporte`
   - **Mensaje:** `Prueba de tutorial — ignorar.`
3. Envía. Debe mostrarse el mensaje de éxito del tema.
4. Abre MantisBT → **Ver incidencias**. El ticket nuevo debe aparecer con:
   - **Resumen:** `[ResolveCore] Soporte — Test Manual`
   - **Categoría:** `Soporte técnico`
   - **Prioridad:** `high`
   - **Descripción:** el cuerpo formateado con Markdown.

📸 **Captura 6.1** → `06-formulario/01_formulario_enviado.png`
📸 **Captura 6.2** → `06-formulario/02_ticket_creado_mantis.png`

### Paso 6.4 — Comprobar rate limiting y validación

El tema implementa rate limiting (ver `functions.php`). Envía 6 mensajes seguidos: el 6º debe rechazarse con HTTP 429. Documenta esa captura — el tribunal valora especialmente las protecciones de seguridad.

📸 **Captura 6.3** → `06-formulario/03_rate_limit_429.png`

> **Criterio de hecho:** un envío válido genera ticket, un exceso de envíos devuelve 429, un envío sin nonce devuelve 403.

---

## Módulo 7 — Backup y despliegue

> **Objetivo:** copia de seguridad reproducible y procedimiento de subida a producción (WordPress.com Business o VPS).

### Paso 7.1 — Backup local con UpdraftPlus

1. **Plugins → Añadir nuevo** → busca `UpdraftPlus`. Instala y activa.
2. **Ajustes → UpdraftPlus → Realizar copia de seguridad ahora**.
3. Marca **Incluir base de datos** + **Incluir archivos**. Pulsa **Comenzar**.
4. Cuando termine, descarga los 5 archivos (`db.gz`, `plugins.zip`, `themes.zip`, `uploads.zip`, `others.zip`) a `docs/capturas/tutorial-wordpress/07-backup/`.

📸 **Captura 7.1** → `07-backup/01_updraft_backup_ok.png`

### Paso 7.2 — Backup manual (independiente del plugin)

Desde la carpeta del sitio:

```powershell
# Exportar BBDD (LocalWP incluye wp-cli)
wp db export backup-$(Get-Date -Format yyyy-MM-dd).sql

# Comprimir wp-content
Compress-Archive -Path "wp-content" `
  -DestinationPath "wp-content-$(Get-Date -Format yyyy-MM-dd).zip"
```

Sube ambos archivos a Google Drive del proyecto (o equivalente).

### Paso 7.3 — Despliegue a producción

Hay dos rutas según lo que decidas con el tutor (ver `docs/informe-tutor-estado-proyecto.md` § preguntas pendientes):

**Ruta A — WordPress.com Business:**

1. Login en wordpress.com con la cuenta del proyecto.
2. **My site → Plugins → Upload plugin** → sube `rc-mantisbt.zip`.
3. **Appearance → Themes → Upload theme** → sube `resolvecore-theme.zip`.
4. Configura las constantes `RC_MANTIS_*` desde **My site → Hosting → Configuration**.
5. Repite los pasos del Módulo 3 (páginas y menús).

**Ruta B — VPS Linux (nginx + PHP-FPM + MariaDB):**

1. Instala WordPress según `docs/entornos.md`.
2. Copia tema y plugin vía SFTP:
   ```bash
   scp -r wordpress/resolvecore-theme usuario@vps:/var/www/resolvecore/wp-content/themes/
   scp -r wordpress/plugins/rc-mantisbt usuario@vps:/var/www/resolvecore/wp-content/plugins/
   ```
3. Edita `/var/www/resolvecore/wp-config.php` y añade las constantes del Módulo 5.
4. Activa tema y plugin desde el admin.
5. Configura SSL con `certbot --nginx`.

📸 **Captura 7.2** → `07-backup/02_produccion_home.png`

> **Criterio de hecho:** la web está accesible públicamente y el formulario crea tickets en el MantisBT de producción.

---

## Checklist final

Marca cada casilla con captura PNG asociada:

- [ ] LocalWP funcionando — `01-localwp/03_localwp_wp_admin.png`
- [ ] Tema activado — `02-tema/01_tema_activado.png`
- [ ] Home con landing oscuro — `02-tema/02_home_landing.png`
- [ ] Cuatro páginas creadas — `03-paginas/01_pagina_docs.png`
- [ ] Menús principal + footer — `03-paginas/02_menus_configurados.png`
- [ ] Plugin activo y conectado — `04-plugin/03_test_conexion_ok.png`
- [ ] Token movido a `wp-config.php` — `05-config/01_wp_config_constantes.png`
- [ ] Aviso de token duplicado mostrado — `05-config/02_aviso_token_duplicado.png`
- [ ] Ticket creado desde formulario — `06-formulario/02_ticket_creado_mantis.png`
- [ ] Rate limit 429 disparado — `06-formulario/03_rate_limit_429.png`
- [ ] Backup UpdraftPlus generado — `07-backup/01_updraft_backup_ok.png`
- [ ] Home pública accesible — `07-backup/02_produccion_home.png`

---

## Troubleshooting

| Síntoma | Causa probable | Solución |
|---------|----------------|----------|
| "Plantilla Docs no aparece" en el desplegable | Tema inactivo o cache de WordPress | Apariencia → Temas → reactivar; vaciar caches |
| Verificar conexión devuelve `403` | Token mal copiado o expirado | Regenerar token en MantisBT y volver a pegar |
| Verificar conexión devuelve `404` | URL incorrecta (falta `/api/rest/`) | El plugin añade `/api/rest/` solo; usa la URL base **sin** ese sufijo |
| Verificar conexión devuelve `cURL error 6` | DNS / VPS apagado / firewall | `ping mantis.resolvecore.com`; abrir puerto 443 |
| Formulario devuelve `400 invalid nonce` | Página cacheada con nonce viejo | Limpiar cache (WP Super Cache, LiteSpeed); recargar con Ctrl+F5 |
| Formulario devuelve `429` justo en el primer envío | Rate limit demasiado estricto | Revisar `RC_RATE_LIMIT` en `functions.php` (default: 5/hora/IP) |
| Ticket creado pero sin descripción | Caracteres no UTF-8 en el textarea | El plugin fuerza UTF-8 a partir de v1.0.0; actualizar plugin |

---

## Referencias

- Stack tecnológico justificado: [`docs/stack-tecnologico.md`](stack-tecnologico.md)
- Integración detallada con MantisBT: [`docs/mantis-integration.md`](mantis-integration.md)
- Esquema de datos del diagnóstico: [`docs/schema-diagnostico.md`](schema-diagnostico.md)
- Entornos dev / prod / backup: [`docs/entornos.md`](entornos.md)
- Defensa TFG (índice maestro): [`docs/defensa-tfg.md`](defensa-tfg.md)
