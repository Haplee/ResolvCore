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

Los 5 scripts están **implementados** (lógica completa, no stubs).
Cada script incluye cabecera con contrato (parámetros, exit codes) y soporte
`-Help` / `--help`.

Tarea de referencia: [docs/tareas/implementar-servicios-adicionales.md](../../docs/tareas/implementar-servicios-adicionales.md)

### Esquemas JSON propios

- **Clonación** — manifiesto `imagenes-manifest.json`:
  documentado en [`docs/scripting/schema-servicios-adicionales.md`](../../docs/scripting/schema-servicios-adicionales.md).
- **Congelación Linux** — salida por stdout (acción `status`, `configure`,
  `snapshot`, `rollback`): documentado en el mismo fichero anterior.
- **Congelación Windows** — `[PSCustomObject]` convertido a JSON por stdout.
- **Kit** — sin JSON; genera `resolvecore-kit.zip` + `README-cliente.txt`.

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
