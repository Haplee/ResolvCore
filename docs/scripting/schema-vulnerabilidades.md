# Esquema de la tabla `rc_vulnerabilities`

> Persistencia local de las vulnerabilidades consumidas por `scripts/buscar_vulnerabilidades.py` y consultadas por los scripts de diagnóstico. La sincronización con feeds externos es responsabilidad del scanner CVE; esta tabla solo persiste el estado consolidado.
>
> Migración inicial: [`vulnerabilities/migrations/0001_init.sql`](../vulnerabilities/migrations/0001_init.sql).

---

## Visión general

| Tabla | Propósito |
|---|---|
| `rc_vulnerabilities` | Catálogo consolidado de CVEs por SO/producto. |
| `rc_vulnerabilities_sync` | Audit trail de cada run de sincronización (fuente, contadores, estado). |

Ambas viven en la base de datos de WordPress (o en un schema dedicado si el despliegue lo separa) con prefijo `rc_` siguiendo `CLAUDE.md`.

---

## `rc_vulnerabilities`

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| `id` | `BIGINT UNSIGNED` PK | No | Auto-increment. |
| `cve_id` | `VARCHAR(32)` UNIQUE | No | Formato `CVE-YYYY-NNNNN`. |
| `fuente` | `VARCHAR(16)` | No | `NVD`, `KEV`, `OSV`, `EPSS`. Si la entrada se ha consolidado desde varias, prevalece la última que la tocó (auditable vía `rc_vulnerabilities_sync`). |
| `gravedad` | ENUM | No | `none / low / medium / high / critical`. |
| `cvss_score` | `DECIMAL(3,1)` | Sí | 0.0–10.0 según CVSSv3 (NVD). |
| `epss_score` | `DECIMAL(5,4)` | Sí | 0.0000–1.0000 (FIRST EPSS). |
| `kev_listed` | `TINYINT(1)` | No | `1` si aparece en CISA KEV (explotación activa conocida). |
| `so_afectado` | `VARCHAR(64)` | No | `windows / linux / macos / android / cross / <vendor>`. |
| `producto` | `VARCHAR(128)` | Sí | `openssl`, `kernel`, `chrome`, … |
| `version_rango` | `VARCHAR(255)` | Sí | Expresión CPE o rango legible. |
| `titulo` | `VARCHAR(255)` | No | Una línea. |
| `descripcion` | `TEXT` | No | Texto plano (≤ 4 KB). |
| `fix` | `TEXT` | Sí | Mitigación o versión que corrige. |
| `referencias` | `TEXT` | Sí | URLs separadas por salto de línea. |
| `publicado_en` | `DATETIME` | Sí | Fecha original de publicación. |
| `actualizado_en` | `DATETIME` | Sí | Última actualización en el feed. |
| `fecha_sync` | `DATETIME` | No | Última sync local con la fuente. |
| `creado_en` | `DATETIME` | No | Inserción local. |

### Índices

| Índice | Columnas | Para qué |
|---|---|---|
| `uk_cve_id` | `cve_id` UNIQUE | Garantiza idempotencia en sync. |
| `idx_rc_vuln_so` | `so_afectado` | Filtro por SO desde scripts de diagnóstico. |
| `idx_rc_vuln_gravedad` | `gravedad` | Listados ordenados por severidad. |
| `idx_rc_vuln_kev` | `kev_listed` | Alertas inmediatas de KEV. |
| `idx_rc_vuln_fecha_sync` | `fecha_sync` | Detectar entradas obsoletas. |
| `idx_rc_vuln_producto` | `producto` | Lookup por software detectado. |

### Reglas de actualización

- **Upsert por `cve_id`**: la sync semanal hace `INSERT … ON DUPLICATE KEY UPDATE` para no duplicar y preservar `creado_en`.
- **`fecha_sync` se actualiza siempre** que la entrada se toque, aunque el contenido no cambie.
- **`kev_listed`** se sobrescribe en cada sync con KEV — si CISA elimina una entrada, el flag debe volver a `0`.

---

## `rc_vulnerabilities_sync`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `BIGINT UNSIGNED` PK | |
| `fuente` | `VARCHAR(16)` | `NVD / KEV / OSV / EPSS`. |
| `iniciado_en` | `DATETIME` | `DEFAULT CURRENT_TIMESTAMP`. |
| `finalizado_en` | `DATETIME` | NULL hasta que el run cierra. |
| `items_nuevos` | `INT UNSIGNED` | Filas insertadas. |
| `items_actualizados` | `INT UNSIGNED` | Filas modificadas. |
| `estado` | ENUM | `ok / parcial / fallo`. |
| `detalle` | `TEXT` | Mensaje de error o resumen. |

Útil para responder en una pasada: ¿cuándo fue la última sync exitosa de NVD? ¿qué runs de KEV fallaron esta semana?

---

## Política de fixtures

Los seeds de desarrollo deben usar **CVE IDs explícitamente ficticios** (`CVE-9999-9000` en adelante) para evitar confundir un fixture local con un CVE real cuando un script consulte la tabla. **Nunca** se versionan datos reales de clientes ni capturas con CVEs reales asociados a un host del usuario.

---

## Cómo aplicar la migración

```bash
mysql -u resolvecore_user -p resolvecore_db < vulnerabilities/migrations/0001_init.sql
```

La migración es idempotente: ejecutarla dos veces es seguro (todas las sentencias usan `IF NOT EXISTS`).

---

## Cómo consultar desde un script

```sql
-- Vulnerabilidades críticas KEV-listed para Linux con CVSS ≥ 9.0
SELECT cve_id, titulo, cvss_score, fix
FROM rc_vulnerabilities
WHERE so_afectado IN ('linux', 'cross')
  AND gravedad = 'critical'
  AND kev_listed = 1
  AND cvss_score >= 9.0
ORDER BY cvss_score DESC, fecha_sync DESC;
```

---

## Changelog del documento

| Fecha | Cambio |
|---|---|
| 2026-05-09 | Versión inicial — migración 0001 + tabla auxiliar de sync. |
