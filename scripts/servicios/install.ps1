#Requires -Version 5.1
<#
.SYNOPSIS
    ResolveCore - Bootstrap de servicios adicionales para Windows

.DESCRIPTION
    Descarga e instala todas las dependencias necesarias para los servicios
    adicionales de ResolveCore (congelacion, clonacion, kit de implantacion).
    Ejecutar como Administrador.

    Uso rapido (desde PowerShell Admin):
      irm https://resolvecore.website/install.ps1 | iex

.NOTES
    Exit codes: 0 OK  1 Error  2 Requiere reinicio

    Autor:   Francisco Vidal Mateo (GitHub: Haplee)
    Versión: 1.0.0
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:needsReboot = $false
$script:isFile = $MyInvocation.ScriptName -ne ''

function Write-Step($n, $m) { Write-Host "[$n] $m" -ForegroundColor Cyan }
function Write-Ok($m)       { Write-Host "[OK] $m" -ForegroundColor Green }
function Write-Warn($m)     { Write-Host "[!]  $m" -ForegroundColor Yellow }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warn "Ejecuta como Administrador (clic derecho -> Ejecutar como administrador)"
    if ($script:isFile) { exit 1 } else { return }
}

Write-Host ""
Write-Host "  =======================================================" -ForegroundColor Cyan
Write-Host "   ResolveCore - Instalacion de servicios adicionales     " -ForegroundColor Cyan
Write-Host "  =======================================================" -ForegroundColor Cyan
Write-Host ""

# -- 1. PowerShell ExecutionPolicy ----------------------------------------
Write-Step 1 "Verificando ExecutionPolicy..."
$policy = Get-ExecutionPolicy
if ($policy -eq 'Restricted') {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Ok "ExecutionPolicy -> RemoteSigned"
} else {
    Write-Ok "ExecutionPolicy ya es $policy"
}

# -- 2. Chocolatey (si no hay gestor de paquetes) -------------------------
Write-Step 2 "Verificando gestor de paquetes..."
$hasChoco = Get-Command choco -ErrorAction SilentlyContinue
$hasScoop = Get-Command scoop -ErrorAction SilentlyContinue
if (-not $hasChoco -and -not $hasScoop) {
    # Preferir winget (firmado, viene con Windows 10/11) sobre descargar y
    # ejecutar un script remoto con Invoke-Expression (riesgo de RCE si la URL
    # o el CDN se ven comprometidos).
    $hasWinget = Get-Command winget -ErrorAction SilentlyContinue
    if ($hasWinget) {
        Write-Step 2 "Instalando Chocolatey via winget..."
        try {
            winget install --id Chocolatey.Chocolatey --silent --accept-source-agreements --accept-package-agreements
            $env:Path += ";$env:ALLUSERSPROFILE\chocolatey\bin"
            Write-Ok "Chocolatey instalado (winget)"
        } catch {
            Write-Warn "No se pudo instalar Chocolatey via winget: $($_.Exception.Message)"
        }
    } else {
        Write-Warn "winget no disponible. Instala Chocolatey manualmente desde https://chocolatey.org/install (verifica el hash del instalador antes de ejecutarlo)."
    }
} else {
    Write-Ok "Gestor de paquetes disponible: $(if ($hasScoop) {'scoop'} else {'chocolatey'})"
}

# -- 3. WSL (para scripts de clonacion Bash) ------------------------------
Write-Step 3 "Verificando WSL..."
$wsl = Get-Command wsl -ErrorAction SilentlyContinue
if (-not $wsl) {
    Write-Step 3 "Instalando WSL (requiere reinicio al terminar)..."
    try {
        wsl --install --no-distribution 2>&1 | Out-Null
        Write-Ok "WSL instalado - REINICIA el equipo cuando termine este script"
        $script:needsReboot = $true
    } catch {
        Write-Warn "WSL no se pudo instalar automaticamente. Hazlo manualmente: wsl --install"
    }
} else {
    Write-Ok "WSL disponible"
    # Instalar jq dentro de WSL para clonacion
    Write-Step 3 "Instalando jq en WSL..."
    try {
        $bashCmd = 'command -v jq >/dev/null 2>&1 || (sudo apt-get update -qq && sudo apt-get install -y -qq jq)'
        wsl -- bash -c $bashCmd 2>&1 | Out-Null
        Write-Ok "jq disponible en WSL"
    } catch {
        Write-Warn "No se pudo instalar jq en WSL"
    }
}

# -- 4. AnyDesk portable --------------------------------------------------
Write-Step 4 "Verificando AnyDesk portable..."
$baseDir = if ($PSScriptRoot) { $PSScriptRoot } else { Join-Path $env:USERPROFILE 'ResolveCore' }
$anyDeskDest = Join-Path $baseDir 'kit\anydesk.exe'
if (-not (Test-Path $anyDeskDest)) {
    Write-Step 4 "Descargando AnyDesk portable..."
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path $anyDeskDest) | Out-Null
        Invoke-WebRequest -Uri 'https://download.anydesk.com/AnyDesk.exe' `
            -OutFile $anyDeskDest -UseBasicParsing -ErrorAction Stop
        Write-Ok "AnyDesk portable -> $anyDeskDest"
    } catch {
        Write-Warn "No se pudo descargar AnyDesk: $($_.Exception.Message)"
    }
} else {
    Write-Ok "AnyDesk portable ya existe"
}

# -- Resumen --------------------------------------------------------------
Write-Host ""
Write-Host "  =======================================================" -ForegroundColor Cyan
Write-Host "   Instalacion completada"                                   -ForegroundColor Cyan
Write-Host "  =======================================================" -ForegroundColor Cyan
Write-Host ""

if ($script:needsReboot) {
    Write-Warn "REINICIO REQUERIDO para completar la instalacion."
    Write-Host "  Tras reiniciar, ejecuta: .\ResolveCore.ps1 -> opcion 6 SERVICIOS" -ForegroundColor Gray
    if ($script:isFile) { exit 2 }
} else {
    Write-Ok "Todo listo. Ejecuta: .\ResolveCore.ps1 -> opcion 6 SERVICIOS"
    if ($script:isFile) { exit 0 }
}
