#Requires -Version 5.1
<#
.SYNOPSIS
    ResolveCore - Constructor del kit de implantacion en cliente

.DESCRIPTION
    Empaqueta el "kit de implantacion en cliente" que ResolveCore entrega a los
    clientes con suscripcion: una carpeta autocontenida con AnyDesk portable, las
    instrucciones para el cliente y los scripts de diagnostico.

    Estructura del kit (segun docs/tecnica/servicios-adicionales.md, seccion 3):
      resolvecore-kit/
      |-- anydesk-portable.exe
      |-- README-cliente.pdf
      \-- scripts/
          |-- diagnostico-windows.ps1
          \-- diagnostico-linux.sh

    --- STUB / NO IMPLEMENTADO ---
    Este script es scaffolding. La logica se implementa siguiendo:
      docs/tareas/implementar-servicios-adicionales.md

    Exit codes (contrato previsto):
      0  ok
      1  error de empaquetado
      2  AnyDesk portable no encontrado

.PARAMETER AnyDeskPath
    Ruta al ejecutable AnyDesk portable que se incluira en el kit.

.PARAMETER OutputDir
    Directorio donde se generara resolvecore-kit/ y resolvecore-kit.zip
    (default: ./dist).

.PARAMETER IncludeScripts
    Incluir los scripts de diagnostico en el kit (default: $true).

.EXAMPLE
    .\construir-kit.ps1 -AnyDeskPath .\anydesk.exe
    .\construir-kit.ps1 -AnyDeskPath .\anydesk.exe -OutputDir C:\kits
#>

[CmdletBinding()]
param(
    [string]$AnyDeskPath,
    [Alias('O')][string]$OutputDir = './dist',
    [bool]$IncludeScripts = $true,
    [Alias('h')][switch]$Help
)

# =============================================================================
# TODO(otro-dia): implementar segun docs/tareas/implementar-servicios-adicionales.md
#
#   - Validar que -AnyDeskPath existe || exit 2.
#   - Crear el arbol resolvecore-kit/ dentro de -OutputDir.
#   - Copiar AnyDesk portable como anydesk-portable.exe.
#   - Si -IncludeScripts: copiar scripts/windows/diagnostico.ps1 y
#     scripts/linux/diagnostico.sh como diagnostico-windows.ps1 /
#     diagnostico-linux.sh.
#   - Generar README-cliente.pdf (plantilla de instrucciones de una pagina).
#   - Comprimir el arbol a resolvecore-kit.zip con Compress-Archive.
#   - try/catch + exit codes del contrato (.DESCRIPTION).
# =============================================================================

Write-Warning 'construir-kit.ps1: STUB no implementado.'
Write-Host    'Ver docs/tareas/implementar-servicios-adicionales.md'
exit 1
