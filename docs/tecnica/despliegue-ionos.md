# Despliegue ResolveCore en VPS Ionos

> Guía de despliegue completo para VPS Ionos Linux S (Ubuntu 24.04 LTS).
> Resultado: WordPress en `<dominio>` + MantisBT en `mantis.<dominio>`,
> ambos con HTTPS Let's Encrypt, en el mismo VPS de 2,50 €/mes.
>
> Script automatizado: `scripts/server/deploy-ionos.sh` (idempotente).
> Tiempo total: ~15 min si el DNS ya propagó.

---

## 0. Pre-requisitos

| Recurso | Dónde se obtiene | Coste |
|---------|------------------|-------|
| VPS Linux S Ionos (1 vCPU / 2 GB / 80 GB) | `ionos.es` → "Servidores Cloud y VPS" | 2,50 €/mes (promo) |
| Dominio (`.es` / `.com` / …)              | Ionos o DonDominio                    | ~7-12 €/año |
| Email administrativo                        | Cualquier proveedor                   | — |
| SSH key pública (ED25519 recomendado)       | `ssh-keygen -t ed25519` en local      | gratis |

Coste anual estimado año 1: **~37-50 €** (12 × 2,50 + dominio).

## 1. Provisión del VPS

### 1.1 Pedir VPS

Panel Ionos → `Servidores Cloud y VPS` → `VPS Linux S`:

- **SO**: Ubuntu 24.04 LTS
- **Datacenter**: Madrid (latencia mínima España)
- **Hostname**: `resolvecore-prod` (o similar)
- **Plazo**: mensual (no anual hasta validar)
- **Snapshot**: activar — 0,5 €/mes adicional pero salva la vida

Tras provisión (5-15 min), Ionos envía email con:
- IP pública (v4 + v6)
- Usuario inicial: `root`
- Password inicial (uso único)

### 1.2 Configurar DNS

Panel Ionos → `Dominios y SSL` → tu dominio → `Configurar dominio` → `Registros DNS`:

| Tipo | Nombre  | Valor             | TTL  |
|------|---------|-------------------|------|
| A    | `@`     | `<IP_IONOS_IPv4>` | 3600 |
| A    | `www`   | `<IP_IONOS_IPv4>` | 3600 |
| A    | `mantis`| `<IP_IONOS_IPv4>` | 3600 |
| AAAA | `@`     | `<IP_IONOS_IPv6>` | 3600 |
| AAAA | `mantis`| `<IP_IONOS_IPv6>` | 3600 |

Esperar 10-30 min y verificar desde local:

```bash
dig +short resolvecore.es
dig +short mantis.resolvecore.es
```

Ambos deben resolver a la IP del VPS. **No continúes hasta que la resolución sea correcta** — Let's Encrypt falla sin DNS.

## 2. Primer acceso al VPS

```powershell
# Desde Windows local — PowerShell
ssh root@<IP_IONOS>
# Te pide el password del email Ionos.

# Cambio inmediato (incluso si vas a deshabilitarlo después):
passwd
```

## 3. Subir el código del proyecto al VPS

Desde **tu máquina Windows** (PowerShell), comprime y sube:

```powershell
cd C:\Users\franc\proyecto\ResolvCore

# Empaqueta solo lo necesario (tema, plugin, scripts SQL, deploy script)
$exclude = @('--exclude=wp/', '--exclude=node_modules/', '--exclude=.git/',
             '--exclude=mantisbt-2.28.1/', '--exclude=scripts/diagnosticos/')
tar @exclude -czf resolvecore-src.tar.gz `
    wordpress/ mantisbt/ scripts/ docs/ reports/ vulnerabilities/

scp resolvecore-src.tar.gz root@<IP_IONOS>:/tmp/
```

En el VPS:

```bash
mkdir -p /opt/resolvecore-source
tar -xzf /tmp/resolvecore-src.tar.gz -C /opt/resolvecore-source
rm /tmp/resolvecore-src.tar.gz
ls /opt/resolvecore-source/wordpress/resolvecore-theme/    # comprobación
```

## 4. Ejecutar el script de despliegue

```bash
chmod +x /opt/resolvecore-source/scripts/server/deploy-ionos.sh

REPO_PATH=/opt/resolvecore-source \
bash /opt/resolvecore-source/scripts/server/deploy-ionos.sh \
    --domain resolvecore.es \
    --email  admin@resolvecore.es \
    --user   franvi \
    --ssh-pubkey "$(cat /root/.ssh/authorized_keys | head -n1)"
```

El script pide interactivamente:
- `WP_DB_PASS`     — contraseña MySQL para `wp_user`
- `MANTIS_DB_PASS` — contraseña MySQL para `mantis_user`

**Guárdalas en gestor de contraseñas** — no se vuelven a pedir.

El script automatiza:

| Paso | Acción |
|------|--------|
| 1    | `apt update && upgrade` |
| 2    | nginx + PHP-FPM 8.3 + MariaDB + certbot + ufw + fail2ban |
| 3    | Crea usuario `franvi` + clave SSH + sudo |
| 4    | SSH hardening (`PermitRootLogin no`, `PasswordAuthentication no`) |
| 5    | ufw: 22/80/443 |
| 6    | Swap 2 GB |
| 7    | Crea DBs `wp_resolvecore` + `mantisbt` y sus usuarios |
| 8    | Descarga WP core a `/var/www/wp` |
| 9    | Genera `wp-config.php` con SALT desde api.wordpress.org |
| 10   | `rsync` tema + plugin desde `/opt/resolvecore-source` |
| 11   | Descarga MantisBT 2.28.1 a `/var/www/mantis` |
| 12   | Vhosts nginx (con cache estáticos, bloqueo `xmlrpc.php`, `wp-config.php`, `.htaccess`) |
| 13   | Tuning PHP-FPM para 2 GB RAM (`pm = ondemand`, `max_children = 8`, `memory_limit = 256M`) |
| 14   | Let's Encrypt para `<dominio>`, `www.<dominio>`, `mantis.<dominio>` + redirect 80→443 |
| 15   | Cron Mantis (envío emails cada 5 min + schema check diario) |

## 5. Wizards web finales

El script deja todo listo pero los wizards de instalación requieren navegador.

### 5.1 WordPress

URL: `https://<dominio>/wp-admin/install.php`

- Título: `ResolveCore`
- Usuario admin: `franvi` (o el que prefieras — NO uses `admin`)
- Password: generador integrado (guardar)
- Email: tu email administrativo
- Visibilidad motores búsqueda: marcado (hasta lanzar)

Tras login:
- `Apariencia → Temas` → activar **ResolveCore**
- `Plugins` → activar **ResolveCore — MantisBT Integration**
- `Ajustes → Enlaces permanentes` → `Nombre de la entrada` (`/%postname%/`) → Guardar
- `Páginas → Añadir nueva` → crear: `Inicio`, `Contacto` (plantilla `Contacto`), `Docs`, `Changelog`
- `Ajustes → Lectura` → "Página estática" → Inicio
- `Apariencia → Menús` → crear menú con las páginas y asignar a `primary`

### 5.2 MantisBT

URL: `https://mantis.<dominio>/admin/install.php`

| Campo | Valor |
|-------|-------|
| Type of Database     | `MySQL Improved (mysqli)` |
| Hostname             | `localhost` |
| Username             | `mantis_user` |
| Password             | `<MANTIS_DB_PASS>` (paso 4) |
| Database name        | `mantisbt` |
| Admin Username       | `root` *(usuario root del MySQL — solo para crear tablas)* |
| Admin Password       | password root MySQL |
| Crypto Master Salt   | dejar el sugerido (lo guarda en `config_inc.php`) |

Tras `Install/Upgrade Database`:

```bash
# En el VPS — bloquear /admin/ tras instalar
sed -i 's|# location ~\* \^/admin/|location ~* ^/admin/|; s|# deny all; return 404;.*$|deny all; return 404; }|' \
    /etc/nginx/sites-available/mantis.conf
# Más limpio — editar a mano y descomentar el bloque admin
nano /etc/nginx/sites-available/mantis.conf
nginx -t && systemctl reload nginx
```

Login default Mantis: `administrator` / `root`. **Cambiar password inmediato**.

### 5.3 Custom fields ResolveCore

En Mantis:
- Crear proyecto `Incidencias` (debe tener ID `1`)
- O aplicar SQL directo:

```bash
mysql -uroot -p mantisbt < /opt/resolvecore-source/mantisbt/sql/resolvecore-setup.sql
```

Esto crea:
- Categorías (`Soporte técnico`, `Bug`, `Colaboración`, `Licencia`, `General`)
- Custom field `Plataforma` (lista: Windows/Linux/macOS/Android/Otro)
- Custom field `AnyDesk ID` (texto, regex `^[0-9 ]{0,15}$`)

### 5.4 API token + conexión WP↔Mantis

En Mantis, logueado como tu usuario admin:
1. `Mi cuenta` → `API Tokens` → `Crear`
2. Nombre: `wp-rc-mantisbt-prod`
3. **Copiar token (solo se muestra una vez)**

En VPS:

```bash
sudo nano /var/www/wp/wp-config.php
# Sustituir:
#   define( 'RC_MANTIS_TOKEN', 'REPLACE_AFTER_MANTIS_SETUP' );
# Por:
#   define( 'RC_MANTIS_TOKEN', '<TOKEN_COPIADO>' );
```

En WP Admin (`https://<dominio>/wp-admin`):
- `Ajustes → MantisBT` → marcar **Activar integración** → Guardar
- Botón **Verificar conexión con MantisBT** → debe decir "Conexión OK"

## 6. Test end-to-end

1. Abrir `https://<dominio>` en navegador incógnito
2. Click en `Contacta con nosotros` o ir a `#contacto`
3. Rellenar formulario (nombre, email, tipo: Soporte técnico, mensaje)
4. Enviar — debe mostrar `Ticket #N creado`
5. Abrir `https://mantis.<dominio>` → login → ver ticket en bandeja del proyecto `Incidencias`

## 7. Hardening adicional post-despliegue

### 7.1 Auto-renew Let's Encrypt (ya activo)

```bash
systemctl list-timers | grep certbot
certbot renew --dry-run
```

### 7.2 Backups MySQL diarios

```bash
sudo mkdir -p /var/backups/mysql
sudo tee /etc/cron.d/mysql-backup <<'CRON'
0 3 * * * root /usr/bin/mysqldump --all-databases --single-transaction --routines --triggers | gzip > /var/backups/mysql/all-$(date +\%F).sql.gz
0 4 * * 0 root /usr/bin/find /var/backups/mysql -name "all-*.sql.gz" -mtime +30 -delete
CRON
sudo chmod 644 /etc/cron.d/mysql-backup
```

### 7.3 Monitorización básica

```bash
# Logs nginx en vivo
sudo tail -f /var/log/nginx/resolvecore.es.access.log

# Estado PHP-FPM
sudo systemctl status php8.3-fpm

# Errores WP
sudo tail -f /var/www/wp/wp-content/debug.log
```

### 7.4 Snapshot mensual Ionos

Panel Ionos → tu VPS → `Snapshots` → `Crear snapshot manual`. Recomendado antes de cambios mayores o actualizaciones.

## 8. Operación rutinaria

### Actualizar tema/plugin desde local

```powershell
# Windows local — tras editar wordpress/resolvecore-theme/
cd C:\Users\franc\proyecto\ResolvCore
tar -czf theme-update.tar.gz wordpress/resolvecore-theme/ wordpress/plugins/rc-mantisbt/
scp theme-update.tar.gz franvi@<IP>:/tmp/
ssh franvi@<IP> "
    sudo tar -xzf /tmp/theme-update.tar.gz -C /opt/resolvecore-source/ &&
    sudo rsync -a --delete /opt/resolvecore-source/wordpress/resolvecore-theme/  /var/www/wp/wp-content/themes/resolvecore-theme/ &&
    sudo rsync -a --delete /opt/resolvecore-source/wordpress/plugins/rc-mantisbt/ /var/www/wp/wp-content/plugins/rc-mantisbt/ &&
    sudo chown -R www-data:www-data /var/www/wp/wp-content/themes /var/www/wp/wp-content/plugins
"
```

### Re-ejecutar el script (idempotente)

Si añades nuevas configs o quieres reaplicar tuning:

```bash
sudo bash /opt/resolvecore-source/scripts/server/deploy-ionos.sh \
    --domain resolvecore.es --email admin@resolvecore.es \
    --user franvi --ssh-pubkey ""
```

Skip-ea los pasos ya completados.

## 9. Troubleshooting

| Síntoma | Causa probable | Fix |
|---------|----------------|-----|
| `certbot` falla con "DNS problem" | DNS aún no propagado | `dig +short <dominio>` debe devolver IP VPS. Esperar 10-30 min y re-ejecutar `certbot --nginx ...` |
| `502 Bad Gateway` | PHP-FPM caído o socket equivocado | `sudo systemctl restart php8.3-fpm` + verificar `fastcgi_pass unix:/run/php/php8.3-fpm.sock` |
| `Error establishing database connection` (WP) | `WP_DB_PASS` no coincide con `wp-config.php` | Verificar `define('DB_PASSWORD', '...')` |
| `Mantis: 401 / Token inválido` | Token mal copiado o sin permisos | Regenerar token en Mantis → actualizar `RC_MANTIS_TOKEN` |
| Plugin WP "MantisBT no configurado" | constantes no leídas | Verificar `wp-config.php` define las 3: URL, TOKEN, PROJECT_ID |
| `OOM killer` mata MariaDB | 2 GB RAM saturados | `free -m` para confirmar. Ya hay swap 2 GB. Si insiste: subir VPS M (4 GB) |
| WP shows raw PHP on screen | OPcache caché stale | `sudo systemctl restart php8.3-fpm` |

## 10. Coste total real (TFG)

| Año | Concepto | € |
|-----|----------|---|
| 1   | VPS Ionos S (12 meses promo 2,50 €) | 30 |
| 1   | Dominio `.es`                       | 7-10 |
| 1   | Snapshots (opcional)                | 6 |
| **Año 1 total** | | **~43-46 €** |
| 2   | VPS Ionos S (sin promo, ~5-7 €/mes) | 60-84 |
| 2   | Dominio renovación                   | 7-10 |
| **Año 2 total** | | **~67-94 €** |

> Para defensa TFG ASIR el coste año 1 es despreciable. Lo importante es la
> demostración de despliegue end-to-end (nginx, MariaDB, PHP-FPM, certbot,
> integración WP↔REST API, hardening) — todo competencia ASIR pura.

## 11. Referencias cruzadas

- Configuración detallada MantisBT: [`manual-usuario-mantis.md`](manual-usuario-mantis.md)
- Integración WP↔Mantis (código + esquema BD): [`mantis-integration.md`](mantis-integration.md)
- Tutorial WP local (paso previo): [`tutorial-wordpress-manual.md`](tutorial-wordpress-manual.md)
- Backup / migración: [`backup-entorno-web.md`](backup-entorno-web.md)
- Stack tecnológico: [`stack-tecnologico.md`](stack-tecnologico.md)
