#Requires -Version 5.1
<#
.SYNOPSIS
    ResolveCore — Limpieza básica de Windows.

.DESCRIPTION
    Vacía las carpetas TEMP del usuario y del sistema, la caché de Windows
    Update y la papelera de reciclaje. Reporta cuánto se ha liberado.

    OJO: hay que ejecutarlo con permisos suficientes; idealmente como
    Administrador para que la limpieza del SoftwareDistribution funcione.

.PARAMETER Confirm
    Sin esta flag el script no hace nada. Lo añado a propósito para evitar
    que se ejecute por accidente al hacer doble clic.

.EXAMPLE
    .\optimizacion.ps1 -Confirm

.NOTES
    Autor:   Francisco Vidal Mateo (FranVi)
    Versión: 2.0
#>

param(
    [switch]$Confirm
)

if (-not $Confirm) {
    Write-Host "Ejecuta de nuevo con -Confirm para iniciar la limpieza."
    Write-Host "Ejemplo: .\optimizacion.ps1 -Confirm"
    exit 0
}

# ── Lista de rutas a vaciar ────────────────────────────────────────────────
# Las dos primeras siempre existen. La de SoftwareDistribution solo
# funciona si el script corre como Administrador.

$rutas = @(
    $env:TEMP,
    "$env:SystemRoot\Temp",
    "$env:LOCALAPPDATA\Temp",
    "$env:SystemRoot\SoftwareDistribution\Download"
)

$liberado = 0

foreach ($ruta in $rutas) {

    if (-not (Test-Path $ruta)) {
        continue
    }

    # Medimos antes de borrar — Measure-Object falla silenciosamente si
    # no puede leer algún fichero, lo cual está bien (solo es estadística).
    $tamano = (Get-ChildItem $ruta -Recurse -ErrorAction SilentlyContinue |
               Measure-Object -Property Length -Sum).Sum

    Get-ChildItem $ruta -Recurse -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    $liberado += $tamano
    Write-Host "[+] Limpiado: $ruta"
}

# ── Papelera ────────────────────────────────────────────────────────────────
# Clear-RecycleBin pide confirmación a no ser que pasemos -Force.
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
Write-Host "[+] Papelera vaciada."

$mb = [math]::Round($liberado / 1MB, 2)
Write-Host ""
Write-Host "Total liberado: $mb MB"
