# Pendiente — 2026-05-26

Tareas que quedaron sin completar al final de la sesión del 25-05-2026.

---

## 1. Deploy VPS (prioridad alta)

- [x] Conectar al VPS y clonar / hacer pull del repo
- [x] Ejecutar el script de setup del directorio de descargas:
  ```bash
  sudo bash scripts/server/setup-downloads-dir.sh
  ```
  - Crea `/opt/resolvecore-downloads/` con permisos `www-data`
  - Instala `apache2-utils` (htpasswd)
  - Escribe config nginx `/etc/nginx/conf.d/rc-downloads.conf`
  - Recarga nginx
  - Añade `RC_DOWNLOADS_PATH` a `wp-config.php`

- [ ] Subir manualmente `RebootRestoreRx-Setup.exe` a `/opt/resolvecore-downloads/`
  - Descargar desde `https://horizondatasys.com` (vendor oficial)
  - O usar la versión ya descargada localmente

---

## 2. Construir y subir el kit cliente (prioridad alta)

- [x] Ejecutar en Windows (desde raíz del repo):
  ```powershell
  pwsh scripts/servicios/kit/construir-kit.ps1 -AnyDeskPath .\anydesk.exe
  ```
  - Si no tienes `anydesk.exe`, el script lo descarga automáticamente de `download.anydesk.com`
  - Genera `resolvecore-kit.zip` con MANIFEST.txt + checksums SHA-256

- [x] Subir `resolvecore-kit.zip` al VPS:
  ```bash
  scp dist\resolvecore-kit.zip root@resolvecore.website:/opt/resolvecore-downloads/
  ```

---

## 3. WordPress — Página de técnicos (prioridad alta)

- [x] En WP Admin → Pages → Add New:
  - Título: `Área de Técnicos`
  - Slug: `tecnicos`
  - Template: seleccionar **"Área de Técnicos"** (registrado en `functions.php`)
  - Publicar
- [x] Añadir `/tecnicos/` al menú de navegación (nav principal o menú de admin)
- [x] Asignar rol `Editor` a las cuentas WP de los técnicos que necesiten acceso

---

## 4. Pruebas end-to-end (prioridad alta)

### Portal de técnicos
- [x] Login con cuenta de técnico (rol Editor) → verificar acceso a `/tecnicos/`
- [x] Click en **Descargar para Windows** → recibir `install-servicios.ps1`
- [x] Click en **Descargar para Linux** → recibir `install-servicios.sh`
- [x] Click en **Descargar Kit** → recibir `resolvecore-kit.zip`
- [x] Verificar que sin login (o con rol Subscriber) → redirige a `/wp-login.php` (302 confirmado)

### Scripts de instalación
- [ ] Ejecutar `install.ps1` en máquina Windows limpia (sin Chocolatey):
  ```powershell
  Set-ExecutionPolicy Bypass -Scope Process -Force
  .\install-servicios.ps1
  ```
  - Verifica: Chocolatey instalado, WSL activado, AnyDesk descargado
- [ ] Ejecutar `install.sh` en máquina Linux limpia:
  ```bash
  bash install-servicios.sh
  ```
  - Verifica: jq + curl + btrfs-progs + snapper instalados

### Servicios adicionales desde el launcher
- [ ] Windows: `pwsh scripts/windows/ResolveCore.ps1` → opción 6 → submenú servicios
- [ ] Linux: `bash scripts/linux/ResolveCore.sh` → opción 6 → submenú servicios

### Congelación Linux (requiere sistema BTRFS)
- [ ] `bash scripts/servicios/congelacion/congelacion-linux.sh --action=configure`
- [ ] `bash scripts/servicios/congelacion/congelacion-linux.sh --action=snapshot`
- [ ] `bash scripts/servicios/congelacion/congelacion-linux.sh --action=rollback`
- [ ] Verificar fix B2: rollback sin snapshots devuelve error (exit 1), no silencioso

### Clonación
- [ ] `bash scripts/servicios/clonacion/registrar-imagen.sh --imagen=/ruta/imagen.img`
- [ ] `bash scripts/servicios/clonacion/verificar-imagen.sh --imagen=/ruta/imagen.img`
- [ ] Verificar fix B4: si `mv` falla, manifiesto original no se corrompe
- [ ] Verificar fix B3: path con espacios/caracteres especiales funciona

### Integración MantisBT (`--ticket`)
- [ ] Crear ticket de prueba en MantisBT, anotar ID
- [ ] Ejecutar con `--ticket=<ID>`:
  ```bash
  bash scripts/servicios/congelacion/congelacion-linux.sh --action=snapshot --ticket=42
  ```
- [ ] Verificar nota creada en MantisBT ticket #42

---

## 5. Documentación pendiente (prioridad media)

- [x] Actualizar `docs/defensa/defensa-tfg.md` sección 18 (guía de demo):
  - Añadir pasos de demo para servicios adicionales (congelación + clonación + kit)
  - Guion ampliado a 20 min con pasos 8-10 nuevos
- [x] Actualizar `README.md`:
  - Añadir "Servicios adicionales" en la tabla de módulos
  - Añadir comandos de los nuevos scripts en la sección de uso
- [ ] Verificar que `docs/scripting/schema-servicios-adicionales.md` refleja la salida JSON real de cada script (tras las pruebas)

---

## 6. Seguridad y configuración (prioridad media)

- [x] Configurar `.env` en el VPS con:
  ```
  MANTIS_URL=https://mantis.resolvecore.website
  MANTIS_TOKEN=<token_api_mantis>
  RRRX_DOWNLOAD_URL=https://resolvecore.website/downloads/RebootRestoreRx-Setup.exe
  ```
  - El `.env` debe estar fuera del docroot y con permisos `600`
- [x] Verificar que `wp-config.php` tiene `RC_DOWNLOADS_PATH` correctamente definido
- [x] Comprobar permisos nginx: `/opt/resolvecore-downloads/` solo accesible con htpasswd

---

## 7. Opcional / mejoras futuras

- [ ] Añadir página WP con tracking de descargas (cuántas veces se descargó cada fichero)
- [ ] Añadir firma digital (GPG) a los scripts en el kit para verificación de integridad
- [ ] Notificación por email al técnico cuando hay una nueva versión del kit disponible
- [ ] Soporte `--ticket` en `congelacion-windows.ps1`: pendiente de obtener URL MANTIS_URL real

---

## Referencias

- Script setup VPS: `scripts/server/setup-downloads-dir.sh`
- Bootstrap Windows: `scripts/servicios/install.ps1`
- Bootstrap Linux: `scripts/servicios/install.sh`
- Portal técnicos WP: `wordpress/resolvecore-theme/page-tecnicos.php`
- Handler descargas WP: `wordpress/resolvecore-theme/functions.php` (función `rc_handle_technician_download`)
- Schema JSON servicios: `docs/scripting/schema-servicios-adicionales.md`
- Changelog sesión: `docs/defensa/cambios _desde_25_05.md`
