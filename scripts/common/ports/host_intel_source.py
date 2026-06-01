# -*- coding: utf-8 -*-
"""Port: fuente de inteligencia de exposicion de host.

Cualquier servicio que devuelva inventario de puertos/servicios/CVEs por IP
cumple este contrato. Implementaciones: Nmap local, APIs externas.
"""

from typing import Protocol, runtime_checkable

from ..domain import Host


@runtime_checkable
class HostIntelSource(Protocol):
    """Contrato para fuentes de inteligencia de host por IP.

    El dominio depende de esta abstraccion, no de ninguna API concreta.
    Permite testear con FakeHostIntelSource sin red.
    """

    def get_host_info(self, ip: str) -> Host:
        """Devuelve inventario del host. Si falla, Host.error contiene el motivo.

        Nunca lanza excepcion — siempre devuelve Host (puede tener error set).
        """
        ...
