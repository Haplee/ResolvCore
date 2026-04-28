# ResolveCore — Lo que FALTA por hacer

> Estado: 27 abril 2026 | Puntuación actual: 8.4/10 | Objetivo: 8.7/10

---

## ✅ RESUELTO (del commit anterior)

| Issue | Estado |
|-------|--------|
| CRITICAL RLS diagnosticos | ✅ Migration aplicada |
| CRITICAL RLS notas_internas | ✅ Migration aplicada |
| CRITICAL RLS vulnerabilidades | ✅ Migration aplicada |
| HIGH Paginación CVE | ✅ Implementado (8/page) |
| HIGH Tests fallback NVD | ✅ 10 tests nuevos |
| HIGH Rate limiting Edge Function | ✅ 10 req/min |
| HIGH Tipos TypeScript nvdApi | ✅ Sin `any` |
| HIGH handleRating refetch | ✅ Corregido |
| HIGH Búsquedas dashboards | ✅ Funcionales |
| HIGH HistoricoDiagnosticos | ✅ Integrado |
| HIGH as any en inserts | ✅ Parcialmente corregido |

---

## 🔴 PENDIENTE — Medium Priority

### [MED-001] PDF síncrono bloquea el hilo principal
**Archivo:** `src/lib/generatePDF.ts`
**Problema:** `jsPDF` se ejecuta en el main thread, congela 1-2s con informes largos
**Solución:** Web Worker con `comlink` o `?worker` de Vite
**Coste:** M (alto)
**Recomendación:** Descartar para entrega — mejora marginal

---

### [MED-002] Sin loading skeleton en dashboards
**Archivos:** `src/pages/client/Dashboard.tsx`, `src/pages/technician/Dashboard.tsx`
**Problema:** Hooks no exponen estado `loading`, UI vacía mientras carga
**Solución:** Añadir flag `loading` a hooks + skeletons en dashboards
**Coste:** S
**→ ACCIÓN:** Implementar

---

### [MED-003] TTL de caché KEV hardcodeado
**Archivo:** `supabase/functions/enrich-cve/index.ts`
**Problema:** 24h fijas, CISA actualiza varias veces al día
**Solución:** `Deno.env.get('KEV_TTL_MS')` con default 24h
**Coste:** XS
**→ ACCIÓN:** Implementar

---

### [MED-004] Sin auditoría de eventos auth
**Archivo:** `src/stores/authStore.ts`
**Problema:** Login, logout, cambios de rol no se persisten
**Solución:** Trigger `AFTER INSERT` en `auth.audit_log_entries`
**Coste:** M
**Recomendación:** Documentar en memoria como trabajo futuro

---

## 🟡 PENDIENTE — Low Priority

### [LOW-001] Accesibilidad — pocos `aria-label`
**Archivos:** `StarRating`, `Login`, `Register` (solo 6 ocurrencias)
**Problema:** Botones de iconos en `NotificacionesPanel`, `CVESearchPanel`, `HistoricoDiagnosticos` carecen de ARIA
**Solución:** Añadir `aria-label` a botones-icono + `aria-live="polite"` a notificaciones
**Coste:** S
**→ ACCIÓN:** Implementar

---

### [LOW-002] Variables poco descriptivas
**Archivo:** `src/lib/diagnosticoUtil.ts:26`
**Problema:** `m` → `metrics`
**Solución:** Renombrar parámetro
**Coste:** XS
**→ ACCIÓN:** Implementar

---

### [LOW-003] `console.warn` en producción
**Archivo:** `src/lib/nvdApi.ts:109,117`
**Problema:** Contamina consola en producción
**Solución:** Wrapper `log.warn()` que respete `import.meta.env.DEV`
**Coste:** XS
**→ ACCIÓN:** Implementar

---

### [LOW-004] Sin análisis de bundle
**Problema:** Recharts + jsPDF son pesados, sin visibilidad de tamaño
**Solución:** `vite-plugin-visualizer` en `vite.config.ts`
**Coste:** S
**Recomendación:** Opcional

---

### [LOW-005] Sin pre-commit hooks
**Problema:** No hay Husky ni lint-staged
**Solución:** `npx husky init` + `lint-staged` con `eslint --fix` y `tsc --noEmit`
**Coste:** S
**Recomendación:** Opcional

---

## ℹ️ PENDIENTE — Info / Nice-to-have

### [INFO-001] Sin error tracking
- No hay Sentry / Glitchtip
- **Acción:** Mencionar en memoria como mejora futura

### [INFO-002] README sin capturas
- Faltan capturas del portal cliente y técnico para defensa oral
**→ ACCIÓN:** Añadir capturas

### [INFO-003] Diary fuera del index
- `notes/dairy.md` typo intencional
- **Acción:** Renombrar a `diary.md` y enlazar desde README

---

## 📋 PLAN DE ACCIÓN RECOMENDADO

### Bloque 1 — Pulido pre-defensa (prioridad alta)
- [ ] **MED-002**: Loading skeletons en dashboards
- [ ] **LOW-001**: aria-label en botones-icono
- [ ] **LOW-003**: Wrapper log que respete DEV mode
- [ ] **INFO-002**: Añadir capturas al README
- [ ] **INFO-003**: Renombrar dairy.md → diary.md

### Bloque 2 — Opcional (si hay tiempo)
- [ ] MED-003: TTL KEV configurable
- [ ] LOW-002: Variables descriptivas
- [ ] LOW-005: Husky + lint-staged
- [ ] LOW-004: vite-plugin-visualizer

### Descartar para entrega
- MED-001 (PDF Web Worker): coste alto, mejora marginal
- MED-004 (auditoría auth): documentar como trabajo futuro

---

## 📊 Resumen

| Categoría | Pendientes | Accionables |
|-----------|-----------|-------------|
| Medium | 4 | 3 (descartar 1) |
| Low | 5 | 3-5 depending on time |
| Info | 3 | 2 |
| **Total accionables** | — | **8-10** |

**Objetivo realista:** 8.7/10 completando Bloque 1 completo + 2 items de Bloque 2

---

*Documento generado: 27 abril 2026*
*Basado en: notes/analiza.md + notes/Plan de desarrollo.md*