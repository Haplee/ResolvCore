# -*- coding: utf-8 -*-
"""
ResolveCore — Modelos de dominio (sin clases, sin librerías externas).

Aquí no usamos clases. Un "modelo" es solo un diccionario normal de Python
con unas claves conocidas. Las funciones `nueva_*` crean esos diccionarios
con valores por defecto, y las funciones `es_*` / `contar_*` los consultan.

Se hace así a propósito: es más fácil de leer sin saber clases, y los dicts
se convierten directos a JSON sin pasos intermedios.

Autor:   Francisco Vidal Mateo (GitHub: Haplee)
Versión: 2.0
"""


# Vulnerability — un CVE detectado en un host o software.
# dict: {"cve", "cvss", "summary"}
def nueva_vulnerabilidad(cve, cvss=None, summary=""):
    return {"cve": cve, "cvss": cvss, "summary": summary}


def es_critica(vuln):
    # CVSS 9.0 o más = crítica.
    return vuln.get("cvss") is not None and vuln["cvss"] >= 9.0


def es_alta(vuln):
    # CVSS entre 7.0 y 9.0 = alta.
    cvss = vuln.get("cvss")
    return cvss is not None and 7.0 <= cvss < 9.0


# Service — un servicio expuesto en un puerto.
# dict: {"port", "transport", "product", "version"}
def nuevo_servicio(port, transport="tcp", product="", version=""):
    return {"port": port, "transport": transport, "product": product, "version": version}


def servicio_str(svc):
    # Texto legible del servicio. Si no hay producto, solo el puerto.
    if svc.get("product"):
        base = svc["product"]
        if svc.get("version"):
            base += "/" + svc["version"]
        return base + " (" + str(svc["port"]) + "/" + svc["transport"] + ")"
    return "port " + str(svc["port"]) + "/" + svc["transport"]


# AttachmentResult — resultado de subir un fichero a un ticket MantisBT.
def nuevo_attachment_result(ok, ticket_id, file_name, status_code=None, error=None):
    return {
        "ok": ok,
        "ticket_id": ticket_id,
        "file_name": file_name,
        "status_code": status_code,
        "error": error,
    }


# Host — inventario de exposición de un host (resultado típico de nmap).
def nuevo_host(ip, hostnames=None, org="", isp="", country="", country_code="",
               os=None, asn="", last_update="", ports=None, services=None,
               vulnerabilities=None, error=None):
    # Las listas se crean dentro: si pusiéramos [] como valor por defecto en
    # los argumentos, Python la comparte entre llamadas (bug clásico).
    return {
        "ip": ip,
        "hostnames": hostnames if hostnames is not None else [],
        "org": org,
        "isp": isp,
        "country": country,
        "country_code": country_code,
        "os": os,
        "asn": asn,
        "last_update": last_update,
        "ports": ports if ports is not None else [],
        "services": services if services is not None else [],
        "vulnerabilities": vulnerabilities if vulnerabilities is not None else [],
        "error": error,
    }


def host_tiene_error(host):
    return host.get("error") is not None


def contar_criticas(host):
    return sum(1 for v in host.get("vulnerabilities", []) if es_critica(v))


def contar_altas(host):
    return sum(1 for v in host.get("vulnerabilities", []) if es_alta(v))
