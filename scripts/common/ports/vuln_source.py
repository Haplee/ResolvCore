# -*- coding: utf-8 -*-
"""Port: fuente de vulnerabilidades CVE.

Cualquier feed (NVD, OSV, CISA KEV, EPSS) que devuelva lista de
Vulnerability para un software/versión dado cumple este contrato.
"""

from typing import List, Protocol, runtime_checkable

from ..domain import Vulnerability


@runtime_checkable
class VulnSource(Protocol):
    """Contrato para fuentes de datos CVE.

    El dominio depende de esta abstracción, no de NVD ni de ninguna API concreta.
    Permite testear con FakeVulnSource sin red.
    """

    def get_vulns(self, product: str, version: str) -> List[Vulnerability]:
        """Devuelve lista de CVEs para product/version.

        Nunca lanza excepción — devuelve lista vacía si falla o no hay datos.
        """
        ...
