# -*- coding: utf-8 -*-
"""Modelos de dominio puros — sin dependencias externas."""

from dataclasses import dataclass, field
from typing import List, Optional


@dataclass(frozen=True)
class Vulnerability:
    """CVE detectado en un host o software."""
    cve: str
    cvss: Optional[float] = None
    summary: str = ""

    @property
    def is_critical(self) -> bool:
        return self.cvss is not None and self.cvss >= 9.0

    @property
    def is_high(self) -> bool:
        return self.cvss is not None and 7.0 <= self.cvss < 9.0


@dataclass(frozen=True)
class Service:
    """Servicio expuesto en un puerto (banner Shodan, nmap, etc)."""
    port: int
    transport: str = "tcp"
    product: str = ""
    version: str = ""

    def __str__(self) -> str:
        if self.product:
            base = self.product
            if self.version:
                base += f"/{self.version}"
            return f"{base} ({self.port}/{self.transport})"
        return f"port {self.port}/{self.transport}"


@dataclass
class Host:
    """Inventario de exposicion de un host (resultado tipico de Shodan/nmap)."""
    ip: str
    hostnames: List[str] = field(default_factory=list)
    org: str = ""
    isp: str = ""
    country: str = ""
    country_code: str = ""
    os: Optional[str] = None
    asn: str = ""
    last_update: str = ""
    ports: List[int] = field(default_factory=list)
    services: List[Service] = field(default_factory=list)
    vulnerabilities: List[Vulnerability] = field(default_factory=list)
    error: Optional[str] = None

    @property
    def has_error(self) -> bool:
        return self.error is not None

    @property
    def critical_count(self) -> int:
        return sum(1 for v in self.vulnerabilities if v.is_critical)

    @property
    def high_count(self) -> int:
        return sum(1 for v in self.vulnerabilities if v.is_high)
