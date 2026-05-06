# ResolveCore — CLAUDE.md

> Plataforma de mantenimiento y optimización remota para equipos Windows, Linux y Android.
> Eslogan: "Solución a tus problemas informáticos." — Francisco Vidal Mateo

---

## Descripción del proyecto

ResolveCore es un sistema de soporte técnico remoto estructurado en 7 fases:
solicitud del usuario → ticket (MantisBT) → conexión remota (AnyDesk) → diagnóstico
(PowerShell / Bash) → resolución → informe PDF → facturación.

El proyecto se implementa sobre WordPress (frontend de soporte) + MantisBT (gestión
de incidencias) + scripts de diagnóstico multiplataforma + generación automática
de informes PDF.

---

## Stack técnico

- **CMS / Frontend:** WordPress (PHP)
- **Tickets:** MantisBT
- **Acceso remoto:** AnyDesk
- **Scripts diagnóstico:** PowerShell (Windows), Bash (Linux / macOS)
- **Generación de informes:** PDF automatizado
- **Base de datos de vulnerabilidades:** MySQL / MariaDB
- **Android (futuro):** Kotlin + Jetpack Compose + Material 3

Para la parte web usa PHP moderno. No mezcles jQuery con vanilla JS sin motivo.
Para los scripts, usa PowerShell 7+ en Windows y Bash compatible con sh en Linux.

---

## Comandos esenciales

```bash
# WordPress local (si usas DevKinsta / wp-cli)
wp server --host=0.0.0.0 --port=8080

# Ejecutar script de diagnóstico Windows (PowerShell)
pwsh ./scripts/windows/diagnostico.ps1

# Ejecutar script de diagnóstico Linux
bash ./scripts/linux/diagnostico.sh

# Generar informe PDF (cuando esté implementado)
php artisan resolvecore:report --ticket=ID

# Tests (cuando existan)
composer test
```

---

## Arquitectura del proyecto

```
resolvecore/
├── wordpress/          # Tema + plugins personalizados
│   ├── theme/          # Tema ResolveCore (PHP + CSS)
│   └── plugins/        # Plugin de integración MantisBT
├── scripts/
│   ├── windows/        # Scripts PowerShell de diagnóstico
│   └── linux/          # Scripts Bash de diagnóstico
├── reports/            # Plantillas y generación de informes PDF
├── vulnerabilities/    # Base de datos de vulnerabilidades (SQL + seeders)
├── android/            # App nativa (Kotlin, fase futura)
└── docs/               # Documentación técnica
```

---

## Convenciones de código

### PHP / WordPress
- Sigue los estándares de WordPress Coding Standards (WPCS).
- Usa prefijo `rc_` en todas las funciones y opciones del plugin.
- Sanitiza siempre los inputs con `sanitize_text_field()` / `intval()`.
- Escapa siempre los outputs con `esc_html()` / `esc_attr()`.
- YOU MUST never store sensitive data (contraseñas, tokens) en opciones de WordPress sin cifrar.

### PowerShell
- Usa `#Requires -Version 7.0` al inicio de cada script.
- Maneja errores con `try/catch` y escribe al log con `Write-EventLog` o fichero.
- Los scripts de diagnóstico deben devolver un objeto `[PSCustomObject]` estructurado.
- IMPORTANT: nunca ejecutes comandos destructivos sin confirmación explícita del técnico.

### Bash
- `#!/usr/bin/env bash` en todos los scripts. `set -euo pipefail`.
- Variables en UPPER_CASE. Funciones en snake_case.
- Comprueba dependencias al inicio con `command -v <tool> || exit 1`.

### SQL
- Tablas con prefijo `rc_`. Ej.: `rc_tickets`, `rc_vulnerabilities`.
- Usa migraciones idempotentes (IF NOT EXISTS, IF EXISTS).

---

## Módulos principales

### 1. Diagnóstico multiplataforma
- Windows: rendimiento (CPU/RAM/disco), servicios críticos, logs de eventos, Windows Update.
- Linux: top/htop, journalctl, df, apt/dnf, cron, puertos abiertos.
- Salida estructurada JSON para alimentar el generador de informes.

### 2. Base de datos de vulnerabilidades
- Tabla `rc_vulnerabilities`: CVE, gravedad, SO afectado, descripción, fix.
- Script de sincronización con NVD/NIST (cron semanal).
- Los scripts de diagnóstico consultan esta tabla para alertar al técnico.

### 3. Informe técnico PDF
- Plantilla HTML → PDF via wkhtmltopdf o DomPDF.
- Secciones fijas: resumen ejecutivo, incidencias detectadas, problemas solucionados,
  estado actual del sistema, recomendaciones, proyección de vida útil del equipo.
- Se adjunta automáticamente al ticket en MantisBT al cerrar la incidencia.

### 4. Modelo de facturación
- **Pago por servicio:** genera factura por intervención al cerrar ticket.
- **Suscripción:** revisiones programadas vía cron + notificación automática al usuario.

---

## Reglas de comportamiento para Claude Code

- Cuando modifiques un script de diagnóstico, SIEMPRE actualiza el esquema JSON de salida en `docs/schema-diagnostico.md`.
- Antes de crear una nueva tabla SQL, comprueba si ya existe en `vulnerabilities/migrations/`.
- Los scripts destructivos (limpiar disco, desinstalar, eliminar) requieren flag `--confirm` explícito.
- No generes datos de prueba con IPs, MACs o emails reales. Usa fixtures ficticios.
- Al añadir una nueva fase al flujo del sistema, actualiza el diagrama en `docs/flujo-sistema.md`.
- YOU MUST seguir el patrón de informe existente al generar nuevas secciones PDF.

---

## Contexto de desarrollo

- Autor: Francisco Vidal Mateo (GitHub: Haplee)
- Entorno: Windows 11 + Ubuntu (dual boot), IDE Antigravity (VS Code-based)
- Despliegue objetivo: servidor VPS Linux (nginx + PHP-FPM + MariaDB)
- TFG ASIR — curso 2024/25

---

## Lo que Claude NO debe hacer

- No instalar dependencias globales sin avisar.
- No hacer commits directamente a `main`. Usa ramas con prefijo `feat/`, `fix/`, `docs/`.
- No modificar `wp-config.php` con credenciales reales.
- No generar código que asuma privilegios root sin comprobarlo antes.
- No acortar el informe PDF: las secciones son obligatorias por diseño del servicio.

---

## Referencias útiles

- Diagrama del sistema: `docs/flujo-sistema.md`
- Esquema JSON de diagnóstico: `docs/schema-diagnostico.md`
- Estructura de tickets MantisBT: `docs/mantis-integration.md`
- Ver `@README.md` para instrucciones de instalación del entorno local.
