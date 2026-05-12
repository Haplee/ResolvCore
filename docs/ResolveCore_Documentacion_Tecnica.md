# ResolveCore — Documentación Técnica de Scripts
---

## Índice

1. [Visión General del Proyecto](#1-visión-general-del-proyecto)
2. [Arquitectura y Estructura](#2-arquitectura-y-estructura)
3. [Scripts Windows](#3-scripts-windows)
   - 3.1 [diagnostico.ps1](#31-diagnosticops1)
   - 3.2 [optimizacion.ps1](#32-optimizacionps1)
   - 3.3 [ResolveCore.ps1 (Menú)](#33-resolvecoreps1-menú-windows)
4. [Scripts Linux](#4-scripts-linux)
   - 4.1 [diagnostico.sh](#41-diagnosticosh)
   - 4.2 [optimizacion.sh](#42-optimizacionsh)
   - 4.3 [ResolveCore.sh (Menú)](#43-resolvecoresh-linux)
5. [Scripts Android](#5-scripts-android)
   - 5.1 [diagnostico_android.sh](#51-diagnostico_androidsh)
   - 5.2 [optimizacion_android.sh](#52-optimizacion_androidsh)
   - 5.3 [ResolveCore.sh (Menú Android)](#53-resolvecoresh-android)
6. [Formato de Salida JSON](#6-formato-de-salida-json)
7. [Consideraciones de Seguridad](#7-consideraciones-de-seguridad)
8. [Tabla Comparativa](#8-tabla-comparativa)
9. [buscar_vulnerabilidades.py](#9-buscar_vulnerabilidadespy)
10. [Scripts de Instalación / Aprovisionamiento](#10-scripts-de-instalación--aprovisionamiento)
    - 10.1 [post-install.sh (Linux)](#101-post-installsh-linux)
    - 10.2 [setup.ps1 (Windows)](#102-setupps1-windows)
    - 10.3 [autoinstall.yaml (Ubuntu preseed)](#103-autoinstallyaml-ubuntu-preseed)

---

## 1. Visión General del Proyecto

**ResolveCore** es una suite de herramientas de línea de comandos diseñada para técnicos de soporte IT. Permite realizar **diagnósticos completos** y **optimizaciones controladas** en tres plataformas principales:

| Plataforma | Tecnología | Alcance |
|------------|-----------|---------|
| **Windows** | PowerShell 5.1+ | Estaciones de trabajo y servidores Windows |
| **Linux** | Bash 4+ | Distribuciones Debian, RHEL, Arch, openSUSE |
| **Android** | Bash + ADB | Dispositivos móviles vía Android Debug Bridge |

### Filosofía de Diseño
- **No destructivo**: Las optimizaciones hacen backup antes de modificar (registro, sysctl, servicios).
- **Reversible**: Todo cambio puede deshacerse con el flag `--undo` / `-Undo`.
- **Autocontenido**: Los scripts generan informes JSON estructurados importables en la plataforma ResolveCore.
- **Seguro**: Exclusiones explícitas de componentes críticos (Spooler en Windows, servicios esenciales en Linux).

---

## 2. Arquitectura y Estructura

### Flujo de Datos

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│   Script CLI    │ ──▶ │  JSON v3.x   │ ──▶ │  ResolveCore    │
│  (Diag/Opt)     │     │  + HTML      │     │  (Importador)   │
└─────────────────┘     └──────────────┘     └─────────────────┘
```

### Estructura de Directorios

```
resolvecore/
├── scripts/
│   ├── windows/
│   │   ├── diagnostico.ps1
│   │   ├── optimizacion.ps1
│   │   └── ResolveCore.ps1          # Menú interactivo Windows
│   ├── linux/
│   │   ├── diagnostico.sh
│   │   ├── optimizacion.sh
│   │   └── ResolveCore.sh
│   ├── android/
│   │   ├── diagnostico.sh
│   │   ├── optimizacion.sh
│   │   └── ResolveCore.sh
│   ├── iso/
│   │   ├── linux/
│   │   │   ├── post-install.sh      # Setup stack completo Ubuntu
│   │   │   └── autoinstall.yaml     # Preseed Ubuntu 24.04 desatendido
│   │   └── windows/
│   │       └── setup.ps1            # Setup stack completo Windows
│   ├── buscar_vulnerabilidades.py   # Escáner CVE multiplataforma
│   └── informe.html                 # Plantilla HTML para informe visual
├── diagnosticos/                    # Salida JSON/HTML generada
└── .env                             # Variables de entorno (opcional)
```

---

## 3. Scripts Windows

### 3.1 diagnostico.ps1

**Versión:** 3.2.0  
**Requiere:** PowerShell 5.1+, privilegios de Administrador (recomendado)  
**Salida:** JSON estructurado + informe HTML autocontenido

#### Propósito
Recoge métricas exhaustivas del sistema Windows y las estructura en un archivo JSON consumible por el generador de informes de ResolveCore.

#### Parámetros

| Parámetro | Alias | Tipo | Descripción |
|-----------|-------|------|-------------|
| `-OutputDir` | `-O`, `-Output` | string | Directorio de salida (default: `../diagnosticos`) |
| `-Silent` | `-S` | switch | Suprime salida por consola (modo CI/automatización) |
| `-InstallDeps` | `-I`, `-Install` | switch | Detecta e instala dependencias opcionales (winget/choco) |
| `-AutoInstall` | `-A` | switch | Igual que `-InstallDeps` sin confirmación interactiva |
| `-Help` | `-h` | switch | Muestra ayuda detallada y sale |

#### Códigos de Salida

| Código | Significado |
|--------|-------------|
| 0 | Diagnóstico generado correctamente |
| 1 | Error escribiendo informe |
| 2 | Error fatal recogiendo datos |

#### Secciones de Recolección

1. **Sistema Operativo**: Versión, build, arquitectura, uptime, parches instalados, memoria libre.
2. **Procesador**: Modelo, núcleos, hilos, velocidad, cachés L1/L2/L3, temperatura (vía WMI `MSAcpi_ThermalZoneTemperature`).
3. **Memoria**: Total, disponible, usada, módulos por slot (velocidad, tipo DDR3/4/5, fabricante).
4. **Almacenamiento**: Discos físicos (modelo, capacidad, tipo SSD/HDD/NVMe, serial, bus), S.M.A.R.T. extendido (temperatura, desgaste, errores de lectura/escritura, horas de encendido), volúmenes lógicos (uso %).
5. **Gráfica**: GPU(s) detectadas, driver, VRAM, resolución, refresh rate, temperatura NVIDIA (nvidia-smi).
6. **Red**: Adaptadores (MAC, tipo, velocidad), configuración IP, gateway, DNS, latencia a 8.8.8.8, pérdida de paquetes, SSID WiFi.
7. **Placa Base y BIOS**: Producto, fabricante, versión BIOS, fecha, UUID.
8. **Batería**: Nivel de carga, estado, voltaje, desgaste %, ciclos de carga.
9. **Servicios**: Total, iniciados/detenidos, automáticos detenidos (alerta), servicios críticos verificados (wuauserv, WSearch, Spooler, BITS, etc.).
10. **Software Instalado**: Primeras 50 aplicaciones del registro (nombre, versión, proveedor).
11. **Rendimiento**: Uso % CPU, uso % memoria, top 5 procesos por consumo de RAM.
12. **Seguridad**: Windows Defender (firmas, tiempo real), Firewall (perfiles activos), UAC, BitLocker.
13. **Usuarios**: Cuentas locales, estado (activo/deshabilitado).

#### Dependencias Opcionales

| Paquete | Gestor winget | Gestor choco | Propósito |
|---------|---------------|--------------|-----------|
| smartmontools | `smartmontools.smartmontools` | `smartmontools` | S.M.A.R.T. extendido |
| LibreHardwareMonitor | `LibreHardwareMonitor.LibreHardwareMonitor` | `librehardwaremonitor` | Sensores de temperatura/voltaje |
| Speedtest CLI | `Ookla.Speedtest.CLI` | `speedtest` | Test de ancho de banda |
| Nmap | `Insecure.Nmap` | `nmap` | Escaneo de puertos |
| Git | `Git.Git` | `git` | Control de versiones |

#### Características Destacadas
- **Captura no-fatal**: Cada bloque tiene su propio `try/catch` local; un fallo en una sección no aborta todo el diagnóstico.
- **Detección de tipo de disco**: Usa `MediaType` de WMI + heurísticas en el caption para clasificar SSD/HDD/NVMe.
- **Alertas inteligentes**: Temperatura > 55°C, desgaste SSD > 80%, desgaste batería > 80% generan warnings visuales.

---

### 3.2 optimizacion.ps1

**Versión:** 3.2.0  
**Requiere:** PowerShell como Administrador  
**Salida:** JSON de auditoría + backups de registro (.reg)

#### Propósito
Aplica optimizaciones progresivas al sistema Windows, siempre con backup previo del registro y snapshot de servicios para permitir deshacer cambios.

#### Parámetros

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `-Nivel` | string | `ligero` \| `estandar` \| `rendimiento` \| `extreme` |
| `-DryRun` | switch | Simula sin aplicar cambios |
| `-Undo` | switch | Restaura estado previo desde backup |
| `-BackupOnly` | switch | Solo crea copias de seguridad del registro |
| `-Help` | switch | Ayuda detallada |

#### Niveles de Optimización

| Nivel | Servicios Deshabilitados | Registro | Red | Otros |
|-------|-------------------------|----------|-----|-------|
| **ligero** | Ninguno | No | No | Limpieza TEMP |
| **estandar** | BITS, WSearch | No | No | Telemetría OFF |
| **rendimiento** | + DiagTrack, DPS | Memoria (DisablePagingExecutive, LargeSystemCache) | TCP tuning (autotuning, CTCP) | Plan alto rendimiento |
| **extreme** | + SysMain | + Explorer (AlwaysUnloadDLL) | + TCP Fast Open | Cortana/OneDrive/Bing |

> **NOTA CRÍTICA**: El servicio **Spooler** (cola de impresión) está **EXCLUIDO EXPLÍCITAMENTE** de la deshabilitación en todos los niveles para no afectar a usuarios con impresoras.

#### Archivos Generados

| Archivo | Ubicación | Propósito |
|---------|-----------|-----------|
| `optimizacion_<hostname>_<fecha>.json` | `../diagnosticos/` | Informe de acciones aplicadas |
| `estado_previo.json` | `%TEMP%\ResolveCore_Optimizacion/` | Snapshot de servicios para Undo |
| `*.reg` | `%TEMP%\ResolveCore_Optimizacion/backup/` | Backups de ramas del registro modificadas |
| `optimizacion.log` | `%TEMP%\ResolveCore_Optimizacion/` | Log de ejecución |

#### Función de Undo
1. Restaura plan de energía a "Equilibrado".
2. Revierte servicios a su `StartupType` original usando `estado_previo.json`.
3. Importa los archivos `.reg` de backup para restaurar el registro.

---

### 3.3 ResolveCore.ps1 (Menú Windows)

**Versión:** 1.0.0  
**Requiere:** PowerShell 5.1+, sesión de consola interactiva  
**Propósito**: Menú TUI interactivo para Windows. Equivalente al `ResolveCore.sh` de Linux.

#### Modos de Operación

1. **Menú interactivo** (sin argumentos): Banner + análisis proactivo del sistema + menú de 5 opciones.
2. **Pass-through diagnóstico**: Flags `-O`, `-S`, `-I`, `-A` se reenvían directamente a `diagnostico.ps1` sin mostrar el menú.
3. **Pass-through optimización**: Flags `-Nivel`, `-DryRun`, `-Undo`, `-BackupOnly` se reenvían a `optimizacion.ps1`.

#### Parámetros del Launcher

| Parámetro | Descripción |
|-----------|-------------|
| `-NoLoop` | Sale tras ejecutar una opción (útil para scripts wrapper) |
| `-h, -Help` | Ayuda detallada y sale |

#### Opciones del Menú

| Opción | Descripción |
|--------|-------------|
| 1. DIAGNÓSTICO | Ejecuta `diagnostico.ps1` |
| 2. OPTIMIZACIÓN | Sub-menú de nivel (ligero/estandar/rendimiento/extreme) |
| 3. VULNERABILIDADES | Lanza `buscar_vulnerabilidades.py` via Python |
| 4. AYUDA | Guía rápida embebida |
| 5. SALIR | Cierra con mensaje de despedida |

#### Análisis Proactivo (`Get-SystemAnalysis`)

Antes de mostrar el menú evalúa automáticamente:

| Comprobación | Umbral alerta | Severidad |
|---|---|---|
| Espacio disco C: | < 10 GB libre | critical |
| Espacio disco C: | < 20 GB libre | high |
| Uso memoria RAM | > 90% | critical |
| Uso memoria RAM | > 80% | high |
| Carga CPU | > 80% | high |
| Windows Update | Actualizaciones pendientes | medium |
| Servicios críticos (`wuauserv`, `WSearch`, `Spooler`) | Detenido | medium |
| Windows Defender | Desactivado | critical |
| Firmas antivirus | > 14 días sin actualizar | high |
| UAC | Desactivado | high |

#### Auto-instalación de Python

Si `buscar_vulnerabilidades.py` se selecciona y Python no está disponible, intenta instalarlo automáticamente vía:
1. Scoop (sin admin)
2. Chocolatey (requiere admin)

#### Validación de Exclusividad de Flags
Combinar flags de diagnóstico y optimización simultáneamente devuelve error (código 2) y sale sin ejecutar nada.

#### Códigos de Salida

| Código | Significado |
|--------|-------------|
| 0 | Salida normal |
| 1 | No interactivo (stdin redirigido) |
| 2 | Flags de diagnóstico y optimización combinados |

---

## 4. Scripts Linux

### 4.1 diagnostico.sh

**Versión:** 3.0.0 (con mejoras 3.1.0 en ensamblaje JSON)  
**Requiere:** Bash 4+, `jq` (obligatorio), root (recomendado)  
**Salida:** JSON estructurado + informe HTML

#### Propósito
Análisis completo del sistema Linux: hardware, kernel, red, seguridad y generación de JSON compatible con ResolveCore.

#### Parámetros

| Parámetro | Descripción |
|-----------|-------------|
| `-O, --output <dir>` | Directorio de salida |
| `-S, --silent` | Modo silencioso |
| `-I, --install` | Instala dependencias opcionales (apt/dnf/pacman/zypper) |
| `-A, --auto-install` | Instalación automática sin confirmar |

#### Dependencias Opcionales (multi-distribución)

| Comando | Debian | RHEL | Arch | openSUSE | Propósito |
|---------|--------|------|------|----------|-----------|
| `sensors` | lm-sensors | lm_sensors | lm_sensors | sensors | Temperatura CPU/GPU |
| `smartctl` | smartmontools | smartmontools | smartmontools | smartmontools | S.M.A.R.T. discos |
| `lspci` | pciutils | pciutils | pciutils | pciutils | Detección GPU |
| `jq` | jq | jq | jq | jq | Validación JSON |
| `bc` | bc | bc | bc | bc | Cálculos numéricos |

#### Secciones de Recolección

1. **Hardware**: CPU (núcleos, hilos, MHz, nombre, temperatura), RAM (total GB, módulos), discos (tipo, capacidad, SMART con atributos extendidos: sectores reubicados, pendientes, errores no corregibles, temperatura, horas de encendido), GPU (NVIDIA vía nvidia-smi o lspci), batería (carga, desgaste, ciclos).
2. **Sistema Operativo**: Distribución, versión, kernel, uptime, actualizaciones pendientes (apt/dnf/pacman), integridad de paquetes (dpkg/rpm), plan de energía (governor CPU).
3. **Drivers/Módulos**: Módulos cargados, errores en dmesg, módulos sin firma.
4. **Red**: Interfaz activa, DNS, latencia (ping a 8.8.8.8), pérdida de paquetes.
5. **Seguridad**: Firewall (UFW/firewalld/iptables), antivirus (ClamAV), SELinux/AppArmor.

#### Características Destacadas
- **Ensamblaje JSON vía `jq -n`**: Cada sección se pasa como `--argjson` y `jq` valida la estructura antes de escribir. Si falla, vuelca los fragmentos a un archivo `.debug.txt`.
- **Detección multi-distribución**: Soporta Debian, Ubuntu, RHEL, CentOS, Fedora, Arch, Manjaro, openSUSE.
- **S.M.A.R.T. extendido**: Extrae atributos críticos con `smartctl -A` y genera alertas para sectores reubicados o errores no corregibles.

---

### 4.2 optimizacion.sh

**Versión:** 3.1.0  
**Requiere:** Bash 4+, root obligatorio  
**Salida:** JSON de auditoría + backups en `/var/tmp/resolvecore_optimizacion/`

#### Propósito
Optimización progresiva del sistema Linux con backup previo de `sysctl.conf` y registro de servicios deshabilitados para undo.

#### Parámetros

| Parámetro | Descripción |
|-----------|-------------|
| `NIVEL` | `ligero` \| `estandar` \| `rendimiento` \| `extreme` |
| `--dry-run` | Simula sin aplicar |
| `--undo` | Restaura sysctl y servicios desde backup |

#### Niveles de Optimización

| Nivel | Limpieza | Servicios | Sysctl | Kernel Avanzado |
|-------|----------|-----------|--------|-----------------|
| **ligero** | Cache + logs antiguos | Ninguno | No | No |
| **estandar** | + journal vacuum | snapd off | swappiness | No |
| **rendimiento** | + | postfix off | rmem/wmem/tcp tuning | No |
| **extreme** | + | + | + dirty ratios | NUMA balancing |

#### Archivos de Backup

| Archivo | Ubicación | Propósito |
|---------|-----------|-----------|
| `sysctl.conf.bak` | `/var/tmp/resolvecore_optimizacion/` | Backup de sysctl antes de modificar |
| `services_disabled.log` | `/var/tmp/resolvecore_optimizacion/` | Lista de servicios deshabilitados |
| `optimizacion.log` | `/var/tmp/resolvecore_optimizacion/` | Log de ejecución |

#### Función de Undo
1. Restaura `/etc/sysctl.conf` desde backup y ejecuta `sysctl -p`.
2. Re-activa y re-inicia los servicios listados en `services_disabled.log`.
3. Elimina el log de servicios tras restauración exitosa.

---

### 4.3 ResolveCore.sh (Linux)

**Propósito**: Menú interactivo (TUI) que actúa como launcher para los scripts de diagnóstico y optimización de Linux.

#### Modos de Operación

1. **Menú interactivo** (sin argumentos): Muestra banner, opciones 1-5, y ejecuta el módulo seleccionado.
2. **Pass-through diagnóstico**: Flags `-O`, `-S`, `-I`, `-A` se reenvían directamente a `diagnostico.sh`.
3. **Pass-through optimización**: Flags `--dry-run`, `--undo` y nivel posicional se reenvían a `optimizacion.sh`.

#### Opciones del Menú

| Opción | Descripción |
|--------|-------------|
| 1. DIAGNÓSTICO | Análisis completo del sistema |
| 2. OPTIMIZACIÓN | Optimización con selección de nivel |
| 3. VULNERABILIDADES | Ejecuta `buscar_vulnerabilidades.py` (CVEs) |
| 4. AYUDA | Guía rápida embebida |
| 5. SALIR | Cierra el programa |

#### Características
- **Auto-instalación de dependencias**: Si falta `python3` o `adb`, intenta instalarlos vía `apt-get`, `dnf` o `pacman`.
- **Análisis del sistema**: Al mostrar el banner, evalúa espacio en disco, memoria, carga CPU y actualizaciones pendientes para dar recomendaciones proactivas.
- **Validación de exclusividad**: No permite combinar flags de diagnóstico y optimización simultáneamente.

---

## 5. Scripts Android

### 5.1 diagnostico_android.sh

**Versión:** 2.1.0  
**Requiere:** `adb`, `jq`, dispositivo con depuración USB habilitada y autorizada  
**Salida:** JSON estructurado + HTML

#### Propósito
Recoge métricas de dispositivos Android conectados vía ADB (Android Debug Bridge) y genera un diagnóstico completo compatible con ResolveCore.

#### Parámetros

| Parámetro | Descripción |
|-----------|-------------|
| `SERIAL` (posicional) | Número de serie del dispositivo ADB |
| `-O, --output <dir>` | Directorio de salida |
| `-h, --help` | Ayuda |

#### Secciones de Recolección

1. **Dispositivo**: Fabricante, modelo, marca, nombre interno, serial.
2. **Hardware**: CPU (nombre, núcleos), RAM (total GB), almacenamiento interno (/data: total/usado/libre), tarjeta SD (presente/ausente).
3. **Batería**: Nivel de carga, estado (cargando/descargando/completa), salud (buena/sobrecalentamiento/deteriorada), temperatura, voltaje, ciclos de carga, desgaste % (capacidad actual vs diseño), tecnología.
4. **Temperatura CPU**: Lee zonas térmicas del kernel (`/sys/class/thermal/thermal_zone*/`).
5. **Red**: WiFi (SSID, IP, señal RSSI en dBm), latencia (ping a 8.8.8.8 desde el dispositivo), pérdida de paquetes.
6. **Seguridad**: Estado del bootloader (bloqueado/desbloqueado), cifrado (FBE/FDE), fuentes desconocidas, modo desarrollador, root (detección de binarios `su`), SELinux.
7. **Aplicaciones**: Total de apps instaladas, desglose usuario/sistema.
8. **Sistema Operativo**: Versión Android, SDK, build, kernel, arquitectura, parche de seguridad.

#### Características Destacadas
- **Ensamblaje JSON vía `jq -n`**: Similar al script Linux, cada sección se valida antes de persistir.
- **Detección de desgaste de batería**: Usa múltiples métodos (`/sys/class/power_supply/battery/charge_full` vs `charge_full_design`, `dumpsys batterystats`).
- **Detección de ciclos**: Lee `cycle_count` desde sysfs si está disponible.
- **Detección de root**: Busca binarios `su` en rutas comunes (`/system/bin/su`, `/sbin/su`, etc.).

---

### 5.2 optimizacion_android.sh

**Versión:** 3.1.0  
**Requiere:** `adb`, dispositivo autorizado  
**Salida:** JSON de auditoría + log de apps deshabilitadas

#### Propósito
Optimiza el rendimiento de dispositivos Android aplicando limpieza de caché y, opcionalmente, deshabilitando apps preinstaladas no esenciales (bloatware).

> **FIX CRÍTICO v3.1.0**: En versiones anteriores usaba `pm clear` que borraba **todos los datos** de las apps (logins, ajustes, archivos). Se sustituyó por `pm trim-caches` que solo elimina la caché, preservando datos de usuario.

#### Parámetros

| Parámetro | Descripción |
|-----------|-------------|
| `NIVEL` | `ligero` \| `estandar` \| `rendimiento` \| `extreme` |
| `--serial <id>` | Dispositivo ADB específico |
| `--dry-run` | Simula sin aplicar |
| `--confirm` | Requerido para niveles destructivos (rendimiento/extreme) |
| `--undo` | Reactiva apps deshabilitadas en sesiones previas |
| `-O, --output <dir>` | Directorio del informe |

#### Niveles de Optimización

| Nivel | Acciones |
|-------|----------|
| **ligero** | `pm trim-caches` (solo caché) |
| **estandar** | trim-caches + servicios no críticos |
| **rendimiento** | + deshabilitar bloatware (requiere `--confirm`) |
| **extreme** | + ajustes agresivos (requiere `--confirm`) |

#### Apps Deshabilitadas (rendimiento/extreme)

```bash
com.android.soundrecorder    # Grabadora de sonido
com.android.stk              # SIM Toolkit
com.android.provision        # Provisión inicial (typo corregido en v3.1.0)
```

#### Archivos Generados

| Archivo | Propósito |
|---------|-----------|
| `optimizacion_android_<serial>_<fecha>.json` | Informe de acciones |
| `android_<serial>_disabled.log` | Lista de apps deshabilitadas (para `--undo`) |

#### Función de Undo
Lee el archivo `android_<serial>_disabled.log` y ejecuta `pm enable --user 0 <paquete>` para cada app listada, luego elimina el log.

---

### 5.3 ResolveCore.sh (Android)

**Propósito**: Menú interactivo para técnicos ResolveCore en Android. Idéntico en estructura al menú Linux pero adaptado para ADB.

#### Opciones del Menú

| Opción | Descripción |
|--------|-------------|
| 1. DIAGNÓSTICO | Ejecuta `diagnostico.sh` |
| 2. OPTIMIZACIÓN | Ejecuta `optimizacion.sh` con selección de nivel |
| 3. VULNERABILIDADES | Ejecuta `buscar_vulnerabilidades.py` |
| 4. AYUDA | Guía rápida embebida |
| 5. SALIR | Cierra |

#### Características
- **Pass-through**: Soporta reenvío directo de flags a los scripts subyacentes.
- **Validación ADB**: Verifica que `adb` esté instalado y que haya dispositivos conectados antes de mostrar el menú.
- **Auto-instalación**: Intenta instalar `python3` y `adb` automáticamente si faltan.

---

## 6. Formato de Salida JSON

### Estructura Común (v3.x)

Todos los scripts generan JSON con una estructura base similar:

```json
{
  "hardware": { ... },
  "sistema_operativo": { ... },
  "red": { ... },
  "seguridad": { ... },
  "aplicaciones": { ... },        // Android
  "servicios": { ... },           // Windows
  "drivers": { ... },              // Linux
  "software": { ... },             // Windows
  "rendimiento": { ... },          // Windows
  "usuarios": [ ... ],             // Windows
  "discos": { ... },               // Windows
  "gpu": [ ... ],                  // Windows
  "smart": [ ... ],                // Windows
  "placa_base": { ... },           // Windows
  "bateria": { ... },              // Windows/Linux/Android
  "_meta": {
    "version": "3.2.0",
    "plataforma": "windows|linux|android",
    "hostname": "...",
    "generado_en": "2026-05-12T09:55:00Z",
    "admin": true|false
  }
}
```

### Campos de Optimización

```json
{
  "plataforma": "windows|linux|android",
  "hostname|serial": "...",
  "nivel": "ligero|estandar|rendimiento|extreme",
  "dry_run": false,
  "acciones": [
    "limpieza_temp_mb:150.2",
    "servicio_desactivado:BITS",
    "plan_energia:rendimiento",
    "registro_memoria",
    "tcp_tuning"
  ],
  "generado_en": "2026-05-12T09:55:00Z",
  "_meta": { "version": "3.2.0" }
}
```

---

## 7. Consideraciones de Seguridad

### Permisos Requeridos

| Script | Mínimo | Recomendado | Justificación |
|--------|--------|-------------|---------------|
| `diagnostico.ps1` | Usuario estándar | Administrador | Métricas completas de SMART, servicios, firewall |
| `optimizacion.ps1` | **Administrador** | Administrador | Modificación de registro, servicios, plan de energía |
| `diagnostico.sh` | Usuario estándar | root | SMART extendido, sensores, módulos del kernel |
| `optimizacion.sh` | **root** | root | Modificación de sysctl, servicios systemd |
| `diagnostico_android.sh` | Usuario estándar | Usuario estándar | ADB ya corre con privilegios del demonio adb |
| `optimizacion_android.sh` | Usuario estándar | Usuario estándar | No requiere root en el dispositivo |

### Exclusiones de Seguridad Explícitas

- **Spooler (Windows)**: Nunca se desactiva en optimización para no romper la impresión.
- **Servicios críticos (Linux)**: `systemd-journald`, `networking`, `ssh` nunca se tocan.
- **Apps del sistema (Android)**: Solo se deshabilitan apps no esenciales (grabadora, SIM Toolkit), nunca framework o Google Play Services.

### Backups y Reversibilidad

| Plataforma | Mecanismo de Backup | Mecanismo de Undo |
|-----------|--------------------|-------------------|
| Windows | `reg export` (.reg) + `estado_previo.json` | `reg import` + `Set-Service` |
| Linux | `cp /etc/sysctl.conf` + `services_disabled.log` | `cp` inversa + `systemctl enable/start` |
| Android | `android_<serial>_disabled.log` | `pm enable` por cada paquete |

---

## 8. Tabla Comparativa

| Característica | Windows (PS) | Linux (Bash) | Android (Bash+ADB) |
|---------------|--------------|--------------|-------------------|
| **Lenguaje** | PowerShell 5.1+ | Bash 4+ | Bash 4+ |
| **Interfaz** | CLI + Help | CLI + Menú TUI | CLI + Menú TUI |
| **JSON** | `ConvertTo-Json` | `jq -n` (validado) | `jq -n` (validado) |
| **HTML** | Sí (plantilla informe.html) | Sí (plantilla informe.html) | Sí (plantilla informe.html) |
| **Dry Run** | Sí | Sí | Sí |
| **Undo** | Sí (registro + servicios) | Sí (sysctl + servicios) | Sí (apps deshabilitadas) |
| **Instalación deps** | winget / choco | apt/dnf/pacman/zypper | apt/brew (host) |
| **Niveles opt.** | 4 (ligero a extreme) | 4 (ligero a extreme) | 4 (ligero a extreme) |
| **SMART** | StorageReliabilityCounter | smartctl -A | N/A (Flash) |
| **Temperatura** | WMI / LibreHardwareMonitor | lm-sensors / thermal zones | thermal zones (sysfs) |
| **GPU** | Win32_VideoController / nvidia-smi | lspci / nvidia-smi | N/A |
| **Firewall** | Get-NetFirewallProfile | ufw/firewalld/iptables | SELinux |
| **Antivirus** | Get-MpComputerStatus | ClamAV | N/A |
| **Batería** | Win32_Battery / WMI | sysfs power_supply | dumpsys battery / sysfs |
| **Root requerido** | Opt: Admin / Opt: root | Opt: root / Req: root | No |

---

## 9. buscar_vulnerabilidades.py

**Versión:** 1.0.0  
**Requiere:** Python 3.8+, sin dependencias pip (solo stdlib)  
**Plataformas:** Windows, Linux, Android (host), multiplataforma  
**Invocación:** desde los menús `ResolveCore.ps1`, `ResolveCore.sh` (Linux) y `ResolveCore.sh` (Android)

### Propósito

Escáner unificado de vulnerabilidades. Construye inventario de software instalado, consulta CVEs en APIs públicas y genera informe de riesgos. Política: solo software libre y APIs públicas (NVD, CISA KEV, OSV, EPSS-FIRST). Sin dependencias externas pip.

### APIs Utilizadas

| API | URL | Propósito |
|-----|-----|-----------|
| NVD 2.0 | `services.nvd.nist.gov/rest/json/cves/2.0` | Búsqueda de CVEs por software |
| CISA KEV | `cisa.gov/.../known_exploited_vulnerabilities.json` | Vulnerabilidades explotadas activamente |
| OSV | `api.osv.dev/v1/query` | Vulnerabilidades en dependencias de proyecto |
| EPSS (FIRST) | `api.first.org/data/v1/epss` | Probabilidad de explotación por CVE |

Rate limit NVD sin API key: 6 s entre requests (`NVD_SLEEP = 6.0`).

### Fuentes de Inventario de Software

| Plataforma | Método |
|---|---|
| Windows | Registro (`HKLM/HKCU Software\Microsoft\Windows\CurrentVersion\Uninstall`) |
| Linux | `dpkg -l`, `rpm -qa`, `pacman -Q` según distribución |
| Android | `adb shell pm list packages` |

### Puertos de Riesgo Monitorizados

| Puerto | Servicio | Severidad |
|--------|----------|-----------|
| 21 | FTP (sin cifrar) | HIGH |
| 23 | Telnet | CRITICAL |
| 135/139 | RPC/NetBIOS | MEDIUM/HIGH |
| 445 | SMB | HIGH |
| 3389 | RDP expuesto | HIGH |
| 6379 | Redis sin auth | CRITICAL |
| 27017 | MongoDB sin auth | CRITICAL |

### Análisis de Dependencias de Proyecto

Detecta y consulta automáticamente archivos de dependencias:

| Archivo | Ecosistema |
|---------|-----------|
| `requirements.txt` | PyPI |
| `package.json` | npm |
| `pom.xml` / `build.gradle` | Maven |
| `Gemfile` | RubyGems |
| `go.sum` | Go |
| `composer.json` | Packagist |

### Características Destacadas

- **CPE matching**: Verifica si el CVE afecta la versión instalada exacta (reduce falsos positivos).
- **Deduplicación de software**: Elimina duplicados por nombre normalizado, conserva versión más alta.
- **Filtros de ruido**: Descarta entradas como "Update for Microsoft...", "Security Update", SDKs de herramientas de desarrollo que no aportan valor de CVE.
- **Normalización de nombres**: Mapea nombres de software comunes a keywords efectivos para la API NVD (p.ej. "Oracle VirtualBox" → "virtualbox").
- **Límite de queries**: `MAX_SOFTWARE_QUERIES = 25` para respetar rate limits de la API.

---

## 10. Scripts de Instalación / Aprovisionamiento

Scripts para provisionar la máquina física del técnico desde cero. No son scripts de diagnóstico — configuran el stack completo de ResolveCore (Nginx + PHP + MariaDB + WordPress + MantisBT + AnyDesk).

### 10.1 post-install.sh (Linux)

**Ruta:** `scripts/iso/linux/post-install.sh`  
**Requiere:** Ubuntu/Debian, root (`sudo`), internet  
**Uso:** `sudo bash post-install.sh`

#### Propósito

Provisiona la máquina del técnico con el stack completo de ResolveCore en Ubuntu Desktop 22.04/24.04 LTS. Diseñado para ejecutarse en instalación limpia.

#### Componentes Instalados

| Componente | Versión | Propósito |
|---|---|---|
| Nginx | Última estable | Servidor web + reverse proxy |
| PHP-FPM | 8.2 (PPA ondrej) | Backend WordPress + MantisBT |
| MariaDB | Última estable | Base de datos |
| WordPress | Última (WP-CLI) | Frontend de soporte (es_ES) |
| MantisBT | 2.28.1 | Gestión de tickets |
| wkhtmltopdf | 0.12.6 | Generación PDF de informes |
| PowerShell 7 | Última (repo Microsoft) | Compatibilidad scripts Windows |
| AnyDesk | Última | Acceso remoto |

#### Seguridad

- Contraseñas generadas aleatoriamente con `openssl rand`.
- Credenciales guardadas en `/root/resolvecore-credentials.txt` (permisos 600, solo root).
- MariaDB securizado (equivalente a `mysql_secure_installation`).
- UFW habilitado: solo SSH + HTTP permitidos.
- Directorio `/mantis/admin/` bloqueado en Nginx (403).

#### Dominio Local

Configura `resolvecore.local` en `/etc/hosts`. Acceso tras instalación:
- WordPress: `http://resolvecore.local`
- MantisBT: `http://resolvecore.local/mantis/`

#### Códigos de Salida

| Código | Significado |
|--------|-------------|
| 0 | Setup completado |
| 1 | Error fatal en cualquier paso |

---

### 10.2 setup.ps1 (Windows)

**Ruta:** `scripts/iso/windows/setup.ps1`  
**Requiere:** PowerShell 7+, Administrador, internet  
**Uso:** `pwsh -ExecutionPolicy Bypass -File setup.ps1`

#### Propósito

Equivalente Windows de `post-install.sh`. Provisiona la máquina del técnico en Windows 10/11 con el stack completo usando Chocolatey como gestor de paquetes.

#### Componentes Instalados

| Componente | Método | Propósito |
|---|---|---|
| Chocolatey | Script oficial | Gestor de paquetes |
| PHP 8.2 | choco | Backend |
| Nginx | choco + NSSM | Servidor web como servicio Windows |
| MariaDB | choco | Base de datos |
| WordPress | WP-CLI (phar) | Frontend |
| MantisBT | 2.28.1 (GitHub tarball + 7zip) | Tickets |
| wkhtmltopdf | choco | PDF |
| AnyDesk | choco | Acceso remoto |
| Git, 7zip, NSSM | choco | Herramientas base |

#### Diferencias respecto a post-install.sh

| Aspecto | Linux | Windows |
|---|---|---|
| Gestor paquetes | apt-get | Chocolatey |
| PHP-FPM | Servicio systemd | `php-cgi` en modo FastCGI |
| Nginx | Servicio systemd | Servicio Windows via NSSM |
| Contraseñas | `openssl rand -base64` | `New-Guid` truncado |
| Instalación base | `/var/www/` | `C:\ResolveCore\www\` |
| Log | `/var/log/resolvecore-install.log` | `C:\ResolveCore\install.log` |
| Credenciales | `/root/resolvecore-credentials.txt` | `C:\ResolveCore\credenciales.txt` |

#### Códigos de Salida

| Código | Significado |
|--------|-------------|
| 0 | Setup completado |
| 1 | Error fatal |

---

### 10.3 autoinstall.yaml (Ubuntu preseed)

**Ruta:** `scripts/iso/linux/autoinstall.yaml`  
**Formato:** Ubuntu Autoinstall (cloud-init v1)  
**Propósito:** Instalación desatendida de Ubuntu Server 24.04 LTS para la máquina del técnico.

#### Uso

1. Descargar ISO Ubuntu Server 24.04.
2. En el boot del instalador, pasar al kernel:
   ```
   autoinstall ds=nocloud-net;s=http://TU_SERVIDOR/
   ```
3. El instalador aplica este YAML automáticamente (sin intervención manual).

#### Configuración Base

| Parámetro | Valor |
|---|---|
| Hostname | `resolvecore` |
| Usuario | `tecnico` |
| Locale | `es_ES.UTF-8` |
| Teclado | `es` |
| Zona horaria | `Europe/Madrid` |
| Red | DHCP en primera interfaz `en*` |
| Almacenamiento | LVM, todo el disco |

#### Paquetes Base Instalados

`curl`, `wget`, `git`, `unzip`, `htop`, `net-tools`, `ufw`

#### Primer Arranque Automático

El `late-commands` del YAML descarga `post-install.sh` desde GitHub y crea un servicio systemd `resolvecore-firstboot.service` que lo ejecuta al primer arranque (tras `network-online.target`). Una vez completado, el script se autoeliminan.

---

## Apéndice: Glosario de Términos

| Término | Descripción |
|---------|-------------|
| **ADB** | Android Debug Bridge. Herramienta de línea de comandos para comunicarse con dispositivos Android. |
| **S.M.A.R.T.** | Self-Monitoring, Analysis and Reporting Technology. Sistema de monitoreo de salud de discos. |
| **Sysctl** | Interfaz para examinar y modificar dinámicamente parámetros del kernel Linux. |
| **Swappiness** | Tendencia del kernel a usar swap (0-100). Valores bajos = más RAM, menos swap. |
| **Bloatware** | Software preinstalado no esencial que consume recursos. |
| **Governor CPU** | Algoritmo que controla la frecuencia del procesador (performance, powersave, ondemand). |
| **WMI** | Windows Management Instrumentation. Infraestructura de gestión de datos y operaciones en Windows. |
| **Thermal Zone** | Zona térmica del kernel Linux para monitoreo de temperatura de componentes. |

---

*Documento generado a partir del análisis de código fuente de ResolveCore v3.2.0 (Windows), v3.1.0 (Linux), v2.1.0 (Android), v1.0.0 (buscar_vulnerabilidades.py). Última actualización: 2026-05-12.*
