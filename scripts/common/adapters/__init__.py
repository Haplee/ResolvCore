"""Adapters: implementaciones concretas de los contratos (Ports), sin clases.

Cada adapter es un módulo con funciones que cumplen el contrato descrito en
ports/. Solo aquí se permite hacer IO, llamadas HTTP, subprocesos y env.

Uso:
    from scripts.common.adapters import nmap_local, nvd_rest
    host = nmap_local.get_host_info("192.168.1.10")
    cves = nvd_rest.get_vulns("OpenSSH", "8.2")
"""

from . import mantis_rest, nmap_local, nvd_rest

__all__ = ["mantis_rest", "nmap_local", "nvd_rest"]
