#Requires -Version 5.1
<#
.SYNOPSIS
    ResolveCore - Setup del entorno del tecnico (Windows)

.DESCRIPTION
    Instala todas las dependencias para ejecutar los scripts de diagnóstico,
    optimización y análisis de vulnerabilidades. NO instala el stack servidor
    (WordPress / MantisBT / Nginx — eso es scripts/server/windows/setup.ps1).

    Componentes instalados:
      - Python 3            (buscar_vulnerabilidades.py)
      - Git                 (control de versiones / actualizar scripts)
      - ADB                 (diagnóstico Android)
      - smartmontools        (S.M.A.R.T. extendido en diagnostico.ps1)
      - AnyDesk             (acceso remoto al equipo del cliente)
      - Herramientas opcionales: LibreHardwareMonitor, Nmap, Speedtest CLI

.EXAMPLE
    # Ejecutar como Administrador:
    powershell -ExecutionPolicy Bypass -File setup-tecnico-windows.ps1
#>

[CmdletBinding()]
param(
    [Alias('h')][switch]$Help,
    [switch]$SkipOptional   # omite LibreHardwareMonitor, Nmap, Speedtest
)

if ($Help) {
    @"
NAME
    setup-tecnico-windows.ps1 - Setup del entorno del tecnico ResolveCore

SYNOPSIS
    powershell -ExecutionPolicy Bypass -File setup-tecnico-windows.ps1 [-SkipOptional] [-Help]

DESCRIPTION
    Instala en la máquina del técnico todo lo necesario para ejecutar:
      · diagnostico.ps1 / optimizacion.ps1
      · diagnostico.sh / optimizacion.sh (Android vía ADB)
      · buscar_vulnerabilidades.py
      · ResolveCore.ps1 (menú)

PARAMETROS
    -SkipOptional   No instala LibreHardwareMonitor, Nmap ni Speedtest CLI.
    -Help, -h       Muestra esta ayuda y sale.

REQUISITOS
    - Windows 10/11.
    - PowerShell 5.1+.
    - Consola Administrador.
    - Conexión a internet.

EXIT CODES
    0   Setup completado.
    1   Error fatal.
"@ | Write-Host
    exit 0
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Helpers ──────────────────────────────────────────────────────────────────
function Write-Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Info($msg) { Write-Host "  [->] $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "  [!] $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "  [X] $msg" -ForegroundColor Red; exit 1 }

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-ChocoPackage {
    param([string]$Package, [string]$Label = $Package, [switch]$Optional)
    Write-Info "Instalando $Label..."
    try {
        & choco install $Package -y --no-progress 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "choco exit code $LASTEXITCODE" }
        Write-Ok "$Label instalado"
    } catch {
        if ($Optional) { Write-Warn "$Label no disponible: $_" }
        else           { Write-Fail "$Label fallo: $_" }
    }
}

function Install-WingetPackage {
    param([string]$Id, [string]$Label = $Id)
    Write-Info "Instalando $Label via winget..."
    try {
        winget install --id $Id -e --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
        Write-Ok "$Label instalado"
        return $true
    } catch {
        return $false
    }
}

# ── Banner ───────────────────────────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  ____                 _       ____" -ForegroundColor Cyan
Write-Host " |  _ \ ___  ___  ___ | |_   / ___|___  _ __ ___" -ForegroundColor Cyan
Write-Host " | |_) / _ \/ __|/ _ \| \ \ / /  / _ \| '__/ _ \" -ForegroundColor Cyan
Write-Host " |  _ <  __/\__ \ (_) | |\ V /  | (_) | | |  __/" -ForegroundColor Cyan
Write-Host " |_| \_\___||___/\___/|_| \_/    \___/|_|  \___|" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Setup del Tecnico - Windows" -ForegroundColor Cyan

Write-Host ""

# ── Comprobaciones previas ───────────────────────────────────────────────────
if (-not (Test-Admin)) {
    Write-Fail "Ejecuta como Administrador: clic derecho -> Ejecutar como administrador"
}

$confirm = Read-Host "  Continuar con la instalacion? [S/N]"
if ($confirm -notmatch '^[sS]$') { Write-Host "  Cancelado."; exit 0 }
Write-Host ""

# ── 1. Chocolatey ────────────────────────────────────────────────────────────
Write-Info "Verificando Chocolatey..."
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Info "Instalando Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = `
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString(
        'https://community.chocolatey.org/install.ps1'))
    $env:PATH += ";$env:ALLUSERSPROFILE\chocolatey\bin"
    Write-Ok "Chocolatey instalado"
} else {
    Write-Ok "Chocolatey ya presente"
}

# ── 2. Python 3 ──────────────────────────────────────────────────────────────
Write-Info "Verificando Python 3..."
$pyCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pyCmd) { $pyCmd = Get-Command python3 -ErrorAction SilentlyContinue }

if (-not $pyCmd) {
    # Intento 1: winget (instalación nativa, sin UAC adicional)
    $wingetOk = Install-WingetPackage -Id "Python.Python.3.12" -Label "Python 3.12"
    if (-not $wingetOk) {
        # Intento 2: Chocolatey
        Install-ChocoPackage -Package "python" -Label "Python 3"
        $env:PATH += ";C:\Python313;C:\Python313\Scripts;C:\Python312;C:\Python312\Scripts"
    }
} else {
    $pyVer = & $pyCmd.Source --version 2>&1
    Write-Ok "Python ya presente ($pyVer)"
}

# ── 3. Git ────────────────────────────────────────────────────────────────────
Write-Info "Verificando Git..."
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Install-ChocoPackage -Package "git" -Label "Git"
    $env:PATH += ";C:\Program Files\Git\bin"
} else {
    Write-Ok "Git ya presente"
}

# ── 4. ADB (Android Debug Bridge) ────────────────────────────────────────────
Write-Info "Verificando ADB..."
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    $adbDir = "$env:LOCALAPPDATA\ResolveCore\platform-tools"
    if (-not (Test-Path "$adbDir\adb.exe")) {
        Write-Info "Descargando Android Platform Tools..."
        $adbZip = "$env:TEMP\platform-tools-latest-windows.zip"
        try {
            Invoke-WebRequest `
                "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" `
                -OutFile $adbZip -UseBasicParsing
            New-Item -ItemType Directory -Force -Path (Split-Path $adbDir) | Out-Null
            Expand-Archive -Path $adbZip -DestinationPath (Split-Path $adbDir) -Force
            Remove-Item $adbZip -Force
            Write-Ok "ADB instalado en $adbDir"
        } catch {
            Write-Warn "No se pudo descargar ADB: $_"
        }
    } else {
        Write-Ok "ADB ya presente en $adbDir"
    }

    # Añadir al PATH del usuario (persistente, sin requerir reinicio)
    $userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($userPath -notlike "*platform-tools*") {
        [System.Environment]::SetEnvironmentVariable('PATH', "$userPath;$adbDir", 'User')
        $env:PATH += ";$adbDir"
        Write-Ok "ADB anadido al PATH del usuario"
    }
} else {
    Write-Ok "ADB ya presente"
}

# ── 5. smartmontools ─────────────────────────────────────────────────────────
Write-Info "Verificando smartmontools..."
if (-not (Get-Command smartctl -ErrorAction SilentlyContinue)) {
    Install-ChocoPackage -Package "smartmontools" -Label "smartmontools"
    $env:PATH += ";C:\Program Files\smartmontools\bin"
} else {
    Write-Ok "smartmontools ya presente"
}

# ── 6. AnyDesk ───────────────────────────────────────────────────────────────
Write-Info "Verificando AnyDesk..."
$anydeskInstalled = Get-Command anydesk -ErrorAction SilentlyContinue
if (-not $anydeskInstalled) {
    $anydeskInstalled = Test-Path "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe"
}
if (-not $anydeskInstalled) {
    Install-ChocoPackage -Package "anydesk" -Label "AnyDesk"
} else {
    Write-Ok "AnyDesk ya presente"
}

# ── 7. Herramientas opcionales ────────────────────────────────────────────────
if (-not $SkipOptional) {
    Write-Host ""
    Write-Host "  [Opcionales]" -ForegroundColor Gray

    # LibreHardwareMonitor - temperaturas y voltajes en diagnostico.ps1
    if (-not (Get-Command LibreHardwareMonitor -ErrorAction SilentlyContinue)) {
        Install-ChocoPackage -Package "librehardwaremonitor" `
            -Label "LibreHardwareMonitor" -Optional
    } else { Write-Ok "LibreHardwareMonitor ya presente" }

    # Nmap — escaneo de puertos
    if (-not (Get-Command nmap -ErrorAction SilentlyContinue)) {
        Install-ChocoPackage -Package "nmap" -Label "Nmap" -Optional
        $env:PATH += ";${env:ProgramFiles(x86)}\Nmap"
    } else { Write-Ok "Nmap ya presente" }

    # Speedtest CLI
    if (-not (Get-Command speedtest -ErrorAction SilentlyContinue)) {
        Install-ChocoPackage -Package "speedtest" -Label "Speedtest CLI" -Optional
    } else { Write-Ok "Speedtest CLI ya presente" }
}

# ── 8. Scripts ResolveCore ────────────────────────────────────────────────────
$scriptsDir = "$env:USERPROFILE\.resolvecore"
Write-Info "Instalando scripts ResolveCore en $scriptsDir..."
try {
    if (Test-Path "$scriptsDir\.git") {
        & git -C $scriptsDir pull --quiet 2>&1 | Out-Null
        Write-Ok "Scripts actualizados"
    } else {
        & git clone --depth=1 --quiet "https://github.com/Haplee/ResolveCore.git" $scriptsDir 2>&1 | Out-Null
        Write-Ok "Scripts clonados en $scriptsDir"
    }
} catch {
    Write-Warn "No se pudo clonar desde GitHub. Copia los scripts manualmente en $scriptsDir"
}

# Añadir scripts al PATH del usuario
$userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
$winScriptsDir = "$scriptsDir\scripts\windows"
if ($userPath -notlike "*$winScriptsDir*" -and (Test-Path $winScriptsDir)) {
    [System.Environment]::SetEnvironmentVariable('PATH', "$userPath;$winScriptsDir", 'User')
    Write-Ok "Scripts añadidos al PATH del usuario"
}

# ── 9. Atajo en el escritorio ─────────────────────────────────────────────────
$shortcutPath = "$env:USERPROFILE\Desktop\ResolveCore.lnk"
if (-not (Test-Path $shortcutPath) -and (Test-Path "$scriptsDir\scripts\windows\ResolveCore.ps1")) {
    try {
        $wsh = New-Object -ComObject WScript.Shell
        $sc = $wsh.CreateShortcut($shortcutPath)
        $sc.TargetPath       = "powershell.exe"
        $sc.Arguments        = "-ExecutionPolicy Bypass -File `"$scriptsDir\scripts\windows\ResolveCore.ps1`""
        $sc.WorkingDirectory = "$scriptsDir\scripts\windows"
        $sc.Description      = "ResolveCore - Herramientas de soporte"
        $sc.IconLocation     = "powershell.exe,0"
        $sc.Save()
        Write-Ok "Acceso directo creado en el escritorio"
    } catch {
        Write-Warn "No se pudo crear el acceso directo: $_"
    }
}

# ── 10. Verificación final ────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host "    Verificacion del entorno" -ForegroundColor Cyan
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host ""

$ok = 0; $fail = 0

function Test-Tool {
    param([string]$Label, [string]$Command, [string]$VersionArg = "--version")
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if ($cmd) {
        try {
            $ver = (& $cmd.Source $VersionArg 2>&1 | Select-String '\d+\.\d+' | Select-Object -First 1).Matches[0].Value
        } catch { $ver = "ok" }
        Write-Host "  " -NoNewline
        Write-Host "[OK]" -ForegroundColor Green -NoNewline
        Write-Host " $Label ($ver)"
        $script:ok++
    } else {
        Write-Host "  " -NoNewline
        Write-Host "[X]" -ForegroundColor Red -NoNewline
        Write-Host " $Label - NO ENCONTRADO"
        $script:fail++
    }
}

Test-Tool "Python 3"       "python"    "--version"
Test-Tool "Git"            "git"       "--version"
Test-Tool "ADB"            "adb"       "--version"
Test-Tool "smartctl"       "smartctl"  "--version"
Test-Tool "AnyDesk"        "anydesk"   "--version"

Write-Host ""
Write-Host "  Resultado: " -NoNewline
Write-Host "$ok ok" -ForegroundColor Green -NoNewline
Write-Host " / " -NoNewline
Write-Host "$fail fallo(s)" -ForegroundColor $(if ($fail -gt 0) { 'Red' } else { 'Green' })
Write-Host ""

if ($fail -eq 0) {
    Write-Host "  [OK] Entorno listo." -ForegroundColor Green
    Write-Host "  Ejecuta: " -NoNewline
    Write-Host "ResolveCore.ps1" -ForegroundColor Cyan
} else {
    Write-Warn "Algunos componentes no se instalaron. Revisa los errores arriba."
    Write-Host "  Puedes reintentar con: " -NoNewline
    Write-Host ".\setup-tecnico-windows.ps1" -ForegroundColor Cyan
}
Write-Host ""
