# Handoff — ResolveCore

> Estado del proyecto al 2026-05-26. Para retomar trabajo o entregar contexto al tutor.

---

## Estado general

| Indicador | Estado |
|---|---|
| Versión | 1.2.0-beta |
| Entrega TFG | 5 de junio de 2026 |
| Web producción | https://resolvecore.website |
| MantisBT | https://mantis.resolvecore.website |
| Portal técnicos | https://resolvecore.website/tecnicos/ |
| Rama activa | `feat/facturacion-clonacion-congelacion` |

---

## Infraestructura VPS

| Recurso | Valor |
|---|---|
| Proveedor | Ionos VPS Linux S (Madrid) |
| OS | Ubuntu 24.04 LTS |
| Web root WP | `/var/www/wp/` |
| Tema activo | `/var/www/wp/wp-content/themes/resolvecore-theme/` |
| Repo en VPS | `/opt/resolvecore-git/` |
| Descargas técnicos | `/opt/resolvecore-downloads/` |
| htpasswd nginx | `/etc/nginx/.htpasswd-tecnicos` |
| .env scripts | `/opt/resolvecore-git/.env` (permisos 600) |
| nginx vhost | `/etc/nginx/sites-enabled/resolvecore.conf` |

### Ficheros en `/opt/resolvecore-downloads/`

| Fichero | Estado |
|---|---|
| `install-servicios.ps1` | ✅ |
| `install-servicios.sh` | ✅ |
| `resolvecore-kit.zip` | ✅ |
| `RebootRestoreRx-Setup.exe` | ❌ Eliminado — freeware discontinuado |

---

## Módulos implementados

### Scripts de servicios (`scripts/servicios/`)

| Script | Función | Estado |
|---|---|---|
| `congelacion/congelacion-windows.ps1` | Status/Configure/Freeze/Thaw con RRRx o Deep Freeze | ✅ |
| `congelacion/congelacion-linux.sh` | BTRFS + snapper: status/configure/snapshot/rollback | ✅ |
| `clonacion/registrar-imagen.sh` | Alta en `imagenes-manifest.json` + SHA-256 | ✅ |
| `clonacion/verificar-imagen.sh` | Valida integridad imagen (exit 0/1/2) | ✅ |
| `kit/construir-kit.ps1` | Genera `resolvecore-kit.zip` | ✅ |
| `install.ps1` | Bootstrap Windows (Chocolatey + WSL + AnyDesk) | ✅ |
| `install.sh` | Bootstrap Linux (jq + curl + btrfs-progs + snapper) | ✅ |

### Portal técnicos (WordPress) — rediseñado 2026-05-26

- Plantilla: `wordpress/resolvecore-theme/page-tecnicos.php`
- Handler descarga: `rc_handle_technician_download()` en `functions.php`
- Acceso: rol `editor` o `administrator` (admin bar oculto para editor)
- Bootstrappers públicos: `https://resolvecore.website/install.ps1` y `/install.sh`
- Kit binarios protegido: `/downloads/` con HTTP Basic Auth (htpasswd)

**Features UI:**
- Hero con gradient mesh animado + título gradient text
- Estado infra en vivo (3 pings 60s, cached): MantisBT / Web / Fleet
- Tabs sticky + auto-detect SO por UA + localStorage
- Terminal mock con chrome (3 dots, prompt, cursor parpadeante)
- SHA-256 + tamaño + mtime reales por fichero
- QR del oneliner (modal, qrserver.com)
- Troubleshooting expandible (UAC, BOM, BTRFS)
- Checklist primer uso persistido localStorage
- Widget tickets Mantis del técnico
- **Dashboard ticket activo (pinned, sticky)**: cronómetro, add note Mantis, upload informe PDF/HTML, generar factura HTML (`?rc_factura=ID&cliente=X&horas=N&tarifa=€`), AnyDesk launcher (`anydesk:ID` + historial)
- **Command palette Ctrl+K**: búsqueda fuzzy de tabs, acciones, links, tickets
- **Tail logs en vivo**: últimas 20 entradas `wp_rc_download_log`, refresh 10s
- Atajos teclado: `1/2/3` tabs, `C` copia oneliner activo, `Ctrl+K` palette, `Esc` cierra
- Generador README cliente personalizado (cliente + ticket → .txt descargable)

**Endpoints backend nuevos (`functions.php`):**
| Endpoint | Tipo | Función |
|---|---|---|
| `rc_tech_infra_status` | AJAX | Ping servicios, cache 60s |
| `rc_tech_my_tickets` | AJAX | Tickets Mantis filtrados por user |
| `rc_tech_logs_tail` | AJAX | Últimas 20 descargas |
| `rc_tech_add_note` | AJAX | Añade nota al ticket pinned |
| `rc_tech_upload_informe` | AJAX | Adjunta PDF/HTML al ticket |
| `rc_tech_factura_inline` | GET | Factura HTML imprimible |
| `rc_tech_build_readme` | POST | README cliente personalizado |

**Tablas DB nuevas:**
- `wp_rc_download_log` (id, file_key, user_login, ip, ua, downloaded_at) — creada vía `dbDelta` en `after_setup_theme`

---

## Tests pendientes

### Scripts de instalación
- [x] `install.ps1` en VM Windows limpia — verificado 2026-05-26 (Chocolatey + WSL + jq + AnyDesk)
- [x] `install.sh` en VPS Linux — verificado 2026-05-26 (ext4 detectado, BTRFS skip esperado)

### Servicios adicionales
- [ ] Clonación: `registrar-imagen.sh` + `verificar-imagen.sh` con imagen real
- [ ] Congelación Linux: requiere BTRFS — skip si VPS es ext4
- [ ] Launcher → opción 6 SERVICIOS (Windows + Linux)

### Integración MantisBT
- [ ] `congelacion-linux.sh --action=snapshot --ticket=<ID>` → nota en ticket

---

## Configuración clave

### `.env` en VPS (`/opt/resolvecore-git/.env`)
```
MANTIS_URL=https://mantis.resolvecore.website
MANTIS_TOKEN=<token API MantisBT>
SMTP_HOST=smtp.ionos.es
SMTP_PORT=587
SMTP_USER=tecnicos@resolvecore.website
SMTP_PASSWORD=<password Ionos>
SMTP_FROM=tecnicos@resolvecore.website
SMTP_FROM_NAME=ResolveCore
```

### Constantes `wp-config.php`
```php
define('RC_DOWNLOADS_PATH', '/opt/resolvecore-downloads');
define('RC_MANTIS_TOKEN', '<token>');
define('RC_FLEET_TOKEN', '<token>');
```

### Credenciales WP producción
- Admin: usuario `franvi` (administrador)
- Técnico de prueba: cuenta con rol `Editor`

---

## Flujo de actualización VPS

**Tema WP** ya es symlink (`/var/www/wp/wp-content/themes/resolvecore-theme` → `/opt/resolvecore-git/wordpress/resolvecore-theme`). Cualquier `git pull` actualiza sin copiar.

```powershell
# 1. Push desde Windows
git push origin feat/facturacion-clonacion-congelacion
```

```bash
# 2. Pull en VPS
cd /opt/resolvecore-git && git pull

# 3. Si install.ps1 cambia: re-copiar a /opt/resolvecore-downloads/ con BOM
sudo bash scripts/server/setup-downloads-dir.sh
# (el script ya añade BOM UTF-8 al .ps1 — PS5.1 lo necesita)
```

**Cache CSS:** si cambios visuales no aparecen, bump versión en `functions.php`:
```bash
sed -i "s/'3.1.3'/'3.2.0'/" /opt/resolvecore-git/wordpress/resolvecore-theme/functions.php
```

**Gotchas:**
- PS5.1 lee `.ps1` sin BOM como ANSI → parser falla con em-dashes. `setup-downloads-dir.sh` añade BOM automáticamente al copiar.
- `www-data` tiene shell `/usr/sbin/nologin` → usar `sudo -u www-data -s /bin/bash -c '...'` para wp-cli.
- Conflicto `git pull` por edits locales en VPS: `git checkout -- <file>` para descartar (los cambios reales vienen del repo).

---

## Próximos pasos (post-tests)

1. Completar tests pendientes arriba
2. Merge `feat/facturacion-clonacion-congelacion` → `main`
3. Preparar demo defensa (guion en `docs/defensa/defensa-tfg.md` sección 18)
4. Verificar `schema-servicios-adicionales.md` contra salida JSON real

---

## Referencias

| Documento | Ruta |
|---|---|
| Memoria defensa | `docs/defensa/defensa-tfg.md` |
| Tareas pendientes | `docs/tareas/pendiente-2026-05-26.md` |
| Schema servicios | `docs/scripting/schema-servicios-adicionales.md` |
| Despliegue VPS | `docs/tecnica/despliegue-ionos.md` |
| Índice completo | `docs/INDEX.md` |
