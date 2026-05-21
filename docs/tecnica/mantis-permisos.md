# MantisBT — Gestión de permisos por capacidad

> Configuración de seguridad de MantisBT 2.28.1 para ResolveCore.
> Define qué nivel de acceso mínimo necesita cada capacidad del sistema.
> **Autor:** Francisco Vidal Mateo · TFG ASIR 2024/25

---

## Niveles de acceso (roles)

MantisBT define seis niveles de acceso jerárquicos. Cada capacidad tiene un **umbral**: el nivel mínimo que la posee. Todos los niveles iguales o superiores la heredan automáticamente.

| Rol | Constante | Nivel | Quién lo usa en ResolveCore |
|-----|-----------|:-----:|------------------------------|
| Espectador | `VIEWER` | 10 | Auditoría de solo lectura (tutor) |
| Informador | `REPORTER` | 25 | Clientes — crean tickets vía la API del plugin WordPress |
| Actualizador | `UPDATER` | 40 | Técnico de apoyo (rol intermedio, sin gestión) |
| Desarrollador | `DEVELOPER` | 55 | Técnico principal — diagnostica y resuelve incidencias |
| Supervisor | `MANAGER` | 70 | Gestión de proyectos y SLA |
| Administrador | `ADMINISTRATOR` | 90 | Administración del sistema y usuarios |

**Criterio aplicado:** principio de mínimo privilegio. El cliente (Informador) recibe lo justo para abrir incidencias y aportar evidencias; no puede borrar nada ni gestionar. El técnico (Desarrollador) tiene el control operativo. Supervisor y Administrador acumulan la gestión de proyectos, campos y usuarios.

Leyenda de las tablas: **✓** = capacidad concedida · **·** = capacidad denegada.

---

## 1. Adjuntos

| Capacidad | Espectador | Informador | Actualizador | Desarrollador | Supervisor | Administrador | Umbral |
|-----------|:----------:|:----------:|:------------:|:-------------:|:----------:|:-------------:|--------|
| Ver lista de adjuntos | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Espectador |
| Descargar adjuntos | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Espectador |
| Adjuntar archivos a la incidencia | · | ✓ | ✓ | ✓ | ✓ | ✓ | Informador |
| Borrar adjuntos | · | · | · | ✓ | ✓ | ✓ | Desarrollador |

**Justificación:** ver y descargar adjuntos es necesario para cualquiera que pueda ver la incidencia. El cliente debe poder adjuntar capturas o ficheros, y la API del plugin adjunta el JSON de diagnóstico — por eso "Adjuntar" baja a Informador. **Borrar** se reserva al técnico: el cliente no debe poder eliminar evidencias (JSON, informe PDF).

---

## 2. Filtros

| Capacidad | Espectador | Informador | Actualizador | Desarrollador | Supervisor | Administrador | Umbral |
|-----------|:----------:|:----------:|:------------:|:-------------:|:----------:|:-------------:|--------|
| Usar filtros guardados | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Espectador |
| Guardar filtros | · | · | · | ✓ | ✓ | ✓ | Desarrollador |
| Guardar filtros como compartidos | · | · | · | · | ✓ | ✓ | Supervisor |

**Justificación:** usar un filtro existente es inofensivo y se permite a todos. Guardar filtros propios es una herramienta de trabajo del técnico. Los filtros **compartidos** afectan a la vista de todos los usuarios, así que se limitan a Supervisor.

---

## 3. Proyectos

| Capacidad | Espectador | Informador | Actualizador | Desarrollador | Supervisor | Administrador | Umbral |
|-----------|:----------:|:----------:|:------------:|:-------------:|:----------:|:-------------:|--------|
| Gestionar proyectos | · | · | · | · | ✓ | ✓ | Supervisor |
| Administrar el acceso de usuarios al proyecto | · | · | · | · | ✓ | ✓ | Supervisor |
| Incluido automáticamente en proyectos privados | · | · | · | ✓ | ✓ | ✓ | Desarrollador |
| Crear Proyecto | · | · | · | · | · | ✓ | Administrador |
| Borrar Proyecto | · | · | · | · | · | ✓ | Administrador |

**Justificación:** crear y borrar proyectos son operaciones estructurales — solo Administrador. La gestión diaria del proyecto y de su acceso de usuarios corresponde al Supervisor. El técnico (Desarrollador) se incluye automáticamente en proyectos privados para poder atender incidencias de clientes sin asignación manual.

---

## 4. Campos personalizados

| Capacidad | Espectador | Informador | Actualizador | Desarrollador | Supervisor | Administrador | Umbral |
|-----------|:----------:|:----------:|:------------:|:-------------:|:----------:|:-------------:|--------|
| Vincular campos personalizados a proyectos | · | · | · | · | ✓ | ✓ | Supervisor |
| Gestionar campos personalizados | · | · | · | · | · | ✓ | Administrador |

**Justificación:** definir o modificar los campos personalizados (Plataforma, AnyDesk ID, Modalidad, Precio, Notas técnico) cambia el modelo de datos — solo Administrador. Vincularlos a un proyecto concreto es gestión de proyecto, nivel Supervisor.

---

## 5. Otros

| Capacidad | Espectador | Informador | Actualizador | Desarrollador | Supervisor | Administrador | Umbral |
|-----------|:----------:|:----------:|:------------:|:-------------:|:----------:|:-------------:|--------|
| Ver Resumen | · | · | · | ✓ | ✓ | ✓ | Desarrollador |
| Enviar recordatorios | · | · | · | ✓ | ✓ | ✓ | Desarrollador |
| Añadir perfiles | · | · | · | ✓ | ✓ | ✓ | Desarrollador |
| Ver la dirección de correo de otros usuarios | · | · | · | · | · | ✓ | Administrador |
| Gestionar usuarios | · | · | · | · | · | ✓ | Administrador |
| Notificación de creación de nuevos usuarios | · | · | · | · | · | ✓ | Administrador |

**Justificación:** el técnico necesita el panel **Resumen** (estadísticas de incidencias), poder **enviar recordatorios** y gestionar **perfiles** de plataforma/hardware. Ver el **correo de otros usuarios** se restringe al Administrador por coherencia con las páginas RGPD del proyecto — el email de un cliente es un dato personal. La gestión de usuarios y sus notificaciones es administración pura.

---

## Resumen por rol

| Rol | Qué puede hacer |
|-----|-----------------|
| **Espectador** | Ver y descargar adjuntos, usar filtros guardados. Solo lectura. |
| **Informador** (cliente) | Lo anterior + adjuntar archivos a su incidencia. |
| **Actualizador** | Igual que Informador a nivel de estas capacidades (su poder real está en el flujo de estados de la incidencia). |
| **Desarrollador** (técnico) | + borrar adjuntos, guardar filtros, acceso a proyectos privados, ver Resumen, enviar recordatorios, añadir perfiles. |
| **Supervisor** | + gestionar proyectos y su acceso, filtros compartidos, vincular campos personalizados. |
| **Administrador** | Todo: crear/borrar proyectos, gestionar campos y usuarios, ver correos. |

---

## Aplicación de la configuración

### Opción A — Interfaz web (recomendada para la defensa)

`Gestionar → Configuración → Gestión de permisos`

Para cada capacidad, marca la casilla del nivel **umbral**; los niveles superiores se heredan solos. El Administrador siempre conserva todas las capacidades.

### Opción B — `config_inc.php` (configuración reproducible)

Equivalente como código, apto para versionar y redeplegar. Las constantes `VIEWER`, `REPORTER`, `UPDATER`, `DEVELOPER`, `MANAGER` y `ADMINISTRATOR` las define MantisBT.

**Este bloque ya está aplicado** en el repositorio: `mantisbt/config/config_inc.php` (entorno Docker local) y `mantisbt/config/config_inc.php.template` (referencia de producción).

```php
// === ResolveCore — Gestión de permisos MantisBT ===

// 1. Adjuntos
$g_view_attachments_threshold      = VIEWER;
$g_download_attachments_threshold  = VIEWER;
$g_upload_bug_file_threshold       = REPORTER;
$g_delete_attachments_threshold    = DEVELOPER;

// 2. Filtros
$g_stored_query_create_threshold         = DEVELOPER;
$g_stored_query_create_shared_threshold  = MANAGER;

// 3. Proyectos
$g_manage_project_threshold  = MANAGER;
$g_project_user_threshold    = MANAGER;
$g_private_project_threshold = DEVELOPER;
$g_create_project_threshold  = ADMINISTRATOR;
$g_delete_project_threshold  = ADMINISTRATOR;

// 4. Campos personalizados
$g_custom_field_link_threshold     = MANAGER;
$g_manage_custom_fields_threshold  = ADMINISTRATOR;

// 5. Otros
$g_view_summary_threshold             = DEVELOPER;
$g_add_profile_threshold              = DEVELOPER;
$g_show_user_email_threshold          = ADMINISTRATOR;
$g_manage_user_threshold              = ADMINISTRATOR;
$g_notify_new_user_created_threshold  = ADMINISTRATOR;
```

> **«Usar filtros guardados»** y **«Enviar recordatorios»** no tienen una constante global fiable en MantisBT 2.28 — se ajustan desde la interfaz `Gestionar → Configuración → Gestión de permisos` (umbrales recomendados: Espectador y Desarrollador respectivamente).

> Tras editar `config_inc.php`, recarga cualquier página de MantisBT para aplicar los cambios. Si una capacidad aparece distinta en la interfaz, prevalece el valor guardado en base de datos sobre el de `config_inc.php`: revísalo en `Gestionar → Configuración → Gestión de permisos`.

> **VPS en producción:** la instancia ya desplegada en `mantis.resolvecore.website` usa su propio `config_inc.php` (generado por el instalador, fuera del repo). Para aplicar estos permisos allí, copia el bloque anterior a `/var/www/mantis/config/config_inc.php` en el VPS.
