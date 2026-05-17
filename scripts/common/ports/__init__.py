"""Ports: interfaces abstractas (Protocols PEP 544).

Define que necesita el dominio del mundo exterior, sin atarse a una
implementacion concreta. Adapters cumplen estos contratos.
"""

from .host_intel_source import HostIntelSource

__all__ = ["HostIntelSource"]
