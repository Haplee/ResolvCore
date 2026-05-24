# Equipo técnico ResolveCore — Alta y gestión en MantisBT

> Plantilla de equipo + procedimiento UI para alta de los técnicos en MantisBT 2.28.1 de producción (`resolvecore.website`). Crear manualmente desde la UI admin de Mantis.
>
> **Autor:** Francisco Vidal Mateo · **Fecha:** 2026-05-23 · **Ruta canónica:** `docs/tecnica/equipo-tecnicos.md`
>
> Complementa: [`mantis-permisos.md`](mantis-permisos.md) (matriz de capacidades por rol) y [`manual-usuario-mantis.md`](manual-usuario-mantis.md) (workflow del técnico).

---

## 1. Plantilla del equipo

5 cuentas (4 DEVELOPER + 1 MANAGER). Diseño orientado a especialización por SO + un coordinador que cierra tickets y gestiona SLA.

| Username       | Real Name                  | Email                                  | Acceso global  | Especialidad / Función                                       |
|----------------|----------------------------|----------------------------------------|----------------|--------------------------------------------------------------|
| `tecnico1`     | Técnico Senior Cross-OS    | `tecnicos+1@resolvecore.website`       | `DEVELOPER` 55 | Tickets sin SO claro · backup · escalado de incidentes      |
| `tecnico-win`  | Técnico Windows / AD       | `tecnicos+win@resolvecore.website`     | `DEVELOPER` 55 | Win 10/11, Active Directory, GPO, Defender, BitLocker        |
| `tecnico-unix` | Técnico Linux / macOS      | `tecnicos+unix@resolvecore.website`    | `DEVELOPER` 55 | Ubuntu/Debian, systemd, journalctl, brew, FileVault          |
| `tecnico-mob`  | Técnico Móvil              | `tecnicos+mob@resolvecore.website`     | `DEVELOPER` 55 | Android (ADB/Termux), kits remotos                           |
| `coordinador`  | Coordinador SLA            | `coordinador@resolvecore.website`      | `MANAGER` 70   | Cierre RESOLVED→CLOSED · gestión proyecto · revisa PDFs      |

**Notas de diseño:**

- Sufijos `+win`/`+unix`/`+mob` aprovechan **subaddressing** RFC 5233. Ionos lo soporta sobre el buzón `tecnicos@`. Si tu MTA no lo soporta, sustituye por alias reales en el panel Ionos.
- El `coordinador` es **MANAGER** (no DEVELOPER): puede cerrar tickets, ver `due_date`, gestionar proyecto. Necesario para el workflow 4-estados `NEW → ASSIGNED → RESOLVED → CLOSED` (ver [`mantis-permisos.md`](mantis-permisos.md) §3).
- Usernames en lowercase, sólo `[a-z0-9._-]` (validación Mantis).
- Real names en UTF-8 sin restricciones (Mantis acepta acentos).
- **No crear cuentas con privilegios ADMINISTRATOR.** El admin único es Francisco. El principio de mínimo privilegio aplica también al equipo interno.

---

## 2. Alta paso a paso (UI Mantis)

### 2.1 Prerrequisitos

- Estar logueado como **ADMINISTRATOR** en `https://mantis.resolvecore.website/`.
- Verificar que `$g_signup_enabled = OFF` en `mantisbt/config/config_inc.php` (registros públicos cerrados — solo admin da de alta).
- Verificar que el envío SMTP funciona (DKIM/SPF OK — ver [`correo-dkim.md`](correo-dkim.md)) para que el técnico reciba el email de bienvenida con el link de password.
- Si SMTP falla, plan B: setear password manualmente desde el formulario admin (Mantis lo permite si `$g_send_reset_password = OFF`; mejor mantenerlo ON y reenviar reset).

### 2.2 Crear cada cuenta

Por cada fila de la tabla de arriba:

1. Menú lateral **Gestionar → Gestionar usuarios → Crear nueva cuenta**.
   - URL directa: `https://mantis.resolvecore.website/manage_user_create_page.php`
2. Rellenar:
   - **Username**: como en la tabla, lowercase, sin espacios.
   - **Real name**: como en la tabla.
   - **E-mail**: como en la tabla.
   - **Access level**: `DEVELOPER` (o `MANAGER` para `coordinador`).
   - **Enabled**: marcado.
   - **Protected**: **desmarcado** (protected = `READ-ONLY` en el sistema, impide cambios).
3. **Create User**.
4. Mantis envía email con link de set-password. Si no llega en 60s, comprobar Postfix (`mail.log`) y reenviar desde **Gestionar usuarios → [usuario] → Reset password**.

### 2.3 Asignar al proyecto ResolveCore

Por defecto el `DEVELOPER` se incluye automático en proyectos donde tenga acceso global suficiente (ver `mantis-permisos.md` §3 — "Incluido automáticamente en proyectos privados"). Si el proyecto es **público** y el access level global ya es DEVELOPER, no requiere acción extra.

Si el proyecto está marcado como **privado**:

1. **Gestionar → Gestionar proyectos → ResolveCore → Gestionar proyecto**.
2. Sección **Usuarios**: `Add User to Project`.
3. Seleccionar el username creado, access level `DEVELOPER` (o `MANAGER`).
4. **Add User**.

### 2.4 Verificar alta

1. Logout admin → login como el técnico recién creado.
2. Verificar:
   - Acceso a **My View** sin errores.
   - Ve la lista de tickets del proyecto ResolveCore.
   - Puede crear nota en un ticket de prueba.
   - **No** puede borrar proyecto, cambiar permisos ni gestionar usuarios (esto valida que NO es admin).
3. Logout y de vuelta admin.

---

## 3. Hardening post-creación

Aplicar **una vez** tras dar de alta el equipo. Comprobaciones idempotentes — repetir es seguro.

### 3.1 Config Mantis (`config_inc.php`)

```php
# Signup cerrado — solo admin crea cuentas
$g_signup_enabled = OFF;

# Bloqueo tras N intentos fallidos
$g_max_failed_login_count       = 5;
$g_failed_login_lockout_duration = 600;   # segundos

# Cookie session segura (requiere HTTPS — ya activado en producción)
$g_cookie_secure_flag_enabled = ON;

# Expiración de sesión 8h (ajustable)
$g_cookie_time_length = 28800;

# No mostrar versión Mantis en el footer (defensa en profundidad)
$g_show_version = OFF;
```

Tras editar, **no reiniciar nada** — Mantis lee config_inc.php en cada request.

### 3.2 Verificar EventLog registra altas

Plugin `EventLog` ya instalado (ver `mantisbt/plugins/EventLog/`). Comprobar:

1. Tras crear las 5 cuentas, ir a **Gestionar → EventLog**.
2. Debe haber 5 entradas tipo `USER_CREATED` con el username + IP del admin + timestamp.
3. Retención 365 días configurada en `config_inc.php`.

### 3.3 Notificación SLA

Configurar suscripción automática:

1. Por cada técnico: **Mi cuenta → Preferencias → Email**.
   - Activar `Email on Assigned`, `Email on Feedback`, `Email on Resolved`.
2. Coordinador: además activar `Email on New` (recibe todos los tickets entrantes para repartir).

### 3.4 Comprobación final

- Cuenta de cuentas en BD:
  ```sql
  SELECT id, username, realname, email, access_level, enabled
  FROM mantis_user_table
  WHERE access_level >= 55
  ORDER BY access_level DESC, username;
  ```
- Debe devolver **6 filas** (5 nuevas + el admin Francisco).

---

## 4. Asignación de tickets — convención

Sin Round-Robin automático (no implementado todavía). Convención manual mientras tanto:

| Plataforma del ticket | Asigna a       |
|-----------------------|----------------|
| Windows               | `tecnico-win`  |
| Linux / macOS         | `tecnico-unix` |
| Android               | `tecnico-mob`  |
| Sin SO claro / dudoso | `tecnico1`     |
| Cierre RESOLVED→CLOSED| `coordinador`  |

El **plugin `rc-tech`** (ver plan TFG actual) automatizará este routing leyendo el custom field **Plataforma** y haciendo PATCH del handler vía Mantis REST.

---

## 5. Baja / suspensión de un técnico

1. **Gestionar → Gestionar usuarios → [usuario]**.
2. Desmarcar **Enabled** (no borrar — preserva historial de tickets que asignó/cerró).
3. (Opcional) Cambiar access level a `VIEWER` (10) si quieres que conserve acceso de solo lectura.
4. **Update User**.

**No usar `Delete User`** salvo error en alta — borra referencias y rompe el blame de tickets ya cerrados.

---

## 6. Checklist rápido de alta

- [ ] `$g_signup_enabled = OFF` verificado
- [ ] DKIM/SPF/DMARC OK ([`correo-dkim.md`](correo-dkim.md))
- [ ] 5 cuentas creadas (4 DEVELOPER + 1 MANAGER)
- [ ] Email de bienvenida llegó a cada técnico
- [ ] Cada técnico cambió password inicial
- [ ] Suscripciones email configuradas (§3.3)
- [ ] EventLog muestra 5 `USER_CREATED`
- [ ] Smoke test: login técnico, ver tickets, crear nota
- [ ] Hardening §3.1 aplicado
- [ ] Convención de routing §4 comunicada al equipo

---

## Changelog del documento

| Fecha       | Cambio                                                    |
|-------------|-----------------------------------------------------------|
| 2026-05-23  | Versión inicial — equipo 5 técnicos para producción Ionos |
