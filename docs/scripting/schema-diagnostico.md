# Esquema JSON de diagnóstico — ResolveCore

> Estructura que producen los scripts `scripts/{windows,linux,android}/diagnostico.*`.
> El generador de plantillas (`scripts/common/generar_informe.py --json`) consume este
> JSON para pre-rellenar la cabecera y las secciones del informe. El endpoint
> `/wp-json/rc/v1/fleet` lo recibe envuelto en `{client_email, diagnostico}`.
>
> **Modelo PLANO por diseño.** Las claves de hardware/sistema/red/seguridad cuelgan
> directamente de la raíz (`cpu`, `ram`, `discos`, `red`, …), no de un sub-objeto
> `hardware{}`. Cualquier consumidor debe leer de la raíz.
>
> (macOS está en ROADMAP: su script se borró en `12890ac` y no está en el repo.)

---

## Versionado

`_meta.version` sigue **SemVer**. Cambios en campos:

- **major** — campo eliminado o renombrado (breaking).
- **minor** — campo nuevo añadido (no rompe consumidores existentes).
- **patch** — semántica idéntica, fix interno.

| Plataforma | Script                    | Versión actual | Notas |
|------------|---------------------------|----------------|-------|
| Windows    | `windows/diagnostico.ps1` | **2.1.0**      | +sistema, disco_smart, seguridad, servicios_criticos, actualizaciones, procesos_top, red (2026-06-02) |
| Linux      | `linux/diagnostico.sh`    | **3.1.0**      | +sistema, disco_smart, servicios_criticos, procesos_top, red, seguridad (2026-06-02) |
| Android    | `android/diagnostico.sh`  | **2.2.0**      | +fabricante, marca, parche_seguridad, red, procesos_top (2026-06-02) |
| macOS      | `macos/diagnostico.sh`    | — (ROADMAP)    | Borrado en `12890ac`, recuperable de histórico. |

---

## `_meta` — común a todas las plataformas

```json
{
  "_meta": {
    "plataforma": "windows | linux | android",
    "hostname":   "string",
    "version":    "x.y.z"
  }
}
```

Tras `_meta`, todas llevan `timestamp` (ISO-8601) y `hostname`/`dispositivo`.

---

## Windows — `diagnostico.ps1` (v2.1)

| Campo | Tipo | Origen | Notas |
|-------|------|--------|-------|
| `os` | string | `Win32_OperatingSystem` | Caption + Version. |
| `sistema` | object | `Win32_OperatingSystem` | `{nombre, version, build, uptime_horas, ultimo_arranque}`. |
| `cpu` | object | `Win32_Processor` | `{name, cores, load}`. |
| `ram` | object | CIM | `{total_gb, free_gb}`. |
| `discos[]` | array | `Get-PSDrive` | `{drive, used_gb, free_gb, total_gb}`. |
| `disco_smart` | array \| null | `MSStorageDriver_FailurePredictStatus` | `{instancia, fallo_predicho}`. `null` si el driver no lo expone. |
| `antivirus[]` | array | `root/SecurityCenter2` | nombres de producto. |
| `seguridad` | object | Defender/Firewall/UAC | `{defender_activo, firewall, uac}` (bool \| null). |
| `servicios_criticos[]` | array | `Get-Service` | Spooler, wuauserv, WinDefend, WSearch, BITS → `{nombre, display, estado}`. **Spooler solo se reporta.** |
| `actualizaciones` | object | Windows Update Agent | `{pendientes}` (int \| null). |
| `procesos_top[]` | array | `Get-Process` | top 10 por CPU → `{nombre, cpu_s, ram_mb}`. |
| `red` | object | `Get-NetIPConfiguration`, `Get-NetTCPConnection` | `{ip, gateway, dns[], puertos_escucha[]}`. |

### Ejemplo mínimo — Windows 2.1
```json
{
  "_meta": { "plataforma": "windows", "hostname": "PC-01", "version": "2.1" },
  "timestamp": "2026-06-02T16:00:00+02:00",
  "hostname": "PC-01",
  "os": "Microsoft Windows 11 Pro 10.0.26100",
  "sistema": { "nombre": "Microsoft Windows 11 Pro", "version": "10.0.26100", "build": "26100", "uptime_horas": 72.3, "ultimo_arranque": "2026-05-30T08:00:00+02:00" },
  "cpu": { "name": "AMD Ryzen 5", "cores": 6, "load": 12 },
  "ram": { "total_gb": 32.0, "free_gb": 18.5 },
  "discos": [ { "drive": "C", "used_gb": 200.1, "free_gb": 256.4, "total_gb": 456.5 } ],
  "disco_smart": [ { "instancia": "...", "fallo_predicho": false } ],
  "antivirus": [ "Windows Defender" ],
  "seguridad": { "defender_activo": true, "firewall": true, "uac": true },
  "servicios_criticos": [ { "nombre": "Spooler", "display": "Print Spooler", "estado": "Running" } ],
  "actualizaciones": { "pendientes": 3 },
  "procesos_top": [ { "nombre": "chrome", "cpu_s": 124.5, "ram_mb": 850.2 } ],
  "red": { "ip": "192.168.1.20", "gateway": "192.168.1.1", "dns": ["1.1.1.1"], "puertos_escucha": [135, 445, 3389] }
}
```

---

## Linux — `diagnostico.sh` (v3.1)

| Campo | Tipo | Origen | Notas |
|-------|------|--------|-------|
| `os` | string | `/etc/os-release` (PRETTY_NAME) | |
| `kernel` | string | `uname -r` | |
| `uptime_horas` | number | `/proc/uptime` | |
| `sistema` | object | — | `{nombre, kernel, uptime_horas, ultimo_arranque}` (`uptime -s`). |
| `cpu` | object | `/proc/cpuinfo`, `/proc/loadavg` | `{modelo, cores, carga_1min}`. |
| `ram` | object | `/proc/meminfo` | `{total_gb, libre_gb}`. |
| `disco` | object | `df` | `{usado, libre, porcentaje_uso}` (root). |
| `disco_smart` | string \| null | `smartctl -H` | overall-health del primer disco; `null` sin smartctl/permiso. |
| `actualizaciones` | object | `apt-get -s upgrade` / `dnf check-update` | `{pendientes}`. |
| `servicios_criticos[]` | array | `systemctl is-active` | ssh, cron, **cups** (impresión, solo reporte), systemd-journald, NetworkManager → `{nombre, estado}`. |
| `procesos_top[]` | array | `ps -eo %cpu,%mem,comm` | top 10 → `{nombre, cpu, mem}`. |
| `red` | object | `ip`, `ss`, `/etc/resolv.conf` | `{ip, gateway, dns[], puertos_escucha[]}`. |
| `seguridad` | object | `ufw` / `iptables` | `{firewall}` (bool). |

> Nota: `export LC_ALL=C` fuerza punto decimal — sin él, en locales es_ES el `awk`
> emite coma y rompe el JSON.

---

## Android — `diagnostico.sh` (v2.2, vía ADB)

| Campo | Tipo | Origen |
|-------|------|--------|
| `dispositivo` | string | `getprop ro.product.model` |
| `fabricante` | string | `getprop ro.product.manufacturer` |
| `marca` | string | `getprop ro.product.brand` |
| `android` | string | `getprop ro.build.version.release` |
| `sdk` | int | `getprop ro.build.version.sdk` |
| `parche_seguridad` | string | `getprop ro.build.version.security_patch` |
| `bateria` | object | `dumpsys battery` → `{nivel, temp_decimas_grado}` |
| `almacenamiento_data` | string | `df /data` → `"TOTAL LIBRE"` (bloques 1K) |
| `red` | object | `ip -o -4 addr show wlan0` → `{ip}` |
| `procesos_top[]` | array(string) | `top -b -n 1` (nombre + cpu, best-effort) |

---

## Convenciones

- **Unidades:** GB para discos/RAM, MB para RAM de procesos, horas para uptime, décimas de grado para batería Android.
- **Booleanos:** `true`/`false` literales.
- **Nulos:** campo no disponible → `null` (Windows) o cadena vacía `""` / `0` con blindaje (Bash, para no romper el JSON manual).
- **Fechas:** ISO-8601.
- Cada bloque de recogida está aislado (`try/catch` en PS, `|| default` en Bash): si una métrica falla, el resto del diagnóstico se completa igual.

---

*Última actualización: 2026-06-02*
