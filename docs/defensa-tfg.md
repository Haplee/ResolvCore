# Defensa TFG — ResolveCore

> Documento maestro para la defensa del Trabajo Fin de Grado ASIR 2024/25.
> Plataforma cross-platform de mantenimiento y optimización remota.
> **Autor:** Francisco Vidal Mateo · **Tutor:** [pendiente] · **Fecha defensa:** [pendiente]

---

> ⚠️ **REGLA DE MANTENIMIENTO**
> Este documento es el **artefacto vivo** de la defensa. Cada vez que se añade o modifica una funcionalidad del proyecto, se actualiza la sección correspondiente aquí. No se mantiene en el commit final únicamente — se mantiene continuamente. Si un cambio no está reflejado en este fichero, no existe a efectos de la defensa.

---

## Tabla de contenidos

1. [Idea y motivación](#1-idea-y-motivación)
2. [Objetivos y alcance](#2-objetivos-y-alcance)
3. [Arquitectura general](#3-arquitectura-general)
4. [Flujo de servicio (7 fases)](#4-flujo-de-servicio-7-fases)
5. [Stack técnico](#5-stack-técnico)
6. [Módulo 1 — Diagnóstico multiplataforma](#6-módulo-1--diagnóstico-multiplataforma)
7. [Módulo 2 — Optimización del sistema](#7-módulo-2--optimización-del-sistema)
8. [Módulo 3 — Base de vulnerabilidades CVE](#8-módulo-3--base-de-vulnerabilidades-cve)
9. [Módulo 4 — MantisBT (tickets)](#9-módulo-4--mantisbt-tickets)
10. [Módulo 5 — Plugin WordPress de integración](#10-módulo-5--plugin-wordpress-de-integración)
11. [Módulo 6 — Tema WordPress (frontend público)](#11-módulo-6--tema-wordpress-frontend-público)
12. [Módulo 7 — Informe técnico PDF](#12-módulo-7--informe-técnico-pdf)
13. [Despliegue / Infraestructura](#13-despliegue--infraestructura)
14. [Seguridad y cumplimiento](#14-seguridad-y-cumplimiento)
15. [Modelo de negocio](#15-modelo-de-negocio)
16. [Decisiones de diseño justificadas](#16-decisiones-de-diseño-justificadas)
17. [Errores cometidos y aprendizajes](#17-errores-cometidos-y-aprendizajes)
18. [Demostración en vivo (guion)](#18-demostración-en-vivo-guion)
19. [Roadmap futuro](#19-roadmap-futuro)
20. [Bibliografía y referencias](#20-bibliografía-y-referencias)

---

## 1. Idea y motivación

### Problema detectado
Pequeñas empresas, autónomos y usuarios domésticos sufren degradación de sus equipos por mantenimiento inexistente: discos llenos, malware silencioso, vulnerabilidades CVE sin parchear, hardware al final de su vida útil sin diagnóstico previo. El soporte técnico tradicional es presencial, caro y reactivo (se actúa cuando ya falla).

### Propuesta de valor
ResolveCore = **soporte técnico remoto estructurado, trazable y automatizado** con tres pilares:

1. **Diagnóstico automatizado** sobre Windows/Linux/Android — JSON estructurado que alimenta informes y tickets.
2. **Análisis de vulnerabilidades** contra base CVE propia, sincronizada con NVD/NIST.
3. **Informe técnico PDF** entregable al cliente, con proyección de vida útil del hardware y recomendaciones.

### Eslogan
> "Solución a tus problemas informáticos."

### Justificación académica (ASIR)
El proyecto integra **todos los bloques curriculares del ciclo**:
- Sistemas operativos (Windows + Linux + Android)
- Redes y servicios de internet (VPS, nginx, REST)
- Bases de datos (MariaDB, schema CVE)
- Aplicaciones web (WordPress + plugin propio)
- Seguridad (CVE, headers HTTP, sanitización)
- Lenguajes de marcas y gestión de información (HTML/CSS/JSON)

---

## 2. Objetivos y alcance

### Objetivo principal
Construir una plataforma operativa que permita a un técnico:
1. Recibir solicitudes vía formulario web público.
2. Ejecutar diagnóstico automatizado en remoto sobre el equipo del cliente.
3. Cruzar resultado con base de vulnerabilidades.
4. Resolver y entregar informe técnico en PDF.
5. Facturar la intervención.

### Objetivos específicos
| ID | Objetivo | Estado |
|----|----------|--------|
| O1 | Scripts diagnóstico Windows (PowerShell 7) | ✅ Completado v3.2.0 |
| O2 | Scripts diagnóstico Linux (Bash) | ✅ Completado v3.1.0 |
| O3 | Scripts diagnóstico Android (Termux/ADB) | ✅ Completado v3.1.0 |
| O4 | Scripts diagnóstico macOS (stub demo) | ✅ Completado v0.1.0 |
| O5 | Schema JSON cross-platform unificado | 🟡 Documentado, falta migración Win |
| O6 | Plugin WP integración MantisBT | ✅ Completado |
| O7 | Tema WP landing pública | ✅ Completado v3.0.0 |
| O8 | Generador PDF informes | 🟡 Plantilla diseñada, no implementado |
| O9 | Base CVE sincronizada con NVD | 🟡 Schema definido, cron pendiente |
| O10 | Despliegue VPS productivo | 🔴 Pendiente |

### Fuera de alcance (declarado)
- App móvil nativa Android (queda como roadmap, no entregable TFG).
- iOS / macOS funcional (stub únicamente).
- Sistema de facturación electrónica completo (factura simple sí, no AEAT).
- IA / ML para predicción de fallos hardware (heurística sí, ML no).

---

## 3. Arquitectura general

```
┌─────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  Cliente final  │    │   Técnico        │    │   Admin/Tutor    │
│  (formulario)   │    │   (panel)        │    │   (auditoría)    │
└────────┬────────┘    └─────────┬────────┘    └────────┬─────────┘
         │ HTTPS               │ HTTPS                │
         ▼                       ▼                      ▼
┌────────────────────────────────────────────────────────────┐
│           VPS Linux  ·  nginx  ·  PHP-FPM  ·  MariaDB       │
│                                                              │
│  ┌─────────────┐   ┌─────────────┐   ┌──────────────────┐   │
│  │  WordPress  │──▶│  Plugin     │──▶│   MantisBT 2.27  │   │
│  │  (tema RC)  │   │  rc-mantisbt│   │   (REST API)     │   │
│  └─────────────┘   └─────────────┘   └──────────────────┘   │
│         │                  │                  │              │
│         │                  ▼                  ▼              │
│         │           ┌───────────────────────────────┐        │
│         └──────────▶│  rc_tickets / rc_vulnerabilities│      │
│                     │  rc_diagnostics (futuro)        │      │
│                     └───────────────────────────────┘        │
└──────────────────────────────────────────────────────────────┘
                                │
                  AnyDesk (acceso remoto al equipo del cliente)
                                │
                                ▼
                  ┌────────────────────────────────┐
                  │  Equipo cliente                │
                  │  · scripts/windows/*.ps1       │
                  │  · scripts/linux/*.sh          │
                  │  · scripts/android/*.sh (ADB)  │
                  └────────────────────────────────┘
```

### Capas
- **Presentación:** WordPress + tema custom `resolvecore-theme`.
- **Aplicación:** Plugin `rc-mantisbt` (PHP 8) + scripts diagnóstico.
- **Datos:** MariaDB (Mantis schema + tablas `rc_*` propias) + ficheros JSON locales.
- **Integración:** REST API MantisBT 2.x + AnyDesk (sesión remota).

---

## 4. Flujo de servicio (7 fases)

| # | Fase | Actor | Acción | Artefacto |
|---|------|-------|--------|-----------|
| 1 | Solicitud | Cliente | Rellena formulario en landing pública | POST AJAX `resolvecore_contact` |
| 2 | Ticket | Sistema | Crea issue en MantisBT vía REST | `issue_id` numérico |
| 3 | Conexión | Técnico | Acceso remoto al equipo (AnyDesk) | Sesión cifrada |
| 4 | Diagnóstico | Técnico | Ejecuta `diagnostico.ps1`/`.sh` | JSON estructurado |
| 5 | Resolución | Técnico | Aplica `optimizacion.*`, parches CVE | Logs + estado_previo (undo) |
| 6 | Informe PDF | Sistema | Genera PDF y lo adjunta al ticket | `informe_TICKET.pdf` |
| 7 | Facturación | Sistema | Factura por intervención o suscripción | Factura PDF |

Cada fase emite un **evento auditable**: log local en cliente, nota en ticket, fichero adjunto. Permite trazabilidad completa de la intervención.

---

## 5. Stack técnico

| Capa | Tecnología | Versión | Justificación |
|------|------------|---------|---------------|
| Frontend público | WordPress | 6.x | CMS con cuota >40% web, ecosistema masivo, hosting barato |
| Frontend tema | PHP + HTML5 + CSS3 + JS vanilla | — | Sin frameworks JS para minimizar bundle; tema 100% propio |
| Tickets | MantisBT | 2.27 | Open source, PHP, REST API completa, granularidad de roles |
| BD | MariaDB | 10.6+ | Drop-in MySQL, soporte UTF8MB4, licencia libre |
| Acceso remoto | AnyDesk | — | Cifrado TLS 1.2, sin VPN, multiplataforma |
| Diagnóstico Win | PowerShell | 7.0+ | Cross-platform, objetos, CIM/WMI nativo |
| Diagnóstico Linux | Bash | 4+ | Universal, `set -euo pipefail` para fail-fast |
| Diagnóstico Android | Bash + ADB / Termux | — | ADB sobre USB; Termux para acceso local sin root |
| PDF | wkhtmltopdf / DomPDF | — | HTML→PDF fiel, plantillas reusables (planificado) |
| Servidor | nginx + PHP-FPM | 1.24 / 8.2 | Performance > Apache para PHP, footprint bajo |
| Hosting | VPS Linux Ubuntu 22.04 LTS | — | LTS hasta 2027, Snap/APT, soporte amplio |

> Detalle completo: [`docs/stack-tecnologico.md`](stack-tecnologico.md).

---

## 6. Módulo 1 — Diagnóstico multiplataforma

### Windows (`scripts/windows/diagnostico.ps1` v3.2.0)
Recolecta:
- CPU: modelo, núcleos, carga (Get-CimInstance Win32_Processor reusado)
- RAM: total, en uso, % libre
- Disco: capacidad, libre, S.M.A.R.T (predicción fallo)
- Red: IPs, MACs, gateway, latencia
- Servicios críticos: estado y modo arranque
- Windows Update: parches pendientes
- Eventos: últimos errores System/Application
- Seguridad: Defender activo, firewall, BitLocker

Salida: JSON + HTML resumen. Exit codes 0/1/2.

### Linux (`scripts/linux/diagnostico.sh` v3.1.0)
- `top`/`uptime`/`free -h` → CPU, carga, RAM
- `df -h`, `lsblk`, `smartctl` → disco
- `journalctl -p 3` → errores recientes
- `dpkg -l` / `rpm -qa` → paquetes
- `ss -tulpn` → puertos abiertos
- `systemctl --failed` → servicios caídos

### Android (`scripts/android/diagnostico.sh` v3.1.0)
- ADB: `dumpsys battery`, `dumpsys meminfo`, `pm list packages`
- Termux: `getprop`, `df`, `top -n 1`
- Detección de apps con permisos peligrosos.

### macOS (stub `scripts/macos/diagnostico.sh` v0.1.0-demo)
Esqueleto CLI con `--host --user --port --output --dry-run --confirm`. Devuelve JSON placeholder con `_meta.stub: true`. **Decisión consciente:** la versión completa anterior contenía operaciones destructivas (`mdutil off`, `rm -rf ~/Library/Caches`, `networksetup -setdnsservers`) sin guardas — se redujo a stub hasta poder revisar a fondo.

### Schema JSON unificado
Documentado en [`docs/schema-diagnostico.md`](schema-diagnostico.md). Convenciones:
- Unidades: GB / MB / MHz / °C / ms
- Fechas: ISO-8601 UTC
- Valores desconocidos: `null` literal (nunca `"unknown"`)
- `_meta { version, plataforma, hostname, generado_en }` obligatorio

Pendiente: migrar Windows para que exponga hardware bajo `hardware {}` como Linux/Android (hoy lo expone en raíz).

---

## 7. Módulo 2 — Optimización del sistema

### Niveles
- `ligero`: limpieza temporales, sin tocar servicios.
- `estandar`: + desactiva BITS, WSearch.
- `rendimiento`: + DiagTrack, DPS.
- `extreme`: + SysMain.

### Servicio Spooler — exclusión durable
**NUNCA** se desactiva el servicio **Spooler (cola de impresión)** en ningún nivel. Decisión tomada tras feedback del usuario: muchos clientes finales tienen impresoras locales o de red; desactivar Spooler rompe impresión sin beneficio de rendimiento perceptible. Esta regla está fijada como memoria persistente del proyecto.

### Mecanismos de seguridad
- **Idempotencia:** todas las operaciones se pueden re-ejecutar sin cambio acumulado.
- **Snapshot estado_previo.json:** antes de modificar nada se guarda el estado actual (servicios + claves registro).
- **Backup .reg:** las modificaciones de registro Windows se exportan antes de aplicar.
- **Undo log:** `--undo` revierte cambios exactos basándose en el snapshot.
- **Confirmación explícita:** niveles `rendimiento` / `extreme` requieren `--confirm` para arrancar (regla CLAUDE.md: scripts destructivos requieren flag explícito).
- **Dry-run:** `--dry-run` muestra qué haría sin ejecutar.

### Bug crítico Android — corregido
La versión anterior (`scripts/android/optimizacion.sh` v3.0.0) usaba `pm clear $app` para "limpiar caché". `pm clear` borra **todos los datos de usuario** (sesiones, ficheros, configuraciones), no solo caché. Reemplazado por `pm trim-caches 1073741824` (1 GB cache trim, no destructivo). Lección: validar exhaustivamente comandos del sistema antes de incluirlos en producción.

---

## 8. Módulo 3 — Base de vulnerabilidades CVE

### Tabla `rc_vulnerabilities`
```sql
CREATE TABLE IF NOT EXISTS rc_vulnerabilities (
    id           BIGINT PRIMARY KEY AUTO_INCREMENT,
    cve          VARCHAR(20) UNIQUE NOT NULL,        -- CVE-2024-1234
    severity     ENUM('low','medium','high','critical') NOT NULL,
    cvss_score   DECIMAL(3,1),                       -- 0.0–10.0
    os_affected  SET('windows','linux','android','macos','cross'),
    description  TEXT,
    fix          TEXT,
    published_at DATETIME,
    updated_at   DATETIME ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_severity (severity),
    KEY idx_os (os_affected)
);
```

### Sincronización NVD
Cron semanal pendiente de implementar:
1. Descarga JSON feed NVD.
2. Parseo CVE-ID, CVSS, descripción.
3. Insert/Update idempotente (`ON DUPLICATE KEY UPDATE`).
4. Notificación email si nuevas críticas afectan SO desplegados.

### Consumo desde scripts diagnóstico
Los scripts comparan paquetes instalados (`dpkg -l`, `Get-HotFix`, `pm list packages`) contra `rc_vulnerabilities.os_affected` y emiten alertas en el JSON de salida bajo `vulnerabilidades_detectadas[]`.

---

## 9. Módulo 4 — MantisBT (tickets)

### Por qué MantisBT y no Jira/GitHub Issues/Redmine
| Criterio | MantisBT | Jira | GitHub Issues | Redmine |
|----------|----------|------|---------------|---------|
| Open source | ✅ | ❌ | ❌ (servicio) | ✅ |
| PHP/MySQL | ✅ | ❌ | ❌ | ❌ (Ruby) |
| REST API | ✅ | ✅ | ✅ | ✅ |
| Custom fields | ✅ | ✅ | ⚠️ labels | ✅ |
| Plugins | ✅ | ✅ ($) | ❌ | ✅ |
| Self-hosted gratuito | ✅ | ❌ | ❌ | ✅ |
| Workflow configurable | ✅ | ✅ | ⚠️ | ✅ |

MantisBT alinea stack (PHP + MariaDB), permite custom fields para datos del diagnóstico, y la REST API 2.x soporta issues + notes + files. Plugins instalados:
- `source-integration` (commits GitHub → tickets)
- `MantisKanban` (vista Kanban)
- `SetDuedate` (SLA por prioridad)
- `Reminder` (alertas tickets sin atender)
- `mailtemplate` (notificaciones HTML branded)
- `EventLog` (auditoría)

### Endpoints REST consumidos
| Método | Endpoint | Uso |
|--------|----------|-----|
| `POST` | `/api/rest/issues` | Crear ticket desde formulario |
| `GET`  | `/api/rest/issues/{id}` | Consultar estado |
| `POST` | `/api/rest/issues/{id}/notes` | Adjuntar resumen del diagnóstico |
| `POST` | `/api/rest/issues/{id}/files` | Subir JSON diagnóstico al ticket |
| `GET`  | `/api/rest/projects` | Verificación conexión / health-check |

Detalle completo: [`docs/mantis-integration.md`](mantis-integration.md).

---

## 10. Módulo 5 — Plugin WordPress de integración

### Estructura
```
wordpress/plugins/rc-mantisbt/
├── rc-mantisbt.php              # Bootstrap + helpers públicos
└── includes/
    └── class-mantis-api.php     # Cliente REST tipado
```

### Clase `RC_Mantis_API`
- **Constantes whitelist:** `PRIORITIES`, `SEVERITIES`, `MAX_DESCRIPTION=65000`, `MAX_SUMMARY=250`, `MAX_FILE_BYTES=5MB`.
- **Validación pre-request:** project_id ≥ 1, summary/description no vacíos, prioridad/severidad whitelisted, categoría fallback `General`.
- **UTF-8 forzado:** `wp_check_invalid_utf8()` + `wp_json_encode(..., JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)` — no rompe acentos en logs.
- **Métodos:**
  - `create_issue( array $data )` — crear ticket
  - `get_issue( int $id )` — consultar
  - `add_note( int $issue_id, string $text, string $view_state )` — comentario
  - `attach_file( int $issue_id, string $path )` — multipart manual (wp_remote_request no soporta uploads nativos)
  - `get_projects()` — health-check
- **Logs:** todo HTTP no-2xx → `error_log('[rc-mantisbt] ...')` con body truncado a 1000 chars.

### Helper `rc_mantis_attach_diagnostic()`
Validaciones encadenadas antes de subir:
| Comprobación | Error si falla |
|--------------|----------------|
| Fichero legible y no vacío | `rc_mantis_file_unreadable` |
| `json_decode` válido | `rc_mantis_json_invalid` |
| Esquema mínimo `_meta.plataforma`+`_meta.version` | `rc_mantis_schema_invalid` |
| Tamaño ≤ 5 MB | `mantis_file_too_large` |
| Token y URL configurados | `rc_mantis_no_config` |

Si falla la nota pero el adjunto subió → no se aborta (el JSON ya está en el ticket; el fallo de nota se loguea).

---

## 11. Módulo 6 — Tema WordPress (frontend público)

### `wordpress/resolvecore-theme/`
- `front-page.php` (1278 líneas) — landing pública one-page
- `index.php` — fallback mínimo
- `page-docs.php` — documentación técnica
- `page-changelog.php` — historial de versiones
- `style.css` — estilos compartidos docs/changelog
- `functions.php` — setup, hooks, AJAX form

### Mejoras aplicadas (último ciclo)
**`functions.php`:**
- `theme_supports` ampliado: html5, automatic-feed-links, responsive-embeds, nav menus
- Preconnect Google Fonts vía `wp_resource_hints` (mejora LCP)
- Suprime emojis, oEmbed, jQuery-migrate, wp-block-library/global-styles/classic-theme-styles
- Security headers en `send_headers`: X-Content-Type-Options, Referrer-Policy, Permissions-Policy, X-Frame-Options
- Defer JS no críticos vía filter `script_loader_tag`
- Rate limit IP-hash con `wp_salt('auth')` + `FILTER_VALIDATE_IP` (IPv6-safe)
- Whitelist tipos de consulta + límite 500 chars + `wp_unslash` en POST

**`front-page.php` (a11y + SEO + perf):**
- Skip-link `<a class="rc-skip-link">` + `<main id="main-content">` envolvente
- 6 `<div class="rc-section">` → `<section aria-label="...">` (landmarks ARIA)
- Hamburger: `aria-expanded`, `aria-controls`, label flips Abrir/Cerrar
- Mobile menu: `role="dialog"`, `aria-hidden`, cierre con tecla Esc
- Vuln spans → `<button type="button">` reales (focus + teclado nativo)
- `prefers-reduced-motion`: anula animaciones, oculta partículas/glow/cursor
- `:focus-visible` global con outline accent
- Meta: `theme-color`, `og:locale`, `twitter:image`, `og:image:alt`, `color-scheme`
- `esc_url()` + `esc_html()` + `esc_attr()` en todos los outputs
- Logo nav: `fetchpriority="high"`; logo footer: `loading="lazy"` + `alt=""` (decorativo)
- Footer envuelto en `<nav aria-label>` + `role="contentinfo"`
- Scroll handler con `requestAnimationFrame` + listener `passive: true`
- `date_i18n('Y')` localizado

### Lighthouse (objetivo y estado)
| Métrica | Antes | Después | Objetivo |
|---------|-------|---------|----------|
| Performance | ~75 | ~92 | ≥90 |
| Accesibilidad | ~78 | ~98 | ≥95 |
| SEO | ~85 | ~100 | 100 |
| Best Practices | ~85 | ~95 | ≥90 |

(Mediciones a confirmar tras despliegue VPS — local con DevKinsta.)

---

## 12. Módulo 7 — Informe técnico PDF

### Plantilla (diseño aprobado, implementación pendiente)
**Secciones obligatorias** (no se acortan por diseño del servicio):
1. Resumen ejecutivo
2. Ficha del equipo (modelo, SO, hardware)
3. Incidencias detectadas
4. Vulnerabilidades CVE encontradas + severidad
5. Acciones realizadas
6. Estado actual del sistema
7. Recomendaciones
8. **Proyección de vida útil del equipo** (heurística sobre S.M.A.R.T + edad CPU + GPU)
9. Anexo: log completo del diagnóstico

### Implementación prevista
- HTML plantilla → `wkhtmltopdf` o `DomPDF` (PHP nativo; menos dependencias).
- Datos inyectados desde JSON diagnóstico estructurado.
- Adjunto automático al ticket MantisBT al cerrar incidencia (vía `rc_mantis_attach_diagnostic` ya operativo para el JSON, mismo patrón para PDF).

---

## 13. Despliegue / Infraestructura

### VPS — análisis
Se evaluó hosting compartido vs VPS:
| Componente | ¿Hosting compartido suficiente? | ¿Requiere VPS? |
|------------|-------------------------------|----------------|
| WordPress + tema | ✅ | — |
| MantisBT | ⚠️ depende del provider | ✅ recomendado |
| Plugin rc-mantisbt | ✅ | — |
| Generador PDF (wkhtmltopdf) | ❌ binario no instalable | ✅ |
| Cron sync NVD | ⚠️ limitado | ✅ |
| AnyDesk session host | — | n/a (corre en cliente) |

**Conclusión:** se requiere VPS para wkhtmltopdf + cron + control total nginx/PHP-FPM. Detalles: [`docs/anotaciones-tutor.md`](anotaciones-tutor.md) — apéndice glosario técnico.

### Opciones evaluadas
| Provider | Plan | Coste | Pros | Contras |
|----------|------|-------|------|---------|
| Oracle Free Tier ARM | 4 OCPU / 24 GB / siempre gratis | 0 € | Generoso, gratuito | Cuotas estrictas, ARM (compatibilidad PHP/wkhtmltopdf) |
| Hetzner CX11 | 2 vCPU / 2 GB / 20 GB | ~3,79 €/mes | Barato, fiable | Sin free tier |
| Contabo VPS S | 4 vCPU / 8 GB / 50 GB | ~4,50 €/mes | Mucho RAM/precio | Latencia variable |
| OVH VPS Starter | 1 vCPU / 2 GB | ~3,50 €/mes | Soporte español | Recursos limitados |
| WSL local | — | 0 € | Sin coste, control total | Sin URL pública (requiere ngrok) |

Decisión pendiente del tutor: ¿se exige URL pública para la defensa? Si no, WSL local es suficiente.

### Despliegue base (Ubuntu 22.04 LTS)
```bash
apt update && apt install -y nginx php8.2-fpm php8.2-{mysql,curl,gd,mbstring,xml,zip} \
                              mariadb-server wkhtmltopdf certbot python3-certbot-nginx
```
Servicios:
- `nginx` :80/:443 (reverse proxy + SSL Let's Encrypt)
- `php8.2-fpm` (socket Unix)
- `mariadb` :3306 local únicamente
- Cron: `cve-sync-weekly.sh`

---

## 14. Seguridad y cumplimiento

### Sanitización inputs
- WP REST: `sanitize_text_field()`, `sanitize_email()`, `sanitize_textarea_field()`
- POST: `wp_unslash()` antes de sanitizar
- Tipos de consulta: whitelist estricta
- AJAX nonce: `check_ajax_referer( 'resolvecore_contact', 'nonce' )`
- Honeypot anti-spam: campo oculto `rc_website`
- Rate limit: 3 envíos/IP/hora (transient + IP-hash con `wp_salt`)

### Headers HTTP
| Header | Valor | Propósito |
|--------|-------|-----------|
| `X-Content-Type-Options` | `nosniff` | MIME-sniffing prevent |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Privacidad referer |
| `Permissions-Policy` | `geolocation=(), microphone=(), camera=()` | Bloquea APIs sensibles |
| `X-Frame-Options` | `SAMEORIGIN` | Anti-clickjacking |

### Datos sensibles
- Tokens MantisBT: WP options (no hardcoded). Pendiente: cifrado at-rest con `wp_salt`.
- IPs de clientes: solo hash SHA-256 + salt (LOPD/GDPR-friendly para rate-limit).
- Logs diagnóstico: locales en cliente, transferidos vía sesión AnyDesk cifrada.

### Operaciones destructivas
- Scripts con flag `--confirm` obligatorio (regla CLAUDE.md: "scripts destructivos requieren `--confirm` explícito").
- Snapshot pre-cambio (`estado_previo.json`) + `--undo`.
- Backup `.reg` antes de modificar registro Windows.

---

## 15. Modelo de negocio

### Pago por servicio (B2C)
- Diagnóstico básico: gratis (atrae leads).
- Diagnóstico completo + informe PDF: 29 €.
- Resolución de incidencia: 49 €/hora.
- Generación de factura PDF al cerrar ticket en MantisBT.

### Suscripción (B2B / autónomos)
- Plan Pro: 4,99 €/mes — 3 dispositivos, Win+Linux, mantenimiento mensual.
- Plan Enterprise: 14,99 €/mes — ilimitados, todas las plataformas, BD CVE offline, panel multi-dispositivo.
- Cron de revisiones programadas + notificación email automática.

### Costes operativos estimados
| Concepto | Coste mensual |
|----------|---------------|
| VPS (Hetzner CX11) | 3,79 € |
| Dominio (.com) | ~1 €/mes (12 €/año) |
| Email transaccional (SMTP) | 0 € (Gmail SMTP relay free tier) |
| **Total** | **~5 €/mes** |

Punto de equilibrio: 1 cliente Pro mensual cubre infraestructura.

---

## 16. Decisiones de diseño justificadas

### Por qué WordPress
- **Audiencia objetivo** son pequeñas empresas y autónomos no-tech: WordPress = familiar.
- **Mantenimiento post-TFG**: stack PHP unificado, sin pipeline JS adicional.
- **SEO out-of-the-box** (sitemap, robots, schema vía plugins).
- **Hosting barato** universalmente disponible.
- **Stack ASIR**: PHP + MariaDB + Nginx demuestra contenidos del ciclo (administración web, BBDD, servicios en red).

### Por qué tema custom y no tema comercial
- Tamaño bundle: tema custom <50 KB CSS, comercial típicamente 500 KB+.
- Control total a11y (skip-link, ARIA, prefers-reduced-motion).
- Sin licencias propietarias.

### Por qué PowerShell 7 y no .ps1 clásico
- Cross-platform real (PowerShell Core corre en Linux/macOS).
- Sintaxis moderna (`??`, ternario, pipeline chain).
- Soporte oficial Microsoft a largo plazo.

### Por qué Bash (no Python) en Linux/Android
- **Cero dependencias**: cualquier distro tiene Bash; Python 3 no siempre.
- Scripts de diagnóstico = composiciones de comandos del sistema. Bash es lingua franca.
- `set -euo pipefail` + `command -v <tool> || exit 1` cubre fail-fast.

### Por qué REST y no GraphQL para MantisBT
- MantisBT 2.x trae REST nativo. GraphQL requeriría plugin extra no oficial.
- Casos de uso: 5 endpoints — REST es más que suficiente.

### Por qué stub para macOS
- Versión completa anterior contenía operaciones destructivas sin guardas (`mdutil off`, `rm -rf ~/Library/Caches`, `networksetup -setdnsservers`). Reducir a stub es **más honesto académicamente** que entregar código peligroso. Demo funcional CLI; implementación real queda como roadmap.

---

## 17. Errores cometidos y aprendizajes

> Sección importante para la defensa: muestra capacidad crítica.

| # | Error | Detección | Solución | Aprendizaje |
|---|-------|-----------|----------|-------------|
| 1 | `pm clear $app` en Android opt → borraba TODOS los datos de usuario | Revisión código antes de release | Reemplazar por `pm trim-caches 1073741824` | Validar comandos del sistema en sandbox antes de incluirlos |
| 2 | Linux opt: `--dry-run` y `--undo` declarados pero nunca parseados → código muerto | Auditoría manual | Añadir `while $#` argument parsing real | Tests de integración en scripts CLI |
| 3 | Windows diag: `Get-CimInstance Win32_OperatingSystem` llamado 2x en mismo script | Profiling tiempo ejecución | Reusar variable `$os` | Cachear consultas WMI/CIM caras |
| 4 | macOS opt destructivo sin `--confirm` (`mdutil off`, `rm -rf cache`) | Auditoría seguridad | Reducir a stub demo | Honestidad académica > apariencia funcional |
| 5 | Spooler en lista de servicios desactivados | Feedback usuario | Excluir de todos los niveles + memoria persistente | Optimización que rompe funcionalidad común = peor servicio |
| 6 | MantisBT 400 errors por enums inválidos en `priority`/`severity` | Pruebas integración | Whitelist + validación previa al request | Validar payload contra schema antes de hablar con APIs externas |
| 7 | UTF-8 roto en summary/notes con tildes | Pruebas con datos reales | `wp_check_invalid_utf8` + `JSON_UNESCAPED_UNICODE` | Configurar utf8mb4 en MariaDB no es opcional |

---

## 18. Demostración en vivo (guion)

### Material a tener listo
- Laptop con WSL Ubuntu + WordPress local (DevKinsta o `docker compose`)
- VPS con MantisBT 2.27 + plugin instalado y token válido
- Equipo Windows secundario para diagnóstico real
- Móvil Android con USB debugging activado y ADB en el laptop

### Guion (15 min)
1. **(2 min)** Mostrar landing pública — nav, hero, stats animados, hamburger en mobile.
2. **(2 min)** Lighthouse en directo: Performance/A11y/SEO/Best Practices ≥ 90.
3. **(2 min)** Rellenar formulario contacto → mostrar respuesta AJAX con `#TICKET_ID` → abrir ticket en MantisBT.
4. **(3 min)** Ejecutar `diagnostico.ps1` en el portátil Windows → mostrar JSON de salida → snippet HTML resumen.
5. **(2 min)** `rc_mantis_attach_diagnostic($id, $jsonpath)` desde wp-cli → mostrar adjunto + nota Markdown en el ticket.
6. **(1 min)** Mostrar tabla `rc_vulnerabilities` con CVEs cargados + matching contra paquetes detectados.
7. **(2 min)** `optimizacion.ps1 -Nivel rendimiento -DryRun` → mostrar plan; luego con `-Confirm` → mostrar `estado_previo.json` y servicios desactivados; finalmente `-Undo` → restaura.
8. **(1 min)** Cierre: roadmap, preguntas.

### Riesgos demo + mitigación
| Riesgo | Mitigación |
|--------|-----------|
| Sin internet en aula | VPS en localhost (Docker) + scripts grabados con `asciinema` como fallback |
| MantisBT cae | Screenshots de respaldo + JSON output cacheado |
| Lighthouse score baja | Pre-medir 1h antes con configuración limpia |
| WP form bloquea por rate-limit (3/hora) | Limpiar transient: `wp transient delete --all` antes de demo |

---

## 19. Roadmap futuro

### Corto plazo (post-defensa, antes de producción)
- [ ] Implementar generador PDF (wkhtmltopdf + plantilla HTML)
- [ ] Cron sync NVD operativo
- [ ] Migrar Windows diag para exponer hardware bajo `hardware {}` (alinear schema)
- [ ] Tests integración Mantis (PHPUnit) contra instancia local
- [ ] Despliegue VPS productivo + dominio + Let's Encrypt

### Medio plazo
- [ ] Panel admin WordPress para subir JSON diagnóstico vía UI
- [ ] App nativa Android (Kotlin + Jetpack Compose + Material 3) — comunicación con backend WP REST
- [ ] macOS diagnostico completo (sustituir stub)
- [ ] Notificaciones email branded vía SMTP transaccional
- [ ] Dashboard cliente: historial de diagnósticos + descargas PDF

### Largo plazo (post-TFG)
- [ ] Modelo predictivo ML para vida útil hardware (ML.NET / scikit-learn)
- [ ] Integración facturación electrónica AEAT (Verifactu)
- [ ] White-label: permitir a otros técnicos ofrecer ResolveCore con su marca
- [ ] Plugin Mantis nativo para visualizar diagnósticos sin descargar JSON

---

## 20. Bibliografía y referencias

### Documentación oficial
- [WordPress Plugin Handbook](https://developer.wordpress.org/plugins/)
- [WordPress Coding Standards](https://developer.wordpress.org/coding-standards/wordpress-coding-standards/)
- [MantisBT REST API](https://documenter.getpostman.com/view/29959/RVu8CTDL)
- [PowerShell 7 Documentation](https://learn.microsoft.com/en-us/powershell/)
- [NVD CVE Feeds](https://nvd.nist.gov/vuln/data-feeds)
- [Web Content Accessibility Guidelines (WCAG) 2.1 AA](https://www.w3.org/TR/WCAG21/)
- [Open Web Application Security Project (OWASP) Top 10](https://owasp.org/Top10/)

### Documentos internos del proyecto
- [`README.md`](../README.md) — instalación entorno local
- [`docs/stack-tecnologico.md`](stack-tecnologico.md) — justificación stack completa
- [`docs/schema-diagnostico.md`](schema-diagnostico.md) — esquema JSON cross-platform
- [`docs/mantis-integration.md`](mantis-integration.md) — integración MantisBT detallada
- [`docs/so-especializado.md`](so-especializado.md) — comparativa SO
- [`docs/anotaciones-tutor.md`](anotaciones-tutor.md) — notas para tutor + glosario VPS
- [`docs/informe-tutor-estado-proyecto.md`](informe-tutor-estado-proyecto.md) — estado entregable
- [`.claude/CLAUDE.md`](../.claude/CLAUDE.md) — convenciones de desarrollo

### Repositorios
- GitHub: <https://github.com/Haplee/ResolveCore>

---

## Changelog del documento

| Fecha | Cambio |
|-------|--------|
| 2026-05-07 | Creación inicial. Cubre módulos 1-7, decisiones, errores, guion demo, roadmap. Estado proyecto al cierre de ciclo "mejoras tema WP + integración JSON↔Mantis". |
| 2026-05-07 | Sección 16: eliminadas referencias a stack previo (React/Vue/SPA). Justificación WordPress reescrita en positivo (audiencia, mantenimiento, SEO, hosting, ASIR). Sincroniza con docs/stack-tecnologico.md. |
| 2026-05-07 | README.md reescrito: índice, badges ampliados (MantisBT/PowerShell/Bash/Lighthouse), instalación vía zip oficial, troubleshooting WP, sección plugins separada, tabla docs, módulos ASIR con descripción concreta, footer con autor unificado. |
