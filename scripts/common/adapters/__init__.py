"""Adapters: implementaciones concretas de los Ports sobre APIs externas.

Cada adapter encapsula una integracion (NVD, OSV, Mantis, Nmap...).
Solo aqui se permite hacer IO, llamadas HTTP, subprocesos y lectura de env.
"""

from .mantis_rest import MantisRestSink
from .nmap_local import NmapLocalAdapter
from .nvd_rest import NvdRestAdapter

__all__ = ["MantisRestSink", "NmapLocalAdapter", "NvdRestAdapter"]
