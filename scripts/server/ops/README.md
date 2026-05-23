# ResolveCore — scripts/server/ops

Operación día-2 del VPS Ionos (Ubuntu 24.04 + nginx + PHP-FPM 8.3 + MariaDB + WordPress + MantisBT).
Complementa `scripts/server/deploy-ionos.sh` (setup inicial) y `scripts/server/bootstrap-mantis.sh`.

## Contenido

| Fichero | Tipo | Propósito |
|---|---|---|
| `deploy.sh` | script | Deploy continuo (`--target wp\|mantis\|rc-tech\|all`), con lock `flock`. |
| `backup.sh` | script | Dump MariaDB + tarballs WP/Mantis/config + `MANIFEST.txt` (SHA256). Retención 14d. |
| `restore.sh` | script | Restaura un backup. Verifica `MANIFEST.txt` antes. Requiere `--confirm`. |
| `healthcheck.sh` | script | Chequeos LISTEN/HTTP/MariaDB/disco/wp-cron. Email vía `msmtp` con `--alert`. |
| `purge-sessions.sh` | script | Limpia transients WP, sesiones Mantis (>30d) y `rc-tech/tmp` (>1d). |
| `nginx-reload-safe.sh` | script | `nginx -t` + `systemctl reload nginx` + verificación post-reload. |
| `logrotate-resolvecore` | config | Drop-in para `/etc/logrotate.d/`. Rota `/var/log/resolvecore/*.log` 30d. |
| `cron-resolvecore` | config | Drop-in para `/etc/cron.d/`. 3 entradas: backup / healthcheck / purge. |

## Instalación en el VPS

```bash
# 1) Copiar scripts al VPS (no se sirven desde el repo del WP)
sudo mkdir -p /opt/resolvecore/ops /var/log/resolvecore /etc/resolvecore
sudo cp scripts/server/ops/*.sh                     /opt/resolvecore/ops/
sudo cp scripts/server/ops/logrotate-resolvecore    /opt/resolvecore/ops/
sudo cp scripts/server/ops/cron-resolvecore         /opt/resolvecore/ops/
sudo chmod +x /opt/resolvecore/ops/*.sh

# 2) Symlinks de los drop-ins de sistema
sudo ln -sf /opt/resolvecore/ops/logrotate-resolvecore  /etc/logrotate.d/resolvecore
sudo ln -sf /opt/resolvecore/ops/cron-resolvecore       /etc/cron.d/resolvecore

# 3) Entorno (variables que leen los scripts)
sudo tee /etc/resolvecore/env >/dev/null <<EOF
RC_DOMAIN=resolvecore.es
WP_DIR=/var/www/wp
MANTIS_DIR=/var/www/mantis
BUILDS_DIR=/var/cache/resolvecore/builds
ALERT_TO=fvidalmateo@gmail.com
EOF
sudo chmod 644 /etc/resolvecore/env

# 4) Credenciales MariaDB para backup/restore/healthcheck
sudo tee /etc/resolvecore/mysql-backup.cnf >/dev/null <<EOF
[client]
user=root
password=<PEGAR_PASSWORD_DE_/root/resolvecore-credentials.txt>
EOF
sudo chmod 600 /etc/resolvecore/mysql-backup.cnf
sudo chown root:root /etc/resolvecore/mysql-backup.cnf
```

## Uso manual

```bash
sudo /opt/resolvecore/ops/backup.sh
sudo /opt/resolvecore/ops/healthcheck.sh
sudo /opt/resolvecore/ops/deploy.sh --target rc-tech
sudo /opt/resolvecore/ops/restore.sh --from /var/backups/resolvecore/<ts> --target wp --confirm
```

## Logs

Cada script escribe a `/var/log/resolvecore/<script>.log` (stdout + stderr).
`logrotate-resolvecore` los rota a diario, comprimidos, 30 ficheros de retención.

## Limitaciones conocidas

- **Sin backup off-site**: retención solo local (`/var/backups/resolvecore/`, 14d). Para producción real, añadir `restic` → Backblaze B2 (follow-up).
- **`deploy.sh --target wp`**: requiere que `/var/www/wp` sea un repo git. El despliegue inicial vía `deploy-ionos.sh` usa `rsync`; convertir a git antes de usar deploy.sh sobre WP.
- **`deploy.sh --target mantis`**: schema upgrades de Mantis no se automatizan (requieren admin interactivo en `/admin/install.php`).
- **`healthcheck.sh`**: depende de `msmtp` configurado (vía `scripts/server/setup-mail-dkim.sh`) para enviar alertas.
