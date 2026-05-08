# Requires -Version 5.1
<#
.SYNOPSIS
    ResolveCore - Menu Windows

.DESCRIPTION
    Menu interactivo para tecnicos de soporte
#>
# Variables 



[CmdletBinding()]
param(
    [switch]$NoLoop,
    [Alias('h')][switch]$Help,

    # Pass-through a diagnostico.ps1
    [Alias('O','Output')][string]$OutputDir,
    [Alias('S')][switch]$Silent,
    [Alias('I','Install')][switch]$InstallDeps,
    [Alias('A')][switch]$AutoInstall,

    # Pass-through a optimizacion.ps1
    [ValidateSet('','ligero','estandar','rendimiento','extreme')]
    [string]$Nivel = '',
    [switch]$DryRun,
    [switch]$Undo,
    [switch]$BackupOnly
)

# ── Pass-through: si llega flag de modulo, invocar directo y salir ──────────
$diagFlags = $OutputDir -or $Silent -or $InstallDeps -or $AutoInstall
$optFlags  = $Nivel -or $DryRun -or $Undo -or $BackupOnly
if ($diagFlags -and $optFlags) {
    Write-Host '[X] Flags de diagnostico y optimizacion son mutuamente exclusivos.' -ForegroundColor Red
    Write-Host '    Invoca .\diagnostico.ps1 o .\optimizacion.ps1 por separado.'
    exit 2
}
if ($diagFlags) {
    $diagPath = Join-Path $PSScriptRoot 'diagnostico.ps1'
    $splat = @{}
    if ($OutputDir)    { $splat.OutputDir   = $OutputDir }
    if ($Silent)       { $splat.Silent      = $true }
    if ($InstallDeps)  { $splat.InstallDeps = $true }
    if ($AutoInstall)  { $splat.AutoInstall = $true }
    & $diagPath @splat
    exit $LASTEXITCODE
}
if ($optFlags) {
    $optPath = Join-Path $PSScriptRoot 'optimizacion.ps1'
    $splat = @{}
    if ($Nivel)        { $splat.Nivel      = $Nivel }
    if ($DryRun)       { $splat.DryRun     = $true }
    if ($Undo)         { $splat.Undo       = $true }
    if ($BackupOnly)   { $splat.BackupOnly = $true }
    & $optPath @splat
    exit $LASTEXITCODE
}

if ($Help) {
    @"
NAME
    ResolveCore.ps1 - Menu interactivo de herramientas ResolveCore para Windows

SYNOPSIS
    .\ResolveCore.ps1 [-NoLoop] [-Help]
    .\ResolveCore.ps1 [-O <dir>] [-S] [-I|-A]                # forward a diagnostico
    .\ResolveCore.ps1 -Nivel <nivel> [-DryRun] [-Undo] [-BackupOnly]  # forward a optimizacion

DESCRIPTION
    Sin flags: lanza menu interactivo TUI (analisis, diagnostico, optimizacion,
    ayuda, salir). Con flags de modulo: salta el menu e invoca diagnostico.ps1
    u optimizacion.ps1 directamente con esos flags. Util para automatizacion
    o tecnicos que ya saben que accion lanzar.

    Antes del menu ejecuta Get-SystemAnalysis que detecta problemas (disco,
    memoria, CPU, servicios, Defender) y muestra resumen.

OPTIONS DEL LAUNCHER
    -NoLoop           Tras seleccionar una opcion, sale en vez de volver al
                      menu. Util para invocaciones desde scripts wrapper.
    -h, -Help         Muestra esta ayuda y sale.

MENU
    1. DIAGNOSTICO    Llama a diagnostico.ps1 (genera JSON + HTML).
    2. OPTIMIZACION   Llama a optimizacion.ps1 (niveles ligero/estandar/
                      rendimiento/extreme).
    3. AYUDA          Guia rapida embebida.
    4. SALIR          Cierra el programa.

FLAGS DE DIAGNOSTICO (forward a diagnostico.ps1)
    -O, -OutputDir, -Output <dir>   Directorio salida JSON/HTML
                                    (default: ..\diagnosticos).
    -S, -Silent                     Sin salida por consola (modo CI).
    -I, -InstallDeps, -Install      Instala paquetes opcionales:
                                    smartmontools, OpenHardwareMonitor,
                                    speedtest, nmap, git (winget/choco).
                                    Pide confirmacion.
    -A, -AutoInstall                Igual que -I sin confirmar.

FLAGS DE OPTIMIZACION (forward a optimizacion.ps1)
    -Nivel <ligero|estandar|rendimiento|extreme>
                                    Nivel a aplicar (default: estandar).
                                      ligero       Limpieza basica.
                                      estandar     Telemetria + servicios.
                                      rendimiento  Anterior + disco/red/RAM.
                                      extreme      Anterior + Cortana/
                                                   OneDrive/Bing off.
    -DryRun                         Simula sin aplicar.
    -Undo                           Deshace cambios via estado_previo.json.
    -BackupOnly                     Solo backup del registro, no aplica.

NOTA
    Los flags de diagnostico y optimizacion son mutuamente exclusivos.
    Si pasas alguno, el launcher salta el menu y lanza el modulo.

REQUISITOS
    - PowerShell 5.1+ (Windows 10/11 trae 5.1; recomendado pwsh 7+).
    - Consola Administrador para deteccion completa y para optimizacion.

EXAMPLES
    # Menu interactivo
    .\ResolveCore.ps1

    # Sin loop (sale tras una accion)
    .\ResolveCore.ps1 -NoLoop

    # Pass-through al modulo de diagnostico (sin pasar por menu)
    .\ResolveCore.ps1 -A
    .\ResolveCore.ps1 -O C:\reports -S
    .\ResolveCore.ps1 -I

    # Pass-through al modulo de optimizacion
    .\ResolveCore.ps1 -Nivel rendimiento -DryRun
    .\ResolveCore.ps1 -Undo

    # Equivalente invocando modulos directamente
    .\diagnostico.ps1 -A
    .\optimizacion.ps1 -Nivel rendimiento

EXIT CODES
    0    Salida normal o ayuda mostrada.
    2    Combinacion invalida de flags (diag + opt).
"@ | Write-Host
    exit 0
}

$usuario = $env:USERNAME

$ErrorActionPreference = 'Continue'
$SCRIPT_DIR = $PSScriptRoot
$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot

$SYSTEM_ISSUES = @()

function Add-Issue {
    param($severity, $category, $message)
    $script:SYSTEM_ISSUES += @{
        severity = $severity
        category = $category
        message  = $message
    }
}

function Get-SystemAnalysis {
    $script:SYSTEM_ISSUES = @()

    # Check admin
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin) {
        Add-Issue -severity "high" -category "permisos" -message "Sin permisos de administrador"
    }

    # Check disk
    try {
        $disk = Get-PSDrive -Name C -ErrorAction SilentlyContinue
        if ($disk) {
            $freeGB = [math]::Round($disk.Free / 1GB, 1)
            $totalGB = [math]::Round(($disk.Free + $disk.Used) / 1GB, 1)
            $usedPct = [math]::Round($disk.Used / ($disk.Free + $disk.Used) * 100, 1)

            if ($freeGB -lt 10) {
                Add-Issue -severity "critical" -category "disco" -message "Poco espacio: ${freeGB}GB libre"
            }
            elseif ($freeGB -lt 20) {
                Add-Issue -severity "high" -category "disco" -message "Espacio bajo: ${freeGB}GB libre"
            }
        }
    }
    catch {}

    # Check memory
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $memUsed = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize * 100, 1)
        if ($memUsed -gt 90) {
            Add-Issue -severity "critical" -category "memoria" -message "Memoria: ${memUsed}% usado"
        }
        elseif ($memUsed -gt 80) {
            Add-Issue -severity "high" -category "memoria" -message "Memoria alta: ${memUsed}%"
        }
    }
    catch {}

    # Check CPU
    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        if ($cpu.LoadPercentage -gt 80) {
            Add-Issue -severity "high" -category "cpu" -message "CPU: $($cpu.LoadPercentage)% usado"
        }
    }
    catch {}

    # Check updates
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $updates = $searcher.Search("IsInstalled=0 and Type='Software'").Updates.Count
        if ($updates -gt 0) {
            Add-Issue -severity "medium" -category "windows" -message "$updates actualizaciones pendientes"
        }
    }
    catch {}

    # Check services
    try {
        $critical = @('wuauserv', 'WSearch', 'Spooler')
        foreach ($svc in $critical) {
            $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($s -and $s.Status -ne 'Running') {
                Add-Issue -severity "medium" -category "servicios" -message "Servicio detenido: $svc"
            }
        }
    }
    catch {}

    # Check security
    try {
        $def = Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($def) {
            $sigAge = [math]::Round(((Get-Date) - $def.AntivirusSignatureLastUpdated).TotalDays, 0)
            if ($def.AntivirusEnabled -eq $false) {
                Add-Issue -severity "critical" -category "seguridad" -message "Windows Defender desactivado"
            }
            elseif ($sigAge -gt 14) {
                Add-Issue -severity "high" -category "seguridad" -message "Antivirus desactualizado: $sigAge dias"
            }
        }
    }
    catch {}

    try {
        $uac = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -ErrorAction SilentlyContinue
        if ($uac -and $uac.EnableLUA -eq 0) {
            Add-Issue -severity "high" -category "seguridad" -message "UAC desactivado"
        }
    }
    catch {}

    return $script:SYSTEM_ISSUES
}

function Show-AnalysisAndSuggestions {
    $issues = Get-SystemAnalysis

    Write-Host ""
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor DarkCyan
    Write-Host "  |  ANALISIS DEL SISTEMA - SUGERENCIAS                            " -ForegroundColor DarkCyan
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor DarkCyan

    if ($issues.Count -eq 0) {
        Write-Host ""
        Write-Host "  [OK] Sistema en buen estado" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Sugerencia: Ejecutar optimizacion para mantenimiento" -ForegroundColor Yellow
    }
    else {
        $critical = $issues | Where-Object { $_.severity -eq "critical" }
        $high = $issues | Where-Object { $_.severity -eq "high" }
        $medium = $issues | Where-Object { $_.severity -eq "medium" }

        if ($critical.Count -gt 0) {
            Write-Host ""
            Write-Host "  [X] PROBLEMAS CRITICOS:" -ForegroundColor Red
            foreach ($i in $critical) {
                Write-Host "    - $($i.message)" -ForegroundColor Red
            }
        }

        if ($high.Count -gt 0) {
            Write-Host ""
            Write-Host "  [!] PROBLEMAS:" -ForegroundColor Yellow
            foreach ($i in $high) {
                Write-Host "    - $($i.message)" -ForegroundColor Yellow
            }
        }

        if ($medium.Count -gt 0) {
            Write-Host ""
            Write-Host "  [>] MEJORAS:" -ForegroundColor Cyan
            foreach ($i in $medium) {
                Write-Host "    - $($i.message)" -ForegroundColor Gray
            }
        }

        Write-Host ""
        Write-Host "  ACCIONES RECOMENDADAS:" -ForegroundColor Cyan

        if ($critical.Count -gt 0 -or $high.Count -gt 0) {
            Write-Host "    1. Ejecutar DIAGNOSTICO para analisis completo" -ForegroundColor Yellow
            Write-Host "    2. Ejecutar OPTIMIZACION para resolver problemas" -ForegroundColor Yellow
        }
        else {
            Write-Host "    1. Ejecutar OPTIMIZACION (mantenimiento)" -ForegroundColor Green
        }
    }

    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor DarkCyan
    Write-Host ""
}

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |                    RESOLVECORE                                |" -ForegroundColor Cyan
    Write-Host "  |              Menu de Herramientas - Windows                   |" -ForegroundColor Cyan
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Equipo: $env:COMPUTERNAME" -ForegroundColor White
    Write-Host "  Usuario: $env:USERNAME" -ForegroundColor Gray
    Write-Host "  Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
}

function Show-Menu {
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor DarkCyan
    Write-Host "  |  SELECCIONA UNA OPCION:                                       |" -ForegroundColor DarkCyan
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "    1.  [DIAGNOSTICO]     - Analisis completo del sistema" -ForegroundColor Green
    Write-Host "    2.  [OPTIMIZACION]    - Optimizar rendimiento" -ForegroundColor Yellow
    Write-Host "    3.  [VULNERABILIDADES] - Buscar y corregir CVEs" -ForegroundColor Magenta
    Write-Host "    4.  [AYUDA]           - Ver guia rapida" -ForegroundColor Gray
    Write-Host "    5.  [SALIR]           - Salir" -ForegroundColor Red
    Write-Host ""
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor DarkCyan
    Write-Host ""
}

function Show-Help {
    Write-Host ""
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host "  GUIA RAPIDA - WINDOWS" -ForegroundColor Cyan
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  DIAGNOSTICO: Analiza todo el sistema y genera JSON"
    Write-Host "  OPTIMIZACION: Aplica mejoras segun nivel seleccionado"
    Write-Host "  ANALIZAR: Vuelve a analizar el sistema"
    Write-Host ""
    Read-Host "  Presiona ENTER"
}

function Get-SystemSummary {
    Write-Host "  Resumen:" -ForegroundColor Cyan

    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
        $disk = [math]::Round((Get-PSDrive -Name C).Free / 1GB, 1)
        $os = Get-CimInstance Win32_OperatingSystem

        Write-Host "    CPU: $($cpu.Name.Substring(0, [Math]::Min(45, $cpu.Name.Length)))" -ForegroundColor White
        Write-Host "    RAM: ${ram}GB | Disco: ${disk}GB libre" -ForegroundColor White
        Write-Host "    $($os.Caption.Substring(0, [Math]::Min(40, $os.Caption.Length)))" -ForegroundColor Gray
    }
    catch {}

    Write-Host ""
}

function Invoke-Diagnostico {
    Write-Host ""
    Write-Host "  Ejecutando diagnostico..." -ForegroundColor Yellow
    Write-Host ""

    $script = Join-Path $SCRIPT_DIR "diagnostico.ps1"
    if (Test-Path $script) {
        & $script
        Write-Host ""
        Write-Host "  [OK] Completado" -ForegroundColor Green
    }
    else {
        Write-Host "  [X] No encontrado" -ForegroundColor Red
    }

    Read-Host "  Presiona ENTER"
}

function Ensure-Python {
    $py = Get-Command python -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
    if ($py) { return $py }

    Write-Host "  [!] Python no encontrado. Intentando instalar..." -ForegroundColor Yellow

    # Intento 1: Scoop (sin admin, software libre - MIT)
    $scoop = Get-Command scoop -ErrorAction SilentlyContinue
    if ($scoop) {
        Write-Host "  [>] Instalando python via scoop..." -ForegroundColor Cyan
        try { & scoop install python *> $null } catch {}
        $py = Get-Command python -ErrorAction SilentlyContinue
        if ($py) { return $py }
    }

    # Intento 2: Chocolatey (Apache 2.0)
    $choco = Get-Command choco -ErrorAction SilentlyContinue
    if ($choco) {
        $isAdminLocal = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($isAdminLocal) {
            Write-Host "  [>] Instalando python via chocolatey..." -ForegroundColor Cyan
            try { & choco install python -y --no-progress *> $null } catch {}
            $env:Path += ";C:\Python313;C:\Python313\Scripts;C:\Python312;C:\Python312\Scripts"
            $py = Get-Command python -ErrorAction SilentlyContinue
            if ($py) { return $py }
        } else {
            Write-Host "  [!] Choco requiere admin para instalar python" -ForegroundColor Yellow
        }
    }

    Write-Host "  [X] No se pudo instalar Python automaticamente" -ForegroundColor Red
    Write-Host "      Descarga desde https://www.python.org/downloads/" -ForegroundColor Gray
    return $null
}

function Invoke-Vulnerabilidades {
    Write-Host ""
    Write-Host "  Lanzando escaneo de vulnerabilidades..." -ForegroundColor Magenta
    Write-Host ""

    $py = Ensure-Python
    if (-not $py) {
        Read-Host "  Presiona ENTER"
        return
    }

    $script = Join-Path $PROJECT_ROOT "buscar_vulnerabilidades.py"
    if (-not (Test-Path $script)) {
        Write-Host "  [X] No encontrado: $script" -ForegroundColor Red
        Read-Host "  Presiona ENTER"
        return
    }

    try {
        & $py.Source $script @args
        Write-Host ""
        Write-Host "  [OK] Escaneo completado" -ForegroundColor Green
    } catch {
        Write-Host "  [!] Error durante escaneo: $_" -ForegroundColor Yellow
    }

    Read-Host "  Presiona ENTER"
}

function Invoke-Optimizacion {
    Write-Host ""
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |  NIVEL DE OPTIMIZACION:                                       |" -ForegroundColor Cyan
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    1. LIGERO      - Basico y seguro" -ForegroundColor Green
    Write-Host "    2. ESTANDAR    - Equilibrio (recomendado)" -ForegroundColor Yellow
    Write-Host "    3. RENDIMIENTO - Mayor rendimiento" -ForegroundColor Magenta
    Write-Host "    4. EXTREMA     - Solo pruebas" -ForegroundColor Red
    Write-Host "    5. VOLVER" -ForegroundColor Gray
    Write-Host ""

    $nivel = Read-Host "  Selecciona (1-5)"

    $nivelOpt = switch ($nivel) {
        "1" { "ligero" }
        "2" { "estandar" }
        "3" { "rendimiento" }
        "4" { "extreme" }
        default { $null }
    }

    if ($nivel -eq "5" -or -not $nivelOpt) { return }

    if ($nivel -eq "4") {
        Write-Host ""
        Write-Host "  [!] ADVERTENCIA: Escribe 'SI' para confirmar" -ForegroundColor Yellow
        if ((Read-Host) -ne "SI") { return }
    }

    Write-Host ""
    Write-Host "  Ejecutando..." -ForegroundColor Yellow

    $script = Join-Path $SCRIPT_DIR "optimizacion.ps1"
    if (Test-Path $script) {
        & $script -Nivel $nivelOpt
        Write-Host ""
        Write-Host "  [OK] Completado" -ForegroundColor Green
    }
    else {
        Write-Host "  [X] No encontrado" -ForegroundColor Red
    }

    Read-Host "  Presiona ENTER"
}

# Programa principal
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

$isInteractive = $Host.Name -eq 'ConsoleHost' -and [Console]::IsInputRedirected -eq $false

if (-not $isInteractive) {
    Show-Banner
    Write-Host "  Este script debe ejecutarse en una terminal PowerShell interactiva" -ForegroundColor Yellow
    Write-Host "  Ejemplo: .\ResolveCore.ps1" -ForegroundColor Gray
    exit 1
}

function Main-Menu {
    while ($true) {
        Show-Banner

        if (-not $isAdmin) {
            Write-Host "  [!] Sin permisos admin - funcionalidad limitada" -ForegroundColor Yellow
            Write-Host ""
        }

        Show-Menu

        $opcion = Read-Host "  Selecciona (1-5)"

        switch ($opcion) {
            "1" { Invoke-Diagnostico }
            "2" { Invoke-Optimizacion }
            "3" { Invoke-Vulnerabilidades }
            "4" { Show-Help }
            "5" {
                Write-Host "  [ResolveCore] Sesion finalizada correctamente." -ForegroundColor Cyan
                Write-Host "  Gracias $usuario por utilizar nuestras herramientas de soporte." -ForegroundColor Gray
                Write-Host "  ¡Hasta la proxima!" -ForegroundColor White
                exit
            }
            default {
                if ($opcion -ne "") {
                    Write-Host "  Opcion no valida" -ForegroundColor Red
                }
                return
            }
        }
    }
}

Main-Menu