#Requires -Version 5.1
<#
.SYNOPSIS
    ResolveCore — Menú del técnico para Windows.

.DESCRIPTION
    Lanzador interactivo que el técnico abre en el equipo del cliente. Reúne en
    un solo menú el diagnóstico, la optimización y el escaneo de
    vulnerabilidades, llamando a los demás scripts de la carpeta. Auto-instala
    Python (scoop/choco) si falta para el módulo de CVEs.

    Pensado para Windows 10 y 11 (PowerShell 5.1, el que trae el sistema).

.PARAMETER NoLoop
    Ejecuta una sola acción y sale, sin volver al menú.

.EXAMPLE
    .\ResolveCore.ps1
    .\ResolveCore.ps1 -Diagnostico -OutputDir C:\Temp

.NOTES
    Autor:   Francisco Vidal Mateo (GitHub: Haplee)
    Versión: 2.0
#>



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
    1. DIAGNOSTICO     Llama a diagnostico.ps1 (genera JSON + resumen en pantalla).
    2. OPTIMIZACION    Llama a optimizacion.ps1 (niveles ligero/estandar/
                       rendimiento/extreme).
    3. VULNERABILIDADES Llama a buscar_vulnerabilidades.py (Python).
    4. INFORME         Genera una plantilla .txt (apartados en blanco) desde el
                       ultimo JSON; el tecnico la rellena y la sube a MantisBT.
    5. SERVICIOS       Congelacion / Clonacion / Kit de cliente.
    6. AYUDA           Guia rapida embebida.
    7. SALIR           Cierra el programa.

    (La facturacion se gestiona desde MantisBT, no desde este menu.)

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
$SERVICIOS_DIR = Join-Path $PROJECT_ROOT "servicios"

$SYSTEM_ISSUES = @()

# Ticket de MantisBT de la sesion. Se pide una vez al inicio y se reutiliza para
# que diagnostico e informe se guarden juntos en reparaciones\<ticket>\.
$TICKET_SESION = ''

function Read-TicketSesion {
    Write-Host ""
    $t = Read-Host "  Numero de ticket MantisBT para esta reparacion (ENTER = sin ticket)"
    if ($t -match '^\d+$') {
        $script:TICKET_SESION = $t
        Write-Host ("  [i] Sesion asociada al ticket #{0}. Salidas en reparaciones\{1}\" -f $t, ('{0:D5}' -f [int]$t)) -ForegroundColor Cyan
    } else {
        $script:TICKET_SESION = ''
        if ($t -ne '') {
            Write-Host "  [!] '$t' no es un numero de ticket valido; sesion sin ticket." -ForegroundColor Yellow
        } else {
            Write-Host "  [i] Sesion sin ticket (salidas en reparaciones\sin-ticket\)." -ForegroundColor Gray
        }
    }
    Start-Sleep 1
}

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

# Reglas a ancho completo (cadenas fijas: sin calculo de anchura -> nunca se
# desalinean, a diferencia de las cajas con borde derecho del estilo anterior).
$RC_RULE = "  ==================================================================="
$RC_THIN = "  -------------------------------------------------------------------"

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host $RC_RULE -ForegroundColor White
    Write-Host "  R E S O L V E C O R E" -NoNewline -ForegroundColor White
    Write-Host "   .  Menu de Herramientas (Windows)" -ForegroundColor DarkGray
    Write-Host $RC_RULE -ForegroundColor White
    Write-Host "   Equipo: $env:COMPUTERNAME    Usuario: $env:USERNAME" -ForegroundColor Gray
    Write-Host "   Fecha:  $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Gray
    Write-Host ""
}

function Show-Menu {
    Write-Host "  SELECCIONA UNA OPCION" -ForegroundColor White
    Write-Host $RC_THIN -ForegroundColor DarkGray
    Write-Host "   [1] Diagnostico       " -NoNewline -ForegroundColor Green
    Write-Host "Analisis completo del sistema (hw, red, seguridad) -> JSON" -ForegroundColor Gray
    Write-Host "   [2] Optimizacion      " -NoNewline -ForegroundColor Yellow
    Write-Host "Limpieza + acta de acciones (.txt/.json)" -ForegroundColor Gray
    Write-Host "   [3] Vulnerabilidades  " -NoNewline -ForegroundColor Magenta
    Write-Host "CVE (NVD + CISA KEV) + riesgo de compromiso" -ForegroundColor Gray
    Write-Host "   [4] Informe           " -NoNewline -ForegroundColor Cyan
    Write-Host "Plantilla .txt para rellenar a mano" -ForegroundColor Gray
    Write-Host "   [5] Servicios         " -NoNewline -ForegroundColor White
    Write-Host "Congelacion / Clonacion / Kit cliente" -ForegroundColor Gray
    Write-Host "   [6] Ayuda             " -NoNewline -ForegroundColor DarkGray
    Write-Host "Guia rapida de uso" -ForegroundColor Gray
    Write-Host "   [7] Salir             " -NoNewline -ForegroundColor Red
    Write-Host "Salir del programa" -ForegroundColor Gray
    Write-Host $RC_THIN -ForegroundColor DarkGray
    Write-Host ""
}

function Show-Help {
    Write-Host ""
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host "  GUIA RAPIDA - WINDOWS" -ForegroundColor Cyan
    Write-Host "  =================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  DIAGNOSTICO:     Analiza todo el sistema y genera JSON"
    Write-Host "  OPTIMIZACION:    Aplica mejoras segun nivel seleccionado"
    Write-Host "  VULNERABILIDADES: Escaneo CVE multi-feed (NVD/KEV/OSV/EPSS)"
    Write-Host "  INFORME:         Plantilla .txt con apartados; el tecnico la rellena y sube a Mantis"
    Write-Host "  SERVICIOS:       Congelacion / Clonacion / Kit de cliente"
    Write-Host "  (La facturacion se gestiona desde MantisBT, no desde este menu.)"
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
        $argsDiag = @()
        if ($script:TICKET_SESION) { $argsDiag += @('-Ticket', $script:TICKET_SESION) }
        & $script @argsDiag
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

    $script = Join-Path $PROJECT_ROOT "common\buscar_vulnerabilidades.py"
    if (-not (Test-Path $script)) {
        Write-Host "  [X] No encontrado: $script" -ForegroundColor Red
        Read-Host "  Presiona ENTER"
        return
    }

    $outJson = Join-Path $env:TEMP 'rc-vuln.json'
    if (Test-Path $outJson) { Remove-Item $outJson -Force -ErrorAction SilentlyContinue }

    try {
        & $py.Source $script --plataforma windows --max 300 --salida-json $outJson @args
        Write-Host ""
        Write-Host "  [OK] Escaneo completado" -ForegroundColor Green
    } catch {
        Write-Host "  [!] Error durante escaneo: $_" -ForegroundColor Yellow
    }

    Show-Riesgo -JsonPath $outJson
    Invoke-DesinstalacionVulns -JsonPath $outJson

    Read-Host "  Presiona ENTER"
}

# Muestra la probabilidad estimada de compromiso del equipo. Lee el campo
# 'riesgo' que ya calcula el escaner comun (P = 1 - prod(1 - p_i) por severidad).
# Es el indicador de exposicion que pide el registro del TFG.
function Show-Riesgo {
    param([string]$JsonPath)
    if (-not (Test-Path $JsonPath)) { return }
    try {
        $data = Get-Content -Raw -Path $JsonPath -Encoding UTF8 | ConvertFrom-Json
    } catch { return }
    $r = $data.riesgo
    if (-not $r) { return }
    $col = switch ($r.nivel) {
        'CRITICO' { 'Red' }    'ALTO' { 'Red' }
        'MEDIO'   { 'Yellow' } 'BAJO' { 'Yellow' }
        default   { 'Green' }
    }
    $interp = switch ($r.nivel) {
        'CRITICO' { 'Compromiso muy probable: hay CVE explotados activamente. Actuar de inmediato.' }
        'ALTO'    { 'Exposicion alta: parchear/actualizar con prioridad.' }
        'MEDIO'   { 'Exposicion moderada: planificar actualizaciones.' }
        'BAJO'    { 'Exposicion baja: mantener el sistema al dia.' }
        default   { 'Sin indicios relevantes de compromiso.' }
    }
    Write-Host ""
    Write-Host "  +============== EVALUACION DE RIESGO DE COMPROMISO ==============+" -ForegroundColor White
    Write-Host ("   Probabilidad estimada de compromiso : {0}%  [{1}]" -f $r.probabilidad_compromiso_pct, $r.nivel) -ForegroundColor $col
    Write-Host ("   Vulnerabilidades explotadas (KEV) ..: {0}" -f $r.factores.kev)
    Write-Host ("   Criticas (CVSS >= 9.0) .............: {0}" -f $r.factores.criticas)
    Write-Host ("   Altas (CVSS 7.0-8.9) ...............: {0}" -f $r.factores.altas)
    Write-Host ("   Otras / informativas ...............: {0}" -f $r.factores.otras)
    Write-Host ("   {0}" -f $interp) -ForegroundColor DarkGray
    Write-Host "  +===============================================================+" -ForegroundColor White
    Write-Host ""
}

# Servicios/componentes que NUNCA se proponen para desinstalar. El Spooler (cola
# de impresion) es critico para el usuario final y se excluye siempre, igual que
# componentes del sistema y runtimes.
$VULN_EXCLUIR = @('spooler','windefend','defender','microsoft','windows',
                  'visual c++','.net','redistributable','runtime','driver')

function Invoke-DesinstalacionVulns {
    param([string]$JsonPath)

    if (-not (Test-Path $JsonPath)) { return }
    try {
        $data = Get-Content -Raw -Path $JsonPath -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Host "  [!] No se pudo leer el resultado del escaneo." -ForegroundColor Yellow
        return
    }

    $avisos = @($data.avisos)
    if ($avisos.Count -eq 0) {
        Write-Host ""
        Write-Host "  [OK] Sin software marcado como peligroso (KEV o CVSS >= 7.0)." -ForegroundColor Green
        return
    }

    # Agrupar por paquete: peor CVSS + si alguno es KEV. Excluir criticos.
    $grupos = $avisos | Group-Object paquete | ForEach-Object {
        $kev  = @($_.Group | Where-Object { $_.kev }).Count -gt 0
        $cvss = ($_.Group | ForEach-Object { $_.cvss } | Where-Object { $null -ne $_ } | Measure-Object -Maximum).Maximum
        [PSCustomObject]@{ Paquete = $_.Name; Kev = $kev; Cvss = $cvss; N = $_.Count }
    } | Where-Object {
        $_.Paquete -and ($_.Kev -or ($null -ne $_.Cvss -and $_.Cvss -ge 7.0))
    } | Where-Object {
        $p = $_.Paquete.ToLower()
        -not ($VULN_EXCLUIR | Where-Object { $p -like "*$_*" })
    } | Sort-Object @{ Expression = { -not $_.Kev } }, @{ Expression = { - [double]($_.Cvss) } }

    $grupos = @($grupos)
    if ($grupos.Count -eq 0) {
        Write-Host ""
        Write-Host "  [OK] No hay software desinstalable (los criticos se excluyen siempre)." -ForegroundColor Green
        return
    }

    Write-Host ""
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor Yellow
    Write-Host "  |  SOFTWARE VULNERABLE DETECTADO                                |" -ForegroundColor Yellow
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor Yellow
    Write-Host ""
    for ($i = 0; $i -lt $grupos.Count; $i++) {
        $g = $grupos[$i]
        $tag = if ($g.Kev) { '[KEV]' } else { '     ' }
        $cv  = if ($null -ne $g.Cvss) { ('CVSS {0}' -f $g.Cvss) } else { 'CVSS  -' }
        Write-Host ("    {0}. {1} {2,-40} {3} ({4} CVE)" -f ($i + 1), $tag, $g.Paquete, $cv, $g.N)
    }
    Write-Host ""
    Write-Host "  [!] La desinstalacion es IRREVERSIBLE. Nada se toca sin que lo confirmes." -ForegroundColor Yellow
    $sel = Read-Host "  Numeros a desinstalar separados por coma (ENTER = cancelar)"
    if ([string]::IsNullOrWhiteSpace($sel)) {
        Write-Host "  Cancelado. No se desinstalo nada." -ForegroundColor Gray
        return
    }

    $indices = $sel -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    $aDesinstalar = foreach ($idx in $indices) {
        if ($idx -ge 1 -and $idx -le $grupos.Count) { $grupos[$idx - 1].Paquete }
    }
    $aDesinstalar = @($aDesinstalar | Select-Object -Unique)
    if ($aDesinstalar.Count -eq 0) {
        Write-Host "  Seleccion vacia o invalida. No se desinstalo nada." -ForegroundColor Gray
        return
    }

    Write-Host ""
    Write-Host "  Vas a desinstalar:" -ForegroundColor Yellow
    $aDesinstalar | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
    Write-Host "  Escribe 'SI' (mayusculas) para confirmar:" -ForegroundColor Red
    if ((Read-Host) -ne 'SI') {
        Write-Host "  Cancelado. No se desinstalo nada." -ForegroundColor Gray
        return
    }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    foreach ($pkg in $aDesinstalar) {
        Write-Host ""
        Write-Host "  Desinstalando '$pkg'..." -ForegroundColor Cyan
        if ($winget) {
            try {
                & winget uninstall --name $pkg --silent --accept-source-agreements 2>&1 | Out-Host
                Write-Host "  [OK] Orden de desinstalacion enviada para '$pkg'." -ForegroundColor Green
            } catch {
                Write-Host "  [!] winget fallo con '$pkg': $_" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [!] winget no disponible. Desinstala '$pkg' manualmente desde Apps y caracteristicas." -ForegroundColor Yellow
        }
    }
}

function Invoke-Informe {
    Write-Host ""
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |  GENERAR INFORME TECNICO                                      |" -ForegroundColor Cyan
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    $py = Ensure-Python
    if (-not $py) {
        Read-Host "  Presiona ENTER"
        return
    }

    $genScript = Join-Path $PROJECT_ROOT "common\generar_informe.py"
    if (-not (Test-Path $genScript)) {
        Write-Host "  [X] No encontrado: $genScript" -ForegroundColor Red
        Read-Host "  Presiona ENTER"
        return
    }

    # Buscar el JSON de diagnostico mas reciente. Si hay ticket de sesion, se
    # prioriza reparaciones\<ticket>\; si no, la carpeta legacy scripts\diagnosticos.
    $repoRoot = Split-Path -Parent $PROJECT_ROOT
    $baseRep  = if ($env:RC_REPARACIONES_DIR) { $env:RC_REPARACIONES_DIR } else { Join-Path $repoRoot 'reparaciones' }
    if ($script:TICKET_SESION) {
        $ticketDir = Join-Path $baseRep ('{0:D5}' -f [int]$script:TICKET_SESION)
    } else {
        $ticketDir = $null
    }
    if ($ticketDir -and (Test-Path $ticketDir) -and (Get-ChildItem -Path $ticketDir -Filter '*.json' -ErrorAction SilentlyContinue)) {
        $diagDir = $ticketDir
    } else {
        $diagDir = Join-Path $PROJECT_ROOT "diagnosticos"
    }
    if (-not (Test-Path $diagDir)) {
        Write-Host "  [X] No hay diagnosticos en $diagDir" -ForegroundColor Red
        Write-Host "      Ejecuta antes la opcion 1 (DIAGNOSTICO)" -ForegroundColor Yellow
        Read-Host "  Presiona ENTER"
        return
    }

    $latest = Get-ChildItem -Path $diagDir -Filter "*.json" -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if (-not $latest) {
        Write-Host "  [X] No se encontro ningun JSON en $diagDir" -ForegroundColor Red
        Write-Host "      Ejecuta antes la opcion 1 (DIAGNOSTICO)" -ForegroundColor Yellow
        Read-Host "  Presiona ENTER"
        return
    }

    Write-Host "  JSON detectado: $($latest.Name)" -ForegroundColor Gray
    Write-Host "    fecha: $($latest.LastWriteTime)" -ForegroundColor Gray
    Write-Host ""

    $useLatest = Read-Host "  Usar este JSON para pre-rellenar la cabecera? (S/n)"
    $jsonPath = $latest.FullName
    if ($useLatest -match '^[nN]') {
        $custom = Read-Host "  Ruta al JSON (ENTER = ninguno)"
        if ([string]::IsNullOrWhiteSpace($custom)) {
            $jsonPath = ''
        } elseif (-not (Test-Path $custom)) {
            Write-Host "  [X] Fichero no existe" -ForegroundColor Red
            Read-Host "  Presiona ENTER"
            return
        } else {
            $jsonPath = $custom
        }
    }

    Write-Host ""
    Write-Host "  Generando plantilla de informe (.txt)..." -ForegroundColor Yellow
    Write-Host ""

    $cliArgs = @($genScript)
    if (-not [string]::IsNullOrWhiteSpace($jsonPath)) { $cliArgs += @('--json', $jsonPath) }
    if ($script:TICKET_SESION) { $cliArgs += @('--ticket', $script:TICKET_SESION) }

    try {
        & $py.Source @cliArgs
        Write-Host ""
        Write-Host "  [i] Rellena los apartados a mano y sube tu el informe a MantisBT." -ForegroundColor Cyan
        Write-Host "  [OK] Plantilla generada" -ForegroundColor Green
    } catch {
        Write-Host "  [!] Error: $_" -ForegroundColor Yellow
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
        # optimizacion.ps1 exige -Confirm para iniciar la limpieza (evita
        # ejecuciones accidentales). El tecnico ya eligio nivel arriba.
        & $script -Nivel $nivelOpt -Confirm
        Write-Host ""
        Write-Host "  [OK] Completado" -ForegroundColor Green
    }
    else {
        Write-Host "  [X] No encontrado" -ForegroundColor Red
    }

    Read-Host "  Presiona ENTER"
}

# ── Servicios adicionales ───────────────────────────────────────────────────

function Get-BashExe {
    # WSL (preferido)
    $wsl = Get-Command wsl -ErrorAction SilentlyContinue
    if ($wsl) { return @{ Cmd = 'wsl'; Type = 'wsl' } }
    # Git Bash
    $gitBash = @(
        "${env:ProgramFiles}\Git\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
        "${env:LOCALAPPDATA}\Programs\Git\bin\bash.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($gitBash) { return @{ Cmd = $gitBash; Type = 'bash' } }
    return $null
}

function Invoke-BashScript {
    param([string]$Script, [string[]]$Args = @(), [hashtable]$BashInfo)
    if ($BashInfo.Type -eq 'wsl') {
        # Conversion explicita Windows -> WSL (C:\ruta\x -> /mnt/c/ruta/x).
        # No usar -replace con scriptblock + $args[0]: en un scriptblock de
        # -replace la variable del match es $_ (no $args), y el literal se colaba
        # como texto al shell de WSL provocando "parse error near )" (2026-06-02).
        if ($Script -match '^([A-Za-z]):(.*)$') {
            $linuxPath = '/mnt/' + $Matches[1].ToLower() + ($Matches[2] -replace '\\', '/')
        } else {
            $linuxPath = $Script -replace '\\', '/'
        }
        & wsl bash $linuxPath @Args
    } else {
        & $BashInfo.Cmd $Script @Args
    }
}

function Invoke-Congelacion {
    Write-Host ""
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor White
    Write-Host "  |  CONGELACION DE SISTEMAS (Windows)                            |" -ForegroundColor White
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor White
    Write-Host ""
    Write-Host "    1. Estado actual                (Status)"    -ForegroundColor Cyan
    Write-Host "    2. Configurar / Verificar       (Configure)" -ForegroundColor Cyan
    Write-Host "    3. CONGELAR sistema             (Freeze)"    -ForegroundColor Yellow
    Write-Host "    4. DESCONGELAR sistema          (Thaw)"      -ForegroundColor Yellow
    Write-Host "    5. Volver"                                    -ForegroundColor Gray
    Write-Host ""

    $s = Join-Path $SERVICIOS_DIR "congelacion\congelacion-windows.ps1"
    if (-not (Test-Path $s)) {
        Write-Host "  [X] Script no encontrado: $s" -ForegroundColor Red
        Read-Host "  Presiona ENTER"
        return
    }

    $op = Read-Host "  Selecciona (1-5)"
    switch ($op) {
        "1" { & $s -Action Status }
        "2" { & $s -Action Configure }
        "3" {
            Write-Host ""
            Write-Host "  [!] CONGELAR: el sistema descartara cambios tras cada reinicio." -ForegroundColor Yellow
            Write-Host "      Escribe 'SI' para confirmar:" -ForegroundColor Yellow
            if ((Read-Host) -eq "SI") { & $s -Action Freeze -Confirm }
        }
        "4" {
            Write-Host ""
            Write-Host "  [!] DESCONGELAR: los cambios se guardaran tras el reinicio." -ForegroundColor Yellow
            Write-Host "      Escribe 'SI' para confirmar:" -ForegroundColor Yellow
            if ((Read-Host) -eq "SI") { & $s -Action Thaw -Confirm }
        }
        "5" { return }
        default { Write-Host "  Opcion no valida" -ForegroundColor Red }
    }
    Write-Host ""
    Read-Host "  Presiona ENTER"
}

function Invoke-Clonacion {
    $bash = Get-BashExe
    if (-not $bash) {
        Write-Host ""
        Write-Host "  [!] Clonacion requiere WSL o Git Bash instalado en Windows." -ForegroundColor Yellow
        Write-Host "      - WSL:      wsl --install  (reinicia y vuelve a ejecutar)" -ForegroundColor Gray
        Write-Host "      - Git Bash: https://git-scm.com/download/win" -ForegroundColor Gray
        Write-Host ""
        Read-Host "  Presiona ENTER"
        return
    }

    Write-Host ""
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor White
    Write-Host "  |  CLONACION DE SISTEMAS                                        |" -ForegroundColor White
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor White
    Write-Host ""
    Write-Host "    1. Registrar imagen en manifiesto"  -ForegroundColor Cyan
    Write-Host "    2. Verificar integridad de imagen"  -ForegroundColor Cyan
    Write-Host "    3. Volver"                           -ForegroundColor Gray
    Write-Host ""

    $regScript = Join-Path $SERVICIOS_DIR "clonacion\registrar-imagen.sh"
    $verScript = Join-Path $SERVICIOS_DIR "clonacion\verificar-imagen.sh"

    $op = Read-Host "  Selecciona (1-3)"
    switch ($op) {
        "1" {
            $img    = Read-Host "  Ruta imagen o carpeta Clonezilla"
            $equipo = Read-Host "  Nombre del equipo (ej: pc-cliente-01)"
            $so     = Read-Host "  SO (windows|linux|macos)"
            $estado = Read-Host "  Estado (limpio|post-instalacion|produccion)"
            $notas  = Read-Host "  Notas (ENTER = ninguna)"
            Write-Host ""
            Write-Host "  Calculando SHA-256..." -ForegroundColor Yellow
            Invoke-BashScript -Script $regScript -BashInfo $bash `
                -Args @("--imagen", $img, "--equipo", $equipo, "--so", $so, "--estado", $estado, "--notas", $notas)
        }
        "2" {
            $img = Read-Host "  Ruta imagen (o ENTER para buscar por ID)"
            if ($img) {
                Invoke-BashScript -Script $verScript -BashInfo $bash -Args @("--imagen", $img)
            } else {
                $id = Read-Host "  ID del manifiesto"
                Invoke-BashScript -Script $verScript -BashInfo $bash -Args @("--id", $id)
            }
        }
        "3" { return }
        default { Write-Host "  Opcion no valida" -ForegroundColor Red }
    }
    Write-Host ""
    Read-Host "  Presiona ENTER"
}

function Invoke-KitCliente {
    Write-Host ""
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor White
    Write-Host "  |  KIT DE IMPLANTACION EN CLIENTE                               |" -ForegroundColor White
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor White
    Write-Host ""

    $kitScript = Join-Path $SERVICIOS_DIR "kit\construir-kit.ps1"
    if (-not (Test-Path $kitScript)) {
        Write-Host "  [X] Script no encontrado: $kitScript" -ForegroundColor Red
        Read-Host "  Presiona ENTER"
        return
    }

    $anydesk = Read-Host "  Ruta a anydesk-portable.exe (ENTER = ./anydesk.exe)"
    if (-not $anydesk) { $anydesk = ".\anydesk.exe" }

    $outdir = Read-Host "  Directorio de salida (ENTER = ./dist)"
    if (-not $outdir) { $outdir = ".\dist" }

    $contacto = Read-Host "  Contacto tecnico (ENTER = tecnicos@resolvecore.website)"
    if (-not $contacto) { $contacto = "tecnicos@resolvecore.website" }

    Write-Host ""
    Write-Host "  Construyendo kit..." -ForegroundColor Yellow

    & $kitScript -AnyDeskPath $anydesk -OutputDir $outdir -ContactoTecnico $contacto

    Write-Host ""
    Read-Host "  Presiona ENTER"
}

function Invoke-Servicios {
    while ($true) {
        Show-Banner
        Write-Host "  +---------------------------------------------------------------+" -ForegroundColor White
        Write-Host "  |  SERVICIOS ADICIONALES                                        |" -ForegroundColor White
        Write-Host "  +---------------------------------------------------------------+" -ForegroundColor White
        Write-Host ""
        Write-Host "    1.  [CONGELACION]  - Estado de referencia restaurable (Win)" -ForegroundColor Cyan
        Write-Host "    2.  [CLONACION]    - Registrar / verificar imagen de disco"  -ForegroundColor Cyan
        Write-Host "    3.  [KIT CLIENTE]  - Empaquetar kit AnyDesk + scripts"       -ForegroundColor Cyan
        Write-Host "    4.  [VOLVER]       - Menu principal"                          -ForegroundColor Gray
        Write-Host ""
        Write-Host "  +---------------------------------------------------------------+" -ForegroundColor White
        Write-Host ""

        $op = Read-Host "  Selecciona (1-4)"
        switch ($op) {
            "1" { Invoke-Congelacion }
            "2" { Invoke-Clonacion }
            "3" { Invoke-KitCliente }
            "4" { return }
            default { Write-Host "  Opcion no valida" -ForegroundColor Red; Start-Sleep 1 }
        }
    }
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
    Show-Banner
    Read-TicketSesion
    while ($true) {
        Show-Banner

        if (-not $isAdmin) {
            Write-Host "  [!] Sin permisos admin - funcionalidad limitada" -ForegroundColor Yellow
            Write-Host ""
        }

        Show-Menu

        $opcion = Read-Host "  Selecciona (1-7)"

        switch ($opcion) {
            "1" { Invoke-Diagnostico }
            "2" { Invoke-Optimizacion }
            "3" { Invoke-Vulnerabilidades }
            "4" { Invoke-Informe }
            "5" { Invoke-Servicios }
            "6" { Show-Help }
            "7" {
                Write-Host "  [ResolveCore] Sesion finalizada correctamente." -ForegroundColor Cyan
                Write-Host "  Gracias $usuario por utilizar nuestras herramientas de soporte." -ForegroundColor Gray
                Write-Host "  Hasta la proxima!" -ForegroundColor White
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