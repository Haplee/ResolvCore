# scripts/servicios/ — Scripts de servicios adicionales

> Scripts de ejecución de los servicios complementarios de ResolveCore.
> Justificación técnica completa: [docs/tecnica/servicios-adicionales.md](../../docs/tecnica/servicios-adicionales.md)

Este directorio agrupa los scripts de los servicios que ResolveCore presta
**además** del diagnóstico y la optimización (`scripts/windows/`, `scripts/linux/`…).

## Servicios

| Subcarpeta | Servicio | Plataformas | Estado |
|------------|----------|-------------|--------|
| `congelacion/` | Congelación de sistemas (estado de referencia restaurable) | Windows + Linux | Implementado |
| `clonacion/`   | Clonación de sistemas (registro y verificación de imágenes) | Multiplataforma | Implementado |
| `kit/`         | Kit de implantación en cliente (paquete de acceso remoto) | Windows | Implementado |

## Estado

Los ficheros de este directorio son **stubs** (esqueletos no implementados).
Cada stub lleva en su cabecera el contrato previsto (parámetros, exit codes) y
un bloque `TODO(otro-dia)`. La lógica se implementa siguiendo el prompt de tarea:

→ [docs/tareas/implementar-servicios-adicionales.md](../../docs/tareas/implementar-servicios-adicionales.md)

## Contenido

```
servicios/
├── congelacion/
│   ├── congelacion-windows.ps1   # Deep Freeze / Reboot Restore Rx
│   └── congelacion-linux.sh      # BTRFS + snapper
├── clonacion/
│   ├── registrar-imagen.sh       # Alta de imagen en el manifiesto
│   └── verificar-imagen.sh       # Verificación de integridad (hash)
└── kit/
    └── construir-kit.ps1         # Empaqueta resolvecore-kit.zip
```
