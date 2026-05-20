# Manual de Configuración, Integración y Usuario de MantisBT — ResolveCore

> Documento técnico de referencia para la operación del gestor de tickets MantisBT v2.27
> dentro de la plataforma ResolveCore. Dirigido a Administrador de Sistemas en Red
> (rol ADMINISTRATOR) y técnico de soporte (rol DEVELOPER / UPDATER).
>
> Ruta canónica: `docs/tecnica/manual-usuario-mantis.md`.

---

## SECCIÓN 1 · ARQUITECTURA E INTEGRACIÓN WP ↔ MantisBT

### 1.1 Topología de servicios

| Servicio | Origen | Host / Puerto | Imagen / Stack |
|----------|--------|---------------|----------------|
| WordPress (frontend ResolveCore) | LocalWP | `localhost:80` / `:443` | PHP-FPM + nginx |
| Plugin `rc-mantisbt`             | WordPress (`wp-content/plugins/`) | — | PHP 8.x |
| MantisBT v2.27                   | Docker Compose | `localhost:8989 → 80` | `vimagick/mantisbt` |
| MySQL 5.7                        | Docker Compose | red interna `mantis_net:3306` | `mysql:5.7` |

Levantar stack:

```bash
docker compose -f mantisbt/docker-compose.yml up -d
docker compose -f mantisbt/docker-compose.yml ps
```

### 1.2 Flujo de petición (formulario → ticket)

```
[Navegador]
   │  POST /wp-admin/admin-ajax.php   action=resolvecore_contact
   ▼
[WordPress :80]
   │  resolvecore_handle_contact()       (functions.php)
   │     ├─ check_ajax_referer()           — nonce CSRF
   │     ├─ honeypot rc_website            — anti-spam
   │     ├─ rate-limit transient           — 3 envíos / IP / hora
   │     ├─ sanitize_* / is_email()
   │     └─ wp_mail() + rc_mantis_create_ticket(...)
   │
   ▼
[Plugin rc-mantisbt → RC_Mantis_API]
   │  POST http://localhost:8989/api/rest/issues
   │     Authorization: <API_TOKEN>
   │     Content-Type:  application/json; charset=utf-8
   │     Body JSON:
   │        { "summary":..., "description":...,
   │          "project":   { "id": 1 },
   │          "category":  { "name": "Soporte técnico" },
   │          "priority":  { "name": "high" },
   │          "severity":  { "name": "minor" } }
   ▼
[MantisBT :8989/api/rest/issues]
   │  Validación token → permisos REPORTER → INSERT mantis_bug_table
   │  ← 201 Created { "issue": { "id": <ID>, ... } }
   ▼
[WordPress]
   │  Devuelve JSON al frontend:
   │     { "success": true, "data": { "ticket_id": <ID>, "msg": "Ticket #<ID> creado" } }
```

Latencia típica en local: 80–220 ms por petición (sin SMTP). Si `wp_mail()`
usa SMTP externo, sumar 600–1500 ms.

### 1.3 Red local — redirección de peticiones

WordPress y MantisBT comparten host, pero exponen puertos distintos:

```
Cliente externo ──▶ nginx :443 (WP) ──▶ PHP-FPM (functions.php)
                                            │
                                            ▼
                              wp_remote_request() loopback
                                            │
                                            ▼
                              http://localhost:8989/api/rest/issues
                                  (Docker container vimagick/mantisbt)
```

Notas operativas:
- La petición sale **del propio servidor PHP** vía `wp_remote_request()` (clase
  `RC_Mantis_API` → método privado `request()`). No es CORS — no cruza navegador.
- Si MantisBT corre en otra máquina, sustituir la URL base por
  `https://mantis.dominio.tld/` y abrir el firewall del host MantisBT al host WP.
- En LocalWP el contenedor Docker debe ser alcanzable desde el PHP de WordPress:
  usar `host.docker.internal` si LocalWP corre en contenedor distinto.

### 1.4 Configuración mínima de `config_inc.php`

Archivo: `mantisbt/config/config_inc.php` (copia desde `config_inc.php.template`).
Claves obligatorias para habilitar la REST API y la integración:

```php
# ── API REST ─────────────────────────────────────────────────
$g_allow_rest_api = ON;          # MantisBT 2.x — directiva canónica
# (en docs antiguas aparece como $g_webservice_rest_enabled = ON;
#  ambas controlan el mismo flag interno en versiones de transición)

# ── Origen y URL pública ────────────────────────────────────
$g_path = 'http://localhost:8989/';     # debe terminar en '/'

# ── Token de seguridad (CSRF + sesión) ──────────────────────
$g_crypto_master_salt = 'GENERAR_CON: php -r "echo bin2hex(random_bytes(32));"';

# ── Umbrales de workflow alineados con ResolveCore ──────────
$g_report_bug_threshold    = REPORTER;     # 25
$g_update_bug_threshold    = DEVELOPER;    # 55
$g_resolve_bug_threshold   = DEVELOPER;    # 55
$g_close_bug_threshold     = MANAGER;      # 70
$g_auto_set_status_to_assigned = ON;
```

### 1.5 Token de API de larga duración (REPORTER)

Generación, vinculado a una cuenta de servicio (no a un humano):

1. MantisBT → `Mi cuenta` → `Tokens de API` → `Crear token`.
2. Nombre: `wp-rc-mantisbt-prod` (o `-dev`). Sin expiración (long-lived).
3. **Copiar el token UNA VEZ** — Mantis no lo vuelve a mostrar.
4. Almacenar en `wp-config.php` (NUNCA en `wp_options`):

```php
// wp-config.php
define( 'RC_MANTIS_URL',   'http://localhost:8989' );
define( 'RC_MANTIS_TOKEN', 'PASTE_TOKEN_HERE' );
```

El plugin `rc-mantisbt` da prioridad a las constantes sobre `wp_options`
(`rc_mantis_get_token()` en `wordpress/plugins/rc-mantisbt/rc-mantisbt.php`).

---

## SECCIÓN 2 · BASE DE DATOS Y CAMPOS PERSONALIZADOS (SQL DIRECTO)

### 2.1 Tablas relevantes

| Tabla | Función | Filas/ticket |
|-------|---------|--------------|
| `mantis_bug_table`                     | Ficha del ticket (resumen, descripción, prioridad, estado) | 1 |
| `mantis_bug_text_table`                | Texto largo (descripción, pasos para reproducir)             | 1 |
| `mantis_category_table`                | Categorías por proyecto                                       | n |
| `mantis_custom_field_table`            | Definición global del campo personalizado                     | 1/campo |
| `mantis_custom_field_project_table`    | Asociación campo ↔ proyecto + orden de visualización          | 1/(campo,proyecto) |
| `mantis_custom_field_string_table`     | Valor real del campo en cada ticket                           | 1/(campo,ticket) |
| `mantis_bugnote_table` + `_text_table` | Notas técnicas y comentarios                                  | n |
| `mantis_bug_file_table`                | Adjuntos (PDF, JSON de diagnóstico)                            | n |
| `mantis_user_table`                    | Cuentas (técnicos, cuenta de servicio WP)                      | n |
| `mantis_api_token_table`               | Tokens API + último uso                                        | n |

### 2.2 Definición de campos personalizados — esquema utilizado

Fichero canónico: `mantisbt/sql/resolvecore-setup.sql`. Ejecutar **después** de la
instalación web de MantisBT, con el proyecto `Incidencias` ya creado y con ID `1`.

#### 2.2.1 Campo `Plataforma` — `type = 6` (lista desplegable)

```sql
INSERT IGNORE INTO mantis_custom_field_table
  (name, type, possible_values, default_value, valid_regexp,
   access_level_r, access_level_rw, length_min, length_max,
   filter_by, display_report, display_update, display_resolved,
   display_closed, require_report, require_update, require_resolved, require_closed)
VALUES
  ('Plataforma',
   6,                                       -- type 6 = enumeración/lista
   'Windows|Linux|macOS|Android|Otro',      -- possible_values separados por '|'
   'Windows',                               -- default_value
   '',                                      -- sin regex (la lista ya restringe)
   10, 55,                                  -- read = VIEWER (10), write = DEVELOPER (55)
   0, 0,
   1,                                       -- filter_by: se puede filtrar en listados
   1, 1, 1, 1,                              -- visible en report/update/resolved/closed
   1,                                       -- require_report = ON (obligatorio al crear)
   0, 0, 0);
```

#### 2.2.2 Campo `AnyDesk ID` — `type = 0` (texto plano)

```sql
INSERT IGNORE INTO mantis_custom_field_table
  (name, type, possible_values, default_value, valid_regexp,
   access_level_r, access_level_rw, length_min, length_max,
   filter_by, display_report, display_update, display_resolved,
   display_closed, require_report, require_update, require_resolved, require_closed)
VALUES
  ('AnyDesk ID',
   0,                                       -- type 0 = texto plano
   '', '',
   '^[0-9 ]{0,15}$',                        -- regex: solo dígitos + espacios, máx 15
   10, 55,
   0, 15,                                   -- length_min=0, length_max=15
   0,
   0, 1, 0, 0,                              -- solo visible/editable en estado 'update'
   0, 0, 0, 0);                             -- nunca obligatorio en alta vía API
```

#### 2.2.3 Asociación campo ↔ proyecto

`mantis_custom_field_project_table` enlaza la definición global al proyecto `1`
y fija el orden de visualización (`sequence`):

```sql
SET @field_id          = (SELECT id FROM mantis_custom_field_table WHERE name = 'Plataforma'  LIMIT 1);
SET @anydesk_field_id  = (SELECT id FROM mantis_custom_field_table WHERE name = 'AnyDesk ID'  LIMIT 1);

INSERT IGNORE INTO mantis_custom_field_project_table (field_id, project_id, sequence)
VALUES
  (@field_id,         1, 10),    -- Plataforma primero
  (@anydesk_field_id, 1, 20);    -- AnyDesk ID después
```

### 2.3 Tabla de tipos de campo (`mantis_custom_field_table.type`)

| Tipo | Constante MantisBT     | Descripción           | Valida con |
|------|------------------------|------------------------|------------|
| 0    | `CUSTOM_FIELD_TYPE_STRING`     | Texto libre           | `valid_regexp` |
| 1    | `CUSTOM_FIELD_TYPE_NUMERIC`    | Numérico              | rango `length_*` |
| 3    | `CUSTOM_FIELD_TYPE_DATE`       | Fecha (timestamp)     | calendar picker |
| 4    | `CUSTOM_FIELD_TYPE_CHECKBOX`   | Múltiple checkbox     | `possible_values` |
| 5    | `CUSTOM_FIELD_TYPE_LIST`       | Lista (single select) | `possible_values` |
| 6    | `CUSTOM_FIELD_TYPE_MULTILIST`  | Lista múltiple        | `possible_values` |
| 7    | `CUSTOM_FIELD_TYPE_EMAIL`      | Email                 | regex interna |
| 8    | `CUSTOM_FIELD_TYPE_TEXTAREA`   | Textarea              | `valid_regexp` |
| 9    | `CUSTOM_FIELD_TYPE_RADIO`      | Radio                 | `possible_values` |

> ResolveCore usa **type 6 (lista) para `Plataforma`** y **type 0 (texto) para `AnyDesk ID`**.

### 2.4 Almacenamiento de valores por ticket

`mantis_custom_field_string_table` guarda el valor real por par (bug, field):

```sql
-- Estructura simplificada
CREATE TABLE mantis_custom_field_string_table (
  field_id INT UNSIGNED NOT NULL,
  bug_id   INT UNSIGNED NOT NULL,
  value    TEXT         NOT NULL,
  PRIMARY KEY (field_id, bug_id),
  KEY idx_custom_field_bug (bug_id, field_id)
);
```

Consulta de plataforma y AnyDesk ID de un ticket:

```sql
SELECT
  b.id                                   AS ticket,
  b.summary,
  MAX(CASE WHEN cf.name = 'Plataforma'  THEN s.value END) AS plataforma,
  MAX(CASE WHEN cf.name = 'AnyDesk ID'  THEN s.value END) AS anydesk_id
FROM mantis_bug_table b
LEFT JOIN mantis_custom_field_string_table s ON s.bug_id   = b.id
LEFT JOIN mantis_custom_field_table        cf ON cf.id      = s.field_id
WHERE b.project_id = 1
GROUP BY b.id, b.summary
ORDER BY b.id DESC
LIMIT 50;
```

### 2.5 Categorías del proyecto Incidencias

```sql
INSERT IGNORE INTO mantis_category_table (project_id, user_id, name, status)
VALUES
  (1, 1, 'Soporte técnico', 10),
  (1, 1, 'Bug',             10),
  (1, 1, 'Colaboración',    10),
  (1, 1, 'Licencia',        10),
  (1, 1, 'General',         10);
```

El plugin `rc-mantisbt` mapea el campo `type` del formulario web a estas categorías
en `rc_mantis_create_ticket()` (array `$category_map`).

---

## SECCIÓN 3 · FLUJO DE ESTADOS DE SOPORTE TÉCNICO

Estados internos de MantisBT relevantes (códigos en `mantis_bug_table.status`):

| Código | Constante         | Etiqueta visible | Umbral de transición |
|--------|-------------------|------------------|----------------------|
| 10     | `NEW_`            | Nueva            | API/REPORTER         |
| 20     | `FEEDBACK`        | Realimentación   | DEVELOPER            |
| 30     | `ACKNOWLEDGED`    | Reconocida       | DEVELOPER            |
| 40     | `CONFIRMED`       | Confirmada       | DEVELOPER            |
| 50     | `ASSIGNED`        | Asignada         | DEVELOPER            |
| 80     | `RESOLVED`        | Resuelta         | DEVELOPER            |
| 90     | `CLOSED`          | Cerrada          | MANAGER              |

`$g_auto_set_status_to_assigned = ON` provoca el salto automático
`NEW_(10) → ASSIGNED(50)` en cuanto se asigna un handler.

### 3.1 Transición 1 — `Nueva` (creación por API)

- **Origen:** `POST /api/rest/issues` desde WordPress.
- **Actor:** cuenta de servicio `wp-rc-mantisbt-prod` (rol REPORTER).
- **Estado inicial:** `NEW_` (10).
- **Proyecto:** `1 — Incidencias`.
- **Campos automáticos rellenados por el plugin:**
  - `summary` = `[ResolveCore] <Tipo> — <Nombre>`
  - `description` = bloque Markdown con remitente, email, tipo, mensaje
  - `category.name` = `Soporte técnico` | `Bug` | `Colaboración` | `Licencia` | `General`
  - `priority.name` = `high` (soporte) / `normal` (bug, licencia) / `low` (otros)
- **Pendiente del técnico:** revisar bandeja del proyecto y autoasignarse.

### 3.2 Transición 2 — `Asignada` (técnico, rol DEVELOPER / UPDATER)

Acciones físicas del técnico:

1. **Autoasignación**
   ```
   Ver ticket #ID → bloque "Asignar a" → seleccionar usuario propio → Actualizar
   ```
   La columna `mantis_bug_table.handler_id` pasa a `user_id` del técnico.
   El estado salta a `ASSIGNED` (50) por `$g_auto_set_status_to_assigned`.

2. **Lectura de metadatos ResolveCore** desde la ficha avanzada:
   - `Plataforma` (lista) — determina el script de diagnóstico a lanzar.
   - `AnyDesk ID` (texto, regex `^[0-9 ]{0,15}$`) — id del cliente para AnyDesk.

   Consulta SQL equivalente para automatizar:
   ```sql
   SELECT
     MAX(CASE WHEN cf.name='Plataforma' THEN s.value END) AS plataforma,
     MAX(CASE WHEN cf.name='AnyDesk ID' THEN s.value END) AS anydesk_id
   FROM mantis_custom_field_string_table s
   JOIN mantis_custom_field_table cf ON cf.id = s.field_id
   WHERE s.bug_id = <ID>;
   ```

3. **Conexión remota y ejecución de scripts**
   - `AnyDesk → Conectar con <AnyDesk ID>` → el usuario acepta la sesión.
   - Según plataforma:
     ```powershell
     # Windows
     pwsh .\scripts\windows\diagnostico.ps1 -OutputJson .\scripts\diagnosticos\diag-<ID>.json
     ```
     ```bash
     # Linux / macOS
     bash ./scripts/linux/diagnostico.sh   --json scripts/diagnosticos/diag-<ID>.json
     bash ./scripts/macos/diagnostico.sh   --json scripts/diagnosticos/diag-<ID>.json
     ```

4. **Adjuntar JSON de diagnóstico al ticket**
   - Vía UI: pestaña *Subir fichero* → seleccionar `diag-<ID>.json`.
   - Vía API (preferido — desde un script o WP-CLI):
     ```php
     rc_mantis_attach_diagnostic( <ID>, 'scripts/diagnosticos/diag-<ID>.json', true );
     ```
     La función valida `_meta.plataforma` + `_meta.version` y añade nota
     privada con resumen (hardware, SO, red, seguridad).

### 3.3 Transición 3 — `Resuelta` (técnico, rol DEVELOPER)

1. Generar informe PDF a partir de la plantilla:
   ```bash
   php artisan resolvecore:report --ticket=<ID>
   # → produce reports/output/informe-diagnostico-<ID>.pdf
   ```
2. Adjuntar el PDF al ticket vía `RC_Mantis_API::attach_file()`:
   ```php
   $api->attach_file( <ID>, 'reports/output/informe-diagnostico-' . $ID . '.pdf' );
   ```
   Límite: 5 MB (`RC_Mantis_API::MAX_FILE_BYTES`).
3. Añadir **nota técnica pública** describiendo la acción tomada:
   ```php
   $api->add_note( <ID>,
       "Acción tomada:\n- Limpieza de temporales (1.4 GB)\n- Actualización de drivers chipset\n- CVE-2024-3049 parcheado\nEstado final: nominal.",
       'public' );
   ```
4. Cambiar el estado a `Resuelta` (80) desde la UI:
   - `Resolver problema` → seleccionar resolución (`fixed`, `won't fix`, etc.)
   - Asignar versión fijada en `mantis_project_version_table` (por defecto `v1.0.0`).

   El umbral para llegar a este estado es `DEVELOPER` (55) — fijado en
   `$g_resolve_bug_threshold` (sección 1.4).

### 3.4 Transición 4 — `Cerrada` (Administrador / MANAGER)

- Verificación: el informe PDF está adjunto, la nota técnica existe, el cliente
  confirma la resolución.
- Comprobación de facturación: factura emitida o cargo en suscripción procesado.
- Acción:
  ```
  Ver ticket #ID → "Cerrar problema" → confirmar
  ```
  Estado pasa a `CLOSED` (90). Umbral requerido: `MANAGER` (70) —
  `$g_close_bug_threshold = MANAGER`.
- Auditoría: el cambio queda registrado en `mantis_bug_history_table` con
  `field_name = 'status'`, `old_value = 80`, `new_value = 90`.

### 3.5 Resumen visual del workflow

```
[API/REPORTER]    [DEVELOPER]              [DEVELOPER]                  [MANAGER]
   NEW_ (10) ──▶  ASSIGNED (50) ───────▶   RESOLVED (80) ───────────▶   CLOSED (90)
                  · autoasignación         · adjunta PDF                · verificación
                  · lee custom fields      · nota técnica               · factura/pago
                  · ejecuta scripts        · resolución=fixed
                  · adjunta JSON           · version=v1.0.0
```

---

## SECCIÓN 4 · SEGURIDAD Y PERMISOS — MATRIZ DE ROLES

### 4.1 Niveles de acceso MantisBT (`access_level`)

| Nivel | Constante           | Valor | Uso ResolveCore                |
|-------|---------------------|-------|--------------------------------|
| 10    | `VIEWER`            | 10    | Lectura pública (no usado)     |
| 25    | `REPORTER`          | 25    | **Cuenta de servicio WP**      |
| 40    | `UPDATER`           | 40    | (reservado, no usado)          |
| 55    | `DEVELOPER`         | 55    | **Técnico de soporte**         |
| 70    | `MANAGER`           | 70    | Coordinación / cierre tickets  |
| 90    | `ADMINISTRATOR`     | 90    | **Administrador del stack**    |

### 4.2 Matriz de permisos por rol ResolveCore

| Capacidad                                  | Reporter (WP) | Developer (Técnico) | Administrator |
|--------------------------------------------|:--------------:|:-------------------:|:-------------:|
| Crear ticket vía REST API                  | ✅ | ✅ | ✅ |
| Leer tickets propios                       | ✅ | ✅ | ✅ |
| Leer **todos** los tickets del proyecto    | ❌ | ✅ | ✅ |
| Asignarse handler                          | ❌ | ✅ | ✅ |
| Modificar campos personalizados            | ❌ | ✅ | ✅ |
| Añadir notas públicas                      | ❌ | ✅ | ✅ |
| Añadir notas privadas                      | ❌ | ✅ | ✅ |
| Adjuntar ficheros (JSON, PDF)              | ❌ | ✅ | ✅ |
| Cambiar estado a `Resuelta`                | ❌ | ✅ | ✅ |
| Cambiar estado a `Cerrada`                 | ❌ | ❌ | ✅ |
| Editar tickets de otros usuarios           | ❌ | ❌ | ✅ |
| Crear/modificar campos personalizados      | ❌ | ❌ | ✅ |
| Regenerar tokens API (otros usuarios)      | ❌ | ❌ | ✅ |
| Acceder a `manage_user_page.php`           | ❌ | ❌ | ✅ |
| Auditoría — leer `mantis_bug_history_table` | ❌ | ✅ (sólo lectura) | ✅ (completo) |
| Operar stack Docker (`docker compose ...`) | ❌ | ❌ | ✅ |
| Backup/restore `mantisbt/sql/`             | ❌ | ❌ | ✅ |

### 4.3 Cuenta de servicio WordPress (REPORTER)

Perfil dedicado, **sin acceso de lectura cruzada** a otros tickets:

```sql
-- Crear usuario para WP (ejecutar como ADMINISTRATOR)
INSERT INTO mantis_user_table (username, realname, email, enabled, access_level, login_count, date_created)
VALUES ('wp-resolvecore', 'WordPress ResolveCore', 'noreply@tudominio.com', 1, 25, 0, UNIX_TIMESTAMP());
```

Tras crear el usuario, generar token desde su cuenta:

```
Login como wp-resolvecore → Mi cuenta → API Tokens → Crear
Nombre: wp-rc-mantisbt-prod
```

Restringir lectura a tickets ajenos (configuración a nivel proyecto):

```php
# config_inc.php — restricción extra para REPORTER
$g_limit_reporters       = ON;   // un reporter sólo ve sus propios bugs
$g_view_bug_threshold    = REPORTER;
```

### 4.4 Cuenta de técnico (DEVELOPER)

```sql
INSERT INTO mantis_user_table (username, realname, email, enabled, access_level, login_count, date_created)
VALUES ('tecnico1', 'Nombre Apellidos', 'tecnico1@tudominio.com', 1, 55, 0, UNIX_TIMESTAMP());
```

Asignar al proyecto `Incidencias` con nivel DEVELOPER:

```sql
INSERT INTO mantis_project_user_list_table (project_id, user_id, access_level)
SELECT 1, id, 55
FROM mantis_user_table
WHERE username = 'tecnico1';
```

### 4.5 Cuenta de Administrador

- Usuario inicial creado durante `admin/install.php` con `access_level = 90`.
- **Cambiar contraseña inicial inmediatamente**: `manage_user_edit_page.php?user_id=1`.
- Tareas exclusivas:
  - Mantenimiento del stack:
    ```bash
    docker compose -f mantisbt/docker-compose.yml pull
    docker compose -f mantisbt/docker-compose.yml up -d --remove-orphans
    docker compose -f mantisbt/docker-compose.yml logs -f mantisbt
    ```
  - Backup MySQL:
    ```bash
    docker compose -f mantisbt/docker-compose.yml exec db \
      mysqldump -uroot -proot mantis > backups/mantis-$(date +%F).sql
    ```
  - Regenerar token API comprometido:
    ```
    Gestionar → Usuarios → <usuario> → API Tokens → Revocar
    ```
    Acto seguido actualizar `wp-config.php` (`RC_MANTIS_TOKEN`).
  - Auditoría EventLog:
    ```sql
    SELECT user_id, event_type, FROM_UNIXTIME(timestamp) AS ts, message
    FROM mantis_log_event_table
    WHERE timestamp > UNIX_TIMESTAMP(NOW() - INTERVAL 7 DAY)
    ORDER BY ts DESC;
    ```

### 4.6 Endurecimiento adicional recomendado

- **Bloquear `/admin/` tras la instalación** en nginx:
  ```nginx
  location ~* /admin/ { deny all; return 404; }
  ```
- **Desactivar registro público:** `$g_allow_signup = OFF;`.
- **Forzar HTTPS** en cualquier despliegue público: `$g_path = 'https://...';`
  + redirección 301 desde 80.
- **Rotar `crypto_master_salt`** invalida sesiones — hacerlo solo si el secreto
  se filtra. Regenerar con `php -r "echo bin2hex(random_bytes(32));"`.
- **Limitar superficie REST API** a hosts conocidos (firewall del Docker host
  bloqueando `:8989` desde fuera del loopback, o reverse proxy con auth-basic
  delante).
