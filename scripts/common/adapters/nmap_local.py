# -*- coding: utf-8 -*-
"""Adapter: NmapLocalAdapter — implementa HostIntelSource via escaneo Nmap local.

Solo funciona en la red LAN del técnico. No requiere API key.
Requiere tener el binario 'nmap' instalado en el sistema.
"""

import shutil
import subprocess
import xml.etree.ElementTree as ET
from typing import List

from ..domain import Host, Service
from ..ports import HostIntelSource  # noqa: F401  — cumple el Port


class NmapLocalAdapter:
    """Escanea una IP local con Nmap y devuelve un Host de dominio.

    Cumple el Port HostIntelSource: nunca lanza excepción — errores
    van en Host.error.
    """

    def __init__(self, flags: List[str] | None = None) -> None:
        # Flags extra opcionales (ej. ['-sV'] para detección de versiones)
        self._flags = flags or ['-T4', '-F', '-n', '-Pn']

    def get_host_info(self, ip: str) -> Host:
        if not shutil.which('nmap'):
            return Host(ip=ip, error="Nmap no está instalado o no está en el PATH.")

        cmd = ['nmap'] + self._flags + ['-oX', '-', ip]
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        except subprocess.TimeoutExpired:
            return Host(ip=ip, error="Timeout: el escaneo Nmap superó 60 segundos.")
        except Exception as exc:
            return Host(ip=ip, error=f"Error ejecutando Nmap: {exc}")

        if result.returncode != 0:
            return Host(ip=ip, error=f"Nmap salió con código {result.returncode}: {result.stderr[:200]}")

        return self._parse_xml(ip, result.stdout)

    def _parse_xml(self, ip: str, xml_output: str) -> Host:
        try:
            root = ET.fromstring(xml_output)
        except ET.ParseError as exc:
            return Host(ip=ip, error=f"XML de Nmap inválido: {exc}")

        for host_el in root.findall('host'):
            state = host_el.find('status')
            if state is None or state.get('state') != 'up':
                continue

            detected_ip = ip
            for addr in host_el.findall('address'):
                if addr.get('addrtype') == 'ipv4':
                    detected_ip = addr.get('addr', ip)

            hostnames: List[str] = []
            for hn in host_el.findall('./hostnames/hostname'):
                name = hn.get('name', '')
                if name:
                    hostnames.append(name)

            ports: List[int] = []
            services: List[Service] = []
            ports_el = host_el.find('ports')
            if ports_el is not None:
                for port_el in ports_el.findall('port'):
                    st = port_el.find('state')
                    if st is None or st.get('state') != 'open':
                        continue
                    portid = int(port_el.get('portid', 0))
                    proto  = port_el.get('protocol', 'tcp')
                    ports.append(portid)
                    svc_el  = port_el.find('service')
                    product = ''
                    version = ''
                    if svc_el is not None:
                        product = svc_el.get('name', '')
                        version = svc_el.get('version', '')
                    services.append(Service(port=portid, transport=proto, product=product, version=version))

            return Host(
                ip=detected_ip,
                hostnames=hostnames,
                ports=ports,
                services=services,
            )

        # Host no respondió o no está activo
        return Host(ip=ip, error="Host no activo o sin puertos abiertos detectados.")
