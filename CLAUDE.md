# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project summary

ResolveCore — ASIR final project by Francisco Vidal Mateo. Cross-platform diagnostic and optimization platform. Stack: **WordPress theme (PHP + vanilla JS + CSS) + standalone shell scripts (PowerShell/Bash)**. No build step. No npm. No React. No Supabase.

> **Legacy warning:** `.env.example`, `notes/falta.md` and `notes/investigacion.md` reference a previous React/Supabase version that no longer exists. The authoritative state document is `notes/analiza.md`.

---

## Running scripts

```bash
# Windows — run as Administrator for full S.M.A.R.T. and security metrics
.\scripts\windows\diagnostico.ps1
.\scripts\windows\optimizacion.ps1
.\scripts\windows\ResolveCore.ps1          # interactive menu (calls the two above)

# Linux
bash scripts/linux/diagnostico.sh [output_dir] [silent:true]
bash scripts/linux/optimizacion.sh
bash scripts/linux/ResolveCore.sh

# macOS
bash scripts/macos/diagnostico.sh
bash scripts/macos/ResolveCore.sh

# Android (requires ADB enabled on device)
bash scripts/android/diagnostico.sh
bash scripts/android/ResolveCore.sh
```

Scripts write JSON output to `scripts/diagnosticos/<timestamp>_<platform>.json`.

## PHP syntax check

```bash
php -l wordpress/resolvecore-theme/front-page.php
php -l wordpress/resolvecore-theme/functions.php
php -l wordpress/resolvecore-theme/page-docs.php
php -l wordpress/resolvecore-theme/page-changelog.php
```

## WordPress theme installation

```bash
cp -r wordpress/resolvecore-theme/ /path/to/wp-content/themes/resolvecore-theme/
# Then: WP Admin → Appearance → Themes → activate ResolveCore
# Create pages: Docs (Template: ResolveCore Docs), Changelog (Template: ResolveCore Changelog)
```

---

## Architecture

### WordPress theme (`wordpress/resolvecore-theme/`)

| File | Role |
|------|------|
| `front-page.php` | Main landing (~1150 lines): navbar, hero, services, interactive demo, vulnerabilities table, downloads, pricing, contact form |
| `functions.php` | WP hooks: enqueue styles/fonts, AJAX contact handler, honeypot check, maintenance mode |
| `page-docs.php` | `Template Name: ResolveCore Docs` — sidebar nav + scrollable content, inline CSS |
| `page-changelog.php` | `Template Name: ResolveCore Changelog` — vertical timeline, inline CSS |
| `style.css` | Shared styles: fonts, CSS variables, shared layout rules |
| `index.php` | WP required fallback |

**Key patterns:**
- All CSS classes prefixed `rc-` to avoid WordPress theme conflicts
- CSS variables defined in `:root` inside `front-page.php` `<style>` block (dark theme: `--rc-bg`, `--rc-accent`, `--rc-mono`, etc.)
- All JS is vanilla — no jQuery, no external libraries
- AJAX contact form: `wp_ajax_resolvecore_contact` / `wp_ajax_nopriv_resolvecore_contact` with `check_ajax_referer('resolvecore_contact', 'nonce')` + honeypot field `rc_website`
- Maintenance mode: flip `RESOLVECORE_MAINTENANCE` constant in `functions.php` to `true`
- Page-specific CSS lives inline in each `page-*.php` file (not in `style.css`)

### Scripts (`scripts/`)

Each platform has the same three scripts:
- `diagnostico.*` — collects system metrics (OS, CPU, RAM, disk, network, security, S.M.A.R.T.) → writes JSON
- `optimizacion.*` — performs safe cleanup (temp files, cache, startup items) → writes JSON report
- `ResolveCore.*` — interactive menu wrapper that invokes the two above

PowerShell scripts use `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'SilentlyContinue'`. Bash scripts use `set -o pipefail`. Both output colored console feedback with `[OK]`/`[!]`/`[X]` levels.

S.M.A.R.T. data: Linux uses `smartctl` (optional, graceful fallback). Windows uses `Get-StorageReliabilityCounter` (primary) → `Get-PhysicalDisk` (fallback). Missing data is reported as `null` in the JSON, not as an error.

### Notes (`notes/`)

| File | Content |
|------|---------|
| `analiza.md` | **Current audit** — issues, scores, action plan. Use this as source of truth |
| `PROPUESTA DE PROYECTO INTEGRADO.md` | Original project proposal |
| `Plan de desarrollo.md` | Development timeline |
| `investigacion.md` | Technical research (CVE APIs, S.M.A.R.T., architecture decisions) — written for old React version but research is still valid |
| `falta.md` | Pending items — **marked as legacy** (references old React paths) |
| `diary.md` | Dev diary |

---

## Constraints

- **No npm / no build step** — the theme has zero npm dependencies. Do not add any.
- **Vanilla JS only** — no jQuery, no frameworks inside the theme.
- **CSS prefix** — all new theme CSS classes must use `rc-` prefix.
- **`rel="noopener noreferrer"`** on all `target="_blank"` links.
- **ARIA** — icon-only buttons need `aria-label`; interactive `<span>` elements need `role="button" tabindex="0"` and keyboard handlers.
- macOS scripts exist (`scripts/macos/`) but macOS is **not shown** in the platform strip on the landing page. Do not add it to the UI without confirming scope.
- The `og-image.png` exists at `wordpress/resolvecore-theme/og-image.png` (1200×630).
