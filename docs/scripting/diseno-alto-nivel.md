# Diseño a Alto Nivel del Scripting de ResolveCore

> **Autor:** Francisco Vidal Mateo · TFG ASIR 2024/25

Este documento define la arquitectura lógica y la delegación de responsabilidades de los scripts que conforman el "Core" de diagnóstico y soporte de ResolveCore.

## 1. Paradigma de Diseño

El sistema de scripting se basa en un diseño **modular y desacoplado**. Las fases de recolección de datos, análisis de vulnerabilidades y generación de informes operan de forma independiente y se comunican a través de un contrato de datos estándar: un archivo **JSON unificado**.

Esto garantiza que el generador de informes en PDF funcione igual independientemente de si los datos provienen de un Windows 11 o de un servidor Ubuntu.

## 2. Arquitectura de Componentes (Scripts)

### 2.1. Componente Windows: PowerShell 7+ (`scripts/windows/diagnostico.ps1`)
**Propósito:** Extracción profunda de métricas del sistema operativo Windows.
**Justificación técnica:** PowerShell maneja objetos nativos (CIM/WMI). Se evita parsear texto como haría Bash o CMD.
**Acciones de alto nivel:**
- Consulta de salud del Disco (WMI S.M.A.R.T.).
- Análisis del EventLog buscando errores críticos del sistema.
- Listado de software instalado y parches de Windows Update faltantes.
- Generación y exportación de un bloque estructurado con `ConvertTo-Json`.

### 2.2. Componente Linux y Android: Bash (`scripts/linux/diagnostico.sh`)
**Propósito:** Extracción de métricas mediante utilidades base de UNIX sin dependencias extrañas.
**Justificación técnica:** Bash garantiza la ejecución en entornos limitados o servidores sin Python instalado.
**Acciones de alto nivel:**
- Ejecución de `top`, `df`, `ss`, `journalctl` extrayendo el texto y formateándolo.
- En el caso de **Android**, el script de Bash actúa como orquestador, enviando comandos al dispositivo del cliente conectado vía red mediante **ADB (Android Debug Bridge)** (`adb shell dumpsys battery`, etc.).

### 2.3. Componente de Ciberseguridad: Python (`scripts/common/buscar_vulnerabilidades.py`)
**Propósito:** Escaneo y cruce de datos contra bases de datos globales de inteligencia de amenazas.
**Justificación técnica:** Python facilita enormemente las peticiones HTTP concurrentes a APIs REST y el manejo de estructuras JSON complejas.
**Acciones de alto nivel:**
- **Shodan API:** Análisis de puertos expuestos de forma pasiva sobre la IP pública del cliente.
- **NVD / CISA KEV:** Cruce de las versiones del software extraído (por PowerShell/Bash) contra bases de datos de vulnerabilidades conocidas (CVEs).

## 3. Flujo Lógico de Ejecución

1. **Launcher TUI (Text User Interface):** El técnico inicia `ResolveCore.ps1` (o `.sh`). Aparece un menú de opciones.
2. **Orquestación Local:** El script detecta el OS, extrae las credenciales o parámetros de entorno (ej. Tokens API para Shodan).
3. **Ejecución del Motor (Engine):** PowerShell o Bash recaban los datos de hardware, procesos y red.
4. **Análisis Secundario:** El script base llama al binario de Python (`python3 buscar_vulnerabilidades.py`) pasándole el listado de software recolectado.
5. **Consolidación JSON:** Todos los datos se unen en un único archivo estructurado (`diagnostico_cliente.json`).
6. **Generación HTML/PDF:** Un módulo final formatea el JSON en una plantilla HTML legible (`informe.html`), inyectando los datos de forma segura, listo para ser adjuntado por el técnico al ticket de MantisBT.

## 4. Estructura del JSON Estándar (Contrato de Datos)
Todos los scripts (Bash, PowerShell, Python) deben construir un árbol JSON que respete esta semántica:

```json
{
  "metadata": { "platform": "Windows|Linux", "timestamp": "ISO8601" },
  "hardware": { "cpu": "...", "ram": "...", "disk_health": "Good|Warning" },
  "security": { "open_ports": [], "cves_found": [] },
  "score": 85
}
```
