# Criterio de versionado

> Unifica cómo se numeran los componentes versionables de ResolveCore.
> Evita el desajuste entre la versión del tema, la del changelog público y la
> de cada plugin.
> **Autor:** Francisco Vidal Mateo · TFG ASIR 2024/25

---

## 0. El problema

ResolveCore tiene **cuatro flujos de versión independientes** que es fácil
confundir:

| Componente | Dónde vive la versión | Visible para |
|------------|-----------------------|--------------|
| Tema `resolvecore-theme` | `style.css` (`Version:`) + `functions.php` (`wp_enqueue_style`) | Técnico (cache-busting) |
| Versión de producto | `page-changelog.php` (timeline `vX.Y.Z`) | Cliente (página pública) |
| Plugin `rc-fleet` | cabecera `* Version:` + `define('RC_FLEET_VERSION')` | Técnico (panel WP) |
| Plugin `rc-mantisbt` | cabecera `* Version:` + `define('RC_MANTIS_VERSION')` | Técnico (panel WP) |
| Esquema de diagnóstico | `_meta.version` del JSON de los scripts | Sistema (validación) |

Cada uno avanza a su ritmo. **No deben sincronizarse a la fuerza**: un cambio
de CSS no implica subir la versión de un plugin. La regla es saber *cuándo*
toca cada uno.

---

## 1. Semántica común — SemVer

Todos los componentes usan **SemVer** (`MAYOR.MENOR.PARCHE`):

- **PARCHE** (`x.y.Z`): corrección de bug, ajuste de estilo, retoque de texto.
  Sin cambio de comportamiento ni de interfaz.
- **MENOR** (`x.Y.0`): funcionalidad nueva compatible hacia atrás.
- **MAYOR** (`X.0.0`): cambio incompatible (rompe API, esquema o flujo).

---

## 2. Regla por componente

### 2.1 Tema `resolvecore-theme`

La versión del tema sirve para **cache-busting**: WordPress sirve CSS/JS con
`?ver=X.Y.Z`, así el navegador del cliente descarga la versión nueva.

- **Sube siempre que cambies `style.css`, `front-page.php` o cualquier asset
  encolado.** Aunque sea un retoque mínimo → sube el PARCHE.
- Mantén **idénticos** los dos sitios donde aparece:
  - `style.css` → línea `Version:`
  - `functions.php` → tercer argumento de `wp_enqueue_style('resolvecore-style', …, '3.1.2')`
- Si los dos no coinciden, el cache-busting falla en silencio.

### 2.2 Versión de producto (`page-changelog.php`)

Es la versión **que ve el cliente** en la página de changelog. Representa el
*sistema ResolveCore como conjunto*, no un fichero concreto.

- **Sube MENOR (`v1.2.0`) cuando se entrega una funcionalidad nueva al cliente**
  (p. ej. el correo de confirmación de ticket).
- **Sube PARCHE** solo si se corrige algo que el cliente notó.
- Cada entrada del timeline lleva fecha y lista de cambios.
- No tiene por qué coincidir con la versión del tema: el tema puede ir por
  `3.1.x` mientras el producto va por `1.2.x`. Son escalas distintas.

### 2.3 Plugins (`rc-fleet`, `rc-mantisbt`)

Cada plugin versiona **su propia funcionalidad**, de forma independiente.

- Sube según SemVer al tocar el plugin.
- Mantén **idénticos** los dos sitios:
  - cabecera del fichero → `* Version:`
  - constante → `define('RC_FLEET_VERSION', '0.2.2')`
- Un plugin en `0.y.z` indica que aún es pre-1.0 (interfaz no estable).

### 2.4 Esquema de diagnóstico (`_meta.version`)

Versión del **contrato JSON** entre los scripts y `rc-mantisbt` /
`generate-report.php`.

- Sube MAYOR si cambias un campo de forma incompatible (renombrar, quitar).
- Sube MENOR si añades un campo opcional.
- `rc-mantisbt` valida `_meta.version`: ver `docs/scripting/schema-diagnostico.md`.

---

## 3. Checklist al publicar un cambio

1. ¿Tocaste CSS/JS/PHP del tema? → sube versión del tema en **los dos** sitios.
2. ¿El cliente verá algo nuevo? → añade entrada en `page-changelog.php` y sube
   la versión de producto.
3. ¿Tocaste un plugin? → sube su versión en cabecera **y** constante.
4. ¿Cambiaste la salida JSON de un script? → sube `_meta.version` y actualiza
   `docs/scripting/schema-diagnostico.md`.
5. Refleja el cambio en `docs/defensa/defensa-tfg.md` (regla del proyecto).
6. Regenera los `.zip` afectados en `builds/`.

---

## 4. Estado actual (2026-05-21)

| Componente | Versión |
|------------|---------|
| Tema `resolvecore-theme` | `3.1.3` |
| Producto (changelog) | `v1.2.0` |
| Plugin `rc-fleet` | `0.2.2` |
| Plugin `rc-mantisbt` | `1.0.0` |
| Esquema de diagnóstico | `4.0.0` |
