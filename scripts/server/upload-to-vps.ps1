# =============================================================================
# ResolveCore — Subir código del repo al VPS Ionos
#
# Uso (desde C:\Users\franc\proyecto\ResolvCore en Windows local):
#   .\scripts\server\upload-to-vps.ps1 -Host <IP_O_DOMINIO> -User root
#   .\scripts\server\upload-to-vps.ps1 -Host resolvecore.es -User franvi
#
# Empaqueta solo lo necesario (excluye wp/, .git, mantisbt-2.28.1/, etc) y lo
# extrae en /opt/resolvecore-source del VPS.
# =============================================================================

#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$VpsHost,
    [Parameter(Mandatory)] [string]$User,
    [string]$RemotePath = '/opt/resolvecore-source',
    [string]$Tarball    = 'resolvecore-src.tar.gz'
)

$ErrorActionPreference = 'Stop'

# Validar tar + scp + ssh
foreach ($cmd in 'tar','scp','ssh') {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "Falta '$cmd'. Instala OpenSSH client: Configuración → Aplicaciones → Características opcionales"
    }
}

# Empaquetar
$excludes = @(
    '--exclude=./wp',
    '--exclude=./node_modules',
    '--exclude=./.git',
    '--exclude=./mantisbt-2.28.1',
    '--exclude=./scripts/diagnosticos',
    '--exclude=./php.ini',
    '--exclude=*.zip'
)

Write-Host "[1/3] Empaquetando..." -ForegroundColor Cyan
tar @excludes -czf $Tarball wordpress/ mantisbt/ scripts/ docs/ reports/ vulnerabilities/ assets/ 2>&1 | Out-Null
$size = (Get-Item $Tarball).Length / 1MB
Write-Host "      $Tarball — $([math]::Round($size,2)) MB" -ForegroundColor Gray

# Subir
Write-Host "[2/3] Subiendo a $User@${VpsHost}:/tmp/..." -ForegroundColor Cyan
scp $Tarball "${User}@${VpsHost}:/tmp/$Tarball"
if ($LASTEXITCODE -ne 0) { throw "scp falló (exit $LASTEXITCODE)" }

# Extraer
Write-Host "[3/3] Extrayendo en $RemotePath..." -ForegroundColor Cyan
$sudo = if ($User -eq 'root') { '' } else { 'sudo ' }
$remoteCmd = @"
${sudo}mkdir -p $RemotePath &&
${sudo}tar -xzf /tmp/$Tarball -C $RemotePath &&
${sudo}rm /tmp/$Tarball &&
${sudo}chown -R ${User}:${User} $RemotePath &&
echo 'OK — contenido:' &&
ls -la $RemotePath
"@
ssh "${User}@${VpsHost}" $remoteCmd
if ($LASTEXITCODE -ne 0) { throw "ssh remote failed" }

Remove-Item $Tarball -Force
Write-Host ""
Write-Host "LISTO. Próximo paso en el VPS:" -ForegroundColor Green
Write-Host "  ssh ${User}@${VpsHost}" -ForegroundColor Yellow
Write-Host "  ${sudo}bash $RemotePath/scripts/server/deploy-ionos.sh \" -ForegroundColor Yellow
Write-Host "      --domain TUDOMINIO.es \" -ForegroundColor Yellow
Write-Host "      --email  admin@TUDOMINIO.es \" -ForegroundColor Yellow
Write-Host "      --user   franvi \" -ForegroundColor Yellow
$_pubkeyPath = "$env:USERPROFILE\.ssh\id_ed25519.pub"
$_pubkey     = if (Test-Path $_pubkeyPath) { (Get-Content $_pubkeyPath -Raw).Trim() } else { 'ssh-ed25519 AAAA...user@host' }
Write-Host "      --ssh-pubkey `"$_pubkey`"" -ForegroundColor Yellow
