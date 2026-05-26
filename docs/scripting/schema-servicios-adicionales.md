# Esquemas JSON — Servicios adicionales

> Esquemas propios de los scripts en `scripts/servicios/`.
> No forman parte del schema de diagnóstico (`schema-diagnostico.md`).

---

## 1. Clonación — manifiesto `imagenes-manifest.json`

Fichero generado/actualizado por `registrar-imagen.sh`. Una imagen por entrada.

```json
{
  "version": "1.0",
  "imagenes": [
    {
      "id":             "pc-cliente-01-20260525143000-1234",
      "equipo":         "pc-cliente-01",
      "so":             "windows",
      "estado":         "limpio",
      "ruta":           "/backups/imagenes/pc-cliente-01-20260525.img",
      "hash_sha256":    "a3f1c8...",
      "fecha_registro": "2026-05-25T14:30:00Z",
      "notas":          "Estado post-instalación de software base"
    }
  ]
}
```

### Campos

| Campo | Tipo | Valores | Descripción |
|-------|------|---------|-------------|
| `version` | string | `"1.0"` | Versión del schema del manifiesto |
| `imagenes` | array | — | Lista de entradas de imagen |
| `id` | string | `<equipo>-<YYYYMMDDHHmmSS>-<pid>` | Identificador único generado al registrar |
| `equipo` | string | libre | Nombre o ID del equipo de origen |
| `so` | string | `windows\|linux\|macos` | Sistema operativo clonado |
| `estado` | string | `limpio\|post-instalacion\|produccion` | Estado del sistema en el momento del clonado |
| `ruta` | string | ruta absoluta | Ubicación del fichero o carpeta de imagen |
| `hash_sha256` | string | hex 64 chars | SHA-256 del fichero (o hash combinado si es carpeta Clonezilla) |
| `fecha_registro` | string | ISO-8601 UTC | Momento en que se ejecutó `registrar-imagen.sh` |
| `notas` | string | libre, puede ser vacío | Anotaciones opcionales del técnico |

### Exit codes `verificar-imagen.sh`

| Code | Significado |
|------|-------------|
| 0 | Imagen íntegra — hash coincide |
| 1 | Imagen corrupta — hash no coincide |
| 2 | Imagen o entrada del manifiesto no encontrada |

---

## 2. Congelación Linux — salida por stdout

`congelacion-linux.sh` emite JSON por stdout. El esquema varía por acción.

### `--action status`

```json
{
  "action":          "status",
  "subvolumen":      "/",
  "fs_type":         "btrfs",
  "snapper_config":  "root",
  "ultimo_snapshot": {
    "numero":      "5",
    "fecha":       "2026-05-25 10:00:00",
    "descripcion": "estado-limpio"
  },
  "fecha_consulta":  "2026-05-25T14:30:00Z"
}
```

### `--action configure`

```json
{
  "action":         "configure",
  "subvolumen":     "/",
  "snapper_config": "root",
  "fecha":          "2026-05-25T14:30:00Z"
}
```

### `--action snapshot`

```json
{
  "action":         "snapshot",
  "snapper_config": "root",
  "snapshot_id":    "6",
  "descripcion":    "estado-limpio",
  "fecha":          "2026-05-25T14:30:00Z"
}
```

### `--action rollback`

```json
{
  "action":             "rollback",
  "snapper_config":     "root",
  "fecha":              "2026-05-25T14:30:00Z",
  "reinicio_requerido": true
}
```

### Exit codes `congelacion-linux.sh`

| Code | Significado |
|------|-------------|
| 0 | OK |
| 1 | Error de configuración (no root, subvol no BTRFS, sin config snapper) |
| 2 | btrfs / snapper no disponibles |
| 3 | Acción destructiva (`rollback`) sin `--confirm` |

---

## 3. Congelación Windows — salida `[PSCustomObject]` → JSON

`congelacion-windows.ps1` imprime JSON por stdout vía `ConvertTo-Json`.

### Acción `Status`

```json
{
  "action":        "Status",
  "tool":          "RebootRestoreRx",
  "installed":     true,
  "state":         "frozen",
  "cli_path":      "C:\\Program Files (x86)\\Horizon DataSys\\Reboot Restore Rx\\rrcli.exe",
  "timestamp_utc": "2026-05-25T14:30:00Z"
}
```

Valores de `state`: `frozen` | `thawed` | `unknown` | `no-installed`

### Acción `Configure`

```json
{
  "action":   "Configure",
  "tool":     "RebootRestoreRx",
  "cli_path": "C:\\Program Files (x86)\\...",
  "ok":       true
}
```

### Acción `Freeze` / `Thaw`

```json
{
  "action":        "Freeze",
  "tool":          "RebootRestoreRx",
  "ok":            true,
  "reboot_needed": true,
  "timestamp_utc": "2026-05-25T14:30:00Z"
}
```

### Exit codes `congelacion-windows.ps1`

| Code | Significado |
|------|-------------|
| 0 | OK |
| 1 | Error de configuración / falta administrador |
| 2 | Herramienta de congelación no instalada |
| 3 | Acción destructiva (`Freeze`/`Thaw`) sin `-Confirm` |
