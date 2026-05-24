#Requires -Version 5.1
<#
.SYNOPSIS
    ResolveCore - Congelacion de sistemas Windows

.DESCRIPTION
    Configura y gestiona la congelacion del sistema en equipos Windows mediante
    Deep Freeze (Faronics) o Reboot Restore Rx (Horizons). La congelacion protege
    un estado de referencia: tras cada reinicio el equipo descarta los cambios de
    la sesion y vuelve al estado congelado.

    Justificacion tecnica y comparativa de herramientas:
      docs/tecnica/servicios-adicionales.md (seccion 1)

    --- STUB / NO IMPLEMENTADO ---
    Este script es scaffolding. La logica se implementa siguiendo:
      docs/tareas/implementar-servicios-adicionales.md

    Exit codes (contrato previsto):
      0  ok
      1  error de configuracion
      2  herramienta de congelacion no instalada
      3  accion destructiva sin -Confirm

.PARAMETER Tool
    Herramienta de congelacion: DeepFreeze | RebootRestoreRx
    Default: RebootRestoreRx (licencia gratuita, perfil PYME).

.PARAMETER Action
    Accion a ejecutar:
      Status     - estado actual (congelado / descongelado)
      Configure  - instalar/configurar la herramienta y el estado de referencia
      Freeze     - activar la congelacion (requiere -Confirm)
      Thaw       - desactivar la congelacion para mantenimiento (requiere -Confirm)

.PARAMETER Confirm
    Obligatorio para Freeze y Thaw: alteran el estado de persistencia del equipo.
    Convencion CLAUDE.md: las acciones destructivas requieren confirmacion explicita.

.PARAMETER OutputDir
    Directorio donde se guardara el registro de la operacion (default: ../../diagnosticos).

.PARAMETER Silent
    Suprime la salida por consola.

.EXAMPLE
    .\congelacion-windows.ps1 -Action Status
    .\congelacion-windows.ps1 -Tool DeepFreeze -Action Configure
    .\congelacion-windows.ps1 -Action Freeze -Confirm
#>

[CmdletBinding()]
param(
    [ValidateSet('DeepFreeze','RebootRestoreRx')]
    [string]$Tool = 'RebootRestoreRx',

    [ValidateSet('Status','Configure','Freeze','Thaw')]
    [string]$Action = 'Status',

    [switch]$Confirm,
    [Alias('O')][string]$OutputDir,
    [Alias('S')][switch]$Silent,
    [Alias('h')][switch]$Help
)

# =============================================================================
# TODO(otro-dia): implementar segun docs/tareas/implementar-servicios-adicionales.md
#
#   - Status     : detectar herramienta instalada + estado congelado/descongelado.
#   - Configure  : verificar/instalar herramienta, definir particion de datos
#                  excluida de la congelacion, fijar el estado de referencia.
#   - Freeze/Thaw: exigir -Confirm; cambiar estado; registrar resultado.
#   - Salida     : [PSCustomObject] estructurado (convencion de scripts ResolveCore).
#   - Errores    : try/catch + exit codes del contrato (.DESCRIPTION).
#   - Help       : implementar bloque de ayuda como en scripts/windows/diagnostico.ps1.
# =============================================================================

Write-Warning 'congelacion-windows.ps1: STUB no implementado.'
Write-Host    'Ver docs/tareas/implementar-servicios-adicionales.md'
exit 1
