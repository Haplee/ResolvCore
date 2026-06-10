# -*- coding: utf-8 -*-
"""
ResolveCore — Escaneo de un host con Nmap local, sin clases.

Lanza `nmap` contra una IP de la red local del técnico y devuelve un host
(dict creado con domain.nuevo_host) con sus puertos y servicios abiertos.

Solo funciona en la LAN del técnico y NO necesita API key, pero sí que el
binario `nmap` esté instalado y en el PATH.

Uso (desde otro script):
    from common.adapters import nmap_local
    host = nmap_local.get_host_info("192.168.1.10")

Autor:   Francisco Vidal Mateo (GitHub: Haplee)
Versión: 2.0
"""

import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

from ..domain import nuevo_host, nuevo_servicio

# Flags por defecto del escaneo. Pasa otra lista a get_host_info(flags=...)
# para cambiarlos (ej. ["-sV"] para que nmap detecte versiones).
FLAGS_POR_DEFECTO = ["-T4", "-F", "-n", "-Pn"]

# Flag válida: empieza por '-' y solo lleva letras/dígitos (admite "=valor"
# sencillo). Rechazamos cosas como --script, -oN /ruta, --script-args, que
# permitirían ejecutar NSE arbitrario o escribir ficheros si 'flags' viniera
# de entrada externa (CLI, formulario).
_FLAG_VALIDA = re.compile(r"^-{1,2}[A-Za-z0-9]+(=[A-Za-z0-9,.:]+)?$")
_FLAGS_PROHIBIDAS = ("--script", "-o", "--datadir", "--resume", "-iL")


def _flags_seguras(flags):
    for f in flags:
        if not _FLAG_VALIDA.match(f):
            return False
        if any(f.lower().startswith(p) for p in _FLAGS_PROHIBIDAS):
            return False
    return True


def get_host_info(ip, flags=None):
    """Escanea una IP local con Nmap y devuelve un host (dict de dominio).

    Nunca lanza excepción: los errores van en la clave "error" del host.
    """
    if flags is None:
        flags = FLAGS_POR_DEFECTO
    elif not _flags_seguras(flags):
        return nuevo_host(ip, error="Flags de Nmap no permitidas (posible inyección de opciones).")

    # Sin el binario nmap no hay nada que hacer.
    if not shutil.which("nmap"):
        return nuevo_host(ip, error="Nmap no está instalado o no está en el PATH.")

    cmd = ["nmap"] + flags + ["-oX", "-", ip]  # -oX - = salida XML por stdout
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    except subprocess.TimeoutExpired:
        return nuevo_host(ip, error="Timeout: el escaneo Nmap superó 60 segundos.")
    except Exception as exc:
        return nuevo_host(ip, error="Error ejecutando Nmap: " + str(exc))

    if result.returncode != 0:
        return nuevo_host(ip, error="Nmap salió con código " + str(result.returncode) + ": " + result.stderr[:200])

    return _parsear_xml(ip, result.stdout)


def _parsear_xml(ip, xml_salida):
    # Convierte el XML de nmap en un host de dominio.
    try:
        root = ET.fromstring(xml_salida)
    except ET.ParseError as exc:
        return nuevo_host(ip, error="XML de Nmap inválido: " + str(exc))

    for host_el in root.findall("host"):
        estado = host_el.find("status")
        if estado is None or estado.get("state") != "up":
            continue  # host caído, lo saltamos

        # Nos quedamos con la IPv4 que reporta nmap (puede diferir de la pedida).
        ip_detectada = ip
        for addr in host_el.findall("address"):
            if addr.get("addrtype") == "ipv4":
                ip_detectada = addr.get("addr", ip)

        hostnames = []
        for hn in host_el.findall("./hostnames/hostname"):
            nombre = hn.get("name", "")
            if nombre:
                hostnames.append(nombre)

        puertos = []
        servicios = []
        ports_el = host_el.find("ports")
        if ports_el is not None:
            for port_el in ports_el.findall("port"):
                st = port_el.find("state")
                if st is None or st.get("state") != "open":
                    continue  # solo nos interesan los puertos abiertos
                portid = int(port_el.get("portid", 0))
                proto = port_el.get("protocol", "tcp")
                puertos.append(portid)
                svc_el = port_el.find("service")
                product = ""
                version = ""
                if svc_el is not None:
                    product = svc_el.get("name", "")
                    version = svc_el.get("version", "")
                servicios.append(nuevo_servicio(portid, proto, product, version))

        return nuevo_host(ip_detectada, hostnames=hostnames, ports=puertos, services=servicios)

    # Si llegamos aquí, el host no respondió o no tenía puertos abiertos.
    return nuevo_host(ip, error="Host no activo o sin puertos abiertos detectados.")
