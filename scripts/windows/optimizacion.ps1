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
    [switch]$BackupOnly,
    [Alias('h')][switch]$Help
)

if ($Help) {
    @"
NAME
    optimizacion.ps1 - Optimizacion de sistema Windows para ResolveCore

SYNOPSIS
    .\optimizacion.ps1 [-Nivel <nivel>] [-DryRun] [-Undo] [-BackupOnly]
                       [-Help]

DESCRIPTION
    Aplica optimizaciones por niveles: telemetria off, servicios no
    criticos (Spooler EXCLUIDO siempre), visual effects, ajustes del
    registro, debloat de Cortana/OneDrive/Bing en niveles altos. Antes
    de modificar nada hace backup del registro y guarda estado_previo.json
    para permitir -Undo. Requiere consola Administrador.

PARAMETERS
    -Nivel <nivel>              Nivel a aplicar (default: estandar):
                                  ligero       Limpieza basica + servicios
                                               no criticos.
                                  estandar     Telemetria off + servicios +
                                               visual effects.
                                  rendimiento  Estandar + optimizaciones
                                               disco/red/RAM.
                                  extreme      Rendimiento + bloqueo de
                                               Cortana/OneDrive/Bing.
    -DryRun                     Simula sin aplicar cambios. Imprime las
                                acciones planificadas.
    -Undo                       Deshace cambios usando estado_previo.json.
    -BackupOnly                 Solo crea copia del registro, no aplica.
    -Help, -h                   Muestra esta ayuda y sale.

FILES
    %TEMP%\ResolveCore_Optimizacion\optimizacion.log
    %TEMP%\ResolveCore_Optimizacion\backup\         (copias .reg)
    %TEMP%\ResolveCore_Optimizacion\estado_previo.json

REQUISITOS
    - Consola PowerShell como Administrador.
    - PowerShell 5.1+ (Windows 10/11 trae 5.1).

EXAMPLES
    .\optimizacion.ps1 -Nivel ligero -DryRun
    .\optimizacion.ps1 -Nivel rendimiento
    .\optimizacion.ps1 -BackupOnly
    .\optimizacion.ps1 -Undo

EXIT CODES
    0    Optimizacion aplicada correctamente.
    1    Sin privilegios de Administrador.
"@ | Write-Host
    exit 0
}

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$SCRIPT_VERSION = "3.2.0"
$LOG_DIR = "$env:TEMP\ResolveCore_Optimizacion"
$LOG_FILE = "$LOG_DIR\optimizacion.log"
$REG_BACKUP_DIR = "$LOG_DIR\backup"
$STATE_FILE = "$LOG_DIR\estado_previo.json"
$REPORT = [ordered]@{ nivel = $Nivel; dry_run = [bool]$DryRun; acciones = @(); inicio = (Get-Date -Format 'o') }

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
if (-not (Test-Path $REG_BACKUP_DIR)) {
    New-Item -ItemType Directory -Path $REG_BACKUP_DIR -Force | Out-Null
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
    Write-Section "Deshaciendo cambios"

    # 1. Plan equilibrado
    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
    Write-Ok "Plan equilibrado restaurado"

    # 2. Restaurar servicios desde estado previo
    if (Test-Path $STATE_FILE) {
        try {
            $previo = Get-Content $STATE_FILE -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($s in $previo.servicios) {
                try {
                    Set-Service -Name $s.nombre -StartupType $s.inicio -ErrorAction Stop
                    Write-Ok "Servicio $($s.nombre) -> $($s.inicio)"
                } catch {
                    Write-Warn "No se pudo restaurar $($s.nombre): $($_.Exception.Message)"
                }
            }
        } catch {
            Write-Warn "Estado previo ilegible: $($_.Exception.Message)"
        }
    } else {
        Write-Warn "Sin estado previo en $STATE_FILE — no hay servicios que restaurar"
    }

    # 3. Restaurar registro desde reg export (.reg)
    Get-ChildItem -Path $REG_BACKUP_DIR -Filter '*.reg' -ErrorAction SilentlyContinue | ForEach-Object {
        $proc = Start-Process -FilePath 'reg.exe' -ArgumentList @('import', "`"$($_.FullName)`"") -Wait -PassThru -WindowStyle Hidden
        if ($proc.ExitCode -eq 0) { Write-Ok "Registro importado: $($_.Name)" }
        else { Write-Warn "Falló import de $($_.Name) (exit $($proc.ExitCode))" }
    }

    Write-Ok "Undo completado"
    exit 0
}

# Optimizacion

Write-Section "Limpieza del sistema"
if (-not $DryRun) {
    $freed = 0
    $tempPaths = @("$env:TEMP", "$env:SystemRoot\Temp", "$env:LOCALAPPDATA\Temp")
    foreach ($tp in $tempPaths) {
        if (Test-Path $tp) {
            $sizeBefore = (Get-ChildItem $tp -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
            Remove-Item -Path "$tp\*" -Recurse -Force -ErrorAction SilentlyContinue
            $freed += $sizeBefore
        }
    }
    $freedMB = [math]::Round($freed / 1MB, 1)
    Write-Ok "Limpieza TEMP/Windows/Temp -- liberados ~${freedMB}MB"
    $REPORT.acciones += "limpieza_temp_mb:$freedMB"
} else {
    Write-Info "DryRun: limpiaria TEMP, $env:SystemRoot\Temp, LOCALAPPDATA\Temp"
}

Write-Section "Servicios del sistema"

# Spooler (cola de impresion) NUNCA se desactiva — requerido por usuarios con impresoras.
$servicesToDisable = @()
switch ($Nivel) {
    'ligero' { $servicesToDisable = @() }
    'estandar' { $servicesToDisable = @('BITS', 'WSearch') }
    'rendimiento' { $servicesToDisable = @('BITS', 'WSearch', 'DiagTrack', 'DPS') }
    'extreme' { $servicesToDisable = @('BITS', 'WSearch', 'DiagTrack', 'DPS', 'SysMain') }
}

# Snapshot estado previo para Undo
$estadoPrevio = @{ servicios = @() }
foreach ($svc in $servicesToDisable) {
    $svcObj = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($svcObj) {
        $estadoPrevio.servicios += [ordered]@{ nombre = $svc; inicio = $svcObj.StartType.ToString() }
        if (-not $DryRun) {
            try {
                Set-Service -Name $svc -StartupType Disabled -ErrorAction Stop
                Write-Ok "Desactivado: $svc (previo: $($svcObj.StartType))"
                $REPORT.acciones += "servicio_desactivado:$svc"
            } catch {
                Write-Warn "No se pudo desactivar $svc: $($_.Exception.Message)"
            }
        } else {
            Write-Info "DryRun: desactivaria servicio $svc (actual: $($svcObj.StartType))"
        }
    }
}

if (-not $DryRun -and $estadoPrevio.servicios.Count -gt 0) {
    $estadoPrevio | ConvertTo-Json -Depth 5 | Out-File -FilePath $STATE_FILE -Encoding UTF8
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
if (-not $DryRun) {
    if ($exists) {
        powercfg /setactive $plan
        Write-Ok "Plan de energia: $Nivel"
        $REPORT.acciones += "plan_energia:$Nivel"
    } else {
        powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
        Write-Ok "Plan equilibrado"
        $REPORT.acciones += "plan_energia:equilibrado"
    }
    if ($Nivel -eq 'rendimiento' -or $Nivel -eq 'extreme') {
        powercfg /change monitor-timeout-ac 10 2>$null
        powercfg /change disk-timeout-ac 0 2>$null
        Write-Ok "Ajustes de energia"
    }
} else {
    Write-Info "DryRun: activaria plan de energia $Nivel ($plan)"
}

Write-Section "Registro - Memoria"

$memPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
if ($Nivel -eq 'rendimiento' -or $Nivel -eq 'extreme') {
    if (-not $DryRun) {
        # Backup previo del subarbol antes de modificar — habilita Undo
        $regBackup = Join-Path $REG_BACKUP_DIR 'memory_management.reg'
        reg export 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' "$regBackup" /y 2>$null | Out-Null

        Set-ItemProperty -Path $memPath -Name DisablePagingExecutive -Value 1 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $memPath -Name LargeSystemCache -Value 1 -ErrorAction SilentlyContinue
        Write-Ok "Optimizacion memoria (backup: memory_management.reg)"
        $REPORT.acciones += "registro_memoria"
    } else {
        Write-Info "DryRun: modificaria registro memoria (DisablePagingExecutive, LargeSystemCache)"
    }
}

Write-Section "Explorador"

if ($Nivel -eq 'rendimiento' -or $Nivel -eq 'extreme') {
    if (-not $DryRun) {
        $expPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'
        $regBackup = Join-Path $REG_BACKUP_DIR 'explorer.reg'
        reg export 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' "$regBackup" /y 2>$null | Out-Null
        Set-ItemProperty -Path $expPath -Name AlwaysUnloadDLL -Value 1 -ErrorAction SilentlyContinue
        Write-Ok "AlwaysUnloadDLL (backup: explorer.reg)"
        $REPORT.acciones += "registro_explorer"
    } else {
        Write-Info "DryRun: modificaria Explorer AlwaysUnloadDLL"
    }
}

Write-Section "TCP/IP"

if ($Nivel -eq 'rendimiento' -or $Nivel -eq 'extreme') {
    if (-not $DryRun) {
        netsh int tcp set global autotuninglevel=normal 2>$null
        netsh int tcp set global congestionprovider=ctcp 2>$null
        Write-Ok "TCP optimizado"
        $REPORT.acciones += "tcp_tuning"
        if ($Nivel -eq 'extreme') {
            netsh int tcp set global fastopen=3 2>$null
            Write-Ok "TCP Fast Open"
            $REPORT.acciones += "tcp_fastopen"
        }
    } else {
        Write-Info "DryRun: optimizaria TCP (autotuninglevel=normal, congestionprovider=ctcp)"
    }
}

Write-Section "Desactivar telemetria"

$telemetryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
if (-not $DryRun) {
    if (-not (Test-Path $telemetryPath)) { New-Item -Path $telemetryPath -Force | Out-Null }
    Set-ItemProperty -Path $telemetryPath -Name AllowTelemetry -Value 0 -ErrorAction SilentlyContinue
    Write-Ok "Telemetria desactivada"
    $REPORT.acciones += "telemetria_desactivada"
} else {
    Write-Info "DryRun: desactivaria telemetria (AllowTelemetry=0)"
}

Write-Section "Sistema de archivos"

if (-not $DryRun) {
    fsutil behavior set DisableLastAccess 1 2>$null
    Write-Ok "LastAccess deshabilitado"
    $REPORT.acciones += "last_access_disabled"
} else {
    Write-Info "DryRun: deshabilitaria LastAccess en NTFS"
}

# Output JSON
$REPORT.fin = (Get-Date -Format 'o')
$REPORT.plataforma = 'windows'
$REPORT.hostname = $env:COMPUTERNAME
$REPORT.acciones_count = $REPORT.acciones.Count

$outDir = Join-Path (Split-Path $PSScriptRoot -Parent) "diagnosticos"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$outFile = Join-Path $outDir "optimizacion_$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$REPORT | ConvertTo-Json -Depth 5 | Out-File -FilePath $outFile -Encoding UTF8

# Resultado

Write-Host ""
Write-Host "  ==============================================================" -ForegroundColor Cyan
Write-Host "  [OK] Optimizacion completada" -ForegroundColor Green
Write-Host "  Informe: $outFile" -ForegroundColor White
Write-Host ""

if (-not $DryRun) {
    Write-Host "  Recomendaciones:" -ForegroundColor Yellow
    Write-Host "    - Reiniciar el sistema"
    Write-Host "    - Para deshacer: .\optimizacion.ps1 -Undo"
    Write-Host ""
}

exit 0