# Defensa TFG — ResolveCore

> Documento maestro para la defensa del Trabajo Fin de Grado ASIR 2024/25.
> Plataforma cross-platform de mantenimiento y optimización remota.
> **Autor:** Francisco Vidal Mateo · **Tutor:** [Juan Carlos] · **Fecha defensa:** [JUNIO]

---

> ⚠️ **REGLA DE MANTENIMIENTO**
> Este documento es el **artefacto vivo** de la defensa. Cada vez que se añade o modifica una funcionalidad del proyecto, se actualiza la sección correspondiente aquí. No se mantiene en el commit final únicamente — se mantiene continuamente. Si un cambio no está reflejado en este fichero, no existe a efectos de la defensa.

> 🔄 **ESTADO DEL ÁRBOL (2026-05-31, tras auditoría A11).**
> El commit `12890ac` borró 44 ficheros fuente; se restauró lo esencial + indispensable.
> **SÍ en el árbol actual** (restaurado desde `12890ac^`): los scripts Python en capas
> (sin clases) `scripts/common/{domain,ports,adapters}` + `escaner_nmap.py`/`generar_informe.py`/
> `generar_factura.py`/`adjuntar_informe_mantis.py`, la migración
> `vulnerabilities/migrations/0001_init.sql`, los **launchers** `ResolveCore.{sh,ps1}`
> (Linux/Android/Windows) y `scripts/servicios/` (congelación/clonación/kit, **source**).
> **NO en el árbol (siguen en histórico, recuperables):** `scripts/macos/`,
> `scripts/setup/`, el binario `scripts/servicios/kit/anydesk.exe` (7.9 MB — no se
> versiona, lo aporta el técnico) y `scripts/server/setup-mail-dkim.sh` (superado por
> `setup-mail-ionos.sh`). Lo no presente se marca **[ROADMAP]**/**[EN HISTÓRICO]**.
> Ver `docs/defensa/auditoria-mejoras.md` §8.

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
15b. [Servicios adicionales — scripts operativos](#15b-servicios-adicionales--scripts-operativos)
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
| O1 | Scripts diagnóstico Windows (PowerShell 5.1+) | ✅ Completado v4.0.0 |
| O2 | Scripts diagnóstico Linux (Bash) | ✅ Completado v3.0.0 |
| O3 | Scripts diagnóstico Android (Termux/ADB) | ✅ Completado v2.1.0 |
| O4 | Scripts diagnóstico macOS (stub demo) | 🟡 ROADMAP — stub borrado en `12890ac`, en histórico |
| O5 | Schema JSON cross-platform unificado | ✅ Completado — Windows migrado a `hardware {}` v4.0.0 |
| O6 | Plugin WP integración MantisBT | ✅ Completado |
| O7 | Tema WP landing pública | ✅ Completado v3.0.0 |
| O8 | Generador PDF informes | ✅ Completado — `reports/generate-report.php` + wkhtmltopdf |
| O9 | Base CVE sincronizada con NVD | 🟡 Schema definido, cron pendiente |
| O10 | Despliegue VPS productivo | 🟡 Scripts listos (`deploy-ionos.sh` + `upload-to-vps.ps1`), pendiente ejecución |
| O11 | Servicio congelación de sistemas (Windows + Linux) | ✅ Completado — `scripts/servicios/congelacion/` (restaurado) |
| O12 | Servicio clonación (registro + verificación de imágenes) | ✅ Completado — `scripts/servicios/clonacion/` (restaurado) |
| O13 | Kit de implantación en cliente (paquete AnyDesk + scripts) | ✅ Completado — `scripts/servicios/kit/construir-kit.ps1` (binario `anydesk.exe` no versionado, lo aporta el técnico) |

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
│  │  WordPress  │──▶│  Plugin     │──▶│   MantisBT 2.28  │   │
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

> 📸 **Evidencia:** Capturas demostrativas de la integración con el sistema de tickets se encuentran en `docs/capturas/20-05-MantisBT/`.

---

## 5. Stack técnico

| Capa | Tecnología | Versión | Justificación |
|------|------------|---------|---------------|
| Frontend público | WordPress | 6.x | CMS con cuota >40% web, ecosistema masivo, hosting barato |
| Frontend tema | PHP + HTML5 + CSS3 + JS vanilla | — | Sin frameworks JS para minimizar bundle; tema 100% propio |
| Tickets | MantisBT | 2.28.1 | Open source, PHP, REST API completa, granularidad de roles |
| BD | MariaDB | 10.6+ | Drop-in MySQL, soporte UTF8MB4, licencia libre |
| Acceso remoto | AnyDesk | — | Cifrado TLS 1.2, sin VPN, multiplataforma |
| Diagnóstico Win | PowerShell | 5.1 (target) / 7+ (opt-in) | 5.1 viene en Win 10/11 — sin fricción para el técnico. 7+ solo en scripts que requieren `ForEach-Object -Parallel` u operadores PS7 |
| Diagnóstico Linux | Bash | 4+ | Universal, `set -uo pipefail` (omite `-e` para captura granular comando a comando) |
| Diagnóstico Android | Bash + ADB / Termux | — | ADB sobre USB; Termux para acceso local sin root |
| PDF | wkhtmltopdf / DomPDF | — | HTML→PDF fiel, plantillas reusables (planificado) |
| Servidor | nginx + PHP-FPM | 1.24 / 8.2 | Performance > Apache para PHP, footprint bajo |
| Hosting | VPS Linux Ubuntu 22.04 LTS | — | LTS hasta 2027, Snap/APT, soporte amplio |

> Detalle completo: [`docs/stack-tecnologico.md`](../tecnica/stack-tecnologico.md).

---

## 6. Módulo 1 — Diagnóstico multiplataforma

### Windows (`scripts/windows/diagnostico.ps1` v4.0.0)
Recolecta:
- CPU: modelo, núcleos, carga (Get-CimInstance Win32_Processor reusado)
- RAM: total, en uso, % libre
- Disco: capacidad, libre, S.M.A.R.T (predicción fallo)
- Red: IPs, MACs, gateway, latencia
- Servicios críticos: estado y modo arranque
- Windows Update: parches pendientes
- Eventos: últimos errores System/Application
- Seguridad: Defender activo, firewall, BitLocker

Salida: JSON (v4.0.0 — todos los datos hardware bajo `hardware {}`) + HTML resumen. Exit codes 0/1/2.

### Linux (`scripts/linux/diagnostico.sh` v3.0.0)
- `top`/`uptime`/`free -h` → CPU, carga, RAM
- `df -h`, `lsblk`, `smartctl` → disco
- `journalctl -p 3` → errores recientes
- `dpkg -l` / `rpm -qa` → paquetes
- `ss -tulpn` → puertos abiertos
- `systemctl --failed` → servicios caídos

### Android (`scripts/android/diagnostico.sh` v2.1.0)
- ADB: `dumpsys battery`, `dumpsys meminfo`, `pm list packages`
- Termux: `getprop`, `df`, `top -n 1`
- Detección de apps con permisos peligrosos.

### macOS (stub `scripts/macos/diagnostico.sh` v0.1.0-demo) — **[EN HISTÓRICO]**
> Borrado en `12890ac`; no está en el árbol actual. Recuperable de histórico. Descrito aquí como trabajo realizado y roadmap.

Esqueleto CLI con `--host --user --port --output --dry-run --confirm`. Devuelve JSON placeholder con `_meta.stub: true`. **Decisión consciente:** la versión completa anterior contenía operaciones destructivas (`mdutil off`, `rm -rf ~/Library/Caches`, `networksetup -setdnsservers`) sin guardas — se redujo a stub hasta poder revisar a fondo.

### Schema JSON unificado
Documentado en [`docs/schema-diagnostico.md`](../scripting/schema-diagnostico.md). Convenciones:
- Unidades: GB / MB / MHz / °C / ms
- Fechas: ISO-8601 UTC
- Valores desconocidos: `null` literal (nunca `"unknown"`)
- `_meta { version, plataforma, hostname, generado_en }` obligatorio
- Todas las plataformas exponen los datos de hardware bajo `hardware {}` (Windows migrado en v4.0.0)

Pendiente: actualizar template `reports/informe.html` para leer de `hardware.*` en vez de raíz del JSON.

> 📸 **Evidencia:** Capturas de ejecución de los scripts de diagnóstico están disponibles en `docs/capturas/18-05-Scripting/`.

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

## 8. Módulo 3 — Vulnerabilidades CVE (`buscar_vulnerabilidades.py` v1.0)

### Decisión arquitectónica

Módulo unificado en **Python 3.8+ stdlib** (sin pip, sin requirements.txt) que vale para los 4 SO. Evita duplicar lógica CVE en PowerShell + Bash + Bash + Bash. El script (`scripts/common/buscar_vulnerabilidades.py`) **sí está** en el árbol actual y se ejecuta directamente. Se invoca además como **opción 3** del menú `ResolveCore` en cada plataforma; los launchers `ResolveCore.{sh,ps1}` (Linux/Android/Windows, restaurados tras A11) auto-instalan Python via scoop/choco/apt/dnf/brew.

**Política open source estricta (defendible):**

| ✅ Permitido | ❌ Rechazado |
|---|---|
| Scoop (MIT), Chocolatey (Apache 2.0) | winget, Microsoft Store |
| apt / dnf / pacman / brew | Snap, Mac App Store |
| smtplib + msmtp (GPL) | MAPI, Outlook COM |
| NIST NVD / CISA KEV / OSV / EPSS | Nessus, Qualys, Snyk, Tenable |
| Python stdlib | Cualquier dep pip/pnpm |

### Pipeline (16 clases, ~1700 líneas)

```
PlatformDetector → inventario SW + servicios + OS
        ↓
CISAKEVCache → feed CISA KEV (~1589 CVEs explotados activamente)
        ↓
WhitelistManager → excepciones aceptadas con caducidad
        ↓
VulnScanner → NVD (3 intentos: keyword+ver, keyword, virtualMatchString CPE)
            + OSV (paralelo, threading)
            + EPSS (probabilidad explotación 30 días)
        ↓
ConfigAuditor → audita config local (UAC, SMBv1, RDP NLA, SSH, UFW, ASLR, ...)
        ↓
NetworkScanner → 12 puertos riesgo (Telnet/FTP/SMB/RDP/Redis/Mongo)
        ↓
LogAnalyzer → IOCs (BruteForce SSH, Event 4625, crons sospechosos)
        ↓
DepsScanner (--scan-deps) → requirements.txt, package.json contra OSV
        ↓
RemediationEngine → corrección automática:
    - Win: scoop / chocolatey
    - Linux: apt / dnf / pacman
    - macOS: brew
    - Android: lista manual al técnico
        ↓
RiskScorer → score 0-100 con desglose línea a línea
        ↓
HistoryManager → guarda histórico, compara con escaneo previo (--compare)
        ↓
ReportGenerator → JSON + TXT (estructurado) + HTML (gauge SVG, chips, banner)
        ↓
Notifier → SMTP (smtplib, msmtp fallback, .eml si todo falla)
        ↓
MantisBTClient → crea ticket REST + adjunta JSON + nota Markdown
        ↓
MultiHostRunner (--hosts) → ejecuta en N máquinas vía SSH (script base64 embebido)
```

### Fuentes públicas auditables

| API | Licencia | Uso |
|-----|----------|-----|
| **NIST NVD 2.0** | Pública USG | Catálogo CVE + CVSS v3.1/v3.0/v2.0 |
| **CISA KEV** | Dominio público | CVEs explotados activamente |
| **OSV.dev** (Google) | Apache 2.0 | Vulns por ecosistema (PyPI/pnpm/Maven/Go) |
| **EPSS FIRST.org** | Pública | Probabilidad explotación 30 días |

CVSS = gravedad estática. EPSS = urgencia real. KEV = ya está siendo explotado *ahora*. La combinación de las tres aporta señal mucho más útil que solo CVSS.

### Normalización inteligente de inventario

Sistema típico Windows: 181 entradas en registro Uninstall. Sin filtrar = ruido total + 0 matches NVD (los nombres en español/edición no coinciden con CPE).

```python
SOFTWARE_NOISE_PATTERNS    # descarta updates/hotfixes/SDKs/redists
SOFTWARE_KEYWORD_MAP       # "Microsoft Visual C++ 2013" → "vcredist 2013"
                           # "Eclipse Temurin JDK con Hotspot" → "openjdk"
                           # "Oracle VirtualBox 7.2.8" → "virtualbox"
dedupe_software()          # agrupa duplicados x86/x64, queda versión más alta
```

Tres intentos NVD por SW: keyword+versión corta → keyword solo → `virtualMatchString` CPE-like. Versión normalizada a `MAJOR.MINOR` (más matches).

### RiskScore con desglose

```
Base: 100
- CVE CRITICAL: -15      - CVE HIGH: -8       - CVE MEDIUM: -3
- CVE en KEV: -20 extra  - Config CRITICAL FALLO: -20
- Config HIGH FALLO: -10 - Config MEDIUM FALLO: -4
- Puerto CRITICAL: -8    - Puerto HIGH: -5    - Puerto MEDIUM: -3
- IOC HIGH: -25          + Remediación aplicada: +5 c/u
Clasificación: 80-100 BUENO | 50-79 MEJORABLE | 0-49 CRÍTICO
```

El JSON expone `score_desglose[]` con cada línea de penalización para auditoría: `"-20 CVE en CISA KEV: CVE-2024-1234"`. El HTML lo muestra en `<details>` desplegable.

### Informes generados

**TXT estructurado** — secciones: identificación equipo, score con barra ASCII, resumen ejecutivo, CVEs detallados, auditoría config, puertos, IOCs, comparativa histórica, acciones priorizadas numeradas, mensaje cliente personalizado, próxima revisión recomendada (7d crítico / 30d mejorable / 90d bueno).

**HTML autocontenido** — paleta corporativa idéntica a `informe.html` (mismas CSS vars `--bg`, `--accent`, `--red`, etc.), gauge SVG circular, chips de severidad (KEV/CRITICAL/HIGH/MEDIUM), banner del mensaje cliente coloreado por nivel, desglose del score desplegable, tablas con filas coloreadas por severidad, sección IOCs/dependencias/comparativa condicionales, footer con versión.

**JSON** — incluye `_meta.version/plataforma/hostname` (schema MantisBT del proyecto), `por_severidad`, `score_desglose`, `duracion_segundos`, `proxima_revision`, `excepciones_activas`.

### Mensaje cliente personalizado

`build_client_message()` construye el texto adaptado a hallazgos reales:
- KEV detectados → "se han detectado N vulnerabilidades en explotación activa…"
- CRITICAL → "hay N CVEs de severidad crítica…"
- Configs fallidas → "configuración insuficiente en: Defender, SMBv1…"
- Puertos abiertos → "servicios sensibles expuestos en red: 445 (SMB)…"
- IOCs → "indicadores de compromiso en logs…"

### CLI completa

```
--dry-run --no-fix       Solo detectar, no corregir
--silent --verbose       Modo CI / debug
--compare                Diff contra último escaneo
--output <dir>           Directorio salida
--report-html            Generar HTML adicional
--notify <email>         Email vía SMTP (smtplib + fallbacks)
--mantis-ticket          Crear ticket REST en MantisBT
--mantis-url --mantis-token   Override de .env
--platform <W|L|A|M>     Forzar plataforma
--min-score <N>          Umbral CVSS (default 7.0)
--serial <id>            Serial ADB Android
--whitelist-add <CVE>    Añadir excepción
--whitelist-list         Listar excepciones activas
--whitelist-expire       Listar caducadas
--hosts <fichero>        Multihost SSH/ADB
--scan-deps              Escanear dependencias proyecto (lento, opt-in)
--no-net-scan --no-logs --no-config   Saltar fases
```

### Tabla histórica `rc_vulnerabilities` (BBDD MariaDB - sincronización futura)

```sql
CREATE TABLE IF NOT EXISTS rc_vulnerabilities (
    id           BIGINT PRIMARY KEY AUTO_INCREMENT,
    cve          VARCHAR(20) UNIQUE NOT NULL,
    severity     ENUM('low','medium','high','critical') NOT NULL,
    cvss_score   DECIMAL(3,1),
    os_affected  SET('windows','linux','android','macos','cross'),
    description  TEXT,
    fix          TEXT,
    published_at DATETIME,
    updated_at   DATETIME ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_severity (severity),
    KEY idx_os (os_affected)
);
```

Pendiente: cron semanal que vuelque `vuln_history.json` a esta tabla para vista global del parque de equipos del cliente.

### Defensa académica

| Competencia | Demostración |
|-------------|--------------|
| **Programación** | 16 clases Python, threading, context managers, decoradores |
| **Seguridad** | CVE / CVSS / EPSS / KEV / hardening / IOC detection |
| **Redes** | HTTP REST (NVD/OSV/EPSS), socket port scan, SSH multihost |
| **SO multiplataforma** | winreg / dpkg-rpm-pacman / brew / adb |
| **BBDD** | Schema CVE + integración MantisBT REST |
| **Calidad** | Try/except por fase, timeouts, rate limiting, fallbacks SMTP |

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

Detalle completo: [`docs/mantis-integration.md`](../tecnica/mantis-integration.md).

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
- `front-page.php` — landing pública one-page
- `header.php` / `footer.php` — cabecera y pie compartidos por las páginas internas
- `index.php` — fallback mínimo
- `page-docs.php` — documentación técnica
- `page-changelog.php` — historial de versiones (4 releases reales: v0.9.0 → v1.2.0)
- `page-fleet-status.php` — panel público de estado de la flota
- `page-contacto.php` + páginas legales (aviso legal, privacidad, cookies)
- `style.css` — estilos compartidos de las páginas internas
- `functions.php` — setup, hooks, AJAX form, fallback de menús

### Navegación unificada
Antes existían dos sistemas de navegación distintos (la `front-page.php` con su nav propia y `header.php` con `wp_nav_menu`). Se unificaron: ambas comparten ahora la misma estructura y un menú desplegable **«Recursos»** (Documentación · Changelog · Estado de la flota). El desplegable funciona con hover (CSS) y con click/teclado (JS, `aria-expanded` + cierre con Esc). El menú de pie de página tiene `fallback_cb` para mostrar enlaces aunque no haya un menú configurado en `Apariencia → Menús`.

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

### Alta de cliente por correo (flujo actual)
> **Nota (2026-05-29):** la home **ya no crea tickets**. `resolvecore_send_client_confirmation()` fue eliminada (A7). El formulario público solo da de alta cuenta `rc_cliente` + email de activación y avisa al admin como *lead*. Los tickets se crean ahora exclusivamente desde el dashboard.

Al recibir el formulario, `resolvecore_handle_contact()` llama a `rc_crear_cuenta_cliente()` (plugin `rc-core`, idempotente por email): crea el usuario con contraseña aleatoria que **nunca se envía** y manda un correo HTML de activación con enlace «Fijar mi contraseña» (clave de reset nativa de WP, un solo uso, caduca). Canal no bloqueante: si `wp_mail()` falla solo se registra en el log. El tracker público de tickets (`resolvecore_handle_ticket_status` + token HMAC `?rc_ticket=N&rc_t=TOKEN`) se conserva como feature reutilizable desde el dashboard.

### Endurecimiento y mejoras (ciclo 2026-05-21)
- **Token anti-enumeración en el seguimiento de tickets.** El endpoint de estado recibía solo `?rc_ticket=N`, un identificador secuencial enumerable (un curioso podía probar 1, 2, 3… y ver fases/fechas de tickets ajenos — IDOR de baja gravedad: sin PII, pero indeseable). Se añadió un token HMAC-SHA256 derivado de `rc_ticket_<id>` con `wp_salt('auth')` (`resolvecore_ticket_token()`), truncado a 20 caracteres. Es **stateless**: no se almacena nada, se recalcula y se compara con `hash_equals()` (tiempo constante). El handler `resolvecore_handle_ticket_status()` rechaza la consulta sin token válido. El token viaja en el correo, en la respuesta AJAX (`ticket_token`) y en el `dataset.token` del enlace; el JS del modal lo reenvía en cada `fetchStatus(id, token)`.
- **Caché del endpoint público de la flota.** `rc_fleet_get_public_stats()` ejecutaba dos consultas de agregación en cada visita anónima. Ahora cachea el resultado en un transient (`rc_fleet_public_stats`, 5 min) y lo invalida (`delete_transient`) cuando un agente nuevo hace POST a `fleet/stats`. Plugin `rc-fleet` 0.2.1 → 0.2.2.
- **Entregabilidad de correo (SPF/DKIM/DMARC).** El correo de confirmación es inútil si cae en spam. Se añadió `scripts/server/setup-mail-dkim.sh` (instala y configura Postfix + OpenDKIM en el VPS, idempotente) y la guía `docs/tecnica/correo-dkim.md` con los tres registros DNS exactos para el panel de Ionos y la verificación con mail-tester.
- **Criterio de versionado unificado.** `docs/tecnica/versionado.md` documenta los cuatro flujos de versión del proyecto (tema, producto/changelog, plugins, esquema de diagnóstico), cuándo sube cada uno y dónde se duplica cada número.
- **Riesgo de dependencia documentado.** Cabecera de `reports/generate-report.php` advierte que wkhtmltopdf está archivado/sin mantenimiento desde 2023 y describe el plan de migración a DomPDF (librería PHP pura vía Composer, sin binario externo).
- **Checklist de verificación de permisos MantisBT.** `docs/tecnica/mantis-permisos.md` incorpora un smoke-test por rol (Informador / Desarrollador / Administrador) para validar la matriz de permisos tras aplicarla.
- **Correo saliente en producción — relay Ionos.** El despliegue real reveló que Ionos bloquea el puerto 25 saliente del VPS: el correo se quedaba en cola (`Connection timed out`). Se configuró Postfix para relayar autenticado por el smarthost `smtp.ionos.es:587` (buzón `tecnicos@`). El script `setup-mail-dkim.sh` ganó el flag `--relayhost` (configura relay + SASL, pide la contraseña de forma interactiva sin exponerla en la línea de comandos) y fija `myhostname`/`mydestination` para evitar el rebote `unknown user` de los buzones del dominio. `resolvecore_send_client_confirmation()` pasó a `multipart/alternative` (parte de texto plano además del HTML) con cabecera `List-Unsubscribe`. Verificado con mail-tester: SPF/DKIM/DMARC autenticados, sin blacklist, enlace de seguimiento con token HMAC operativo.

### Privacidad del cliente y claridad del flujo (ciclo 2026-06-02)
- **El cliente ya no accede a MantisBT.** El dashboard (`[rc_cliente_dashboard]`, plugin `rc-core`) mostraba en cada ticket un botón «Ver detalle en MantisBT» que abría `view.php?id=N` en el servidor de tickets — exponía la herramienta interna a un usuario que no tiene cuenta allí. Se sustituyó por un **indicador de progreso de 4 fases** (Recibido · En diagnóstico · En resolución · Resuelto) derivado del `status_id` del ticket, con el mismo mapeo que el tracker público (`resolvecore_handle_ticket_status()`). El cliente ve *en qué punto está* su incidencia sin ninguna referencia ni enlace a MantisBT. La descripción de la fase «Resuelto» en el tracker se reescribió («informe disponible en el historial de tu cuenta» en vez de «adjunto al ticket en MantisBT»).
- **Centrado del bloque de estadísticas del hero (definitivo).** El bloque `.rc-hero-stats` de la home seguía descuadrado pese a varios intentos. Causa: en `style.css` la regla de centrado solo aplicaba `justify-content: center !important`, que en un grid de columnas `1fr` no centra nada, mientras el CSS inline de `.rc-hero--split` quedaba sin reforzar. Se hizo el centrado a prueba de cascada: `justify-items` + `text-align` + `margin` auto con `!important`, independiente del orden de carga.
- **Flujo de datos de la home redescrito.** Los siete pasos de «El flujo de servicio» (`front-page.php`) describían acciones sueltas; ahora narran cómo viaja el dato (solicitud → incidencia con nº de seguimiento → diagnóstico JSON → el JSON se transforma en PDF → factura al cerrar) y se eliminó la marca «MantisBT» de la cara pública, dejándola como «incidencia».
- *Pendiente (follow-up):* el bloque de adjuntos del dashboard aún enlaza a `file_download.php` del servidor de tickets; requiere un proxy de descarga en WordPress para que el cliente baje el PDF sin cuenta en MantisBT.

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

### Plantilla + generador (implementado)

**Artefactos:**
- `reports/informe.html` — plantilla HTML autocontenida, paleta corporativa dark, gauges SVG circulares, score de salud, cards por módulo (CPU/RAM/disco/red/seguridad/batería), sección de recomendaciones priorizadas (crit/warn/ok). Normaliza JSON Windows v4.0.0 y Linux/macOS/Android.
- `reports/generate-report.php` — generador CLI:

```bash
# Generar PDF desde JSON de diagnóstico
php reports/generate-report.php --json scripts/diagnosticos/resultado.json

# Con ticket MantisBT y adjunto automático
php reports/generate-report.php \
    --json scripts/diagnosticos/resultado.json \
    --output informes/informe_TICKET42.pdf \
    --ticket 42 \
    --mantis-url https://mantis.resolvecore.es \
    --mantis-token <TOKEN>

# Variables de entorno alternativas
RC_MANTIS_URL=https://mantis.resolvecore.es \
RC_MANTIS_TOKEN=<TOKEN> \
php reports/generate-report.php --json diag.json --ticket 42
```

**Secciones del informe** (no se acortan por diseño del servicio):
1. Puntuaciones de salud (global, RAM, CPU, disco, batería) — gauges SVG
2. Ficha del equipo (hostname, SO, uptime, actualizaciones pendientes)
3. Procesador (modelo, núcleos, temperatura, carga)
4. Memoria RAM (total, disponible, % uso)
5. Almacenamiento (discos físicos, particiones, S.M.A.R.T, desgaste SSD)
6. Batería (carga actual, desgaste acumulado, ciclos)
7. Red (WiFi, latencia, pérdida de paquetes)
8. Seguridad (firewall, Defender, UAC, SELinux, FileVault, Gatekeeper, root, bootloader)
9. Recomendaciones priorizadas (críticas primero, con descripción accionable)

**Pipeline:**
1. `generate-report.php` lee el JSON diagnóstico y valida schema mínimo (`_meta.plataforma` + `_meta.version`).
2. Inyecta JSON en `<script type="application/json">` (con `<\/script>` escapado).
3. Llama a `wkhtmltopdf` para convertir el HTML renderizado a PDF A4.
4. Si se especifica `--ticket`, adjunta el PDF al ticket MantisBT vía REST API (`POST /api/rest/issues/{id}/files`).

**Decisión wkhtmltopdf vs DomPDF:** wkhtmltopdf renderiza el HTML idéntico al navegador (gauges SVG, CSS vars, grid), DomPDF no soporta SVG ni CSS custom properties de forma fiable. El VPS incluye wkhtmltopdf en el deploy script.

> 📸 **Evidencia:** Justificaciones y servicios documentados gráficamente en `docs/capturas/17-05-Servicios/`.

---

## 13. Despliegue / Infraestructura

### Entornos de desarrollo y producción
- **Desarrollo:** Aislado mediante *LocalWP* (NGINX + PHP 8.2 + MariaDB). Permite pruebas seguras de integración con MantisBT y simulación de correos vía MailHog.
- **Producción:** WordPress en subdominio `.com` y MantisBT planificado en VPS dedicado utilizando contenedor/raw.
- **Backup (DRC):** Política 3-2-1. `UpdraftPlus` en WordPress (frecuencia semanal/diaria) con destino a Google Drive. Copias manuales de BBDD (`mysqldump`) y archivos (`tar -czvf`) pre-despliegues críticos para MantisBT.

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

### Despliegue automatizado (implementado)

**Artefactos:**
- `scripts/server/deploy-ionos.sh` — script idempotente (re-ejecutable) que monta el stack completo en un VPS Ubuntu 24.04 LTS desde cero. 16 pasos: actualización del sistema → LEMP + wkhtmltopdf → usuario non-root → SSH hardening → UFW + fail2ban → swap 2 GB → MariaDB (DBs + usuarios) → WordPress core → `wp-config.php` (SALTs auto-generados) → tema + plugin desde repo → MantisBT 2.28.1 → nginx vhosts → PHP-FPM tuning → Let's Encrypt (con check DNS previo) → cron MantisBT.
- `scripts/server/upload-to-vps.ps1` — empaqueta el repo (tar.gz, excluye `.git`, `wp/`, `node_modules`) y lo sube al VPS vía `scp`, extrae en `/opt/resolvecore-source`.

**Flujo de despliegue:**
```powershell
# 1. Desde Windows local — subir código al VPS
.\scripts\server\upload-to-vps.ps1 -VpsHost resolvecore.es -User franvi

# 2. En el VPS — ejecutar deploy completo
bash /opt/resolvecore-source/scripts/server/deploy-ionos.sh \
    --domain resolvecore.es \
    --email  admin@resolvecore.es \
    --user   franvi \
    --ssh-pubkey "ssh-ed25519 AAAA..."
```

**Stack desplegado:**
- nginx :80/:443 — WordPress en `resolvecore.es`, MantisBT en `mantis.resolvecore.es`
- PHP-FPM 8.3 (pool `ondemand`, 8 workers, 256 MB, 25 MB upload)
- MariaDB local — `wp_resolvecore` + `mantisbt`
- Let's Encrypt — certbot auto-renew
- Swap 2 GB — crítico para VPS S con 2 GB RAM
- wkhtmltopdf — generación de informes PDF
- UFW + fail2ban — hardening perímetro

**Nota Ionos vs Ubuntu 22.04 vs 24.04:** el script se probó contra Ubuntu 24.04 LTS (PHP 8.3 disponible en repos oficiales). En 22.04 funcionaría con `PHP_VERSION="8.2"`.

> 📸 **Evidencia:** Capturas de la infraestructura y entornos se recogen en `docs/capturas/19-05-Entornos/`.

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

## 15b. Servicios adicionales — scripts operativos

> ℹ️ `scripts/servicios/` se restauró tras la auditoría A11 (source completo).
> Único elemento no versionado: el binario `kit/anydesk.exe` (7.9 MB), que aporta el
> técnico al construir el kit con `construir-kit.ps1`.

Tres servicios complementarios implementados en `scripts/servicios/`.
Justificación técnica completa: [`docs/tecnica/servicios-adicionales.md`](../tecnica/servicios-adicionales.md).

### Congelación de sistemas

| Plataforma | Script | Mecanismo |
|------------|--------|-----------|
| Windows | `congelacion/congelacion-windows.ps1` | Reboot Restore Rx Free (freeware PYME) / Deep Freeze (comercial) |
| Linux | `congelacion/congelacion-linux.sh` | BTRFS + snapper (GPL) sobre Ubuntu 22.04 LTS |

**Acciones Windows:** `Status` · `Configure` · `Freeze -Confirm` · `Thaw -Confirm`  
**Acciones Linux:** `status` · `configure` · `snapshot --etiqueta` · `rollback --confirm`

`Freeze`/`Thaw` y `rollback` exigen flag de confirmación explícito (operaciones destructivas — convención CLAUDE.md). Salida estructurada: `[PSCustomObject]` → JSON (Windows), JSON por stdout (Linux). Esquema documentado en [`docs/scripting/schema-servicios-adicionales.md`](../scripting/schema-servicios-adicionales.md).

### Clonación de sistemas

ResolveCore no automatiza Clonezilla (Live USB, fuera de alcance). Aporta **trazabilidad** sobre las imágenes generadas:

- `registrar-imagen.sh` — da de alta en `imagenes-manifest.json`: `id`, `equipo`, `so`, `estado`, `ruta`, `hash_sha256`, `fecha_registro`.  
- `verificar-imagen.sh` — recalcula SHA-256 y compara con el manifiesto. Exit codes: 0 íntegra · 1 corrupta · 2 no encontrada.

Hash de carpetas Clonezilla: hash determinista combinando hashes individuales ordenados (`find | sort | sha256sum`).

### Kit de implantación en cliente

`kit/construir-kit.ps1` empaqueta `resolvecore-kit/` + `resolvecore-kit.zip`:

```
resolvecore-kit/
├── anydesk-portable.exe
├── README-cliente.txt
└── scripts/
    ├── diagnostico-windows.ps1
    └── diagnostico-linux.sh
```

Genera `README-cliente.txt` con instrucciones no técnicas (conexión AnyDesk, diagnóstico, cláusula RGPD). Comprime con `Compress-Archive` (built-in PS 5.1+). Exit 2 si AnyDesk portable no encontrado.

### Modelo de precios asociado

| Servicio | Precio orientativo |
|----------|--------------------|
| Congelación (configuración + estado de referencia) | Incluido en Plan Pro mensual |
| Clonación (registro + verificación) | 19 € intervención puntual |
| Kit implantación (entrega única suscriptores) | Sin coste adicional en Plan Pro/Enterprise |

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

### Por qué MantisBT y no soluciones comerciales
- Licencia GPL, coste cero para entornos de producción en TFG frente a Jira.
- Soporte PHP + MariaDB, mismo ecosistema que el frontal WordPress, minimizando dependencias.
- REST API nativa soporta toda la gestión de tickets (creación, notas, subida de JSON diagnostico remoto).

### Por qué PowerShell 5.1 como target (no PS7)
- Windows 10/11 ship con 5.1 nativo: cero fricción para el técnico en sesión remota AnyDesk.
- Pedir PS7 obligaría a instalarlo en cada equipo cliente antes de poder ejecutar el script — coste innecesario para los casos de uso reales.
- PS7 se admite como opt-in cuando un script concreto necesita una capacidad PS7 (`ForEach-Object -Parallel`, ternario, `??`): se marca con `#Requires -Version 7.0` y se documenta en cabecera. Ejemplo: `scripts/iso/windows/setup.ps1`.
- Aviso de sintaxis: `#Requires` sin espacio entre `#` y `Requires`. Con espacio (`# Requires`) PowerShell lo ignora — sería un comentario inerte.

### Por qué Bash (no Python) en Linux/Android
- **Cero dependencias**: cualquier distro tiene Bash; Python 3 no siempre.
- Scripts de diagnóstico = composiciones de comandos del sistema. Bash es lingua franca.
- `set -uo pipefail` (omite `-e` deliberadamente) + `command -v <tool> || exit 1` cubre fail-fast sin abortar la captura granular de fallos comando a comando que rellena el JSON. `set -e` se reserva para scripts auxiliares cortos (`bootstrap-mantis.sh`).

### Por qué REST y no GraphQL para MantisBT
- MantisBT 2.x trae REST nativo. GraphQL requeriría plugin extra no oficial.
- Casos de uso: 5 endpoints — REST es más que suficiente.

### Por qué stub para macOS
- Versión completa anterior contenía operaciones destructivas sin guardas (`mdutil off`, `rm -rf ~/Library/Caches`, `networksetup -setdnsservers`). Reducir a stub es **más honesto académicamente** que entregar código peligroso. Demo funcional CLI; implementación real queda como roadmap.

### Por qué pnpm y no npm
- Recientemente (2026) se descubrió una vulnerabilidad crítica de escalada de privilegios local en la CLI de `npm` (CVE-2026-0775 en Windows) y un incremento notable en ataques a la cadena de suministro que aprovechan scripts post-install maliciosos en `npm`. 
- Se decidió migrar todas las referencias y el soporte en la detección de dependencias a `pnpm` por su enfoque más estricto con `node_modules` (uso de symlinks/hardlinks) que mitiga vectores de ataque basados en la manipulación de la resolución de módulos, y por un mejor manejo y aislamiento de las instalaciones.

> 📸 **Evidencia:** Las decisiones de diseño y otras justificaciones cuentan con respaldo visual en `docs/capturas/16-05-Justificaciones/`.

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
| 8 | Parseo de NVD API devolvía `cvss` como string en algunos registros | Testeo con CVEs variados | Try-except local con normalización forzada a `float` | Las respuestas de APIs externas nunca deben asumirse estandarizadas |

---

## 18. Demostración en vivo (guion)

### Material a tener listo
- Laptop con WSL Ubuntu + WordPress local (DevKinsta o `docker compose`)
- VPS con MantisBT 2.28.1 + plugin instalado y token válido
- Equipo Windows secundario para diagnóstico real
- Móvil Android con USB debugging activado y ADB en el laptop

### Guion (20 min)
1. **(2 min)** Mostrar landing pública — nav, hero, stats animados, hamburger en mobile.
2. **(1 min)** Lighthouse en directo: Performance/A11y/SEO/Best Practices ≥ 90.
3. **(2 min)** Rellenar formulario contacto → mostrar respuesta AJAX con `#TICKET_ID` → abrir ticket en MantisBT.
4. **(3 min)** Ejecutar `diagnostico.ps1` en el portátil Windows → mostrar JSON de salida → snippet HTML resumen.
5. **(2 min)** `adjuntar_informe_mantis.py --ticket <ID> --pdf informe.pdf` → mostrar adjunto + nota Markdown en el ticket.
6. **(1 min)** Mostrar tabla `rc_vulnerabilities` con CVEs cargados + matching contra paquetes detectados.
7. **(2 min)** `optimizacion.ps1 -Nivel rendimiento -DryRun` → mostrar plan; luego con `-Confirm` → mostrar `estado_previo.json`; finalmente `-Undo` → restaura.
> ℹ️ **Pasos 8-10:** `scripts/servicios/` está en el árbol (restaurado A11). Para el
> paso del **kit** (construir-kit) hace falta colocar `anydesk.exe` en `kit/` (no versionado).

8. **(2 min)** **Servicios adicionales — congelación Linux:**
   ```bash
   bash scripts/servicios/congelacion/congelacion-linux.sh --action=snapshot --etiqueta="estado-limpio"
   # → JSON: { "action": "snapshot", "snapshot_id": "6", ... }
   bash scripts/servicios/congelacion/congelacion-linux.sh --action=status
   # → lista snapshots snapper
   ```
9. **(2 min)** **Servicios adicionales — clonación:**
   ```bash
   bash scripts/servicios/clonacion/registrar-imagen.sh --imagen=/ruta/imagen.img --equipo=pc-cliente-01 --so=linux --estado=limpio
   # → actualiza imagenes-manifest.json con hash SHA-256
   bash scripts/servicios/clonacion/verificar-imagen.sh --imagen=/ruta/imagen.img
   # → exit 0 (íntegra) o 1 (corrupta)
   ```
10. **(2 min)** **Portal técnicos:** abrir `https://resolvecore.website/tecnicos/` — login con cuenta técnico (rol Editor) → mostrar botones de descarga: `install-servicios.ps1` / `install-servicios.sh` / `resolvecore-kit.zip` (servidos con HTTP Basic Auth desde nginx).
11. **(1 min)** Cierre: roadmap, preguntas.

### Riesgos demo + mitigación
| Riesgo | Mitigación |
|--------|-----------|
| Sin internet en aula | VPS en localhost (Docker) + scripts grabados con `asciinema` como fallback |
| MantisBT cae | Screenshots de respaldo + JSON output cacheado |
| Lighthouse score baja | Pre-medir 1h antes con configuración limpia |
| WP form bloquea por rate-limit (3/hora) | Limpiar transient: `wp transient delete --all` antes de demo |
| Congelación Linux sin BTRFS | Preparar salida JSON pre-grabada; el script puede ejecutarse en `--dry-run` modo de documentación |
| Portal técnicos — sesión expirada | Mantener pestaña de WP Admin abierta; re-login inmediato con credenciales técnico guardadas |
| Kit zip no subido al VPS | Tener `resolvecore-kit.zip` local; mostrar contenido con `Expand-Archive` en pantalla |

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
- [`README.md`](../../README.md) — instalación entorno local
- [`docs/stack-tecnologico.md`](../tecnica/stack-tecnologico.md) — justificación stack completa
- [`docs/schema-diagnostico.md`](../scripting/schema-diagnostico.md) — esquema JSON cross-platform
- [`docs/mantis-integration.md`](../tecnica/mantis-integration.md) — integración MantisBT detallada
- [`docs/tutorial-wordpress-manual.md`](../tecnica/tutorial-wordpress-manual.md) — tutorial manual de la web (LocalWP → tema → plugin → producción)
- [`docs/defensa-scripts-mantis.md`](defensa-scripts-mantis.md) — guion técnico de defensa: catálogo de los 17 scripts, integración MantisBT punta a punta, FAQ tribunal
- [`docs/so-especializado.md`](../tecnica/so-especializado.md) — comparativa SO
- [`docs/anotaciones-tutor.md`](anotaciones-tutor.md) — notas para tutor + glosario VPS
- [`docs/informe-tutor-estado-proyecto.md`](informe-tutor-estado-proyecto.md) — estado entregable
- [`.claude/CLAUDE.md`](../../.claude/CLAUDE.md) — convenciones de desarrollo

### Repositorios
- GitHub: <https://github.com/Haplee/ResolveCore>

---

## Changelog del documento

| Fecha | Cambio |
|-------|--------|
| 2026-06-03 | **Diagrama ER + favicon nítido + validación de scripts.** **(1) Modelo de datos**: añadido el diagrama entidad-relación de la BD de MantisBT (`mantisbt`) en `docs/ER/diagrama-er-mantisbt.{pdf,png,svg}`, generado por ingeniería inversa del esquema real (`mysqldump --no-data` → dbdiagram.io); indexado en `docs/INDEX.md`. **(2) Favicon MantisBT nítido**: el logo completo (trazos finos + contorno) se empastaba al reducirse a 16/32px; nueva variante simplificada `assets/logo/resolvcore-favicon.svg` (sin contorno, trazo grueso, fondo oscuro) + set `.ico`/PNG 16/32/180. `ResolveCoreBranding.php` (`favicon_link()`), `config_inc.php` (`$g_favicon_image = images/rc-favicon.ico`) y `mantis-branding.sh` apuntan al nuevo set. **(3) Validación de scripts**: chequeo estático de los 49 scripts → 0 errores (`bash -n` ×23, `py_compile` ×19, parser AST PowerShell ×7); BOM UTF-8 verificado en los 7 `.ps1` con no-ASCII. **(4) Limpieza VPS**: consolidación A4 (borrado de `/opt/resolvecore-git` y `/opt/resolvecore-source`, canónico `/opt/resolvecore-repo`). |
| 2026-06-02 (tarde, fixes) | **Correcciones tras prueba en producción.** **(1) Favicon MantisBT**: `ResolveCoreBranding.php` apunta ahora al icono cuadrado del tema (`assets/logo/resolvcore-icon.svg`+png) en vez del icono apaisado/deformado. **(2) Pie de Mantis**: nuevo JS `cleanFooter()` (+ respaldo CSS) que elimina "Powered by", "Copyright © … MantisBT Team" y "Contacta con el administrador por ayuda"; el único pie es `.rc-mantis-footer`. **(3) Login técnicos (`wp-login.php`)**: usaba el logo **oscuro sobre fondo oscuro** (invisible); cambiado a `resolvcore-logo-light.svg` + fondo con gradiente de marca + ancho de caja. **(4) Doble logout en dashboard cliente**: eliminado el botón del pie; queda solo el del hero. **(5) Email de alta**: el registro **con contraseña** no enviaba ningún correo (cuenta activa al instante, rama sin `wp_mail`); añadida `rc_cliente_email_bienvenida()` que envía confirmación HTML+texto con enlace al panel. **(6) CTA cliente del header**: "Mi panel" (link muerto/redundante) → **"Solicitar informe"** con deep-link `/dashboard/#solicitar` (el `<details>` del formulario recibe `id="solicitar"`). `php -l` limpio en los 5 ficheros. |
| 2026-06-02 (tarde) | **Arreglo integral del flujo del técnico (8 tareas, tras prueba real en Windows).** **(T1) Diagnóstico ampliado + resumen en terminal**: `diagnostico.ps1` (v2.0→**2.1**, +`-Silent`), `diagnostico.sh` (v3.0→**3.1**), `android/diagnostico.sh` (v2.1→**2.2**) ahora recogen muchos más datos reales (servicios críticos, top procesos CPU/RAM, red IP/GW/DNS/puertos, SMART, uptime/build, Defender/Firewall/UAC) e **imprimen un resumen legible** tras guardar el JSON. **`docs/scripting/schema-diagnostico.md` reescrito a la estructura PLANA real** de los scripts (el modelo v4 `hardware{}` que describía el doc — entrada 2026-05-12 — nunca se implementó en los scripts shipped; se documenta lo que de verdad producen). **(T2) Menú de desinstalación tras escaneo CVE**: `buscar_vulnerabilidades.py` gana `--salida-json`; los launchers Windows/Linux/Android leen ese JSON, filtran software con `kev=true` o `cvss≥7.0`, lo listan numerado y permiten desinstalar (`winget uninstall` / `apt-get|dnf remove` / `adb uninstall`) **solo con selección + confirmación explícita 'SI'**. Spooler/cups y componentes del sistema en lista de exclusión, nunca desinstalables. **(T3) Informe .txt**: fix mojibake `Nº`→`Nro.` (plantilla 100% ASCII), pre-rellenado desde el diagnóstico (incidencias derivadas por umbrales, estado actual, recomendaciones-checklist) + placeholders-guía `[...]`; nuevo `--ticket` y `--vuln-json`. Las 6 secciones obligatorias se mantienen. **(T4) Factura eliminada del launcher** (la gestiona MantisBT): menú renumerado 8→7 opciones en `ResolveCore.ps1`/`.sh`, help corregido (decía "HTML/PDF"), `generar_factura.py` queda para archivar en `_archivo/common/`. **(T5) Bug WSL clonación**: `Invoke-BashScript` usaba `-replace` con scriptblock + `$args[0]` (incorrecto: la variable del match es `$_`), provocando `parse error near )` en zsh; reemplazado por conversión explícita de ruta `C:\…`→`/mnt/c/…`. **(T6) Salidas por ticket**: `diagnostico.*` y `generar_informe.py` aceptan `--ticket <N>` y guardan en `reparaciones/<NNNNN>/` (base configurable con `RC_REPARACIONES_DIR`); los launchers piden el ticket **una vez al inicio**; sin ticket → `reparaciones/sin-ticket/` con timestamp + aviso; no sobrescribe (sufijo `_vN`); `reparaciones/` añadido a `.gitignore`. **(T7) Web**: hook `login_redirect` (técnico→`/tecnicos/`, cliente→`/dashboard/`), nav condicional por rol en `header.php` (cliente ve "Mi panel" y se le ocultan Docs/Changelog/Flota; técnico ve "Área de técnicos"), guard en `rc-core.php` para no modificar tickets `status≥30` + banner cuando hay ticket en `feedback` (20), botón de cerrar sesión mejorado (icono) y un 2º logout al pie del dashboard. **(T8) Responsive móvil**: footer (`.rc-footer-inner` recibe layout flex + media query que apila en columna — antes desbordaba a la derecha), `page-tecnicos.php` (barra de trabajo, grids y formularios a 1 columna <720px), y MantisBT desde `ResolveCoreBranding.php` (CSS responsive de tablas/inputs + JS que engancha el toggle del hamburguesa, que no abría). Validación: `bash -n`, `python -m py_compile`, parser PowerShell y `php -l` limpios en todos los ficheros tocados; `diagnostico.ps1 -Ticket 99999` probado end-to-end (JSON válido + resumen + ruta `reparaciones/99999/`). |
| 2026-06-01 | **Web — rediseño contacto/seguridad + UX cliente y MantisBT White-Label** (desplegado a `main` `1d43b8e` vía `sync-wp.sh`). **(1) Portada (`front-page.php`)**: hero stats centrados y simétricos (`grid repeat(4,1fr)` + `justify-items:center`, antes `repeat(4,auto)` desbalanceado). **Eliminado de raíz el formulario «Escríbenos»** (campos + JS `submitForm` + char-counter) y **desregistrado su handler AJAX** `resolvecore_handle_contact` (`functions.php`, hooks `wp_ajax[_nopriv]_resolvecore_contact` comentados) para mitigar saturación/DDoS contra `admin-ajax` (alta de cuenta + `wp_mail` sin login). Canales fusionados en **4 tarjetas de contacto directo** con icono SVG vectorial + hover-lift: Email `tecnicos@resolvecore.website`, GitHub `github.com/Haplee`, X `@FranVidalMateo`, Docs. Añadido **banner full-width** con CTA primario grande → `/registro/`. El nonce `rc_nonce` (que el modal de seguimiento de tickets reutiliza) se conserva como campo suelto para no romper el tracker. **(2) Registro (`[rc_registro_cliente]` / `style.css`)**: pestañas → toggle/segmented control (pill + sombra al activo), inputs con `padding .85rem 1rem` + `border-radius 8px`, auth-card centrada con sombra difuminada. **(3) Dashboard (`rc-core.php` / `style.css`)**: métricas → **píldoras** con color semántico (neutro=total, ámbar=en curso, verde=cerrados) con franja-acento lateral; `<details>` «Solicitar informe» reestilizado como módulo SaaS (icono que rota 45°, subtítulo, chevron animado, sombra al abrir); tickets ya en list-view con badge redondeado semántico. **(4) Área técnica (`page-tecnicos.php`)**: `wp_die()` gris nativo → 403 elegante que hereda header/footer del tema (`status_header(403)` + `get_header()/get_footer()`, tarjeta «403 · Acceso restringido» con botones a inicio/panel). **(5) MantisBT White-Label**: `mantisbt/config/config_inc.php` + nuevo `scripts/server/ops/mantis-branding.sh` (idempotente, `--apply`, backup) — `$g_logo_image='images/rc-logo-dark.png'`, `$g_window_title`, `$g_favicon_image`, `$g_copyright_statement=''`, `$g_show_version=OFF`, `$g_bottom_include_page` → `rc_footer.php` con CSS que oculta «Powered by MantisBT» + enlaces de soporte; logo oscuro copiado a la web-root de Mantis. En el VPS el branding se aplicó directo (append guardado con marcador `RC_BRANDING_BLOCK` a `config_inc.php` + `rc_footer.php` + `install` del logo). Vanilla CSS (sin Bootstrap/Tailwind), mobile-first, outputs escapados. `php -l` limpio en `functions.php`, `page-tecnicos.php`, `rc-core.php`, `config_inc.php`; `bash -n` limpio en `mantis-branding.sh`. Añadido `.vscode/settings.json` (stubs WordPress de Intelephense) para silenciar falsos positivos PHP0417/PHP0415 del language-server. |
| 2026-06-01 | **Scripts Python reescritos sin clases** (decisión del autor: el código debe entenderse sin orientación a objetos). En `scripts/common/` se quitaron todas las clases: `domain/models.py` ya no usa `@dataclass` — las entidades son **diccionarios** creados por funciones `nueva_vulnerabilidad()`/`nuevo_servicio()`/`nuevo_host()` y las reglas son funciones sueltas (`es_critica`, `contar_criticas`...). Los adapters dejan de ser clases: `nvd_rest.py` pasa de `class NvdRestAdapter` a la función `get_vulns(product, version, api_key=None)` y `nmap_local.py` de `class NmapLocalAdapter` a `get_host_info(ip, flags=None)`. Los `ports/` dejan de ser `Protocol` (PEP 544) y quedan como **contratos escritos en el docstring** (qué función debe ofrecer cada adapter). Fuera también los type hints (`typing`, `-> dict`) y nombres de variables a español, para casar con el estilo de `buscar_vulnerabilidades.py`. Compila limpio, salida JSON idéntica (mismas claves). Docs sincronizadas: `arquitectura-scripting.md` §6 (antes "Hexagonal / Ports & Adapters" con clases) y `origen-componentes.md` §8 reescritas a la versión sin clases; banner del árbol actualizado. `_archivo/` (código archivado) no tocado. |
| 2026-05-07 | Creación inicial. Cubre módulos 1-7, decisiones, errores, guion demo, roadmap. Estado proyecto al cierre de ciclo "mejoras tema WP + integración JSON↔Mantis". |
| 2026-05-07 | Sección 16: eliminadas referencias a stack previo (React/Vue/SPA). Justificación WordPress reescrita en positivo (audiencia, mantenimiento, SEO, hosting, ASIR). Sincroniza con docs/stack-tecnologico.md. |
| 2026-05-07 | README.md reescrito: índice, badges ampliados (MantisBT/PowerShell/Bash/Lighthouse), instalación vía zip oficial, troubleshooting WP, sección plugins separada, tabla docs, módulos ASIR con descripción concreta, footer con autor unificado. |
| 2026-05-08 | Módulo 3 reescrito al completo: nuevo `scripts/buscar_vulnerabilidades.py` v1.0 (~1700 líneas, Python stdlib). 16 clases, integra NVD + CISA KEV + OSV + EPSS, ConfigAuditor multi-SO, NetworkScanner, LogAnalyzer (IOCs), DepsScanner, RemediationEngine (scoop/choco/apt/dnf/brew), HistoryManager con --compare, MantisBTClient REST, Notifier SMTP+msmtp+.eml, MultiHostRunner SSH. Política open source estricta documentada. |
| 2026-05-08 | Launchers `ResolveCore.{ps1,sh}` (Windows/Linux/Android): añadida opción 3 [VULNERABILIDADES], menú reordenado (1=Diag 2=Optim 3=Vulns 4=Ayuda 5=Salir). Auto-instalan Python via scoop/choco/apt si falta. Manejo de errores `2>&1` para no aparecer en consola. |
| 2026-05-08 | Informes mejorados: TXT con secciones (identificación, score barra, resumen ejecutivo, CVEs detallados, config, puertos, IOCs, comparativa, pendientes priorizados, mensaje cliente personalizado, próxima revisión). HTML con chips severidad, banner cliente coloreado, desglose score desplegable, banda OS info. JSON añade `por_severidad`, `score_desglose`, `duracion_segundos`, `proxima_revision`. RiskScore más justo (Config CRITICAL FALLO ahora -20). |
| 2026-05-08 | WordPress sincronizado: `wordpress/page-resolvecore.php` y `wordpress/resolvecore-landing.php` actualizados a v1.1 — hero menciona TUI Launcher + multi-feed CVE, plataformas añade macOS 12+, servicios reescritos (TUI · Diagnóstico · CVE Engine · Optimización por niveles · Cross-platform · Auto-deps), terminal demo invoca `./ResolveCore.sh` y `optimizacion.sh --dry-run`, planes Pro/Enterprise reflejan macOS y MantisBT. README añade sección "Novedades v1.1", badges macOS/Android/Python, árbol arquitectura ampliado (`macos/`, `diagnosticos/`, `buscar_vulnerabilidades.py`, launchers `ResolveCore.{ps1,sh}`) y bloque "Uso rápido del TUI Launcher". |
| 2026-05-08 | Landing WordPress polish premium: smooth scroll + scrollbar custom, h1 con gradient accent (verde→azul), fade-in stagger, tarjetas de servicio con border-radius + hover lift + glow, sección nueva `#flujo` con pipeline 7 fases numerada, sección `#faq` con `<details>` nativo (6 preguntas), bloque CTA final con gradient bg, mobile menu hamburguesa funcional <860px, scroll hint animado en hero, pricing card featured con sombra glow + offset. Aplicado a `page-resolvecore.php`. Re-empaquetado en `resolvecore-theme.zip` y `resolvecore-theme-v11.zip`. |
| 2026-05-08 | README reescrito formato profesional: TOC numerada (15 secciones), badges reorganizados (status/version/license/TFG/A11y), resumen ejecutivo con propuesta de valor, mermaid arquitectura ampliada (7 fases con etiquetas), tabla capas por responsabilidad, stack con columna "Versión", tablas detalladas por módulo (diagnóstico/optimización/scanner CVE/MantisBT), referencia a esquema JSON, sección "Seguridad y reversibilidad" enumerada, índice de docs/, roadmap v1.2-v2.0, estado del proyecto, licencia GPL-3.0. Eliminados emojis decorativos en headers. |
| 2026-05-11 | Añadido `docs/defensa-scripts-mantis.md`: guion técnico de defensa orientado al tribunal. Cataloga los 17 scripts (4 Windows, 3 Linux, 3 Android, 3 macOS stub, escáner Python, ISO Win/Linux, bootstrap Mantis, install plugins) con flags, mecanismos de seguridad, exit codes. Detalla integración MantisBT (5 endpoints REST, plugin `rc-mantisbt`, helper `rc_mantis_attach_diagnostic`, flujo end-to-end 11 pasos). 9 preguntas frecuentes del tribunal con respuestas. Referencia cruzada en sección 20 de este documento. |
| 2026-05-11 | Auditoría scripts vs reglas Bash/PS actualizadas en CLAUDE.md. Fix `set -euo pipefail` → `set -uo pipefail` en `scripts/android/optimizacion.sh`, `scripts/macos/diagnostico.sh`, `scripts/macos/optimizacion.sh`. Fix `set -o pipefail` → `set -uo pipefail` en `scripts/linux/diagnostico.sh`. Sincronizadas versiones en este documento: Linux diag v3.1.0 → **v3.0.0** (versión real), Android diag v3.1.0 → **v2.1.0** (versión real). Stack: PowerShell 7.0+ → **5.1 target / 7+ opt-in** (Win 10/11 ship con 5.1, sin fricción técnico). Sección 16 "Por qué PowerShell" reescrita: target 5.1 + excepción PS7 documentada + aviso sintaxis `#Requires` sin espacio. Sección 16 "Por qué Bash" actualizada: `set -uo pipefail` (no `-e`) + razón captura granular del JSON. |
| 2026-05-11 | Versión MantisBT unificada en 2.28.1 (era 2.27 en arquitectura/demo/stack de este doc, en `docs/informe-tutor-estado-proyecto.md` y en `docs/so-especializado.md`). Scripts ISO `scripts/iso/linux/post-install.sh` y `scripts/iso/windows/setup.ps1`: bump `MANTIS_VER` 2.27.0 → 2.28.1 + fix URL de GitHub Releases (`download/release-${VER}/` → `download/${VER}/`, alineado con `scripts/bootstrap-mantis.sh` que funciona). El tag de release sin prefijo `release-` es el formato actual para MantisBT ≥ 2.28. |
| 2026-05-12 | O5 completado: `diagnostico.ps1` migrado v3.2.0 → **v4.0.0** (major por cambio breaking): todos los campos de hardware (`cpu`, `memoria`, `discos`, `gpu`, `placa_base`, `bateria`, `smart`) movidos de raíz a sub-objeto `hardware {}`. Alinea schema Windows con Linux/Android. `docs/schema-diagnostico.md` reescrito: tabla unificada, ejemplos JSON actualizados para ambas plataformas, roadmap de items `[x]` completados. `defensa-tfg.md` O5 → ✅. Pendiente: actualizar template `reports/informe.html` para adaptarse a `hardware.*`. |
| 2026-05-14 | Migración completa de referencias y dependencias de `npm` a `pnpm` debido a la vulnerabilidad CVE-2026-0775 (escalada de privilegios local en CLI) descubierta recientemente, además de ataques a la cadena de suministro. Documentado en la sección de Decisiones de Diseño de este documento. |
| 2026-05-17 | Añadido `docs/tutorial-wordpress-manual.md`: guía paso a paso para montar la web a mano (7 módulos: LocalWP → tema `resolvecore-theme` → páginas/menús → plugin `rc-mantisbt` → constantes `wp-config.php` → formulario AJAX + tests end-to-end → backup/despliegue). Incluye checklist con 12 capturas obligatorias en `docs/capturas/tutorial-wordpress/` y tabla de troubleshooting. Referenciado en README y en sección 20 de este documento. |
| 2026-05-20 | Añadido `docs/tecnica/manual-usuario-mantis.md`: manual técnico exhaustivo de configuración, integración y operación de MantisBT v2.27 para ResolveCore. 4 secciones: (1) arquitectura WP↔MantisBT + flujo REST `/api/rest/issues` + `config_inc.php` (`$g_allow_rest_api`); (2) base de datos — `mantis_custom_field_table` + `_project_table` + `_string_table` con SQL real (Plataforma type=6 lista, AnyDesk ID type=0 regex `^[0-9 ]{0,15}$`) + tabla tipos campo + consulta cruzada por ticket; (3) workflow 4 estados (NEW_→ASSIGNED→RESOLVED→CLOSED) con acciones físicas del técnico (autoasignación, lectura custom fields, AnyDesk + diagnóstico, adjuntar JSON/PDF, nota técnica); (4) matriz de permisos por rol (Reporter API WP, Developer técnico, Administrator) + SQL de creación de usuarios + endurecimiento (`$g_limit_reporters`, bloqueo `/admin/`, rotación de `crypto_master_salt`). Indexado en `docs/INDEX.md`. |
| 2026-05-20 | Tema WordPress `resolvecore-theme`: añadido CTA "Contacta con nosotros" en `header.php` (verde accent, mono) + FAB flotante global de contacto en todas las páginas excepto `/contacto/` (auto-oculto en sección contacto del front-page vía IntersectionObserver, respeta `prefers-reduced-motion`). Front-page: nueva sección **FAQ** (7 Q&A con `<details>` + schema.org FAQPage para SEO) + grid de **canales rápidos** (email directo, GitHub Issues, docs). Reescrito `page-contacto.php` matching landing aesthetic: hero con gradiente radial + badges (respuesta <2h, AnyDesk cifrado, sin compromiso), sidebar de 4 canales + caja "Qué esperar", form con char counter live 0/500. Nav y mobile menu actualizados con link `#faq`. |
| 2026-05-20 | Plugin **`rc-fleet`** v0.1.0 (MVP Panel multiplataforma del plan Enterprise): nueva tabla `wp_rc_fleet_hosts` (host_id sha256, client_email, hostname, os enum win/linux/macos/android/unknown, os_version, last_seen, last_score 0-100, last_json longtext, ticket_id, optim_at). Endpoint REST `POST /wp-json/rc/v1/fleet` con auth Bearer (constante `RC_FLEET_TOKEN` en wp-config.php) — inserta/actualiza UPSERT por (email, host_id). `GET /wp-json/rc/v1/fleet?os=&limit=` lista 200 hosts. Score heurístico `rc_fleet_score()`: penaliza disco ≥85% (-12/-25), RAM ≥85% (-10), firewall/AV inactivos (-10/-15), CVEs críticos (-5 cada uno, máx -30). Admin page `wp-admin/admin.php?page=rc-fleet` con búsqueda + filtro SO + tabla widefat con badge score color-coded (verde≥80/amarillo≥60/rojo) y link al ticket Mantis. Bloque feature `05 Panel multiplataforma` en landing reescrito sin humo (descripción técnica real: REST endpoint + score + filtros), badge BETA en plan Enterprise. Stage 4 del tracker corregido: "Resumen técnico en la nota del ticket" en lugar de "Informe PDF disponible" (PDF no implementado todavía, no se vende lo que no existe). Smoke test: 3 hosts demo Win/Linux/Android creados, scores 95/63/100. |
| 2026-05-20 | Tracking de tickets en tiempo real (UX tipo seguimiento de paquete): nuevo handler AJAX `resolvecore_ticket_status` en `functions.php` que consulta `RC_Mantis_API::get_issue()` y mapea el status enum MantisBT (10/20/30/40/50/80/90) a 4 fases UX (Recibido → En diagnóstico → En resolución → Resuelto), rate-limit 30 consultas/hora/IP, expone solo status_id+phase+timestamps (sin PII). Modal frontend en `front-page.php` (`#rc-ticket-modal`): timeline con dots ✓/activo/pendiente, pulse animation en fase actual, refresh manual, cierre por overlay/Escape/×, lazy fetch al click en `.rc-ticket-link` (delegación de eventos). Scroll indicator reubicado de centro-abajo a esquina inferior izquierda con icono `<mouse>` (border + rueda animada `rcMouseWheel`), oculto en móviles <480px. MantisBT custom fields añadidos al proyecto 1: **Modalidad** (id 3, type=6 list `Remoto\|Presencial`, secuencia 10), **Precio EUR** (id 4, type=2 float, R=Developer/RW=Manager, secuencia 20), **Notas técnico** (id 5, type=10 textarea, secuencia 30). Sistema de tags habilitado: `tag_create_threshold=25` + `tag_attach_threshold=25` (DEVELOPER) — el técnico puede crear y enlazar etiquetas a tickets. |
| 2026-05-20 | Despliegue producción finalizado en VPS Ionos `resolvecore.website` con HTTPS Let's Encrypt: branding MantisBT personalizado (logo ResolveCore, paleta verde accent, nombre "ResolveCore" en lugar de Mantis), custom fields aplicados (Plataforma list + AnyDesk ID regex), token API en `wp-config.php` como constante `RC_MANTIS_TOKEN` (no en `wp_options` por CLAUDE.md). Tema WP mejorado: hero "Solución a tus problemas informáticos" centrado, eliminados elementos duplicados, stats reales (`<2h`, `3` plataformas, `7` fases, `GPL-3` — no datos inventados), footer 4 columnas con enlaces legales **RGPD**, 3 plantillas legales nuevas (`page-aviso-legal.php` LSSI-CE art.10, `page-privacidad.php` RGPD/LOPDGDD con tabla bases legales, `page-cookies.php` con tabla cookies técnicas), responsive completo (grid → 2 cols 768px → 1 col 380px, `clamp()` headings, touch targets ≥44px `@media (hover:none)`, `font-size:16px` inputs iOS no-zoom). Fix crítico `functions.php` formulario contacto: orden invertido — **MantisBT primario** (crea ticket aunque `wp_mail()` falle por SMTP no configurado), email secundario no bloqueante; antes wp_mail fallaba sin postfix instalado y devolvía "Error al enviar" antes de llegar a Mantis. Postfix instalado en VPS (`Internet Site` mode + `mailname=resolvecore.website`) para canal secundario. Test end-to-end: AJAX `admin-ajax.php` retorna `{"success":true,"ticket_id":2}`, página `/aviso-legal/` HTTP 200. |
| 2026-05-20 | Hosting producción adquirido: **VPS Ionos Linux S** (Ubuntu 24.04 LTS, 1 vCPU / 2 GB / 80 GB, DC Madrid) a 2,50 €/mes promo. Stack objetivo: WP en `<dominio>` + Mantis en `mantis.<dominio>` en mismo VPS. Añadido `scripts/server/deploy-ionos.sh` — script bash idempotente (16 pasos, ~15 min) que automatiza: apt upgrade, instalación nginx + PHP-FPM 8.3 + MariaDB + certbot + ufw + fail2ban, creación usuario non-root con SSH key, hardening SSH (sin root + sin password auth), firewall ufw (22/80/443), swap 2 GB (vital para 2 GB RAM), creación DBs `wp_resolvecore` + `mantisbt` con usuarios dedicados (permisos mínimos), descarga WP core + generación `wp-config.php` con SALT desde api.wordpress.org, despliegue tema + plugin `rc-mantisbt` vía rsync, descarga MantisBT 2.28.1, vhosts nginx con cache estáticos + bloqueo `xmlrpc.php`/`wp-config.php`/`.htaccess`/`config_inc.php`, tuning PHP-FPM ondemand para 2 GB RAM (`pm.max_children=8`, `memory_limit=256M`), Let's Encrypt para `<dominio>` + `www.<dominio>` + `mantis.<dominio>` con redirect 80→443, cron Mantis (envío emails cada 5 min + schema check diario). Script asociado `scripts/server/upload-to-vps.ps1` (PowerShell Windows): empaqueta repo excluyendo `wp/`, `.git/`, `mantisbt-2.28.1/`, `node_modules/`, `scripts/diagnosticos/`, sube vía scp y extrae en `/opt/resolvecore-source`. Documentación nueva: `docs/tecnica/despliegue-ionos.md` (11 secciones — provisión VPS, DNS, hardening, wizards finales WP+Mantis, custom fields SQL, API token, smoke test end-to-end, backups MySQL cron, snapshots Ionos, operación rutinaria con `rsync` updates desde local, troubleshooting tabla 7 casos, coste real año 1 ~43 € / año 2 ~67 €). Indexado en `docs/INDEX.md`. |
| 2026-05-21 | **Informe PDF (O8 → ✅)**: nuevo `reports/generate-report.php` — generador CLI que inyecta el JSON de diagnóstico en `reports/informe.html` (escapando `</script>`), convierte a PDF A4 vía wkhtmltopdf y, con `--ticket`, lo adjunta al ticket MantisBT (`POST /api/rest/issues/{id}/files`). Valida schema mínimo `_meta.plataforma`+`version`. `deploy-ionos.sh`: añadido `wkhtmltopdf` al stack apt. Fix `upload-to-vps.ps1`: la línea que muestra la pubkey SSH no expandía `$env:USERPROFILE` (backtick mal escapado) — ahora lee el fichero con `Test-Path` + fallback. Secciones 12 y 13 de este documento reescritas con la implementación real. |
| 2026-05-21 | **Web — navegación y fleet status**: menú desplegable **«Recursos»** (Documentación · Changelog · Estado de la flota) en `front-page.php` y `header.php`, que se unifican (antes eran dos sistemas de nav distintos). Desplegable con hover (CSS) + click/teclado (JS `aria-expanded`, cierre con Esc), espejado en menú móvil. `rc-fleet`: nuevo endpoint REST **público** `GET /wp-json/rc/v1/fleet/stats` (solo agregados — total, score medio, distribución de salud, recuento por SO, activos 24 h — **sin emails, hostnames ni JSON**), función `rc_fleet_get_public_stats()`, render `rc_fleet_render_stats()` y shortcode `[rc_fleet_status]`. Nueva plantilla `page-fleet-status.php` (panel público). `page-changelog.php` reescrito con 4 releases reales (v0.9.0 beta → v1.2.0). Footer de páginas internas con `fallback_cb` (`resolvecore_footer_menu_fallback`). Skip-link + `id="main-content"` en docs/changelog/fleet-status. El endpoint protegido `POST/GET /fleet` se mantiene con auth Bearer — el 401 al navegarlo sin token es comportamiento correcto. |
| 2026-05-21 | **Demo interactiva reescrita** (`front-page.php`): selector de plataforma **Windows/Linux/Android** que cambia comando y salida del terminal por SO (`.\ResolveCore.ps1` / `bash diagnostico.sh` / ADB). Datos reestructurados en `demoPlatforms` × `demoModules`. Corregidos 2 bugs: botones `[REPARAR]`/`[PARCHE]` no tenían `onclick` (función `fixVuln` muerta); barra de progreso falsa (ahora cuenta 0→100% sincronizada línea a línea). Añadido: panel de resultado con gauge SVG animado de salud, contadores animados, tabla de vulnerabilidades contextual con CVE enlazados a NVD, vista comparativa antes/después (Optimización y Proyección hardware), efecto typewriter en el comando, botón Repetir, CTA a contacto. A11y: `aria-live` en el terminal, `role="progressbar"`, respeto a `prefers-reduced-motion` (render instantáneo), auto-scroll. Badge `LIVE` → `SIMULACIÓN` (no era live, es HTML simulado). |
| 2026-05-21 | **Gestión de permisos MantisBT**: nuevo `docs/tecnica/mantis-permisos.md` — matriz de las 19 capacidades (adjuntos, filtros, proyectos, campos personalizados, otros) × 6 roles, con umbral recomendado por capacidad bajo criterio de mínimo privilegio (cliente=REPORTER solo abre/adjunta; técnico=DEVELOPER opera; ADMINISTRATOR gestiona usuarios y proyectos). Bloque de constantes `$g_*_threshold` aplicado en `mantisbt/config/config_inc.php` (Docker local) y `config_inc.php.template` (producción). «Usar filtros guardados» y «Enviar recordatorios» quedan para la GUI (sin constante fiable en 2.28). Indexado en `docs/INDEX.md`. |
| 2026-05-24 | **Fase 2 MantisBT — adjuntador de informes vía API REST (hexagonal)**: nuevo módulo `scripts/common/adapters/mantis_rest.py` (`MantisRestSink`, stdlib-only, construye `multipart/form-data` a mano sobre `urllib.request` — sin dependencia de `requests`), `scripts/common/ports/mantis_attachment_sink.py` (Protocol PEP 544) y dataclass `AttachmentResult` en `domain/models.py`. CLI entrada `scripts/common/adjuntar_informe_mantis.py --ticket <id> --pdf <ruta>` lee `MANTIS_URL` + `MANTIS_TOKEN` del entorno (nunca hardcodeado), nunca lanza excepción (siempre devuelve `AttachmentResult`), exit codes 0/1/2. Implementa el flujo descrito en `docs/defensa/mantisbt-api-integracion.md` y desbloquea el cierre automático del ticket con informe PDF adjunto en la fase 7 del flujo. **PHPCS 0 warnings (antes 6)**: normalizada terminación de línea LF en `rc-mantisbt.php`, `footer.php`, `header.php`, `page-aviso-legal.php`, `page-cookies.php`, `page-privacidad.php` (resuelve `Internal.LineEndings.Mixed`). |
| 2026-05-24 | **CI lint endurecido (4/4 verde y bloqueante)**: arreglada cadena de fallos en `.github/workflows/lint.yml`. **Python (ruff)**: limpieza imports y f-strings en `scripts/common/buscar_vulnerabilidades.py` + `escaner_nmap.py`. **Shell (shellcheck)**: SC2144 (`compgen -G` en lugar de `-f` con globs), SC2164 (`cd … \|\| exit 1` en launchers Linux/macOS/Android + `deploy-ionos.sh`), SC2034/SC2229/SC2163 declarados explícitamente. **PowerShell (PSScriptAnalyzer)**: nuevo `PSScriptAnalyzerSettings.psd1` excluyendo reglas no aplicables a TUI interactiva (Write-Host intencional, empty catch, naming es-ES, BOM cosmético), fix `$null -ne $var` en `diagnostico.ps1`. **PHP (PHPCS/WPCS 3.x)**: `composer global config allow-plugins.dealerdirect/phpcodesniffer-composer-installer true` + registro de `phpcsstandards/phpcsutils` + `phpcsstandards/phpcsextra` (requeridos por WPCS 3 para sniffs Universal/NormalizedArrays). `phpcbf` auto-fix de 4791 issues (tabs en lugar de espacios, alignment). Nuevo `phpcs.xml.dist` con ruleset proyecto: hereda WordPress excluyendo reglas cosméticas (Squiz.Commenting, Yoda, `error_log`, short ternary, line endings) pero conservando todo el bloque `WordPress.Security`. **Security fixes manuales** detectados por WPCS: `functions.php` añade `sanitize_text_field( wp_unslash( $_SERVER['REMOTE_ADDR'] ) )`; `front-page.php`, `page-changelog.php`, `page-docs.php`, `page-contacto.php`, `page-fleet-status.php` escapan output con `esc_url()`, `esc_attr()`, `esc_js()`, `wp_kses_post()` en URLs admin-ajax, `get_template_directory_uri()`, nonces y HTML interno (`rc_fleet_render_stats`). PHPCS pasa de `continue-on-error: true` a bloqueante. |
| 2026-05-21 | **Correo de confirmación al cliente**: el handler `resolvecore_handle_contact()` (`functions.php`) envía ahora un segundo correo HTML al cliente además del aviso al técnico — función `resolvecore_send_client_confirmation()`. Incluye número de incidencia `#ID`, categoría, el mensaje enviado, las 4 fases de seguimiento y botón «Ver estado en tiempo real» que enlaza a `?rc_ticket=ID#contacto`. Nuevo bloque JS en `front-page.php`: lee el parámetro `rc_ticket` de la URL y abre automáticamente el modal de tracking. Canal informativo no bloqueante (si `wp_mail()` falla solo se registra), `Reply-To` al correo del técnico. Tema `resolvecore-theme` v3.1.1 → **v3.1.2**, nueva entrada en `page-changelog.php` (v1.2.0). |
| 2026-05-21 | **Correo de contacto profesional**: sustituido el email personal `fvidalmateo@gmail.com` por el buzón Ionos del dominio `tecnicos@resolvecore.website` en las 4 páginas del tema donde aparecía — `front-page.php` (canales de contacto), `page-contacto.php`, y las páginas legales `page-aviso-legal.php` (LSSI) y `page-privacidad.php` (RGPD: responsable del tratamiento y ejercicio de derechos). Tema `resolvecore-theme` v3.1.2 → **v3.1.3**. El `admin_email` de WordPress (usado por `resolvecore_handle_contact()` y el `Reply-To` de la confirmación) se cambia en `Ajustes → Generales` del VPS. |
| 2026-05-21 | **Correo saliente en producción — relay Ionos + mejoras de entregabilidad**: el despliegue real destapó que Ionos bloquea el puerto 25 saliente del VPS (`Connection timed out`, correo en cola). Se configuró Postfix para relayar el correo autenticado por el smarthost `smtp.ionos.es:587` (buzón `tecnicos@`); `setup-mail-dkim.sh` ganó el flag `--relayhost` (relay + SASL, contraseña pedida de forma interactiva) y fija `myhostname = mail.<dominio>` + `mydestination` sin el dominio raíz, lo que corrige el rebote `unknown user` de los buzones del dominio. `resolvecore_send_client_confirmation()` pasó a `multipart/alternative` — añade una parte de texto plano junto al HTML — y emite la cabecera `List-Unsubscribe`. Doc `docs/tecnica/correo-dkim.md` ampliada con la sección "1b. Relay saliente". Verificado con mail-tester sobre el ticket #8: SPF/DKIM/DMARC autenticados, sin blacklist, enlace de seguimiento con token HMAC respondiendo 200. Tras detectar que el aviso al técnico caía en spam, se unificó el remitente con los filtros `wp_mail_from`/`wp_mail_from_name` a `ResolveCore <tecnicos@resolvecore.website>` — el `wordpress@` genérico de WordPress no coincidía con el buzón autenticado del relay y el antispam lo penalizaba. |
| 2026-05-21 | **Endurecimiento y mejoras**: (1) **Token anti-enumeración** en el seguimiento de tickets — `resolvecore_ticket_token()` deriva un HMAC-SHA256 stateless de `rc_ticket_<id>` con `wp_salt('auth')`; `resolvecore_handle_ticket_status()` lo valida con `hash_equals()`; el token viaja en el correo (`&rc_t=`), en la respuesta AJAX y en el `dataset.token` del enlace, y el JS del modal (`fetchStatus(id, token)`) lo reenvía. Cierra un IDOR de baja gravedad (IDs secuenciales enumerables). (2) **Caché del endpoint público de la flota** — `rc_fleet_get_public_stats()` cachea en transient (`rc_fleet_public_stats`, 5 min), invalidado en cada POST de agente; plugin `rc-fleet` 0.2.1 → **0.2.2**. (3) **Entregabilidad de correo** — nuevo `scripts/server/setup-mail-dkim.sh` (Postfix + OpenDKIM idempotente) y guía `docs/tecnica/correo-dkim.md` con los registros SPF/DKIM/DMARC para Ionos. (4) **Versionado** — `docs/tecnica/versionado.md` unifica los 4 flujos de versión. (5) **Riesgo wkhtmltopdf** — nota de deprecación + plan de migración a DomPDF en cabecera de `generate-report.php`. (6) **Smoke-test de permisos** — checklist por rol añadido a `docs/tecnica/mantis-permisos.md`. Tres docs nuevos indexados en `docs/INDEX.md`. |
| 2026-05-25 | **Servicios adicionales — scripts operativos** (O11–O13 → ✅): implementados los 5 scripts en `scripts/servicios/`. Congelación Windows (`congelacion-windows.ps1`): detección automática Reboot Restore Rx / Deep Freeze, acciones `Status`/`Configure`/`Freeze -Confirm`/`Thaw -Confirm`, salida `[PSCustomObject]` JSON. Congelación Linux (`congelacion-linux.sh`): BTRFS + snapper, acciones `status`/`configure`/`snapshot`/`rollback --confirm`, JSON por stdout. Clonación: `registrar-imagen.sh` da de alta en `imagenes-manifest.json` (SHA-256 fichero o árbol), `verificar-imagen.sh` valida integridad (exit 0/1/2). Kit implantación: `construir-kit.ps1` empaqueta `resolvecore-kit.zip` (AnyDesk portable + scripts diagnóstico + README-cliente.txt). Esquemas JSON propios documentados en `docs/scripting/schema-servicios-adicionales.md`. `scripts/servicios/README.md` actualizado: stubs → implementado. Sección 15b añadida a este documento. Objetivos O11–O13 marcados ✅. |
| 2026-05-26 | **Deploy VPS — portal técnicos + directorio de descargas**: `setup-downloads-dir.sh` corregido (wp-config path multi-candidato, snippet location-only en lugar de nuevo `server{}` que rompía SSL). Desplegado en producción: `/opt/resolvecore-downloads/` con `install-servicios.ps1`, `install-servicios.sh`, `resolvecore-kit.zip`; nginx `/downloads/` con HTTP Basic Auth (htpasswd). Página WP `/tecnicos/` con plantilla "Área de Técnicos" (`page-tecnicos.php`) publicada y accesible para usuarios con rol Editor. Guion de demo sección 18 ampliado: pasos 8-10 cubren congelación Linux, clonación y portal técnicos. |
| 2026-05-29 | **Segunda auditoría (`docs/defensa/auditoria-mejoras.md` §6) — regresión de vendor + secreto filtrado**: el repo había crecido a 3285 ficheros, **3119 (95 %) en `wp/`** (WordPress core + akismet + tema twentytwentyfive + sqlite-integration) — misma patología que `E1` con Mantis. **A1**: `wp/` añadido a `.gitignore` + `git rm -r --cached wp/` → repo **3285 → 165** ficheros propios. **A2** (seguridad): `wp-config.php` y `wp/wp-config.php` estaban versionados con `define('RC_MANTIS_TOKEN', …)` — token de la API Mantis **filtrado en git** (anula `W1`, viola CLAUDE.md); ambos destrackeados, **pendiente rotar el token**. Abiertos: A3 alta pública sin verificación de email, A4 tres repos de deploy en el VPS, A6 formato de autor mezclado, A7 código muerto tras separar flujos. |
| 2026-05-29 | **Alta de clientes (rol `rc_cliente`) + refactor cliente Mantis**: plugin `rc-core` v1.2.0 → **v1.3.0**. (1) **Gap funcional cerrado** — la captación creaba ticket pero no cuenta WP, así que el cliente no podía entrar al dashboard. Nuevo rol `rc_cliente` (`add_role`, cap `read`, idempotente en activación + `init`) y shortcode **`[rc_registro_cliente]`** (CTA separado de soporte): formulario nombre+email con honeypot `rc_website` + rate-limit 3/h por IP (`rc_cliente_ip_hash()` local, solo `REMOTE_ADDR`), valida `email_exists`, crea usuario con `wp_insert_user` (login derivado del email con desambiguación) y contraseña autogenerada `wp_generate_password(16)`. `rc_registro_cliente_email()` envía las credenciales en correo HTML `multipart/alternative` (mismo estilo dark que la confirmación de contacto) con enlace de acceso al dashboard; recomienda cambiar la clave tras el primer acceso. **Decisión consciente**: contraseña en claro por email (riesgo aceptado por el autor frente al enlace de reset). (2) **Refactor anti-duplicación** — `rc_mantis_crear_ticket()` y `rc_mantis_listar_tickets()` ahora delegan en `RC_Mantis_API` vía `rc_mantis_get_api()`, con *fallback* al REST directo si `rc-mantisbt` no está activo. Nuevo método `RC_Mantis_API::search_issues($query, $page_size)` en la clase base (búsqueda por texto/email, `page_size` clamp 1-100) — elimina el transporte `wp_remote_*` duplicado en `rc-core`. PHP `-l` limpio en ambos ficheros. |
| 2026-05-29 | **Flujo de cliente reorganizado: enlace de activación + home capta, dashboard tickea**: `rc-core` v1.3.0 → **v1.4.0** y tema `resolvecore-theme` style.css → **v3.1.4**. (1) **Credenciales por enlace seguro** (supera la decisión previa de contraseña en claro): el alta crea el usuario con `wp_generate_password(24)` que **nunca se envía**; se genera `get_password_reset_key()` y se manda email de activación con botón «Fijar mi contraseña» (URL nativa `wp-login.php?action=rp`, un solo uso, caduca). Lógica extraída a `rc_crear_cuenta_cliente($email,$nombre)` (idempotente por email), reutilizada por `[rc_registro_cliente]` y por la home. Nueva plantilla `page-registro.php` (`Template Name: Registro cliente`) + estilos `.rc-registro*` (tarjeta centrada 460px, botón full-width). (2) **Separación de flujos**: el formulario de la home (`resolvecore_handle_contact()`) **dejó de crear tickets**; ahora solo da de alta cuenta + activación y avisa al admin como *lead* («Solicitud de acceso»). Se quitó el correo de seguimiento de ticket (`resolvecore_send_client_confirmation` sin uso) y el botón JS `[VER TICKET #id]` de `front-page.php`; respuesta AJAX sin `ticket_id`. El alta de tickets es ahora exclusiva del **dashboard** (`[rc_cliente_dashboard]` → `rc_cliente_procesar_form()` → `rc_mantis_crear_ticket()`). Flujo: solicitud de acceso (home) → cuenta + email activación → `/dashboard/` → ticket Mantis → diagnóstico/informe. PHP `-l` limpio en `rc-core.php`, `functions.php`, `front-page.php`. |
| 2026-05-29 | **Cierre 2ª auditoría (A3·A4·A6·A7)**: `rc-core` v1.4.0 → **v1.5.0**. **A3 (alta pública sin verificación de email)** cerrado sin captcha/infra externa, apoyándose en que la activación ya **es** verificación (la cuenta es inservible hasta clicar el enlace de reset, que solo llega al buzón real): (a) throttle **por-email** en `rc_crear_cuenta_cliente()` — 1 email de activación/hora por dirección (transient con `wp_salt`), frena el email-bombing a una víctima dentro del rate-limit por IP; (b) marca `rc_pending_activation` (timestamp) al crear; (c) `after_password_reset` → `rc_cliente_on_password_reset()` borra el marcador al fijar contraseña; (d) cron diario `rc_cliente_purga_evento` → `rc_cliente_purgar_pendientes()` borra cuentas `rc_cliente` no activadas a los 7 días (programado/desprogramado en activación/desactivación del plugin). **A7 (código muerto)**: eliminada `resolvecore_send_client_confirmation()` (~185 líneas, sin callers tras separar flujos; sustituida por nota-docblock); **conservado** el tracker público de tickets (`resolvecore_handle_ticket_status` + modal + URL firmada HMAC `?rc_ticket=N&rc_t=TOKEN`) como feature viva reutilizable desde el dashboard. **A6 (autor inconsistente)**: 8 cabeceras `(FranVi)` → `(GitHub: Haplee)` (formato canónico de CLAUDE.md). **A4 (3 repos en VPS)**: documentada la consolidación en `docs/tecnica/despliegue-ionos.md` §8.0 — `/opt/resolvecore-repo` (main) canónico, `git reset --hard origin/main` + `sync-wp.sh`, comandos de borrado de `-git`/`-source`; falta solo el `rm -rf` manual de ops. **A2**: el token Mantis **no se rota por decisión del autor** (riesgo asumido; sigue en el histórico). PHP `-l` limpio en `rc-core.php`, `functions.php`. |
| 2026-05-30 | **Tercera auditoría — lógica del flujo cliente/técnico** (`docs/defensa/auditoria-mejoras.md` §7, 9 fixes): `rc-core` v1.5.0 → **v1.5.1** + `functions.php` + `page-tecnicos.php`. **L1** rate-limit del registro (`rc_registro_cliente_procesar`) se incrementa **tras** validar y comprobar `email_exists`, no antes — un usuario que corrige typos ya no agota la cuota de 3/h sin crear cuenta. **L2** `rc_cliente_calcular_stats()` cuenta cerrados por `status['id'] >= 80` (enum Mantis) en vez de comparar `status['name']` contra `'closed'/'resolved'` en inglés, que fallaba con nombres localizados. **L3** si el `wp_signon()` posterior al alta falla, redirige a `/registro/?tab=login&alta=ok` con mensaje de confirmación en vez de un texto engañoso sin sesión. **L4** el `<details>` "Solicitar informe" colapsa solo si se envió **ese** formulario (`rc_solicitar_informe`), no ante cualquier POST del sitio. **L5** `rc_create_download_log_table()` deja de ejecutar `dbDelta` (`SHOW TABLES/COLUMNS`) en cada request: guard de versión `rc_dl_log_schema_ver` vs constante `RC_DL_LOG_SCHEMA_VER` + hook `after_switch_theme`. **L6** `define('RESOLVECORE_MAINTENANCE')` envuelto en `if(!defined())` — sin notice y forzable desde `wp-config.php`. **L7** `rc_tech_infra_status` gana `check_ajax_referer('rc_tech_nonce')` (era el único endpoint AJAX técnico sin nonce) + `fetchInfra()` en `page-tecnicos.php` envía el nonce. **L8** `rc_tech_my_tickets` devuelve `note` explicando el mismatch de login WP↔Mantis cuando el filtro deja la lista vacía. **L9** `rc_tech_factura_inline` aplica clamp `0–1000` a `horas`/`tarifa` de GET. PHP `-l` limpio en los tres ficheros. |
| 2026-05-30 | **Registro de clientes provisionado + mejora visual home** (tema `resolvecore-theme`). (1) **Bug en producción**: el enlace «Acceso clientes → /registro/» daba 404 porque la plantilla `page-registro.php` existía pero ninguna página WP la usaba (no había auto-provisión). Nueva `rc_provision_pages()` en `functions.php` (idempotente, guard `rc_pages_provision_ver` v**2** + hooks `after_switch_theme`/`init`): crea las páginas que el nav da por hechas (`/registro/` con `[rc_registro_cliente]`, `/dashboard/` con `[rc_cliente_dashboard]`, y docs/changelog/fleet-status/tecnicos/contacto/legales con su plantilla). **Fix v2**: si la página ya existe pero su `post_content` no contiene el shortcode requerido (caso real: `/registro/` existía vacía y solo pintaba la cabecera del template, sin formulario, porque `page-registro.php` hace `the_content()`), se inyecta el shortcode vía `wp_update_post` (comprobación `has_shortcode`, sin duplicar). (2) **Mejora visual de la portada** (color **verde de marca `#00e5a0` conservado/restaurado** — el primer deploy había subido azul a `origin/main`; revertidos tokens `style.css` + 37 hardcodeados de `front-page.php`): hero rehecho a **dos columnas** (copy izquierda + tarjeta-mockup de diagnóstico a la derecha: anillo de salud 87, barras CPU/Memoria/Disco, píldoras de estado) con grid `1.05fr/.95fr` que apila en ≤880px; botón secundario del hero «CREAR CUENTA» → `/registro/`. **Demo interactiva conservada** (terminal animado por plataforma/módulo + gauge); `runDemo()` gana guard `if(!output||!bar) return`. Tarjetas de **servicios** refinadas (icono 52px protagonista, lift en hover, barra de acento superior). **Nav**: corregido el desplegable «Recursos» que partía el caret `▾` a otra línea (`inline-flex` + `white-space:nowrap` + `flex-shrink:0` en el caret). (3) **Branding de wp-login** (`rc_login_branding` vía `login_enqueue_scripts` + filtros `login_headerurl`/`login_headertext`): las pantallas de login, «¿Olvidaste tu contraseña?» y reset `action=rp` (las de los emails de activación) se visten con el logo ResolveCore y la paleta oscura/verde en vez de la pantalla genérica de WordPress; el flujo nativo seguro se conserva, solo se reestiliza. PHP `-l` limpio en `front-page.php` y `functions.php`. |
| 2026-05-30 | **Fuga de datos en dashboard de cliente — fix de seguridad** (`rc-core` v1.5.1 → **v1.5.2**). Síntoma reportado en producción: el dashboard de un cliente listaba **los 15 tickets de Mantis de todos los clientes** (antonio, María, Smoke, PEPE…) y sus stats (15/9/6). Causa: el endpoint `/api/rest/issues` de Mantis **ignora** el parámetro `search`, así que `RC_Mantis_API::search_issues($email)` devolvía la lista completa sin filtrar. Fix: nueva `rc_mantis_filtrar_por_cliente($issues, $email)` que recorta en PHP la lista a SOLO los del cliente — pertenencia por (1) `reporter.email == email` o (2) el email embebido como «Solicitado por: <email>» en la descripción (lo inyecta `rc_mantis_crear_ticket()`). Aplicado en las dos vías de `rc_mantis_listar_tickets()` (API centralizada + fallback REST). Las stats (`rc_cliente_calcular_stats`) ya cuadran al operar sobre la lista filtrada. **Mejora UI del dashboard**: tarjetas de ticket con badge de estado coloreado + punto y borde-acento izquierdo por familia de estado (pendiente ámbar `<50` / en curso azul `50-79` / hecho verde `≥80`), prioridad como chip (urgent/high en naranja), y línea «Creado … · Actualizado …» (usa `updated_at` de Mantis). Cabecera del dashboard (`page-dashboard.php`) con chip de email + enlace «Cerrar sesión». **Email de activación (infra)**: causa = el VPS no tenía relay SMTP, así que `wp_mail()` (PHP `mail()`) no entregaba. Nuevo `scripts/server/ops/setup-mail-ionos.sh` (idempotente, `set -euo pipefail`): instala `msmtp`+`msmtp-mta`, escribe `/etc/msmtprc` (relay `smtp.ionos.es:587` autenticado con buzón del dominio, `0640 root:www-data`, password por argumento — no se versiona) y cablea `sendmail_path = msmtp -t -i` en PHP-FPM/CLI 8.3 + reload. El From ya lo alinea `resolvecore_mail_from` al `admin_email` (debe ser el buzón). PHP `-l` limpio en `rc-core.php`, `page-dashboard.php`; `bash -n` limpio en el script. |
| 2026-05-31 | **Cuarta auditoría (§8) + sincronización de este documento con el árbol real**. **A11 (causa raíz)**: el commit `12890ac` había borrado 44 ficheros fuente (−18.793 líneas). Decisión del autor: **restaurar solo el núcleo esencial** — arquitectura Hexagonal Python `scripts/common/{domain,ports,adapters}` + `escaner_nmap.py`/`generar_informe.py`/`generar_factura.py`/`adjuntar_informe_mantis.py` + `vulnerabilities/migrations/0001_init.sql` (16 ficheros desde `12890ac^`, compila limpio). También restaurados (indispensables): los **launchers** `ResolveCore.{sh,ps1}` (Linux/Android/Windows) y `scripts/servicios/` **source** (congelación/clonación/kit) → O11–O13 vuelven a ✅. **No** restaurados (en histórico): `scripts/macos/`, `scripts/setup/`, el binario `kit/anydesk.exe` (7.9 MB, lo aporta el técnico) y `setup-mail-dkim.sh` (superado por `setup-mail-ionos.sh`). **A8/A9/A10** (limpieza): destrackeados `wordpress-db.sql` (traía el **hash bcrypt del admin** + emails), `php.ini` del servidor y el fichero basura `-Headers` — **pendiente rotar la contraseña del admin** (hash en histórico). **D5/D6/D7/D8** cerrados alineando CLAUDE.md, `correo-dkim.md` (ruta real msmtp+IONOS `.website`, DKIM s1/s2) y `schema-diagnostico.md`. Este documento se actualiza: banner de estado del árbol, objetivos O4/O11–O13 → ROADMAP/[EN HISTÓRICO], §6 macOS y §15b servicios marcadas, guion de demo pasos 8-10 advierten de restaurar `scripts/servicios/` antes de demostrar. **S7** queda abierto (referencias a launchers en docs de defensa). Correo de activación verificado a **inbox** (no spam). |
| 2026-05-23 | **Auditoría — quick-wins + CI**: cerrados 9 items pendientes de `docs/defensa/auditoria-mejoras.md`. **E4** `.editorconfig` raíz (UTF-8 + LF globales, CRLF para `.ps1`, indent 2 YAML/JSON, tab Makefile). **E5** `LICENSE` con texto oficial GPL-3.0 (35 149 bytes); GitHub ya detecta la licencia. **D3** nueva sección "Versiones por componente" en README — tabla con 12 componentes (producto, tema, plugin, los 8 scripts diag/optim, escáner CVE, schema JSON) y regla de paridad `_meta.version` ≡ versión cabecera de script. **S4** (ya hecho — verificación): los 4 puntos de inyección HTML escapan `</`→`<\/` (`scripts/windows/diagnostico.ps1:820`, `scripts/linux/diagnostico.sh:933`, `scripts/android/diagnostico.sh:522`, `reports/generate-report.php:82`) sobre template `<script type="application/json" id="rc-data">` parseado con `JSON.parse()`. **W3** `strlen`→`mb_strlen` en `RC_Mantis_API::sanitize_summary/description()` (sync ambas copias del plugin: `wordpress/plugins/` + `wp/wp-content/plugins/`). **W4** cabeceras estándar de WP en `rc-mantisbt.php`: `Requires at least: 6.0`, `Tested up to: 6.5`, `Requires PHP: 8.0`, `License URI`, `Domain Path`; license alineada a `GPL-3.0-or-later` (era `GPL-2.0+`). **W5** `SELECT id ... LIMIT 1` → `SELECT MAX(id)` en las dos asignaciones `@field_id`/`@anydesk_field_id` de `mantisbt/sql/resolvecore-setup.sql` (evita warnings strict-mode). **C1** `.github/workflows/lint.yml` con 4 jobs paralelos: shellcheck (`ludeeus/action-shellcheck@2.0.0`), PSScriptAnalyzer (Windows runner), phpcs WordPress-Core (`shivammathur/setup-php@v2` + composer WPCS 3.x), ruff + `py_compile` sobre `scripts/common/`. **C2** `.pre-commit-config.yaml` con `pre-commit-hooks@v4.6.0` + `shellcheck-py@v0.10.0.1` + `ruff-pre-commit@v0.5.0` + hook local `phpcs` opcional (skip si no está en PATH). Pendientes diferidos en `auditoria-mejoras.md`: E2 mover zips a GitHub Releases (manual), D4 testar macOS en hardware real, S3 test con hostnames `"\\\n`, S5 modularizar `buscar_vulnerabilidades.py` (solo si crece). |
| 2026-06-02 | **Arreglo integral de los launchers + escáner CVE real + informe/factura a `.txt`** (una ejecución real del técnico destapó fallos en casi todas las opciones del menú). **Bugs de menú/parseo**: (1) vuln Android crasheaba con `Error resolviendo --platform` porque el launcher pasaba `--platform A` a un port-scanner que lo tomaba como host → ahora invoca `--plataforma android --serial`; (2) `show_devices` Android salía vacío (`adb devices -l \| grep "device$"` no casa con líneas que acaban en `transport_id:N`) → parseo con `awk 'NR>1 && $2=="device"'`; (3/4) optimización Linux **y Windows** no ejecutaban (el menú no pasaba `--confirm`/`-Confirm`, el script solo imprimía el "Uso:") → confirmación explícita + flag; en Android se añade aviso `pm clear` + `SI` antes de `--confirm`. **JSON de diagnóstico inválido** (`Expecting property name … line 11`): locale `es_ES` hacía que `awk printf "%.1f"` emitiera coma decimal (`120,5`) en `linux/diagnostico.sh` → `export LC_ALL=C` + blindaje de numéricos vacíos + validación `python -m json.tool`; mismo blindaje en `android/diagnostico.sh` (Windows usa `ConvertTo-Json`, inmune). **Parser PS5.1 roto** en `congelacion-windows.ps1` («Falta Catch/Finally»): patología `feedback_ps51_utf8_bom` (sin BOM, PS5.1 lee ANSI y los em-dash/acentos rompen el parser) → re-guardados con **UTF-8 BOM** los 7 `.ps1` fuente con no-ASCII (parser 0 errores). **Informe y factura → plantilla `.txt`** (decisión del autor: el técnico rellena a mano y sube él mismo el informe a Mantis; sin PDF/HTML/email/upload): `generar_informe.py` y `generar_factura.py` reescritos como generadores de `.txt` con apartados/campos predefinidos (stdlib, **sin clases ni type hints**, español — corrige la violación previa con `typing`); launchers Linux/Windows simplificados, Android no los expone. **Escáner CVE real (S5 cumplido)**: `buscar_vulnerabilidades.py` reescrito como orquestador hexagonal sobre `common/{domain,ports,adapters}`; nuevos adapters `osv_rest.py` (OSV.dev, primario en Linux), `kev_rest.py` (catálogo CISA KEV cacheado 24h) e `inventario_local.py` (dpkg/rpm · winreg · adb `pm list`) + port `inventory_source.py`; reutiliza `nvd_rest.py` para Windows/Android (rate-limit 6s → `--max`). Salida JSON `{plataforma,software,vulnerabilidades,avisos}` con flag `kev`; modo legacy `--puertos` conservado; stdout/stderr forzados a UTF-8 (evita `UnicodeEncodeError` en consola cp1252). Verificado: `bash -n`/`py_compile`/parser PS 0 errores; ambos modos del escáner producen JSON válido end-to-end (Windows real: 2 software, sin crash); plantillas `.txt` con todos los apartados en blanco. |
