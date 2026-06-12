#Requires -Version 5.1
<#
.SYNOPSIS
    ResolveCore — Diagnóstico básico de un equipo Windows.

.DESCRIPTION
    Lanza una recogida rápida de información del sistema (CPU, RAM, discos,
    antivirus) y la vuelca en un JSON con marca de tiempo. La salida la
    consume luego el técnico para rellenar a mano la plantilla de informe .txt.

    Pensado para Windows 10 y 11. No instala nada — solo consulta CIM.

.PARAMETER OutputDir
    Carpeta de salida explícita del JSON. Por defecto vacío: la salida se
    organiza por ticket en <repo>\diagnosticos\tickets\<NNNNN>\windows\ (o \sin-ticket\windows\).

.EXAMPLE
    .\diagnostico.ps1
    .\diagnostico.ps1 -OutputDir C:\Temp

.NOTES
    Autor:   Francisco Vidal Mateo (GitHub: Haplee)
    Versión: 2.2
#>

param(
    # Carpeta de salida explicita. Vacio por defecto: la salida se organiza por
    # ticket en <repo>\diagnosticos\tickets\ (ver resolucion mas abajo). Igualado
    # al patron de optimizacion.ps1 para evitar el default fantasma con $PSScriptRoot.
    [string]$OutputDir = '',

    # Numero de ticket MantisBT. Si se indica, el JSON se guarda en
    # <repo>/diagnosticos/tickets/<NNNNN>/windows/diagnostico.json (zero-padded a 5 digitos).
    # Sin ticket (y sin -OutputDir explicito) cae a diagnosticos/tickets/sin-ticket/windows/.
    # Base configurable con la variable de entorno RC_REPARACIONES_DIR.
    [string]$Ticket = '',

    # Sin salida por consola (modo CI / invocacion automatizada). El JSON se
    # escribe igual; solo se omite el resumen legible y los Write-Host.
    [switch]$Silent,

    # ── Subida automática del JSON a WordPress (Fase 5) ──────────────────────
    # Si se indican -ClientEmail y un token (parámetro o variable de entorno
    # RC_FLEET_TOKEN), el script publica el diagnóstico en el endpoint REST de
    # la flota tras generarlo, sin que el técnico lo copie a mano.
    [string]$ClientEmail = $env:RC_CLIENT_EMAIL,
    [string]$ApiUrl      = $(if ($env:RC_FLEET_URL) { $env:RC_FLEET_URL } else { 'https://resolvecore.website/wp-json/rc/v1/fleet' }),
    [string]$Token       = $env:RC_FLEET_TOKEN,
    [int]$TicketId       = 0
)

# ── Blindaje de binding: si -OutputDir recibe algo que parece un nombre de ───
# parametro (p.ej. "-Ticket" pasado posicionalmente), lo ignoramos para no crear
# una carpeta literal "-Ticket" junto al script.
if ($OutputDir -and $OutputDir -match '^-') {
    Write-Warning "OutputDir '$OutputDir' parece un parametro mal pasado; se ignora."
    $OutputDir = ''
}

# ── Aviso de privilegios (no bloqueante) ─────────────────────────────────────
# Sin Administrador algunas consultas CIM/red quedan incompletas; avisamos en
# lugar de dejar caer excepciones sueltas. No abortamos: el script degrada con
# gracia (paridad con ResolveCore.ps1).
$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin -and -not $Silent) {
    Write-Warning "Sin privilegios de Administrador: algunas metricas quedaran incompletas."
}

# ── Recogida vía CIM ────────────────────────────────────────────────────────
# Get-CimInstance es más rápido que Get-WmiObject y no tira RPC clásico,
# así que va mejor en entornos con firewall apretado.

try {
    $cpuInfo = Get-CimInstance Win32_Processor | Select-Object -First 1
    $osInfo  = Get-CimInstance Win32_OperatingSystem
    $csInfo  = Get-CimInstance Win32_ComputerSystem
} catch {
    Write-Host "ERROR: no se pudieron leer datos del sistema vía CIM."
    Write-Host $_.Exception.Message
    exit 2
}

if (-not $Silent) { Write-Host "Recogiendo métricas de $env:COMPUTERNAME..." }

# ── Recogida ampliada (cada bloque aislado: si uno falla, el resto sigue) ─────

# Servicios criticos. El Spooler SIEMPRE se reporta, nunca se toca ni desinstala.
$serviciosCriticos = @(
    @('Spooler','wuauserv','WinDefend','WSearch','BITS') | ForEach-Object {
        $svc = Get-Service -Name $_ -ErrorAction SilentlyContinue
        if ($svc) {
            [ordered]@{ nombre = $svc.Name; display = $svc.DisplayName; estado = "$($svc.Status)" }
        }
    }
)

# Actualizaciones de software pendientes (Windows Update Agent). null si falla.
$updatesPend = $null
try {
    $wuSession  = New-Object -ComObject Microsoft.Update.Session
    $wuSearcher = $wuSession.CreateUpdateSearcher()
    $updatesPend = $wuSearcher.Search("IsInstalled=0 and Type='Software'").Updates.Count
} catch { $updatesPend = $null }

# Top 10 procesos por CPU acumulada.
$procesosTop = @(
    Get-Process -ErrorAction SilentlyContinue |
        Sort-Object CPU -Descending |
        Select-Object -First 10 |
        ForEach-Object {
            [ordered]@{
                nombre = $_.ProcessName
                cpu_s  = if ($null -ne $_.CPU) { [math]::Round($_.CPU, 1) } else { $null }
                ram_mb = [math]::Round($_.WorkingSet64 / 1MB, 1)
            }
        }
)

# Red: IP/gateway/DNS del adaptador con salida + puertos en escucha + interfaces.
$red = [ordered]@{ ip = $null; gateway = $null; dns = @(); puertos_escucha = @(); interfaces = @(); conexiones_estab = $null }
try {
    $netCfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
              Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1
    if ($netCfg) {
        $red.ip      = ($netCfg.IPv4Address.IPAddress | Select-Object -First 1)
        $red.gateway = ($netCfg.IPv4DefaultGateway.NextHop | Select-Object -First 1)
        $red.dns     = @($netCfg.DNSServer.ServerAddresses)
    }
} catch {}
try {
    $red.puertos_escucha = @(
        Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty LocalPort -Unique | Sort-Object
    )
} catch {}

# SMART / prediccion de fallo de disco (no siempre expuesto por el driver).
$discoSmart = $null
try {
    $pred = Get-CimInstance -Namespace root/wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue
    if ($pred) {
        $discoSmart = @(
            $pred | ForEach-Object {
                [ordered]@{ instancia = $_.InstanceName; fallo_predicho = [bool]$_.PredictFailure }
            }
        )
    }
} catch { $discoSmart = $null }

# Sistema: build + uptime + ultimo arranque.
$sistema = [ordered]@{
    nombre             = $osInfo.Caption
    version            = $osInfo.Version
    build              = $osInfo.BuildNumber
    uptime_horas       = $null
    ultimo_arranque    = $null
    reinicio_requerido = $null
}
try {
    $boot = $osInfo.LastBootUpTime
    if ($boot) {
        $sistema.ultimo_arranque = (Get-Date $boot -Format 'o')
        $sistema.uptime_horas    = [math]::Round(((Get-Date) - $boot).TotalHours, 1)
    }
} catch {}

# Seguridad: Defender, Firewall, UAC.
$seguridad = [ordered]@{ defender_activo = $null; firewall = $null; uac = $null }
try {
    $defStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($defStatus) { $seguridad.defender_activo = [bool]$defStatus.AntivirusEnabled }
} catch {}
try {
    $fwProfiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
    if ($fwProfiles) { $seguridad.firewall = [bool]( @($fwProfiles | Where-Object { $_.Enabled }).Count -gt 0 ) }
} catch {}
try {
    $uacKey = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -ErrorAction SilentlyContinue
    if ($uacKey) { $seguridad.uac = [bool]($uacKey.EnableLUA -eq 1) }
} catch {}

# ── Paridad con Linux: GPU, red ampliada, usuarios, swap, top por memoria, ────
#    reinicio pendiente y servicios fallidos. Cada bloque aislado en try/catch.

# GPU: primer adaptador de video (equivalente a 'gpu' de Linux).
$gpu = $null
try {
    $gpu = (Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty Name)
} catch {}

# Interfaces de red activas con MAC e IP (equivalente a red.interfaces[]).
try {
    $red.interfaces = @(
        Get-NetAdapter -ErrorAction SilentlyContinue |
            Where-Object { $_.Status -eq 'Up' } |
            ForEach-Object {
                $ipv4 = Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                        Select-Object -First 1 -ExpandProperty IPAddress
                [ordered]@{ nombre = $_.Name; mac = $_.MacAddress; ip = $ipv4 }
            }
    )
} catch {}

# Conexiones TCP establecidas (equivalente a red.conexiones_estab).
try {
    $red.conexiones_estab = @(Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue).Count
} catch {}

# Usuarios con sesion iniciada (equivalente a usuarios_conectados[]).
$usuarios = @()
try {
    $usuarios = @(
        Get-CimInstance Win32_LoggedOnUser -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Antecedent.Name } |
            Where-Object { $_ } | Sort-Object -Unique
    )
} catch {}

# Swap / archivo de paginacion (equivalente a swap_total_gb / swap_libre_gb).
$swapTotalGb = $null; $swapLibreGb = $null
try {
    $pfAll = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue
    if ($pfAll) {
        $totMb = ($pfAll | Measure-Object -Property AllocatedBaseSize -Sum).Sum
        $usoMb = ($pfAll | Measure-Object -Property CurrentUsage -Sum).Sum
        $swapTotalGb = [math]::Round($totMb / 1024, 2)
        $swapLibreGb = [math]::Round(($totMb - $usoMb) / 1024, 2)
    }
} catch {}

# Top 10 procesos por memoria (working set), complemento de procesos_top (CPU).
$procesosTopMem = @(
    Get-Process -ErrorAction SilentlyContinue |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First 10 |
        ForEach-Object {
            [ordered]@{
                nombre = $_.ProcessName
                ram_mb = [math]::Round($_.WorkingSet64 / 1MB, 1)
                cpu_s  = if ($null -ne $_.CPU) { [math]::Round($_.CPU, 1) } else { $null }
            }
        }
)

# Reinicio pendiente (equivalente a sistema.reinicio_requerido de Linux).
try {
    $pendiente = $false
    $rebootKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    foreach ($k in $rebootKeys) { if (Test-Path $k) { $pendiente = $true } }
    $pfr = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    if ($pfr -and $pfr.PendingFileRenameOperations) { $pendiente = $true }
    $sistema.reinicio_requerido = $pendiente
} catch {}

# Servicios automaticos que no estan corriendo (equivalente a servicios_fallidos[]).
$serviciosFallidos = @()
try {
    $serviciosFallidos = @(
        Get-Service -ErrorAction SilentlyContinue |
            Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' } |
            ForEach-Object { $_.Name }
    )
} catch {}

# ── Construcción del objeto de salida ───────────────────────────────────────
# Usamos [ordered] para que el JSON salga en el mismo orden que aquí, no
# en el aleatorio de un hashtable normal. Estructura PLANA por diseño
# (ver docs/scripting/schema-diagnostico.md).

$resultado = [ordered]@{
    # _meta lo exige el endpoint /wp-json/rc/v1/fleet para identificar el agente.
    _meta = [ordered]@{
        plataforma = 'windows'
        hostname   = $env:COMPUTERNAME
        version    = '2.2'
    }
    timestamp = (Get-Date -Format 'o')
    hostname  = $env:COMPUTERNAME
    os        = "$($osInfo.Caption) $($osInfo.Version)"
    sistema   = $sistema

    cpu = [ordered]@{
        name  = $cpuInfo.Name.Trim()
        cores = $cpuInfo.NumberOfCores
        load  = $cpuInfo.LoadPercentage
        # Windows no expone load average (1/5/15 min) como Linux: null por paridad.
        carga_5min  = $null
        carga_15min = $null
    }

    ram = [ordered]@{
        total_gb      = [math]::Round($csInfo.TotalPhysicalMemory / 1GB, 2)
        free_gb       = [math]::Round($osInfo.FreePhysicalMemory / 1MB, 2)
        swap_total_gb = $swapTotalGb
        swap_libre_gb = $swapLibreGb
    }

    gpu = $gpu

    discos = @(
        Get-PSDrive -PSProvider FileSystem |
            Where-Object { $null -ne $_.Used } |
            ForEach-Object {
                [ordered]@{
                    drive    = $_.Name
                    used_gb  = [math]::Round($_.Used / 1GB, 2)
                    free_gb  = [math]::Round($_.Free / 1GB, 2)
                    total_gb = [math]::Round(($_.Used + $_.Free) / 1GB, 2)
                }
            }
    )

    disco_smart = $discoSmart

    antivirus = @(
        # Algunas instalaciones limpias no exponen SecurityCenter2 — capturamos
        # silenciosamente para no abortar el diagnóstico entero por esto.
        Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct `
            -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty displayName
    )

    seguridad          = $seguridad
    servicios_criticos = $serviciosCriticos
    servicios_fallidos = $serviciosFallidos
    actualizaciones    = [ordered]@{ pendientes = $updatesPend }
    procesos_top       = $procesosTop
    procesos_top_mem   = $procesosTopMem
    usuarios_conectados = $usuarios
    red                = $red
}

# ── Volcado del JSON ────────────────────────────────────────────────────────

# ── Resolucion de la carpeta de salida (organizada por ticket) ───────────────
# Prioridad: -OutputDir explicito > diagnosticos/tickets/<ticket> > diagnosticos/tickets/sin-ticket.
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'

if ($OutputDir) {
    # El llamante fijo una carpeta concreta (CI, -O del launcher): se respeta.
    $destDir = $OutputDir
    $ruta    = Join-Path $destDir "diagnostico_${env:COMPUTERNAME}_${ts}.json"
} else {
    # Blindaje: ejecutado de formas en que $PSScriptRoot puede venir vacio (dot-
    # source, pipe), caeriamos al CWD (p.ej. C:\Windows\System32 como admin). Se
    # resuelve siempre el directorio real del script para anclar diagnosticos/tickets/.
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
    $baseRep  = if ($env:RC_REPARACIONES_DIR) { $env:RC_REPARACIONES_DIR } else { Join-Path (Join-Path $repoRoot 'diagnosticos') 'tickets' }
    if ($Ticket -and $Ticket -match '^\d+$') {
        $destDir = Join-Path (Join-Path $baseRep ('{0:D5}' -f [int]$Ticket)) 'windows'
        $ruta    = Join-Path $destDir 'diagnostico.json'
        # No sobrescribir: si ya existe, sufijo _vN y aviso.
        if (Test-Path $ruta) {
            $n = 2
            while (Test-Path (Join-Path $destDir "diagnostico_v$n.json")) { $n++ }
            $ruta = Join-Path $destDir "diagnostico_v$n.json"
            if (-not $Silent) { Write-Host "  [i] Ya existia diagnostico.json; guardando como diagnostico_v$n.json" -ForegroundColor Yellow }
        }
    } else {
        $destDir = Join-Path (Join-Path $baseRep 'sin-ticket') 'windows'
        $ruta    = Join-Path $destDir "diagnostico_${env:COMPUTERNAME}_${ts}.json"
        if (-not $Silent) { Write-Host "  [!] No se ha indicado ticket. Guardando en diagnosticos/tickets/sin-ticket/windows/" -ForegroundColor Yellow }
    }
}

if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}

$resultado | ConvertTo-Json -Depth 6 | Set-Content -Path $ruta -Encoding UTF8

# ── Resumen legible en terminal ──────────────────────────────────────────────
# El tecnico debe poder leer los datos clave sin abrir el JSON.
if (-not $Silent) {
    $primerDisco = $resultado.discos | Select-Object -First 1
    $svcParados  = @($serviciosCriticos | Where-Object { $_.estado -ne 'Running' })

    Write-Host ""
    Write-Host "  +-------------------- RESUMEN DEL DIAGNOSTICO --------------------+" -ForegroundColor Cyan
    Write-Host ("   Equipo .......: {0}" -f $resultado.hostname)
    Write-Host ("   Sistema ......: {0} (build {1})" -f $sistema.nombre, $sistema.build)
    if ($null -ne $sistema.uptime_horas) {
        Write-Host ("   Uptime .......: {0} h" -f $sistema.uptime_horas)
    }
    Write-Host ("   CPU ..........: {0} ({1} cores, carga {2}%)" -f $resultado.cpu.name, $resultado.cpu.cores, $resultado.cpu.load)
    if ($gpu) { Write-Host ("   GPU ..........: {0}" -f $gpu) }
    Write-Host ("   RAM ..........: {0} GB libres de {1} GB" -f $resultado.ram.free_gb, $resultado.ram.total_gb)
    if ($primerDisco) {
        Write-Host ("   Disco {0} ......: {1} GB libres de {2} GB" -f $primerDisco.drive, $primerDisco.free_gb, $primerDisco.total_gb)
    }
    if ($red.ip)      { Write-Host ("   Red ..........: IP {0} | GW {1} | DNS {2}" -f $red.ip, $red.gateway, ($red.dns -join ', ')) }
    Write-Host ("   Antivirus ....: {0}" -f (($resultado.antivirus -join ', ') -replace '^$','(no detectado)'))
    Write-Host ("   Seguridad ....: Defender={0} Firewall={1} UAC={2}" -f $seguridad.defender_activo, $seguridad.firewall, $seguridad.uac)
    if ($null -ne $updatesPend) { Write-Host ("   Updates ......: {0} pendientes" -f $updatesPend) }
    if ($svcParados.Count -gt 0) {
        Write-Host ("   [!] Servicios parados: {0}" -f (($svcParados | ForEach-Object { $_.nombre }) -join ', ')) -ForegroundColor Yellow
    }
    if ($serviciosFallidos.Count -gt 0) {
        Write-Host ("   [!] Servicios auto sin arrancar: {0}" -f ($serviciosFallidos -join ', ')) -ForegroundColor Yellow
    }
    if ($sistema.reinicio_requerido) {
        Write-Host "   [!] Reinicio pendiente del sistema" -ForegroundColor Yellow
    }
    Write-Host "   Top procesos (CPU):"
    foreach ($p in ($resultado.procesos_top | Select-Object -First 5)) {
        Write-Host ("     - {0,-22} cpu={1}s ram={2}MB" -f $p.nombre, $p.cpu_s, $p.ram_mb) -ForegroundColor Gray
    }
    Write-Host "  +-----------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Listo. Diagnóstico guardado en:"
    Write-Host "  $ruta"
}

# ── Subida automática a WordPress (Fase 5) ──────────────────────────────────
# Solo se intenta si hay email de cliente y token. Cualquier fallo de red se
# avisa pero NO aborta el script: el JSON local ya está a salvo en disco.

if ($ClientEmail -and $Token) {
    if (-not $Silent) { Write-Host "Subiendo diagnóstico a $ApiUrl ..." }

    $payload = [ordered]@{
        client_email = $ClientEmail
        diagnostico  = $resultado
    }
    if ($TicketId -gt 0) { $payload.ticket_id = $TicketId }

    try {
        $resp = Invoke-RestMethod -Method Post -Uri $ApiUrl `
            -Headers @{ Authorization = "Bearer $Token" } `
            -ContentType 'application/json; charset=utf-8' `
            -Body ($payload | ConvertTo-Json -Depth 6) `
            -TimeoutSec 15
        if (-not $Silent) {
            Write-Host "  Subida OK (accion=$($resp.action), host_id=$($resp.host_id))."
            # El score 0-100 lo calcula el servidor (rc_fleet_score() en rc-fleet)
            # y viene en la respuesta; aquí solo se muestra.
            if ($null -ne $resp.score) {
                Write-Host "  Puntuación de salud (servidor): $($resp.score)/100"
            }
        }
    } catch {
        Write-Warning "No se pudo subir el diagnóstico: $($_.Exception.Message)"
        Write-Warning "El JSON local sigue disponible en: $ruta"
    }
} else {
    if (-not $Silent) { Write-Host "(Subida automática omitida: define -ClientEmail y RC_FLEET_TOKEN para activarla.)" }
}
