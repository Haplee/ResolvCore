# ResolveCore — Informe de Estado para Tutor TFG ASIR
**Alumno:** Francisco Vidal Mateo  
**Fecha:** 6 de mayo de 2026  
**Entrega TFG:** 5 de junio de 2026 (30 días restantes)  
**Repositorio:** https://github.com/Haplee/ResolveCore

---

## 1. Descripción del proyecto

**ResolveCore** es una plataforma de soporte técnico remoto y optimización de sistemas. Permite a un técnico informático gestionar incidencias de clientes de forma estructurada, automatizada y auditable.

**Eslogan:** *"Solución a tus problemas informáticos."*

### Flujo completo del servicio (7 fases)

```
Cliente rellena formulario web (WordPress)
    ↓
Se crea ticket automáticamente en MantisBT (gestor de incidencias)
    ↓
Técnico conecta remotamente al equipo del cliente via AnyDesk
    ↓
Script de diagnóstico analiza el sistema (PowerShell / Bash / Android)
    ↓
Técnico resuelve el problema
    ↓
Se genera informe técnico PDF automáticamente
    ↓
Facturación: pago por servicio o suscripción mensual
```

---

## 2. Stack tecnológico

| Componente | Tecnología | Rol en el sistema |
|------------|------------|-------------------|
| Frontend / CMS | WordPress (PHP) | Web pública, formulario de contacto |
| Gestión de incidencias | MantisBT 2.27 | Tickets, estados, SLA, auditoría |
| Scripts Windows | PowerShell 7+ | Diagnóstico, optimización, informes |
| Scripts Linux/macOS | Bash | Diagnóstico, optimización |
| Scripts Android | Bash (ADB) | Diagnóstico remoto dispositivos Android |
| Servidor web | Nginx + PHP-FPM | Producción en VPS Linux |
| Base de datos | MariaDB | MantisBT + vulnerabilidades |
| Acceso remoto | AnyDesk | Conexión al equipo del cliente |
| Informes | HTML → PDF (wkhtmltopdf/DomPDF) | Informe técnico automático |
| Control de versiones | Git + GitHub | Código fuente + webhook → MantisBT |
| App móvil (futuro) | Kotlin + Jetpack Compose | Fase 7 del proyecto |

---

## 3. Lo que está implementado

### 3.1 Scripts de diagnóstico multiplataforma ✅

**Windows** (`scripts/windows/diagnostico.ps1`):
- CPU, RAM, disco, temperatura, red
- Servicios críticos y su estado
- Logs de errores del sistema
- Estado de Windows Update
- Salida: JSON estructurado + HTML visual

**Linux** (`scripts/linux/diagnostico.sh`):
- CPU/RAM/disco, procesos, servicios systemd
- Puertos abiertos, journalctl
- Salida: JSON estructurado

**macOS** (`scripts/macos/diagnostico.sh`):
- Similar a Linux, adaptado a launchctl y brew

**Android** (`scripts/android/diagnostico.sh`):
- Vía ADB: batería, almacenamiento, apps, conectividad

**Scripts de optimización:**
- `scripts/windows/optimizacion.ps1` — limpieza, desfrag, registro
- `scripts/linux/optimizacion.sh` — apt autoremove, limpieza caché
- `scripts/macos/optimizacion.sh` — brew cleanup, caché sistema
- `scripts/android/optimizacion.sh` — limpieza vía ADB

**Informe HTML generado:** `scripts/informe.html` (prueba real sobre el equipo del alumno)

### 3.2 Tema WordPress personalizado ✅

Ubicación: `wordpress/resolvecore-theme/`

- Diseño dark (fondo `#0a0c10`, acento `#00e5a0`)
- Página principal con secciones: servicios, precios, contacto
- Formulario de contacto con 5 tipos: soporte, bug, colaboración, licencia, otro
- Envío vía AJAX (sin recarga de página)
- Responsive, animaciones CSS, tipografía monoespaciada

### 3.3 Plugin WordPress: integración MantisBT ✅

Ubicación: `wordpress/plugins/rc-mantisbt/`

- **`rc-mantisbt.php`**: plugin principal con panel de configuración en Ajustes → MantisBT
  - Campos: URL de MantisBT, API Token, ID de proyecto, activar/desactivar
  - Botón de verificación de conexión
- **`includes/class-mantis-api.php`**: cliente REST API
  - `create_issue()`, `get_issue()`, `get_projects()`
  - Autenticación por token Bearer
- Integrado en `functions.php`: cuando el usuario envía el formulario, se crea automáticamente un ticket en MantisBT y se muestra el número de ticket al cliente

**Resultado visible al cliente tras enviar formulario:**
> *"¡Mensaje enviado! Ticket #42 creado. Te responderemos pronto."*

### 3.4 MantisBT: configuración completa ✅

Ubicación: `mantisbt/`

- **`config/config_inc.php.template`**: plantilla lista para producción con todos los parámetros configurados (BD, SMTP, API, permisos, workflow)
- **`sql/resolvecore-setup.sql`**: script SQL que crea:
  - 5 categorías: Soporte técnico, Bug, Colaboración, Licencia, General
  - Versión inicial v1.0.0
  - Campo personalizado "Plataforma" (Windows/Linux/macOS/Android/Otro)
  - Campo personalizado "AnyDesk ID" para registrar la sesión remota

### 3.5 Plugins MantisBT instalados ✅

Script de instalación: `mantisbt/plugins/install.sh`

| Plugin | Función | Config personalizada |
|--------|---------|---------------------|
| source-integration | Vincula commits GitHub → tickets (`fix #42`) | Sí |
| MantisKanban | Vista Kanban del flujo de soporte | No |
| SetDuedate | SLA automático según prioridad | Sí (immediate=1h, urgent=2h, high=4h, normal=24h) |
| Reminder | Alerta si ticket supera umbral sin respuesta | Sí |
| mailtemplate | Emails HTML con branding ResolveCore | Sí |
| EventLog | Auditoría completa (login, tickets, config) | Sí (retención 365 días) |

### 3.6 Documentación técnica ✅

- `docs/mantis-integration.md` — guía completa de integración WordPress ↔ MantisBT
- `docs/stack-tecnologico.md` — justificación de cada tecnología vs alternativas

---

## 4. Lo que falta implementar

### 4.1 Despliegue en servidor (BLOQUEANTE) 🔴

**Problema:** Todo el código está desarrollado localmente en Windows 11. Para que el sistema funcione de extremo a extremo (formulario web → ticket MantisBT), necesito un servidor Linux con:
- Nginx + PHP-FPM 8.2
- MariaDB
- WordPress instalado
- MantisBT instalado en el mismo dominio

**Opciones que estoy evaluando:**
1. **Oracle Cloud Free Tier** — VM con 4 OCPU + 24 GB RAM, gratis indefinidamente
2. **WSL (Windows Subsystem for Linux)** — local, sin IP pública, no accesible para el tribunal
3. **Hosting compartido** — limitado, sin acceso SSH completo

**Pregunta para el tutor:** ¿Qué opción recomienda para el TFG? ¿Es suficiente con una demo local en WSL o es necesario que el tribunal pueda acceder a una URL pública?

### 4.2 Generación automática de informes PDF 🟡

**Pendiente de implementar:**
- Leer JSON de diagnóstico → poblar plantilla HTML → exportar PDF
- Adjuntar PDF automáticamente al ticket MantisBT al cerrar la incidencia
- Herramienta prevista: DomPDF (PHP) o wkhtmltopdf

Ya existe `scripts/informe.html` como prueba de concepto del formato visual.

**Pregunta para el tutor:** ¿Es suficiente DomPDF para la entrega o se valoraría mejor wkhtmltopdf que produce PDFs más fieles al HTML?

### 4.3 Base de datos de vulnerabilidades 🟡

**Pendiente de implementar:**
- Tabla `rc_vulnerabilities` (CVE, gravedad, SO, descripción, fix)
- Script de sincronización con NVD/NIST API
- Consulta desde los scripts de diagnóstico para alertar al técnico

**Pregunta para el tutor:** ¿Debe la base de datos estar poblada con datos reales de CVEs o es suficiente con el esquema y un seeder de datos de ejemplo?

### 4.4 Sistema de facturación 🟠

**Conceptualmente definido, no implementado:**
- **Pago por servicio:** factura PDF generada al cerrar ticket
- **Suscripción:** cron job que notifica al cliente revisiones programadas

**Pregunta para el tutor:** ¿Este módulo es necesario para la calificación del TFG o puede quedar como trabajo futuro documentado?

### 4.5 App Android (Kotlin) 🔵

**Fase futura explícita en el proyecto.** No se implementará en el TFG actual.

---

## 5. Estructura del repositorio actual

```
ResolvCore/
├── wordpress/
│   ├── resolvecore-theme/       # Tema WP completo (PHP + CSS + JS)
│   └── plugins/
│       └── rc-mantisbt/         # Plugin integración MantisBT
│           ├── rc-mantisbt.php
│           └── includes/class-mantis-api.php
├── scripts/
│   ├── windows/
│   │   ├── diagnostico.ps1      # Diagnóstico completo Windows
│   │   └── optimizacion.ps1     # Optimización Windows
│   ├── linux/
│   │   ├── diagnostico.sh       # Diagnóstico Linux
│   │   └── optimizacion.sh      # Optimización Linux
│   ├── macos/
│   │   ├── diagnostico.sh
│   │   └── optimizacion.sh
│   ├── android/
│   │   ├── diagnostico.sh       # Vía ADB
│   │   └── optimizacion.sh
│   ├── diagnosticos/            # Diagnósticos reales generados (JSON + HTML)
│   └── informe.html             # Prototipo visual del informe técnico
├── mantisbt/
│   ├── config/
│   │   └── config_inc.php.template   # Config MantisBT lista para producción
│   ├── sql/
│   │   └── resolvecore-setup.sql     # Categorías, campos personalizados
│   └── plugins/
│       ├── install.sh           # Instala 6 plugins automáticamente
│       ├── source-integration/config.php
│       ├── SetDuedate/config.php
│       ├── Reminder/config.php
│       ├── mailtemplate/config.php
│       └── EventLog/config.php
├── docs/
│   ├── mantis-integration.md   # Guía integración WordPress ↔ MantisBT
│   └── stack-tecnologico.md    # Justificación tecnológica completa
└── CLAUDE.md                   # Especificación del proyecto
```

---

## 6. Preguntas concretas para el tutor

1. **Despliegue:** ¿VPS público, WSL local o hosting compartido para la defensa?
2. **Informe PDF:** ¿DomPDF o wkhtmltopdf? ¿Es obligatoria la generación automática para el TFG?
3. **Base de datos CVEs:** ¿Datos reales de NVD/NIST o seeder de ejemplo?
4. **Facturación:** ¿Implementar o dejar como trabajo futuro documentado?
5. **Alcance de la demo:** ¿Qué módulos debe demostrar funcionando en la defensa?
6. **Memoria TFG:** ¿Hay plantilla oficial de la institución para la memoria escrita?

---

## 7. Timeline propuesto (30 días restantes)

| Semana | Actividad |
|--------|-----------|
| 7–11 mayo | Despliegue en servidor (según indicación tutor) · MantisBT funcional |
| 12–16 mayo | Plugin WP activo · Formulario → ticket funcionando end-to-end |
| 17–23 mayo | Generación PDF automática · Base de datos vulnerabilidades |
| 24–30 mayo | Facturación básica · Pulido general · Tests de flujo completo |
| 31 mayo – 4 jun | Memoria TFG escrita · Presentación / demo |
| 5 junio | **Entrega** |

---

*Documento generado automáticamente el 06/05/2026 para revisión del tutor.*
