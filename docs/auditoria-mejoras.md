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

### `E4` — Añadir `.editorconfig`
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: trabajas con PHP + Bash + PowerShell entre Windows y Linux (dual boot). Sin guardia de EOL/charset acabarás mezclando CRLF/LF en scripts críticos.
- **Plantilla mínima**:
  ```ini
  root = true
  [*]
  charset = utf-8
  end_of_line = lf
  insert_final_newline = true
  trim_trailing_whitespace = true
  indent_style = space
  indent_size = 4
  [*.{ps1,psm1,psd1}]
  end_of_line = crlf
  [*.md]
  trim_trailing_whitespace = false
  ```
- [ ] Implementado

### `E5` — Añadir `LICENSE` en raíz
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: README declara GPL-3.0 pero no hay fichero `LICENSE`. GitHub no detecta licencia y el proyecto queda jurídicamente ambiguo.
- [ ] Añadir `LICENSE` con el texto oficial GPL-3.0.

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

### `D3` — Tabla de versiones por componente en README
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: README declara `v1.1.0` pero internamente Windows va en `3.2.0`, Linux `3.0.0`, Android `2.0.0`, plugin WP `1.0.0`. Hoy es ambiguo qué número es el de referencia.
- [ ] Añadir en README (o `docs/defensa-tfg.md`) tabla "Componente → Versión actual" y política de versionado por componente.

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

### `S4` — Inyección segura del JSON en `informe.html`
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `linux/diagnostico.sh:683-705` inyecta el JSON crudo dentro de la plantilla con `head/tail` cortando por la marca `__JSON_DATA__`. Si algún valor contiene `</script>` el HTML revienta.
- **Acciones**:
  - [ ] Cambiar plantilla para que el JSON viva en `<script type="application/json" id="rc-data">…</script>` y se lea con `JSON.parse(document.getElementById('rc-data').textContent)`.
  - [ ] Aplicar en `scripts/informe.html` y en los puntos de inyección de cada SO.

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

### `W3` — Strlen vs mb_substr en sanitize_description
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `class-mantis-api.php:175-186` mide con `strlen` (bytes) y corta con `mb_substr` (caracteres). En strings con muchos caracteres multibyte cortarás antes del límite real.
- [ ] Cambiar la condición a `mb_strlen($s) > self::MAX_*` para coherencia.

### `W4` — Cabecera del plugin: declarar requisitos
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `rc-mantisbt.php:1-11` no declara `Requires at least`, `Tested up to`, `Requires PHP`. Mejora UX en WP-Admin y bloquea instalaciones incompatibles.
- [ ] Añadir cabeceras estándar de WordPress.

### `W5` — `INSERT … (SELECT … LIMIT 1)` en SQL Mantis
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: `mantisbt/sql/resolvecore-setup.sql:55-57` usa subquery con `LIMIT 1` en `INSERT`. Funciona pero MariaDB/MySQL emite warnings según versión.
- [ ] Sustituir por `SET @anydesk_field_id = (SELECT MAX(id) ...);` o similar.

---

# 5. CI / tooling (pendiente)

### `C1` — GitHub Actions con linters
- **Severidad**: baja · **Esfuerzo**: medio · **Reversible**: sí
- **Stack sugerido**:
  - `shellcheck` para `scripts/{linux,macos,android}/*.sh`.
  - `PSScriptAnalyzer` para `scripts/windows/*.ps1`.
  - `phpcs` con `WordPress-Core` ruleset para `wordpress/`.
  - `python -m py_compile` + `ruff` para `scripts/buscar_vulnerabilidades.py`.
- **Workflow recomendado**: corre en PRs y bloquea merge con errores.
- [ ] Implementado

### `C2` — Pre-commit hook local
- **Severidad**: baja · **Esfuerzo**: bajo · **Reversible**: sí
- **Por qué**: atrapa los mismos errores antes del push.
- [ ] Añadir `.pre-commit-config.yaml` con shellcheck + ruff + phpcs.

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
