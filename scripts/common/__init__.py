"""ResolveCore - paquete Python comun (hexagonal).

Estructura Ports & Adapters:
    domain/    - entidades puras sin IO
    ports/     - interfaces abstractas (Protocols)
    adapters/  - implementaciones concretas sobre APIs externas
    cli/       - entry points de linea de comandos

buscar_vulnerabilidades.py sigue como monolito legacy a migrar en fase 2.
"""
