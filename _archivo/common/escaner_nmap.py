#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ResolveCore - escaner_nmap.py
Auditoría de red local (LAN) usando Nmap.

Arquitectura (hexagonal):
    CLI (este fichero) -> adapter NmapLocalAdapter -> Host (dominio)
                       -> formatter texto/JSON

Política: sin dependencias pip. Solo Python 3.8+ stdlib.
Requiere tener instalado el binario de 'nmap' en el sistema.

Uso:
    python3 escaner_nmap.py --ip 192.168.1.141
    python3 escaner_nmap.py --ip 192.168.1.0/24 --json
    python3 escaner_nmap.py --ip 192.168.1.0/24 --sV      # detección de versiones

Autor: Francisco Vidal Mateo (Haplee) - TFG ASIR ResolveCore
"""

import argparse
import json
import sys
from typing import Any, Dict, List, Optional

# Importación compatible con ejecución como script suelto o como módulo
import os as _os
if __package__ in (None, ''):
    _here = _os.path.dirname(_os.path.abspath(__file__))
    _parent = _os.path.dirname(_here)
    if _parent not in sys.path:
        sys.path.insert(0, _parent)
    from common.adapters.nmap_local import NmapLocalAdapter
    from common.domain import Host
else:
    from .adapters.nmap_local import NmapLocalAdapter
    from .domain import Host

SCRIPT_VERSION = '1.0.0'


# ---------------------------------------------------------------------------
# Serialización Host → dict (formato legacy compatible con v0)
# ---------------------------------------------------------------------------

def _host_to_dict(host: Host) -> Dict[str, Any]:
    if host.has_error:
        return {'ip': host.ip, 'error': host.error}
    return {
        'ip':       host.ip,
        'hostnames': host.hostnames,
        'ports':    host.ports,
        'services': [str(s) for s in host.services],
    }


def nmap_scan(target: str, extra_flags: Optional[List[str]] = None) -> Dict[str, Any]:
    """API pública: escanea target y devuelve dict serializable."""
    flags = ['-T4', '-F', '-n', '-Pn']
    if extra_flags:
        flags = extra_flags + flags
    adapter = NmapLocalAdapter(flags=flags)
    host = adapter.get_host_info(target)
    if host.has_error:
        return {'target': target, 'error': host.error}
    return {'target': target, 'hosts': [_host_to_dict(host)]}


# ---------------------------------------------------------------------------
# Formateo CLI
# ---------------------------------------------------------------------------

def format_nmap_report(data: Dict[str, Any], color: bool = True) -> str:
    RESET  = '\033[0m'  if color else ''
    BOLD   = '\033[1m'  if color else ''
    RED    = '\033[91m' if color else ''
    GREEN  = '\033[92m' if color else ''
    CYAN   = '\033[96m' if color else ''

    target = data.get('target', '?')

    if 'error' in data:
        return f'{RED}[Nmap] {target}: {data["error"]}{RESET}'

    hosts = data.get('hosts', [])
    if not hosts:
        return f'{GREEN}[Nmap] Sin hosts activos en: {target}{RESET}'

    lines = []
    for host in hosts:
        ip       = host.get('ip', target)
        ports    = host.get('ports', [])
        services = host.get('services', [])
        lines += [
            f'{BOLD}{CYAN}{"─"*60}{RESET}',
            f'{BOLD}  Nmap LAN Report — {ip}{RESET}',
            f'{CYAN}{"─"*60}{RESET}',
        ]
        if ports:
            lines.append(f'  {BOLD}Puertos abiertos ({len(ports)}):{RESET}')
            for svc in services:
                lines.append(f'    • {GREEN}{svc}{RESET}')
        else:
            lines.append(f'  {GREEN}Host activo, sin puertos abiertos en el top 100.{RESET}')
        if host.get('hostnames'):
            lines.append(f'  Hostnames: {", ".join(host["hostnames"])}')
        lines.append('')
    return '\n'.join(lines)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog='escaner_nmap.py',
        description='ResolveCore — Auditoría rápida de puertos en red LAN (hexagonal)',
    )
    p.add_argument('--ip',       required=True, metavar='IP',
                   help='IP o subred (ej: 192.168.1.141 o 192.168.1.0/24)')
    p.add_argument('--json',     action='store_true', help='Salida en JSON estructurado')
    p.add_argument('--sV',       action='store_true', dest='sV',
                   help='Activar detección de versiones de servicios (-sV)')
    p.add_argument('--no-color', action='store_true', help='Deshabilitar colores ANSI')
    return p.parse_args()


def main() -> int:
    if sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except AttributeError:
            pass

    args = parse_args()
    extra: List[str] = ['-sV'] if args.sV else []
    data = nmap_scan(args.ip, extra_flags=extra or None)

    if args.json:
        print(json.dumps(data, ensure_ascii=False, indent=2))
    else:
        print(format_nmap_report(data, color=not args.no_color))

    return 1 if 'error' in data else 0


if __name__ == '__main__':
    sys.exit(main())
