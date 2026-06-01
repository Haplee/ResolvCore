# -*- coding: utf-8 -*-
"""Port: fuente de inteligencia de exposición de host.

Contrato escrito (sin clases): describe la función que debe ofrecer
cualquier adapter que devuelva inventario de un host por IP.

CONTRATO HostIntelSource
------------------------
El adapter debe exponer una función:

    get_host_info(ip: str) -> dict

- Devuelve un host (dict creado con domain.nuevo_host) con sus puertos,
  servicios y CVEs.
- Si falla, el host devuelto lleva la clave "error" con el motivo.
- Nunca lanza excepción: siempre devuelve un host (puede tener error).

Implementación actual: adapters/nmap_local.py (get_host_info).
"""
