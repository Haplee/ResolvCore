#Requires -Version 5.1
<#
.SYNOPSIS
    ResolveCore — Optimización de Windows con acta de acciones.

.DESCRIPTION
    Vacía las carpetas TEMP del usuario y del sistema, la caché de Windows
    Update y la papelera de reciclaje, midiendo cuánto se libera en cada paso.
    Detecta procesos de alto consumo y programas de arranque (el análogo a
    "apps en segundo plano"). Deja constancia de TODO lo realizado en un acta
    para técnico y cliente:
        diagnosticos\tickets\<NNNNN>\optimizacion.txt   (legible, para el cliente)
        diagnosticos\tickets\<NNNNN>\optimizacion.json  (estructurado, técnico/flota)

    Idealmente como Administrador para que la limpieza de SoftwareDistribution
    funcione.

.PARAMETER Confirm
    Sin esta flag el script no hace nada (evita ejecución accidental por doble clic).

.PARAMETER StopHogs
    Además de detectar, detiene (Stop-Process) los procesos de mayor consumo
    que NO sean críticos del sistema.

.PARAMETER Ticket
    Nº de ticket MantisBT: el acta se guarda en diagnosticos\tickets\<NNNNN>\.

.EXAMPLE
    .\optimizacion.ps1 -Confirm
    .\optimizacion.ps1 -Confirm -Ticket 42 -StopHogs

.NOTES
    Autor:   Francisco Vidal Mateo (GitHub: Haplee)
    Versión: 3.0
#>

param(
    [switch]$Confirm,
    [switch]$StopHogs,
    [string]$Ticket = '',
    [string]$OutputDir = '',

    # ── Subida automática del acta a WordPress (Fase 5) ──────────────────────
    [string]$ClientEmail = $env:RC_CLIENT_EMAIL,
    [string]$ApiUrl      = $(if ($env:RC_FLEET_URL) { $env:RC_FLEET_URL } else { 'https://resolvecore.website/wp-json/rc/v1/fleet' }),
    [string]$Token       = $env:RC_FLEET_TOKEN,
    [int]$TicketId       = 0
)

if (-not $Confirm) {
    Write-Host "Ejecuta de nuevo con -Confirm para iniciar la limpieza."
    Write-Host "Ejemplo: .\optimizacion.ps1 -Confirm -Ticket 42 [-StopHogs]"
    exit 0
}

$hostName = $env:COMPUTERNAME

# ── Aviso de privilegios (no bloqueante) ─────────────────────────────────────
# Sin Administrador la limpieza de SoftwareDistribution (Windows Update) y otras
# acciones quedan incompletas; avisamos en lugar de fallar a medias. No abortamos.
$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin) {
    Write-Warning "Sin privilegios de Administrador: algunas acciones de limpieza quedaran incompletas."
}

# ── Registro de acciones (acta) ──────────────────────────────────────────────
$acciones  = [System.Collections.ArrayList]::new()
$hallazgos = [System.Collections.ArrayList]::new()
$liberadoBytes = [int64]0

# registra paso/descripcion/estado/resultado y lo muestra en vivo.
function Add-Accion {
    param([string]$Paso, [string]$Desc, [string]$Estado, [string]$Resultado)
    [void]$acciones.Add([ordered]@{ paso = $Paso; descripcion = $Desc; resultado = $Resultado; estado = $Estado })
    $marca = switch ($Estado) { 'ok' { 'OK' } 'fallo' { 'FALLO' } default { 'OMITIDO' } }
    Write-Host ("[+] {0} ... {1} ({2})" -f $Desc, $marca, $Resultado)
}

function Get-DirSize {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return [int64]0 }
    try {
        $s = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue |
              Measure-Object -Property Length -Sum).Sum
        if ($null -eq $s) { return [int64]0 }
        return [int64]$s
    } catch { return [int64]0 }
}

function Format-Bytes {
    param([int64]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    return ("{0:N1} MB" -f ($Bytes / 1MB))
}

# ── 1. Carpetas TEMP / caché de Windows Update ──────────────────────────────
$rutas = @(
    @{ paso = 'temp_usuario'; desc = 'TEMP del usuario';            path = $env:TEMP },
    @{ paso = 'temp_sistema'; desc = 'TEMP del sistema';            path = "$env:SystemRoot\Temp" },
    @{ paso = 'temp_local';   desc = 'TEMP de LocalAppData';        path = "$env:LOCALAPPDATA\Temp" },
    @{ paso = 'wsus_cache';   desc = 'Caché de Windows Update';     path = "$env:SystemRoot\SoftwareDistribution\Download" }
)

foreach ($r in $rutas) {
    if (-not (Test-Path $r.path)) {
        Add-Accion -Paso $r.paso -Desc $r.desc -Estado 'omitido' -Resultado 'ruta no existe'
        continue
    }
    $antes = Get-DirSize $r.path
    Get-ChildItem $r.path -Recurse -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    $despues = Get-DirSize $r.path
    $dif = $antes - $despues
    if ($dif -lt 0) { $dif = 0 }
    $liberadoBytes += $dif
    Add-Accion -Paso $r.paso -Desc $r.desc -Estado 'ok' -Resultado ("{0} liberados" -f (Format-Bytes $dif))
}

# ── 2. Papelera de reciclaje ────────────────────────────────────────────────
try {
    Clear-RecycleBin -Force -ErrorAction Stop
    Add-Accion -Paso 'papelera' -Desc 'Papelera de reciclaje' -Estado 'ok' -Resultado 'vaciada'
} catch {
    Add-Accion -Paso 'papelera' -Desc 'Papelera de reciclaje' -Estado 'omitido' -Resultado 'ya vacía o sin acceso'
}

# ── 3. Detección de procesos de alto consumo ────────────────────────────────
# Críticos que NUNCA se detienen, ni con -StopHogs.
$criticos = @('System','Idle','csrss','wininit','winlogon','services','lsass','smss','svchost','explorer','dwm')
$detectados = 0; $detenidos = 0

Write-Host "[+] Detectando procesos de alto consumo..."
$topCpu = Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CPU -gt 0 } |
    Sort-Object CPU -Descending | Select-Object -First 5
foreach ($p in $topCpu) {
    $detectados++
    $accion = 'reportado'
    if ($StopHogs -and ($criticos -notcontains $p.ProcessName)) {
        try { Stop-Process -Id $p.Id -Force -ErrorAction Stop; $accion = 'detenido'; $detenidos++ } catch {}
    }
    [void]$hallazgos.Add([ordered]@{
        nombre  = $p.ProcessName
        tipo    = 'cpu'
        detalle = ("pid {0}, cpu {1}s, ram {2} MB" -f $p.Id, [math]::Round($p.CPU,1), [math]::Round($p.WorkingSet64/1MB,1))
        accion  = $accion
    })
    Write-Host ("[+]   - {0} (pid {1}): cpu {2}s ram {3}MB -> {4}" -f $p.ProcessName, $p.Id, [math]::Round($p.CPU,1), [math]::Round($p.WorkingSet64/1MB,1), $accion)
}

# ── 4. Programas de arranque (análogo a apps en segundo plano) ──────────────
# Solo se REPORTAN: deshabilitar autoarranque es decisión del técnico/cliente.
try {
    $startup = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue
    foreach ($s in $startup) {
        [void]$hallazgos.Add([ordered]@{
            nombre  = $s.Name
            tipo    = 'arranque'
            detalle = ("{0} ({1})" -f $s.Command, $s.Location)
            accion  = 'reportado'
        })
    }
    if ($startup) {
        Write-Host ("[+]   {0} programas de arranque detectados (solo reporte)" -f @($startup).Count)
    }
} catch {}

if ($detectados -eq 0) { Write-Host "[+]   (sin procesos destacables por CPU)" }
if (-not $StopHogs -and $detectados -gt 0) { Write-Host "[+]   (solo reporte; usa -StopHogs para detenerlos)" }

# ── Resolución de la carpeta de salida (organizada por ticket) ──────────────
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
if ($OutputDir) {
    $destDir  = $OutputDir
    $jsonFile = Join-Path $destDir "optimizacion_${hostName}_${ts}.json"
    $txtFile  = Join-Path $destDir "optimizacion_${hostName}_${ts}.txt"
    $ticketStr = 'sin-ticket'
} else {
    # Blindaje: si $PSScriptRoot viene vacio (dot-source/pipe) caeriamos al CWD
    # (C:\Windows\System32 como admin). Resolvemos el directorio real del script.
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
    $baseRep  = if ($env:RC_REPARACIONES_DIR) { $env:RC_REPARACIONES_DIR } else { Join-Path (Join-Path $repoRoot 'diagnosticos') 'tickets' }
    if ($Ticket -and $Ticket -match '^\d+$') {
        $ticketStr = '{0:D5}' -f [int]$Ticket
        $destDir   = Join-Path $baseRep $ticketStr
        $jsonFile  = Join-Path $destDir 'optimizacion.json'
        $txtFile   = Join-Path $destDir 'optimizacion.txt'
        if (Test-Path $jsonFile) {
            $n = 2
            while (Test-Path (Join-Path $destDir "optimizacion_v$n.json")) { $n++ }
            $jsonFile = Join-Path $destDir "optimizacion_v$n.json"
            $txtFile  = Join-Path $destDir "optimizacion_v$n.txt"
            Write-Host "  [i] Ya existia optimizacion.json; guardando como optimizacion_v$n.json" -ForegroundColor Yellow
        }
    } else {
        $ticketStr = 'sin-ticket'
        $destDir   = Join-Path $baseRep 'sin-ticket'
        $jsonFile  = Join-Path $destDir "optimizacion_${hostName}_${ts}.json"
        $txtFile   = Join-Path $destDir "optimizacion_${hostName}_${ts}.txt"
        Write-Host "  [!] No se ha indicado ticket. Guardando acta en diagnosticos\tickets\sin-ticket\" -ForegroundColor Yellow
    }
}
if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

# ── Acta JSON ────────────────────────────────────────────────────────────────
$liberadoMb = [math]::Round($liberadoBytes / 1MB, 1)
$nOk     = @($acciones | Where-Object { $_.estado -eq 'ok' }).Count
$nFallo  = @($acciones | Where-Object { $_.estado -eq 'fallo' }).Count

$acta = [ordered]@{
    _meta = [ordered]@{
        plataforma = 'windows'
        hostname   = $hostName
        version    = '1.0'
        tipo       = 'optimizacion'
    }
    timestamp         = (Get-Date -Format 'o')
    ticket            = $ticketStr
    acciones          = @($acciones)
    hallazgos_consumo = @($hallazgos)
    resumen           = [ordered]@{
        espacio_liberado_mb     = $liberadoMb
        acciones_ok             = $nOk
        acciones_fallidas       = $nFallo
        consumidores_detectados = $detectados
        consumidores_detenidos  = $detenidos
    }
}
$acta | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonFile -Encoding UTF8

# ── Acta TXT (legible para el cliente) ───────────────────────────────────────
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("  +-------------------------------------------------------------+")
[void]$sb.AppendLine("  |              ACTA DE OPTIMIZACION - ResolveCore             |")
[void]$sb.AppendLine("  +-------------------------------------------------------------+")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("  Equipo ....: $hostName")
[void]$sb.AppendLine(("  Fecha .....: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
[void]$sb.AppendLine("  Ticket ....: $ticketStr")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("  ACCIONES REALIZADAS")
$i = 0
foreach ($a in $acciones) {
    $i++
    $marca = switch ($a.estado) { 'ok' { 'OK' } 'fallo' { 'FALLO' } default { 'OMITIDO' } }
    [void]$sb.AppendLine(("  {0,2}. {1,-40} {2} ({3})" -f $i, $a.descripcion, $marca, $a.resultado))
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("  PROCESOS Y ARRANQUE DE ALTO CONSUMO DETECTADOS")
if ($hallazgos.Count -eq 0) {
    [void]$sb.AppendLine("    (ninguno destacable)")
} else {
    foreach ($h in $hallazgos) {
        [void]$sb.AppendLine(("    - [{0}] {1}  ->  {2}  [{3}]" -f $h.tipo, $h.nombre, $h.detalle, $h.accion))
    }
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("  RESUMEN")
[void]$sb.AppendLine(("    Espacio liberado ......: {0} MB" -f $liberadoMb))
[void]$sb.AppendLine(("    Acciones correctas ....: {0}" -f $nOk))
[void]$sb.AppendLine(("    Acciones con fallo ....: {0}" -f $nFallo))
[void]$sb.AppendLine(("    Consumidores detectados: {0} (detenidos: {1})" -f $detectados, $detenidos))
[void]$sb.AppendLine("")
[void]$sb.AppendLine("  Este acta es un registro automatico de la intervencion realizada.")
[void]$sb.AppendLine("  +-------------------------------------------------------------+")
$sb.ToString() | Set-Content -Path $txtFile -Encoding UTF8

# ── Resumen en terminal ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "  +----------------- OPTIMIZACION COMPLETADA -----------------+" -ForegroundColor Cyan
Write-Host ("   Espacio liberado .....: {0} MB" -f $liberadoMb)
Write-Host ("   Acciones .............: {0} OK / {1} fallos" -f $nOk, $nFallo)
Write-Host ("   Consumidores .........: {0} detectados / {1} detenidos" -f $detectados, $detenidos)
Write-Host "  +-----------------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "Acta guardada en:"
Write-Host "  $txtFile"
Write-Host "  $jsonFile"

# ── Subida automática a WordPress (Fase 5) ──────────────────────────────────
if ($ClientEmail -and $Token) {
    Write-Host "Subiendo acta de optimización a $ApiUrl ..."
    $payload = [ordered]@{
        client_email = $ClientEmail
        optimizacion = $acta
    }
    if ($TicketId -gt 0) { $payload.ticket_id = $TicketId }
    try {
        $resp = Invoke-RestMethod -Method Post -Uri $ApiUrl `
            -Headers @{ Authorization = "Bearer $Token" } `
            -ContentType 'application/json; charset=utf-8' `
            -Body ($payload | ConvertTo-Json -Depth 6) `
            -TimeoutSec 15
        Write-Host "  Subida OK (accion=$($resp.action))."
    } catch {
        Write-Warning "No se pudo subir el acta: $($_.Exception.Message)"
        Write-Warning "El acta local sigue disponible en: $jsonFile"
    }
} else {
    Write-Host "(Subida automática omitida: define -ClientEmail y RC_FLEET_TOKEN para activarla.)"
}
