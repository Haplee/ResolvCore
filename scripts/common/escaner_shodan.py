#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ResolveCore - escaner_shodan.py
CLI thin sobre el adapter Shodan. Mantiene compatibilidad retroactiva con
codigo que importa shodan_host_info / format_shodan_report directamente.

Arquitectura (hexagonal):
    CLI (este fichero) -> adapter ShodanRestAdapter -> Host (dominio)
                       -> formatter texto/JSON

Politica: stdlib only. SHODAN_API_KEY via env o .env local.

Uso standalone:
    python escaner_shodan.py --ip 8.8.8.8
    python escaner_shodan.py --info
    python escaner_shodan.py --ip 1.1.1.1 --json

Autor: Francisco Vidal Mateo (Haplee) - TFG ASIR ResolveCore
"""

import argparse
import json
import os
import sys
from typing import Any, Dict, Optional

# Import por path absoluto cuando se ejecuta como script suelto
if __package__ in (None, ""):
    _here = os.path.dirname(os.path.abspath(__file__))
    _parent = os.path.dirname(_here)
    if _parent not in sys.path:
        sys.path.insert(0, _parent)
    from common.adapters.shodan_rest import ShodanRestAdapter, _load_dotenv
    from common.domain import Host
else:
    from .adapters.shodan_rest import ShodanRestAdapter, _load_dotenv
    from .domain import Host

SCRIPT_VERSION = "2.0.0"


# ---------------------------------------------------------------------------
# Compat retroactiva: API publica antigua (basada en dicts)
# ---------------------------------------------------------------------------

def _host_to_dict(host: Host) -> Dict[str, Any]:
    """Serializa Host a dict equivalente al formato v1 (compat retroactiva)."""
    if host.has_error:
        return {"ip": host.ip, "error": host.error}
    return {
        "ip": host.ip,
        "hostnames": host.hostnames,
        "org": host.org,
        "isp": host.isp,
        "country": host.country,
        "country_code": host.country_code,
        "os": host.os,
        "ports": host.ports,
        "services": [str(s) for s in host.services],
        "cves": [
            {"cve": v.cve, "cvss": v.cvss, "summary": v.summary}
            for v in host.vulnerabilities
        ],
        "last_update": host.last_update,
        "asn": host.asn,
    }


def shodan_host_info(ip: str, api_key: Optional[str] = None) -> Dict[str, Any]:
    """API legacy: devuelve dict (no Host). Mantenida para compat con buscar_vulnerabilidades."""
    adapter = ShodanRestAdapter(api_key=api_key)
    return _host_to_dict(adapter.get_host_info(ip))


def shodan_api_info(api_key: Optional[str] = None) -> Dict[str, Any]:
    """API legacy: estado del plan + creditos."""
    adapter = ShodanRestAdapter(api_key=api_key)
    return adapter.get_api_info()


# ---------------------------------------------------------------------------
# Formateo CLI
# ---------------------------------------------------------------------------

def format_shodan_report(data: Dict[str, Any], color: bool = True) -> str:
    """Devuelve informe Shodan como cadena legible para CLI."""
    RESET = "\033[0m" if color else ""
    BOLD = "\033[1m" if color else ""
    RED = "\033[91m" if color else ""
    YELLOW = "\033[93m" if color else ""
    GREEN = "\033[92m" if color else ""
    CYAN = "\033[96m" if color else ""

    ip = data.get("ip", "?")

    if "error" in data:
        return f"{RED}[Shodan] {ip}: {data['error']}{RESET}"

    lines = [
        f"{BOLD}{CYAN}{'-'*60}{RESET}",
        f"{BOLD}  Shodan Host Report - {ip}{RESET}",
        f"{CYAN}{'-'*60}{RESET}",
    ]

    org = data.get("org") or data.get("isp") or "-"
    country = data.get("country") or "-"
    asn = data.get("asn") or "-"
    os_name = data.get("os") or "-"
    last = data.get("last_update") or "-"
    hostnames = ", ".join(data.get("hostnames", [])) or "-"

    lines += [
        f"  Organizacion : {org}",
        f"  Pais         : {country}  ASN: {asn}",
        f"  Sistema op.  : {os_name}",
        f"  Hostnames    : {hostnames}",
        f"  Ultima index.: {last}",
        "",
    ]

    ports = data.get("ports", [])
    if ports:
        lines.append(f"  {BOLD}Puertos abiertos ({len(ports)}):{RESET}")
        lines.append("    " + "  ".join(str(p) for p in ports))
    else:
        lines.append(f"  {GREEN}Sin puertos indexados.{RESET}")
    lines.append("")

    services = data.get("services", [])
    if services:
        lines.append(f"  {BOLD}Servicios detectados:{RESET}")
        for svc in services[:10]:
            lines.append(f"    - {svc}")
        if len(services) > 10:
            lines.append(f"    ... y {len(services)-10} mas")
    lines.append("")

    cves = data.get("cves", [])
    if cves:
        lines.append(f"  {BOLD}{RED}Vulnerabilidades CVE ({len(cves)}):{RESET}")
        for cve in cves[:15]:
            score: Optional[float] = cve.get("cvss")
            score_str = f"CVSS {score:.1f}" if score is not None else "CVSS -"
            color_score = RED if (score or 0.0) >= 7.0 else YELLOW
            summary = cve.get("summary", "")[:80]
            lines.append(
                f"    {color_score}[{score_str}]{RESET} {cve['cve']}  {summary}"
            )
        if len(cves) > 15:
            lines.append(f"    ... y {len(cves)-15} CVEs mas")
    else:
        lines.append(f"  {GREEN}Sin CVEs conocidos indexados.{RESET}")

    lines.append(f"{CYAN}{'-'*60}{RESET}")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="escaner_shodan.py",
        description="ResolveCore - Consulta de exposicion de host en Shodan (hexagonal)",
    )
    p.add_argument("--ip", default=None, metavar="IP", help="IP a consultar (consume 1 credito)")
    p.add_argument("--info", action="store_true",
                   help="Mostrar creditos Shodan restantes (no consume)")
    p.add_argument("--json", action="store_true", dest="output_json",
                   help="Salida en JSON estructurado")
    p.add_argument("--no-color", action="store_true",
                   help="Deshabilitar colores ANSI")
    p.add_argument("--api-key", default=None,
                   help="API key Shodan (por defecto: SHODAN_API_KEY)")
    return p.parse_args()


def main() -> int:
    if sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except AttributeError:
            pass

    script_dir = os.path.dirname(os.path.abspath(__file__))
    _load_dotenv(script_dir)

    args = parse_args()

    if not args.ip and not args.info:
        print("Error: usa --ip <IP> o --info.", file=sys.stderr)
        return 1

    adapter = ShodanRestAdapter(api_key=args.api_key)

    if args.info:
        info = adapter.get_api_info()
        if args.output_json:
            print(json.dumps(info, ensure_ascii=False, indent=2))
        elif "error" in info:
            print(f"[Shodan] Error: {info['error']}", file=sys.stderr)
            return 1
        else:
            plan = info.get("plan", "-")
            credits_left = info.get("query_credits", "-")
            scan_credits = info.get("scan_credits", "-")
            print(f"  Plan activo    : {plan}")
            print(f"  Query credits  : {credits_left} restantes este mes")
            print(f"  Scan credits   : {scan_credits} restantes este mes")
            print(f"  (1 credito = 1 IP lookup | free tier: 100/mes)")
        if not args.ip:
            return 0

    host = adapter.get_host_info(args.ip)
    data = _host_to_dict(host)

    if args.output_json:
        print(json.dumps(data, ensure_ascii=False, indent=2))
    else:
        print(format_shodan_report(data, color=not args.no_color))

    return 1 if host.has_error else 0


if __name__ == "__main__":
    sys.exit(main())
