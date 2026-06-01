# _archivo — código conservado fuera del árbol activo

Scripts que **no están en uso** en la rama actual pero se conservan por si vuelven
a hacer falta. No los ejecuta nada del proyecto vivo; mantienen su historia y son
restaurables con un `git mv` de vuelta a `scripts/`.

## Contenido

| Fichero | Origen | Para qué servía |
|---------|--------|-----------------|
| `common/escaner_nmap.py` | `scripts/common/` | Escaneo de red con Nmap (arquitectura Hexagonal). |
| `common/generar_informe.py` | `scripts/common/` | Generador de informe HTML/PDF desde el JSON de diagnóstico. |
| `common/generar_factura.py` | `scripts/common/` | Generador de factura de la intervención. |
| `common/adjuntar_informe_mantis.py` | `scripts/common/` | Adjunta el informe PDF al ticket vía REST de MantisBT. |
| `common/adapters/mantis_rest.py` | `scripts/common/adapters/` | Adapter `MantisRestSink` (multipart sobre `urllib`, stdlib). |

## Restaurar uno

```bash
git mv _archivo/common/escaner_nmap.py scripts/common/escaner_nmap.py
# si era un adapter, re-añadir su import en scripts/common/adapters/__init__.py
```

> Nota: al archivar `mantis_rest.py` se quitó su import de
> `scripts/common/adapters/__init__.py`. Revertirlo al restaurar.
