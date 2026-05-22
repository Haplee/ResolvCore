# Auditoría técnica — ResolveCore

> **Fecha:** 2026-05-22
> **Auditor:** Ingeniería senior (revisión independiente, sin concesiones)
> **Alcance:** Código fuente, configuración, estructura de repositorio, dependencias y documentación.
> **Rama analizada:** `140526`
> **Stack:** WordPress + PHP 8.2 + MySQL/MariaDB · Scripts PowerShell/Bash/Python · MantisBT

---

## Índice

1. [Resumen ejecutivo](#1-resumen-ejecutivo)
2. [Análisis general](#2-análisis-general)
   - 2.1 [Arquitectura](#21-arquitectura)
   - 2.2 [Calidad de código](#22-calidad-de-código)
   - 2.3 [Seguridad](#23-seguridad)
   - 2.4 [Rendimiento](#24-rendimiento)
   - 2.5 [Mantenibilidad](#25-mantenibilidad)
   - 2.6 [Compatibilidad y accesibilidad](#26-compatibilidad-y-accesibilidad)
3. [Catálogo de bugs](#3-catálogo-de-bugs)
   - [Críticos](#críticos)
   - [Altos](#altos)
   - [Medios](#medios)
   - [Bajos](#bajos)
4. [Plan de acción](#4-plan-de-acción)
   - 4.1 [🗑️ Para borrar](#41-️-para-borrar)
   - 4.2 [⚡ Para optimizar](#42--para-optimizar)
   - 4.3 [🚀 Para mejorar](#43--para-mejorar)
5. [Tabla resumen final](#5-tabla-resumen-final)

---

## 1. Resumen ejecutivo

ResolveCore es un proyecto **funcionalmente ambicioso y, en su núcleo de aplicación, sorprendentemente bien escrito**. El plugin `rc-mantisbt` y el archivo `functions.php` del tema demuestran madurez real: nonces, sanitización de inputs, escape de outputs, rate limiting, tokens HMAC anti-enumeración y manejo de errores con `WP_Error`. El cliente REST `RC_Mantis_API` está validado con whitelists y límites de tamaño. Esa parte es nota alta.

El problema **no está en el código de aplicación, sino en la higiene del repositorio y en la coherencia del conjunto**. El repositorio filtra secretos reales, contiene el core completo de WordPress versionado, arrastra ~17 MB de binarios y dumps, y mantiene **dos copias divergentes del código personalizado**. La capa de presentación (`front-page.php`, 2.295 líneas) es un monolito que mezcla PHP, ~1.200 líneas de CSS y ~600 de JS inline. Y la documentación describe, en partes, un producto que no existe.

**Nivel de madurez:** prototipo avanzado / beta temprana. El backend está listo para producción; el repositorio y la capa de presentación **no lo están**.

**Riesgos críticos:** exposición de credenciales en el control de versiones. Si este repositorio es o ha sido público en GitHub (`github.com/Haplee/ResolveCore`), los secretos deben considerarse **comprometidos y rotados de inmediato**.

### Los 5 hallazgos más importantes

| # | Hallazgo | Severidad | Detalle |
|---|----------|-----------|---------|
| 1 | `wp-config.php` versionado con salts de autenticación y `RC_MANTIS_TOKEN` reales | 🔴 Crítica | [BUG-001](#bug-001-wp-configphp-con-secretos-reales-en-el-control-de-versiones) |
| 2 | `.env.example` contiene una `SHODAN_API_KEY` real, no un placeholder | 🔴 Crítica | [BUG-002](#bug-002-shodan_api_key-real-en-envexample) |
| 3 | Dump completo de la base de datos (`wordpress-db.sql`, 1,5 MB) versionado | 🔴 Crítica | [BUG-004](#bug-004-dump-completo-de-base-de-datos-versionado) |
| 4 | Código personalizado duplicado y **desincronizado** entre `wordpress/` y `wp/wp-content/` | 🟠 Alta | [BUG-008](#bug-008-código-personalizado-duplicado-y-desincronizado) |
| 5 | Migración SQL usa `CREATE INDEX IF NOT EXISTS`, sintaxis **inválida en MySQL 8.0** | 🟠 Alta | [BUG-007](#bug-007-migración-sql-incompatible-con-mysql) |

---

## 2. Análisis general

### 2.1 Arquitectura

**Diseño general.** El proyecto se reparte en cuatro dominios bien diferenciados: tema WordPress, plugins de integración, scripts de diagnóstico multiplataforma y configuración de MantisBT. La separación conceptual es correcta y los scripts Python (`scripts/common/`) sí siguen una arquitectura hexagonal limpia (domain → ports → adapters).

**Problemas estructurales graves:**

- **Core de WordPress versionado.** El directorio `wp/` contiene **3.119 ficheros versionados** que son el núcleo de WordPress (`wp-includes/`, `wp-admin/`, etc.). El core nunca debe estar en el repositorio del proyecto: infla el repo, dificulta las actualizaciones de seguridad y mezcla código de terceros con el propio.

- **Doble fuente de verdad.** El código personalizado vive simultáneamente en `wordpress/` (fuente de desarrollo) y en `wp/wp-content/` (instalación local desplegada). Las dos copias **ya han divergido** — ver [BUG-008](#bug-008-código-personalizado-duplicado-y-desincronizado). No hay forma de saber, mirando el repo, cuál es la canónica.

- **`front-page.php` como monolito autónomo.** Con 2.295 líneas, este archivo **no usa `get_header()` ni `get_footer()`**: reimplementa el `<!DOCTYPE>`, el `<head>`, las metaetiquetas, el footer y el FAB por su cuenta. El resultado es que el sitio tiene **dos cabeceras y dos footers distintos** según la plantilla servida (`header.php`/`footer.php` para páginas internas, markup propio en la portada). Acoplamiento de presentación altísimo y cero reutilización.

- **Formulario de contacto implementado tres veces.** El mismo formulario AJAX existe en `front-page.php` (inline), en `page-contacto.php` (inline) y en `assets/js/main.js` (este último roto y sin cargar). Tres implementaciones del mismo flujo de negocio.

**Escalabilidad.** El backend escala razonablemente: el endpoint público de la flota cachea agregados en un transient e invalida bajo demanda — buena decisión. El cuello de botella es la presentación: cada visita reenvía ~1.200 líneas de CSS embebido sin que el navegador pueda cachearlas.

### 2.2 Calidad de código

**Lo bueno.** PHP moderno y consistente en la capa de aplicación: tipos de retorno union (`int|WP_Error`), `match`, propiedades tipadas, `strict` en los closures. Prefijo `rc_` / `resolvecore_` respetado. PHPDoc presente y útil. Los comentarios explican el *porqué*, no el *qué*.

**Lo malo:**

- **Funciones y archivos gigantes.** `front-page.php` mezcla cuatro lenguajes en un único archivo de 2.295 líneas. `resolvecore_send_client_confirmation()` (functions.php) tiene ~180 líneas, casi todas concatenación de HTML de email a mano.
- **Duplicación.** Las variables CSS `:root` (`--rc-bg`, `--rc-accent`, etc.) están copiadas literalmente en `front-page.php`, `page-contacto.php`, `page-docs.php` y otras plantillas. Cualquier cambio de marca obliga a editar N archivos.
- **Código muerto.** `assets/js/main.js` no se encola en ningún sitio y, además, está roto ([BUG-006](#bug-006-formulario-de-contacto-roto-en-mainjs)).
- **`magic numbers` y constantes muertas.** `RC_MANTIS_PROJECT_ID` se define en `wp-config.php` pero **ningún código la lee** ([BUG-015](#bug-015-constante-rc_mantis_project_id-muerta)).

### 2.3 Seguridad

**Capa de aplicación: sólida.** Es justo decirlo. Los handlers AJAX (`resolvecore_handle_contact`, `resolvecore_handle_ticket_status`) verifican nonce, aplican honeypot, rate limiting por hash de IP y validación con whitelist. El token de seguimiento de tickets es un HMAC-SHA256 con `wp_salt()` — diseño correcto contra enumeración. `RC_Mantis_API` sanitiza y valida todo el payload. `rc_fleet_check_auth` usa `hash_equals` (timing-safe). El generador de PDF usa `escapeshellarg`. Esto está bien hecho.

**Capa de repositorio: catastrófica.** El problema no es el código que se ejecuta, sino lo que se ha *commiteado*:

- `wp-config.php` con los 8 salts reales y el token `RC_MANTIS_TOKEN` en claro ([BUG-001](#bug-001-wp-configphp-con-secretos-reales-en-el-control-de-versiones)).
- `.env.example` con una `SHODAN_API_KEY` operativa ([BUG-002](#bug-002-shodan_api_key-real-en-envexample)).
- `mantisbt/config/config_inc.php` con `$g_crypto_master_salt` y contraseña de BD ([BUG-003](#bug-003-config_incphp-de-mantisbt-con-secretos)).
- `wordpress-db.sql` — dump completo, incluye hashes de contraseñas de usuarios y emails ([BUG-004](#bug-004-dump-completo-de-base-de-datos-versionado)).
- `wp/wp-content/database/.ht.sqlite` — base de datos SQLite viva ([BUG-005](#bug-005-base-de-datos-sqlite-viva-versionada)).

Ironía notable: el propio plugin `rc-mantisbt` muestra un aviso en su pantalla de ajustes recomendando *no* guardar el token en la BD "en claro"… y el token acaba en `wp-config.php`, versionado en git. La intención de seguridad es correcta; la ejecución en el repo la anula.

**Cabeceras de seguridad.** `resolvecore_security_headers()` aplica `X-Content-Type-Options`, `Referrer-Policy`, `X-Frame-Options` y `Permissions-Policy`. Falta `Content-Security-Policy` — difícil de aplicar con tanto CSS/JS inline, lo cual es otra razón para extraerlo.

### 2.4 Rendimiento

- **CSS/JS inline masivo.** `front-page.php` embebe ~1.200 líneas de CSS y ~600 de JS en cada respuesta. No se puede cachear en navegador, no se minifica, no se comparte entre páginas. Es el mayor problema de rendimiento del frontend.
- **Repositorio inflado.** `wp-content.tar.gz` (15 MB) + `wordpress-db.sql` (1,5 MB) + core completo de WordPress = clonados lentos y un historial git pesado para siempre.
- **Base de datos de la flota sin poda.** `rc_fleet_hosts.last_json` es `LONGTEXT` y guarda el JSON de diagnóstico íntegro por host, sin política de retención. Crece de forma indefinida.
- **Bien resuelto:** el endpoint `/fleet/stats` cachea con transient (5 min) e invalida en cada POST de agente; los emojis, `wp-block-library` y oEmbed se desencolan; hay `preconnect` a Google Fonts y `defer` en scripts no críticos. La intención de rendimiento existe — solo no llega a la portada.

### 2.5 Mantenibilidad

- **Deuda técnica declarada:** el propio `generate-report.php` documenta que `wkhtmltopdf` está archivado desde 2023 y propone migrar a DomPDF. Es deuda *consciente*, lo cual es mejor que deuda oculta, pero sigue siendo deuda.
- **Sin tests ni CI.** No hay un solo test (PHPUnit, Pest, Bats, pytest) ni workflow de integración continua. Para un proyecto con lógica de seguridad (tokens, nonces, rate limiting) esto es un riesgo: cualquier refactor puede romper la validación sin que nadie lo note.
- **Documentación contradictoria.** Versiones y licencia no concuerdan entre archivos ([BUG-012](#bug-012-licencia-inconsistente), [BUG-021](#bug-021-versionado-incoherente-entre-componentes)). `page-docs.php` documenta comandos (`resolvecore --scan`, `resolvecore-gui`) y un esquema JSON que **no existen** en el código ([BUG-013](#bug-013-page-docsphp-documenta-un-producto-ficticio)).
- **Dumps redundantes.** `docs_dump.txt` (246 KB) y `ResolvCore_Documentacion_Unificada.md` (169 KB) duplican el contenido ya estructurado de `docs/`.

### 2.6 Compatibilidad y accesibilidad

- **PHP.** Se usan `match`, tipos union de retorno y `str_contains` → requieren PHP 8.0+. README y CLAUDE.md declaran PHP 8.2+. Coherente.
- **MySQL/MariaDB.** La migración `0001_init.sql` **rompe la compatibilidad declarada** ([BUG-007](#bug-007-migración-sql-incompatible-con-mysql)).
- **Accesibilidad — bien:** skip-link, `:focus-visible`, `prefers-reduced-motion`, roles ARIA en el modal y el menú desplegable, `aria-expanded` gestionado.
- **Accesibilidad — a mejorar:** el modal de seguimiento de tickets (`#rc-ticket-modal`) no atrapa el foco (focus trap) mientras está abierto; con teclado se puede tabular fuera del diálogo ([BUG-022](#bug-022-modal-sin-focus-trap)).
- **Navegadores.** Uso de `IntersectionObserver`, `fetch`, `async/await`, `URLSearchParams`, optional chaining — todo soportado en navegadores modernos (2021+). Sin polyfills; aceptable para el público objetivo.

---

## 3. Catálogo de bugs

> 22 hallazgos, ordenados por severidad descendente.

### Críticos

#### BUG-001: `wp-config.php` con secretos reales en el control de versiones
- **Severidad:** Crítica
- **Tipo:** Seguridad
- **Archivo y línea:** `wp-config.php:52-60`, `wp-config.php:96`
- **Descripción:** El archivo está versionado (`git ls-files` lo confirma) e incluye los 8 salts de autenticación de WordPress (`AUTH_KEY`, `SECURE_AUTH_KEY`, …) con valores reales y la constante `RC_MANTIS_TOKEN` con un token de API de MantisBT operativo (`TM4mZDbt58rlpXG0yreC4Vg7vWEMXTWF`). Las credenciales de BD (`root`/`root`) también están expuestas.
- **Reproducción:** `git log --oneline -- wp-config.php` → commit `a7a5dbf`. El archivo y sus secretos están en el historial.
- **Impacto:** Quien acceda al repositorio obtiene el token de API de MantisBT (creación/lectura de tickets) y los salts (permiten falsificar cookies de sesión y nonces si además se conoce el dominio). Si el repo es o fue público, comprometido de forma permanente: el historial git conserva los valores aunque se borren después.
- **Solución propuesta:**
  1. **Rotar ya** todos los salts (regenerar en `https://api.wordpress.org/secret-key/1.1/salt/`) y el token de MantisBT (Mi cuenta → API Tokens → revocar y recrear).
  2. Eliminar `wp-config.php` del seguimiento: `git rm --cached wp-config.php` y añadirlo a `.gitignore`.
  3. Versionar solo un `wp-config-sample.php` con placeholders.
  4. Purgar el historial (`git filter-repo --invert-paths --path wp-config.php`) si el repo fue público.
- **Esfuerzo estimado:** S (el arreglo) — la rotación de secretos es la parte ineludible.

#### BUG-002: `SHODAN_API_KEY` real en `.env.example`
- **Severidad:** Crítica
- **Tipo:** Seguridad
- **Archivo y línea:** `.env.example:8`
- **Descripción:** Un archivo `.env.example` debe contener **solo placeholders**. Aquí la línea `SHODAN_API_KEY=BgdwtmGnPtp7r19OvU4HumMgAout6zTd` contiene una clave de API de Shodan funcional. El `.gitignore` ignora `.env` pero **no** `.env.example`, así que la clave está versionada.
- **Reproducción:** Abrir `.env.example`; la clave es un valor real, no `your_key_here`.
- **Impacto:** Cualquiera puede consumir los créditos de Shodan de la cuenta del autor (free tier: 100/mes) y usar la clave para reconocimiento de red atribuible a esa cuenta.
- **Solución propuesta:** Revocar la clave en `account.shodan.io`, generar una nueva y dejar la línea como `SHODAN_API_KEY=` (vacía) en `.env.example`. La clave real solo en `.env` (ya ignorado).
- **Esfuerzo estimado:** XS

#### BUG-003: `config_inc.php` de MantisBT con secretos
- **Severidad:** Crítica
- **Tipo:** Seguridad
- **Archivo y línea:** `mantisbt/config/config_inc.php:6`, `mantisbt/config/config_inc.php:10`
- **Descripción:** El archivo está versionado con `$g_db_password = 'mantis'` y, sobre todo, `$g_crypto_master_salt = 'VYN83XZpOaNhKQ9C3G0J+jePI75myahTH4KW8R8rfao='`. El `crypto_master_salt` de MantisBT firma tokens de sesión y de API; si se filtra, se pueden forjar. Existe ya un `config_inc.php.template` versionado correctamente — el archivo real no debería estar.
- **Reproducción:** `git ls-files | grep config_inc` → aparecen ambos: el real y el `.template`.
- **Impacto:** Compromiso del crypto salt de MantisBT → posible falsificación de tokens. Contraseña de BD expuesta.
- **Solución propuesta:** `git rm --cached mantisbt/config/config_inc.php`, añadir el patrón a `.gitignore`, regenerar el `crypto_master_salt`. Versionar únicamente el `.template`.
- **Esfuerzo estimado:** XS

#### BUG-004: Dump completo de base de datos versionado
- **Severidad:** Crítica
- **Tipo:** Seguridad
- **Archivo y línea:** `wordpress-db.sql` (1,5 MB), `mantisbt/sql/mantisbt-db.sql`
- **Descripción:** `wordpress-db.sql` es un volcado completo de la base de datos de WordPress. Un dump de WP contiene la tabla `wp_users` (hashes de contraseñas), `wp_usermeta`, emails, y normalmente claves de API guardadas en `wp_options` — incluido, potencialmente, el `rc_mantis_token` si alguna vez se guardó por el formulario en lugar de la constante.
- **Reproducción:** Inspeccionar `wordpress-db.sql`; buscar `INSERT INTO \`wp_users\`` y `wp_options`.
- **Impacto:** Exposición de hashes de contraseñas (crackeables offline), datos personales de usuarios (RGPD) y posibles secretos de `wp_options`.
- **Solución propuesta:** Eliminar del repo y del historial. Los dumps de BD se guardan en almacenamiento de backups, nunca en git. Si hace falta un esquema de referencia, versionar solo el `CREATE TABLE` sin datos.
- **Esfuerzo estimado:** S

#### BUG-005: Base de datos SQLite viva versionada
- **Severidad:** Crítica
- **Tipo:** Seguridad
- **Archivo y línea:** `wp/wp-content/database/.ht.sqlite`
- **Descripción:** El plugin `sqlite-database-integration` persiste toda la instalación local de WordPress en este fichero SQLite, que está versionado. Equivale al dump de BD del [BUG-004](#bug-004-dump-completo-de-base-de-datos-versionado): contiene usuarios, hashes y opciones.
- **Reproducción:** `git ls-files | grep ht.sqlite`.
- **Impacto:** Idéntico al BUG-004 — exposición de credenciales y datos personales.
- **Solución propuesta:** Eliminar del seguimiento y del historial; ignorar `*.sqlite` y el directorio `wp/`. Ver también [BUG-008](#bug-008-código-personalizado-duplicado-y-desincronizado) sobre por qué `wp/` no debe estar en el repo.
- **Esfuerzo estimado:** S

### Altos

#### BUG-006: Formulario de contacto roto en `main.js`
- **Severidad:** Alta
- **Tipo:** Funcional
- **Archivo y línea:** `wordpress/resolvecore-theme/assets/js/main.js:16-17`
- **Descripción:** `main.js` implementa un tercer handler del formulario de contacto con **tres errores simultáneos**:
  1. `data.append('action', 'rc_contact_submit')` — no existe ningún handler `wp_ajax_rc_contact_submit`. El registrado es `resolvecore_contact` (`functions.php:228`).
  2. `data.append('_rc_nonce', rcAjax.nonce)` — el handler hace `check_ajax_referer('resolvecore_contact', 'nonce')`, es decir, espera el nonce en el campo `nonce`, no `_rc_nonce`.
  3. `rcAjax` es un objeto global que nunca se define: `functions.php` no llama a `wp_localize_script` ni siquiera encola `main.js`.
- **Reproducción:** Si se encolara `main.js`, el envío respondería siempre `0`/`-1` de `admin-ajax.php`. Hoy el archivo simplemente no se carga, así que es **código muerto roto**.
- **Impacto:** Riesgo de regresión: si alguien encola `main.js` "para que el JS del tema funcione", rompe el formulario. Confunde sobre cuál es la implementación real (que está inline en `front-page.php` y `page-contacto.php`, y sí funciona).
- **Solución propuesta:** Eliminar `main.js`. La lógica del formulario ya vive (correcta) inline en las plantillas. Si se quiere un único origen, extraer **una** implementación a un `.js` encolado con `wp_localize_script` y borrar las inline — ver [sección 4.3](#43--para-mejorar).
- **Esfuerzo estimado:** XS (borrar) / M (unificar)

#### BUG-007: Migración SQL incompatible con MySQL
- **Severidad:** Alta
- **Tipo:** Funcional
- **Archivo y línea:** `vulnerabilities/migrations/0001_init.sql:37-41`
- **Descripción:** Las cinco sentencias `CREATE INDEX IF NOT EXISTS idx_… ON rc_vulnerabilities (…)` usan la cláusula `IF NOT EXISTS`, que **MySQL 8.0 no soporta** en `CREATE INDEX` (es exclusiva de MariaDB ≥ 10.5). La cabecera del archivo afirma "Compatible con MariaDB 10.4+ y MySQL 8.0+" — falso en ambos extremos: falla entera en MySQL 8.0 y en MariaDB requiere 10.5, no 10.4.
- **Reproducción:** Ejecutar la migración en MySQL 8.0 → error de sintaxis en la línea 37; la migración aborta dejando las tablas a medias. Re-ejecutarla en MariaDB 10.4 → mismo error.
- **Impacto:** La afirmación de idempotencia es falsa. En el stack MySQL la base de vulnerabilidades no se crea correctamente; en MariaDB 10.4 tampoco.
- **Solución propuesta:** Declarar los índices **dentro del `CREATE TABLE`** (que ya es `IF NOT EXISTS`), eliminando los `CREATE INDEX` sueltos:
  ```sql
  CREATE TABLE IF NOT EXISTS rc_vulnerabilities (
      ...
      PRIMARY KEY (id),
      UNIQUE KEY uk_cve_id (cve_id),
      KEY idx_rc_vuln_so       (so_afectado),
      KEY idx_rc_vuln_gravedad (gravedad),
      KEY idx_rc_vuln_kev      (kev_listed),
      KEY idx_rc_vuln_sync     (fecha_sync),
      KEY idx_rc_vuln_producto (producto)
  ) ENGINE=InnoDB ...;
  ```
  Así la idempotencia la garantiza el único `IF NOT EXISTS` de la tabla y funciona en MySQL 8.0 y MariaDB 10.4+.
- **Esfuerzo estimado:** S

#### BUG-008: Código personalizado duplicado y desincronizado
- **Severidad:** Alta
- **Tipo:** Lógica / Mantenibilidad
- **Archivo y línea:** `wordpress/resolvecore-theme/` vs `wp/wp-content/themes/resolvecore-theme/`; `wordpress/plugins/` vs `wp/wp-content/plugins/`
- **Descripción:** El tema y el plugin `rc-mantisbt` existen en dos rutas a la vez. Las copias **ya divergen**:
  - `functions.php` — la copia de `wp/` está en versión de estilo `3.1.2` y **le falta todo el bloque de relay de correo** (`resolvecore_mail_from`, la versión multipart/alternative del email de confirmación). La copia de `wordpress/` es la `3.1.3`, más reciente.
  - El plugin `rc-fleet` **solo existe en `wordpress/plugins/`**; no está desplegado en `wp/wp-content/plugins/`. La instalación local de WordPress no tiene el módulo Fleet.
- **Reproducción:** `diff wordpress/resolvecore-theme/functions.php wp/wp-content/themes/resolvecore-theme/functions.php` → 40+ líneas de diferencia.
- **Impacto:** Si la instalación que se sirve es la de `wp/`, está corriendo **código obsoleto** (sin el remitente de correo unificado que un commit reciente introdujo explícitamente para mejorar la entregabilidad). Nadie puede determinar la fuente canónica desde el repo. Cualquier corrección hay que hacerla dos veces o se vuelve a desincronizar.
- **Solución propuesta:** Decidir una única fuente de verdad (`wordpress/`). Sacar el core de WordPress del repo (ver [sección 4.1](#41-️-para-borrar)) y, para el entorno local, enlazar/desplegar el tema y plugins desde `wordpress/` mediante el script de despliegue o un symlink, no mediante una copia versionada.
- **Esfuerzo estimado:** M

#### BUG-009: `rc-fleet` no verifica el resultado de las escrituras en BD
- **Severidad:** Alta
- **Tipo:** Lógica
- **Archivo y línea:** `wordpress/plugins/rc-fleet/rc-fleet.php:188-196`
- **Descripción:** `rc_fleet_rest_post()` llama a `$wpdb->update()` / `$wpdb->insert()` pero **no comprueba el valor de retorno**. Si la escritura falla (tabla ausente, columna incompatible, conexión caída), el endpoint responde igualmente `{ "ok": true, "action": "created", … }` con `id` posiblemente `0`.
- **Reproducción:** Provocar un fallo de inserción (p. ej., desactivar el plugin sin que la tabla exista y forzar un POST). La respuesta sigue siendo `ok:true`.
- **Impacto:** Un agente de la flota cree que su diagnóstico se ha publicado cuando no es así. Pérdida silenciosa de datos de monitorización; depuración muy difícil.
- **Solución propuesta:** Comprobar el retorno y devolver `WP_Error` con `status 500` si es `false`:
  ```php
  $res = $existing
      ? $wpdb->update( $table, $data, [ 'id' => (int) $existing ] )
      : $wpdb->insert( $table, $data );
  if ( $res === false ) {
      return new WP_Error( 'rc_fleet_db_error', 'No se pudo persistir el host', [ 'status' => 500 ] );
  }
  ```
- **Esfuerzo estimado:** S

### Medios

#### BUG-010: Doble etiqueta `<title>` en la portada
- **Severidad:** Media
- **Tipo:** Funcional / SEO
- **Archivo y línea:** `wordpress/resolvecore-theme/front-page.php:7` + `functions.php:17`
- **Descripción:** `functions.php` declara `add_theme_support('title-tag')`, lo que hace que `wp_head()` inyecte automáticamente una etiqueta `<title>`. Pero `front-page.php:7` ya tiene un `<title>` hardcodeado **y además** llama a `wp_head()` en la línea 52. La portada renderiza, por tanto, **dos `<title>`**.
- **Reproducción:** Cargar la portada → "Ver código fuente" → aparecen dos `<title>`.
- **Impacto:** HTML inválido; los crawlers de SEO y las previsualizaciones sociales pueden tomar el equivocado. Comportamiento indefinido.
- **Solución propuesta:** Eliminar el `<title>` hardcodeado de `front-page.php` y dejar que `title-tag` lo gestione (configurando el título vía `pre_get_document_title` si se quiere uno fijo), o bien `remove_theme_support('title-tag')`. Recomendado lo primero.
- **Esfuerzo estimado:** XS

#### BUG-011: `generate-report.php` habilita acceso a ficheros locales en wkhtmltopdf
- **Severidad:** Media
- **Tipo:** Seguridad
- **Archivo y línea:** `reports/generate-report.php:105`
- **Descripción:** El comando pasa `--enable-local-file-access` a `wkhtmltopdf`. La plantilla `informe.html` se rellena con el JSON de diagnóstico (`__JSON_DATA__`) y se renderiza con esa opción activa. Si el JSON o la plantilla cargan recursos `file://` o un `<script>` malicioso, wkhtmltopdf puede leer ficheros arbitrarios del sistema e incrustarlos en el PDF (exfiltración LFI).
- **Reproducción:** Construir un JSON de diagnóstico con un payload que la plantilla renderice como `<img src="file:///etc/passwd">`; el contenido acabaría en el PDF.
- **Impacto:** Limitado hoy porque el JSON lo genera el propio técnico en su máquina (no es input de un atacante remoto). Sube de severidad si en el futuro se generan informes a partir de JSON subidos por agentes/clientes.
- **Solución propuesta:** Si la plantilla no necesita cargar recursos locales (CSS/imágenes embebidas en el HTML), **quitar `--enable-local-file-access`**. Si los necesita, restringir con `--allow <dir>` solo al directorio de assets del informe. Acelera además la migración a DomPDF, que no expone esta superficie.
- **Esfuerzo estimado:** S

#### BUG-012: Licencia inconsistente
- **Severidad:** Media
- **Tipo:** Lógica / Legal
- **Archivo y línea:** `wordpress/plugins/rc-mantisbt/rc-mantisbt.php:9` (`GPL-2.0+`), `front-page.php:1376` (`GPL-3.0-or-later`), `page-docs.php:210` (`licencia MIT`), `README.md` (badge `GPL-3.0`)
- **Descripción:** El proyecto se declara bajo cuatro licencias distintas según el archivo: GPL-2.0+, GPL-3.0-or-later, MIT y "GPL-3.0". GPL-2.0 y GPL-3.0 son incompatibles entre sí en un sentido; MIT es permisiva y contradice ambas.
- **Reproducción:** Comparar las cuatro referencias.
- **Impacto:** Ambigüedad legal real. Un tercero no sabe bajo qué términos puede usar el código. Para un TFG, además, es un fallo de rigor que un tribunal puede señalar.
- **Solución propuesta:** Elegir **una** licencia, añadir un `LICENSE` en la raíz y unificar todas las cabeceras y la documentación. WordPress empuja a GPL — `GPL-3.0-or-later` es coherente con el ecosistema.
- **Esfuerzo estimado:** S

#### BUG-013: `page-docs.php` documenta un producto ficticio
- **Severidad:** Media
- **Tipo:** Funcional (documentación) / UX
- **Archivo y línea:** `wordpress/resolvecore-theme/page-docs.php:101-178`
- **Descripción:** La página de documentación pública describe cosas que **no existen** en el código:
  - Comandos `resolvecore --scan --full`, `resolvecore --vuln-scan`, `resolvecore-gui` — no hay ningún binario `resolvecore` en `scripts/`.
  - Un esquema JSON con claves `timestamp`, `platform`, `system`, `cpu`, `ram` (línea 164). El esquema **real**, validado por `rc_mantis_attach_diagnostic()` y `rc_fleet_rest_post()`, usa `_meta.plataforma`, `_meta.version`, `_meta.hostname`, `sistema`, `memoria`, `discos`… No coincide ni una clave.
  - El ejemplo PowerShell (`page-docs.php:185-188`) es además incorrecto — ver [BUG-020](#bug-020-ejemplo-powershell-roto-en-la-documentación).
- **Reproducción:** Comparar `page-docs.php` con `scripts/diagnosticos/diagnostico_*.json` real y con `docs/scripting/schema-diagnostico.md`.
- **Impacto:** La documentación de cara al cliente induce a error. Un usuario que copie esos comandos no obtiene nada. CLAUDE.md ordena explícitamente mantener `docs/scripting/schema-diagnostico.md` sincronizado con la salida real; esta página lo contradice.
- **Solución propuesta:** Reescribir la sección "Uso" y "Salida JSON" de `page-docs.php` con los comandos reales (`pwsh ./scripts/windows/diagnostico.ps1`, etc.) y el esquema `_meta`-based real. Marcar `resolvecore-gui` como "futuro" si forma parte del roadmap.
- **Esfuerzo estimado:** M

#### BUG-014: `front-page.php` duplica el armazón del documento
- **Severidad:** Media
- **Tipo:** Lógica / Mantenibilidad
- **Archivo y línea:** `wordpress/resolvecore-theme/front-page.php:1-52`, `:1326-1380`
- **Descripción:** La portada no usa `get_header()`/`get_footer()`: reimplementa `<!DOCTYPE>`, `<head>`, metaetiquetas y un footer propio (`rc-footer-pro`). El sitio acaba con dos footers distintos: `rc-footer` (de `footer.php`, copyright **hardcodeado** `© 2026`) en páginas internas y `rc-footer-pro` (con `date_i18n('Y')`, dinámico) en la portada. La cabecera/nav de `header.php` tampoco se reutiliza en la portada.
- **Reproducción:** Comparar el footer de `/` con el de `/docs/`: estructura, enlaces y año difieren.
- **Impacto:** Mantenimiento por duplicado, divergencia garantizada (de hecho, el copyright ya divergió), y a partir de 2027 el footer de las páginas internas mostrará un año incorrecto.
- **Solución propuesta:** Hacer que `front-page.php` use `get_header()`/`get_footer()` y mover su `<head>`/footer propios a esos parciales (o a `header-front.php`/`footer-front.php` si de verdad necesita variantes). Como mínimo inmediato, cambiar `footer.php:3` de `© 2026` a `© <?php echo esc_html( date_i18n('Y') ); ?>`.
- **Esfuerzo estimado:** L (unificación completa) / XS (parche del año)

#### BUG-015: Constante `RC_MANTIS_PROJECT_ID` muerta
- **Severidad:** Media
- **Tipo:** Lógica
- **Archivo y línea:** `wp-config.php:97`
- **Descripción:** `wp-config.php` define `RC_MANTIS_PROJECT_ID`, pero el plugin `rc-mantisbt` **nunca lee esa constante**: `rc_mantis_create_ticket()` toma el ID de proyecto siempre de `get_option('rc_mantis_project_id', 1)` (`rc-mantisbt.php:229`). A diferencia de `RC_MANTIS_URL` y `RC_MANTIS_TOKEN`, que sí tienen su helper con prioridad constante > opción, el `project_id` no.
- **Reproducción:** `grep -rn RC_MANTIS_PROJECT_ID wordpress/` → solo aparece en `wp-config.php`, en ningún `.php` del plugin.
- **Impacto:** Configuración engañosa. Cambiar la constante no tiene ningún efecto; el técnico cree haber configurado el proyecto y los tickets siguen yendo al ID por defecto de la opción.
- **Solución propuesta:** O bien añadir un helper `rc_mantis_get_project_id()` simétrico a los otros (constante > opción) y usarlo en `create_issue`, o bien eliminar la constante de `wp-config.php`. Recomendado lo primero, por coherencia.
- **Esfuerzo estimado:** S

#### BUG-016: El rate limiting consume cuota antes de validar el formulario
- **Severidad:** Media
- **Tipo:** UX / Lógica
- **Archivo y línea:** `wordpress/resolvecore-theme/functions.php:142-166`
- **Descripción:** En `resolvecore_handle_contact()`, el contador de intentos (`set_transient`, máx. 3/hora) se incrementa en la línea 148, **antes** de validar nombre/email/mensaje (líneas 161-166). Un usuario que envíe el formulario con un email mal escrito gasta un intento; tres typos y queda bloqueado una hora sin haber enviado nada válido.
- **Reproducción:** Enviar el formulario 3 veces con un campo vacío → al 4º intento, ya con datos correctos, responde "Demasiados intentos".
- **Impacto:** Fricción para usuarios legítimos. El rate limiting debería penalizar envíos *procesados*, no errores de validación del lado cliente.
- **Solución propuesta:** Mover el `set_transient` del contador a **después** de pasar la validación de campos (tras la línea 166), o incrementarlo solo cuando se intenta crear el ticket/enviar el correo. La comprobación `if ($attempts >= 3)` puede quedarse al principio.
- **Esfuerzo estimado:** XS

### Bajos

#### BUG-017: La respuesta AJAX filtra detalles de error internos
- **Severidad:** Baja
- **Tipo:** Seguridad (divulgación de información)
- **Archivo y línea:** `wordpress/resolvecore-theme/functions.php:212-215`
- **Descripción:** Cuando fallan tanto MantisBT como el email, la respuesta JSON incluye `'debug' => $ticket_err`, que es el mensaje de error crudo devuelto por la API de MantisBT. Puede revelar la URL interna, versiones o detalles de configuración del backend.
- **Reproducción:** Forzar el fallo de ambos canales e inspeccionar la respuesta JSON en el navegador.
- **Impacto:** Divulgación menor de información de infraestructura a un usuario anónimo.
- **Solución propuesta:** Registrar el detalle con `error_log()` (ya se hace en la línea 180) y no incluir `debug` en la respuesta al cliente, o sustituirlo por un código de error genérico.
- **Esfuerzo estimado:** XS

#### BUG-018: `register_rest_route` invocado dos veces para la misma ruta
- **Severidad:** Baja
- **Tipo:** Lógica
- **Archivo y línea:** `wordpress/plugins/rc-fleet/rc-fleet.php:122-131`
- **Descripción:** La ruta `rc/v1/fleet` se registra en dos llamadas separadas (una para POST, otra para GET) en lugar de una sola con un array de endpoints. Funciona porque WordPress hace `array_merge` de las definiciones cuando `$override` es `false`, pero es frágil y no idiomático.
- **Reproducción:** Lectura del código.
- **Impacto:** Ninguno funcional hoy. Riesgo de confusión y de que un futuro `$override` accidental elimine un método.
- **Solución propuesta:** Registrar ambos métodos en una única llamada:
  ```php
  register_rest_route( 'rc/v1', '/fleet', [
      [ 'methods' => 'POST', 'callback' => 'rc_fleet_rest_post', 'permission_callback' => 'rc_fleet_check_auth' ],
      [ 'methods' => 'GET',  'callback' => 'rc_fleet_rest_list', 'permission_callback' => 'rc_fleet_check_auth' ],
  ] );
  ```
- **Esfuerzo estimado:** XS

#### BUG-019: Valor `$color` sin escapar en la tabla de administración de la flota
- **Severidad:** Baja
- **Tipo:** Seguridad (consistencia)
- **Archivo y línea:** `wordpress/plugins/rc-fleet/rc-fleet.php:499`
- **Descripción:** `background:<?php echo $color; ?>` imprime `$color` sin `esc_attr()`. No es explotable — `$color` es un literal hexadecimal de un ternario, sin input de usuario — pero rompe la consistencia con el resto del archivo, que sí escapa (`esc_attr`, `esc_html`) sistemáticamente.
- **Reproducción:** Lectura del código.
- **Impacto:** Nulo hoy; mala práctica que puede copiarse a un contexto donde sí haya input variable.
- **Solución propuesta:** Envolver en `esc_attr( $color )`, como ya se hace en `rc_fleet_render_stats()`.
- **Esfuerzo estimado:** XS

#### BUG-020: Ejemplo PowerShell roto en la documentación
- **Severidad:** Baja
- **Tipo:** Funcional (documentación)
- **Archivo y línea:** `wordpress/resolvecore-theme/page-docs.php:185-189`
- **Descripción:** El snippet `Get-Content .\scripts\diagnosticos\*.json | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content | ConvertFrom-Json` es incorrecto: `Get-Content` emite *líneas de texto*, no objetos de fichero, así que `Sort-Object LastWriteTime` no ordena nada y el segundo `Get-Content` se aplica sobre una cadena. Lo correcto sería `Get-ChildItem … | Sort-Object LastWriteTime`.
- **Reproducción:** Ejecutar el snippet en PowerShell → no devuelve el último diagnóstico.
- **Impacto:** Un usuario que copie el ejemplo obtiene un error o resultados vacíos.
- **Solución propuesta:** `Get-ChildItem .\scripts\diagnosticos\*.json | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Raw | ConvertFrom-Json`.
- **Esfuerzo estimado:** XS

#### BUG-021: Versionado incoherente entre componentes
- **Severidad:** Baja
- **Tipo:** Mantenibilidad
- **Archivo y línea:** `README.md` (badge `1.2.0`), `page-docs.php:26` (`v1.0.0`), `style.css:7` (`3.1.3`), `rc-mantisbt.php:6` (`1.0.0`), `rc-fleet.php:6` (`0.2.2`), `front-page.php` JSON-LD / curl de ejemplo (`4.0.0`)
- **Descripción:** No hay un esquema de versionado unificado. Cada artefacto declara una versión distinta y el número global del proyecto aparece como 1.0.0, 1.2.0, 3.1.3 y 4.0.0 según dónde se mire.
- **Impacto:** Imposible saber "qué versión es ResolveCore". Confunde en soporte y en la defensa del TFG.
- **Solución propuesta:** Definir una versión global del proyecto (en README y un `VERSION` o `composer.json`) y permitir que tema y plugins lleven la suya propia *documentando esa distinción*. Como mínimo, alinear README ↔ `page-docs.php`.
- **Esfuerzo estimado:** S

#### BUG-022: Modal de seguimiento sin focus trap
- **Severidad:** Baja
- **Tipo:** UX (accesibilidad)
- **Archivo y línea:** `wordpress/resolvecore-theme/front-page.php:2108-2135`
- **Descripción:** El modal `#rc-ticket-modal` se abre con `role="dialog"` y `aria-modal="true"` y gestiona el cierre con `Escape` — bien. Pero no atrapa el foco: con `Tab` el usuario de teclado puede salir del diálogo hacia el contenido de fondo, que sigue siendo interactivo.
- **Reproducción:** Abrir el modal y pulsar `Tab` repetidamente → el foco escapa al `<body>`.
- **Impacto:** Barrera de accesibilidad para usuarios de teclado/lectores de pantalla. WCAG 2.1 (2.4.3 Focus Order, 2.1.2 No Keyboard Trap inverso).
- **Solución propuesta:** Al abrir, mover el foco al primer elemento focusable del modal y ciclar `Tab`/`Shift+Tab` dentro de él; al cerrar, devolver el foco al elemento que lo abrió.
- **Esfuerzo estimado:** S

---

## 4. Plan de acción

### 4.1 🗑️ Para borrar

| Elemento | Justificación | Prioridad | Esfuerzo |
|----------|---------------|-----------|----------|
| `wp/` (core de WordPress, 3.119 ficheros) | El core nunca se versiona en el repo del proyecto. Infla el repo, bloquea actualizaciones de seguridad y mezcla código de terceros. WordPress se instala con `wp-cli`/Composer. | Alta | M |
| `wp-content.tar.gz` (15 MB) | Binario opaco que nadie revisa en code review. Los backups van a almacenamiento de backups, no a git. | Alta | XS |
| `wordpress-db.sql` (1,5 MB) | Dump de BD con datos personales y hashes ([BUG-004](#bug-004-dump-completo-de-base-de-datos-versionado)). Fuera del repo y del historial. | Crítica | S |
| `mantisbt/sql/mantisbt-db.sql` | Mismo motivo si contiene datos; si es solo esquema, conservar solo los `CREATE TABLE`. | Alta | S |
| `wp/wp-content/database/.ht.sqlite` | Base de datos viva versionada ([BUG-005](#bug-005-base-de-datos-sqlite-viva-versionada)). | Crítica | S |
| `wp-config.php` (del seguimiento git) | Secretos reales ([BUG-001](#bug-001-wp-configphp-con-secretos-reales-en-el-control-de-versiones)). Conservar solo `wp-config-sample.php` con placeholders. | Crítica | S |
| `mantisbt/config/config_inc.php` (del seguimiento) | Secretos reales ([BUG-003](#bug-003-config_incphp-de-mantisbt-con-secretos)). Conservar solo el `.template`. | Crítica | XS |
| `assets/js/main.js` | Código muerto y roto ([BUG-006](#bug-006-formulario-de-contacto-roto-en-mainjs)). | Media | XS |
| `php.ini` (70 KB, en la raíz) | Configuración de servidor que no pertenece al repo de aplicación. Documentar los valores relevantes en `docs/` si hace falta. | Media | XS |
| `docs_dump.txt` (246 KB) | Volcado plano que duplica el contenido ya estructurado de `docs/`. | Media | XS |
| `ResolvCore_Documentacion_Unificada.md` (169 KB) | Documento generado que duplica `docs/`. Si se necesita un PDF/MD unificado, generarlo en build, no versionarlo. | Media | XS |
| `builds/*.zip` (2,3 MB) | El propio `.gitignore` dice "distribuir vía GitHub Releases" e ignora `wordpress/*.zip`; los zips de `builds/` contradicen esa política. | Media | XS |
| `RC_MANTIS_PROJECT_ID` en `wp-config.php` | Constante muerta ([BUG-015](#bug-015-constante-rc_mantis_project_id-muerta)) — o se cablea en el plugin, o se borra. | Media | S |

> **Nota sobre el historial:** borrar estos ficheros en un commit nuevo **no los elimina del historial git**. Para los que contienen secretos (BUG-001 a BUG-005) hay que reescribir el historial con `git filter-repo` **y rotar los secretos igualmente** — asumir que ya están comprometidos.

### 4.2 ⚡ Para optimizar

**1. Extraer el CSS inline de la portada a una hoja encolada** · Prioridad Alta · Esfuerzo M

- *Estado actual:* `front-page.php` embebe ~1.200 líneas de CSS en `<style>`, reenviadas en cada visita, sin minificar ni cachear.
  ```php
  // front-page.php
  <?php wp_head(); ?>
  <style> /* ~1.200 líneas */ </style>
  ```
- *Estado propuesto:* mover a `assets/css/front-page.css` y encolar con versión para cache-busting.
  ```php
  // functions.php
  if ( is_front_page() ) {
      wp_enqueue_style( 'rc-front', get_template_directory_uri() . '/assets/css/front-page.css', [], '3.1.3' );
  }
  ```
  El navegador cachea el `.css`; las visitas siguientes no lo redescargan.

**2. Extraer el JS inline de la portada** · Prioridad Alta · Esfuerzo M

- *Estado actual:* ~600 líneas de JS inline (animaciones, formulario, modal de tickets) más `admin_url()` interpolado con PHP.
- *Estado propuesto:* `assets/js/front-page.js` encolado con `defer`, y los datos PHP (URL de ajax, nonce) pasados con `wp_localize_script` — el mismo patrón que `main.js` *intentaba* hacer pero mal:
  ```php
  wp_enqueue_script( 'rc-front', get_template_directory_uri() . '/assets/js/front-page.js', [], '3.1.3', true );
  wp_localize_script( 'rc-front', 'rcAjax', [
      'url'   => admin_url( 'admin-ajax.php' ),
      'nonce' => wp_create_nonce( 'resolvecore_contact' ),
  ] );
  ```

**3. Unificar las variables `:root` de CSS** · Prioridad Media · Esfuerzo S

- *Estado actual:* el mismo bloque `:root { --rc-bg … }` está copiado en `front-page.php`, `page-contacto.php`, `page-docs.php`, etc.
- *Estado propuesto:* un único `assets/css/tokens.css` (o el propio `style.css`) encolado en todas las páginas; las plantillas solo añaden su CSS específico.

**4. Política de retención para `rc_fleet_hosts.last_json`** · Prioridad Media · Esfuerzo S

- *Estado actual:* se guarda el JSON de diagnóstico completo por host en `LONGTEXT`, sin poda. Crecimiento ilimitado.
- *Estado propuesto:* o bien guardar solo los campos que el panel necesita (score, métricas agregadas) y descartar el JSON bruto, o añadir un cron `wp_schedule_event` que purgue/trunque registros con `last_seen` antiguo.

**5. Migrar de wkhtmltopdf a DomPDF** · Prioridad Media · Esfuerzo M

- *Estado actual:* dependencia de un binario externo archivado desde 2023 ([documentado en el propio `generate-report.php`](#) y sin parches de seguridad), más `--enable-local-file-access` ([BUG-011](#bug-011-generate-reportphp-habilita-acceso-a-ficheros-locales-en-wkhtmltopdf)).
- *Estado propuesto:* `composer require dompdf/dompdf`; DomPDF es PHP puro, sin binario ni PATH ni esa superficie LFI. El único punto de cambio es el bloque "Generar PDF" del script.

### 4.3 🚀 Para mejorar

| Mejora | Descripción | Prioridad | Esfuerzo |
|--------|-------------|-----------|----------|
| **Higiene de secretos** | `.gitignore` para `wp-config.php`, `config_inc.php`, `*.sqlite`, `*.sql`, `wp/`. Versionar solo `*-sample`/`*.template`. Rotar todos los secretos expuestos. Idealmente, gestor de secretos o variables de entorno del servidor. | Crítica | M |
| **Sacar el core de WordPress del repo** | Versionar solo `wp-content/themes/resolvecore-theme`, `wp-content/plugins/rc-*` y la config. Resuelve [BUG-008](#bug-008-código-personalizado-duplicado-y-desincronizado): una sola fuente de verdad. WordPress se instala con `wp core download`. | Alta | M |
| **Unificar el formulario de contacto** | Una única implementación en `assets/js/`, encolada con `wp_localize_script`, usada por portada y `page-contacto`. Elimina la triplicación y [BUG-006](#bug-006-formulario-de-contacto-roto-en-mainjs). | Alta | M |
| **Descomponer `front-page.php`** | Trocear el monolito de 2.295 líneas en parciales (`template-parts/front/hero.php`, `…/precios.php`, …) cargados con `get_template_part()`, y usar `get_header()`/`get_footer()`. Resuelve [BUG-014](#bug-014-front-pagephp-duplica-el-armazón-del-documento). | Alta | L |
| **Suite de tests** | PHPUnit/Pest para la lógica de seguridad (nonces, token HMAC, rate limiting, validación de `RC_Mantis_API`) y `pytest` para los scripts hexagonales de `scripts/common/`. Es lo que protege los aciertos actuales de una regresión. | Alta | L |
| **CI/CD** | Workflow de GitHub Actions: lint PHP (`php -l`, PHPCS con WPCS), `shellcheck` para Bash, `PSScriptAnalyzer` para PowerShell, `ruff`/`pytest` para Python, y un escáner de secretos (`gitleaks`) que falle el build si reaparece una credencial. | Alta | M |
| **Unificar la licencia** | Un `LICENSE` en la raíz y todas las cabeceras coherentes ([BUG-012](#bug-012-licencia-inconsistente)). | Media | S |
| **Sincronizar la documentación con la realidad** | Reescribir `page-docs.php` con los comandos y el esquema JSON reales ([BUG-013](#bug-013-page-docsphp-documenta-un-producto-ficticio)); mantener `docs/scripting/schema-diagnostico.md` como fuente única del esquema. | Media | M |
| **Versionado coherente** | Esquema SemVer global + versiones por componente documentadas ([BUG-021](#bug-021-versionado-incoherente-entre-componentes)). | Media | S |
| **Content-Security-Policy** | Una vez extraídos CSS/JS inline, añadir cabecera CSP en `resolvecore_security_headers()` — hoy es inviable por el `unsafe-inline` que exigiría todo el código embebido. | Media | S |
| **Focus trap en modales** | Atrapar y restaurar el foco en `#rc-ticket-modal` ([BUG-022](#bug-022-modal-sin-focus-trap)). | Baja | S |
| **`composer.json`** | Gestionar DomPDF y futuras dependencias PHP con Composer, con `autoload` PSR-4 para el código del plugin. | Baja | M |

---

## 5. Tabla resumen final

| ID | Tipo | Título | Severidad/Prioridad | Esfuerzo | Sección |
|----|------|--------|---------------------|----------|---------|
| BUG-001 | Seguridad | `wp-config.php` con secretos reales versionado | 🔴 Crítica | S | [§3](#bug-001-wp-configphp-con-secretos-reales-en-el-control-de-versiones) |
| BUG-002 | Seguridad | `SHODAN_API_KEY` real en `.env.example` | 🔴 Crítica | XS | [§3](#bug-002-shodan_api_key-real-en-envexample) |
| BUG-003 | Seguridad | `config_inc.php` de MantisBT con secretos | 🔴 Crítica | XS | [§3](#bug-003-config_incphp-de-mantisbt-con-secretos) |
| BUG-004 | Seguridad | Dump completo de BD versionado | 🔴 Crítica | S | [§3](#bug-004-dump-completo-de-base-de-datos-versionado) |
| BUG-005 | Seguridad | Base de datos SQLite viva versionada | 🔴 Crítica | S | [§3](#bug-005-base-de-datos-sqlite-viva-versionada) |
| BUG-006 | Funcional | Formulario de contacto roto en `main.js` | 🟠 Alta | XS | [§3](#bug-006-formulario-de-contacto-roto-en-mainjs) |
| BUG-007 | Funcional | Migración SQL incompatible con MySQL | 🟠 Alta | S | [§3](#bug-007-migración-sql-incompatible-con-mysql) |
| BUG-008 | Lógica | Código personalizado duplicado y desincronizado | 🟠 Alta | M | [§3](#bug-008-código-personalizado-duplicado-y-desincronizado) |
| BUG-009 | Lógica | `rc-fleet` no verifica las escrituras en BD | 🟠 Alta | S | [§3](#bug-009-rc-fleet-no-verifica-el-resultado-de-las-escrituras-en-bd) |
| BUG-010 | Funcional/SEO | Doble `<title>` en la portada | 🟡 Media | XS | [§3](#bug-010-doble-etiqueta-title-en-la-portada) |
| BUG-011 | Seguridad | wkhtmltopdf con acceso a ficheros locales | 🟡 Media | S | [§3](#bug-011-generate-reportphp-habilita-acceso-a-ficheros-locales-en-wkhtmltopdf) |
| BUG-012 | Legal | Licencia inconsistente (MIT/GPL-2/GPL-3) | 🟡 Media | S | [§3](#bug-012-licencia-inconsistente) |
| BUG-013 | Documentación | `page-docs.php` documenta un producto ficticio | 🟡 Media | M | [§3](#bug-013-page-docsphp-documenta-un-producto-ficticio) |
| BUG-014 | Mantenibilidad | `front-page.php` duplica el armazón del documento | 🟡 Media | L | [§3](#bug-014-front-pagephp-duplica-el-armazón-del-documento) |
| BUG-015 | Lógica | Constante `RC_MANTIS_PROJECT_ID` muerta | 🟡 Media | S | [§3](#bug-015-constante-rc_mantis_project_id-muerta) |
| BUG-016 | UX/Lógica | Rate limiting consume cuota antes de validar | 🟡 Media | XS | [§3](#bug-016-el-rate-limiting-consume-cuota-antes-de-validar-el-formulario) |
| BUG-017 | Seguridad | Respuesta AJAX filtra detalles de error internos | 🟢 Baja | XS | [§3](#bug-017-la-respuesta-ajax-filtra-detalles-de-error-internos) |
| BUG-018 | Lógica | `register_rest_route` duplicado para la misma ruta | 🟢 Baja | XS | [§3](#bug-018-register_rest_route-invocado-dos-veces-para-la-misma-ruta) |
| BUG-019 | Seguridad | `$color` sin escapar en admin de la flota | 🟢 Baja | XS | [§3](#bug-019-valor-color-sin-escapar-en-la-tabla-de-administración-de-la-flota) |
| BUG-020 | Documentación | Ejemplo PowerShell roto en `page-docs.php` | 🟢 Baja | XS | [§3](#bug-020-ejemplo-powershell-roto-en-la-documentación) |
| BUG-021 | Mantenibilidad | Versionado incoherente entre componentes | 🟢 Baja | S | [§3](#bug-021-versionado-incoherente-entre-componentes) |
| BUG-022 | Accesibilidad | Modal de seguimiento sin focus trap | 🟢 Baja | S | [§3](#bug-022-modal-sin-focus-trap) |
| LIMP-01 | Limpieza | Eliminar core de WordPress (`wp/`) del repo | 🟠 Alta | M | [§4.1](#41-️-para-borrar) |
| LIMP-02 | Limpieza | Eliminar binarios y dumps (`*.tar.gz`, `*.sql`, `*.sqlite`) | 🔴 Crítica | S | [§4.1](#41-️-para-borrar) |
| LIMP-03 | Limpieza | Eliminar `main.js`, `php.ini`, `docs_dump.txt`, `builds/*.zip` | 🟡 Media | XS | [§4.1](#41-️-para-borrar) |
| OPT-01 | Rendimiento | Extraer CSS inline de la portada a hoja encolada | 🟠 Alta | M | [§4.2](#42--para-optimizar) |
| OPT-02 | Rendimiento | Extraer JS inline + `wp_localize_script` | 🟠 Alta | M | [§4.2](#42--para-optimizar) |
| OPT-03 | Rendimiento | Unificar variables `:root` de CSS | 🟡 Media | S | [§4.2](#42--para-optimizar) |
| OPT-04 | Rendimiento | Política de retención para `rc_fleet_hosts.last_json` | 🟡 Media | S | [§4.2](#42--para-optimizar) |
| OPT-05 | Mantenibilidad | Migrar wkhtmltopdf → DomPDF | 🟡 Media | M | [§4.2](#42--para-optimizar) |
| MEJ-01 | Seguridad | Higiene de secretos + rotación + `.gitignore` | 🔴 Crítica | M | [§4.3](#43--para-mejorar) |
| MEJ-02 | Arquitectura | Unificar el formulario de contacto (1 implementación) | 🟠 Alta | M | [§4.3](#43--para-mejorar) |
| MEJ-03 | Arquitectura | Descomponer `front-page.php` en parciales | 🟠 Alta | L | [§4.3](#43--para-mejorar) |
| MEJ-04 | Calidad | Suite de tests (PHPUnit/Pest + pytest) | 🟠 Alta | L | [§4.3](#43--para-mejorar) |
| MEJ-05 | Calidad | CI/CD con lint, shellcheck y escáner de secretos | 🟠 Alta | M | [§4.3](#43--para-mejorar) |
| MEJ-06 | Seguridad | Cabecera Content-Security-Policy | 🟡 Media | S | [§4.3](#43--para-mejorar) |
| MEJ-07 | Calidad | `composer.json` + autoload PSR-4 | 🟢 Baja | M | [§4.3](#43--para-mejorar) |

---

### Cierre

ResolveCore tiene un **núcleo de aplicación de buena ingeniería** rodeado de un **repositorio descuidado**. La buena noticia: ninguno de los hallazgos críticos exige reescribir lógica — son problemas de *higiene* (secretos, ficheros que no deberían estar versionados) que se resuelven en una tarde, más una rotación de credenciales ineludible. Las tres tareas de mayor retorno, por orden:

1. **Rotar los secretos expuestos y sanear el repositorio** (BUG-001 a 005, MEJ-01, LIMP-01/02). Inaplazable.
2. **Resolver la doble fuente de verdad** (BUG-008): hoy es imposible saber qué código corre en producción.
3. **Arreglar lo que está funcionalmente roto** (BUG-007 migración SQL, BUG-006 código muerto).

A partir de ahí, la descomposición de `front-page.php` y la introducción de tests/CI son inversiones de mantenibilidad que protegen lo que ya está bien hecho.

*Fin de la auditoría — fase de diagnóstico. No se ha modificado código.*
