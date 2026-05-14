# Guía de Estudio y Defensa de Scripts ante el Tribunal

> **Documento de estudio técnico**
> Diseñado exclusivamente para preparar la defensa oral del TFG. Contiene la explicación técnica, flujo lógico y justificación de **TODOS** los scripts del proyecto ResolveCore, orientados a responder preguntas de un tribunal evaluador ASIR.
> **Autor:** Francisco Vidal Mateo (Haplee)

---

## 1. Filosofía de Código y Decisiones Globales

Antes de defender un script individual, debes tener clara la defensa de las decisiones transversales del proyecto:

1.  **Por qué PowerShell 5.1 en Windows**: Porque es nativo en Windows 10/11. Exigir PowerShell 7 obligaría al técnico a instalar dependencias previas en la máquina remota del cliente, añadiendo fricción al servicio.
2.  **Por qué Bash y no Python para diagnósticos en Linux**: Bash y las utilidades estándar GNU/Linux (`top`, `df`, `lsblk`, `ip`) están presentes en todas las distribuciones. Python no siempre viene instalado por defecto en servidores mínimos (ej. Alpine, contenedores).
3.  **Por qué Python *sólo* para el escáner de vulnerabilidades**: Porque la complejidad de parsear JSONs de múltiples APIs (NVD, OSV, Shodan) y correlacionarlos es inmanejable en Bash/PowerShell puro de forma cruzada. Python stdlib permite usar el *mismo código* en los cuatro sistemas operativos.
4.  **Por qué `set -uo pipefail` sin `-e` en Bash**: Para diagnósticos, un comando fallido (ej. `sensors` si no hay hardware) no debe detener la recolección del resto del JSON. El script captura el error granularmente y escribe `"null"` en el JSON.
5.  **Cero dependencias cerradas (No winget / No pip)**: Se respeta una política estricta de Open Source. Los scripts usan `urllib` en vez de `requests` para no requerir `pip install`. En Windows se prefiere Scoop/Choco si no hay winget, evitando la Microsoft Store.

---

## 2. Scripts de Windows (`scripts/windows/`)

### 2.1 `ResolveCore.ps1` (Launcher interactivo)
*   **Propósito**: Punto de entrada unificado para el técnico (CLI TUI).
*   **Flujo Lógico**:
    1. Comprueba si se invoca con *flags* (ej. `-Silent` o `-Nivel`). Si es así, actúa como pasarela e invoca directamente a los scripts hijos (`diagnostico.ps1` u `optimizacion.ps1`).
    2. Si es interactivo, pinta el menú.
    3. Comprueba Python antes de invocar la opción 3 (Vulnerabilidades). Si no está, lo instala por Scoop o Choco.
*   **Defensa**: El doble modo (interactivo/pasarela) permite usar exactamente el mismo fichero para uso manual de un técnico y para tareas programadas (cron/Task Scheduler) sin duplicar código.

### 2.2 `diagnostico.ps1` (v3.2.0 / Schema v4.0.0)
*   **Propósito**: Extrae la telemetría del equipo (HW, OS, Red, Seguridad) y vuelca un JSON unificado (ahora todo el hardware agrupado en la clave `hardware`).
*   **Flujo Lógico**:
    1. Revisa privilegios de administrador.
    2. Gestión de flags (`-InstallDeps` detecta herramientas extra como `smartmontools` o `speedtest`).
    3. Llamadas WMI (`Get-CimInstance`). *Dato técnico a mencionar:* Se usa `Get-CimInstance` en lugar de `Get-WmiObject` porque este último está obsoleto desde PS 3.0.
    4. Ensamblaje progresivo de diccionarios ordenados (`[ordered]@{}`) que al final se convierten con `ConvertTo-Json -Depth 10`.
*   **Defensa (Tribunal):** *"¿Por qué haces lecturas S.M.A.R.T. extendidas?"* -> "Porque el flag predeterminado de Windows a menudo miente hasta que el disco está literalmente muerto. `Get-StorageReliabilityCounter` da errores de lectura directos."

### 2.3 `optimizacion.ps1` (v3.2.0)
*   **Propósito**: Realiza afinamiento del sistema operativo según 4 niveles de agresividad (ligero, estandar, rendimiento, extreme).
*   **Flujo Lógico**:
    1. Validación estricta del flag `-DryRun` por seguridad.
    2. Backup obligatorio del estado de servicios en `estado_previo.json` y del registro (ramas tocadas).
    3. Desactivación de Telemetría, Cortana, Indexado (según nivel).
*   **Defensa (Tribunal):** *"Si aplico el nivel extremo, ¿qué rompo?"* -> "Romperá OneDrive y la búsqueda de Windows (SysMain). Por eso el script fuerza backups previos y permite ejecutar `--Undo`. Cabe destacar que **nunca se deshabilita el Spooler de impresión**, decisión explícita para evitar incidencias en clientes de oficina."

---

## 3. Scripts de Linux (`scripts/linux/`)

### 3.1 `ResolveCore.sh` (Launcher interactivo)
*   **Propósito**: Análogo al de Windows pero en Bash.
*   **Defensa**: Identifica dinámicamente el gestor de paquetes del sistema (`apt`, `dnf`, `pacman`, `zypper`) para la auto-instalación de Python. Esto garantiza que funcione tanto en servidores Debian/Ubuntu como en RedHat/Fedora o Arch.

### 3.2 `diagnostico.sh` (v3.0.0)
*   **Propósito**: Equivalente funcional al de Windows. Produce el mismo modelo JSON.
*   **Flujo Lógico**:
    1. Parseo de argumentos con bucle `while [[ $# -gt 0 ]]`.
    2. Usa utilidades del core: `/proc/cpuinfo`, `lsblk`, `smartctl`, `ip route`.
    3. Para construir JSON seguro usa la función `json_num` y `json_escape`.
*   **Defensa (Tribunal):** *"¿Por qué construyes el JSON a mano con variables concatenadas en Bash en vez de usar `jq` para formarlo?"* -> "Para minimizar dependencias en sistemas pelados. Aunque se pide `jq` para validar, la construcción nativa asegura que si el equipo no puede instalar nada, aún se genere un JSON rudimentario. Las funciones de escape blindan frente a comillas rotas."

### 3.3 `optimizacion.sh` (v3.1.0)
*   **Propósito**: Limpieza de journalctl, ajuste de `swappiness`, mitigaciones zram.
*   **Defensa**: Implementa idempotencia en sus archivos de backup (`/var/tmp/resolvecore_optimizacion/`). Mantiene a salvo `/etc/sysctl.conf` comprobando previamente si la regla existe para no inyectarla dos veces.

---

## 4. Scripts de Android (`scripts/android/`)

### 4.1 `diagnostico.sh` & `optimizacion.sh`
*   **Propósito**: Actuar sobre dispositivos Android del cliente usando ADB (Android Debug Bridge).
*   **Defensa (Tribunal):** *"¿Por qué usas ADB en lugar de crear una APK?"* -> "Por escalabilidad y seguridad. Pedir al cliente que instale un APK fuera de la Play Store genera rechazo y alertas de Play Protect. ADB funciona de forma nativa por cable o Wi-Fi sin alterar permanentemente el equipo. En la optimización se corrigió un fallo crítico: usar `pm trim-caches` en vez del destructivo `pm clear`."

---

## 5. Scripts de macOS (`scripts/macos/`)

### 5.1 Los "Stubs" (`diagnostico.sh`, `optimizacion.sh`)
*   **Propósito**: Demonstrar la arquitectura modular multiplataforma devolviendo un `_meta.stub: true`.
*   **Defensa (Tribunal):** *"¿Por qué macOS está incompleto?"* -> "Es una decisión de ética y seguridad (declarada en el roadmap). macOS cierra continuamente el acceso a partes del core (SIP, volúmenes de solo lectura). Un script bash destructivo de macOS no es seguro sin probarlo exhaustivamente en silicio Apple (M1/M2/M3). Mantener el *stub* permite que la plataforma web lo parsee sin romperse mientras se desarrolla la versión final segura."

---

## 6. Integración y Python (`scripts/common/`)

### 6.1 `buscar_vulnerabilidades.py` (v1.0.0)
*   **Propósito**: El motor central del proyecto. Analiza el JSON/Inventario, consulta APIs (NVD, OSV, CISA KEV, EPSS), audita puertos/configuraciones y calcula el *RiskScore*.
*   **Arquitectura (11 fases)**: `PlatformDetector` (inventaría apps) -> `CISAKEVCache` (baja feed de explotados activos) -> `VulnScanner` (Threadding de NVD y OSV) -> `RiskScorer` (calcula puntos) -> `MantisBTClient` (envía resultado).
*   **Defensa (Tribunal):** *"Si el script no usa pip, ¿cómo haces las peticiones web de forma segura?"* -> "Usando `urllib.request` con validación estricta de TLS/SSL por defecto (`ssl.create_default_context()`). Se prefiere no forzar `requests` para cumplir la máxima de no depender de instalaciones de terceros, garantizando la ejecución inmediata."
*   **Defensa avanzada**: *"¿Por qué añades EPSS y KEV además del CVSS?"* -> "CVSS mide gravedad estática. KEV mide si está siendo explotado hoy. EPSS mide la probabilidad futura de explotación. Priorizar solo por CVSS (NVD) es obsoleto y arroja demasiados falsos positivos en entornos corporativos."

### 6.2 `shodan_lookup.py` (v1.0.0)
*   **Propósito**: Consultar la exposición pública (puertos, servicios, CVEs) de una IP usando la API de Shodan.
*   **Arquitectura**: Consta de gestión de créditos (`--info`), conexión REST pura y normalización de la salida a formato consola o JSON.
*   **Defensa (Tribunal):** *"¿Qué pasa si la respuesta de la API no es un JSON estándar o cambia el tipo de dato?"* -> "Está securizado en el script. Por ejemplo, en la fase de CVEs, capturamos el `cvss` crudo e intentamos convertirlo a `float` gestionando `ValueError` y `TypeError`, porque Shodan devuelve inconsistencias de tipos. Además controlamos el crédito del tier gratuito explícitamente y mostramos los créditos restantes con `api-info` antes de agotar la cuota."

---

## 7. Despliegue y Auxiliares

### 7.1 `bootstrap-mantis.sh` & `mantisbt/plugins/install.sh`
*   **Propósito**: Descargar MantisBT al entorno de desarrollo e instalar los plugins requeridos de forma desatendida.
*   **Defensa**: Idempotencia. Comprueba primero si el directorio o archivo `.tar.gz` ya está presente para evitar desgastar ancho de banda y perder tiempo. Ideal para integrarlo en un pipeline CI/CD en el futuro.

### 7.2 Scripts ISO (`setup.ps1` & `post-install.sh`)
*   **Propósito**: Para incluir en imágenes custom (.iso/.qcow2) e instalar de serie las herramientas en clientes que requieran equipos pre-configurados.
*   **Defensa**: Usan los metadatos de Autounattend (Windows) y Cloud-init (Linux) para ejecutar tareas de system administration en el instante de primer boot, dejando programadas tareas programadas cron/schtasks para lanzar diagnósticos diarios.

---

## Resumen Final para el Tribunal

*"Este proyecto no es una colección aleatoria de scripts de mantenimiento. Es una arquitectura distribuida donde el agente final (los scripts) se ejecuta de forma **nativa y limpia** en el SO del cliente sin polucionarlo con agentes instalables (EDR), mientras el análisis de inteligencia y ticketing se consolida remotamente a través de APIs documentadas. Cada línea respeta los principios ASIR de idempotencia, seguridad por defecto (DryRun) y compatibilidad retroactiva."*
