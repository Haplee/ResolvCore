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

### Portal técnicos (WordPress)

- Plantilla: `wordpress/resolvecore-theme/page-tecnicos.php`
- Handler descarga: `rc_handle_technician_download()` en `functions.php`
- Acceso: rol `editor` o `administrator`
- Descargas servidas via nginx `/downloads/` con HTTP Basic Auth

---

## Tests pendientes

### Scripts de instalación
- [ ] `install.ps1` en VM Windows limpia — verifica Chocolatey + WSL + AnyDesk
- [ ] `install.sh` en Linux limpio — verifica jq + curl + btrfs-progs + snapper

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

Cuando hay cambios en el repo local:

```powershell
# 1. Push desde Windows
git push origin feat/facturacion-clonacion-congelacion
```

```bash
# 2. Pull en VPS
cd /opt/resolvecore-git && git pull

# 3. Sincronizar tema WP
cp wordpress/resolvecore-theme/*.php /var/www/wp/wp-content/themes/resolvecore-theme/
cp wordpress/resolvecore-theme/functions.php /var/www/wp/wp-content/themes/resolvecore-theme/

# 4. Sincronizar scripts de descarga
cp scripts/servicios/install.ps1 /opt/resolvecore-downloads/install-servicios.ps1
cp scripts/servicios/install.sh  /opt/resolvecore-downloads/install-servicios.sh
```

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
