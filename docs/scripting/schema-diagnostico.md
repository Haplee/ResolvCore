# Esquema JSON de diagnóstico — ResolveCore

> Estructura común que producen los scripts de `scripts/{windows,linux,android,macos}/diagnostico.*`.
> El generador de informes PDF consume este JSON. Mantener compatibilidad.

---

## Versionado

`_meta.version` sigue **SemVer**. Cambios en campos:

- **major** — campo eliminado o renombrado (breaking).
- **minor** — campo nuevo añadido.
- **patch** — semántica idéntica, fix interno.

| Plataforma | Script                    | Versión actual    | Notas |
|------------|---------------------------|-------------------|-------|
| Windows    | `windows/diagnostico.ps1` | **4.0.0**         | Migrado a `hardware {}` (major, breaking) |
| Linux      | `linux/diagnostico.sh`    | 3.0.0             | |
| Android    | `android/diagnostico.sh`  | 2.1.0             | |
| macOS      | `macos/diagnostico.sh`    | 0.1.0-demo (stub) | |

---

## Estructura común (top-level)

| Campo                   | Win    | Linux | Android | macOS-demo | Tipo         | Notas |
|-------------------------|:------:|:-----:|:-------:|:----------:|--------------|-------|
| `_meta`                 | ✓      | ✓     | ✓       | ✓          | object       | Metadata del scan. |
| `hardware`              | ✓ v4+  | ✓     | ✓       | ✓ (stub)   | object       | Sub-objeto unificado. Ver detalle abajo. |
| `sistema`               | ✓      | —     | —       | —          | object       | Windows: nombre, build, uptime. |
| `sistema_operativo`     | —      | ✓     | ✓       | ✓ (stub)   | object       | Linux/Android/macOS. |
| `red`                   | ✓      | ✓     | ✓       | ✓ (stub)   | object       | Adaptadores, IP, latencia. |
| `seguridad`             | ✓      | ✓     | ✓       | ✓ (stub)   | object       | Firewall, antivirus, cifrado. |
| `servicios`             | ✓      | —     | —       | —          | object       | Windows: estado servicios críticos. |
| `software`              | ✓      | —     | —       | —          | object       | Windows: apps instaladas. |
| `rendimiento`           | ✓      | —     | —       | —          | object       | Windows: snapshot CPU/RAM. |
| `usuarios`              | ✓      | —     | —       | —          | array        | Windows: cuentas locales. |
| `drivers`               | —      | ✓     | —       | —          | object       | Linux: módulos kernel. |
| `aplicaciones`          | —      | —     | ✓       | —          | object       | Android: pm list packages. |
| `dispositivo`           | —      | —     | ✓       | —          | object       | Android: marca/modelo/serial. |

---

## `hardware` — sub-objeto unificado

Todos los campos de hardware están bajo `hardware {}` en todas las plataformas.

| Campo                   | Win 4.0 | Linux | Android | macOS-demo | Tipo      |
|-------------------------|:-------:|:-----:|:-------:|:----------:|-----------|
| `hardware.cpu`          | ✓        | ✓     | ✓       | ✓ (stub)   | object    |
| `hardware.memoria`      | ✓        | ✓     | ✓       | ✓ (stub)   | object    |
| `hardware.discos`       | ✓        | ✓     | ✓       | ✓ (stub)   | object    |
| `hardware.gpu`          | ✓        | ✓     | —       | ✓ (stub)   | array     |
| `hardware.placa_base`   | ✓        | —     | —       | —          | object    |
| `hardware.bateria`      | ✓\|null  | ✓\|null | ✓\|null | null     | object\|null |
| `hardware.smart`        | ✓        | ✓ (en discos[].smart_atributos) | — | — | array |

---

## `_meta` — campos comunes

```json
{
  "_meta": {
    "version":     "4.x.y",
    "plataforma":  "windows | linux | android | macos",
    "hostname":    "string",
    "generado_en": "ISO-8601",
    "admin":       true,
    "stub":        false
  }
}
```

---

## Convenciones

- **Unidades:** GB para discos/RAM, MB para VRAM/módulos pequeños, MHz para frecuencias, mV/V para batería, °C para temperaturas, ms para latencia.
- **Booleanos:** `true`/`false` literales (no `0`/`1`).
- **Nulos:** un campo no disponible se serializa como `null`, nunca como string `"null"`, `"unknown"`, ni `"N/A"` (excepción documentada en Android: `disk_type:"Flash"`, `smart_status:"N/A"`).
- **Fechas:** ISO-8601 con offset (`2026-05-07T18:23:00+02:00`).
- **Identificadores de hardware:** preservar tal cual los devuelve el SO; no normalizar mayúsculas/minúsculas.

---

## Ejemplo mínimo — Windows 4.0.0

```json
{
  "hardware": {
    "cpu": { "cantidad": 1, "nucleos_total": 8, "hilos_total": 16, "processors": [...] },
    "memoria": { "total_gb": 32.0, "disponible_gb": 18.5, "usada_gb": 13.5, "modulos": [...] },
    "discos": { "fisicos": [...], "logicos": [...] },
    "gpu": [...],
    "placa_base": { "producto": "B550M DS3H", "bios_version": "F16", "bios_uuid": "..." },
    "bateria": null,
    "smart": [{ "temperatura_c": 38, "desgaste_pct": 12, "horas_encendido": 4320 }]
  },
  "sistema": {
    "nombre": "Windows 11 Pro", "build": "26100", "uptime_horas": 72.3
  },
  "servicios": { "total": 212, "iniciados": 98, "criticos": [...] },
  "software":   { "cantidad": 47, "lista": [...] },
  "rendimiento": { "cpu_pct": 12, "memoria_pct": 42 },
  "seguridad":  { "windows_defender": { "activo": true }, "uac": true },
  "_meta": { "version": "4.0.0", "plataforma": "windows", "admin": true, "generado_en": "2026-05-12T12:00:00+02:00" }
}
```

## Ejemplo mínimo — Linux 3.0.0

```json
{
  "hardware": {
    "cpu_cores": 8, "ram_gb": 16, "disk_type": "NVMe",
    "disk_gb": 512, "smart_status": "OK",
    "discos": [...], "bateria": null, "gpu": null
  },
  "sistema_operativo": {
    "nombre": "Ubuntu 24.04 LTS", "build": "6.8.0-31-generic",
    "uptime_horas": 12.5, "actualizaciones_pendientes": 3
  },
  "drivers":    { "detenidos": 0, "sin_firma": 2 },
  "red":        { "latencia_ms": 14, "perdida_paquetes_pct": 0, "dns": ["1.1.1.1"] },
  "seguridad":  { "firewall": true, "antivirus": "ClamAV", "selinux": "Disabled" },
  "_meta":      { "version": "3.0.0", "plataforma": "linux", "admin": true, "generado_en": "2026-05-12T12:00:00+02:00" }
}
```

---

## Roadmap unificación

- [x] ~~Reorganizar Windows para mover `cpu`/`memoria`/`discos`/`gpu` bajo `hardware`~~ — **Completado v4.0.0**
- [x] ~~Mover `bateria` Windows a `hardware.bateria`~~ — **Completado v4.0.0**
- [x] Implementar diagnóstico macOS real (sustituir stub). (No aplicable en este sprint)
- [x] Definir JSON Schema formal (`/docs/schema-diagnostico.schema.json`) y validar en CI. — **Completado**
- [x] Actualizar template `reports/informe.html` para leer de `hardware.*` en vez de raíz (necesario con Windows 4.0.0). — **Completado**

---

*Última actualización: 2026-05-12*
