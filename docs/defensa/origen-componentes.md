# ResolveCore — Origen y autoría de componentes

**Alumno:** Francisco Vidal Mateo (Haplee)  
**TFG ASIR 2024/25 — IES / Centro**  
**Fecha:** 20 de mayo de 2026

> Documento para el tribunal: justifica el origen de cada componente del proyecto,
> distinguiendo entre software de terceros reutilizado, código propio y el uso de
> herramientas de IA como asistente de desarrollo.

---

## Nota sobre el uso de IA

Durante el desarrollo de ResolveCore se ha utilizado **Claude (Anthropic)** como
asistente de programación, de forma análoga a como se usa Stack Overflow, la
documentación oficial o un compañero más experimentado. El rol de la IA ha sido:

- Sugerir estructuras y detectar errores en el código escrito por el alumno.
- Explicar APIs y comportamientos de herramientas (MantisBT REST, Shodan API, udev).
- Revisar y refactorizar scripts que el alumno había escrito previamente.

**Todo el código ha sido comprendido, revisado, probado y adaptado por el alumno.**
No se ha usado IA para generar código que no se entienda ni se sepa defender.
Esta práctica es equivalente al uso de cualquier otra herramienta de consulta y
está en línea con las competencias de un técnico ASIR que debe saber integrar y
adaptar herramientas existentes.

---

## 1. MantisBT (gestor de incidencias)

| Campo | Valor |
|-------|-------|
| Origen | Software libre de terceros |
| Licencia | GPL-2.0 |
| Fuente | https://mantisbt.org — versión 2.27 LTS |
| Autor original | MantisBT Team |

**Qué he hecho yo:**
- Despliegue local vía Docker (`mantisbt/docker-compose.yml`).
- Configuración completa del sistema (`mantisbt/config/config_inc.php`):
  - SMTP, BD, API REST, permisos por rol, workflow de estados.
- Script SQL de setup ResolveCore (`mantisbt/sql/resolvecore-setup.sql`):
  - 5 categorías de ticket (Soporte, Bug, Colaboración, Licencia, General).
  - Campo personalizado "Plataforma" (Windows/Linux/macOS/Android/Otro).
  - Campo personalizado "AnyDesk ID" para registrar la sesión remota.
- Integración con WordPress vía API REST (ver punto 4).

**No he modificado** el código fuente de MantisBT — se usa como aplicación.

---

## 2. Plugins de MantisBT

Los siguientes plugins son proyectos open source independientes descargados del
repositorio oficial de MantisBT (`github.com/mantisbt-plugins`):

| Plugin | Función | Fuente |
|--------|---------|--------|
| source-integration | Vincula commits GitHub → tickets (`fix #42`) | mantisbt-plugins/source-integration |
| MantisKanban | Vista Kanban del backlog | mantisbt-plugins/MantisKanban |
| SetDuedate | SLA automático por prioridad | mantisbt-plugins/SetDuedate |
| Reminder | Alertas por ticket sin respuesta | mantisbt-plugins/Reminder |
| mailtemplate | Emails HTML con branding | mantisbt-plugins/mailtemplate |
| EventLog | Auditoría: login, tickets, config | mantisbt-plugins/EventLog |

**Qué he hecho yo:** configurar cada plugin para ResolveCore (SLA en horas
concretas, retención de logs 365 días, plantillas de email con la identidad
visual del proyecto). Los archivos de config personalizados están en
`mantisbt/plugins/<plugin>/config.php`.

---

## 3. WordPress y tema

### WordPress (CMS)

| Campo | Valor |
|-------|-------|
| Origen | Software libre de terceros |
| Licencia | GPL-2.0 |
| Fuente | https://wordpress.org |

Se usa WordPress.com Business como entorno de producción (SaaS) y
LocalWP como entorno de desarrollo local. No se ha modificado el core de WordPress.

### Tema ResolveCore (`wordpress/resolvecore-theme/`)

| Campo | Valor |
|-------|-------|
| Origen | **Creación propia** |
| Autor | Francisco Vidal Mateo |
| Asistencia IA | Sí — revisión de CSS y estructura PHP |

El tema es **código original** escrito desde cero. No se ha partido de ningún
tema hijo (child theme) ni plantilla premium. Se comenzó con un `style.css` vacío
y un `functions.php` mínimo, siguiendo la documentación oficial de WordPress
Theme Development.

**Decisiones de diseño propias:**
- Paleta dark: fondo `#0a0c10`, acento `#00e5a0` (verde terminal) — inspirada en
  terminales de desarrollo y la identidad visual de herramientas de ciberseguridad.
- Tipografía: `JetBrains Mono` para código, `Inter` para texto — elección personal
  del alumno por legibilidad y coherencia con el entorno técnico.
- Layout: `CSS Grid` y `Flexbox` sin frameworks externos (sin Bootstrap, sin Tailwind).
  Decisión deliberada para demostrar dominio del CSS nativo.
- Animaciones: `@keyframes` CSS puras, sin JavaScript de terceros.

**Páginas implementadas:** front-page, docs, changelog, contacto, header, footer.

La IA asistió en la detección de errores CSS (overflow en el layout con sidebar) y
en la revisión de seguridad PHP (sanitización de inputs con `sanitize_text_field()`).

---

## 4. Plugin WordPress: integración MantisBT (`wordpress/plugins/rc-mantisbt/`)

| Campo | Valor |
|-------|-------|
| Origen | **Creación propia** |
| Autor | Francisco Vidal Mateo |
| Asistencia IA | Sí — estructura del cliente REST y manejo de errores |

Plugin WordPress **original** que no existía previamente. Creado para resolver
una necesidad específica del proyecto: conectar el formulario de contacto de la
web con MantisBT sin soluciones intermedias.

**Componentes:**
- `rc-mantisbt.php` — Plugin principal: panel de configuración en Ajustes → MantisBT,
  registro de opciones (`rc_mantis_*`), sanitización y escaping WPCS-compliant.
- `includes/class-mantis-api.php` — Cliente REST para MantisBT 2.x:
  - `create_issue()`, `get_issue()`, `get_projects()`, `add_note()`, `attach_file()`.
  - Autenticación Bearer token. Manejo de errores via `WP_Error`.
  - Logging de respuestas HTTP no-2xx a `error_log()` para debug en producción.

**Por qué no usar un plugin existente:** no existe ningún plugin publicado en el
directorio oficial de WordPress que integre MantisBT vía REST API. Los que existen
usan SOAP (obsoleto) o el email gateway de MantisBT, que no permite campos personalizados.

---

## 5. Scripts de diagnóstico Windows (`scripts/windows/`)

| Campo | Valor |
|-------|-------|
| Origen | **Creación propia** |
| Autor | Francisco Vidal Mateo |
| Lenguaje | PowerShell 5.1+ |
| Asistencia IA | Sí — revisión de cmdlets WMI y estructura JSON |

`diagnostico.ps1` v4.1.0 — script original que recoge:
- CPU, RAM, disco, temperatura (WMI), red, servicios críticos.
- Software instalado (3 hives del registro: HKLM x64, HKLM x86, HKCU).
- Logs de errores del sistema (Event Log), estado Windows Update.
- Salida: JSON estructurado + informe HTML (generado desde plantilla).

`optimizacion.ps1` — script original con modo `--dry-run` y `--undo`.

**Fuentes consultadas** (no copiadas): documentación oficial Microsoft
(`learn.microsoft.com`), ejemplos de la comunidad PowerShell Gallery para
cmdlets específicos de WMI/CIM, adaptados y reescritos para ResolveCore.

---

## 6. Scripts de diagnóstico Linux/macOS (`scripts/linux/`, `scripts/macos/`)

| Campo | Valor |
|-------|-------|
| Origen | **Creación propia** |
| Autor | Francisco Vidal Mateo |
| Lenguaje | Bash (POSIX-compatible) |
| Asistencia IA | Sí — revisión de `set -uo pipefail` y captura granular de errores |

`diagnostico.sh` v3.2.0 — script original que recoge:
- CPU/RAM/disco via `/proc`, `df`, `free`.
- Servicios systemd, puertos abiertos (`ss`/`netstat`), journalctl.
- Temperatura (lm-sensors, SMART), GPU (pciutils/nvidia-utils) si disponibles.
- Salida JSON + HTML con inyección segura (fix S4: `<script type="application/json">`).

`optimizacion.sh` v3.2.0 — script original con `--dry-run` real (no simulado).

**Decisión técnica propia:** `set -uo pipefail` sin `-e` para permitir captura
granular de errores comando a comando, rellenando el JSON aunque un comando falle.
Con `-e` el script aborta antes de completar el diagnóstico.

---

## 7. Script de diagnóstico Android (`scripts/android/`)

| Campo | Valor |
|-------|-------|
| Origen | **Creación propia** |
| Autor | Francisco Vidal Mateo |
| Lenguaje | Bash (vía ADB — ejecutado en el host técnico) |
| Asistencia IA | Sí — comandos ADB y serialización JSON |

Script original que usa ADB (Android Debug Bridge) para recoger:
- Batería, almacenamiento, apps instaladas, conectividad Wi-Fi/datos.
- Versión Android, modelo, número de serie.
- Genera JSON + HTML en el host que ejecuta ADB (no en el dispositivo).

---

## 8. Scripts Python — reconocimiento de red y vulnerabilidades (`scripts/common/`)

| Campo | Valor |
|-------|-------|
| Origen | **Creación propia** con Hexagonal Architecture |
| Autor | Francisco Vidal Mateo |
| Lenguaje | Python 3.8+ — stdlib only (sin `pip install`) |
| Asistencia IA | Sí — patrón Hexagonal y manejo de APIs REST |

### `buscar_vulnerabilidades.py`
Consulta en tiempo real NVD (NIST), CISA KEV, OSV y EPSS-FIRST.
No almacena base de datos local — cada ejecución obtiene datos frescos.
Salida: JSON, HTML con chips de severidad, texto plano.

### `escaner_shodan.py` (adapter `adapters/shodan_rest.py`)
Cliente REST puro para la API de Shodan. Sin dependencia `pip install shodan`.
Descubre puertos abiertos y CVEs asociados a una IP pública.

### `escaner_nmap.py`
Wrapper sobre Nmap (debe estar instalado en el sistema).
Parsea salida XML de Nmap y la convierte a la estructura de dominio de ResolveCore.

**Arquitectura Hexagonal aplicada:**
```
domain/         → modelos (Host, Vulnerability, Service) — sin dependencias externas
ports/          → interfaces abstractas (HostIntelSource)
adapters/       → implementaciones concretas (shodan_rest.py, nmap_adapter.py)
```
Esta arquitectura permite añadir nuevas fuentes (VirusTotal, Censys) sin modificar
el dominio, siguiendo el patrón Strangler Fig (migración incremental).

---

## 9. Plantilla de informe HTML (`reports/informe.html`)

| Campo | Valor |
|-------|-------|
| Origen | **Creación propia** |
| Autor | Francisco Vidal Mateo |
| Asistencia IA | Sí — revisión de seguridad de inyección JSON |

Plantilla HTML + CSS + JS vanilla que consume el JSON generado por cualquiera
de los scripts de diagnóstico. Diseño coherente con la identidad visual de ResolveCore.

**Fix de seguridad S4 (mayo 2026):** el JSON se inyecta via
`<script type="application/json" id="rc-data">` y se parsea con `JSON.parse()`,
evitando que un valor que contenga `</script>` rompa el HTML. Identificado y
corregido durante el desarrollo — no es un problema teórico, es un caso real
que se reproduce con salidas de `lshw` en Linux.

---

## 10. Infraestructura Docker (`mantisbt/docker-compose.yml`)

| Campo | Valor |
|-------|-------|
| Origen | **Creación propia** basada en documentación oficial |
| Imagen MantisBT | `vimagick/mantisbt` (Docker Hub) |
| Imagen BD | `mysql:5.7` (Docker Hub oficial) |
| Asistencia IA | Mínima — revisión de variables de entorno |

El `docker-compose.yml` es configuración propia que orquesta dos servicios
(MantisBT + MySQL 5.7) en red interna (`mantis_net`) con volumen persistente.
Las imágenes son de terceros pero la orquestación y configuración son originales.

---

## 11. Documentación técnica (`docs/`)

| Campo | Valor |
|-------|-------|
| Origen | **Creación propia** |
| Asistencia IA | Sí — revisión de redacción y estructura |

Todos los documentos técnicos (`defensa-tfg.md`, `stack-tecnologico.md`,
`mantis-integration.md`, `schema-diagnostico.md`, etc.) han sido redactados por
el alumno. La IA ha asistido en la revisión de la coherencia y en la expansión
de secciones técnicas que el alumno ya había esbozado.

---

## Resumen de autoría

| Componente | Tipo | IA usada |
|------------|------|----------|
| MantisBT (core) | Tercero (GPL) | No |
| Plugins MantisBT | Terceros (GPL) | No |
| WordPress (core) | Tercero (GPL) | No |
| Tema ResolveCore | **Propio** | Revisión |
| Plugin rc-mantisbt | **Propio** | Revisión |
| diagnostico.ps1 | **Propio** | Revisión |
| optimizacion.ps1 | **Propio** | Revisión |
| diagnostico.sh (Linux/macOS) | **Propio** | Revisión |
| diagnostico.sh (Android/ADB) | **Propio** | Revisión |
| buscar_vulnerabilidades.py | **Propio** | Revisión |
| escaner_shodan.py | **Propio** | Revisión |
| informe.html | **Propio** | Revisión |
| docker-compose.yml | **Propio** | Mínima |
| Documentación | **Propia** | Revisión |

> **"Revisión"** = la IA detectó errores, sugirió mejoras o explicó APIs.
> El código fue escrito, entendido y adaptado por el alumno.
