#Requires -Version 7.0
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    ResolveCore — Setup automatico de dependencias para Windows 10/11
    Maquina fisica del tecnico

.DESCRIPTION
    Instala y configura el stack completo de ResolveCore en Windows:
    - Chocolatey (gestor de paquetes)
    - PHP 8.2 + Nginx + MariaDB + Composer
    - WordPress (via WP-CLI)
    - MantisBT
    - wkhtmltopdf (generacion PDF)
    - AnyDesk
    - Git + configuracion

.PARAMETER Help
    Muestra ayuda y sale.

.EXAMPLE
    # Ejecutar como Administrador en PowerShell 7:
    pwsh -ExecutionPolicy Bypass -File setup.ps1
#>

[CmdletBinding()]
param(
    [Alias('h')][switch]$Help
)

if ($Help) {
    @"
NAME
    setup.ps1 - Setup automatico del stack ResolveCore en Windows 10/11

SYNOPSIS
    pwsh -ExecutionPolicy Bypass -File setup.ps1 [-Help]

DESCRIPTION
    Instala y configura el stack completo de ResolveCore en una instalacion
    limpia de Windows. Aprovisiona la maquina fisica del tecnico con todos
    los servicios necesarios para operar.

    Componentes instalados:
        - Chocolatey (gestor de paquetes)
        - PHP 8.2 + Nginx + MariaDB + Composer
        - WordPress (via WP-CLI)
        - MantisBT
        - wkhtmltopdf (generacion PDF)
        - AnyDesk
        - Git + configuracion

PARAMETERS
    -Help, -h                   Muestra esta ayuda y sale.

REQUISITOS
    - PowerShell 7+ (#Requires -Version 7.0).
    - Consola Administrador.
    - Conexion a internet.
    - Maquina recien instalada (no ejecutar sobre sistema en uso).

EXAMPLES
    pwsh -ExecutionPolicy Bypass -File setup.ps1
    pwsh -ExecutionPolicy Bypass -File setup.ps1 -Help

EXIT CODES
    0    Setup completado.
    1    Error fatal (cualquier paso falla con Write-Fail).

ATENCION
    Modifica la configuracion del sistema. Usar solo en maquina recien
    instalada para evitar conflictos con servicios existentes.
"@ | Write-Host
    exit 0
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================
# COLORES / HELPERS
# ============================================================
function Write-Ok($msg)   { Write-Host "[✓] $msg" -ForegroundColor Green }
function Write-Info($msg) { Write-Host "[→] $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "[⚠] $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "[✗] $msg" -ForegroundColor Red; exit 1 }

# ============================================================
# BANNER
# ============================================================
Clear-Host
Write-Host @"

  ____                 _       ____
 |  _ \ ___  ___  ___ | |_   / ___|___  _ __ ___
 | |_) / _ \/ __|/ _ \| \ \ / /  / _ \| '__/ _ \
 |  _ <  __/\__ \ (_) | |\ V /  | (_) | | |  __/
 |_| \_\___||___/\___/|_| \_/    \___/|_|  \___|

  SO Tecnico Windows — Instalacion automatica
"@ -ForegroundColor Cyan

Write-Host "Stack: Nginx · PHP 8.2 · MariaDB · WordPress · MantisBT · AnyDesk`n" -ForegroundColor Gray
$confirm = Read-Host "¿Continuar? [s/N]"
if ($confirm -notmatch '^[sS]$') { Write-Host "Cancelado."; exit 0 }

# ============================================================
# VARIABLES
# ============================================================
$RC_BASE     = "C:\ResolveCore"
$NGINX_DIR   = "$RC_BASE\nginx"
$PHP_DIR     = "$RC_BASE\php"
$MARIADB_DIR = "$RC_BASE\mariadb"
$WP_DIR      = "$RC_BASE\www\wordpress"
$MANTIS_DIR  = "$RC_BASE\www\mantis"
$SCRIPTS_DIR = "$RC_BASE\scripts"
$LOG_FILE    = "$RC_BASE\install.log"
$CREDS_FILE  = "$RC_BASE\credenciales.txt"

$MANTIS_VER  = "2.27.0"

# Contrasenas aleatorias
function New-Password { [System.Convert]::ToBase64String((1..24 | ForEach-Object { [byte](Get-Random -Max 256) })) -replace '[^a-zA-Z0-9]','' | Select-Object -First 1 }
$DB_ROOT_PASS   = (New-Guid).ToString().Replace('-','').Substring(0,20)
$DB_WP_PASS     = (New-Guid).ToString().Replace('-','').Substring(0,20)
$DB_MANTIS_PASS = (New-Guid).ToString().Replace('-','').Substring(0,20)
$WP_ADMIN_PASS  = (New-Guid).ToString().Replace('-','').Substring(0,16)

New-Item -ItemType Directory -Force -Path $RC_BASE, "$RC_BASE\www", $SCRIPTS_DIR | Out-Null
Start-Transcript -Path $LOG_FILE -Append | Out-Null

# ============================================================
# 1. CHOCOLATEY
# ============================================================
Write-Info "Instalando Chocolatey..."
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:PATH += ";$env:ALLUSERSPROFILE\chocolatey\bin"
}
Write-Ok "Chocolatey listo"

# ============================================================
# 2. DEPENDENCIAS BASE
# ============================================================
Write-Info "Instalando dependencias via Chocolatey..."
$packages = @(
    'git',
    'curl',
    'wget',
    '7zip',
    'nssm'       # Non-Sucking Service Manager (para servicios Windows)
)
foreach ($pkg in $packages) {
    Write-Info "  → $pkg"
    choco install $pkg -y --no-progress 2>&1 | Out-Null
}
Write-Ok "Dependencias base instaladas"

# ============================================================
# 3. PHP 8.2
# ============================================================
Write-Info "Instalando PHP 8.2..."
choco install php --version=8.2.12 -y --no-progress 2>&1 | Out-Null
$env:PATH += ";C:\tools\php82"

# Extensions necesarias para WordPress + MantisBT
$phpIni = "C:\tools\php82\php.ini"
if (Test-Path "C:\tools\php82\php.ini-production") {
    Copy-Item "C:\tools\php82\php.ini-production" $phpIni -Force
}
$extensions = @('curl','gd','mbstring','mysqli','openssl','pdo_mysql','xml','zip','intl','soap','bcmath')
foreach ($ext in $extensions) {
    (Get-Content $phpIni) -replace ";extension=$ext", "extension=$ext" | Set-Content $phpIni
}
Add-Content $phpIni "`nupload_max_filesize=64M`npost_max_size=64M`nmemory_limit=256M`nmax_execution_time=120"
Write-Ok "PHP 8.2 configurado"

# ============================================================
# 4. NGINX
# ============================================================
Write-Info "Instalando Nginx..."
choco install nginx -y --no-progress 2>&1 | Out-Null

# Configurar nginx para WordPress + MantisBT
$nginxConf = @"
events { worker_connections 1024; }
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile      on;
    keepalive_timeout 65;

    server {
        listen       80;
        server_name  resolvecore.local localhost;
        root         $($WP_DIR -replace '\\','/');
        index        index.php index.html;
        client_max_body_size 64M;

        location / {
            try_files `$uri `$uri/ /index.php?`$args;
        }

        location /mantis/ {
            alias $($MANTIS_DIR -replace '\\','/')/;
            index index.php;
            location ~ \.php$ {
                fastcgi_pass   127.0.0.1:9000;
                fastcgi_param  SCRIPT_FILENAME `$request_filename;
                include        fastcgi_params;
            }
        }

        location ~ \.php$ {
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME `$document_root`$fastcgi_script_name;
            include        fastcgi_params;
        }

        location ~ /\.ht { deny all; }
    }
}
"@
Set-Content "C:\tools\nginx\conf\nginx.conf" $nginxConf

# Registrar como servicio Windows
nssm install ResolveCore-Nginx "C:\tools\nginx\nginx.exe" 2>&1 | Out-Null
nssm set ResolveCore-Nginx AppDirectory "C:\tools\nginx" 2>&1 | Out-Null
Start-Service ResolveCore-Nginx -ErrorAction SilentlyContinue
Write-Ok "Nginx instalado como servicio Windows"

# ============================================================
# 5. MARIADB
# ============================================================
Write-Info "Instalando MariaDB..."
choco install mariadb -y --no-progress 2>&1 | Out-Null
$env:PATH += ";C:\Program Files\MariaDB 10.11\bin"

Start-Service MySQL -ErrorAction SilentlyContinue

# Esperar a que MariaDB arranque
Start-Sleep 5

# Crear bases de datos
$sqlSetup = @"
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASS';
CREATE DATABASE IF NOT EXISTS resolvecore_wp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'rc_wp'@'localhost' IDENTIFIED BY '$DB_WP_PASS';
GRANT ALL PRIVILEGES ON resolvecore_wp.* TO 'rc_wp'@'localhost';
CREATE DATABASE IF NOT EXISTS resolvecore_mantis CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'rc_mantis'@'localhost' IDENTIFIED BY '$DB_MANTIS_PASS';
GRANT SELECT,INSERT,UPDATE,DELETE,INDEX,CREATE,ALTER,DROP ON resolvecore_mantis.* TO 'rc_mantis'@'localhost';
FLUSH PRIVILEGES;
"@
$sqlSetup | mysql -u root 2>&1 | Out-Null
Write-Ok "MariaDB configurado con bases de datos ResolveCore"

# ============================================================
# 6. WORDPRESS
# ============================================================
Write-Info "Instalando WordPress..."
New-Item -ItemType Directory -Force -Path $WP_DIR | Out-Null

# WP-CLI
$wpCliPath = "$RC_BASE\wp-cli.phar"
Invoke-WebRequest "https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar" -OutFile $wpCliPath

function Invoke-WpCli($args) {
    php $wpCliPath @($args) --allow-root 2>&1
}

Invoke-WpCli @("core", "download", "--path=$WP_DIR", "--locale=es_ES")
Invoke-WpCli @("config", "create", "--path=$WP_DIR",
    "--dbname=resolvecore_wp", "--dbuser=rc_wp",
    "--dbpass=$DB_WP_PASS", "--dbhost=localhost")
Invoke-WpCli @("core", "install", "--path=$WP_DIR",
    "--url=http://resolvecore.local",
    "--title=ResolveCore",
    "--admin_user=admin",
    "--admin_password=$WP_ADMIN_PASS",
    "--admin_email=admin@resolvecore.local",
    "--skip-email")
Write-Ok "WordPress instalado"

# ============================================================
# 7. MANTISBT
# ============================================================
Write-Info "Instalando MantisBT $MANTIS_VER..."
New-Item -ItemType Directory -Force -Path $MANTIS_DIR | Out-Null
$mantisTar = "$env:TEMP\mantisbt-$MANTIS_VER.tar.gz"
Invoke-WebRequest "https://github.com/mantisbt/mantisbt/releases/download/release-$MANTIS_VER/mantisbt-$MANTIS_VER.tar.gz" -OutFile $mantisTar
7z x $mantisTar -o"$env:TEMP" -y | Out-Null
7z x "$env:TEMP\mantisbt-$MANTIS_VER.tar" -o"$env:TEMP\mantisbt-extracted" -y | Out-Null
Copy-Item "$env:TEMP\mantisbt-extracted\mantisbt-$MANTIS_VER\*" $MANTIS_DIR -Recurse -Force
New-Item -ItemType Directory -Force -Path "$MANTIS_DIR\uploads" | Out-Null

Set-Content "$MANTIS_DIR\config\config_inc.php" @"
<?php
`$g_hostname               = 'localhost';
`$g_db_type                = 'mysqli';
`$g_database_name          = 'resolvecore_mantis';
`$g_db_username            = 'rc_mantis';
`$g_db_password            = '$DB_MANTIS_PASS';
`$g_default_language       = 'spanish';
`$g_default_timezone       = 'Europe/Madrid';
`$g_path                   = 'http://resolvecore.local/mantis/';
`$g_short_path             = '/mantis/';
`$g_allow_signup           = OFF;
`$g_api_enabled            = ON;
"@
Write-Ok "MantisBT instalado"

# ============================================================
# 8. WKHTMLTOPDF
# ============================================================
Write-Info "Instalando wkhtmltopdf..."
choco install wkhtmltopdf -y --no-progress 2>&1 | Out-Null
Write-Ok "wkhtmltopdf instalado"

# ============================================================
# 9. ANYDESK
# ============================================================
Write-Info "Instalando AnyDesk..."
choco install anydesk -y --no-progress 2>&1 | Out-Null
Write-Ok "AnyDesk instalado"

# ============================================================
# 10. SCRIPTS RESOLVECORE
# ============================================================
Write-Info "Clonando scripts ResolveCore..."
try {
    git clone --depth=1 "https://github.com/Haplee/ResolveCore.git" "$env:TEMP\resolvecore-src" 2>&1 | Out-Null
    Copy-Item "$env:TEMP\resolvecore-src\scripts\*" $SCRIPTS_DIR -Recurse -Force
    Remove-Item "$env:TEMP\resolvecore-src" -Recurse -Force
    Write-Ok "Scripts instalados en $SCRIPTS_DIR"
} catch {
    Write-Warn "No se pudo clonar desde GitHub. Copia los scripts manualmente en $SCRIPTS_DIR"
}

# Agregar al PATH del sistema
$currentPath = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
if ($currentPath -notlike "*$SCRIPTS_DIR*") {
    [System.Environment]::SetEnvironmentVariable('PATH', "$currentPath;$SCRIPTS_DIR", 'Machine')
}

# ============================================================
# 11. HOSTS LOCAL
# ============================================================
$hostsPath = "C:\Windows\System32\drivers\etc\hosts"
if (-not (Select-String -Path $hostsPath -Pattern "resolvecore.local" -Quiet)) {
    Add-Content $hostsPath "`n127.0.0.1   resolvecore.local"
}
Write-Ok "Dominio local: http://resolvecore.local"

# ============================================================
# GUARDAR CREDENCIALES
# ============================================================
Set-Content $CREDS_FILE @"
==================================================
  ResolveCore — Credenciales de instalacion
  Generadas: $(Get-Date)
==================================================

--- MariaDB ---
Root password:        $DB_ROOT_PASS

WordPress DB:
  Base de datos:      resolvecore_wp
  Usuario:            rc_wp
  Contrasena:         $DB_WP_PASS

MantisBT DB:
  Base de datos:      resolvecore_mantis
  Usuario:            rc_mantis
  Contrasena:         $DB_MANTIS_PASS

--- WordPress ---
URL:                  http://resolvecore.local
Admin usuario:        admin
Admin contrasena:     $WP_ADMIN_PASS

--- MantisBT ---
URL:                  http://resolvecore.local/mantis/
  (completar instalacion abriendo la URL en el navegador)

==================================================
GUARDA ESTE ARCHIVO EN LUGAR SEGURO.
==================================================
"@

# ============================================================
# RESUMEN
# ============================================================
Stop-Transcript | Out-Null
Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host "  ResolveCore instalado correctamente" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host ""
Write-Ok "WordPress:   http://resolvecore.local"
Write-Ok "MantisBT:    http://resolvecore.local/mantis/"
Write-Ok "Credenciales: $CREDS_FILE"
Write-Host ""
Write-Warn "PROXIMOS PASOS:"
Write-Host "  1. Abre http://resolvecore.local/mantis/ → completa el wizard"
Write-Host "  2. Abre http://resolvecore.local/wp-admin/ → instala el tema ResolveCore"
Write-Host "  3. En WP: Plugins → rc-mantisbt → configura URL + API token MantisBT"
Write-Host "  4. Reinicia el equipo para que los servicios arranquen correctamente"
Write-Host ""
Write-Info "Log completo: $LOG_FILE"
