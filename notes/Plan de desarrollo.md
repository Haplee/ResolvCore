# ResolveCore — Plan de Desarrollo y Roadmap (WordPress)

> Última actualización: 28 abril 2026
> Proyecto Integrado ASIR 2026
> Stack: WordPress Theme + PHP + MySQL

---

## Estado Real del Proyecto — WordPress Theme

### Puntuación Global: 8.4/10 (B)

Tras migración a WordPress theme (commit 280426):

| Módulo | Estado | Puntuación | Observaciones |
|--------|--------|------------|---------------|
| Landing Page (front-page) | Funcional | 9/10 | Demo interactiva completa |
| Página Docs | Funcional | 8.5/10 | Sidebar, código copy-paste |
| Página Changelog | Funcional | 8.5/10 | Timeline de versiones |
| Formulario Contacto | Funcional | 8/10 | AJAX + honeypot anti-spam |
| Modo Mantenimiento | Funcional | 9/10 | Constante configurable |
| SEO / Meta tags | Funcional | 8/10 | OG, Twitter Card, Schema.org |
| Estilos CSS | Funcional | 8/10 | Tema oscuro, diseño propio |

---

## Funcionalidades Completadas

### Del Archivo cambio.md

- [x] **Tarea 1:** Enlaces de descarga con tooltips "Próximamente" + data-platform
- [x] **Tarea 2:** Página docs (page-docs.php) con sidebar navegable
- [x] **Tarea 3:** Página changelog (page-changelog.php) con timeline
- [x] **Tarea 4:** Formulario mejorado (validación, honeypot, contador 500 chars)
- [x] **Tarea 5:** Meta tags SEO (Open Graph, Twitter Card, Schema.org)
- [x] **Tarea 6:** Modo mantenimiento opcional (RESOLVECORE_MAINTENANCE)

---

## Scripts de Diagnóstico (Parte del TFG)

Los scripts de diagnóstico son ejecutables independientes:

| Script | Plataforma | Estado |
|--------|------------|--------|
| `diagnostico.ps1` | Windows (PowerShell) | Completo v3.0.0 |
| `diagnostico.sh` | Linux (Bash) | Completo |
| `optimizacion.ps1` | Windows (PowerShell) | Completo |
| `optimizacion.sh` | Linux (Bash) | Completo |

**Ubicación:** `scripts/windows/`, `scripts/linux/`, `scripts/macos/`

**Funcionalidad:** generan JSON con métricas de hardware, SO, red y seguridad para importar en el formulario de diagnóstico del técnico.

---

## Deuda Técnica

| Severidad | Cantidad | Área principal |
|----------|---------|---------------|
| CRITICAL | 0 | — |
| HIGH | 0 | — |
| MEDIUM | 3 | SEO image, downloads, API缓存 |
| LOW | 4 | CSS compartido, pre-commit, static analysis |

---

## Issues — Priorizados

### MEDIUM

| ID | Problema | Esfuerzo |
|----|---------|----------|
| M-001 | og-image.png no existe | S |
| M-2 | URLs de descarga placeholder | XS |
| M-3 | API NVD sin caché local | M |

### LOW

| ID | Problema | Esfuerzo |
|----|---------|----------|
| L-001 | CSS inline en page-docs.php | S |
| L-2 | Estilos duplicados en page-changelog.php | S |
| L-3 | Sin pre-commit hooks PHP | S |
| L-4 | Sin análisis estático PHP (PHPStan) | M |

---

## Cronograma — Pre-defensa

**Plazo:** 28 abril → 5 junio 2026

### Semana 7 — Pulido

**Bloque A — SEO y Metadatos (30 min)**

- [ ] M-001: crear og-image.png (1200x630)
- [ ] actualizar meta descriptions

**Bloque B — Estilos Compartidos (1h)**

- [ ] L-001: extraer CSS de page-docs.php a style.css
- [ ] L-2: reutilizar estilos en page-changelog.php

**Bloque C — Mejoras Ocionales**

- [ ] M-2: actualizar URLs de descarga tras primer release
- [ ] L-3: GitHub Actions con PHP linting (`php -l`)
- [ ] implementar PDF server-side (TCPDF/mPDF) — si hay tiempo

**Bloque D — Descartar**

- M-3 (caché NVD): mantener como mejora futura en memoria
- L-4 (PHPStan): mencionar en memoria como mejora futura

---

## Módulos ASIR Cubiertos

| Módulo | Estado |
|--------|--------|
| Gestión de BD + Admin. SGBD | ✅ |
| Servicios en Red + Implantación Apps Web | ✅ (WP theme) |
| Lenguajes de Marca (HTML/CSS) | ✅ |
| FOL + Empresa | ✅ (propuesta) |
| Administración de SO | ✅ (scripts) |
| Fundamentos Hardware | ✅ (scripts diagnóstico) |
| Planificación Redes | ✅ (scripts red) |
| Seguridad | ✅ (sesiones, nonces, prepared statements) |

---

## Fases de Desarrollo

### ✅ MVP — WordPress Theme (Completado)

Tema WordPress operativo: landing con demo interactiva, docs, changelog, formulario AJAX, modo mantenimiento.

**Criterio de done:** todas las tareas del archivo cambio.md completadas.

---

### v1.0 — Listo para Defensa

Objetivo: entrega del 5 de junio.

**Criterio de done:**
- og-image.png creada
- CSS compartido entre páginas docs/changelog
- GitHub Actions con PHP linting
- Tema WordPress funcional en servidor WP

**Estimación:** 2h

---

### v2.0 — Post-defensa (Opcional)

- PDF server-side con TCPDF/mPDF
- Caché local para API NVD
- Módulo de incidencias
- App Android (Kotlin) — propuesto en ampliación

---

## Métricas Objetivo

| Métrica | Objetivo |
|---------|---------|
| Puntuación global | 8.5/10 |
| Issues críticos | 0 |
| Issues HIGH | 0 |
| Documentación | Completa |
| Scripts diagnóstico | ✅ 4 plataformas |

---

## Notas para la Defensa

- El tribunal verá el tema WordPress funcionando en vivo
- La demo interactiva demuestra el diagnóstico en tiempo real
- Los scripts de diagnóstico se ejecutan en máquinas reales o VMs
- La propuesta cubre todos los módulos ASIR requeridos
- Changelog documenta la evolución desde v1.0.0

---

## Recomendaciones Finales

1. **Subir tema WordPress** a un servidor WP (puede ser local o hosting compartido)
2. **Preparar scripts** de diagnóstico en USB para demo en máquina real
3. **Capturas de pantalla** del theme, docs y changelog para documentación
4. **oger imagen** antes de la defensa
5. **Probar formulario** de contacto en producción

---

*Plan actualizado: 28 abril 2026*
*Stack: WordPress + PHP + MySQL*
*Estado: LISTO PARA ENTREGA*