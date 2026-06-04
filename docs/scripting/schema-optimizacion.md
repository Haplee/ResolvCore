# Esquema del acta de optimización — ResolveCore

> Artefacto que producen los scripts `scripts/{windows,linux,android}/optimizacion.*`
> al optimizar un equipo. Deja **constancia escrita de todo lo realizado** para que
> técnico y cliente sepan exactamente qué se tocó en el dispositivo.
>
> Se generan **dos ficheros** en `reparaciones/<NNNNN>/`:
> - `optimizacion.json` — estructurado (técnico / endpoint de flota).
> - `optimizacion.txt`  — legible en español (para el cliente).
>
> **No es el informe técnico** rellenado a mano (`generar_informe.py`): es un registro
> automático de la intervención (un "acta"), artefacto distinto y complementario.

---

## Versionado

`_meta.version` sigue **SemVer**. Tabla por plataforma:

| Plataforma | Script                     | Versión | Notas |
|------------|----------------------------|---------|-------|
| Windows    | `windows/optimizacion.ps1` | **1.0** | TEMP/WSUS/papelera + procesos + arranque + acta + flota |
| Linux      | `linux/optimizacion.sh`    | **1.0** | apt/journal/tmp/snap + consumo + acta + flota |
| Android    | `android/optimizacion.sh`  | **1.0** | pm trim-caches + batterystats + acta + flota |

---

## Estructura JSON

```json
{
  "_meta": {
    "plataforma": "windows | linux | android",
    "hostname":   "string",
    "version":    "1.0",
    "tipo":       "optimizacion"
  },
  "timestamp": "ISO-8601",
  "ticket": "00042 | sin-ticket",
  "acciones": [
    {
      "paso": "trim_caches",
      "descripcion": "Limpieza de caché de apps (conserva datos)",
      "resultado": "caché liberada",
      "estado": "ok | fallo | omitido"
    }
  ],
  "hallazgos_consumo": [
    {
      "nombre": "com.whatsapp",
      "tipo": "bateria | cpu | memoria | arranque",
      "detalle": "45.2 mAh estimados",
      "accion": "reportado | detenido"
    }
  ],
  "resumen": {
    "espacio_liberado_mb": 1536.0,
    "acciones_ok": 5,
    "acciones_fallidas": 0,
    "consumidores_detectados": 3,
    "consumidores_detenidos": 0
  }
}
```

> En Android `resumen.espacio_liberado_mb` es `null` (la limpieza de caché vía
> `pm trim-caches` no devuelve un total fiable de bytes liberados).

---

## Acciones por plataforma

| Plataforma | Pasos (`paso`) |
|------------|----------------|
| Linux      | `apt_clean`, `journal`, `tmp`, `snap` |
| Android    | `trim_caches`, `tmp` |
| Windows    | `temp_usuario`, `temp_sistema`, `temp_local`, `wsus_cache`, `papelera` |

Cada paso mide el espacio liberado antes/después (salvo Android) y registra
`estado`: `ok` (hecho), `fallo` (error/sin permisos), `omitido` (no aplica).

## Detección de consumo (`hallazgos_consumo`)

| Plataforma | Origen | `tipo` |
|------------|--------|--------|
| Linux      | `ps --sort=-%cpu` (umbral CPU > 5%) | `cpu` |
| Android    | `dumpsys batterystats --charged` ("Estimated power use") + `pm list packages -U` | `bateria` |
| Windows    | `Get-Process` (top CPU) + `Win32_StartupCommand` | `cpu`, `arranque` |

**Detención (`accion: "detenido"`)** solo ocurre con la flag explícita
`--stop-hogs` (Bash) / `-StopHogs` (PS) y **nunca** sobre procesos/paquetes de
sistema:
- Linux: excluye `ssh sshd cron crond systemd-journald NetworkManager systemd init dbus-daemon`.
- Android: solo apps de terceros (UID ≥ 10000); excluye `com.android.*`, `android`,
  Play Services/GSF y `*.systemui`.
- Windows: excluye `System Idle csrss wininit winlogon services lsass smss svchost explorer dwm`.

---

## Subida a la flota

Si se exportan `RC_CLIENT_EMAIL` y `RC_FLEET_TOKEN` (o `-ClientEmail`/`-Token` en
PS), el acta se publica en `POST /wp-json/rc/v1/fleet` envuelta como:

```json
{ "client_email": "cliente@example.com", "ticket_id": 42, "optimizacion": { ... } }
```

El endpoint distingue el acta por la clave `optimizacion`: sella `optim_at` en la
fila del host (no recalcula `last_score`, que es propio del diagnóstico) y responde
`{ ok, action: "optim_updated|optim_created", optim_at }`. Si falla la red, el acta
local sigue disponible y el técnico la sube a MantisBT a mano.

---

## Convenciones

- **Booleanos / nulos:** `true`/`false`/`null` literales en JSON.
- **Espacio:** MB en el resumen; las acciones lo muestran en MB/GB legibles.
- **Fechas:** ISO-8601.
- Cada acción está aislada: si una falla, el resto del proceso y el acta se completan.
- La flag de confirmación (`--confirm` / `-Confirm`) es **obligatoria**; sin ella el
  script no toca nada.

---

*Última actualización: 2026-06-04*
