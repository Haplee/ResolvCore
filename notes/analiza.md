# Auditoría Técnica — ResolveCore (WordPress)

> Fecha: 28 abril 2026
> Auditor: ResolveCore Internal Audit
> Versión: 3.0 (post-migración WordPress)
> Stack: WordPress Theme + PHP + MySQL

---

## Resumen ejecutivo

Estado general: **8.4 / 10**. Proyecto ASIR basado en WordPress, listo para entrega tras los cambios del commit de migración a tema WordPress.

**Arquitectura Actual**
- WordPress con tema personalizado (`resolvecore-theme/`)
- PHP + HTML + CSS + JS vanilla
- MySQL/MariaDB con WordPress
- Sesiones PHP nativas para autenticación
- WP REST API / admin-ajax.php para endpoints AJAX

**Métricas**
- Críticos: **0**
- High: **0**
- Medium: **3**
- Low: **4**
- Info: **2**

---

## Inventario del Tema WordPress

| Elemento | Estado |
|----------|--------|
| `front-page.php` | Completado (1124 líneas) |
| `functions.php` | Completado (65 líneas) |
| `page-docs.php` | Completado (nuevo) |
| `page-changelog.php` | Completado (nuevo) |
| `style.css` | Existente |
| `index.php` | Existente |

---

## Tareas Completadas del Archivo cambio.md

| # | Tarea | Estado |
|---|------|--------|
| 1 | Enlaces de descarga + tooltips "Próximamente" | ✅ |
| 2 | Página docs (`page-docs.php`) | ✅ |
| 3 | Página changelog (`page-changelog.php`) | ✅ |
| 4 | Formulario mejorado (validación, honeypot, contador) | ✅ |
| 5 | Meta tags SEO (Open Graph, Twitter Card, Schema.org) | ✅ |
| 6 | Modo mantenimiento (`RESOLVECORE_MAINTENANCE`) | ✅ |

---

## Issues Medium

### [MED-001] SEO — og:image no existe

**Archivo:** `front-page.php:28`

Se referencia `/og-image.png` pero el archivo no existe.

**Solución:** crear og-image.png (1200x630) con el branding ResolveCore. Coste S.

---

### [MED-002] Descargas sin URLs reales

**Archivo:** `front-page.php:686,695,704`

Los botones tienen `href="#"` con `data-platform`. Cuando haya releases, actualizar a URLs reales.

**Solución:** actualizar tras primer release en GitHub. Coste XS.

---

### [MED-003] API CVE externa sin caché local

**Archivo:** `functions.php` / `api/cves.ts`

La API CVE/NVD del NIST depende de conexión externa. Sin API key las requests son limitadas (5/30s).

**Solución:** considerar cache local o API key de NVD. Coste M.

---

## Issues Low

### [LOW-001] Estilo inline en page-docs.php

**Archivo:** `page-docs.php`

CSS en línea dentro del PHP. Ideal para tema WP sería mover a `style.css`.

**Solución:** extraer a hoja de estilos del tema. Coste S.

---

### [LOW-002] page-changelog.php sin estilos compartidos

**Archivo:** `page-changelog.php`

Duplica variables CSS de `page-docs.php`. should share via `style.css`.

**Solución:** mover CSS común a `style.css`. Coste S.

---

### [LOW-003] Sin pre-commit hooks

No hay validación de PHP antes de commit.

**Solución:** añadir GitHub Actions con `php -l` para linting. Coste S.

---

### [LOW-004] Sin análisis estático PHP

No hay PHPStan ni Psalm para el código PHP.

**Solución:** añadir PHPStan al CI. Coste M.

---

## Info

### [INFO-001] Scripts de diagnóstico externos

El tema WordPress no incluye los scripts de diagnóstico (PowerShell, Bash). Deben estar en repositorio separado o enlazados.

### [INFO-002] PDF generation pending

La propuesta indica TCPDF o mPDF desde servidor PHP. Actualmente no implementado — el PDF se genera desde cliente (JS).

---

## Análisis por dimensión

| Dimensión | Puntuación | Notas |
|---|---|---|
| Seguridad | 8.5/10 | Sesiones PHP, password_hash(), prepared statements |
| Performance | 8/10 | Tema estático con JS mínimo |
| Arquitectura | 8.5/10 | WordPress theme estándar, separación clara |
| Testing | 7/10 | Tests del cliente (JS), PHP sin coverage |
| PHP | 8/10 | Código limpio, sin deprecated APIs |
| Documentación | 8.5/10 | README, docs WP, changelog, diary |
| Accesibilidad | 6/10 |Etiquetas ARIA básicas, mejora needed |
| Despliegue | 8/10 | WP standard, GitHub Actions |

---

## Valoración académica ASIR

| Criterio | Puntuación | Justificación |
|---|---|---|
| Funcionalidad | 9/10 | Portal completo con demos interactivas |
| Código | 8.5/10 | PHP moderno, JS vanilla, CSS propio |
| Seguridad | 8.5/10 | Sesiones seguras, nonces, prepared statements |
| Base de datos | 8.5/10 | MySQL con WP, esquemas del negocio |
| Documentación | 8.5/10 | Docs, changelog, propuesta completa |
| Testing | 7/10 | Tests JS, lógica cubierto |
| **Total** | **8.4/10** | Apto con sobresaliente para entrega ASIR |

---

## Plan de acción — Pre-defensa

### Bloque 1 — SEO y metadatos (Completado)
- [x] MED-001: crear og-image.png (Generada y copiada)

### Bloque 2 — Estilos compartidos (Completado)
- [x] LOW-001: extraer CSS de page-docs.php a style.css
- [x] LOW-002: compartir estilos con page-changelog.php

### Bloque 3 — Mejoras opcionales si hay tiempo
- [ ] MED-002: actualizar URLs de descarga tras release
- [ ] MED-003: añadir API key NVD para mejor rate limiting
- [ ] LOW-3: añadir GitHub Actions con PHP linting
- [ ] INFO-002: implementar PDF desde servidor (TCPDF/mPDF)

### Bloque 4 — Descartar para entrega
- MED-001 (PDF síncrono): mejorar desde cliente es suficiente para demo
- LOW-004: PHPStan como mejora futura en memoria

---

## Conclusión

ResolveCore basado en WordPress alcanza **8.4/10**. El tema cubre todas las funcionalidades descritas en la propuesta: landing page con demo interactiva, páginas docs/changelog, formulario con AJAX, y modo mantenimiento.

Los scripts de diagnóstico (PowerShell, Bash) son ejecutables independientes del tema WordPress y se documentan en la propuesta como parte del módulo de Administración de SO.

**Recomendación:** apto para entrega final del 5 de junio de 2026 tras completar Bloque 1.

---

*Auditoría completada: 28 abril 2026*
*Stack: WordPress + PHP + MySQL*
*Estado: LISTO PARA ENTREGA (Bloque 1 y 2 finalizados)*