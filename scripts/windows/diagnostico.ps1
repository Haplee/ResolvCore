#Requires -Version 5.1
<#
.SYNOPSIS
    ResolveCore — Diagnóstico básico de un equipo Windows.

.DESCRIPTION
    Lanza una recogida rápida de información del sistema (CPU, RAM, discos,
    antivirus) y la vuelca en un JSON con marca de tiempo. La salida la
    consume luego el técnico para generar el informe en HTML/PDF.

    Pensado para Windows 10 y 11. No instala nada — solo consulta CIM.

.PARAMETER OutputDir
    Carpeta donde se deja el JSON. Por defecto ../diagnosticos respecto al
    script.

.EXAMPLE
    .\diagnostico.ps1
    .\diagnostico.ps1 -OutputDir C:\Temp

.NOTES
    Autor:   Francisco Vidal Mateo (GitHub: Haplee)
    Versión: 2.0
#>

param(
    [string]$OutputDir = "$PSScriptRoot\..\diagnosticos",

    # ── Subida automática del JSON a WordPress (Fase 5) ──────────────────────
    # Si se indican -ClientEmail y un token (parámetro o variable de entorno
    # RC_FLEET_TOKEN), el script publica el diagnóstico en el endpoint REST de
    # la flota tras generarlo, sin que el técnico lo copie a mano.
    [string]$ClientEmail = $env:RC_CLIENT_EMAIL,
    [string]$ApiUrl      = $(if ($env:RC_FLEET_URL) { $env:RC_FLEET_URL } else { 'https://resolvecore.website/wp-json/rc/v1/fleet' }),
    [string]$Token       = $env:RC_FLEET_TOKEN,
    [int]$TicketId       = 0
)

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

Write-Host "Recogiendo métricas de $env:COMPUTERNAME..."

# ── Construcción del objeto de salida ───────────────────────────────────────
# Usamos [ordered] para que el JSON salga en el mismo orden que aquí, no
# en el aleatorio de un hashtable normal.

$resultado = [ordered]@{
    # _meta lo exige el endpoint /wp-json/rc/v1/fleet para identificar el agente.
    _meta = [ordered]@{
        plataforma = 'windows'
        hostname   = $env:COMPUTERNAME
        version    = '2.0'
    }
    timestamp = (Get-Date -Format 'o')
    hostname  = $env:COMPUTERNAME
    os        = "$($osInfo.Caption) $($osInfo.Version)"

    cpu = @{
        name  = $cpuInfo.Name.Trim()
        cores = $cpuInfo.NumberOfCores
        load  = $cpuInfo.LoadPercentage
    }

    ram = @{
        total_gb = [math]::Round($csInfo.TotalPhysicalMemory / 1GB, 2)
        free_gb  = [math]::Round($osInfo.FreePhysicalMemory / 1MB, 2)
    }

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

    antivirus = @(
        # Algunas instalaciones limpias no exponen SecurityCenter2 — capturamos
        # silenciosamente para no abortar el diagnóstico entero por esto.
        Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct `
            -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty displayName
    )
}

# ── Volcado del JSON ────────────────────────────────────────────────────────

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$ts      = Get-Date -Format 'yyyyMMdd_HHmmss'
$ruta    = Join-Path $OutputDir "diagnostico_${env:COMPUTERNAME}_${ts}.json"

$resultado | ConvertTo-Json -Depth 5 | Set-Content -Path $ruta -Encoding UTF8

Write-Host "Listo. Diagnóstico guardado en:"
Write-Host "  $ruta"

# ── Subida automática a WordPress (Fase 5) ──────────────────────────────────
# Solo se intenta si hay email de cliente y token. Cualquier fallo de red se
# avisa pero NO aborta el script: el JSON local ya está a salvo en disco.

if ($ClientEmail -and $Token) {
    Write-Host "Subiendo diagnóstico a $ApiUrl ..."

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
        Write-Host "  Subida OK (accion=$($resp.action), score=$($resp.score), host_id=$($resp.host_id))."
    } catch {
        Write-Warning "No se pudo subir el diagnóstico: $($_.Exception.Message)"
        Write-Warning "El JSON local sigue disponible en: $ruta"
    }
} else {
    Write-Host "(Subida automática omitida: define -ClientEmail y RC_FLEET_TOKEN para activarla.)"
}
