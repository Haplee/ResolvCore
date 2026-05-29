#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ResolveCore — Escaneo básico de puertos abiertos.

Mira los puertos TCP "habituales" en una IP/host dado, marca los que están
abiertos y avisa de los que se consideran peligrosos en una red de cliente
(FTP, Telnet, SMB, RDP, etc.).

No usa nmap ni ninguna lib externa — solo `socket` de la stdlib, así
funciona en cualquier máquina con Python 3 instalado.

Uso:
    python3 buscar_vulnerabilidades.py                 # localhost
    python3 buscar_vulnerabilidades.py 192.168.1.10
    python3 buscar_vulnerabilidades.py resolvecore.website

Autor:   Francisco Vidal Mateo (FranVi)
Versión: 2.0
"""

import socket
import sys
import json
from datetime import datetime


# Puertos que escaneamos siempre. Lista corta a propósito: si añadimos
# todos los /etc/services el script tarda eternidades sin aportar nada.
PUERTOS = {
    21:   "FTP",
    22:   "SSH",
    23:   "Telnet",
    25:   "SMTP",
    53:   "DNS",
    80:   "HTTP",
    110:  "POP3",
    143:  "IMAP",
    443:  "HTTPS",
    445:  "SMB",
    3306: "MySQL",
    3389: "RDP",
    5432: "PostgreSQL",
    6379: "Redis",
    8080: "HTTP-Alt",
    8443: "HTTPS-Alt",
    27017: "MongoDB",
}

# Puertos que en una red de cliente NO deberían estar abiertos hacia
# Internet. El informe destaca estos como aviso al técnico.
PELIGROSOS = {21, 23, 445, 3389, 6379, 27017}


def escanear(host, timeout=1.0):
    """Devuelve la lista de puertos abiertos en `host`."""
    abiertos = []

    for puerto, servicio in PUERTOS.items():
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(timeout)
            if s.connect_ex((host, puerto)) == 0:
                abiertos.append({
                    "puerto": puerto,
                    "servicio": servicio,
                    "peligroso": puerto in PELIGROSOS,
                })
            s.close()
        except OSError:
            # Si falla el socket (sin red, host caído, etc) seguimos.
            pass

    return abiertos


def main():
    host = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"

    # Resolvemos primero — así si el DNS falla damos un error claro.
    try:
        ip = socket.gethostbyname(host)
    except socket.gaierror as e:
        print(f"Error resolviendo {host}: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Escaneando {host} ({ip})...", file=sys.stderr)
    abiertos = escanear(ip)

    resultado = {
        "host": host,
        "ip": ip,
        "timestamp": datetime.now().isoformat(),
        "puertos_abiertos": abiertos,
        "avisos": [p for p in abiertos if p["peligroso"]],
    }

    print(json.dumps(resultado, indent=2, ensure_ascii=False))

    if resultado["avisos"]:
        print("", file=sys.stderr)
        print(f"[!] {len(resultado['avisos'])} puerto(s) de riesgo:", file=sys.stderr)
        for p in resultado["avisos"]:
            print(f"    {p['puerto']}/{p['servicio']}", file=sys.stderr)


if __name__ == "__main__":
    main()
