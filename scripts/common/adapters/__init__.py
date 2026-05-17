"""Adapters: implementaciones concretas de los Ports sobre APIs externas.

Cada adapter encapsula una integracion (Shodan REST, NVD, OSV...).
Solo aqui se permite hacer IO, llamadas HTTP, lectura de variables de entorno.
"""

from .shodan_rest import ShodanRestAdapter

__all__ = ["ShodanRestAdapter"]
