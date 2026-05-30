# Auditoría y plan de mejoras — ResolvCore

> Lista priorizada de mejoras detectadas en auditoría del 2026-05-09.
> Marca cada `- [ ]` como `- [x]` al ir completando. Los IDs (`E1`, `S2`, …) sirven para referenciar items en commits y tickets.

---

## Cómo usar este documento

- **Severidad**: `alta` (bloqueante o seguridad) · `media` (calidad / coherencia con CLAUDE.md) · `baja` (mejora incremental).
- **Esfuerzo**: `bajo` (≤ 30 min) · `medio` (1–3 h) · `alto` (> 3 h).
- **Reversible**: ¿se puede deshacer sin reescribir histórico ni tocar terceros?
- Items marcados con **CLAUDE.md** son desviaciones respecto a las reglas que tú mismo fijaste en `.claude/CLAUDE.md` — corregir el código o relajar la regla, pero no dejarlo desalineado.

---

## Resumen ejecutivo

De 2.747 ficheros versionados en el momento de la auditoría, **2.680 (97,6 %) eran vendor MantisBT 2.28.1** (~41 MB). Solo 67 ficheros son código propio. El código custom es sólido (paridad cross-platform, plugin WP bien sanitizado, cliente Mantis con validaciones); el problema está en **vendor + artefactos + desviaciones respecto a `CLAUDE.md`**.

Si solo pudieras hacer dos tareas: **E1 + E2** (saca 41 MB del repo y deja de versionar artefactos generados). Si solo una de seguridad: **W1** (token Mantis sin cifrar).

---

# 1. Estructura y limpieza

### `E1` — Sacar el bundle MantisBT 2.28.1 del repositorio  ✅
- **Severidad**: alta · **Esfuerzo**: medio · **Reversible**: sí (con cuidado si reescribes histórico)
- **Por qué**: 2.680 ficheros (97,6 % del repo, 41 MB) son upstream GPL ajeno. Inflas clones, ensucias `git blame`, y mezclas tu código con software de terceros. El commit `a64c65a` lo introdujo.
- **Estrategia elegida**: script de bootstrap (sin reescribir histórico).
- **Acciones**:
  - [x] Decidir estrategia (submódulo / bootstrap / instalación manual).
  - [x] Implementar la elegida → `scripts/bootstrap-mantis.sh`.
  - [x] `git rm -r --cached mantisbt-2.28.1/` (los ficheros locales se conservan).
  - [x] Añadir `mantisbt-2.28.1/` a `.gitignore` para que no vuelva por accidente.
  - [ ] (Opcional) Reescribir histórico con `git filter-repo` — descartado.

### `E2` — Limpiar artefactos generados versionados  ✅
- **Severidad**: alta · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: hay bytecode, datos personales y zips empaquetados en el árbol. Viola CLAUDE.md ("No generes datos de prueba con IPs, MACs o emails reales") y rompe diffs.
- **Ficheros a desversionar**:
  - `scripts/__pycache__/buscar_vulnerabilidades.cpython-314.pyc`
  - `scripts/diagnosticos/vuln_FranVi-Victus_20260508_123609.json`
  - `scripts/diagnosticos/vuln_FranVi-Victus_20260508_123609.txt`
  - `scripts/diagnosticos/vuln_history.json`
  - `wordpress/resolvecore-landing.zip`
  - `wordpress/resolvecore-theme.zip`
  - `wordpress/resolvecore-theme-v11.zip`
- **Acciones**:
  - [x] `git rm --cached <ficheros>` (mantienes los locales, los sacas del índice).
  - [x] Añadir reglas a `.gitignore` (ver `E3`).
  - [ ] Mover los `.zip` a *Releases* de GitHub para distribución.

### `E3` — Ampliar `.gitignore`  ✅
- **Severidad**: alta · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: la regla actual `diagnosticos/*.json` no funciona porque el path real es `scripts/diagnosticos/*.json`. Falta cobertura para Python y zips de empaquetado.
- **Reglas añadidas** en commit junto a E1+E2:
  ```gitignore
  # Python
  __pycache__/
  *.pyc

  # Diagnósticos generados (corrige el path actual, que no aplica)
  scripts/diagnosticos/

  # Empaquetados del tema/plugin (van en GitHub Releases)
  wordpress/*.zip

  # Vendor MantisBT (instalado vía bootstrap o submódulo)
  mantisbt-2.28.1/
  ```
- [x] Implementado

### `E4` — Añadir `.editorconfig`  ✅
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: trabajas con PHP + Bash + PowerShell entre Windows y Linux (dual boot). Sin guardia de EOL/charset acabarás mezclando CRLF/LF en scripts críticos.
- **Implementado**: `.editorconfig` en raíz — UTF-8 + LF + indent 4 globales; `crlf` para `.ps1/.psm1/.psd1` (PowerShell ISE espera CRLF); `indent_size=2` para YAML/JSON; `tab` para Makefile; `trim_trailing_whitespace=false` en Markdown (preserva line breaks).
- [x] Implementado

### `E5` — Añadir `LICENSE` en raíz  ✅
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: README declara GPL-3.0 pero no hay fichero `LICENSE`. GitHub no detecta licencia y el proyecto queda jurídicamente ambiguo.
- **Implementado**: `LICENSE` con texto oficial GPL-3.0 (35 149 bytes) descargado de `https://www.gnu.org/licenses/gpl-3.0.txt`. GitHub ya detecta la licencia.
- [x] Implementado

---

# 2. Documentación

### `D1` — Crear `docs/flujo-sistema.md`  ✅
- **Severidad**: media · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `CLAUDE.md` referencia el fichero ("Diagrama del sistema: `docs/flujo-sistema.md`") y obliga a actualizarlo "al añadir una nueva fase al flujo del sistema". El fichero **no existe**.
- **Contenido mínimo**: promover el diagrama mermaid del README + descripción detallada de cada fase (1–7) con responsable, input, output y herramientas implicadas.
- [x] Implementado — diagrama mermaid + 7 fases (responsable / input / output / herramienta / persistencia) + tabla de payloads + guía de modificación.

### `D2` — Crear `vulnerabilities/migrations/`  ✅ (parcial)
- **Severidad**: media · **Esfuerzo**: medio · **Reversible**: sí
- **Por qué**: `CLAUDE.md` y README hablan de la tabla `rc_vulnerabilities` y de migraciones idempotentes en `vulnerabilities/migrations/`, pero **el directorio no existe**. La única SQL del repo (`mantisbt/sql/resolvecore-setup.sql`) solo configura categorías Mantis.
- **Acciones**:
  - [x] Crear `vulnerabilities/migrations/0001_init.sql` con `CREATE TABLE IF NOT EXISTS rc_vulnerabilities` (CVE, fuente, gravedad, CVSS, EPSS, KEV, SO afectado, producto, versión, fix, referencias, fecha sync) + tabla auxiliar `rc_vulnerabilities_sync` (audit trail).
  - [x] Documentar el esquema en `docs/schema-vulnerabilidades.md` (campos, índices, política de upsert, fixtures `CVE-9999-*`).
  - [ ] `0002_seed_dev.sql` con fixtures ficticios — pendiente hasta primera integración real con scanner (sin valor antes).

### `D3` — Tabla de versiones por componente en README  ✅
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: README declara `v1.2.0` pero internamente Windows va en `4.1.0`, Linux `3.2.0`, Android `2.2.0`, plugin WP `1.0.0`. Hoy es ambiguo qué número es el de referencia.
- **Implementado**: nueva sección "Versiones por componente" en README (debajo de "Estado del proyecto") con tabla `componente · path · versión · política`. Cubre producto, tema, plugin, los 8 scripts de diagnóstico/optimización por SO, escáner CVE y el schema JSON. Regla de paridad documentada: `_meta.version` del JSON ≡ versión cabecera de script.
- [x] Implementado

### `D4` — Confirmar estado real de macOS
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `docs/schema-diagnostico.md` declara macOS como `0.1.0-demo (stub)` pero `scripts/macos/diagnostico.sh` tiene 132 líneas reales. O el script ya pasó de stub y la doc está desactualizada, o la doc miente y el script no es funcional.
- [ ] Probar el script en un macOS y actualizar la versión en `_meta.version` y en `docs/schema-diagnostico.md`.

---

# 3. Calidad de scripts

### `S1` — **CLAUDE.md**: alinear shebangs y `set` en Bash  ✅
- **Severidad**: media · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `CLAUDE.md` dice *"`#!/usr/bin/env bash` en todos los scripts. `set -euo pipefail`"*. Realidad:
  - `scripts/linux/diagnostico.sh:1` → `#!/bin/bash` y solo `set -o pipefail`.
  - `scripts/linux/optimizacion.sh:13` → `set -uo pipefail` (sin `-e`).
- **Decisión aplicada**: relajar `CLAUDE.md` para reflejar la realidad. `set -uo pipefail` es la convención del proyecto en scripts con captura granular (regresión 2026-05-09 con `apt-get -s upgrade | grep -c '^Inst'` demostró que `-e` rompe la captura). `set -euo pipefail` se mantiene para scripts auxiliares cortos como `bootstrap-mantis.sh`.
- **Acciones**:
  - [x] Política documentada en `CLAUDE.md` (sección `Bash`).
  - [x] Shebangs corregidos: `linux/diagnostico.sh` y `linux/ResolveCore.sh` pasan a `#!/usr/bin/env bash`.
  - [x] `set -uo pipefail` añadido a los launchers `linux/ResolveCore.sh`, `macos/ResolveCore.sh`, `android/ResolveCore.sh` que lo omitían.

### `S2` — **CLAUDE.md**: `#Requires -Version 7.0` en PowerShell  ✅
- **Severidad**: media · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `CLAUDE.md` exige `#Requires -Version 7.0`. Realidad: `scripts/windows/diagnostico.ps1:1` declara `#Requires -Version 5.1`. README también declara PS7+. Decide cuál es la verdad.
- **Decisión aplicada**: target real es **PS5.1** (Windows 10/11 default; pedir PS7 sumaba fricción al técnico). Se alinean `CLAUDE.md` y `README.md` a 5.1.
- **Acciones**:
  - [x] Bug fix: `scripts/windows/ResolveCore.ps1:1` tenía `# Requires -Version 5.1` (con espacio = comentario inerte). Corregido a `#Requires -Version 5.1`.
  - [x] `CLAUDE.md` actualizado: directiva PS5.1 + cláusula de excepción para scripts que necesiten capacidades PS7.
  - [x] `README.md` actualizado: badge, resumen ejecutivo, capa Diagnóstico, stack table, tabla de requisitos y árbol de directorios.

### `S3` — Reescribir generación de JSON en Linux/macOS/Android  ✅
- **Severidad**: media (riesgo real de JSON inválido) · **Esfuerzo**: medio · **Reversible**: sí
- **Por qué**: scripts construían el JSON por **concatenación de strings**. Cualquier comilla, salto de línea o carácter especial rompía el JSON. **Ocurrió en producción 2026-05-09** con `actualizaciones_pendientes: $'0\n0'` provocado por `apt-get -s upgrade | grep -c '^Inst' || echo "0"` con `pipefail` (grep imprime `0` y exit 1, el `||` añade otro `0`).
- **Solución aplicada**:
  - **Linux** (3.0.0 → 3.1.0):
    - Bug raíz fix: `|| echo "0"` → `|| true` + validación regex en apt/dnf/yum/pacman.
    - Helper `json_num()` para coerción defensiva de numéricos a JSON válido (number o `null`).
    - Ensamblaje top-level migrado a `jq -n --argjson` con dump de fragmentos a `*.debug.txt` si falla.
    - `jq` ahora dependencia obligatoria (exit 3 si falta).
  - **Android** (2.0.0 → 2.1.0):
    - Mismo refactor a `jq -n --argjson` para los 7 sub-objetos (hardware, sistema_operativo, red, seguridad, aplicaciones, dispositivo, _meta).
    - `jq` añadido como dependencia obligatoria tras `adb`.
    - Helpers `json_str/num/bool` ya existentes — solo cambia la fase de ensamblaje.
  - **macOS** (stub, sin bump): hardening defensivo aunque sea stub. Si `jq` está, usa `jq -n --arg` para serializar; si no, fallback con escape manual de strings. Replicar el patrón completo cuando deje de ser stub.
- **Acciones**:
  - [x] Reescribir `scripts/linux/diagnostico.sh` (sección OUTPUT JSON).
  - [x] Replicar en `scripts/android/diagnostico.sh`.
  - [x] Hardening en `scripts/macos/diagnostico.sh` (stub).
  - [x] Versiones bumped en `docs/schema-diagnostico.md`.
  - [ ] Test con hostnames/valores que contengan `"`, `\`, `\n` para regresión.

### `S4` — Inyección segura del JSON en `informe.html`  ✅
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `linux/diagnostico.sh:683-705` inyecta el JSON crudo dentro de la plantilla con `head/tail` cortando por la marca `__JSON_DATA__`. Si algún valor contiene `</script>` el HTML revienta.
- **Implementado** (ya hecho en commits previos — verificado 2026-05-23):
  - `reports/informe.html:72` usa `<script type="application/json" id="rc-data">__JSON_DATA__</script>` y `reports/informe.html:78` parsea con `JSON.parse(document.getElementById('rc-data').textContent)`.
  - Generadores escapan `</` → `<\/` antes de inyectar: `scripts/windows/diagnostico.ps1:820` (`-replace '</', '<\/'`), `scripts/linux/diagnostico.sh:933` (`sed 's|</|<\\/|g'`), `scripts/android/diagnostico.sh:522` (mismo `sed`), `reports/generate-report.php:82` (`str_replace('</', '<\/', …)`).
  - macOS sigue stub — no inyecta HTML hasta dejar de ser stub.
- [x] Implementado

### `S6` — Mismatch nivel "basico" entre launcher y optimización  ✅
- **Severidad**: media (UX: la opción 1 del menú revienta) · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: detectado 2026-05-09 testando Android. El launcher (`ResolveCore.sh`) mapea opción 1 → `nivel_opt="basico"`, pero `optimizacion.sh` solo acepta `ligero|estandar|rendimiento|extreme`. Resultado: "Opción no reconocida: basico" + ayuda. Mismo bug en Linux + macOS + Android.
- **Solución aplicada**: `"basico"` → `"ligero"` en los tres launchers (línea 335/258/336). Etiqueta del menú "BASICO" se mantiene como label de UI.
- [x] Implementado en los tres launchers.

### `S5` — Modularizar `buscar_vulnerabilidades.py`
- **Severidad**: baja · **Esfuerzo**: alto · **Reversible**: sí
- **Por qué**: 2.709 líneas en un único fichero. No es bug, es mantenibilidad.
- **Estructura sugerida**:
  ```
  scripts/vulnscan/
      __init__.py
      cli.py            # argparse + entrypoint
      feeds/
          nvd.py
          kev.py
          osv.py
          epss.py
      report/
          json.py
          html.py
          txt.py
          csv.py
      compare.py
      mantis.py         # --mantis ticket_id
      ssh.py            # --ssh user@host
  ```
- [ ] Hacerlo solo si el fichero crece más o si se incorpora un colaborador.

---

# 4. WordPress + integración Mantis

### `W1` — **CLAUDE.md**: cifrar (o externalizar) el token Mantis  ✅
- **Severidad**: alta (seguridad) · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `wordpress/plugins/rc-mantisbt/rc-mantisbt.php:36` registra `rc_mantis_token` con `sanitize_text_field` y lo guarda en `wp_options` **en claro**. `CLAUDE.md` dice literalmente: *"YOU MUST never store sensitive data (contraseñas, tokens) en opciones de WordPress sin cifrar"*.
- **Solución aplicada**: opción 1 (constante en `wp-config.php`).
  - Helpers `rc_mantis_get_url()` y `rc_mantis_get_token()` con prioridad **constante > wp_options**.
  - Pantalla de ajustes detecta la constante y desactiva el campo correspondiente con un aviso.
  - Si la constante está definida y además existe un valor en `wp_options`, aviso de aplicación (recomendar vaciar el campo).
  - `rc_mantis_get_api()` ahora usa los helpers — ningún consumidor accede directamente a `get_option('rc_mantis_token')`.
  - `docs/mantis-integration.md` documenta la prioridad y la sección "Almacenamiento de credenciales".
- [x] Implementado.

### `W2` — Nonce en el botón "Verificar conexión"  ✅
- **Severidad**: media · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `rc-mantisbt.php:89-94` construye un enlace con `add_query_arg([..., 'rc_mantis_test' => '1'])` y lo dispara con `isset($_GET['rc_mantis_test'])`. Hay `current_user_can('manage_options')` (correcto), pero falta nonce — un admin que pinche un enlace malicioso dispararía el test sin querer (CSRF en acción admin).
- **Solución aplicada**: enlace generado con `wp_nonce_url(..., 'rc_mantis_test', 'rc_mantis_nonce')`; handler verifica con `check_admin_referer('rc_mantis_test', 'rc_mantis_nonce')` antes de llamar a `get_projects()`. Resuelto en el mismo commit que W1 (mismo archivo).
- [x] Implementado.

### `W3` — Strlen vs mb_substr en sanitize_description  ✅
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `class-mantis-api.php:175-186` mide con `strlen` (bytes) y corta con `mb_substr` (caracteres). En strings con muchos caracteres multibyte cortarás antes del límite real.
- **Implementado**: `strlen` → `mb_strlen` en `sanitize_summary()` (`:175`) y `sanitize_description()` (`:184`). Aplicado en ambas copias: `wordpress/plugins/rc-mantisbt/includes/class-mantis-api.php` y `wp/wp-content/plugins/rc-mantisbt/includes/class-mantis-api.php` (deploy local).
- [x] Implementado

### `W4` — Cabecera del plugin: declarar requisitos  ✅
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `rc-mantisbt.php:1-11` no declara `Requires at least`, `Tested up to`, `Requires PHP`. Mejora UX en WP-Admin y bloquea instalaciones incompatibles.
- **Implementado**: añadidas `Requires at least: 6.0`, `Tested up to: 6.5`, `Requires PHP: 8.0`, `License URI`, `Domain Path`. License migrada de `GPL-2.0+` a `GPL-3.0-or-later` para alinear con `LICENSE` (E5) y badge del README. Aplicado en ambas copias del plugin.
- [x] Implementado

### `W5` — `INSERT … (SELECT … LIMIT 1)` en SQL Mantis  ✅
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `mantisbt/sql/resolvecore-setup.sql:55-57` usa subquery con `LIMIT 1` en `INSERT`. Funciona pero MariaDB/MySQL emite warnings según versión.
- **Implementado**: `SELECT id ... WHERE name = ... LIMIT 1` → `SELECT MAX(id) ... WHERE name = ...` en las dos asignaciones (`@field_id` línea 39, `@anydesk_field_id` línea 56). `MAX(id)` garantiza una sola fila por construcción, sin depender de `LIMIT` (que el optimizador puede ignorar en algunos modos estrictos).
- [x] Implementado

---

# 5. CI / tooling

### `C1` — GitHub Actions con linters  ✅
- **Severidad**: baja · **Esfuerzo**: medio · **Reversible**: sí
- **Implementado**: `.github/workflows/lint.yml` con 4 jobs paralelos en `push`/`pull_request` a `main`:
  - **shellcheck** (Ubuntu) — `ludeeus/action-shellcheck@2.0.0` con `SHELLCHECK_OPTS="-e SC1091 -e SC2155"` (SC1091: source no resoluble; SC2155: declare/assign separado), severity warning, scandir `scripts/`.
  - **PSScriptAnalyzer** (Windows) — instala módulo, analiza `scripts/windows/` recursivamente; falla solo si hay errores (warnings se reportan pero no bloquean).
  - **phpcs WordPress-Core** (Ubuntu) — `shivammathur/setup-php@v2` PHP 8.2 + composer instala `squizlabs/php_codesniffer`, `wp-coding-standards/wpcs:^3.0`, `phpcompatibility/phpcompatibility-wp`. Ejecuta sobre `wordpress/plugins/rc-mantisbt/` + `wordpress/resolvecore-theme/`, reporta vía `cs2pr`. `continue-on-error: true` mientras se pulen warnings legacy.
  - **Python** (Ubuntu) — `ruff check scripts/common/ --output-format=github` + `python -m py_compile` recursivo.
- [x] Implementado

### `C2` — Pre-commit hook local  ✅
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: atrapa los mismos errores antes del push.
- **Implementado**: `.pre-commit-config.yaml` con:
  - `pre-commit/pre-commit-hooks@v4.6.0` — `end-of-file-fixer`, `trailing-whitespace`, `mixed-line-ending` (sólo check, sin auto-fix para no romper `.ps1` CRLF), `check-yaml`, `check-json`, `check-merge-conflict`, `check-added-large-files --maxkb=2048`. Exclude `wp/` y `mantisbt-2.28.1/` (vendor).
  - `shellcheck-py/shellcheck-py@v0.10.0.1` — same args que CI, scope `scripts/(linux|macos|android|server|setup)/.*\.sh$`.
  - `astral-sh/ruff-pre-commit@v0.5.0` — `--fix` sobre `scripts/common/.*\.py$`.
  - **local hook** `phpcs-wordpress` — system hook opcional; si `phpcs` no está en PATH hace skip (no fuerza a instalar la toolchain WP en cada dev).
- Instalación: `pip install pre-commit && pre-commit install`.
- [x] Implementado

---

# 6. Auditoría 2026-05-29 — regresión de vendor + secretos

> Segunda pasada tras el trabajo de registro de clientes. El repo había vuelto a
> inflarse: de 67 ficheros propios pasó a **3285 trackeados, 3119 (95 %) en `wp/`**.

### `A1` — WordPress core entero versionado en `wp/`  ✅
- **Severidad**: alta · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `wp/` traía 3119 ficheros — 2592 son `wp-includes`/`wp-admin` (core puro), más `akismet`, tema `twentytwentyfive` y `sqlite-database-integration`. Repite el problema de `E1` con WP en vez de Mantis. `wp/` no estaba en `.gitignore`. El código fuente del proyecto vive en `wordpress/`, no en `wp/`.
- **Acciones**:
  - [x] `wp/` añadido a `.gitignore`.
  - [x] `git rm -r --cached wp/` (3119 ficheros fuera del índice; locales intactos). Repo: 3285 → **165** ficheros trackeados.

### `A2` — Secretos en `wp-config.php` versionado  ✅ (parcial — falta rotar token)
- **Severidad**: alta (seguridad) · **Esfuerzo**: bajo · **Reversible**: el destrackeo sí; la **filtración del token no** (queda en histórico)
- **Por qué**: `wp-config.php` (raíz) y `wp/wp-config.php` estaban trackeados con `define('RC_MANTIS_TOKEN', …)`. El token de la API Mantis quedó **filtrado en git**, anulando el objetivo de `W1`. Viola CLAUDE.md (*"No modificar wp-config.php con credenciales reales"*). El root usa salts reales; `wp/` los deriva de `hash(__FILE__)` (predecibles).
- **Acciones**:
  - [x] `git rm --cached wp-config.php` + `wp/wp-config.php` (vía regla `wp/`).
  - [x] `.gitignore`: `wp-config.php` (ya estaba) + `wp/`.
  - [ ] **ROTAR el token Mantis** — asumir comprometido; está en el histórico de git. Regenerar en MantisBT y actualizar la constante en el `wp-config.php` del VPS (fuera de git).
  - [ ] (Opcional) `git filter-repo` para purgar el token del histórico.

### `A3` — Alta de cuenta pública sin verificación de email  ✅
- **Severidad**: media · **Esfuerzo**: medio · **Reversible**: sí
- **Por qué**: el form de la home crea usuario `rc_cliente` para cualquier email. Honeypot + rate-limit 3/h mitigan, pero no se verifica propiedad del email → spam de cuentas + emails de activación a terceros.
- **Enfoque**: la activación ya **es** verificación de email (la cuenta es inservible hasta clicar el enlace de reset, que solo llega al buzón real). Se cierra el resto del riesgo con throttle por-email + purga de cuentas no activadas, sin añadir captcha/infra externa.
- **Acciones** (`rc-core.php` 1.4.0 → **1.5.0**):
  - [x] Throttle **por-email** en `rc_crear_cuenta_cliente()`: 1 email de activación/hora por dirección (transient con `wp_salt`). Frena el email-bombing a una víctima dentro del rate-limit por IP.
  - [x] Marca `rc_pending_activation` (timestamp) al crear la cuenta.
  - [x] `after_password_reset` → `rc_cliente_on_password_reset()` borra el marcador al fijar contraseña (cuenta verificada).
  - [x] Cron diario `rc_cliente_purga_evento` → `rc_cliente_purgar_pendientes()` borra cuentas `rc_cliente` no activadas tras 7 días. Programado/desprogramado en activación/desactivación del plugin.

### `A4` — Modelo de deploy con tres repos en el VPS
- **Severidad**: media · **Esfuerzo**: medio · **Reversible**: sí
- **Por qué**: en el VPS coexisten `/opt/resolvecore-git` (rama feature), `/opt/resolvecore-repo` (main) y `/opt/resolvecore-source` (sin `.git`). `deploy.sh` asume `/var/www/wp/.git`, que no existe. Fuente de verdad ambigua.
- [x] `scripts/server/ops/sync-wp.sh` creado (autodetecta el repo canónico, rsync tema+plugins a `/var/www/wp/wp-content`).
- [x] Documentada la consolidación en `docs/tecnica/despliegue-ionos.md` §8.0: `/opt/resolvecore-repo` (main) = **canónico**; `git reset --hard origin/main` + `sync-wp.sh`; borrar `-git` y `-source`. Comandos de borrado incluidos.
- [ ] Ejecutar el borrado en el VPS (`rm -rf /opt/resolvecore-git /opt/resolvecore-source`) — acción manual de ops.

### `A5` — Copia stale de plugins en `wp/wp-content/plugins`
- **Severidad**: media · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `wp/` traía `rc-mantisbt` pero no `rc-core` → fuente de verdad doble y desincronizada. Los edits van a `wordpress/plugins/`.
- [x] Resuelto por `A1` (al destrackear `wp/`).

### `A6` — Autor mezclado en cabeceras de scripts  ✅
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: 6 scripts con `(FranVi)`, 12 con `(GitHub: Haplee)`. Nombre presente en todos, formato inconsistente.
- [x] Unificado a `Francisco Vidal Mateo (GitHub: Haplee)` (formato canónico de `CLAUDE.md`) en los 8 ficheros con `(FranVi)`: `scripts/windows/{diagnostico,optimizacion}.ps1`, `scripts/linux/{diagnostico,optimizacion}.sh`, `scripts/android/{diagnostico,optimizacion}.sh`, `scripts/common/buscar_vulnerabilidades.py`, `mantisbt/plugins/ResolveCoreBranding/ResolveCoreBranding.php`.

### `A7` — Código muerto tras separar flujos (home capta / dashboard tickea)  ✅
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `resolvecore_send_client_confirmation()`, el modal de seguimiento de ticket y `resolvecore_handle_ticket_status` quedaron huérfanos en `functions.php`/`front-page.php`.
- [x] Eliminada `resolvecore_send_client_confirmation()` (~185 líneas, sin callers tras separar flujos; el alta de cliente envía su propio email desde `rc_crear_cuenta_cliente()`). Sustituida por nota-docblock que explica la decisión.
- [x] **Conservado** el tracker público de tickets (`resolvecore_handle_ticket_status` + modal + `?rc_ticket=N&rc_t=TOKEN`): no es muerto, es feature funcional vía URL firmada (HMAC `resolvecore_ticket_token`). Decisión "reutilizar", no "eliminar" — reutilizable desde el dashboard.

---

# 7. Auditoría 2026-05-30 — lógica del flujo de cliente/técnico

> Tercera pasada, centrada en la **lógica** del trabajo de registro/dashboard
> (`rc-core` 1.5.0) y panel técnico (`functions.php`). 9 hallazgos, todos
> corregidos. PHP `-l` limpio. `rc-core` 1.5.0 → **1.5.1**.

### `L1` — Rate-limit consumido por errores de formulario  ✅
- **Severidad**: media (UX) · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `rc_registro_cliente_procesar()` incrementaba el transient de rate-limit (3/h por IP) **antes** de validar nombre/email/contraseñas. Un usuario que corrige "las contraseñas no coinciden" 3 veces quedaba bloqueado 1 h sin haber creado ninguna cuenta.
- **Fix**: el incremento se mueve a **después** de validar y de `email_exists`, justo antes de `rc_crear_cuenta_cliente()`. Solo cuentan altas reales, no submits con typos.

### `L2` — Stats del dashboard por nombre de estado localizado  ✅
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `rc_cliente_calcular_stats()` comparaba `status['name']` contra `'closed'`/`'resolved'` en inglés literal. Si Mantis devuelve nombres localizados (es), todo caía a "abiertos".
- **Fix**: conteo por `status['id'] >= 80` (enum Mantis: 80 resolved, 90 closed). Coherente con `functions.php:411`.

### `L3` — Auto-login fallido tras alta sin feedback  ✅
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: tras crear cuenta, si `wp_signon()` fallaba se renderizaba el form con un mensaje engañoso ("ya puedes iniciar sesión") pero sin sesión y sin explicación.
- **Fix**: redirección a `/registro/?tab=login&alta=ok` con mensaje de confirmación explícito en la pestaña de login.

### `L4` — `<details>` del form colapsa tras cualquier POST  ✅
- **Severidad**: baja (cosmético) · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `rc_cliente_render_form()` abría/cerraba el `<details>` con `empty($_POST)`, así que cualquier POST del sitio lo colapsaba.
- **Fix**: solo colapsa si se envió **este** formulario (`isset($_POST['rc_solicitar_informe'])`).

### `L5` — `dbDelta` en cada request  ✅
- **Severidad**: media (perf) · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `rc_create_download_log_table()` colgaba `dbDelta` de `after_setup_theme` → `SHOW TABLES`/`SHOW COLUMNS` en cada carga de cada visitante.
- **Fix**: guard de versión (`get_option('rc_dl_log_schema_ver')` vs constante `RC_DL_LOG_SCHEMA_VER`). El esquema solo se evalúa la primera vez y al cambiar la versión. Añadido hook `after_switch_theme`.

### `L6` — `RESOLVECORE_MAINTENANCE` redefine constante  ✅
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `define('RESOLVECORE_MAINTENANCE', false)` sin guard → notice "constant already defined" si se define en `wp-config.php`, y ganaba el del tema.
- **Fix**: envuelto en `if (!defined(...))`. Ahora `wp-config.php` puede forzar el modo mantenimiento.

### `L7` — `rc_tech_infra_status` sin nonce  ✅
- **Severidad**: baja (CSRF read-only) · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: único endpoint AJAX del panel técnico sin `check_ajax_referer('rc_tech_nonce')`; los otros 4 sí lo tenían.
- **Fix**: añadido el nonce server-side + `fd.append('nonce', nonce)` en `fetchInfra()` de `page-tecnicos.php` (sin el fix JS el endpoint quedaba roto).

### `L8` — Panel técnico vacío sin explicación  ✅
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `rc_tech_my_tickets` filtra `handler/reporter` de Mantis contra `user_login` de WP. Si los logins difieren, devuelve lista vacía sin avisar de la causa.
- **Fix**: si hay tickets en Mantis pero ninguno casa con el usuario, se devuelve `note` explicando el mismatch de login.

### `L9` — Factura sin clamp de horas/tarifa  ✅
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `rc_tech_factura_inline` tomaba `horas`/`tarifa` de GET sin tope; un enlace manipulado generaba cifras absurdas.
- **Fix**: clamp de cordura `0–1000` en ambos.

---

# Orden recomendado de ejecución

Por **ROI** (impacto / esfuerzo):

1. `E2` + `E3` — limpia artefactos y `.gitignore`. 30 min, alto impacto.
2. `W1` — token Mantis cifrado o externalizado. Único hallazgo de seguridad real.
3. `E1` — sacar MantisBT 2.28.1. Saca 41 MB y 2.680 ficheros del repo.
4. `S3` — JSON robusto en scripts Bash. Cierra un bug latente.
5. `D1` + `D2` — crear los docs/migraciones que `CLAUDE.md` ya promete.
6. `S1` + `S2` — alinear scripts con `CLAUDE.md` (o relajar `CLAUDE.md`).
7. `W2`, `W3`, `W4`, `W5` — pulido del plugin WP.
8. `D3`, `D4`, `S4` — coherencia de versiones, inyección segura HTML.
9. `S5`, `C1`, `C2`, `E4`, `E5` — mantenibilidad a largo plazo.

---

## Changelog del documento

| Fecha       | Cambio                                                       |
|-------------|--------------------------------------------------------------|
| 2026-05-09  | Versión inicial — auditoría completa.                        |
| 2026-05-09  | E1 + E2 + E3 completados: vendor Mantis fuera, bootstrap script, gitignore ampliado. |
| 2026-05-09  | S3 (Linux) parcial: jq -n + json_num + fix bug apt grep -c. S6 nuevo y resuelto. |
| 2026-05-09  | S3 cerrado: Android refactor (2.0.0 → 2.1.0) + macOS stub hardening. Versiones actualizadas en schema-diagnostico.md. |
| 2026-05-09  | W1 + W2 cerrados: token Mantis externalizable a `RC_MANTIS_TOKEN` (constante > wp_options), nonce CSRF en "Verificar conexión", aviso de duplicado, helpers `rc_mantis_get_*()`. D1 cerrado: `docs/flujo-sistema.md` con 7 fases. D2 parcial: migración 0001 (rc_vulnerabilities + sync) + `docs/schema-vulnerabilidades.md`. S1 + S2 cerrados: shebangs `#!/usr/bin/env bash` en linux/, `set -uo pipefail` en launchers, política Bash documentada en CLAUDE.md, target real PS5.1 alineado en CLAUDE.md/README, fix typo `# Requires` en ResolveCore.ps1. |
| 2026-05-29  | **Segunda auditoría — regresión vendor + secretos**. **A1** cerrado: `wp/` (WordPress core, 3119 ficheros = 95 % del repo) destrackeado y añadido a `.gitignore`; repo 3285 → **165** ficheros. **A2** parcial: `wp-config.php` + `wp/wp-config.php` (con `RC_MANTIS_TOKEN` filtrado) destrackeados y en `.gitignore` — **pendiente ROTAR el token** (sigue en histórico). **A5** cerrado por A1 (copia stale de plugins en `wp/`). Abiertos: **A3** alta pública sin verificación de email, **A4** consolidar 3 repos del VPS (`sync-wp.sh` ya creado), **A6** unificar formato de autor en cabeceras, **A7** código muerto tras separar flujos home/dashboard. |
| 2026-05-29  | **Cierre 2ª auditoría (sin rotar token, decisión del autor)**. **A3** cerrado: throttle por-email + `rc_pending_activation` + `after_password_reset` (verificación) + cron de purga a 7 días en `rc-core` 1.4.0→**1.5.0**. **A6** cerrado: 8 cabeceras `(FranVi)`→`(GitHub: Haplee)`. **A7** cerrado: borrada `resolvecore_send_client_confirmation()` (sin callers); tracker de tickets conservado como feature viva. **A4** documentado en `despliegue-ionos.md` §8.0 (repo canónico `-repo`, comandos de consolidación) — falta solo el `rm -rf` manual en el VPS. **A2**: token NO rotado por decisión del autor (riesgo asumido; sigue en histórico). |
| 2026-05-30  | **Tercera auditoría — lógica del flujo cliente/técnico (§7)**. 9 hallazgos corregidos en `rc-core` (1.5.0→**1.5.1**) + `functions.php` + `page-tecnicos.php`. **L1** rate-limit incrementado tras validar (no antes) — los typos ya no bloquean. **L2** stats del dashboard por `status.id>=80` en vez de nombre localizado. **L3** auto-login fallido redirige a login con `?alta=ok` + mensaje. **L4** `<details>` colapsa solo tras enviar su form. **L5** `dbDelta` con guard de versión (`rc_dl_log_schema_ver`) — fin del `SHOW` en cada request. **L6** `RESOLVECORE_MAINTENANCE` con `if(!defined)`. **L7** `check_ajax_referer` en `rc_tech_infra_status` + nonce en `fetchInfra()`. **L8** `my_tickets` devuelve `note` si el filtro por login deja la lista vacía. **L9** clamp 0–1000 en horas/tarifa de la factura. PHP `-l` limpio. |
| 2026-05-23  | Bloque quick-wins + CI cerrado: **E4** `.editorconfig` (UTF-8/LF + CRLF para PS1 + idents YAML/Makefile). **E5** `LICENSE` GPL-3.0 oficial. **D3** sección "Versiones por componente" en README con regla de paridad `_meta.version`. **S4** verificado: `<script type="application/json">` + `JSON.parse()` con escape `</`→`<\/` en 4 puntos de inyección (PS1, linux.sh, android.sh, PHP). **W3** `strlen`→`mb_strlen` en `sanitize_summary/description` (sync wordpress/ + wp/). **W4** cabeceras WP `Requires at least/Tested up to/Requires PHP/License URI`, license alineada a GPL-3.0. **W5** `SELECT id ... LIMIT 1` → `SELECT MAX(id)` en setup Mantis. **C1** `.github/workflows/lint.yml` con jobs shellcheck/PSScriptAnalyzer/phpcs WP/ruff+py_compile. **C2** `.pre-commit-config.yaml` con pre-commit-hooks + shellcheck-py + ruff + local phpcs opcional. |
