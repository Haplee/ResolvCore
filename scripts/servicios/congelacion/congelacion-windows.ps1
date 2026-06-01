#Requires -Version 5.1
<#
.SYNOPSIS
    ResolveCore - Congelacion de sistemas Windows

.DESCRIPTION
    Gestiona la congelacion del sistema en equipos Windows mediante:
      - Reboot Restore Rx Free (Horizons) — freeware gratuito, perfil PYME.
      - Deep Freeze (Faronics)            — comercial, opcional.

    El equipo descarta los cambios de la sesion tras cada reinicio y vuelve al
    estado de referencia. ResolveCore detecta la herramienta instalada y opera
    sobre su CLI: este script no instala la herramienta automaticamente — el
    tecnico la instala manualmente porque requiere reinicio.

    Justificacion tecnica:
      docs/tecnica/servicios-adicionales.md (seccion 1)

    Exit codes:
      0  ok
      1  error de configuracion
      2  herramienta de congelacion no instalada
      3  accion destructiva sin -Confirm

.PARAMETER Tool
    Herramienta: Auto | RebootRestoreRx | DeepFreeze. Default: Auto (detectar).

.PARAMETER Action
    Status     - estado actual (congelado / descongelado, herramienta detectada)
    Configure  - verificar instalacion y mostrar instrucciones
    Freeze     - activar congelacion (requiere -Confirm)
    Thaw       - desactivar congelacion para mantenimiento (requiere -Confirm)

.PARAMETER Confirm
    Obligatorio para Freeze y Thaw.

.EXAMPLE
    .\congelacion-windows.ps1 -Action Status
    .\congelacion-windows.ps1 -Action Configure
    .\congelacion-windows.ps1 -Action Freeze -Confirm

.NOTES
    Autor:   Francisco Vidal Mateo (GitHub: Haplee)
    Versión: 1.0.0
#>

[CmdletBinding()]
param(
    [ValidateSet('Auto','DeepFreeze','RebootRestoreRx')]
    [string]$Tool = 'Auto',

    [ValidateSet('Status','Configure','Freeze','Thaw')]
    [string]$Action = 'Status',

    [switch]$Confirm,
    [Alias('S')][switch]$Silent,
    [Alias('h')][switch]$Help,
    [int]$Ticket = 0
)

if ($Help) {
    Get-Help $PSCommandPath -Full
    exit 0
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info($m) { if (-not $Silent) { Write-Host "[->] $m" -ForegroundColor Cyan } }
function Write-Ok($m)   { if (-not $Silent) { Write-Host "[OK] $m" -ForegroundColor Green } }
function Write-Warn($m) { if (-not $Silent) { Write-Host "[!]  $m" -ForegroundColor Yellow } }

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-MantisNote {
    param([int]$TicketId, [string]$Text)
    if (-not $TicketId) { return }
    $envCandidates = @(
        (Join-Path $PSScriptRoot '../../../scripts/common/.env'),
        (Join-Path $PSScriptRoot '../../../.env.example')
    )
    $url = $null; $token = $null
    foreach ($ef in $envCandidates) {
        if (Test-Path $ef) {
            Get-Content $ef | Where-Object { $_ -match '^(MANTIS_URL|MANTIS_TOKEN)=' } | ForEach-Object {
                $k,$v = $_ -split '=',2
                if ($k -eq 'MANTIS_URL')   { $url   = $v.Trim().Trim("'").Trim('"') }
                if ($k -eq 'MANTIS_TOKEN') { $token = $v.Trim().Trim("'").Trim('"') }
            }
            break
        }
    }
    if (-not $url -or -not $token) {
        Write-Warn "MANTIS_URL/MANTIS_TOKEN no encontrados — nota al ticket omitida"
        return
    }
    try {
        $body = @{ text = $Text } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri "$url/api/rest/issues/$TicketId/notes" `
            -Method Post `
            -Headers @{ Authorization = "Bearer $token" } `
            -Body $body -ContentType 'application/json' -ErrorAction Stop | Out-Null
        Write-Ok "Nota creada en ticket #$TicketId"
    } catch {
        Write-Warn "No se pudo crear nota en MantisBT: $($_.Exception.Message)"
    }
}

# ── Deteccion de herramienta ────────────────────────────────────────────────
function Get-RebootRestoreRxInfo {
    # Reboot Restore Rx Free instala su CLI en C:\Program Files (x86)\Horizon DataSys\Reboot Restore Rx
    $candidates = @(
        "${env:ProgramFiles(x86)}\Horizon DataSys\Reboot Restore Rx\rrcli.exe",
        "${env:ProgramFiles}\Horizon DataSys\Reboot Restore Rx\rrcli.exe",
        "${env:ProgramFiles(x86)}\Shield\rrcli.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return [PSCustomObject]@{ Installed=$true; Cli=$p } }
    }
    # Servicio
    $svc = Get-Service -Name 'Shield' -ErrorAction SilentlyContinue
    if ($svc) {
        return [PSCustomObject]@{ Installed=$true; Cli=$null; Service=$svc.Status }
    }
    return [PSCustomObject]@{ Installed=$false }
}

function Get-DeepFreezeInfo {
    # Deep Freeze instala DFC.exe (Command Line)
    $candidates = @(
        "${env:ProgramFiles}\Faronics\Deep Freeze\DFC.exe",
        "${env:ProgramFiles(x86)}\Faronics\Deep Freeze\DFC.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return [PSCustomObject]@{ Installed=$true; Cli=$p } }
    }
    $svc = Get-Service -Name 'DFServ' -ErrorAction SilentlyContinue
    if ($svc) {
        return [PSCustomObject]@{ Installed=$true; Cli=$null; Service=$svc.Status }
    }
    return [PSCustomObject]@{ Installed=$false }
}

function Resolve-Tool {
    param([string]$Requested)
    if ($Requested -eq 'RebootRestoreRx') { return @{ Name='RebootRestoreRx'; Info=(Get-RebootRestoreRxInfo) } }
    if ($Requested -eq 'DeepFreeze')      { return @{ Name='DeepFreeze';      Info=(Get-DeepFreezeInfo) } }
    # Auto
    $rrx = Get-RebootRestoreRxInfo
    if ($rrx.Installed) { return @{ Name='RebootRestoreRx'; Info=$rrx } }
    $df  = Get-DeepFreezeInfo
    if ($df.Installed)  { return @{ Name='DeepFreeze';      Info=$df } }
    return @{ Name='None'; Info=[PSCustomObject]@{ Installed=$false } }
}

function Get-FrozenState {
    param([hashtable]$Resolved)
    if ($Resolved.Info.Installed -ne $true) { return 'no-installed' }

    switch ($Resolved.Name) {
        'RebootRestoreRx' {
            if ($Resolved.Info.Cli) {
                try {
                    $out = & $Resolved.Info.Cli status 2>&1 | Out-String
                    if ($out -match 'protect|congelad|frozen') { return 'frozen' }
                    if ($out -match 'thaw|descongelad|disabled') { return 'thawed' }
                } catch {}
            }
            # Heuristica: servicio Shield corriendo => congelado
            if ($Resolved.Info.PSObject.Properties.Name -contains 'Service' -and
                $Resolved.Info.Service -eq 'Running') { return 'frozen' }
            return 'unknown'
        }
        'DeepFreeze' {
            $svc = Get-Service -Name 'DFServ' -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -eq 'Running') { return 'frozen' }
            return 'thawed'
        }
    }
    return 'unknown'
}

function Install-RebootRestoreRx {
    # Intenta descargar e instalar RRRx Free (NSIS, soporte /S silent)
    $rrrxUrl = if ($env:RRRX_DOWNLOAD_URL) { $env:RRRX_DOWNLOAD_URL } `
               else { "https://resolvecore.website/downloads/RebootRestoreRx-Setup.exe" }
    $installer = Join-Path $env:TEMP "RebootRestoreRx-Setup.exe"
    Write-Info "Descargando Reboot Restore Rx Free..."
    try {
        Invoke-WebRequest -Uri $rrrxUrl -OutFile $installer -UseBasicParsing -ErrorAction Stop
        Write-Info "Instalando (silent)..."
        $p = Start-Process -FilePath $installer -ArgumentList '/S' -Wait -PassThru
        Remove-Item $installer -ErrorAction SilentlyContinue
        if ($p.ExitCode -eq 0) {
            Write-Ok "Reboot Restore Rx instalado. REINICIA el equipo y vuelve a ejecutar."
            exit 0
        } else {
            Write-Warn "Instalador salio con codigo $($p.ExitCode) — puede requerir reinicio"
        }
    } catch {
        Write-Warn "No se pudo descargar desde $rrrxUrl"
        Write-Host "  Descarga manual: https://horizondatasys.com/reboot-restore-rx-freeware/" -ForegroundColor Gray
        Write-Host "  O configura: `$env:RRRX_DOWNLOAD_URL = 'https://tu-servidor/RRRx-Setup.exe'" -ForegroundColor Gray
    }
}

# ── Acciones ────────────────────────────────────────────────────────────────
$resolved = Resolve-Tool -Requested $Tool

function Action-Status {
    $state = Get-FrozenState -Resolved $resolved
    $obj = [PSCustomObject]@{
        action       = 'Status'
        tool         = $resolved.Name
        installed    = [bool]$resolved.Info.Installed
        state        = $state
        cli_path     = if ($resolved.Info.PSObject.Properties.Name -contains 'Cli') { $resolved.Info.Cli } else { $null }
        timestamp_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }
    $obj | ConvertTo-Json -Depth 5
    return $obj
}

function Action-Configure {
    if ($resolved.Name -eq 'None') {
        Write-Warn 'Ninguna herramienta de congelacion instalada.'
        Write-Host ''
        Write-Host 'Opcion gratuita recomendada: Reboot Restore Rx Free' -ForegroundColor Cyan
        Write-Host '  Descarga oficial: https://horizondatasys.com/reboot-restore-rx-freeware/' -ForegroundColor Gray
        Write-Host '  Tras instalar, ejecuta este script con -Action Configure para verificar.' -ForegroundColor Gray
        Write-Host ''
        Write-Host 'Opcion comercial (aulas/quioscos): Deep Freeze de Faronics' -ForegroundColor Cyan
        Write-Host '  Licencia por equipo, gestion centralizada.' -ForegroundColor Gray
        if (-not (Test-Admin)) {
            Write-Warn "Instalar requiere consola Administrador"
            exit 1
        }
        $instalar = Read-Host "  ¿Intentar instalar Reboot Restore Rx Free automaticamente? (S/n)"
        if ($instalar -notmatch '^[nN]') { Install-RebootRestoreRx }
    }

    if (-not (Test-Admin)) {
        Write-Warn 'Configure requiere consola Administrador'
        exit 1
    }

    Write-Ok ("Herramienta detectada: " + $resolved.Name)
    if ($resolved.Info.Cli) {
        Write-Ok ("CLI:                   " + $resolved.Info.Cli)
    }
    Write-Host ''
    Write-Info 'Pasos para fijar el estado de referencia:'
    Write-Host '  1. Asegura que el sistema esta limpio (sin malware, parches al dia).'
    Write-Host '  2. Reinicia el equipo con la herramienta en modo DESCONGELADO.'
    Write-Host '  3. Aplica los cambios necesarios (instalaciones, configuraciones).'
    Write-Host '  4. Ejecuta: .\congelacion-windows.ps1 -Action Freeze -Confirm'

    [PSCustomObject]@{
        action     = 'Configure'
        tool       = $resolved.Name
        cli_path   = $resolved.Info.Cli
        ok         = $true
    } | ConvertTo-Json -Depth 5
}

function Action-Freeze-Or-Thaw {
    param([string]$Mode)  # 'Freeze' o 'Thaw'

    if (-not $Confirm) {
        Write-Warn ("$Mode requiere -Confirm (operacion destructiva, persiste tras reinicio)")
        exit 3
    }
    if (-not (Test-Admin)) {
        Write-Warn "$Mode requiere consola Administrador"
        exit 1
    }
    if ($resolved.Name -eq 'None') {
        Write-Warn 'Sin herramienta instalada. Ejecuta -Action Configure primero.'
        exit 2
    }

    $cli = $resolved.Info.Cli
    $success = $false

    if ($resolved.Name -eq 'RebootRestoreRx' -and $cli) {
        $arg = if ($Mode -eq 'Freeze') { 'protect' } else { 'unprotect' }
        try {
            & $cli $arg 2>&1 | Out-Null
            $success = ($LASTEXITCODE -eq 0)
        } catch { $success = $false }
    } elseif ($resolved.Name -eq 'DeepFreeze' -and $cli) {
        # DFC.exe BOOTTHAWED / BOOTFROZEN — efecto al siguiente arranque
        $arg = if ($Mode -eq 'Freeze') { '/BOOTFROZEN' } else { '/BOOTTHAWED' }
        try {
            & $cli $arg 2>&1 | Out-Null
            $success = ($LASTEXITCODE -eq 0)
        } catch { $success = $false }
    } else {
        Write-Warn 'CLI de la herramienta no disponible — ejecuta manualmente desde la GUI.'
    }

    [PSCustomObject]@{
        action        = $Mode
        tool          = $resolved.Name
        ok            = $success
        reboot_needed = $true
        timestamp_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    } | ConvertTo-Json -Depth 5

    $noteText = "ResolveCore Congelacion: accion=$Mode tool=$($resolved.Name) ok=$success timestamp=$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
    Invoke-MantisNote -TicketId $Ticket -Text $noteText

    if (-not $success) { exit 1 }
}

# ── Dispatch ────────────────────────────────────────────────────────────────
switch ($Action) {
    'Status'    { Action-Status | Out-Null; exit 0 }
    'Configure' { Action-Configure; exit 0 }
    'Freeze'    { Action-Freeze-Or-Thaw -Mode 'Freeze' }
    'Thaw'      { Action-Freeze-Or-Thaw -Mode 'Thaw' }
}
exit 0
