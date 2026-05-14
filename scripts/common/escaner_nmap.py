#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ResolveCore - escaner_nmap.py
Auditoría de red local (LAN) usando Nmap.

Política: sin dependencias pip. Solo Python 3.8+ stdlib.
Requiere tener instalado el binario de 'nmap' en el sistema.

Uso:
    python3 escaner_nmap.py --ip 192.168.1.141
    python3 escaner_nmap.py --ip 192.168.1.0/24 --json

Autor: Francisco Vidal Mateo (Haplee) - TFG ASIR ResolveCore
"""

import argparse
import json
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from typing import Any, Dict, List

def check_nmap_installed() -> bool:
    return shutil.which("nmap") is not None

def nmap_scan(target: str) -> Dict[str, Any]:
    """
    Ejecuta un escaneo Nmap (TCP SYN o Connect rápido) y parsea el XML.
    """
    if not check_nmap_installed():
        return {"target": target, "error": "El binario 'nmap' no está instalado o no está en el PATH."}

    # -T4 (rápido), -F (top 100 puertos para agilizar), -oX - (salida XML a stdout)
    # Se omiten resoluciones DNS (-n) y ping (-Pn) para maximizar velocidad si está en LAN.
    cmd = ["nmap", "-T4", "-F", "-n", "-Pn", "-oX", "-", target]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    except subprocess.CalledProcessError as e:
        return {"target": target, "error": f"Fallo al ejecutar Nmap: {e.stderr}"}
    except Exception as e:
        return {"target": target, "error": str(e)}

    # Parsear salida XML de Nmap
    try:
        root = ET.fromstring(result.stdout)
    except ET.ParseError:
        return {"target": target, "error": "Salida XML de Nmap no válida."}

    hosts_data = []
    
    for host in root.findall("host"):
        state = host.find("status")
        if state is not None and state.get("state") != "up":
            continue

        ip_addr = ""
        for address in host.findall("address"):
            if address.get("addrtype") == "ipv4":
                ip_addr = address.get("addr")

        ports = []
        services = []
        
        ports_node = host.find("ports")
        if ports_node is not None:
            for port in ports_node.findall("port"):
                state_node = port.find("state")
                if state_node is not None and state_node.get("state") == "open":
                    portid = int(port.get("portid"))
                    protocol = port.get("protocol")
                    ports.append(portid)
                    
                    svc_node = port.find("service")
                    svc_name = svc_node.get("name") if svc_node is not None else "unknown"
                    services.append(f"{svc_name} ({portid}/{protocol})")

        hosts_data.append({
            "ip": ip_addr,
            "ports": ports,
            "services": services
        })

    return {"target": target, "hosts": hosts_data}


def format_nmap_report(data: Dict[str, Any], color: bool = True) -> str:
    """Devuelve el informe Nmap como cadena legible para CLI."""
    RESET = "\033[0m" if color else ""
    BOLD = "\033[1m" if color else ""
    RED = "\033[91m" if color else ""
    GREEN = "\033[92m" if color else ""
    CYAN = "\033[96m" if color else ""

    target = data.get("target", "?")

    if "error" in data:
        return f"{RED}[Nmap] {target}: {data['error']}{RESET}"

    hosts = data.get("hosts", [])
    
    if not hosts:
        return f"{GREEN}[Nmap] No se detectaron hosts activos o puertos abiertos en: {target}{RESET}"

    lines = []
    for host in hosts:
        ip = host.get("ip")
        lines.extend([
            f"{BOLD}{CYAN}{'─'*60}{RESET}",
            f"{BOLD}  Nmap LAN Report — {ip}{RESET}",
            f"{CYAN}{'─'*60}{RESET}"
        ])

        ports = host.get("ports", [])
        services = host.get("services", [])

        if ports:
            lines.append(f"  {BOLD}Puertos abiertos ({len(ports)}):{RESET}")
            for svc in services:
                lines.append(f"    • {GREEN}{svc}{RESET}")
        else:
            lines.append(f"  {GREEN}Host activo, pero sin puertos abiertos en el top 100.{RESET}")

        lines.append("")

    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="escaner_nmap.py",
        description="ResolveCore — Auditoría rápida de puertos en red LAN",
    )
    p.add_argument("--ip", required=True, metavar="IP", help="IP o subred (ej: 192.168.1.141 o 192.168.1.0/24)")
    p.add_argument("--json", action="store_true", help="Salida en JSON estructurado")
    p.add_argument("--no-color", action="store_true", help="Deshabilitar colores ANSI en texto")
    return p.parse_args()


def main() -> int:
    # Asegurar UTF-8 en stdout
    if sys.stdout.encoding.lower() != 'utf-8':
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except AttributeError:
            pass

    args = parse_args()

    data = nmap_scan(args.ip)

    if args.json:
        print(json.dumps(data, ensure_ascii=False, indent=2))
    else:
        print(format_nmap_report(data, color=not args.no_color))

    return 1 if "error" in data else 0


if __name__ == "__main__":
    sys.exit(main())
