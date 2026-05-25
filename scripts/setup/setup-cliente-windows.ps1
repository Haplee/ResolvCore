#Requires -Version 5.1
<#
.SYNOPSIS
    ResolveCore - Setup del equipo del CLIENTE (Windows)

.DESCRIPTION
    Instala SOLO las dependencias mínimas que necesita diagnostico.ps1 para
    correr sin errores. NO instala Git, ADB, AnyDesk, Python ni otras
    herramientas del entorno del técnico — eso es setup-tecnico-windows.ps1.

    Política Zero Dependencias intrusivas: solo paquetes pasivos de lectura
    (smartmontools, nmap, LibreHardwareMonitor). No modifica configuración
    del sistema. Idempotente: re-ejecutar es seguro.

    Componentes instalados:
      - AnyDesk              (acceso remoto del técnico, freeware)
      - smartmontools        (S.M.A.R.T. extendido, GPL)
      - Nmap                 (escaneo LAN del técnico, NPSL)
      - LibreHardwareMonitor (temperaturas/voltajes, MPL — opcional)

.EXAMPLE
    # Ejecutar como Administrador en el equipo del cliente:
    powershell -ExecutionPolicy Bypass -File setup-cliente-windows.ps1
#>

[CmdletBinding()]
param(
    [Alias('h')][switch]$Help,
    [Alias('a')][switch]$AutoYes    # no preguntar, asumir Sí
)

if ($Help) {
    @"
NAME
    setup-cliente-windows.ps1 - Setup del equipo del CLIENTE

SYNOPSIS
    powershell -ExecutionPolicy Bypass -File setup-cliente-windows.ps1 [-AutoYes] [-Help]

DESCRIPTION
    Instala las dependencias mínimas para que diagnostico.ps1 funcione en el
    equipo del cliente. No instala herramientas del técnico (Git, ADB,
    AnyDesk, Python).

PARAMETROS
    -AutoYes, -a    Sin confirmaciones (para despliegues automatizados).
    -Help, -h       Esta ayuda.

REQUISITOS
    - Windows 10/11.
    - PowerShell 5.1+ (incluido).
    - Consola Administrador.
    - Conexión a internet.

EXIT CODES
    0   Setup OK.
    1   Error fatal.
"@ | Write-Host
    exit 0
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Ok($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Info($m) { Write-Host "  [->] $m" -ForegroundColor Cyan }
function Write-Warn($m) { Write-Host "  [!] $m" -ForegroundColor Yellow }
function Write-Fail($m) { Write-Host "  [X] $m" -ForegroundColor Red; exit 1 }

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-Pkg {
    param([string]$WingetId, [string]$ChocoId, [string]$Label, [switch]$Optional)
    Write-Info "Instalando $Label..."
    # Preferimos winget (nativo Win 10 1809+, sin instalar nada extra)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            winget install --id $WingetId -e --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
            Write-Ok "$Label instalado (winget)"
            return
        } catch { }
    }
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        try {
            & choco install $ChocoId -y --no-progress 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Ok "$Label instalado (choco)"; return }
        } catch { }
    }
    if ($Optional) { Write-Warn "$Label no se pudo instalar (opcional)" }
    else { Write-Fail "$Label fallo. Ni winget ni choco disponibles." }
}

# ── Banner ───────────────────────────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  ResolveCore - Setup del equipo del CLIENTE" -ForegroundColor Cyan
Write-Host "  ───────────────────────────────────────────" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  Este instalador anade SOLO lo necesario para que el tecnico" -ForegroundColor Gray
Write-Host "  ResolveCore pueda diagnosticar este equipo sin errores." -ForegroundColor Gray
Write-Host ""

if (-not (Test-Admin)) {
    Write-Fail "Ejecuta como Administrador (clic derecho - Ejecutar como administrador)"
}

if (-not $AutoYes) {
    $ans = Read-Host "  Continuar? [S/N]"
    if ($ans -notmatch '^[sS]$') { Write-Host "  Cancelado."; exit 0 }
    Write-Host ""
}

# ── 1. Comprobar gestor de paquetes ──────────────────────────────────────────
$hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
$hasChoco  = [bool](Get-Command choco  -ErrorAction SilentlyContinue)

if (-not $hasWinget -and -not $hasChoco) {
    Write-Warn "Ni winget ni Chocolatey disponibles."
    Write-Info "Instalando Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = `
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString(
        'https://community.chocolatey.org/install.ps1'))
    $env:PATH += ";$env:ALLUSERSPROFILE\chocolatey\bin"
    Write-Ok "Chocolatey instalado"
}

# ── 2. AnyDesk (acceso remoto del técnico) ───────────────────────────────────
$anyDeskPresent = (Get-Command anydesk -ErrorAction SilentlyContinue) -or `
                  (Test-Path "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe") -or `
                  (Test-Path "${env:ProgramFiles}\AnyDesk\AnyDesk.exe")
if (-not $anyDeskPresent) {
    Install-Pkg -WingetId "AnyDeskSoftwareGmbH.AnyDesk" -ChocoId "anydesk" -Label "AnyDesk"
} else {
    Write-Ok "AnyDesk ya presente"
}

# ── 3. smartmontools (smartctl) ──────────────────────────────────────────────
if (-not (Get-Command smartctl -ErrorAction SilentlyContinue)) {
    Install-Pkg -WingetId "smartmontools.smartmontools" -ChocoId "smartmontools" -Label "smartmontools"
    $env:PATH += ";C:\Program Files\smartmontools\bin"
} else {
    Write-Ok "smartmontools ya presente"
}

# ── 4. Nmap ──────────────────────────────────────────────────────────────────
if (-not (Get-Command nmap -ErrorAction SilentlyContinue)) {
    Install-Pkg -WingetId "Insecure.Nmap" -ChocoId "nmap" -Label "Nmap"
    $env:PATH += ";${env:ProgramFiles(x86)}\Nmap;${env:ProgramFiles}\Nmap"
} else {
    Write-Ok "Nmap ya presente"
}

# ── 5. LibreHardwareMonitor (opcional — temperaturas) ────────────────────────
$lhmExe = "C:\Program Files\LibreHardwareMonitor\LibreHardwareMonitor.exe"
if (-not (Test-Path $lhmExe)) {
    Install-Pkg -WingetId "LibreHardwareMonitor.LibreHardwareMonitor" `
                -ChocoId "librehardwaremonitor" `
                -Label "LibreHardwareMonitor" -Optional
} else {
    Write-Ok "LibreHardwareMonitor ya presente"
}

# ── Verificacion ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ──────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "    Verificacion" -ForegroundColor Cyan
Write-Host "  ──────────────────────────────────────────" -ForegroundColor Cyan
Write-Host ""

$ok = 0; $fail = 0
function Test-Tool {
    param([string]$Label, [string]$Cmd)
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) {
        Write-Host "  " -NoNewline; Write-Host "[OK]" -ForegroundColor Green -NoNewline; Write-Host " $Label"
        $script:ok++
    } else {
        Write-Host "  " -NoNewline; Write-Host "[X]" -ForegroundColor Red -NoNewline; Write-Host " $Label"
        $script:fail++
    }
}

Test-Tool "smartctl" "smartctl"
Test-Tool "Nmap"     "nmap"
$anyDeskOk = (Get-Command anydesk -ErrorAction SilentlyContinue) -or `
             (Test-Path "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe") -or `
             (Test-Path "${env:ProgramFiles}\AnyDesk\AnyDesk.exe")
if ($anyDeskOk) {
    Write-Host "  " -NoNewline; Write-Host "[OK]" -ForegroundColor Green -NoNewline; Write-Host " AnyDesk"
    $ok++
} else {
    Write-Host "  " -NoNewline; Write-Host "[X]" -ForegroundColor Red -NoNewline; Write-Host " AnyDesk"
    $fail++
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "  [OK] Equipo listo para diagnostico." -ForegroundColor Green
    Write-Host "  El tecnico ya puede ejecutar diagnostico.ps1 sin errores." -ForegroundColor Gray
} else {
    Write-Warn "Algunos componentes fallaron. Revisa los errores arriba."
}
Write-Host ""
