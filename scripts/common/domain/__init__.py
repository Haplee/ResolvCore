"""Capa de dominio: entidades y reglas de negocio puras.

No importa de adapters/ ni ports/. Sin IO, sin red, sin filesystem.
No usa clases: las entidades son diccionarios creados por funciones `nueva_*`.
"""

from .models import (
    contar_altas,
    contar_criticas,
    es_alta,
    es_critica,
    host_tiene_error,
    nueva_vulnerabilidad,
    nuevo_attachment_result,
    nuevo_host,
    nuevo_servicio,
    servicio_str,
)

__all__ = [
    "nueva_vulnerabilidad",
    "es_critica",
    "es_alta",
    "nuevo_servicio",
    "servicio_str",
    "nuevo_attachment_result",
    "nuevo_host",
    "host_tiene_error",
    "contar_criticas",
    "contar_altas",
]
