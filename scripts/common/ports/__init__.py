"""Ports: interfaces abstractas (Protocols PEP 544).

Define que necesita el dominio del mundo exterior, sin atarse a una
implementacion concreta. Adapters cumplen estos contratos.
"""

from .host_intel_source import HostIntelSource
from .mantis_attachment_sink import MantisAttachmentSink
from .vuln_source import VulnSource

__all__ = ["HostIntelSource", "MantisAttachmentSink", "VulnSource"]
