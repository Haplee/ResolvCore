# Script para la Unificación de Documentación del TFG
# Creado para consolidar todos los MDs y subir a Drive fácilmente

$docsPath = ".\docs"
$outputPath = ".\ResolvCore_Documentacion_Unificada.md"

Write-Host "Iniciando consolidación de documentos de ResolveCore..." -ForegroundColor Cyan

# Eliminar el archivo de salida si ya existe
if (Test-Path $outputPath) {
    Remove-Item $outputPath -Force
}

# Crear cabecera del documento maestro
$header = @"
# ResolveCore — Documentación Unificada del Proyecto
> **TFG ASIR 2024/25 — Francisco Vidal Mateo**
> Generado automáticamente el $(Get-Date -Format "dd/MM/yyyy HH:mm")

---

"@
Set-Content -Path $outputPath -Value $header -Encoding UTF8

# Archivos específicos a incluir en un orden lógico (Core, Técnica, Defensa)
$archivosAIncluir = @(
    ".\README.md",
    ".\docs\tecnica\stack-tecnologico.md",
    ".\docs\tecnica\comparativa-componentes.md",
    ".\docs\tecnica\flujo-sistema.md",
    ".\docs\tecnica\mantis-integration.md",
    ".\docs\tecnica\backup-entorno-web.md",
    ".\docs\scripting\diseno-alto-nivel.md",
    ".\docs\scripting\arquitectura-scripting.md",
    ".\docs\defensa\punto-de-partida-ante-proyecto.md",
    ".\docs\defensa\defensa-tfg.md",
    ".\docs\defensa\informe-tutor-estado-proyecto.md"
)

foreach ($archivo in $archivosAIncluir) {
    if (Test-Path $archivo) {
        Write-Host "Integrando: $archivo" -ForegroundColor Green
        
        # Añadir un separador visual antes del archivo
        $separator = "`n`n<div style='page-break-after: always;'></div>`n`n<!--===========================================================-->`n<!-- ARCHIVO: $archivo -->`n<!--===========================================================-->`n`n"
        Add-Content -Path $outputPath -Value $separator -Encoding UTF8
        
        # Leer e insertar el contenido
        $contenido = Get-Content -Path $archivo -Encoding UTF8
        Add-Content -Path $outputPath -Value $contenido -Encoding UTF8
    } else {
        Write-Host "Archivo no encontrado: $archivo" -ForegroundColor Yellow
    }
}

Write-Host "`n¡Consolidación terminada!" -ForegroundColor Green
Write-Host "El documento unificado se encuentra en: $outputPath" -ForegroundColor Cyan
Write-Host "Este es el archivo que puedes subir directamente al Drive del tutor." -ForegroundColor White
