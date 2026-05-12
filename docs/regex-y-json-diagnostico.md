# ResolveCore — Expresiones Regulares y Estructura JSON (diagnostico.sh)

---

## Índice

1. [Expresiones Regulares](#1-expresiones-regulares)
   - 1.1 [Validación numérica](#11-validación-numérica)
   - 1.2 [Integer limpio](#12-integer-limpio)
   - 1.3 [Confirmación de usuario](#13-confirmación-de-usuario)
   - 1.4 [Extracción de temperatura](#14-extracción-de-temperatura-con-k)
   - 1.5 [Horas SMART con comas](#15-horas-smart-con-comas)
   - 1.6 [Número con word boundary](#16-número-con-word-boundary)
   - 1.7 [Ancla de inicio de línea](#17-ancla-de-inicio-de-línea-)
   - 1.8 [Alternaciones](#18-alternaciones-con-)
   - 1.9 [Patrón AWK dpkg](#19-patrón-awk-dpkg)
2. [Estructura JSON de Salida](#2-estructura-json-de-salida)
   - 2.1 [Esquema completo](#21-esquema-completo)
   - 2.2 [Notas de diseño](#22-notas-de-diseño)

---

## 1. Expresiones Regulares

### 1.1 Validación numérica

```
^-?[0-9]+(\.[0-9]+)?$
```

Usada en `json_num()` antes de insertar cualquier valor en el JSON:

```bash
if [[ "$v" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    printf '%s' "$v"
else
    printf 'null'     # evita romper el JSON con texto basura
fi
```

| Parte | Significado |
|---|---|
| `^` | inicio del string |
| `-?` | guión opcional (admite negativos) |
| `[0-9]+` | uno o más dígitos |
| `(\.[0-9]+)?` | grupo opcional: punto seguido de dígitos (parte decimal) |
| `$` | fin del string |

**Por qué existe:** comandos como `grep -c` pueden devolver `"0\n0"` (dos líneas) cuando se usan con `pipefail`. Si ese valor se interpolara directamente en el JSON, generaría JSON inválido. `json_num` lo detecta y emite `null`.

---

### 1.2 Integer limpio

```
^[0-9]+$
```

Versión sin negativo ni decimal. Usada en ~15 puntos del script para validar capturas antes de operar con ellas:

```bash
[[ "$d_size"          =~ ^[0-9]+$ ]]   # tamaño disco en bytes (lsblk -b)
[[ "$_rlc"            =~ ^[0-9]+$ ]]   # sectores reubicados SMART
[[ "$_t"              =~ ^[0-9]+$ ]]   # temperatura raw en milligrados
[[ "$pending_updates" =~ ^[0-9]+$ ]]   # actualizaciones pendientes
[[ "$_uid"            =~ ^[0-9]+$ ]]   # UID de usuario (/etc/passwd)
[[ "$bat_full"        =~ ^[0-9]+$ ]]   # capacidad batería actual
[[ "$_cc"             =~ ^[0-9]+$ ]]   # ciclos de carga batería
```

Patrón de uso: si la comprobación falla, el valor se sustituye por `"null"` o se salta el bloque entero.

---

### 1.3 Confirmación de usuario

```
^[YySs]$
```

```bash
[[ "$_ans" =~ ^[YySs]$ ]] || { warn "Instalación cancelada"; return 1; }
```

| Parte | Significado |
|---|---|
| `^` y `$` | el string debe ser exactamente un carácter |
| `[YySs]` | clase de caracteres: acepta `Y`, `y`, `S` o `s` |

Rechaza `"Yes"`, `"sí"`, `" y"` (con espacio), etc.

---

### 1.4 Extracción de temperatura con `\K`

```
\+\K[0-9]+\.[0-9]+
```

```bash
sensors | grep -oP '\+\K[0-9]+\.[0-9]+'
# Input:  "Package id 0:  +52.0°C  (high = +100.0°C)"
# Output: "52.0"
```

| Parte | Significado |
|---|---|
| `\+` | literal `+` (el `\` escapa porque `+` cuantifica en regex) |
| `\K` | **keep** — descarta todo lo anterior del match (lookbehind sin grupo) |
| `[0-9]+\.[0-9]+` | número decimal obligatorio |

Sin `\K` el resultado sería `"+52.0"`. Con él, solo `"52.0"`, listo para JSON.

---

### 1.5 Horas SMART con comas

```
[0-9,]+
```

```bash
grep -oP '[0-9,]+'
# "Power On Hours:  1,234" → "1,234"
# luego: tr -d ','          → "1234"
```

Algunos firmwares formatean los separadores de miles en los atributos SMART (`1,234` en vez de `1234`). La regex captura dígitos Y comas; `tr -d ','` limpia el resultado después.

---

### 1.6 Número con word boundary

```
\b[0-9]+\b
```

```bash
grep -oP '\b[0-9]+\b'
# "Temperature: 45 Celsius (max 100)"
# Output: "45"   luego "100"  — no captura "45" de "450rpm"
```

`\b` marca la frontera entre carácter alfanumérico y no-alfanumérico. Evita extraer fragmentos de números más largos (p.ej. evitaría `45` dentro de `45000`).

---

### 1.7 Ancla de inicio de línea (`^`)

Usada con `grep` para filtrar líneas de salida de herramientas del sistema:

| Regex | Comando | Propósito |
|---|---|---|
| `^Inst` | `apt-get -s upgrade \| grep -c '^Inst'` | Cuenta paquetes a actualizar (cada uno empieza por "Inst") |
| `^[A-Za-z]` | `dnf check-update \| grep -c "^[A-Za-z]"` | Filtra cabeceras/líneas vacías del output de dnf |
| `^PRETTY_NAME=` | `grep "^PRETTY_NAME=" /etc/os-release` | Extrae línea exacta del archivo de configuración |
| `^VERSION_ID=` | `grep "^VERSION_ID=" /etc/os-release` | Idem para versión numérica |
| `^processor` | `grep -c ^processor /proc/cpuinfo` | Cuenta entradas de CPU (fallback sin `nproc`) |

Sin `^`, `grep 'Inst'` también matchearía `"reinstall"` o `"uninstall"`.

---

### 1.8 Alternaciones con `|`

#### Con `-E` (Extended RE) — `|` literal

```bash
grep -E 'Package id 0:|Core 0:|Tdie:|CPU Temp'
# Matchea cualquiera de las 4 etiquetas de lm-sensors

grep -iE 'VGA compatible|3D controller|Display controller'
# Detecta líneas de GPU en lspci (case-insensitive)

grep -E "disk|nvme"
# Filtra solo discos físicos del output de lsblk

grep -qE "nologin|false"
# Detecta shells deshabilitados en /etc/passwd
```

#### Con grep BRE (sin `-E`) — `\|` para alternar (extensión GNU)

```bash
grep -qi 'amd\|radeon'
# Detecta GPU AMD o Radeon (case-insensitive)

grep -ic "module.*error\|firmware.*failed"
# module.*error  → "module" + cualquier cosa + "error"
# firmware.*failed → "firmware" + cualquier cosa + "failed"
# El .* actúa como comodín entre palabras
```

> **Nota:** `\|` es una extensión de GNU grep, no POSIX BRE estándar. Funciona en todas las distribuciones Linux con glibc, pero fallaría en BSD/macOS sin `-E`.

---

### 1.9 Patrón AWK dpkg

```
/^[a-zA-Z]{2,3}[[:space:]]/ && $1 != "ii"
```

```bash
dpkg -l | awk '/^[a-zA-Z]{2,3}[[:space:]]/ && $1 != "ii" {c++} END{print c+0}'
```

`dpkg -l` produce líneas con un código de estado de 2-3 letras al inicio:

```
Desired=Unknown/Install/Remove/Purge/Hold
| Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
|/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
||/ Name              Version        Architecture  Description
+++-=================-==============-=============-======================
ii  bash              5.2.21-2ubuntu  amd64         GNU Bourne Again SHell
rc  vim-common        2:9.0.1672-1    all           Vi IMproved - Common files
```

| Parte AWK | Significado |
|---|---|
| `^[a-zA-Z]{2,3}` | 2 o 3 letras al inicio — el código de estado (`ii`, `rc`, `iU`...) |
| `[[:space:]]` | espacio tras el código — distingue filas de datos de cabeceras |
| `$1 != "ii"` | excluye paquetes correctamente instalados |
| `{c++}` | incrementa contador |
| `END{print c+0}` | imprime 0 si no hubo matches (el `+0` fuerza tipo numérico) |

`{2,3}` es un **cuantificador de repetición**: exactamente 2 o 3 ocurrencias del patrón anterior.

---

## 2. Estructura JSON de Salida

### 2.1 Esquema completo

Archivo generado en: `scripts/diagnosticos/diagnostico_<hostname>_<YYYYMMDD_HHMMSS>.json`

```json
{
  "hardware": {
    "cpu_nombre":    "Intel Core i7-12700H",
    "cpu_cores":     14,
    "cpu_hilos":     14,
    "cpu_mhz":       2300,
    "cpu_temp_c":    52.0,
    "ram_gb":        32,
    "disk_type":     "NVMe",
    "disk_gb":       1000,
    "disk_free_gb":  650,
    "disk_uso_pct":  35,
    "smart_status":  "OK",
    "discos": [
      {
        "modelo":       "Samsung MZVL21T0HCLR",
        "tipo":         "NVMe",
        "capacidad_gb": 1000,
        "smart":        "OK",
        "bus":          "nvme",
        "smart_atributos": {
          "reallocated_sectors":  0,
          "pending_sectors":      0,
          "uncorrectable_errors": 0,
          "temperatura_c":        38,
          "horas_encendido":      2150
        }
      }
    ],
    "bateria": {
      "presente":     true,
      "carga_pct":    78,
      "estado":       "Discharging",
      "desgaste_pct": 8.3,
      "ciclos":       124
    },
    "gpu": {
      "nombre":       "NVIDIA GeForce RTX 3070",
      "tipo":         "NVIDIA",
      "vram_mb":      8192,
      "temperatura_c": 61
    }
  },

  "sistema_operativo": {
    "nombre":                  "Ubuntu 24.04.1 LTS",
    "build":                   "6.8.0-51-generic",
    "arquitectura":            "x86_64",
    "uptime_horas":            18.4,
    "actualizaciones_pendientes": 5,
    "sfc_archivos_danados":    0,
    "plan_energia":            "equilibrado"
  },

  "drivers": {
    "detenidos":       0,
    "sin_firma":       3,
    "detenidos_lista": [],
    "sin_firma_lista": []
  },

  "red": {
    "latencia_ms":         14,
    "perdida_paquetes_pct": 0,
    "dns":                 ["192.168.1.1", "8.8.8.8"],
    "interfaz":            "enp3s0"
  },

  "seguridad": {
    "antivirus":         "ClamAV",
    "firewall":          true,
    "uac_habilitado":    null,
    "defender_activo":   true,
    "defender_firma_dias": null,
    "selinux":           "Disabled"
  },

  "servicios": {
    "total":                   52,
    "activos":                 44,
    "detenidos":               8,
    "automaticos_detenidos":   2,
    "criticos": [
      { "nombre": "sshd",          "estado": "active"   },
      { "nombre": "NetworkManager","estado": "active"   },
      { "nombre": "nginx",         "estado": "active"   },
      { "nombre": "mariadb",       "estado": "inactive" }
    ]
  },

  "software": [
    { "nombre": "bash",   "version": "5.2.21-2ubuntu4"  },
    { "nombre": "curl",   "version": "8.5.0-2ubuntu10.4" },
    { "nombre": "nginx",  "version": "1.24.0-2ubuntu7"  }
  ],

  "rendimiento": {
    "cpu_uso_pct":      12.3,
    "memoria_uso_pct":  61.7,
    "top_procesos": [
      { "pid": 1842, "memoria_pct": 5.2, "nombre": "/usr/bin/python3" },
      { "pid": 932,  "memoria_pct": 3.8, "nombre": "postgres"         },
      { "pid": 2201, "memoria_pct": 2.1, "nombre": "firefox"          }
    ]
  },

  "usuarios": [
    { "nombre": "francisco", "uid": 1000, "activo": true,  "home": "/home/francisco" },
    { "nombre": "deploy",    "uid": 1001, "activo": false, "home": "/home/deploy"    }
  ],

  "placa_base": {
    "fabricante":    "ASUSTeK COMPUTER INC.",
    "producto":      "ROG STRIX B550-F GAMING",
    "version_bios":  "F15",
    "fecha_bios":    "02/14/2023",
    "uuid":          "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
  },

  "_meta": {
    "version":      "3.1.0",
    "plataforma":   "linux",
    "hostname":     "resolvecore-pc",
    "generado_en":  "2026-05-12T14:30:00+02:00",
    "admin":        true
  }
}
```

---

### 2.2 Notas de diseño

| Decisión | Razón |
|---|---|
| `null` en vez de `""` para datos no disponibles | JSON válido; el importador puede distinguir "no medido" de "valor vacío" |
| `discos[]` es array | soporta multi-disco sin cambiar el esquema |
| `smart_atributos` anidado dentro de cada disco | es propiedad del disco concreto, no del sistema |
| `bateria: null` en sobremesa | no hay path `/sys/class/power_supply/BAT*` → la variable queda `null` |
| `uac_habilitado: null` en Linux | campo reservado para compatibilidad con esquema Windows |
| `_meta` con prefijo `_` | convención: metadato del archivo, no del sistema diagnosticado |
| Ensamblaje vía `jq -n --argjson` | cada sección se valida como JSON antes de incluirse; si una sección está corrupta, `jq` falla con mensaje preciso en vez de generar silenciosamente un archivo inválido |
| `software[]` limitado a 50 paquetes | equilibrio entre utilidad y tamaño del archivo; en sistemas con 2000+ paquetes el JSON sería inmanejable |
| `top_procesos` solo 5 entradas | suficiente para detectar procesos con fuga de memoria |

---

*Referencia: `scripts/linux/diagnostico.sh` v3.1.0 — ResolveCore TFG ASIR 2024/25*
