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
    [string]$OutputDir = "$PSScriptRoot\..\diagnosticos"
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
