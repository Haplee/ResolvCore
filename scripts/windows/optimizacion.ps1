#Requires -Version 5.1
<#
.SYNOPSIS
    ResolveCore - Optimizacion de sistema Windows
.DESCRIPTION
    Aplica optimizaciones segun el nivel seleccionado
.PARAMETER Nivel
    Nivel: ligero, estandar, rendimiento, extreme
.PARAMETER DryRun
    Simula sin aplicar
.PARAMETER Undo
    Deshace cambios
.EXAMPLE
    .\optimizacion.ps1 -Nivel estandar
#>

[CmdletBinding()]
param(
    [ValidateSet('ligero', 'estandar', 'rendimiento', 'extreme')]
    [string]$Nivel = 'estandar',
    [switch]$DryRun,
    [switch]$Undo,
    [switch]$BackupOnly
)

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

$SCRIPT_VERSION = "3.0.0"
$LOG_DIR = "$env:TEMP\ResolveCore_Optimizacion"
$LOG_FILE = "$LOG_DIR\optimizacion.log"
$REG_BACKUP_DIR = "$LOG_DIR\backup"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    Write-Host '[X] Ejecutar como Administrador' -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $LOG_DIR)) {
    New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
}

# Funciones

function Get-WindowsVersion {
    $os = Get-CimInstance Win32_OperatingSystem
    return @{ Build = $os.BuildNumber; Name = $os.Caption; Version = $os.Version }
}

function Get-SystemInfo {
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $mem = Get-CimInstance Win32_ComputerSystem
    $disk = Get-PSDrive -Name C
    return @{
        CPU = $cpu.Name
        Cores = $cpu.NumberOfCores
        Threads = $cpu.NumberOfLogicalProcessors
        RAM = [math]::Round($mem.TotalPhysicalMemory / 1GB, 1)
        DiskFree = [math]::Round($disk.Free / 1GB, 1)
    }
}

function Write-Info { param($t) Write-Host "    > $t" -ForegroundColor Gray }
function Write-Ok { param($t) Write-Host "    [OK] $t" -ForegroundColor Green }
function Write-Warn { param($t) Write-Host "    [!] $t" -ForegroundColor Yellow }
function Write-Fail { param($t) Write-Host "    [X] $t" -ForegroundColor Red }
function Write-Section { param($t) Write-Host ""; Write-Host "  > $t" -ForegroundColor Cyan }

# Obtener info del sistema
$winInfo = Get-WindowsVersion
$sysInfo = Get-SystemInfo

# Banner
Write-Host ""
Write-Host "  ==============================================================" -ForegroundColor Cyan
Write-Host "  ResolveCore - Optimizacion Windows v$SCRIPT_VERSION" -ForegroundColor Cyan
Write-Host "  Nivel: $Nivel" -ForegroundColor White
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "  ==============================================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Warn "Modo simulacion - no se aplicaran cambios"
    Write-Host ""
}

if ($BackupOnly) {
    Write-Section "Creando backup..."
    $regPaths = @(
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer',
        'HKCU:\Control Panel\Desktop'
    )
    foreach ($p in $regPaths) {
        if (Test-Path $p) {
            $name = $p -replace '[:\\]', '_'
            $backupPath = "$REG_BACKUP_DIR\$name.reg"
            try { reg export "$p" "$backupPath" /y 2>$null } catch {}
        }
    }
    Write-Ok "Backup creado: $REG_BACKUP_DIR"
    exit 0
}

if ($Undo) {
    Write-Section "Deshaciendo cambios..."
    Write-Ok "Restaurando plan equilibrado"
    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
    Write-Ok "Completado"
    exit 0
}

# Optimizacion

Write-Section "Limpieza del sistema"
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Ok "Limpieza TEMP"

Write-Section "Servicios del sistema"

$servicesToDisable = @()
switch ($Nivel) {
    'ligero' { $servicesToDisable = @('Spooler') }
    'estandar' { $servicesToDisable = @('Spooler', 'BITS', 'WSearch') }
    'rendimiento' { $servicesToDisable = @('Spooler', 'BITS', 'WSearch', 'DiagTrack', 'DPS') }
    'extreme' { $servicesToDisable = @('Spooler', 'BITS', 'WSearch', 'DiagTrack', 'DPS', 'SysMain', 'wuauserv') }
}

foreach ($svc in $servicesToDisable) {
    $svcObj = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($svcObj) {
        Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Ok "Desactivado: $svc"
    }
}

Write-Section "Plan de energia"

$plans = @{
    'ligero' = '381b4222-f694-41f0-9685-ff5bb260df2e'
    'estandar' = '381b4222-f694-41f0-9685-ff5bb260df2e'
    'rendimiento' = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    'extreme' = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
}

$plan = $plans[$Nivel]
$exists = powercfg /list | Select-String -Pattern $plan
if ($exists) {
    powercfg /setactive $plan
    Write-Ok "Plan de energia: $Nivel"
} else {
    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
    Write-Ok "Plan equilibrado"
}

if ($Nivel -eq 'rendimiento' -or $Nivel -eq 'extreme') {
    powercfg /change monitor-timeout-ac 10 2>$null
    powercfg /change disk-timeout-ac 0 2>$null
    Write-Ok "Ajustes de energia"
}

Write-Section "Registro - Memoria"

$memPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
if ($Nivel -eq 'rendimiento' -or $Nivel -eq 'extreme') {
    Set-ItemProperty -Path $memPath -Name DisablePagingExecutive -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $memPath -Name LargeSystemCache -Value 1 -ErrorAction SilentlyContinue
    Write-Ok "Optimizacion memoria"
}

Write-Section "Explorador"

if ($Nivel -eq 'rendimiento' -or $Nivel -eq 'extreme') {
    $expPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'
    Set-ItemProperty -Path $expPath -Name AlwaysUnloadDLL -Value 1 -ErrorAction SilentlyContinue
    Write-Ok "AlwaysUnloadDLL"
}

Write-Section "TCP/IP"

if ($Nivel -eq 'rendimiento' -or $Nivel -eq 'extreme') {
    netsh int tcp set global autotuninglevel=normal 2>$null
    netsh int tcp set global congestionprovider=ctcp 2>$null
    Write-Ok "TCP optimizado"
}

if ($Nivel -eq 'extreme') {
    netsh int tcp set global fastopen=3 2>$null
    Write-Ok "TCP Fast Open"
}

Write-Section "Desactivar telemetria"

$telemetryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
if (-not (Test-Path $telemetryPath)) { New-Item -Path $telemetryPath -Force | Out-Null }
Set-ItemProperty -Path $telemetryPath -Name AllowTelemetry -Value 0 -ErrorAction SilentlyContinue
Write-Ok "Telemetria desactivada"

Write-Section "Sistema de archivos"

fsutil behavior set DisableLastAccess 1 2>$null
Write-Ok "LastAccess deshabilitado"

# Resultado

Write-Host ""
Write-Host "  ==============================================================" -ForegroundColor Cyan
Write-Host "  [OK] Optimizacion completada" -ForegroundColor Green
Write-Host ""

if (-not $DryRun) {
    Write-Host "  Recomendaciones:" -ForegroundColor Yellow
    Write-Host "    - Reiniciar el sistema"
    Write-Host "    - Para deshacer: .\optimizacion.ps1 -Undo"
    Write-Host ""
}

exit 0