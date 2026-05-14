# ResolveCore — Stack Tecnológico

> Documento técnico de justificación de tecnologías.  
> Autor: Francisco Vidal Mateo · TFG ASIR 2024/25  
> Última actualización: mayo 2026

---

## Índice

1. [Visión general](#1-visión-general)
2. [Frontend / CMS — WordPress](#2-frontend--cms--wordpress)
3. [Gestión de incidencias — MantisBT](#3-gestión-de-incidencias--mantisbt)
4. [Plugins MantisBT](#4-plugins-mantisbt)
5. [Acceso remoto — AnyDesk](#5-acceso-remoto--anydesk)
6. [Scripts de diagnóstico — PowerShell / Bash](#6-scripts-de-diagnóstico--powershell--bash)
7. [Base de datos — MariaDB](#7-base-de-datos--mariadb)
8. [Servidor web — Nginx + PHP-FPM](#8-servidor-web--nginx--php-fpm)
9. [Integración REST — MantisBT API](#9-integración-rest--mantisbt-api)
10. [Control de versiones — Git / GitHub](#10-control-de-versiones--git--github)
11. [Generación de informes — PDF](#11-generación-de-informes--pdf)
12. [Futuro — App Android](#12-futuro--app-android)
13. [Auditoría de exposición — Shodan](#13-auditoría-de-exposición--shodan)
14. [Clonado e imágenes de SO](#14-clonado-e-imágenes-de-so)
15. [Seguridad en cliente — Cifrado y gestores](#15-seguridad-en-cliente--cifrado-y-gestores)
16. [Resumen comparativo](#16-resumen-comparativo)

---

## 1. Visión general

ResolveCore es una plataforma de soporte técnico remoto estructurada en 7 fases:

```
Solicitud → Ticket (MantisBT) → Acceso remoto (AnyDesk) →
Diagnóstico (PS/Bash) → Resolución → Informe PDF → Facturación
```

El stack combina herramientas de código abierto maduras, con integración vía API REST, para cubrir todos los módulos del ciclo ASIR: administración de sistemas, redes, bases de datos, seguridad y servicios en red.

---

## 2. Frontend / CMS — WordPress

### Tecnología elegida

**WordPress 6.x** con tema personalizado `resolvecore-theme` (PHP puro, sin builders).

### Plan de WordPress elegido

WordPress.com ofrece cuatro planes. ResolveCore requiere el plan **Business** (mínimo) por la necesidad de instalar plugins propios.

| Característica | Gratuito | Personal | Business | VIP |
|---------------|----------|---------|---------|-----|
| Precio (aprox.) | 0 €/mes | ~4 €/mes | ~25 €/mes | Contacto |
| Plugins propios | ❌ | ❌ | ✅ | ✅ |
| Themes propios | ❌ | ❌ | ✅ | ✅ |
| Dominio personalizado | ❌ | ✅ | ✅ | ✅ |
| SSL automático | ✅ | ✅ | ✅ | ✅ |
| Acceso SFTP/DB | ❌ | ❌ | ✅ | ✅ |
| Soporte prioritario | ❌ | Chat | Chat + Email | Dedicado |
| Sin anuncios WordPress.com | ❌ | ✅ | ✅ | ✅ |
| WooCommerce | ❌ | ❌ | ✅ | ✅ |

**Por qué Business y no VIP:** VIP está orientado a grandes medios (CNN, TechCrunch). El coste es desproporcionado para un proyecto académico. Business proporciona todo lo necesario: plugin `rc-mantisbt`, tema personalizado `resolvecore-theme`, dominio `resolvecore.com` y acceso SFTP para despliegue.

**Alternativa considerada (WordPress.org + hosting propio):** WordPress.org (software libre) sobre VPS propio daría control total. Se descarta para la fase actual porque WordPress.com Business elimina la gestión de servidor en el periodo del TFG. El despliegue en VPS propio (Oracle Cloud Free Tier) está planificado para producción final.

---

### Por qué WordPress

| Criterio | WordPress | Joomla | Drupal | Desarrollo custom |
|----------|-----------|--------|--------|-------------------|
| Curva de aprendizaje | Baja | Media | Alta | Alta |
| Ecosistema de plugins | 60 000+ | ~7 000 | ~50 000 | N/A |
| Comunidad / documentación | Muy amplia | Media | Media | N/A |
| Hosting compartido | Omnipresente | Común | Menos común | Variable |
| Tiempo de desarrollo | Bajo | Medio | Alto | Muy alto |
| Estándares PHP modernos (WPCS) | Sí | Parcial | Sí | Sí |
| Relevancia mercado laboral | 43% web mundial | ~2% | ~2% | — |

**Razón principal:** WordPress permite entregar un frontend profesional en el tiempo disponible para el TFG, con formularios AJAX, modo mantenimiento, SEO y un sistema de plugins que facilita la integración con MantisBT. El desarrollo de un CMS custom aportaría poco valor pedagógico frente al tiempo invertido. El stack completo (frontend + backend + BBDD) en un único sistema es el adecuado para demostrar administración web en ASIR, reduce dependencias de servicios externos y simplifica el despliegue en VPS propio.

### Componentes del tema

- `front-page.php` — Landing page con demo interactiva, formulario AJAX, pricing
- `page-docs.php` — Documentación técnica con sidebar navegable
- `page-changelog.php` — Historial de versiones con timeline visual
- `functions.php` — Lógica PHP: AJAX handlers, rate limiting, integración MantisBT

---

## 3. Gestión de incidencias — MantisBT

### Tecnología elegida

**MantisBT 2.x** (Bug Tracker de código abierto, PHP + MySQL).

### Evolución de versiones MantisBT

| Versión | Año | Hitos principales |
|---------|-----|-------------------|
| 1.0.x | 2002-2006 | Primera versión estable. Solo SOAP, sin REST. PHP 4. |
| 1.2.x | 2010-2014 | Campos personalizados, plugins básicos. PHP 5. |
| 1.3.x LTS | 2015-2018 | Última rama 1.x. Soporte extendido. Sin REST nativa. |
| 2.0.x | 2017 | Reescritura UI (Bootstrap), REST API v1 introducida, PHP 5.6+. |
| 2.4.x – 2.25.x | 2018-2023 | Mejoras incrementales: API OAuth, 2FA, JSON configurable. |
| **2.26.x LTS** | 2023-2024 | Long Term Support. PHP 8.1+. Soporte hasta 2025. |
| **2.27.x** | 2024-act. | Versión actual. PHP 8.2, MariaDB 10.6, mejoras API. Elegida para ResolveCore. |

**Por qué 2.27 y no 2.26 LTS:** La rama LTS garantiza parches de seguridad sin nuevas features. Para un entorno de producción de empresa, LTS sería la elección. Para un TFG donde se demuestran capacidades técnicas actuales, 2.27 incluye mejoras en la API REST que simplifican la integración con el plugin WordPress.

---

### Por qué MantisBT

| Criterio | MantisBT | Jira | GitLab Issues | Redmine | osTicket |
|----------|----------|------|---------------|---------|---------|
| Licencia | GPL (gratis) | Comercial (≥$8.15/user/mes) | GPL (gratis) | GPL (gratis) | GPL (gratis) |
| Autohospedaje | Sí | Cloud / Server costoso | Sí (GitLab CE) | Sí | Sí |
| REST API | Sí (v2+) | Sí | Sí | Sí (parcial) | No nativa |
| Curva de aprendizaje | Baja | Alta | Media | Media | Baja |
| Plugins disponibles | ~30 oficiales | Miles (pagos) | Integrado en GitLab | ~100 | ~20 |
| Workflow personalizable | Sí | Sí | Limitado | Sí | Sí |
| PHP nativo | Sí | No (Java) | No (Ruby/Go) | Sí | Sí |
| Integración GitHub | Plugin oficial | Sí | Nativo | Plugin | No |

**Razón principal:** MantisBT es la opción de bug tracker open-source más fácil de instalar en un VPS con PHP + MySQL (mismo stack que WordPress). Ofrece REST API completa desde la versión 2.0, flujo de estados configurable (new → assigned → resolved → closed), campos personalizados y un ecosistema de plugins suficiente para las necesidades de ResolveCore.

**Por qué no Jira:** Licencia comercial incompatible con un proyecto académico sin presupuesto. La complejidad de configuración supera las necesidades del TFG.

**Por qué no GitLab Issues:** Requeriría instalar GitLab completo (Ruby, Go, PostgreSQL, Redis, ~4GB RAM) solo para gestionar tickets. MantisBT ocupa <50MB y funciona en cualquier VPS básico.

**Por qué no Redmine:** Requiere Ruby on Rails, más complejo de administrar en entorno PHP. MantisBT encaja mejor con el stack PHP/MySQL del proyecto.

### Flujo de ticket en ResolveCore

```
new → acknowledged → assigned → resolved → closed
         ↑                          ↓
      feedback ←────────────────────┘
```

Campos personalizados añadidos:
- **Plataforma:** Windows / Linux / macOS / Android / Otro
- **AnyDesk ID:** identificador de sesión remota

---

## 4. Plugins MantisBT

### 4.1 source-integration

**Repositorio:** github.com/mantisbt-plugins/source-integration

**Función:** Vincula commits de GitHub con tickets MantisBT. Al incluir `fix #42` en un commit, el ticket #42 se marca automáticamente como resuelto y se adjunta el enlace al commit.

**Por qué:** Demuestra integración DevOps entre control de versiones y gestión de incidencias. Cubre el módulo ASIR de administración de sistemas y herramientas de desarrollo. Alternativa nativa no existe en MantisBT; este plugin es el estándar oficial.

**Configuración:** webhook en GitHub → `POST /mantis/plugin.php?page=Source/checkin`

---

### 4.2 MantisKanban

**Repositorio:** github.com/mantisbt-plugins/MantisKanban

**Función:** Añade una vista Kanban sobre los tickets del proyecto. Columnas: Nuevo / En proceso / Feedback / Resuelto / Cerrado.

**Por qué:** Visualización inmediata del estado de las incidencias durante la demo de defensa. El tribunal puede ver el flujo de trabajo en tiempo real. Alternativas como Trello o Azure Boards requieren servicios externos y no se integran con MantisBT.

---

### 4.3 SetDuedate

**Repositorio:** github.com/mantisbt-plugins/SetDuedate

**Función:** Asigna automáticamente fecha de vencimiento al crear un ticket, según su prioridad.

**Mapeo SLA ResolveCore:**

| Prioridad | Vencimiento |
|-----------|-------------|
| Inmediata | 1 hora |
| Urgente | 2 horas |
| Alta | 4 horas |
| Normal | 24 horas |
| Baja | 72 horas |

**Por qué:** Automatiza el SLA prometido en la landing page (`<2h de respuesta`). Sin este plugin, el técnico debe establecer la fecha manualmente en cada ticket. Ningún otro plugin MantisBT cubre esta funcionalidad.

---

### 4.4 Reminder

**Repositorio:** github.com/mantisbt-plugins/Reminder

**Función:** Envía notificaciones por email cuando un ticket lleva X horas sin cambio de estado.

**Por qué:** Garantiza que ningún ticket quede sin atender más del tiempo acordado en el SLA. Complementa SetDuedate con avisos proactivos. Funciona vía cron del servidor, sin depender de servicios externos.

---

### 4.5 mailtemplate

**Repositorio:** github.com/mantisbt-plugins/mailtemplate

**Función:** Sustituye los emails de texto plano de MantisBT por plantillas HTML con la identidad visual de ResolveCore.

**Por qué:** Los emails de notificación son el punto de contacto principal con el usuario. Emails HTML con el branding del proyecto (fondo oscuro, acento verde `#00e5a0`) ofrecen una imagen profesional coherente. MantisBT por defecto solo envía texto plano.

---

### 4.6 EventLog

**Repositorio:** github.com/mantisbt-plugins/EventLog

**Función:** Registra todos los eventos de MantisBT: logins, creación/modificación de tickets, cambios de configuración, subida de archivos.

**Por qué:** Trazabilidad y auditoría, requisito de seguridad del módulo ASIR. Permite demostrar que el sistema registra quién hizo qué y cuándo sobre cada incidencia. Cubre normativas de seguridad básica (control de acceso, registro de actividad). No existe funcionalidad equivalente en MantisBT sin este plugin.

---

## 5. Acceso remoto — AnyDesk

### Tecnología elegida

**AnyDesk** (acceso remoto por escritorio).

### Por qué AnyDesk

| Criterio | AnyDesk | TeamViewer | RustDesk | VNC | SSH |
|----------|---------|-----------|----------|-----|-----|
| Licencia uso personal/educativo | Gratuita | Gratuita (limitada) | Gratuita (OSS) | Gratuita | Gratuita |
| Rendimiento (codec DeskRT) | Muy alto | Alto | Medio | Bajo | N/A |
| Latencia en conexiones pobres | Muy baja | Baja | Media | Alta | N/A |
| Compatible Windows+Linux+Android | Sí | Sí | Sí | Sí (parcial) | Solo CLI |
| Instalación en cliente | Opcional (portable) | Requerida | Opcional | Requerida | Requerida |
| ID único por dispositivo | Sí | Sí | Sí | No | No |
| Transferencia de archivos | Sí | Sí | Sí | No nativa | Sí (SCP) |

**Razón principal:** AnyDesk ofrece la mejor relación rendimiento/coste para uso educativo. El codec DeskRT minimiza la latencia incluso en conexiones lentas, lo que es crítico para diagnóstico remoto en tiempo real. La versión portable no requiere instalación en el equipo del cliente.

**Por qué no TeamViewer:** Detecta uso "comercial" en sesiones largas y bloquea la conexión en la versión gratuita. Poco fiable para demos en entornos de evaluación.

**Por qué no RustDesk (auto-alojado):** Requiere configurar un servidor relay propio, añadiendo complejidad de infraestructura innecesaria para el alcance del TFG.

**Integración con MantisBT:** El ID de AnyDesk del cliente se almacena como campo personalizado en el ticket, permitiendo al técnico iniciar la sesión remota directamente desde MantisBT.

---

## 6. Scripts de diagnóstico — PowerShell / Bash

### Tecnología elegida

- **PowerShell 7+** para Windows
- **Bash (sh-compatible)** para Linux / macOS / Android

### Por qué PowerShell en Windows

| Criterio | PowerShell 7 | CMD / .bat | Python | WMI/WMIC |
|----------|-------------|-----------|--------|---------|
| Acceso a WMI/CIM | Nativo | Limitado | Via pywin32 | Nativo |
| Objetos estructurados | Sí (PSCustomObject) | No | Sí | Parcial |
| Salida JSON | `ConvertTo-Json` nativo | No | `json.dumps()` | No |
| Manejo de errores | try/catch robusto | Limitado | try/except | Limitado |
| Multiplataforma | Sí (PS7) | No | Sí | Solo Windows |
| Disponible sin instalación | Win 10/11 (PS5) | Siempre | No (Python 3) | Siempre |
| Integración con Windows Update | Sí | No | Via subprocess | Parcial |

**Razón principal:** PowerShell 7 proporciona acceso nativo a todas las APIs de Windows (WMI, CIM, Event Log, Windows Update, S.M.A.R.T.) con salida en objetos tipados que se serializan directamente a JSON. Ninguna otra shell en Windows ofrece esta integración sin dependencias adicionales.

### Por qué Bash en Linux/macOS/Android

| Criterio | Bash | Python | Perl | Zsh |
|----------|------|--------|------|-----|
| Disponible por defecto | Prácticamente siempre | No garantizado | No garantizado | No siempre |
| Dependencias | Ninguna | Python 3 instalado | Perl instalado | Ninguna |
| Llamadas a herramientas del sistema | Nativo | subprocess | system() | Nativo |
| Portabilidad sh-compatible | Sí | N/A | N/A | Parcial |
| Curva de aprendizaje ASIR | Baja | Media | Alta | Baja |

**Razón principal:** Bash garantiza funcionamiento en cualquier sistema Linux sin instalar nada. Los diagnósticos (CPU, RAM, disco, red, logs del sistema) se realizan llamando a herramientas estándar (`top`, `df`, `ss`, `journalctl`) que Bash orquesta directamente.

### Salida estructurada

Ambos scripts generan un objeto JSON común:

```json
{
  "metadata": { "platform": "Windows", "version": "3.0.0", "timestamp": "..." },
  "hardware":  { "cpu": {...}, "ram": {...}, "disk": [...], "battery": {...} },
  "os":        { "name": "...", "build": "...", "updates_pending": 3 },
  "security":  { "firewall": true, "av_active": true, "vulnerabilities": [...] },
  "network":   { "interfaces": [...], "open_ports": [...] },
  "score":     { "health": 87, "risk": "medium" }
}
```

---

## 7. Base de datos — MariaDB

### Tecnología elegida

**MariaDB 10.x** (fork de MySQL, motor InnoDB).

### Por qué MariaDB

| Criterio | MariaDB | MySQL 8 | PostgreSQL | SQLite |
|----------|---------|---------|-----------|--------|
| Compatibilidad MySQL | Casi total | N/A | Parcial | Parcial |
| Licencia | GPL (100% libre) | GPL + Oracle | PostgreSQL | Dominio público |
| Rendimiento lectura | Alto | Alto | Muy alto | Medio |
| Instalación en VPS Linux | Estándar | Común | Menos común | N/A (embebido) |
| Requerido por WordPress | Compatible | Oficial | No | No |
| Requerido por MantisBT | Compatible | Oficial | Soportado | No |
| Comunidad Española / documentación | Amplia | Amplia | Media | Media |

**Razón principal:** MariaDB es el motor predeterminado en la mayoría de distribuciones Linux (Debian, Ubuntu). Es 100% compatible con WordPress y MantisBT, tiene licencia GPL sin restricciones comerciales de Oracle, y su rendimiento es equivalente o superior a MySQL 8 para las cargas de trabajo del proyecto.

**Por qué no PostgreSQL:** MantisBT lo soporta pero WordPress requiere plugins adicionales para PostgreSQL. La combinación MariaDB sirve a ambas aplicaciones sin fricción adicional.

**Tablas personalizadas ResolveCore:**

| Tabla | Contenido |
|-------|-----------|
| `rc_vulnerabilities` | CVEs: id, cve_id, gravedad, SO afectado, descripción, fix |
| `rc_tickets_log` | Historial extendido de tickets (complementa MantisBT) |

---

## 8. Servidor web — Nginx + PHP-FPM

### Tecnología elegida

**Nginx 1.x** + **PHP-FPM 8.2+** en VPS Linux (Ubuntu 22.04 LTS).

### Por qué Nginx

| Criterio | Nginx | Apache 2.4 | Caddy | Lighttpd |
|----------|-------|-----------|-------|---------|
| Rendimiento bajo carga | Muy alto (event-driven) | Alto (process-based) | Alto | Alto |
| Consumo de memoria | Bajo | Medio | Bajo | Bajo |
| Configuración para WordPress | Estándar | .htaccess nativo | Automática | Manual |
| SSL/TLS automático (Let's Encrypt) | Certbot | Certbot | Nativo | Manual |
| Proxy reverso | Excelente | Bueno | Bueno | Limitado |
| Documentación | Muy amplia | Muy amplia | Buena | Media |
| Popularidad servidores VPS | 1º | 2º | 3º | Residual |

**Razón principal:** Nginx maneja concurrencia con bajo consumo de memoria frente a Apache, que crea un proceso/hilo por conexión. Para un VPS con recursos limitados, Nginx permite servir WordPress y MantisBT simultáneamente sin degradación de rendimiento.

### Por qué PHP-FPM

PHP-FPM (FastCGI Process Manager) gestiona un pool de workers PHP independiente del servidor web. Ventajas frente a `mod_php` (integrado en Apache):

- Cada aplicación (WordPress, MantisBT) puede tener su propio pool con usuario Unix distinto
- Reinicio del pool PHP sin reiniciar Nginx
- Control de recursos por pool (max_children, max_requests)

### Por qué Ubuntu 22.04 LTS

- Soporte hasta abril 2027 (más que suficiente para el ciclo de vida del TFG)
- Repositorios oficiales incluyen PHP 8.2, MariaDB 10.6, Nginx actual
- La mayoría de VPS providers ofrecen imagen preconfigurada

---

## 9. Integración REST — MantisBT API

### Tecnología elegida

**MantisBT REST API v1** (JSON sobre HTTP, autenticación por token).

### Flujo de integración

```
WordPress (functions.php)
  → rc_mantis_create_ticket($data)          [plugin rc-mantisbt]
    → RC_Mantis_API::create_issue($body)    [class-mantis-api.php]
      → wp_remote_request(POST /api/rest/issues, Authorization: Token X)
        → MantisBT                          [crea ticket, devuelve ID]
      ← { "issue": { "id": 42 } }
    ← 42
  ← JSON: { success: true, ticket_id: 42, msg: "Ticket #42 creado" }
← JS muestra "[VER TICKET #42]" en el formulario
```

### Por qué REST sobre otras opciones

| Opción | Ventajas | Desventajas |
|--------|----------|-------------|
| REST API (JSON) | Estándar, simple, sin dependencias extra | — |
| SOAP API (MantisBT legacy) | Compatible versiones antiguas | Verboso, obsoleto desde MantisBT 2.0 |
| Acceso directo a BD | Sin latencia de red | Acoplamiento fuerte, rompe con actualizaciones |
| Email-to-ticket (plugin) | Sin código | No devuelve ticket ID al formulario WP |

---

## 10. Control de versiones — Git / GitHub

### Tecnología elegida

**Git** con repositorio remoto en **GitHub**.

### Por qué GitHub

| Criterio | GitHub | GitLab.com | Bitbucket | Gitea (self-hosted) |
|----------|--------|-----------|-----------|-------------------|
| Integración con MantisBT | Plugin oficial (source-integration) | Plugin oficial | No oficial | No oficial |
| CI/CD gratuito | GitHub Actions | GitLab CI (300 min/mes) | Pipelines (50 min/mes) | Requiere Gitea Actions |
| Visibilidad del proyecto (TFG) | Máxima | Alta | Media | Ninguna (privado) |
| Issues, PRs, Releases | Sí | Sí | Sí | Sí |

**Razón principal:** El plugin `source-integration` de MantisBT tiene soporte oficial para GitHub, lo que permite vincular commits con tickets automáticamente. GitHub es además la plataforma con mayor visibilidad para mostrar el proyecto al tribunal.

### Convención de commits

```
<tipo>(<ámbito>): <descripción>

feat(mantisbt): add SetDuedate SLA configuration
fix(scripts): correct PowerShell disk health parsing
docs(stack): add technology justification document
```

### Estrategia de ramas

```
main          ← producción estable
feat/<nombre> ← nuevas funcionalidades
fix/<nombre>  ← correcciones
docs/<nombre> ← documentación
060526        ← rama actual de desarrollo (defensa 5 junio 2026)
```

---

## 11. Generación de informes — PDF

### Estado actual

En desarrollo. Las opciones evaluadas son:

### Opciones comparadas

| Librería | Lenguaje | Calidad | Instalación | Licencia |
|---------|----------|---------|-------------|---------|
| **DomPDF** | PHP | Alta | `composer require dompdf/dompdf` | LGPL |
| **mPDF** | PHP | Muy alta | `composer require mpdf/mpdf` | GPL |
| **wkhtmltopdf** | Binario | Muy alta (Webkit real) | Binario en servidor | LGPL |
| **TCPDF** | PHP | Media | `composer require tecnickcom/tcpdf` | LGPL |
| **Puppeteer** | Node.js | Muy alta | pnpm + Chrome headless | MIT |

**Decisión prevista:** DomPDF o mPDF (PHP nativo, sin binarios externos). wkhtmltopdf produce la mejor calidad pero requiere instalar un binario en el VPS y tiene mantenimiento discontinuado desde 2023.

**Secciones del informe (obligatorias por diseño):**

1. Resumen ejecutivo
2. Incidencias detectadas
3. Problemas solucionados
4. Estado actual del sistema
5. Recomendaciones
6. Proyección de vida útil del hardware

---

## 12. Futuro — App Android

### Tecnología prevista

**Kotlin + Jetpack Compose + Material 3** (nativa Android).

### Por qué nativo sobre otras opciones

| Criterio | Kotlin/Compose | Flutter | PWA |
|----------|---------------|---------|-----|
| Acceso a APIs Android (ADB, diagnóstico) | Total | Parcial (plugins) | Muy limitado |
| Rendimiento | Máximo | Alto | Bajo |
| Material Design 3 | Nativo | Parcial | Via CSS |
| Alineación con ecosistema Android | Total | Parcial | Ninguna |
| Mantenimiento Google | Sí | Sí | Estándar web |

**Razón:** Los diagnósticos Android requieren acceso a APIs nativas (batería, almacenamiento, red, ADB) que solo Kotlin/Android SDK expone completamente. Fase planificada para después de la defensa del TFG.

---

## 13. Auditoría de exposición — Shodan

### Tecnología elegida

**Shodan API REST** (free tier) + módulo Python `shodan_lookup.py` (stdlib, sin `pip install shodan`).

### Por qué Shodan

| Criterio | Shodan | Censys | Fofa | Nmap (local) |
|----------|--------|--------|------|---------------|
| Datos históricos de internet | Sí | Sí | Sí | No |
| Free tier útil | 100 créditos/mes | 250 queries/mes | Limitado | N/A |
| CVEs en respuesta | Sí (campo `vulns`) | Sí | Parcial | No |
| API REST simple | Sí | Sí (más compleja) | Sí | N/A |
| Sin instalación en cliente | Sí | Sí | Sí | No |
| Referencia en ASIR/ciberseguridad | Alta | Media | Baja | Alta |

**Razón principal:** Shodan indexa puertos, banners de servicios y CVEs detectados pasivamente para cualquier IP pública. Permite a ResolveCore ofrecer un informe de exposición sin instalar nada en el equipo del cliente. El free tier (100 créditos/mes, 1 crédito por IP) es suficiente para el TFG.

**Implementación:** `scripts/common/shodan_lookup.py` — Python 3.8+ stdlib, sin dependencias pip. Lee `SHODAN_API_KEY` desde variable de entorno o `.env` local.

```
python shodan_lookup.py --ip 8.8.8.8
python shodan_lookup.py --ip 1.1.1.1 --json
```

**Integración en el catálogo:** Auditoría de exposición Shodan → 30 €/IP/informe → `shodan_lookup.py` genera el JSON que `generar_informe.py` formatea en PDF.

---

## 14. Clonado e imágenes de SO

### Herramientas comparadas

| Herramienta | Tipo | Licencia | Red/Local | SO soportados | Curva | Coste |
|-------------|------|---------|-----------|--------------|-------|-------|
| **Clonezilla Live** | Live USB | GPL | Local (USB/NFS/SFTP) | Windows, Linux, macOS | Baja-Media | Gratis |
| **FOG Project** | Servidor PXE | GPL | Red (LAN) | Windows, Linux | Media | Gratis |
| **WDS + MDT** | Servicio Windows Server | Incluido en Win Server | Red (PXE) | Solo Windows | Alta | Win Server |
| **Veeam Agent Free** | Agente | Freemium | Local + NFS/SMB | Windows, Linux | Baja | Gratis |
| **Acronis Cyber Backup** | Agente + consola | Comercial | Local + Cloud | Windows, Linux | Baja | ~150 €/equipo/año |

### Criterios de elección para ResolveCore

```
Un equipo o intervención puntual     → Clonezilla Live (USB)
Flota mixta >5 equipos (aulas, PYME) → FOG Project
Entorno Windows AD corporativo        → WDS + MDT
Backup programado en producción       → Veeam Agent Free
```

### Casos de uso empresariales

| Escenario | Herramienta elegida | Beneficio |
|-----------|--------------------|-----------|
| Incorporación de nuevo empleado | FOG Project | Imagen corporativa en <20 min |
| Restauración post-ransomware | Clonezilla / Veeam | Vuelta a imagen limpia sin pagar rescate |
| Migración HDD → SSD | Clonezilla | Sector a sector, sin reinstalar SO |
| Actualización de SO en flota | FOG Project | Imagen actualizada → despliegue masivo en LAN |
| Backup previo a intervención mayor | Veeam Agent Free | Punto de restauración antes de cambios |

### Posición en el catálogo ResolveCore

- **Clonación puntual:** 30-60 €/equipo — Clonezilla Live, técnico con USB en cliente
- **Despliegue de imagen en flota:** 15-30 €/equipo — FOG Project (mínimo 3 equipos)
- Ambos servicios se documentan en `docs/servicios-adicionales.md` § 2 y § 6

---

## 15. Seguridad en cliente — Cifrado y gestores

### 15.1 Cifrado de disco

| Herramienta | SO | Licencia | TPM | Algoritmo | Recuperación | Caso de uso |
|-------------|-----|---------|-----|-----------|--------------|-------------|
| **BitLocker** | Windows Pro/Ent | Incluido | Opcional (recomendado) | AES-256-XTS | Clave 48 dígitos | Portátiles corporativos |
| **LUKS (dm-crypt)** | Linux | GPL (kernel) | No | AES-256-XTS | Header de recuperación | Servidores y estaciones Linux |
| **VeraCrypt** | Windows/Linux/macOS | Apache 2.0 | No | AES/Twofish/Serpent | Disco de rescate | Multiplataforma, contenedores cifrados |
| **ecryptfs** | Linux | GPL | No | AES-256 | — | Solo directorio home, sin reinstalar |

**Criterios de elección:**

```
Empresa con Win Pro/Ent + TPM 2.0 → BitLocker (sin coste, integración nativa)
Usuario doméstico con Win Home    → VeraCrypt (gratuito, open source)
Servidor Linux (instalación nueva) → LUKS durante instalación del SO
Portátil Linux sin reinstalar      → VeraCrypt contenedor o ecryptfs home
```

**Por qué no DiskCryptor:** sin mantenimiento activo desde 2014. VeraCrypt lo sustituye con soporte multiplataforma y auditorías de seguridad recientes (2016, 2020).

### 15.2 Gestores de contraseñas

| Gestor | Licencia | Almacenamiento | Sync | 2FA | Compartir | Auditoría | Precio |
|--------|---------|---------------|------|-----|-----------|-----------|--------|
| **Bitwarden** | AGPL (OSS) | Cloud o self-hosted | ✅ | ✅ | ✅ Teams | ✅ | Gratis / 10 €/año Premium |
| **KeePassXC** | GPL | Local (`.kdbx`) | Manual (Dropbox/NAS) | ✅ (TOTP) | ❌ nativo | ❌ nativo | Gratis |
| **1Password** | Propietario | Cloud | ✅ | ✅ | ✅ | ✅ | ~3 €/mes |
| **Dashlane** | Propietario | Cloud | ✅ | ✅ | ✅ | ✅ | ~4 €/mes |

**Decisión para clientes ResolveCore:**

| Perfil cliente | Gestor recomendado | Razón |
|---------------|-------------------|---------|
| Usuario doméstico / autónomo | Bitwarden free | Sync automático, app móvil, sin coste |
| PYME (2-10 personas) | Bitwarden Teams | Compartir contraseñas + auditoría de accesos |
| Máxima seguridad / sin cloud | KeePassXC + NAS | Sin dependencia de terceros |

**Por qué Bitwarden sobre alternativas de pago:** código auditado públicamente (auditorías independientes 2018, 2020, 2022), opción self-hosted (Vaultwarden en VPS propio para clientes con requisitos GDPR estrictos), importación desde LastPass, 1Password o CSV.

**Integración en ResolveCore:** recomendación documentada en el informe PDF de auditoría generado por `generar_informe.py`. Se incluye en la sección "Recomendaciones de seguridad" del informe de cada cliente.

---

## 16. Resumen comparativo

| Componente | Elegido | Alternativa principal | Razón del descarte |
|-----------|---------|----------------------|-------------------|
| CMS | WordPress Business | CMS custom PHP | Tiempo de desarrollo, plugins, comunidad |
| Bug tracker | MantisBT 2.27 | Jira | Coste, complejidad, PHP incompatible |
| Acceso remoto | AnyDesk | TeamViewer | Bloqueo sesiones largas en free |
| Scripts Windows | PowerShell 7 | Python | No requiere instalación adicional |
| Scripts Linux | Bash | Python | Universal, sin dependencias |
| Base de datos | MariaDB | MySQL 8 | WordPress + MantisBT, mismo stack, GPL pura |
| Servidor web | Nginx + PHP-FPM | Apache | Mejor rendimiento, menor consumo RAM |
| Kanban | MantisKanban | Trello | Integración nativa MantisBT |
| VCS integration | source-integration | Manual | Plugin oficial, webhooks automáticos |
| SLA automático | SetDuedate | Manual | Automatiza promesa <2h |
| PDF (previsto) | DomPDF/mPDF | wkhtmltopdf | Sin mantenimiento desde 2023 |
| App Android (futuro) | Kotlin/Compose | Flutter | Acceso total a APIs nativas Android |
| Auditoría exposición | Shodan API | Censys | Free tier más generoso, CVEs en respuesta |
| Clonación puntual | Clonezilla Live | Macrium Reflect | GPL, multiplataforma (Linux/Windows/macOS) |
| Despliegue en flota | FOG Project | WDS + MDT | No requiere Windows Server, multiplataforma |
| Cifrado Windows | BitLocker / VeraCrypt | DiskCryptor | Sin mantenimiento activo |
| Cifrado Linux | LUKS | ecryptfs | Cifrado completo de disco, estándar |
| Gestor contraseñas | Bitwarden | 1Password | OSS, self-hosted, auditorías públicas |

---

*Documento generado en el contexto del TFG ASIR 2024/25 — ResolveCore.*  
*Stack diseñado para máxima coherencia entre componentes, mínimo coste operativo y cobertura completa de los módulos del ciclo formativo.*
