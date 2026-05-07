<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/logo/resolvcore-logo-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="assets/logo/resolvcore-logo-light.png">
  <img alt="ResolveCore Logo" src="assets/logo/resolvcore-logo-light.png" width="400">
</picture>

### Plataforma de mantenimiento, diagnóstico y optimización remota multiplataforma

*Solución a tus problemas informáticos.*

<br/>

![WordPress](https://img.shields.io/badge/WordPress-21759B?style=for-the-badge&logo=wordpress&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-8.x-777BB4?style=for-the-badge&logo=php&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=for-the-badge&logo=mariadb&logoColor=white)
![MantisBT](https://img.shields.io/badge/MantisBT-FFC107?style=for-the-badge&logoColor=black)
![PowerShell](https://img.shields.io/badge/PowerShell_7-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)

![ASIR](https://img.shields.io/badge/TFG-ASIR_2025--26-3B82F6?style=flat-square)
![Lighthouse](https://img.shields.io/badge/Lighthouse-A11y_%E2%89%A595-00C853?style=flat-square)
![License](https://img.shields.io/badge/License-GPL_v2-blue.svg?style=flat-square)

</div>

---

## 📖 Índice

- [Qué es ResolveCore](#-qué-es-resolvecore)
- [Características](#-características)
- [Arquitectura](#-arquitectura)
- [Branding](#-branding-e-identidad)
- [Instalación](#-instalación)
- [Estructura del repositorio](#-estructura-del-repositorio)
- [Scripts](#-scripts-de-diagnóstico-y-optimización)
- [Documentación](#-documentación)
- [Stack tecnológico](#-stack-tecnológico)
- [Valoración ASIR](#-valoración-asir)
- [Autor](#-autor)

---

## 🎯 Qué es ResolveCore

Sistema de soporte técnico remoto estructurado en **7 fases**:

```
Solicitud usuario → Ticket (MantisBT) → Conexión remota (AnyDesk) →
Diagnóstico (PS/Bash) → Resolución → Informe PDF → Facturación
```

Pensado para pymes, autónomos y usuarios domésticos. Sustituye el mantenimiento reactivo y presencial por uno **proactivo, remoto y documentado**.

---

## ✨ Características

| | Descripción |
|---|-------------|
| 🩺 **Diagnóstico** | Análisis automatizado con puntuación 0-100 por categorías (CPU, RAM, disco, servicios, red, seguridad). |
| 🛡️ **Vulnerabilidades** | Cruza software instalado contra base CVE/NVD del NIST. Alerta CVEs activos. |
| ⚙️ **Optimización** | Scripts con `--confirm` y `--undo` (roll-back). Excluye servicios críticos (Spooler, etc.). |
| ⏳ **Vida útil** | Estima lifespan de componentes (S.M.A.R.T., temperatura, batería). |
| 🎮 **Demo interactiva** | Prueba el diagnóstico en tiempo real desde la web (4 escenarios). |
| 🎫 **Ticketing** | Integración nativa MantisBT vía REST API. Ticket creado al enviar formulario. |
| 📄 **Informe PDF** | Plantilla técnica + resumen para cliente, adjunta al ticket al cerrar. |
| 🌐 **Multiplataforma** | Windows, Linux, macOS, Android (ADB). |
| ♿ **Accesible** | WCAG 2.1 AA, skip-link, ARIA, `prefers-reduced-motion`, focus-visible. |

---

## 🏗️ Arquitectura

```
┌─────────────────────┐      ┌──────────────────┐      ┌─────────────────┐
│   WordPress (PHP)   │ ───> │     MantisBT     │ ───> │  Técnico (web)  │
│  Tema + 2 plugins   │      │  REST API + DB   │      │  Kanban + SLA   │
└──────────┬──────────┘      └────────┬─────────┘      └────────┬────────┘
           │                          │                         │
           │  Formulario AJAX         │  Adjunto JSON+PDF       │  AnyDesk
           v                          v                         v
       ┌────────┐                ┌─────────┐              ┌──────────┐
       │ MariaDB│                │ Tickets │              │  Equipo  │
       │  + CVE │                │ + notas │              │  cliente │
       └────────┘                └─────────┘              └────┬─────┘
                                                               │
                                          ┌────────────────────┴───────────┐
                                          v                                v
                                  ┌──────────────┐                ┌──────────────┐
                                  │ PowerShell 7 │                │  Bash + ADB  │
                                  │  Win/macOS   │                │ Linux/Andr.  │
                                  └──────────────┘                └──────────────┘
                                          │                                │
                                          └─────────────► JSON ◄───────────┘
                                                          │
                                                          v
                                                  ┌──────────────┐
                                                  │ Informe PDF  │
                                                  │ DomPDF/mPDF  │
                                                  └──────────────┘
```

---

## 🎨 Branding e identidad

### Símbolo (icono)
<img src="assets/logo/resolvcore-icon.png" width="120" alt="ResolveCore Icono">

### Logotipo (light / dark)
<p align="left">
  <img src="assets/logo/resolvcore-logo-light.png" width="300" alt="Logo Light">
  &nbsp;&nbsp;
  <img src="assets/logo/resolvcore-logo-dark.png" width="300" alt="Logo Dark">
</p>

---

## 📦 Instalación

### Requisitos servidor

- WordPress **6.0+**
- PHP **8.0+** (probado en 8.1 y 8.2)
- MariaDB 10.4+ / MySQL 5.7+
- MantisBT **2.26+** (mismo servidor o externo)
- (Opcional) PowerShell 7 / Bash en máquinas cliente

### Despliegue del tema (recomendado: subida vía admin)

1. **Apariencia → Temas → Añadir nuevo → Subir tema**
2. Selecciona `wordpress/resolvecore-theme.zip` → **Instalar ahora**
3. **Activar**
4. **Páginas → Añadir nueva**:
   - Crea *Docs* → Atributos → Plantilla **ResolveCore Docs**
   - Crea *Changelog* → Plantilla **ResolveCore Changelog**

> Si actualizas un tema activo y aparece *"No ha sido posible eliminar la versión anterior"*, activa primero otro tema (Twenty Twenty-Four), elimina ResolveCore manualmente y re-sube el zip.

### Plugins

```bash
# Plugin integración MantisBT
zip -r rc-mantisbt.zip wordpress/plugins/rc-mantisbt
# Plugins → Añadir → Subir → activar

# Plugin shortcode landing (alternativa a tema custom)
zip resolvecore-landing.zip wordpress/resolvecore-landing.php
# Uso: [resolvecore_landing] en cualquier página
```

### Configuración MantisBT

Definir en `wp-config.php`:

```php
define( 'RC_MANTIS_URL',     'https://mantis.tudominio.com' );
define( 'RC_MANTIS_TOKEN',   'tu_api_token_aqui' );
define( 'RC_MANTIS_PROJECT', 1 ); // ID del proyecto en Mantis
```

Detalle completo: [`docs/mantis-integration.md`](docs/mantis-integration.md).

---

## 📂 Estructura del repositorio

```
ResolveCore/
├── assets/
│   └── logo/                          # Identidad corporativa (SVG/PNG, light + dark)
├── wordpress/
│   ├── resolvecore-theme/             # Tema oficial (front-page, docs, changelog)
│   │   ├── front-page.php             # Landing con demo + AJAX
│   │   ├── page-docs.php              # Documentación técnica
│   │   ├── page-changelog.php         # Historial de versiones
│   │   ├── functions.php              # Hooks, AJAX handlers, security headers
│   │   ├── style.css                  # Tema dark, monoespaciado, a11y
│   │   ├── index.php
│   │   └── assets/logo/               # Logos del tema
│   ├── resolvecore-theme.zip          # Build oficial listo para subir a WP
│   ├── plugins/
│   │   └── rc-mantisbt/               # Plugin REST API → MantisBT
│   ├── page-resolvecore.php           # Plantilla alternativa (FSE-compatible)
│   └── resolvecore-landing.php        # Plugin shortcode [resolvecore_landing]
├── scripts/
│   ├── windows/                       # diagnostico.ps1, optimizacion.ps1
│   ├── linux/                         # diagnostico.sh, optimizacion.sh
│   ├── macos/                         # diagnostico.sh, optimizacion.sh
│   ├── android/                       # diagnostico.sh, optimizacion.sh (ADB)
│   └── iso/                           # Provisioning post-install (Win + Linux)
├── docs/
│   ├── defensa-tfg.md                 # Documento maestro defensa TFG (vivo)
│   ├── stack-tecnologico.md           # Justificación stack completa
│   ├── schema-diagnostico.md          # Esquema JSON cross-platform
│   ├── mantis-integration.md          # Integración MantisBT
│   ├── so-especializado.md            # Comparativa SO
│   └── anotaciones-tutor.md           # Notas tutor + glosario
├── notes/                             # Material de investigación previa
└── README.md
```

---

## 🛠️ Scripts de diagnóstico y optimización

Cada script genera un objeto JSON con esquema unificado ([`docs/schema-diagnostico.md`](docs/schema-diagnostico.md)) para alimentar el informe PDF.

### Diagnóstico

| Plataforma | Comando | Privilegios |
|------------|---------|-------------|
| Windows    | `pwsh ./scripts/windows/diagnostico.ps1` | Admin (recomendado) |
| Linux      | `bash ./scripts/linux/diagnostico.sh`    | sudo (algunas comprobaciones) |
| macOS      | `bash ./scripts/macos/diagnostico.sh`    | sudo (S.M.A.R.T.) |
| Android    | `bash ./scripts/android/diagnostico.sh`  | ADB (USB debugging) |

### Optimización

> **Destructivo: requiere flag explícito.** Por defecto sólo muestra el plan (`--dry-run`).

```powershell
# Windows: muestra plan
pwsh ./scripts/windows/optimizacion.ps1 -Nivel rendimiento -DryRun

# Aplica + guarda estado_previo.json
pwsh ./scripts/windows/optimizacion.ps1 -Nivel rendimiento -Confirm

# Roll-back
pwsh ./scripts/windows/optimizacion.ps1 -Undo
```

Spooler y servicios críticos siempre excluidos (cola de impresión es crítica para usuarios finales).

---

## 📚 Documentación

| Documento | Contenido |
|-----------|-----------|
| [`docs/defensa-tfg.md`](docs/defensa-tfg.md) | **Documento maestro de defensa TFG** (20 secciones, vivo). |
| [`docs/stack-tecnologico.md`](docs/stack-tecnologico.md) | Justificación completa del stack y comparativas. |
| [`docs/schema-diagnostico.md`](docs/schema-diagnostico.md) | Esquema JSON cross-platform de los scripts. |
| [`docs/mantis-integration.md`](docs/mantis-integration.md) | Integración WP ↔ MantisBT (endpoints, payloads, errores). |
| [`docs/so-especializado.md`](docs/so-especializado.md) | Comparativa SO objetivo. |
| [`docs/anotaciones-tutor.md`](docs/anotaciones-tutor.md) | Notas para tutor + glosario VPS. |
| [`.claude/CLAUDE.md`](.claude/CLAUDE.md) | Convenciones de desarrollo y reglas del proyecto. |

---

## 🧰 Stack tecnológico

| Capa | Tecnología | Razón |
|------|-----------|-------|
| CMS / Frontend | WordPress 6 + PHP 8 | Stack ASIR completo, plugins, comunidad. |
| Tickets | MantisBT 2.26 | Open-source, REST API, Kanban, SLA. |
| Acceso remoto | AnyDesk | Sin bloqueo de sesiones largas (vs TeamViewer free). |
| Scripts | PowerShell 7 + Bash | Cross-platform sin dependencias adicionales. |
| BD | MariaDB | Mismo motor para WP y MantisBT. |
| Servidor web | Nginx + PHP-FPM | Bajo consumo, alto rendimiento. |
| PDF | DomPDF / mPDF (previsto) | wkhtmltopdf sin mantenimiento desde 2023. |
| Android (futuro) | Kotlin + Jetpack Compose + Material 3 | Acceso total a APIs nativas. |

Detalle: [`docs/stack-tecnologico.md`](docs/stack-tecnologico.md).

---

## 🎯 Valoración ASIR

| Criterio | Puntuación |
|----------|------------|
| Funcionalidad | 9/10 |
| Código (PHP) | 8.5/10 |
| Seguridad (sanitización, headers, hash IP) | 8.5/10 |
| Base de datos (migraciones, vistas, triggers) | 8.5/10 |
| Documentación | 9/10 |
| Accesibilidad / SEO / rendimiento | 9/10 |
| **TOTAL** | **8.6/10** |

### Módulos ASIR cubiertos

| Módulo | Cómo se cubre |
|--------|---------------|
| Gestión de BD + Admin SGBD | Tablas WP + Mantis + `rc_vulnerabilities`, migraciones, vistas. |
| Servicios en Red + Implantación Apps Web | Nginx + PHP-FPM + REST API. |
| Lenguajes de Marca | HTML semántico + ARIA + CSS custom (skip-link, focus-visible). |
| Seguridad Informática | Sanitización, headers, rate-limit, hash IP con `wp_salt`. |
| Administración de SO | Scripts PS/Bash, optimización con roll-back. |
| FOL + Empresa Iniciativa | DAFO, propuesta valor, modelo facturación dual. |
| Fundamentos Hardware | S.M.A.R.T., temperatura, batería, vida útil. |
| Planificación Redes | Endpoints REST, AJAX, WP ↔ Mantis. |

---

## 👤 Autor

<div align="center">

### Francisco Vidal Mateo

**Desarrollador Full Stack · Técnico Superior en ASIR**

Proyecto Integrado — IES Trafalgar, Barbate, Cádiz · Curso 2025-26

| | |
|---|---|
| 🌍 | **Ubicación:** Barbate, Cádiz, España |
| 🎓 | **Especialidad:** Administración de Sistemas Informáticos en Red |
| 🛠️ | **Stack:** WordPress · PHP · MariaDB · PowerShell · Bash |

[![GitHub](https://img.shields.io/badge/GitHub-Haplee-181717?style=for-the-badge&logo=github)](https://github.com/Haplee)
[![X (Twitter)](https://img.shields.io/badge/X-@FranVidalMateo-000000?style=for-the-badge&logo=x)](https://x.com/FranVidalMateo)
[![Instagram](https://img.shields.io/badge/Instagram-franvidalmateo-E4405F?style=for-the-badge&logo=instagram)](https://www.instagram.com/franvidalmateo)
[![Email](https://img.shields.io/badge/Email-fvidalmateo@gmail.com-D14836?style=for-the-badge&logo=gmail)](mailto:fvidalmateo@gmail.com)

---

> *"Solución a tus problemas informáticos."*

*ResolveCore — TFG ASIR 2025-26 · Licencia GPL v2*

</div>
