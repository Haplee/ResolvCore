# Defensa — Scripts, MantisBT y proyecto ResolveCore

> Documento de apoyo para la defensa oral del TFG. Explica cada script del proyecto, la integración con MantisBT y la visión global de la plataforma en formato de cara al tribunal.
> **Complemento de** [`defensa-tfg.md`](defensa-tfg.md): aquel es el documento maestro de arquitectura y decisiones; este es el guion técnico de scripts y tickets que un examinador puede preguntar.
> **Autor:** Francisco Vidal Mateo · **Fecha:** 2026-05-11

---

## Tabla de contenidos

1. [Resumen del proyecto en 60 segundos](#1-resumen-del-proyecto-en-60-segundos)
2. [Arquitectura global a un vistazo](#2-arquitectura-global-a-un-vistazo)
3. [Catálogo completo de scripts](#3-catálogo-completo-de-scripts)
4. [Scripts Windows](#4-scripts-windows)
5. [Scripts Linux](#5-scripts-linux)
6. [Scripts Android](#6-scripts-android)
7. [Scripts macOS (estado: stub demo)](#7-scripts-macos-estado-stub-demo)
8. [Scripts ISO / instalación desatendida](#8-scripts-iso--instalación-desatendida)
9. [Scripts auxiliares de despliegue](#9-scripts-auxiliares-de-despliegue)
10. [Escáner unificado de vulnerabilidades — `buscar_vulnerabilidades.py`](#10-escáner-unificado-de-vulnerabilidades--buscar_vulnerabilidadespy)
11. [MantisBT — qué es, por qué y cómo se integra](#11-mantisbt--qué-es-por-qué-y-cómo-se-integra)
12. [Plugin WordPress `rc-mantisbt`](#12-plugin-wordpress-rc-mantisbt)
13. [Flujo punta a punta de un ticket](#13-flujo-punta-a-punta-de-un-ticket)
14. [Decisiones técnicas defendibles](#14-decisiones-técnicas-defendibles)
15. [Preguntas frecuentes del tribunal](#15-preguntas-frecuentes-del-tribunal)

---

## 1. Resumen del proyecto en 60 segundos

ResolveCore es una plataforma de **mantenimiento técnico remoto** estructurada en siete fases: solicitud del cliente → ticket en MantisBT → conexión remota AnyDesk → diagnóstico automatizado → resolución → informe PDF → facturación.

El proyecto cubre los cuatro bloques del ciclo ASIR:

- **Sistemas operativos**: scripts nativos PowerShell (Windows), Bash (Linux/macOS) y Bash + ADB (Android).
- **Redes**: APIs públicas REST (NIST NVD, CISA KEV, OSV, EPSS), SSH multihost, escaneo de puertos.
- **Bases de datos**: MariaDB con tablas `rc_*` propias e integración con el esquema MantisBT.
- **Aplicaciones web**: WordPress como frontend público + plugin propio `rc-mantisbt` para comunicar con la API REST de MantisBT.

La diferencia con un soporte técnico tradicional es la **trazabilidad**: cada intervención deja JSON estructurado, ticket Mantis con adjuntos, snapshot de estado previo (undo) e informe PDF para el cliente.

---

## 2. Arquitectura global a un vistazo

```
┌────────────────────┐       ┌──────────────────────┐
│ Cliente (formulario│       │  Técnico (panel +    │
│ web público)       │       │  scripts en remoto)  │
└─────────┬──────────┘       └───────────┬──────────┘
          │ HTTPS                        │ AnyDesk
          ▼                              ▼
┌──────────────────────────────────────────────────────┐
│ VPS Linux · nginx · PHP-FPM · MariaDB                │
│ ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│ │ WordPress    │─▶│ rc-mantisbt  │─▶│ MantisBT 2.28│ │
│ │ (tema RC)    │  │ plugin       │  │ + plugins    │ │
│ └──────────────┘  └──────────────┘  └──────────────┘ │
│                                          │           │
│                                          ▼           │
│                   ┌──────────────────────────────┐   │
│                   │ rc_tickets · rc_vulnerabili- │   │
│                   │ ties · rc_diagnostics        │   │
│                   └──────────────────────────────┘   │
└──────────────────────────────────────────────────────┘
                                │
                  Equipo cliente (Win/Linux/Android/macOS)
                  ├─ scripts/windows/*.ps1
                  ├─ scripts/linux/*.sh
                  ├─ scripts/android/*.sh (ADB/Termux)
                  └─ scripts/macos/*.sh (stub)
```

**Por qué tres capas y no monolito**: separa presentación (WP), gestión (Mantis) y diagnóstico (scripts) en componentes intercambiables. Si mañana Mantis se sustituye por otra herramienta, solo cambia el plugin `rc-mantisbt`.

---

## 3. Catálogo completo de scripts

| Plataforma | Script | Función | Versión |
|------------|--------|---------|---------|
| Windows | `scripts/windows/ResolveCore.ps1` | Menú TUI / launcher | — |
| Windows | `scripts/windows/diagnostico.ps1` | Diagnóstico HW + SW + red + seguridad | 3.2.0 |
| Windows | `scripts/windows/optimizacion.ps1` | Optimización por niveles + undo | 3.2.0 |
| Linux | `scripts/linux/ResolveCore.sh` | Menú TUI / launcher | — |
| Linux | `scripts/linux/diagnostico.sh` | Diagnóstico HW + SW + red + seguridad | 3.0.0 |
| Linux | `scripts/linux/optimizacion.sh` | Optimización por niveles + undo | 3.1.0 |
| Android | `scripts/android/ResolveCore.sh` | Menú TUI / launcher | — |
| Android | `scripts/android/diagnostico.sh` | Diagnóstico vía ADB / Termux | 2.1.0 |
| Android | `scripts/android/optimizacion.sh` | Optimización (cache trim no destructivo) | 3.1.0 |
| macOS | `scripts/macos/ResolveCore.sh` | Menú TUI / launcher | — |
| macOS | `scripts/macos/diagnostico.sh` | Stub demo CLI | 0.1.0 |
| macOS | `scripts/macos/optimizacion.sh` | Stub demo CLI | 0.1.0 |
| Cross-SO | `scripts/buscar_vulnerabilidades.py` | Escáner CVE unificado | 1.0.0 |
| ISO Win | `scripts/iso/windows/setup.ps1` | Post-instalación Windows desatendida | — |
| ISO Linux | `scripts/iso/linux/post-install.sh` | Post-instalación Ubuntu desatendida | — |
| ISO Linux | `scripts/iso/linux/autoinstall.yaml` | Cloud-init para autoinstall | — |
| Despliegue | `scripts/bootstrap-mantis.sh` | Descarga MantisBT 2.28.1 al repo local | — |

Total: **17 ficheros ejecutables** + un informe HTML de referencia (`scripts/informe.html`).

---

## 4. Scripts Windows

### 4.1 `ResolveCore.ps1` — Menú TUI

Launcher interactivo. Es el punto de entrada que un técnico ejecuta en sesión remota. Tiene dos modos:

- **Interactivo (sin flags)**: muestra menú numérico 1–5 (Diagnóstico, Optimización, Vulnerabilidades, Ayuda, Salir).
- **Pass-through (con flags)**: si el técnico invoca con `-Nivel rendimiento` o `-Silent`, redirige directamente al script correspondiente y sale con el `$LASTEXITCODE` correcto. Permite invocación desatendida desde CI o tareas programadas.

Detecta automáticamente si falta Python (necesario para el escáner de vulnerabilidades) e intenta instalarlo vía Scoop o Chocolatey antes de continuar. Política estricta: **nada de winget ni Microsoft Store** (no son open source).

### 4.2 `diagnostico.ps1` — Diagnóstico Windows v3.2.0

Requiere PowerShell 5.1 (Windows 10/11 trae 5.1 nativo; recomienda pwsh 7+). Recolecta:

| Categoría | Métricas |
|-----------|----------|
| **CPU** | Modelo, núcleos, threads, MHz, carga actual, temperatura (OpenHardwareMonitor si disponible) |
| **RAM** | Total, en uso, libre, módulos físicos, velocidad |
| **Disco** | Capacidad, libre, MediaType (SSD/HDD), S.M.A.R.T. con `smartctl`, predicción de fallo |
| **GPU** | Modelo, VRAM, driver, fabricante |
| **Batería** | Estado, capacidad de diseño vs actual (% degradación), ciclos |
| **Red** | IPs, MACs, gateway, DNS, latencia ping, pérdida de paquetes |
| **SO** | Versión, build, parches instalados, Windows Update pendientes, plan de energía |
| **Servicios** | Estado y modo de arranque de los críticos |
| **Eventos** | Últimos errores de System / Application |
| **Seguridad** | Windows Defender activo, firewall, BitLocker, UAC |
| **Integridad** | `sfc /verifyonly` (resumen) |

**Salida**: JSON estructurado conforme a [`docs/schema-diagnostico.md`](schema-diagnostico.md) + HTML autocontenido con CSS embebido. **Exit codes**: 0 OK / 1 error de escritura / 2 fallo fatal en recogida.

**Flags relevantes para la defensa**:
- `-OutputDir <dir>` o `-O <dir>`: directorio de salida.
- `-Silent` o `-S`: modo CI sin output a consola.
- `-InstallDeps` o `-I`: detecta y propone instalar paquetes opcionales (smartmontools, OpenHardwareMonitor, speedtest, nmap, git).
- `-AutoInstall` o `-A`: igual sin confirmación, útil para despliegues automatizados.

**Optimización aplicada en v3.2.0**: la consulta `Get-CimInstance Win32_OperatingSystem` se ejecutaba dos veces en el mismo script. Se cacheó en una variable `$os` reusable. Error #3 del log de aprendizajes.

### 4.3 `optimizacion.ps1` — Optimización Windows v3.2.0

Aplica optimizaciones según un nivel (ligero / estandar / rendimiento / extreme). Requiere consola Administrador.

| Nivel | Acciones |
|-------|----------|
| `ligero` | Limpieza temporales + servicios no críticos |
| `estandar` | Anterior + telemetría off + efectos visuales reducidos |
| `rendimiento` | Anterior + tuning disco/red/RAM + DiagTrack/DPS off |
| `extreme` | Anterior + bloqueo Cortana/OneDrive/Bing + SysMain off |

**Mecanismos de seguridad obligatorios**:

1. **Backup `.reg` previo**: cualquier modificación de registro exporta primero la rama afectada.
2. **`estado_previo.json`**: snapshot de estado de servicios antes de tocar nada.
3. **Idempotencia**: re-ejecutar no acumula efectos.
4. **`-DryRun`**: imprime el plan completo sin aplicar.
5. **`-Undo`**: revierte cambios usando el snapshot.
6. **`-BackupOnly`**: solo crea las copias.

**Exclusión durable de Spooler**: el servicio de cola de impresión **nunca se desactiva** en ningún nivel. Decisión consciente — muchos clientes finales usan impresoras locales o de red, desactivar Spooler rompe impresión sin beneficio perceptible. Está fijado como memoria persistente del proyecto.

Ficheros generados en `%TEMP%\ResolveCore_Optimizacion\`:
- `optimizacion.log` — log de ejecución.
- `backup\` — copias `.reg`.
- `estado_previo.json` — snapshot pre-cambio.

---

## 5. Scripts Linux

### 5.1 `ResolveCore.sh` — Menú TUI

Análogo al de Windows. Detecta si falta Python e intenta instalarlo vía `apt`, `dnf`, `pacman` o `zypper` según la distro. `set -uo pipefail` para fail-fast.

### 5.2 `diagnostico.sh` — Diagnóstico Linux v3.0.0

Recolecta métricas con herramientas estándar del sistema:

| Métrica | Herramienta |
|---------|-------------|
| CPU + carga | `top`, `uptime`, `lscpu` |
| RAM | `free -h`, `/proc/meminfo` |
| Disco | `df -h`, `lsblk`, `smartctl` |
| GPU | `lspci`, `nvidia-smi` si NVIDIA |
| Batería (portátil) | `/sys/class/power_supply/BAT*/` |
| Temperatura | `lm-sensors` |
| Errores recientes | `journalctl -p 3` |
| Paquetes instalados | `dpkg -l` (Debian/Ubuntu) o `rpm -qa` (RHEL/Fedora) |
| Puertos abiertos | `ss -tulpn` |
| Servicios caídos | `systemctl --failed` |
| Firewall | `ufw status` o `firewalld` |
| SELinux | `sestatus` |

**Decisión técnica**: Bash en lugar de Python. Razón — toda distro Linux trae Bash; Python 3 no siempre (Alpine, sistemas mínimos). Los diagnósticos son composiciones de comandos del sistema, y Bash es la lingua franca para eso.

### 5.3 `optimizacion.sh` — Optimización Linux v3.1.0

Aplica optimizaciones por nivel. Requiere `sudo`.

| Nivel | Acciones |
|-------|----------|
| `ligero` | `apt autoremove` + `journalctl --vacuum-time=7d` |
| `estandar` | Anterior + sysctl swappiness (10) + servicios no críticos off |
| `rendimiento` | Anterior + tuning red/IO |
| `extreme` | Anterior + zram + tmp en RAM |

**Cambios clave en v3.1.0**:
- `--dry-run` y `--undo` **se parsean de verdad ahora**. En la versión anterior estaban declarados pero el código no los leía — flags inertes. Error #2 del log de aprendizajes (auditoría manual reveló el código muerto).
- Validación previa de cada unidad systemd antes de `stop/disable` para silenciar ruido.
- Backup de `/etc/sysctl.conf` antes de cualquier modificación, en `/var/tmp/resolvecore_optimizacion/`.
- Registro de servicios deshabilitados (`services_disabled.log`) usado por `--undo`.

**Spooler también excluido** — `cups` no se desactiva en ningún nivel, por la misma razón que en Windows.

---

## 6. Scripts Android

### 6.1 `diagnostico.sh` (Android) v2.1.0

Comunica con el dispositivo Android vía ADB (USB o Wi-Fi). Recolecta:

- Hardware: modelo, fabricante, SoC, RAM (`getprop`).
- Batería: capacidad, salud, ciclos, estado (`dumpsys battery`).
- Almacenamiento: total y libre.
- Versión Android, build, parche de seguridad.
- Paquetes instalados: `pm list packages -f`.
- Permisos peligrosos por app.

Acepta un `SERIAL` opcional para apuntar a un dispositivo concreto cuando hay varios conectados. Si no se pasa, usa el primero detectado.

**Por qué ADB y no app nativa**: para el TFG no se requiere instalar nada en el móvil del cliente. ADB sobre USB es estándar, gratis y suficiente. La app nativa queda como roadmap (Kotlin + Jetpack Compose).

### 6.2 `optimizacion.sh` (Android) v3.1.0

**Bug crítico corregido**: la versión anterior usaba `pm clear $app` para "limpiar caché". `pm clear` borra **todos los datos de usuario** (sesiones, ficheros, configuraciones de la app), no solo la caché. Fue reemplazado por:

```bash
pm trim-caches 1073741824   # solicita 1 GB libre, vacía solo caché real
```

Error #1 del log de aprendizajes — la lección: validar comandos del sistema en un entorno aislado antes de incluirlos en producción. Es el ejemplo perfecto para defensa de capacidad crítica.

---

## 7. Scripts macOS (estado: stub demo)

Las versiones de macOS están reducidas a **stubs**. Versión 0.1.0-demo. Generan JSON placeholder con `_meta.stub: true` para que el resto del sistema pueda procesar la respuesta sin romperse.

**Por qué stub y no implementación completa**: la versión completa anterior contenía operaciones destructivas sin guardas:

- `mdutil off` — desactiva Spotlight (afecta toda la indexación del usuario).
- `rm -rf ~/Library/Caches` — borra cachés del usuario sin distinción.
- `networksetup -setdnsservers` — cambia DNS sin restaurarlo.

Reducir a stub es **más honesto académicamente** que entregar código peligroso. Demuestra capacidad para reconocer cuándo un módulo no está listo para producción. La implementación real queda explícitamente en roadmap.

---

## 8. Scripts ISO / instalación desatendida

Carpeta `scripts/iso/`. Pensados para crear imágenes de instalación que dejen el equipo del cliente preparado con ResolveCore preinstalado.

### 8.1 `iso/windows/setup.ps1`

Script de post-instalación que se invoca desde una ISO modificada (Autounattend.xml). Crea estructura `C:\ResolveCore\`, descarga los scripts del repo, configura la tarea programada de diagnóstico semanal.

### 8.2 `iso/linux/autoinstall.yaml`

Cloud-init para Ubuntu Server autoinstall. Crea usuario, configura SSH, ejecuta `post-install.sh` al final.

### 8.3 `iso/linux/post-install.sh`

Ejecutado por cloud-init al terminar la instalación. Instala dependencias (`smartmontools`, `lm-sensors`, etc.), clona el repo, programa el diagnóstico vía cron.

---

## 9. Scripts auxiliares de despliegue

### 9.1 `bootstrap-mantis.sh`

Descarga MantisBT 2.28.1 desde GitHub a `mantisbt-2.28.1/` (la carpeta está en `.gitignore` — no se versiona el bundle).

Características:
- **Idempotente**: si ya existe, no re-descarga.
- **Verificación SHA256**: si hay `mantisbt/mantis-2.28.1.sha256`, valida el tarball.
- Útil para que un colaborador clone el repo y tenga MantisBT operativo en un solo comando.

### 9.2 `mantisbt/plugins/install.sh`

Instala los seis plugins recomendados (source-integration, MantisKanban, SetDuedate, Reminder, mailtemplate, EventLog) sobre la ruta de MantisBT que se pase como parámetro:

```bash
bash mantisbt/plugins/install.sh /var/www/mantis
```

---

## 10. Escáner unificado de vulnerabilidades — `buscar_vulnerabilidades.py`

Es el componente más extenso del proyecto (~1700 líneas, 16 clases). Vale para Windows, Linux, Android y macOS. Se invoca como **opción 3** del menú TUI en cualquier plataforma.

### 10.1 Por qué Python (y por qué stdlib)

- **Una única implementación** vale para los 4 SO en lugar de duplicar la lógica CVE en PowerShell + 3× Bash.
- **Python stdlib pura**: sin `pip`, sin `requirements.txt`, sin entorno virtual. El launcher solo necesita un Python ≥ 3.8.
- **Defendible políticamente**: solo software libre. Lista negra explícita de tecnologías propietarias:

| ✅ Permitido | ❌ Rechazado |
|--------------|--------------|
| Scoop, Chocolatey, apt, dnf, pacman, brew | winget, Snap, MS Store, Mac App Store |
| smtplib, msmtp | MAPI, Outlook COM |
| NIST NVD, CISA KEV, OSV, EPSS | Nessus, Qualys, Snyk, Tenable |

### 10.2 Pipeline de 11 fases

```
PlatformDetector  → inventario SW + servicios + identificación OS
CISAKEVCache      → feed CISA KEV (~1589 CVEs en explotación activa)
WhitelistManager  → excepciones aceptadas con fecha de caducidad
VulnScanner       → NVD (3 intentos: keyword+ver, keyword, virtualMatchString)
                  + OSV.dev (paralelizado con threading)
                  + EPSS (probabilidad de explotación a 30 días)
ConfigAuditor     → audita config local (UAC, SMBv1, RDP NLA, SSH, UFW, ASLR, …)
NetworkScanner   → 12 puertos de riesgo (Telnet, FTP, SMB, RDP, Redis, Mongo, …)
LogAnalyzer       → IOCs (bruteforce SSH, Event 4625, crons sospechosos)
DepsScanner       → requirements.txt, package.json, etc. contra OSV (--scan-deps)
RemediationEngine → corrección automática (scoop/choco/apt/dnf/pacman/brew)
RiskScorer        → score 0-100 con desglose línea a línea
HistoryManager    → guarda histórico, compara con escaneo previo (--compare)
ReportGenerator   → JSON + TXT estructurado + HTML autocontenido
Notifier          → SMTP (smtplib, msmtp fallback, .eml si todo falla)
MantisBTClient    → crea ticket REST + adjunta JSON + nota Markdown
MultiHostRunner  → ejecuta en N máquinas vía SSH (script base64 embebido)
```

### 10.3 Cuatro fuentes públicas, una señal mucho más útil

| API | Licencia | Aporta |
|-----|----------|--------|
| NIST NVD 2.0 | Pública USG | Catálogo CVE + CVSS v3.1/v3.0/v2.0 |
| CISA KEV | Dominio público | CVEs *explotados activamente ahora* |
| OSV.dev (Google) | Apache 2.0 | Vulns por ecosistema (PyPI/npm/Maven/Go) |
| EPSS (FIRST.org) | Pública | Probabilidad de explotación a 30 días |

**Argumento defendible**: CVSS = gravedad estática. EPSS = urgencia real. KEV = ya está siendo explotado. Combinarlas da una señal mucho más útil para priorizar parches que solo CVSS, que es el criterio que usan la mayoría de herramientas básicas.

### 10.4 Normalización del inventario

Un Windows típico tiene ~181 entradas en el registro Uninstall. Sin filtrar = ruido total + 0 matches NVD (los nombres en español o con edición no coinciden con CPE).

Aplica tres etapas:

```python
SOFTWARE_NOISE_PATTERNS    # descarta updates, hotfixes, SDKs, redistributables
SOFTWARE_KEYWORD_MAP       # "Microsoft Visual C++ 2013" → "vcredist 2013"
                           # "Eclipse Temurin JDK con Hotspot" → "openjdk"
                           # "Oracle VirtualBox 7.2.8" → "virtualbox"
dedupe_software()          # agrupa duplicados x86/x64, queda la versión más alta
```

Tres intentos NVD por software: keyword + versión corta → solo keyword → `virtualMatchString` CPE-like. Versión normalizada a `MAJOR.MINOR` (más matches).

### 10.5 RiskScore con desglose auditable

```
Base: 100
- CVE CRITICAL: -15        - CVE HIGH: -8        - CVE MEDIUM: -3
- CVE en KEV: -20 extra    - Config CRITICAL FALLO: -20
- Config HIGH FALLO: -10   - Config MEDIUM FALLO: -4
- Puerto CRITICAL: -8      - Puerto HIGH: -5     - Puerto MEDIUM: -3
- IOC HIGH: -25            + Remediación aplicada: +5 c/u
Clasificación: 80-100 BUENO | 50-79 MEJORABLE | 0-49 CRÍTICO
```

El JSON expone `score_desglose[]` con cada penalización línea a línea — por ejemplo `"-20 CVE en CISA KEV: CVE-2024-1234"` — para auditoría. El HTML lo muestra en `<details>` desplegable.

---

## 11. MantisBT — qué es, por qué y cómo se integra

### 11.1 Qué es MantisBT

Sistema open source de gestión de incidencias en PHP + MySQL/MariaDB. Versión 2.28.1 en este proyecto. Aporta:

- Gestión de issues con estados configurables (`new`, `assigned`, `resolved`, `closed`, `feedback`).
- Custom fields (campos personalizados por proyecto).
- Roles granulares.
- REST API completa (`/api/rest/issues`, notas, adjuntos).
- Plugins.
- Notificaciones email.

### 11.2 Por qué MantisBT y no Jira / GitHub Issues / Redmine

| Criterio | MantisBT | Jira | GH Issues | Redmine |
|----------|----------|------|-----------|---------|
| Open source | ✅ | ❌ | ❌ (servicio) | ✅ |
| PHP/MySQL (alineado con stack) | ✅ | ❌ | ❌ | ❌ (Ruby) |
| REST API completa | ✅ | ✅ | ✅ | ✅ |
| Custom fields | ✅ | ✅ | ⚠️ labels | ✅ |
| Self-hosted gratis | ✅ | ❌ | ❌ | ✅ |

Razones concretas:
- **Alineación de stack**: PHP + MariaDB. No introduce un runtime nuevo.
- **Custom fields nativos**: imprescindibles para guardar datos del diagnóstico (Plataforma, AnyDesk ID).
- **REST 2.x**: cubre issues + notes + files, los tres endpoints que el plugin necesita.
- **Hosting barato**: corre en el mismo VPS que WordPress.

### 11.3 Plugins instalados

Instalación automatizada: `bash mantisbt/plugins/install.sh /var/www/mantis`.

| Plugin | Función |
|--------|---------|
| `source-integration` | Webhook GitHub: `fix #42` en mensaje de commit cierra ticket 42 |
| `MantisKanban` | Vista Kanban del flujo de soporte |
| `SetDuedate` | SLA automático según prioridad |
| `Reminder` | Alerta si un ticket lleva X horas sin atención |
| `mailtemplate` | Notificaciones HTML con branding ResolveCore |
| `EventLog` | Auditoría completa de acciones |

### 11.4 Setup SQL inicial

`mantisbt/sql/resolvecore-setup.sql` crea:

- **5 categorías**: Soporte técnico, Bug, Colaboración, Licencia, General.
- **Versión inicial** `v1.0.0` registrada en `mantis_project_version_table`.
- **Custom field `Plataforma`**: lista con valores `Windows | Linux | macOS | Android | Otro`, default Windows. Visible en el formulario de creación y en la vista del ticket.
- **Custom field `AnyDesk ID`**: texto, regex `^[0-9 ]{0,15}$`, visible solo al actualizar el ticket (no en el alta).

### 11.5 Endpoints REST consumidos

| Método | Endpoint | Uso |
|--------|----------|-----|
| `POST` | `/api/rest/issues` | Crear ticket desde formulario WP |
| `GET` | `/api/rest/issues/{id}` | Consultar estado |
| `POST` | `/api/rest/issues/{id}/notes` | Adjuntar resumen del diagnóstico |
| `POST` | `/api/rest/issues/{id}/files` | Subir JSON de diagnóstico |
| `GET` | `/api/rest/projects` | Health-check de conexión |

---

## 12. Plugin WordPress `rc-mantisbt`

### 12.1 Estructura

```
wordpress/plugins/rc-mantisbt/
├── rc-mantisbt.php              # Bootstrap + helpers públicos
└── includes/
    └── class-mantis-api.php     # Cliente REST tipado
```

### 12.2 Clase `RC_Mantis_API`

- **Constantes whitelist**: `PRIORITIES`, `SEVERITIES`, `MAX_DESCRIPTION = 65000`, `MAX_SUMMARY = 250`, `MAX_FILE_BYTES = 5 MB`.
- **Validación pre-request**: `project_id` ≥ 1, summary/description no vacíos, prioridad/severidad en whitelist, categoría fallback `General`.
- **UTF-8 forzado**: `wp_check_invalid_utf8()` + `wp_json_encode( ..., JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES )`. Resuelve el error #7 (acentos rotos en summary/notes).

Métodos públicos:
- `create_issue( array $data )`
- `get_issue( int $id )`
- `add_note( int $issue_id, string $text, string $view_state )`
- `attach_file( int $issue_id, string $path )` — multipart manual (`wp_remote_request` no soporta uploads nativos).
- `get_projects()` — health-check.

Logs: todo HTTP no-2xx se vuelca en `error_log()` con prefijo `[rc-mantisbt]` y body truncado a 1000 caracteres.

### 12.3 Helper `rc_mantis_attach_diagnostic( $issue_id, $json_path )`

Pipeline de validaciones encadenadas antes de subir:

| Comprobación | Error si falla |
|--------------|----------------|
| Fichero legible y no vacío | `rc_mantis_file_unreadable` |
| `json_decode` válido | `rc_mantis_json_invalid` |
| Esquema mínimo `_meta.plataforma` + `_meta.version` | `rc_mantis_schema_invalid` |
| Tamaño ≤ 5 MB | `mantis_file_too_large` |
| Token y URL configurados | `rc_mantis_no_config` |

Si el adjunto sube pero la nota falla, **no se aborta** — el JSON ya está en el ticket; el fallo de nota se loguea pero el técnico tiene la información.

---

## 13. Flujo punta a punta de un ticket

Caso real: un cliente reporta que su Windows va lento.

1. **Solicitud**. Cliente rellena el formulario en la landing. JS envía AJAX a `admin-ajax.php?action=resolvecore_contact` con nonce + honeypot + rate limit IP-hash.
2. **Validación WP**. `functions.php` sanitiza con `sanitize_text_field`, `sanitize_email`, whitelist de tipo de consulta, límite 500 chars en mensaje.
3. **Creación ticket**. `rc_mantis_create_ticket()` invoca `RC_Mantis_API::create_issue()`. Payload validado contra whitelists. `POST /api/rest/issues` con `Authorization: Token <api_token>`.
4. **Respuesta inmediata**. MantisBT devuelve `{ "issue": { "id": 42, ... } }`. El frontend muestra "Ticket #42 creado".
5. **Conexión remota**. El técnico, viendo el ticket en MantisBT, contacta al cliente y le pasa la sesión AnyDesk (campo custom `AnyDesk ID` en el ticket).
6. **Diagnóstico**. Por AnyDesk, el técnico ejecuta `.\ResolveCore.ps1` y selecciona la opción 1 (Diagnóstico). Genera `diagnostico_HOST_20260511_120000.json` + HTML.
7. **Adjunto al ticket**. El técnico transfiere el JSON al servidor WP y dispara `rc_mantis_attach_diagnostic( 42, '/ruta/json' )`. Validaciones encadenadas → `POST /api/rest/issues/42/files` (multipart) + `POST /api/rest/issues/42/notes` con resumen Markdown.
8. **Análisis de vulnerabilidades**. Opcionalmente, el técnico ejecuta `python buscar_vulnerabilidades.py --mantis-ticket 42`. El escáner crea una nota adicional con CVEs detectados y score.
9. **Optimización**. El técnico decide el nivel adecuado y ejecuta `.\optimizacion.ps1 -Nivel rendimiento -DryRun` para validar el plan. Si está conforme, lanza sin `-DryRun`. Se genera `estado_previo.json`.
10. **Cierre**. Estado del ticket pasa a `resolved`. El plugin `mailtemplate` envía notificación al cliente. (Pendiente: generación PDF + adjunto automático del informe).
11. **Auto-cierre**. Tras 7 días sin reabrir, el ticket pasa a `closed`.

Cada paso deja **artefactos auditables**: nota en ticket, fichero adjunto, log local en cliente. Trazabilidad punta a punta.

---

## 14. Decisiones técnicas defendibles

### 14.1 PowerShell 7 en Windows, Bash en Linux/Android

- **PowerShell 7+**: cross-platform real (PowerShell Core corre en Linux/macOS). Soporte oficial Microsoft a largo plazo. Sintaxis moderna (`??`, ternario, pipeline chain).
- **Bash**: universal en distros Linux y Termux. `set -euo pipefail` + `command -v <tool> || exit 1` cubre fail-fast sin dependencias.

### 14.2 Python stdlib para vulnerabilidades

Una única implementación CVE vale para los 4 SO. Sin `pip`, sin entorno virtual, sin requirements. Solo necesita Python ≥ 3.8 (que el launcher auto-instala). Política coherente con el resto del proyecto: solo software libre.

### 14.3 MantisBT en lugar de Jira/GitHub Issues

Alineación de stack (PHP + MariaDB), custom fields nativos, REST 2.x suficiente, self-hosted gratis. Jira sería desproporcionado, GitHub Issues no permite custom fields tipados.

### 14.4 WordPress como frontend

Audiencia objetivo (pymes y autónomos no técnicos) reconoce WordPress. SEO out-of-the-box. Hosting universal. Stack alineado con el ciclo ASIR. Tema custom (≤50 KB CSS) en lugar de comercial (500 KB+) por accesibilidad total y sin licencias.

### 14.5 Stub macOS en lugar de versión completa con riesgos

Honestidad académica > apariencia funcional. La versión completa anterior contenía operaciones destructivas (`mdutil off`, `rm -rf ~/Library/Caches`, `networksetup -setdnsservers`) sin guardas. Reducir a stub es más defendible que entregar código peligroso. Roadmap declarado.

### 14.6 Excluir Spooler de optimización siempre

Optimización que rompe funcionalidad común = peor servicio. Decisión durable, fijada en memoria persistente del proyecto.

---

## 15. Preguntas frecuentes del tribunal

**P: ¿Por qué scripts y no una app única que englobe todo?**
R: Los scripts pueden ejecutarse en el equipo del cliente sin instalación, vía sesión AnyDesk. Una app requeriría despliegue previo, permisos, actualizaciones. Los scripts son fail-safe: un fallo en el escáner no afecta al sistema operativo del cliente.

**P: ¿Qué pasa si la conexión a MantisBT cae durante un diagnóstico?**
R: El JSON se guarda localmente con timestamp. `rc_mantis_attach_diagnostic` se puede reinvocar después. El diagnóstico no depende de la red para completarse.

**P: ¿Cómo evita el sistema que un script destructivo arruine el equipo del cliente?**
R: Tres capas: (1) flag `--confirm` obligatorio para niveles altos, (2) `--dry-run` por defecto en demo, (3) snapshot pre-cambio + `--undo`. Regla durable de CLAUDE.md: scripts destructivos requieren flag explícito.

**P: ¿Por qué NVD + KEV + OSV + EPSS y no solo CVSS?**
R: CVSS es gravedad estática y se publica una vez. KEV indica explotación activa *hoy*. EPSS la probabilidad a 30 días. OSV cubre ecosistemas (PyPI, npm, Maven) que NVD ignora. Combinarlos prioriza mejor que CVSS solo.

**P: ¿Qué pasaría si Mantis publica una versión con cambios en la REST API?**
R: Todo el contrato HTTP vive en `RC_Mantis_API`. Adaptarse a un cambio de schema sería editar esa clase. El resto del plugin (validaciones, helpers, hooks WP) es independiente.

**P: ¿Por qué Bash 4 mínimo y no compatibilidad sh estricta?**
R: Necesitamos arrays asociativos y `[[ ... ]]`. Toda distro mantenida desde 2010 trae Bash ≥ 4. Restringirse a sh estricto haría el código mucho más largo sin beneficio real.

**P: ¿El plugin WP es seguro?**
R: Sanitización en input (`sanitize_text_field`, `sanitize_email`), validación de payload con whitelists, nonce AJAX, honeypot, rate limit IP-hash con `wp_salt('auth')` (IPv6-safe), security headers en `send_headers`. Token Mantis en WP options (pendiente: cifrado at-rest con `wp_salt`).

**P: ¿Cómo se escala si crece la cartera de clientes?**
R: El VPS soporta hasta cientos de clientes por las cifras de WP + Mantis. Si crece más, el cuello de botella es el técnico, no la infraestructura. Multi-host SSH (`--hosts`) ya permite escanear varios equipos a la vez.

**P: ¿Qué queda por hacer para producción?**
R: Generador PDF (plantilla diseñada, falta cablear wkhtmltopdf), cron NVD sync semanal operativo, migración del JSON Windows para alinear `hardware {}` (hoy expone hardware en raíz), tests integración Mantis con PHPUnit, despliegue VPS productivo + dominio + Let's Encrypt. Detalle en [`defensa-tfg.md §19 — Roadmap`](defensa-tfg.md#19-roadmap-futuro).

---

## Changelog del documento

| Fecha | Cambio |
|-------|--------|
| 2026-05-11 | Creación inicial. Catálogo completo de los 17 scripts del proyecto, integración MantisBT detallada, flujo end-to-end, decisiones defendibles, FAQ tribunal. |
