# Esquema JSON de diagnóstico — ResolveCore

> Estructura común que producen los scripts de `scripts/{windows,linux,android,macos}/diagnostico.*`.
> El generador de informes PDF consume este JSON. Mantener compatibilidad.

---

## Versionado

`_meta.version` sigue **SemVer**. Cambios en campos:

- **major** — campo eliminado o renombrado.
- **minor** — campo nuevo añadido.
- **patch** — semántica idéntica, fix interno.

| Plataforma | Script              | Versión actual |
|------------|---------------------|----------------|
| Windows    | `windows/diagnostico.ps1` | 3.2.0    |
| Linux      | `linux/diagnostico.sh`    | 3.0.0    |
| Android    | `android/diagnostico.sh`  | 2.0.0    |
| macOS      | `macos/diagnostico.sh`    | 0.1.0-demo (stub) |

---

## Estructura común (top-level)

| Campo                | Win | Linux | Android | macOS-demo | Tipo     | Notas |
|----------------------|:---:|:-----:|:-------:|:----------:|----------|-------|
| `_meta`              | ✓   | ✓     | ✓       | ✓          | object   | Metadata del scan. |
| `hardware` *         | —   | ✓     | ✓       | ✓ (stub)   | object   | Linux/Android usan `hardware`. Windows lo expande en `cpu`, `memoria`, `discos`, `gpu`, `placa_base`. |
| `sistema` / `sistema_operativo` | ✓ (`sistema`) | ✓ | ✓ | ✓ | object | Nombre, build, uptime. |
| `red`                | ✓   | ✓     | ✓       | ✓ (stub)   | object   | Adaptadores, IP, latencia. |
| `seguridad`          | ✓   | ✓     | ✓       | ✓ (stub)   | object   | Firewall, antivirus, cifrado. |
| `cpu`                | ✓   | —     | —       | —          | object   | Windows: detalle CPU. |
| `memoria`            | ✓   | —     | —       | —          | object   | Windows: total/módulos. |
| `discos`             | ✓   | —     | —       | —          | object   | Windows: físicos + lógicos. |
| `gpu`                | ✓   | —     | —       | —          | array    | Windows. Linux la incluye dentro de `hardware.gpu`. |
| `placa_base`         | ✓   | —     | —       | —          | object   | Windows: BIOS/UEFI. |
| `bateria`            | ✓   | —     | —       | —          | object\|null | Windows top-level. Linux/Android dentro de `hardware`. |
| `servicios`          | ✓   | —     | —       | —          | object   | Windows. |
| `software`           | ✓   | —     | —       | —          | object   | Windows. |
| `rendimiento`        | ✓   | —     | —       | —          | object   | Windows: snapshot CPU/RAM. |
| `usuarios`           | ✓   | —     | —       | —          | array    | Windows. |
| `drivers`            | —   | ✓     | —       | —          | object   | Linux: módulos kernel. |
| `aplicaciones`       | —   | —     | ✓       | —          | object   | Android: pm list packages. |
| `dispositivo`        | —   | —     | ✓       | —          | object   | Android: marca/modelo/serial. |
| `smart`              | ✓   | —     | —       | —          | array    | Windows: SMART por disco. Linux mete SMART dentro de `hardware.discos[].smart_atributos`. |

\* En Linux/Android `hardware` es un sub-objeto. En Windows está descompuesto en raíz.

---

## `_meta` — campos comunes

```json
{
  "_meta": {
    "version":     "3.x.y",
    "plataforma":  "windows | linux | android | macos",
    "hostname":    "string",
    "generado_en": "ISO-8601",
    "admin":       true,        // Win/Linux: privilegios elevados
    "stub":        false        // sólo macOS-demo
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

## Ejemplo mínimo (Linux)

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
  "_meta":      { "version": "3.0.0", "plataforma": "linux", "admin": true, "generado_en": "2026-05-07T18:00:00+02:00" }
}
```

---

## Roadmap unificación

- [ ] Reorganizar Windows para mover `cpu`/`memoria`/`discos`/`gpu` bajo `hardware` (alineación con Linux/Android). Requiere migración del template HTML del informe.
- [ ] Mover `bateria` Windows a `hardware.bateria`.
- [ ] Implementar diagnóstico macOS real (sustituir stub).
- [ ] Definir esquema JSON Schema (`/docs/schema-diagnostico.schema.json`) y validar en CI.

---

*Última actualización: 2026-05-07*
