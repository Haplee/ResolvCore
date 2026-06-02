# Análisis de procesos — Flujo de 7 fases ResolveCore

> Entrevista de procesos (skill `entrevistador-procesos`) — análisis del flujo completo end-to-end.
> Generado: 2026-06-01 · Autor del proyecto: Francisco Vidal Mateo
> Prioridad acordada: **1) cuellos de botella → 2) onboarding → 3) defensa TFG → 4) huecos/fallos**.
> Estado: **plan de trabajo para ejecutar**.

---

## 1. Objetivo del proceso

Llevar una incidencia de cliente desde la solicitud hasta el cobro:

`solicitud → ticket → conexión remota → diagnóstico → resolución → informe PDF → factura`

## 2. Destinatario

- **Cliente final**: pide soporte, sigue su ticket, recibe informe + factura.
- **Técnico**: ejecuta diagnóstico/resolución, genera informe, factura.
- **Defensa TFG**: explicar el flujo sin ambigüedades ante el tribunal.

## 3. Flujo paso a paso — REAL (según el código, no la documentación)

| Fase | Implementación real | Fichero clave | Estado |
|------|---------------------|---------------|--------|
| **1. Solicitud** | Form público de la home **eliminado** (anti-DDoS). Hoy solo `/registro/` (alta cuenta) → ticket desde el dashboard del cliente | `functions.php:305`, `rc-core.php` | ✅ funciona · ❌ doc desfasado |
| **2. Ticket** | `rc_mantis_crear_ticket()` → REST `POST /api/rest/issues`, categoría fija "Soporte técnico" | `rc-core.php:85` | ✅ funciona |
| **3. Asignación** | Manual en MantisBT (Kanban + SLA plugins) | MantisBT | ✅ manual |
| **4. AnyDesk** | Manual, ID del cliente como custom field | — | ✅ manual |
| **5. Diagnóstico** | Scripts `diagnostico.ps1/.sh` v2.0 → JSON. macOS = stub demo | `scripts/windows`, `scripts/linux` | ✅ Win/Linux · ⚠️ macOS/Android |
| **6. Informe PDF** | `RC_Tech_Report::generate()` → `shell_exec(php reports/generate-report.php)` | `class-rc-tech-report.php:30` | 🔴 **roto** |
| **7. Factura** | `rc_tech_factura_inline()` — HTML imprimible, horas/tarifa por URL | `functions.php:1007` | ⚠️ semi-manual |

## 4. Inputs por fase

F1 nombre+email+pass → F2 summary+description → F4 ID AnyDesk → F5 sistema objetivo → F6 JSON diagnóstico → F7 horas+tarifa.

## 5. Outputs por fase

Cuenta cliente → ticket MantisBT → sesión remota → JSON diagnóstico → sistema optimizado → PDF adjunto al ticket → factura HTML.

## 6. Reglas principales (verificadas en código)

- Sanitización/escape WP en todo input/output ✅
- Rate-limit alta (3/h/IP) + honeypot ✅
- Filtro anti-fuga: cada cliente solo ve sus tickets (`rc_mantis_filtrar_por_cliente`) ✅
- Optimizaciones reversibles (`--undo` / `-Undo`) ✅

## 7. Excepciones / casos límite cubiertos

- Auto-login tras alta falla → redirige a login ✅
- Cuenta ya existe → mensaje claro ✅
- Cron purga cuentas no activadas a 7 días ✅
- Bypass SSH/ADB salta F4 ✅

---

## 9. CUELLOS DE BOTELLA Y HUECOS (núcleo del análisis)

### Prioridad 1 — Cuellos de botella

#### C1 · Fase 6 (informe) está rota — el cuello más caro
`RC_Tech_Report` llama a `reports/generate-report.php` vía `shell_exec`. **Ese fichero NO existe en el repo.** Hay **3 generadores distintos** documentados, incompatibles:

- `flujo-sistema.md` → `scripts/informe.html` + wkhtmltopdf
- `CLAUDE.md` → `scripts/common/generar_informe.py` (archivado en `_archivo/`)
- `rc-tech` → `reports/generate-report.php` (fantasma)

→ El informe **no se genera solo**. Trabajo manual puro. **Acción de mayor impacto: unificar a UN generador real.**

#### C2 · Fase 5→6: no hay puente automático del JSON
El diagnóstico se genera en el equipo del **cliente** (`scripts/diagnosticos/`, gitignored). `RC_Tech_Report` espera `rc_tech_lookup_host()->last_json` ya en el servidor. **No existe el mecanismo de subida** del JSON desde el equipo del cliente a WP. El técnico lo copia a mano.

#### C3 · Fase 2: filtrado de tickets en PHP, no en Mantis
La REST de Mantis **ignora `search`** y devuelve TODOS los tickets; se filtran en PHP en cada carga del dashboard. Hay un `TODO: cachear 60s` **sin implementar** (`rc-core.php:164`). Escala mal y castiga la API.

#### C4 · Fase 7: factura semi-manual
`rc_tech_factura_inline` recibe horas/tarifa **por query param**, no persiste la factura ni numera de forma secuencial real (usa el ID del ticket). Sin registro contable.

### Prioridad 4 — Huecos / inconsistencias de documentación

- **H1** · `flujo-sistema.md` Fase 1 describe el form de 5 tipos que **ya no existe**. Changelog del doc parado en `2026-05-09`. Viola la regla de CLAUDE.md ("actualizar flujo-sistema al cambiar fase").
- **H2** · `CLAUDE.md` cita `php artisan resolvecore:report` — comando **Laravel**, y el proyecto es WordPress. Fantasma.
- **H3** · macOS y Android: F5 son stubs/parciales pero el flujo los lista como soportados.

## 8. Criterios de calidad (cómo sabré que está "perfecto")

1. Un técnico nuevo ejecuta las 7 fases **sin preguntar nada** (onboarding).
2. El informe PDF se genera con **un comando**, sin copiar JSON a mano.
3. `flujo-sistema.md` describe lo que el código hace **de verdad** (defensa TFG sólida).
4. Cero referencias fantasma (artisan, `reports/`, 3 generadores).

---

## 10. PLAN DE TRABAJO — mañana (en orden de prioridad)

> Decisión bloqueante previa: **¿cuál es el generador de informes real?** (C1). Sin resolver esto, la tarea 1 no arranca.

| # | Acción | Ataca | Esfuerzo | Hecho |
|---|--------|-------|----------|-------|
| 0 | **Decidir UN generador de informes** (PHP `reports/`, Python archivado, o HTML+wkhtmltopdf) | C1 | Decisión | ☐ |
| 1 | Implementar/recuperar ese generador y borrar los otros 2 caminos | C1 (cuello) | Medio | ☐ |
| 2 | **Subida del JSON** cliente→WP (endpoint REST o vía `install-servicios`) | C2 (cuello) | Medio | ☐ |
| 3 | Implementar `set_transient 60s` ya marcado como TODO en `rc-core.php:164` | C3 (cuello) | Bajo | ☐ |
| 4 | **Reescribir `flujo-sistema.md`** con el flujo real (onboarding + defensa) | H1 | Bajo | ☐ |
| 5 | Quitar comando artisan fantasma de `CLAUDE.md` | H2 | Trivial | ☐ |
| 6 | Factura: persistir + numeración secuencial real | C4 | Medio | ☐ |
| 7 | Marcar macOS/Android como ROADMAP explícito en el flujo | H3 | Trivial | ☐ |

### Quick wins para empezar (bajo riesgo, mejora defensa/onboarding ya)
Tareas **3 + 4 + 5 + 7** se pueden cerrar en una sesión corta y no tocan lógica crítica.

### Bloque grande (cuello real)
Tareas **0 + 1 + 2** = arreglar la generación y entrega del informe. Es el núcleo del valor del producto.

---

## Notas para la defensa TFG

- El flujo de 7 fases es **secuencial con una bifurcación tolerada** (F5 offline vía SSH/ADB salta F4).
- Las 3 primeras fases (web + ticket + alta cliente) están **sólidas y seguras** (sanitización, rate-limit, anti-fuga, anti-spam).
- Los puntos débiles a reconocer ante el tribunal con honestidad: generación de informe (F6) y facturación (F7) son las fases menos maduras — y este documento es la prueba de que el análisis está hecho y planificado.

---

## Changelog del documento

| Fecha | Cambio |
|-------|--------|
| 2026-06-01 | Versión inicial — análisis de procesos vía skill entrevistador-procesos. |
