# -*- coding: utf-8 -*-
"""Port: fuente de inteligencia de exposicion de host.

Cualquier servicio que devuelva inventario de puertos/servicios/CVEs por IP
cumple este contrato. Implementaciones actuales: Shodan REST.
Implementaciones futuras posibles: Censys, BinaryEdge, ZoomEye, scan nmap local.
"""

from typing import Protocol, runtime_checkable

from ..domain import Host


@runtime_checkable
class HostIntelSource(Protocol):
    """Contrato para fuentes de inteligencia de host por IP publica.

    Defensa TFG: el dominio depende de esta abstraccion, no de Shodan.
    Esto permite testear el dominio con un FakeHostIntelSource sin red.
    """

    def get_host_info(self, ip: str) -> Host:
        """Devuelve inventario del host. Si falla, Host.error contiene el motivo.

        Nunca lanza excepcion — siempre devuelve Host (puede tener error set).
        """
        ...
