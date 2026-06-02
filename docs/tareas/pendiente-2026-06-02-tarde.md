# Pendiente — tarde 2026-06-02

## Contexto

Proyecto **ResolveCore** — plataforma de soporte tecnico remoto (TFG ASIR).
Stack: PowerShell 5.1+ (Windows), Bash (Linux/Android), Python 3 (scripts comunes).
Launchers: `scripts/windows/ResolveCore.ps1`, `scripts/linux/ResolveCore.sh`, `scripts/android/ResolveCore.sh`.
Convencion Python: sin clases, sin type hints, entidades como diccionarios (ver CLAUDE.md).

Estas tareas vienen de una **prueba real del tecnico en Windows**. Son continuacion del arreglo integral de los launchers. Implementar esta tarde.

> **Commits:** los hace el autor, no el agente.

---

## Restricciones globales

- **Spooler:** siempre se reporta, nunca se toca ni se desinstala.
- **Destructivos:** requieren flag `--confirm` y confirmacion explicita del tecnico.
- **Schema JSON:** todo campo nuevo en diagnostico se documenta en `docs/scripting/schema-diagnostico.md`.
- **Changelog + defensa:** reflejar cada cambio en `docs/defensa/defensa-tfg.md` y changelog.
- **Encoding:** plantillas .txt 100% ASCII (evita mojibake cp1252 en Windows).
- **JSON valido:** Windows usa `ConvertTo-Json`; Linux usa `LC_ALL=C` (ya aplicado).
- **Bash:** `set -uo pipefail` (sin `-e`); shebang `#!/usr/bin/env bash`.
- **PowerShell:** `#Requires -Version 5.1`.

---

## Tarea 1 — Diagnostico: mostrar en terminal + ampliar recogida

### Estado actual

`diagnostico.ps1` / `.sh` solo escriben el JSON a fichero y muestran la ruta. El JSON Windows es basico: `cpu`, `ram`, `discos`, `antivirus`.

### Que hacer

1. **Imprimir resumen legible en terminal** tras guardar el JSON. El tecnico debe ver los datos sin abrir el fichero (tabla o formato clave-valor).

2. **Ampliar campos del JSON** en las 3 plataformas (Windows / Linux / Android):

| Campo nuevo              | Windows                                            | Linux                          | Android              |
|--------------------------|----------------------------------------------------|---------------------------------|----------------------|
| Servicios criticos       | `Get-Service` (Spooler, wuauserv, WinDefend...)    | `systemctl list-units`          | N/A o `dumpsys`      |
| Actualizaciones pend.    | Ya parcial en analisis; moverlo al JSON diagnostico | `apt-get -s upgrade` / `dnf`   | N/A                  |
| Top procesos CPU/RAM     | `Get-Process | Sort CPU -Desc | Select -First 10`  | `ps aux --sort=-%cpu`           | `top -bn1`           |
| Red (IP/GW/DNS/puertos)  | `Get-NetIPConfiguration`, `Get-NetTCPConnection`   | `ip a`, `ss -tlnp`             | `ifconfig`, `netstat`|
| Temp/SMART disco         | `Get-CimInstance MSStorageDriver` (si disponible)  | `smartctl` / `lm-sensors`       | N/A                  |
| Uptime / arranque / SO   | `Get-CimInstance Win32_OperatingSystem`             | `uptime`, `uname -a`, `/etc/os-release` | `getprop`   |
| Defender / Firewall / UAC| Ya calculado en el menu; volcarlo al JSON           | `ufw status` / `iptables -L`   | N/A                  |

3. **Actualizar `docs/scripting/schema-diagnostico.md`** con todos los campos nuevos.

### Archivos

- `scripts/windows/diagnostico.ps1`
- `scripts/linux/diagnostico.sh`
- `scripts/android/diagnostico.sh`
- `docs/scripting/schema-diagnostico.md`

---

## Tarea 2 — Menu de desinstalacion tras escaneo de vulnerabilidades

### Que hacer

Despues de ejecutar `buscar_vulnerabilidades.py`, mostrar un menu interactivo en el **launcher** (no en el `.py`) que liste las apps marcadas como peligrosas y permita desinstalarlas.

### Flujo

```
buscar_vulnerabilidades.py --salida-json /tmp/vuln-result.json
         |
         v
Launcher lee el JSON → filtra software con kev=true O cvss >= umbral
         |
         v
Muestra lista numerada → tecnico selecciona → confirmacion explicita → desinstala
```

### Desinstalacion por plataforma

| Plataforma | Comando                                                        |
|------------|----------------------------------------------------------------|
| Windows    | `winget uninstall` o `UninstallString` del registro            |
| Linux      | `apt-get remove` / `dnf remove` (con `--confirm`)             |
| Android    | `adb uninstall <paquete>` o `pm uninstall --user 0`           |

### Restricciones

- **Nada se desinstala sin seleccion + confirmacion** del tecnico.
- **Nunca tocar Spooler** ni servicios criticos (lista de exclusion).
- Mostrar advertencia visible antes de ejecutar.
- El escaner exporta con `--salida-json fichero` para que el launcher lea JSON limpio (no parsear stdout mezclado con barras de progreso).

### Archivos

- `scripts/windows/ResolveCore.ps1` → funcion `Invoke-Vulnerabilidades`
- `scripts/linux/ResolveCore.sh` → funcion `run_vulnerabilidades`
- `scripts/android/ResolveCore.sh` → equivalente si aplica
- `scripts/common/buscar_vulnerabilidades.py` → anadir flag `--salida-json`

---

## Tarea 3 — Mejorar el informe .txt (encoding + pre-rellenado)

### Bug de encoding

Sale `NÂº` en lugar de `Nº`. Causa: .txt en UTF-8 pero consola/editor lo lee como cp1252.

**Fix:** plantilla 100% ASCII. Sustituir:
- `Nº` → `N.` o `Nro.`
- Revisar `generar_informe.py` y `generar_factura.py` — eliminar todo caracter no-ASCII.

### Pre-rellenado desde diagnostico

Cuando se pase `--json diagnostico.json`:

| Seccion del informe              | Datos auto-rellenados                                        |
|----------------------------------|--------------------------------------------------------------|
| 2. Incidencias detectadas        | Avisos del analisis (disco bajo, RAM alta, Defender, updates) + vulns KEV/criticas |
| 4. Estado actual del sistema     | CPU, RAM, disco, SO, antivirus del JSON de diagnostico       |
| 5. Recomendaciones               | Checklist sugerido basado en incidencias                     |
| 6. Proyeccion de vida util       | Campos con unidades: `Antiguedad estimada: ___ anos`         |

### Texto-guia

Anadir placeholders entre corchetes en cada apartado para orientar al tecnico:

```
[Describe en 2-3 lineas el motivo de la intervencion]
[Lista las incidencias encontradas durante el diagnostico]
[Indica las acciones realizadas para resolver cada incidencia]
```

### Archivos

- `scripts/common/generar_informe.py`

---

## Tarea 4 — Eliminar opcion Factura del programa principal

### Que hacer

La facturacion la hara **MantisBT**, no el script. Eliminar completamente la funcionalidad.

### Pasos

1. Quitar opcion 5 del menu y su handler (`run_factura` / `Invoke-Factura`).
2. Renumerar menu: de 8 a 7 opciones.
3. Ajustar validacion de entrada: `"Selecciona (1-8)"` → `"Selecciona (1-7)"` y el `case`/`switch`.
4. Actualizar textos de ayuda (`Show-Help`) que mencionen la factura.
5. `generar_factura.py` → mover a `_archivo/common/` (archivar).

### Archivos

- `scripts/windows/ResolveCore.ps1`
- `scripts/linux/ResolveCore.sh`
- (`scripts/android/ResolveCore.sh` — no tiene factura, verificar que no haya referencia)

---

## Tarea 5 — Servicios → Clonacion: corregir parse error en WSL

### Bug

Al registrar imagen (Servicios → Clonacion → 1) revienta:

```
Calculando SHA-256...
zsh: parse error near `)'
zsh: parse error near `" "/mnt/$($args[0].T...'
```

### Causa raiz

`Invoke-BashScript` en `ResolveCore.ps1` convierte ruta Windows→WSL con un `-replace` que usa scriptblock + `$args[0]`:

```powershell
$linuxPath = ($Script -replace '\\', '/') -replace '^([A-Za-z]):', { "/mnt/$($args[0].ToLower())" }
```

En `-replace` con scriptblock, la variable correcta es `$_` (el match completo), no `$args[0]`. Ademas el literal PowerShell se cuela como texto a zsh dentro de WSL → parse error.

### Fix

Reemplazar por conversion explicita sin scriptblock:

```powershell
if ($Script -match '^([A-Za-z]):(.*)$') {
    $linuxPath = '/mnt/' + $Matches[1].ToLower() + ($Matches[2] -replace '\\','/')
}
& wsl bash $linuxPath @Args
```

### Verificaciones adicionales

- Comprobar que los `.sh` de clonacion corren bajo **WSL bash** (no zsh).
- Pasar argumentos correctamente (`--imagen`, `--equipo`...).
- **Revisar el mismo patron** en `Invoke-Congelacion` y `Invoke-Kit` — misma funcion `Invoke-BashScript`.
- Probar end-to-end: Registrar + Verificar imagen desde menu Windows (WSL y Git Bash).

### Archivos

- `scripts/windows/ResolveCore.ps1` → funciones `Invoke-BashScript`, `Invoke-Clonacion`, `Invoke-Congelacion`
- `scripts/servicios/clonacion/registrar-imagen.sh`
- `scripts/servicios/clonacion/verificar-imagen.sh`

---

## Tarea 6 — Organizar salidas por ticket en carpeta `reparaciones/`

### Que hacer

Todos los ficheros generados (diagnostico, informe, factura) deben guardarse en una **carpeta central fuera de `scripts/`**, organizados por numero de ticket de MantisBT. El tecnico encuentra todo lo de una reparacion en un solo sitio.

### Estructura de carpetas

```
ResolveCore/
├── reparaciones/
│   ├── 00042/
│   │   ├── diagnostico.json
│   │   └── informe.txt
│   ├── 00043/
│   │   ├── diagnostico.json
│   │   └── informe.txt
│   └── ...
├── scripts/
│   └── ...
```

- La carpeta `reparaciones/` vive en la raiz del proyecto (al nivel de `scripts/`).
- Subcarpeta = numero de ticket (zero-padded a 5 digitos: `00042`).
- Si la subcarpeta no existe, crearla automaticamente.
- Anadir `reparaciones/` a `.gitignore` (datos locales del tecnico, no se suben al repo).

### Cambios por script

| Script                        | Cambio                                                                                   |
|-------------------------------|------------------------------------------------------------------------------------------|
| `diagnostico.ps1` / `.sh`    | Aceptar parametro `--ticket <N>`. Guardar JSON en `reparaciones/<N>/diagnostico.json`.   |
| `generar_informe.py`         | Aceptar `--ticket <N>`. Guardar .txt en `reparaciones/<N>/informe.txt`.                  |
| Launchers (`ResolveCore.*`)  | Pedir numero de ticket al inicio de la sesion o al invocar cada funcion.                 |

### Comportamiento si no se pasa `--ticket`

- Fallback: guardar en `reparaciones/sin-ticket/` con timestamp en el nombre (`diagnostico_20260602-1430.json`).
- Mostrar aviso: `"No se ha indicado ticket. Guardando en reparaciones/sin-ticket/"`.

### Restricciones

- La ruta base `reparaciones/` debe ser relativa al directorio donde se ejecuta el launcher (o configurable por variable de entorno `RC_REPARACIONES_DIR`).
- No sobreescribir ficheros existentes sin avisar: si ya existe `diagnostico.json` en esa carpeta, preguntar al tecnico si quiere sobreescribir o anadir sufijo (`_v2`).

### Archivos

- `scripts/windows/diagnostico.ps1`
- `scripts/linux/diagnostico.sh`
- `scripts/android/diagnostico.sh`
- `scripts/common/generar_informe.py`
- `scripts/windows/ResolveCore.ps1` — pasar `--ticket` a las funciones
- `scripts/linux/ResolveCore.sh` — idem
- `.gitignore` — anadir `reparaciones/`

---

## Criterios de validacion (cierre de tarde)

| #  | Criterio                                                        | Comando de verificacion                   |
|----|-----------------------------------------------------------------|-------------------------------------------|
| 1  | Diagnostico imprime resumen legible en terminal                 | Ejecutar `diagnostico.ps1` / `.sh`        |
| 2  | JSON de diagnostico incluye campos nuevos y es valido           | `python -m json.tool diagnostico.json`    |
| 3  | Menu de desinstalacion aparece tras vuln scan                   | Ejecutar vuln scan con apps vulnerables   |
| 4  | Nada se desinstala sin seleccion + confirmacion                 | Probar cancelar / confirmar               |
| 5  | Informe .txt sin mojibake (100% ASCII)                          | `file informe.txt` / abrir en Notepad     |
| 6  | Informe pre-rellena datos del diagnostico + muestra guias       | `generar_informe.py --json diag.json`     |
| 7  | Menu principal sin opcion Factura, renumerado, sin rotura       | Ejecutar launcher en las 3 plataformas    |
| 8  | Clonacion registra y verifica imagen sin parse error            | Servicios → Clonacion → 1 y 2 en Windows |
| 9  | Sin errores de sintaxis en ningun script                        | `bash -n *.sh`, `py_compile`, PS parser   |
| 10 | Docs y changelog actualizados                                   | Revisar `schema-diagnostico.md`, defensa  |
| 11 | Ficheros se guardan en `reparaciones/<ticket>/`                 | `--ticket 99999` → comprobar ruta salida  |
| 12 | Sin `--ticket`, usa `reparaciones/sin-ticket/` con aviso        | Ejecutar sin flag y verificar fallback    |
| 13 | Login tecnico redirige a `/tecnicos/`, cliente a `/dashboard/`  | Login con ambos roles y verificar destino |
| 14 | Cliente solo ve SUS tickets, no los de otros                    | Login con 2 clientes distintos            |
| 15 | Ticket en progreso/asignado: cliente no puede modificar/borrar  | Intentar editar ticket con status >= 50   |
| 16 | Dashboard del cliente tiene boton "Cerrar sesion" funcional     | Click en cerrar sesion y verificar logout |

---

## Tarea 7 — Logica web: redireccion por rol, permisos de cliente, cerrar sesion

### Estado actual (analizado)

| Aspecto | Situacion actual |
|---------|-----------------|
| **Redireccion post-login** | No existe. Tanto tecnico como cliente van a la URL por defecto de WP (`/wp-admin/` o la pagina de origen). |
| **Header/nav** | `header.php` muestra el mismo nav publico a todos. No hay items condicionales por rol. |
| **Dashboard cliente** | `page-dashboard.php` + shortcode `[rc_cliente_dashboard]` (plugin `rc-core`). Ya tiene "Cerrar sesion" en el hero. |
| **Filtrado de tickets** | `rc_mantis_filtrar_por_cliente()` **ya filtra** tickets por email del reporter. El cliente ya solo ve los suyos. |
| **Permisos edicion** | El cliente puede crear tickets pero no tiene opcion de editar/borrar desde el dashboard. Sin embargo, no hay logica explicita que bloquee acciones cuando el ticket esta en progreso. |
| **Pagina tecnicos** | `page-tecnicos.php` ya bloquea con 403 a no-editores/no-admin. |

### Que hacer

#### 7a. Redireccion post-login segun rol

Anadir hook `login_redirect` en `functions.php`:

| Rol | Destino |
|-----|---------|
| `administrator` | `/wp-admin/` (comportamiento por defecto de WP) |
| `editor` (tecnico) | `/tecnicos/` |
| `rc_cliente` | `/dashboard/` |
| `subscriber` u otro | `/` (home) |

```php
// En functions.php
function rc_login_redirect( $redirect_to, $request, $user ) {
    if ( ! is_wp_error( $user ) ) {
        if ( in_array( 'editor', $user->roles, true ) ) {
            return home_url( '/tecnicos/' );
        }
        if ( in_array( 'rc_cliente', $user->roles, true ) ) {
            return home_url( '/dashboard/' );
        }
    }
    return $redirect_to;
}
add_filter( 'login_redirect', 'rc_login_redirect', 10, 3 );
```

#### 7b. Nav condicional por rol en `header.php`

- **Tecnico logueado:** ocultar el nav publico de marketing (ya lo hace `page-tecnicos.php` via CSS `.rc-header { display: none }`, pero si navega a otra pagina lo ve). Anadir enlace directo a `/tecnicos/` en el nav.
- **Cliente logueado:** mostrar "Mi panel" en vez de "Contacta con nosotros" como CTA principal. Ocultar items que no le aplican (Docs internos, Fleet Status, Changelog — son para tecnicos).
- **No logueado / publico:** nav actual sin cambios.

#### 7c. Bloquear edicion/borrado de tickets en progreso

En `rc-core.php`, funcion `rc_cliente_render_tickets()`:

- Si `status_id >= 30` (acknowledged o superior): **no mostrar** boton de editar/borrar (actualmente no hay, pero si se anade formulario de edicion en el futuro, proteger).
- En `rc_cliente_render_form()`: si el cliente tiene algun ticket con `status_id == 20` (feedback / esperando info del cliente), mostrar banner visible: *"Tienes un ticket esperando tu respuesta. Revisa el ticket #X antes de crear uno nuevo."*
- **En el procesado POST** (`rc_cliente_procesar_form`): si llega un intento de modificar un ticket con `status_id >= 30`, rechazarlo con error.

#### 7d. Cerrar sesion en el dashboard del cliente

El dashboard **ya tiene** enlace de cerrar sesion en el hero (linea 37 de `page-dashboard.php`):
```php
<a class="rc-dash-hero-logout" href="<?php echo esc_url( wp_logout_url( home_url( '/' ) ) ); ?>">Cerrar sesión</a>
```

**Mejoras:**
- Hacerlo mas visible (actualmente es un enlace discreto). Convertirlo en boton con icono de logout, similar al de `page-tecnicos.php`.
- Anadir tambien un boton de cerrar sesion al **final** de la lista de tickets (el usuario puede no hacer scroll arriba para buscarlo).
- Asegurarse de que al cerrar sesion redirige a `/` (home), no a `wp-login.php`.

### Archivos

- `wordpress/resolvecore-theme/functions.php` → hook `login_redirect`
- `wordpress/resolvecore-theme/header.php` → nav condicional por rol
- `wordpress/resolvecore-theme/page-dashboard.php` → mejorar boton logout
- `wordpress/plugins/rc-core/rc-core.php` → bloqueo edicion tickets en progreso, banner feedback

