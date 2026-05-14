#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ResolveCore - shodan_lookup.py
Consulta de exposición de host en Shodan vía REST API pública.

Política: sin dependencias pip. Solo Python 3.8+ stdlib.
API key requerida: variable de entorno SHODAN_API_KEY
Free tier: 100 créditos/mes. host() lookup: 1 crédito/IP.

Uso standalone:
    python shodan_lookup.py --ip 8.8.8.8
    python shodan_lookup.py --ip 1.1.1.1 --json

Uso como módulo:
    from shodan_lookup import shodan_host_info, format_shodan_report
    data = shodan_host_info("8.8.8.8")

Autor: Francisco Vidal Mateo (Haplee) - TFG ASIR ResolveCore
"""

import argparse
import ipaddress
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Dict, List, Optional

SCRIPT_VERSION = "1.0.0"
SHODAN_HOST_URL = "https://api.shodan.io/shodan/host/{ip}"
SHODAN_INFO_URL = "https://api.shodan.io/api-info"  # créditos restantes del plan
HTTP_TIMEOUT = 10


# ---------------------------------------------------------------------------
# Carga de API key
# ---------------------------------------------------------------------------

def _load_dotenv(script_dir: str) -> None:
    paths = [
        os.path.join(os.getcwd(), ".env"),
        os.path.join(script_dir, ".env"),
        os.path.join(script_dir, "..", "..", ".env")
    ]
    env_path = next((p for p in paths if os.path.isfile(p)), None)
    
    if not env_path:
        return
        
    try:
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
    except Exception:
        pass


def _get_api_key() -> Optional[str]:
    return os.environ.get("SHODAN_API_KEY") or None


def shodan_api_info(api_key: Optional[str] = None) -> Dict[str, Any]:
    """
    Consulta el endpoint /api-info para ver el estado del plan y créditos restantes.
    Free tier: 100 query credits/mes. Cada host() lookup consume 1 crédito.
    No consume créditos propios.
    """
    key = api_key or _get_api_key()
    if not key:
        return {"error": "SHODAN_API_KEY no configurada."}

    url = f"{SHODAN_INFO_URL}?{urllib.parse.urlencode({'key': key})}"
    req = urllib.request.Request(
        url, headers={"User-Agent": f"ResolveCore-ShodanLookup/{SCRIPT_VERSION}"}
    )
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        return {"error": f"HTTP {e.code}"}
    except urllib.error.URLError as e:
        return {"error": f"Error de red: {e.reason}"}
    except json.JSONDecodeError:
        return {"error": "Respuesta JSON inválida"}


# ---------------------------------------------------------------------------
# Core: consulta Shodan REST
# ---------------------------------------------------------------------------

def shodan_host_info(ip: str, api_key: Optional[str] = None) -> Dict[str, Any]:
    """
    Consulta información de un host en Shodan.

    Returns dict con claves:
        ip, ports, cves, org, country, services, hostnames,
        last_update, os, isp, error (solo si falla)
    """
    # Validar formato IP antes de consumir un crédito
    try:
        ipaddress.ip_address(ip)
    except ValueError:
        return {"ip": ip, "error": f"'{ip}' no es una dirección IP válida."}

    key = api_key or _get_api_key()
    if not key:
        return {
            "ip": ip,
            "error": "SHODAN_API_KEY no configurada. "
                     "Obtén una gratis en https://account.shodan.io",
        }

    url = SHODAN_HOST_URL.format(ip=urllib.parse.quote(ip, safe=""))
    params = urllib.parse.urlencode({"key": key})
    full_url = f"{url}?{params}"

    req = urllib.request.Request(
        full_url,
        headers={"User-Agent": f"ResolveCore-ShodanLookup/{SCRIPT_VERSION}"},
    )

    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
            raw = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = ""
        try:
            body = e.read().decode("utf-8", errors="replace")
        except Exception:
            pass
        if e.code == 404:
            return {"ip": ip, "error": "Host no encontrado en Shodan (sin datos indexados)."}
        if e.code == 401:
            return {"ip": ip, "error": "API key inválida o sin permisos."}
        if e.code == 402:
            return {"ip": ip, "error": "Sin créditos Shodan. Free tier: 100/mes."}
        return {"ip": ip, "error": f"HTTP {e.code}: {body[:200]}"}
    except urllib.error.URLError as e:
        return {"ip": ip, "error": f"Error de red: {e.reason}"}
    except json.JSONDecodeError as e:
        return {"ip": ip, "error": f"Respuesta JSON inválida: {e}"}

    # Extrae campos relevantes de la respuesta Shodan
    ports: List[int] = sorted(raw.get("ports", []))

    # CVEs: aparecen en raw["vulns"] como dict {CVE-ID: {cvss, ...}}
    # Nota: Shodan puede devolver cvss como float o como string — normalizar a float.
    vulns_raw: Dict[str, Any] = raw.get("vulns", {})
    cves: List[Dict[str, Any]] = []
    for cve_id, vuln_data in vulns_raw.items():
        raw_cvss = vuln_data.get("cvss", None)
        try:
            cvss_float: Optional[float] = float(raw_cvss) if raw_cvss is not None else None
        except (ValueError, TypeError):
            cvss_float = None
        cves.append({
            "cve": cve_id,
            "cvss": cvss_float,
            "summary": vuln_data.get("summary", ""),
        })
    cves.sort(key=lambda x: x["cvss"] or 0.0, reverse=True)

    # Servicios: banner de cada puerto
    services: List[str] = []
    for item in raw.get("data", []):
        product = item.get("product", "")
        version = item.get("version", "")
        port = item.get("port", "")
        transport = item.get("transport", "tcp")
        if product:
            svc = f"{product}"
            if version:
                svc += f"/{version}"
            svc += f" ({port}/{transport})"
        else:
            svc = f"port {port}/{transport}"
        if svc not in services:
            services.append(svc)

    return {
        "ip": ip,
        "hostnames": raw.get("hostnames", []),
        "org": raw.get("org", ""),
        "isp": raw.get("isp", ""),
        "country": raw.get("country_name", ""),
        "country_code": raw.get("country_code", ""),
        "os": raw.get("os", None),
        "ports": ports,
        "services": services,
        "cves": cves,
        "last_update": raw.get("last_update", ""),
        "asn": raw.get("asn", ""),
    }


# ---------------------------------------------------------------------------
# Formateo de salida
# ---------------------------------------------------------------------------

def format_shodan_report(data: Dict[str, Any], color: bool = True) -> str:
    """Devuelve el informe Shodan como cadena legible para CLI."""
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
        f"{BOLD}{CYAN}{'─'*60}{RESET}",
        f"{BOLD}  Shodan Host Report — {ip}{RESET}",
        f"{CYAN}{'─'*60}{RESET}",
    ]

    org = data.get("org") or data.get("isp") or "—"
    country = data.get("country") or "—"
    asn = data.get("asn") or "—"
    os_name = data.get("os") or "—"
    last = data.get("last_update") or "—"
    hostnames = ", ".join(data.get("hostnames", [])) or "—"

    lines += [
        f"  Organización : {org}",
        f"  País         : {country}  ASN: {asn}",
        f"  Sistema op.  : {os_name}",
        f"  Hostnames    : {hostnames}",
        f"  Última index.: {last}",
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
            lines.append(f"    • {svc}")
        if len(services) > 10:
            lines.append(f"    ... y {len(services)-10} más")
    lines.append("")

    cves = data.get("cves", [])
    if cves:
        lines.append(f"  {BOLD}{RED}Vulnerabilidades CVE ({len(cves)}):{RESET}")
        for cve in cves[:15]:
            score: Optional[float] = cve.get("cvss")  # ya normalizado a float o None
            score_str = f"CVSS {score:.1f}" if score is not None else "CVSS —"
            color_score = RED if (score or 0.0) >= 7.0 else YELLOW
            summary = cve.get("summary", "")[:80]
            lines.append(
                f"    {color_score}[{score_str}]{RESET} {cve['cve']}  {summary}"
            )
        if len(cves) > 15:
            lines.append(f"    ... y {len(cves)-15} CVEs más")
    else:
        lines.append(f"  {GREEN}Sin CVEs conocidos indexados.{RESET}")

    lines.append(f"{CYAN}{'─'*60}{RESET}")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="shodan_lookup.py",
        description="ResolveCore — Consulta de exposición de host en Shodan",
    )
    p.add_argument("--ip", default=None, metavar="IP", help="IP a consultar (consume 1 crédito)")
    p.add_argument(
        "--info", action="store_true",
        help="Mostrar créditos Shodan restantes del mes (no consume créditos)",
    )
    p.add_argument(
        "--json", action="store_true", dest="output_json",
        help="Salida en JSON estructurado (para integración con otros módulos)",
    )
    p.add_argument(
        "--no-color", action="store_true",
        help="Deshabilitar colores ANSI en la salida de texto",
    )
    p.add_argument(
        "--api-key", default=None,
        help="API key de Shodan (por defecto: variable SHODAN_API_KEY)",
    )
    return p.parse_args()


def main() -> int:
    # Asegurar UTF-8 en Windows para evitar UnicodeEncodeError al imprimir "─"
    if sys.stdout.encoding.lower() != 'utf-8':
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except AttributeError:
            pass

    script_dir = os.path.dirname(os.path.abspath(__file__))
    _load_dotenv(script_dir)

    args = parse_args()

    if not args.ip and not args.info:
        print("Error: usa --ip <IP> para consultar un host o --info para ver créditos restantes.",
              file=sys.stderr)
        return 1

    # --info: mostrar créditos del plan sin consumir ninguno
    if args.info:
        info = shodan_api_info(api_key=args.api_key)
        if args.output_json:
            print(json.dumps(info, ensure_ascii=False, indent=2))
        elif "error" in info:
            print(f"[Shodan] Error: {info['error']}", file=sys.stderr)
            return 1
        else:
            plan = info.get("plan", "—")
            credits_left = info.get("query_credits", "—")
            scan_credits = info.get("scan_credits", "—")
            print(f"  Plan activo    : {plan}")
            print(f"  Query credits  : {credits_left} restantes este mes")
            print(f"  Scan credits   : {scan_credits} restantes este mes")
            print(f"  (1 crédito = 1 IP lookup | free tier: 100/mes)")
        if not args.ip:
            return 0

    # --ip: consulta del host
    data = shodan_host_info(args.ip, api_key=args.api_key)

    if args.output_json:
        print(json.dumps(data, ensure_ascii=False, indent=2))
    else:
        print(format_shodan_report(data, color=not args.no_color))

    return 1 if "error" in data else 0


if __name__ == "__main__":
    sys.exit(main())
