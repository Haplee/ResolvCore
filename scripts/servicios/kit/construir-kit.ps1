#Requires -Version 5.1
<#
.SYNOPSIS
    ResolveCore - Constructor del kit de implantacion en cliente

.DESCRIPTION
    Empaqueta el kit de implantacion en cliente: una carpeta autocontenida con
    AnyDesk portable (freeware), los scripts de diagnostico y un README.

    Estructura:
      resolvecore-kit/
      |-- anydesk-portable.exe
      |-- README-cliente.txt
      \-- scripts/
          |-- diagnostico-windows.ps1
          \-- diagnostico-linux.sh

    Salida: resolvecore-kit.zip empaquetado con Compress-Archive (built-in PS).

.PARAMETER AnyDeskPath
    Ruta al ejecutable AnyDesk portable.
    Default: ./anydesk.exe en el directorio actual.

.PARAMETER OutputDir
    Directorio donde se generara resolvecore-kit/ y resolvecore-kit.zip
    (default: ./dist).

.PARAMETER ContactoTecnico
    Nombre + telefono / email del tecnico para el README del cliente.

.PARAMETER IncludeScripts
    Incluir los scripts de diagnostico (default: $true).

.EXAMPLE
    .\construir-kit.ps1 -AnyDeskPath .\anydesk.exe
    .\construir-kit.ps1 -AnyDeskPath .\anydesk.exe -OutputDir C:\kits -ContactoTecnico "Fran Vidal - tecnicos@resolvecore.website"

.NOTES
    Exit codes:
      0  ok
      1  error de empaquetado
      2  AnyDesk portable no encontrado
#>

[CmdletBinding()]
param(
    [string]$AnyDeskPath = './anydesk.exe',
    [Alias('O')][string]$OutputDir = './dist',
    [string]$ContactoTecnico = 'tecnicos@resolvecore.website',
    [bool]$IncludeScripts = $true,
    [Alias('h')][switch]$Help
)

if ($Help) { Get-Help $PSCommandPath -Full; exit 0 }

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info($m) { Write-Host "[->] $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "[OK] $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[!]  $m" -ForegroundColor Yellow }
function Write-Fail($m) { Write-Host "[X]  $m" -ForegroundColor Red; exit 1 }

# ── Validar AnyDesk ─────────────────────────────────────────────────────────
if (-not (Test-Path $AnyDeskPath)) {
    Write-Info "AnyDesk portable no encontrado. Descargando desde anydesk.com..."
    $anyDeskDir = Split-Path $AnyDeskPath -Parent
    if ($anyDeskDir -and -not (Test-Path $anyDeskDir)) {
        New-Item -ItemType Directory -Force -Path $anyDeskDir | Out-Null
    }
    try {
        Invoke-WebRequest -Uri 'https://download.anydesk.com/AnyDesk.exe' `
            -OutFile $AnyDeskPath -UseBasicParsing -ErrorAction Stop
        Write-Ok "AnyDesk portable descargado: $AnyDeskPath"
    } catch {
        Write-Warn "No se pudo descargar AnyDesk: $($_.Exception.Message)"
        Write-Host "  Descarga manual: https://anydesk.com/downloads/windows (elige Portable)" -ForegroundColor Gray
        exit 2
    }
}

# ── Ubicacion del repo (un nivel arriba de scripts/) ────────────────────────
$repoRoot   = Resolve-Path (Join-Path $PSScriptRoot '../../..') | Select-Object -ExpandProperty Path
$diagWin    = Join-Path $repoRoot 'scripts/windows/diagnostico.ps1'
$diagLinux  = Join-Path $repoRoot 'scripts/linux/diagnostico.sh'

# ── Preparar arbol del kit ──────────────────────────────────────────────────
$kitName   = 'resolvecore-kit'
$outDirAbs = (New-Item -ItemType Directory -Force -Path $OutputDir).FullName
$kitDir    = Join-Path $outDirAbs $kitName

if (Test-Path $kitDir) {
    Write-Info "Limpiando $kitDir anterior..."
    Remove-Item -Recurse -Force $kitDir
}
New-Item -ItemType Directory -Force -Path $kitDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $kitDir 'scripts') | Out-Null

# ── Copiar AnyDesk ──────────────────────────────────────────────────────────
$anyDeskDest = Join-Path $kitDir 'anydesk-portable.exe'
Copy-Item $AnyDeskPath $anyDeskDest
Write-Ok "AnyDesk portable copiado"

# ── Copiar scripts ──────────────────────────────────────────────────────────
if ($IncludeScripts) {
    if (-not (Test-Path $diagWin)) {
        Write-Fail "Script de diagnostico Windows no encontrado: $diagWin"
    }
    Copy-Item $diagWin (Join-Path $kitDir 'scripts/diagnostico-windows.ps1')
    Write-Ok "diagnostico-windows.ps1 copiado"

    if (-not (Test-Path $diagLinux)) {
        Write-Fail "Script de diagnostico Linux no encontrado: $diagLinux"
    }
    Copy-Item $diagLinux (Join-Path $kitDir 'scripts/diagnostico-linux.sh')
    Write-Ok "diagnostico-linux.sh copiado"
}

# ── README-cliente.txt ──────────────────────────────────────────────────────
$readmePath = Join-Path $kitDir 'README-cliente.txt'
$fechaGen   = Get-Date -Format 'yyyy-MM-dd HH:mm'

$readme = @"
=============================================================
 RESOLVECORE - KIT DE SOPORTE TECNICO PARA CLIENTES
=============================================================
 Generado: $fechaGen
 Contacto tecnico: $ContactoTecnico

CONTENIDO DEL KIT
-----------------
  - anydesk-portable.exe   Acceso remoto del tecnico (no instala, ejecuta y ya).
  - scripts/               Herramientas de diagnostico opcional.
    - diagnostico-windows.ps1
    - diagnostico-linux.sh
  - README-cliente.txt     Este fichero.

COMO USAR
---------
 1. CONEXION REMOTA con el tecnico:
    - Haz doble clic en anydesk-portable.exe (Windows) o en su equivalente Linux.
    - Aparecera tu ID AnyDesk (numero de 9-10 digitos).
    - Comparte ese ID con el tecnico por telefono o email.
    - Cuando el tecnico solicite conectar, ACEPTA la peticion.
    - Para finalizar: cierra la ventana de AnyDesk.

 2. DIAGNOSTICO automatico (si el tecnico te lo pide):
    Windows:
      - Clic derecho sobre diagnostico-windows.ps1 -> Ejecutar con PowerShell.
      - Si pide permisos de administrador, acepta.
    Linux:
      - Abre terminal en la carpeta scripts/
      - Ejecuta: bash diagnostico-linux.sh

    El script genera un informe JSON + HTML que el tecnico necesitara.

PRIVACIDAD
----------
  - AnyDesk solo concede acceso CUANDO TU ACEPTAS la peticion.
  - Los scripts NO envian datos por internet — solo generan ficheros locales.
  - El tecnico se ajusta al RGPD: tus datos se tratan unicamente para resolver
    tu incidencia.

CONTACTO
--------
  $ContactoTecnico
  https://github.com/Haplee/ResolveCore

=============================================================
 ResolveCore - Solucion a tus problemas informaticos.
=============================================================
"@
Set-Content -Path $readmePath -Value $readme -Encoding UTF8
Write-Ok "README-cliente.txt creado"

# ── MANIFEST.txt ─────────────────────────────────────────────────────────────
$manifestPath = Join-Path $kitDir 'MANIFEST.txt'
$anyDeskVer = try { (Get-Item $AnyDeskPath).VersionInfo.FileVersion } catch { 'desconocida' }
$diagWinVer  = try { (Select-String '#Requires\|^# Version' $diagWin | Select-Object -First 1).Line } catch { '' }
$manifest = @"
RESOLVECORE KIT — MANIFEST
==========================
Generado:              $fechaGen
Script kit (version):  1.0.0
AnyDesk portable:      $anyDeskVer
diagnostico-windows:   $diagWinVer
diagnostico-linux:     (ver cabecera del script)
Contacto tecnico:      $ContactoTecnico

Checksums SHA256:
"@
Get-ChildItem -Recurse $kitDir -File | Where-Object { $_.Name -ne 'MANIFEST.txt' } | ForEach-Object {
    $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
    $rel  = $_.FullName.Replace($kitDir + '\','').Replace('\','/')
    $manifest += "`n  $hash  $rel"
}
Set-Content -Path $manifestPath -Value $manifest -Encoding UTF8
Write-Ok "MANIFEST.txt generado"

# ── Empaquetar ZIP ──────────────────────────────────────────────────────────
$zipPath = Join-Path $outDirAbs "$kitName.zip"
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }

try {
    Compress-Archive -Path "$kitDir/*" -DestinationPath $zipPath -CompressionLevel Optimal
    Write-Ok "Kit empaquetado: $zipPath"
} catch {
    Write-Fail "Error empaquetando: $($_.Exception.Message)"
}

# ── Resumen ─────────────────────────────────────────────────────────────────
$zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
Write-Host ""
Write-Host "  =========================================" -ForegroundColor Cyan
Write-Host "    Kit listo"                                -ForegroundColor Cyan
Write-Host "  =========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Directorio: $kitDir"
Write-Host "  ZIP:        $zipPath ($zipSize MB)"
Write-Host ""
Write-Host "  Entrega al cliente:" -ForegroundColor Yellow
Write-Host "    - Email con $kitName.zip adjunto"
Write-Host "    - Pendrive con la carpeta $kitName/"
Write-Host ""

exit 0
