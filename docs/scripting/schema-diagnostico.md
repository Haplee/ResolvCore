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
| Linux      | `linux/diagnostico.sh`    | **4.0.0**      | Diagnóstico completo: +cpu(carga_5/15min, uso_pct, temperatura_c), ram(usado/swap), discos[], inodos, paquetes, servicios_fallidos, procesos_top_mem, bateria, gpu, usuarios_conectados, red(interfaces[], conexiones_estab), seguridad(ssh_root_login, mac_lsm, fail2ban, reinicio_requerido). **major**: `disco_smart` pasa de `string\|null` a **array** (2026-06-04). **Fix**: `servicios_criticos` ya no rompe el JSON cuando un servicio está inactivo. |
| Android    | `android/diagnostico.sh`  | **3.0.0**      | Diagnóstico completo: +modelo_interno, hardware, build, fingerprint, kernel, uptime_horas, batería ampliada (estado/salud/voltaje/tecnología/fuente/ciclos), cpu, ram, almacenamiento{}, pantalla, red ampliada (ip_movil/mac/wifi/operador), seguridad{}, apps{}, termico{} (2026-06-04). **major**: `bateria` añade claves; `red` pasa de `{ip}` a objeto ampliado. |
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

## Linux — `diagnostico.sh` (v4.0)

| Campo | Tipo | Origen | Notas |
|-------|------|--------|-------|
| `os` | string | `/etc/os-release` (PRETTY_NAME) | |
| `kernel` | string | `uname -r` | |
| `uptime_horas` | number | `/proc/uptime` | |
| `sistema` | object | — | `{nombre, kernel, uptime_horas, ultimo_arranque, reinicio_requerido}`. |
| `cpu` | object | `/proc/cpuinfo`, `/proc/loadavg`, `top`, `sensors`/thermal | `{modelo, cores, carga_1min, carga_5min, carga_15min, uso_pct, temperatura_c}`. `uso_pct`/`temperatura_c` `null` si no se obtienen. |
| `ram` | object | `/proc/meminfo` | `{total_gb, libre_gb, usado_gb, swap_total_gb, swap_libre_gb}`. |
| `disco` | object | `df` | `{usado, libre, porcentaje_uso}` (root). **Se conserva** por compatibilidad. |
| `discos[]` | array | `df -hPx tmpfs -x devtmpfs` | todos los FS reales → `{dispositivo, punto, usado, libre, porcentaje_uso}`. |
| `inodos` | object | `df -i /` | `{porcentaje_uso}` (root). |
| `disco_smart[]` | array | `smartctl -H` por disco de `lsblk` | `{dispositivo, salud}`. `[]` sin smartctl/permiso. **(major: antes era `string\|null`)**. |
| `actualizaciones` | object | `apt-get -s upgrade` / `dnf check-update` | `{pendientes, seguridad}`. |
| `paquetes` | object | `dpkg-query` / `rpm -qa` | `{instalados}` (recuento). |
| `servicios_criticos[]` | array | `systemctl is-active` | ssh, cron, **cups** (impresión, solo reporte), systemd-journald, NetworkManager → `{nombre, estado}`. |
| `servicios_fallidos[]` | array(string) | `systemctl --failed` | unidades en estado failed. |
| `procesos_top[]` | array | `ps --sort=-%cpu` | top 10 por CPU → `{nombre, cpu, mem}`. |
| `procesos_top_mem[]` | array | `ps --sort=-%mem` | top 10 por memoria → `{nombre, mem, cpu}`. |
| `bateria` | object \| null | `/sys/class/power_supply/BAT*` | `{nivel, estado}`. `null` en equipos sin batería. |
| `gpu` | string | `lspci` | modelo de la GPU. |
| `usuarios_conectados[]` | array(string) | `who` | sesiones activas (usuarios únicos). |
| `red` | object | `ip`, `ss`, `/etc/resolv.conf`, `/sys/class/net` | `{ip, gateway, dns[], interfaces[]{nombre,mac,ip}, puertos_escucha[], conexiones_estab}`. |
| `seguridad` | object | `ufw`/`iptables`, `sshd_config`, `aa-status`/`getenforce`, `fail2ban`, `/var/run/reboot-required` | `{firewall, ssh_root_login, mac_lsm, fail2ban_activo, reinicio_requerido}`. `ssh_root_login` ∈ `true\|false\|null`; `mac_lsm` = `apparmor`/`selinux:<modo>`/`""`. |

> **Fix v4.0:** `servicios_criticos` capturaba `systemctl is-active` con `|| echo
> desconocido`. Como `is-active` sale con código ≠0 para servicios inactivos, el valor
> quedaba `"inactive\ndesconocido"` (salto de línea **dentro** del string) e invalidaba el
> JSON. Ahora se captura la salida tal cual y solo se cae a `desconocido` si viene vacía.
>
> Nota: `export LC_ALL=C` fuerza punto decimal — sin él, en locales es_ES el `awk`
> emite coma y rompe el JSON.

---

## Android — `diagnostico.sh` (v3.0, vía ADB)

> Modelo PLANO igual que Windows/Linux. Cada bloque es best-effort: si una
> métrica falla, el campo cae a `""` (string), `0`/`null` (numérico blindado) y
> el resto del diagnóstico se completa. `export LC_ALL=C` fuerza punto decimal.

| Campo | Tipo | Origen | Notas |
|-------|------|--------|-------|
| `dispositivo` | string | `getprop ro.product.model` | |
| `fabricante` | string | `getprop ro.product.manufacturer` | |
| `marca` | string | `getprop ro.product.brand` | |
| `modelo_interno` | string | `getprop ro.product.device` | nombre en clave (ej. `tegu`). |
| `hardware` | string | `getprop ro.hardware` | |
| `android` | string | `getprop ro.build.version.release` | |
| `sdk` | int | `getprop ro.build.version.sdk` | |
| `build` | string | `getprop ro.build.display.id` | número de compilación. |
| `fingerprint` | string | `getprop ro.build.fingerprint` | |
| `parche_seguridad` | string | `getprop ro.build.version.security_patch` | |
| `kernel` | string | `uname -r` | |
| `uptime_horas` | number | `/proc/uptime` | |
| `bateria` | object | `dumpsys battery` | `{nivel, temp_decimas_grado, temp_c, estado, salud, voltaje_mv, tecnologia, fuente, ciclos}`. `estado`/`salud` mapean los códigos numéricos a texto; `fuente` ∈ `ac\|usb\|wireless\|bateria`; `ciclos` `null` si no se expone (suele requerir root). |
| `cpu` | object | `/proc/cpuinfo`, `/proc/loadavg`, `dumpsys cpuinfo` | `{modelo, cores, carga_1min, uso_pct}`. `modelo` de `ro.soc.model`→`ro.board.platform`; `uso_pct` `null` si no se parsea. |
| `ram` | object | `/proc/meminfo` | `{total_gb, libre_gb}` (de `MemTotal`/`MemAvailable`). |
| `almacenamiento` | object | `df /data` | `{data_total_gb, data_libre_gb, data_porcentaje_uso}`. |
| `almacenamiento_data` | string | `df /data` | **legacy** `"TOTAL LIBRE"` (bloques 1K). Conservado para `generar_informe.py`. |
| `pantalla` | object | `wm size`, `wm density` | `{resolucion, densidad_dpi}`. |
| `red` | object | `ip`, `dumpsys wifi`, `getprop gsm.*` | `{ip, ip_movil, mac_wifi, wifi_ssid, wifi_rssi_dbm, wifi_velocidad_mbps, operador, tipo_red}`. `wifi_rssi_dbm`/`wifi_velocidad_mbps` `null` sin asociación. |
| `seguridad` | object | `getprop`, `getenforce` | `{cifrado, selinux, verified_boot, bootloader_bloqueado, root_detectado, adb_wifi}`. `root_detectado` = existe binario `su`; `bootloader_bloqueado` de `ro.boot.flash.locked` (`null` si no expone). |
| `apps` | object | `pm list packages` | `{total, terceros, deshabilitadas}` (`-3` / `-d`). |
| `termico` | object | `/sys/class/thermal/thermal_zone*/temp` | `{temp_max_c}`. Normaliza mili-grados→°C; `null` sin acceso (puede requerir root). |
| `procesos_top[]` | array(string) | `top -b -n 1` | top 8 (nombre + cpu, best-effort). |

### Ejemplo mínimo — Android 3.0
```json
{
  "_meta": { "plataforma": "android", "hostname": "Pixel 9a", "version": "3.0" },
  "timestamp": "2026-06-04T17:39:24+02:00",
  "dispositivo": "Pixel 9a", "fabricante": "Google", "marca": "google",
  "modelo_interno": "tegu", "hardware": "tegu",
  "android": "16", "sdk": 36, "build": "BP1A.250505.005",
  "fingerprint": "google/tegu/tegu:16/BP1A.250505.005/1234:user/release-keys",
  "parche_seguridad": "2026-05-05", "kernel": "6.6.30-android15", "uptime_horas": 12.4,
  "bateria": { "nivel": 50, "temp_decimas_grado": 340, "temp_c": 34.0, "estado": "Cargando", "salud": "Buena", "voltaje_mv": 4201, "tecnologia": "Li-ion", "fuente": "usb", "ciclos": 120 },
  "cpu": { "modelo": "Tensor G4", "cores": 8, "carga_1min": 1.25, "uso_pct": 15 },
  "ram": { "total_gb": 7.7, "libre_gb": 3.3 },
  "almacenamiento": { "data_total_gb": 228.6, "data_libre_gb": 165.5, "data_porcentaje_uso": 28 },
  "almacenamiento_data": "239747156 173562208",
  "pantalla": { "resolucion": "1080x2424", "densidad_dpi": 420 },
  "red": { "ip": "192.168.1.45/24", "ip_movil": "10.20.30.40/30", "mac_wifi": "aa:bb:cc:dd:ee:ff", "wifi_ssid": "MiRed", "wifi_rssi_dbm": -45, "wifi_velocidad_mbps": 433, "operador": "Movistar", "tipo_red": "LTE" },
  "seguridad": { "cifrado": "encrypted", "selinux": "Enforcing", "verified_boot": "green", "bootloader_bloqueado": true, "root_detectado": false, "adb_wifi": false },
  "apps": { "total": 280, "terceros": 95, "deshabilitadas": 12 },
  "termico": { "temp_max_c": 41.2 },
  "procesos_top": ["surfaceflinger 5", "systemui 3"]
}
```

---

## Convenciones

- **Unidades:** GB para discos/RAM, MB para RAM de procesos, horas para uptime, décimas de grado para batería Android.
- **Booleanos:** `true`/`false` literales.
- **Nulos:** campo no disponible → `null` (Windows) o cadena vacía `""` / `0` con blindaje (Bash, para no romper el JSON manual).
- **Fechas:** ISO-8601.
- Cada bloque de recogida está aislado (`try/catch` en PS, `|| default` en Bash): si una métrica falla, el resto del diagnóstico se completa igual.

---

*Última actualización: 2026-06-04*
