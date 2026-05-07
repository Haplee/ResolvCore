# MantisBT — Integración con ResolveCore

> Ver también: [`docs/stack-tecnologico.md`](stack-tecnologico.md) para justificación completa de tecnologías.

## Arquitectura

```
Usuario → Formulario WP → functions.php → rc_mantis_create_ticket()
                                        → MantisBT REST API POST /api/rest/issues
                                        ← ticket_id en respuesta JSON
                                        → JS muestra "#ID" en mensaje de éxito
```

## Instalación MantisBT en VPS

### 1. Descargar MantisBT

```bash
cd /var/www
wget https://github.com/mantisbt/mantisbt/releases/download/release-2.27.0/mantisbt-2.27.0.tar.gz
tar -xzf mantisbt-2.27.0.tar.gz
mv mantisbt-2.27.0 mantis
```

### 2. Permisos

```bash
chown -R www-data:www-data /var/www/mantis
chmod -R 755 /var/www/mantis
mkdir -p /var/www/mantis/uploads
chmod 775 /var/www/mantis/uploads
```

### 3. Base de datos

```sql
CREATE DATABASE mantisbt CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'mantis_user'@'localhost' IDENTIFIED BY 'CONTRASEÑA_SEGURA';
GRANT SELECT, INSERT, UPDATE, DELETE, INDEX, CREATE, ALTER, DROP
  ON mantisbt.* TO 'mantis_user'@'localhost';
FLUSH PRIVILEGES;
```

### 4. Nginx (site config)

```nginx
server {
    listen 443 ssl;
    server_name tudominio.com;
    root /var/www/mantis;
    index index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~* /admin/ {
        deny all;   # Bloquear tras la instalación
    }
}
```

### 5. Instalación web

1. Copiar `mantisbt/config/config_inc.php.template` → `/var/www/mantis/config/config_inc.php`
2. Editar credenciales y URL
3. Abrir `https://tudominio.com/mantis/admin/install.php`
4. Completar el wizard → `Install/Upgrade Database`
5. Verificar en `admin/check/index.php`
6. **Eliminar el directorio `admin/`** antes de abrir al público

### 6. Setup inicial

```bash
# Crear usuario admin desde la UI:
# Mi cuenta → Gestionar → Crear nueva cuenta (nivel: ADMINISTRATOR)
# Deshabilitar la cuenta "administrator" por defecto
```

### 7. Categorías y campos personalizados

```bash
mysql -umantis_user -p mantisbt < mantisbt/sql/resolvecore-setup.sql
```

---

## Plugin WordPress: rc-mantisbt

**Ruta:** `wordpress/plugins/rc-mantisbt/`

### Activación

1. Copiar el directorio `rc-mantisbt/` a `wp-content/plugins/`
2. Activar en WordPress → Plugins → ResolveCore — MantisBT Integration
3. Configurar en Ajustes → MantisBT

### Configuración

| Campo | Descripción |
|-------|-------------|
| URL MantisBT | URL base, p.ej. `https://tudominio.com/mantis` |
| API Token | Generar en MantisBT → Mi cuenta → API Tokens |
| ID Proyecto | ID numérico del proyecto (ver URL al editar el proyecto) |
| Activar | Checkbox para habilitar la creación automática de tickets |

### Generar API Token en MantisBT

1. Iniciar sesión como administrador
2. Clic en el nombre de usuario → **Mi cuenta**
3. Pestaña **API Tokens**
4. Nombre: `wordpress-integration` → **Crear token**
5. Copiar el token (solo se muestra una vez)

---

## REST API — Endpoints usados

| Método | Endpoint | Uso |
|--------|----------|-----|
| `POST` | `/api/rest/issues` | Crear ticket desde formulario |
| `GET`  | `/api/rest/issues/{id}` | Consultar estado de ticket |
| `POST` | `/api/rest/issues/{id}/notes` | Añadir nota (resumen del diagnóstico) |
| `POST` | `/api/rest/issues/{id}/files` | Adjuntar JSON de diagnóstico |
| `GET`  | `/api/rest/projects` | Verificar conexión |

### Ejemplo de petición (crear ticket)

```http
POST /api/rest/issues HTTP/1.1
Authorization: Token abc123def456...
Content-Type: application/json

{
  "summary": "[ResolveCore] Soporte — Juan García",
  "description": "**Remitente:** Juan García\n**Email:** juan@ejemplo.com\n\n---\n\nMi equipo no arranca...",
  "project": { "id": 1 },
  "category": { "name": "Soporte técnico" },
  "priority": { "name": "high" }
}
```

### Respuesta

```json
{
  "issue": {
    "id": 42,
    "summary": "[ResolveCore] Soporte — Juan García",
    "status": { "name": "new" },
    "priority": { "name": "high" }
  }
}
```

---

## Flujo de ticket en MantisBT

| Estado | Quién actúa | Acción |
|--------|-------------|--------|
| `new` | Técnico | Revisa y asigna |
| `assigned` | Técnico | Conecta vía AnyDesk, ejecuta diagnóstico |
| `resolved` | Técnico | Cierra con resolución + adjunta PDF |
| `closed` | Sistema | Auto-cierre tras 7 días |
| `feedback` | Técnico | Solicita más información al usuario |

---

## Mapeo tipo de consulta → MantisBT

| Formulario WP | Categoría MantisBT | Prioridad |
|---------------|-------------------|-----------|
| Soporte técnico | Soporte técnico | high |
| Reportar un bug | Bug | normal |
| Colaboración | Colaboración | low |
| Licencia | Licencia | normal |
| Otro | General | low |

---

## Plugins instalados

Instalación automática: `bash mantisbt/plugins/install.sh /var/www/mantis`

Configs personalizadas en `mantisbt/plugins/<nombre>/config.php`.

| Plugin | Función | Config |
|--------|---------|--------|
| **source-integration** | Vincula commits GitHub → tickets | `plugins/source-integration/config.php` |
| **MantisKanban** | Vista Kanban del flujo de soporte | Sin config adicional |
| **SetDuedate** | SLA automático según prioridad | `plugins/SetDuedate/config.php` |
| **Reminder** | Aviso si ticket sin atender supera umbral | `plugins/Reminder/config.php` |
| **mailtemplate** | Notificaciones HTML con branding ResolveCore | `plugins/mailtemplate/config.php` |
| **EventLog** | Auditoría completa de eventos | `plugins/EventLog/config.php` |

### source-integration: configurar webhook

1. MantisBT → **Gestionar → Repositorios → Crear repositorio**
   - Tipo: GitHub
   - URL: `https://github.com/Haplee/ResolveCore`

2. GitHub repo → **Settings → Webhooks → Add webhook**
   - Payload URL: `https://tudominio.com/mantis/plugin.php?page=Source/checkin`
   - Content type: `application/json`
   - Secret: `php -r "echo bin2hex(random_bytes(20));"`
   - Events: Push

3. En mensajes de commit usar:
   - `fix #42: descripción` → cierra ticket #42
   - `refs #17: descripción` → referencia sin cerrar

### SetDuedate: SLA activo tras activar plugin

El plugin lee la prioridad del ticket al crearse y calcula la fecha de vencimiento automáticamente. No requiere acción manual del técnico.

---

## Subir el JSON de diagnóstico al ticket

Tras ejecutar `scripts/<os>/diagnostico.*` se obtiene un JSON conforme a [`docs/schema-diagnostico.md`](schema-diagnostico.md). Para asociarlo a un ticket existente:

```php
// Desde cualquier hook de WordPress, p.ej. al cerrar la sesión remota
$ok = rc_mantis_attach_diagnostic( $issue_id, '/ruta/diagnostico_HOST_20260507_120000.json' );
if ( is_wp_error( $ok ) ) {
    error_log( $ok->get_error_message() );
}
```

`rc_mantis_attach_diagnostic()` hace dos cosas:

1. **Adjunta el JSON** vía `POST /api/rest/issues/{id}/files` (multipart/form-data, campo `files[]`).
2. **Crea una nota** privada con un resumen Markdown que el técnico puede leer sin descargar el adjunto (SO, hardware, latencia, estado seguridad).

### Validaciones previas a la subida

| Comprobación | Acción si falla |
|--------------|-----------------|
| Fichero legible y no vacío | `WP_Error('rc_mantis_file_unreadable')` |
| `json_decode` válido | `WP_Error('rc_mantis_json_invalid')` con `json_last_error_msg()` |
| Esquema mínimo: `_meta.plataforma` + `_meta.version` | `WP_Error('rc_mantis_schema_invalid')` |
| Tamaño ≤ 5 MB (límite por defecto Mantis) | `WP_Error('mantis_file_too_large')` |
| Token y URL configurados | `WP_Error('rc_mantis_no_config')` |

Si solo falla la nota (no el adjunto), no se aborta — el adjunto ya está en el ticket y el fallo se loguea con `error_log('[rc-mantisbt] add_note failed: ...')`.

---

## Validación de payload al crear tickets

El cliente valida y normaliza el payload antes de enviar a `POST /api/rest/issues`:

| Campo | Regla |
|-------|-------|
| `summary` | Trim + UTF-8 + máx 250 chars |
| `description` | Trim + UTF-8 + máx 65 000 chars (se añade `[truncado]` si excede) |
| `project_id` | Entero ≥ 1 obligatorio |
| `category` | String no vacío; fallback `'General'` |
| `priority` | Whitelist: `none, low, normal, high, urgent, immediate` → `normal` por defecto |
| `severity` | Whitelist: `feature, trivial, text, tweak, minor, major, crash, block` → `minor` |

`wp_json_encode()` se invoca con `JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES` para no romper acentos ni rutas en los logs.

Cabeceras de la petición:

```http
Authorization: Token <api_token>
Content-Type: application/json; charset=utf-8
Accept: application/json
```

---

## Troubleshooting

| Síntoma | Causa probable | Cómo verificar |
|---------|---------------|----------------|
| `HTTP 401 Unauthorized` | Token revocado/incorrecto | Probar `GET /api/rest/projects` desde "Verificar conexión" en Ajustes → MantisBT |
| `HTTP 403 Forbidden` | Token sin permiso sobre el proyecto | Revisar nivel de acceso del usuario dueño del token en MantisBT |
| `HTTP 404` al adjuntar | `issue_id` no existe en el proyecto | Confirmar ID correcto y mismo proyecto |
| `HTTP 413 Payload Too Large` | JSON > límite Mantis | Subir `php_max_upload_size` y `g_max_file_size` en `config_inc.php` |
| `Category not found` | Categoría inexistente en MantisBT | Crear categoría manualmente o usar `'General'` |
| Acentos rotos en summary/notes | DB MariaDB sin `utf8mb4` | `SHOW CREATE TABLE mantis_bug_table` y migrar collation |
| Adjunto OK pero nota falla | `g_allow_no_category=OFF` y proyecto sin categorías | Crear al menos una categoría en el proyecto |

Logs del plugin: cualquier error HTTP 4xx/5xx se vuelca en el `error_log` de PHP con prefijo `[rc-mantisbt]` y truncado a 1000 caracteres.

```bash
tail -f /var/log/php/error.log | grep rc-mantisbt
```

---

## Esquema esperado del JSON adjunto

El JSON debe contener al menos:

```json
{
  "_meta": {
    "version":     "3.x.y",
    "plataforma":  "windows | linux | android | macos",
    "hostname":    "...",
    "generado_en": "ISO-8601"
  }
}
```

Si falta cualquiera de los dos campos `version` o `plataforma`, el helper rechaza la subida con `rc_mantis_schema_invalid`. Esto evita adjuntar JSONs corruptos o de otro origen al ticket. Estructura completa: ver [`docs/schema-diagnostico.md`](schema-diagnostico.md).
