# -*- coding: utf-8 -*-
"""
ResolveCore - Consulta de vulnerabilidades en OSV.dev (sin clases, stdlib only).

OSV (Open Source Vulnerabilities, de Google) agrega avisos de muchos
ecosistemas: Debian, Ubuntu, PyPI, npm, etc. Su API es rapida y no exige API
key, asi que es el camino por defecto del escaner para paquetes de Linux.

Cumple el mismo contrato que nvd_rest (ports/vuln_source.py):

    get_vulns(product, version, ecosistema="") -> list[dict]

Devuelve dicts creados con domain.nueva_vulnerabilidad. Nunca lanza excepcion.

API: POST https://api.osv.dev/v1/query
     POST https://api.osv.dev/v1/querybatch  (varias consultas de una vez)

Autor:   Francisco Vidal Mateo (GitHub: Haplee)
Version: 1.0
"""

import ssl
import json
import urllib.error
import urllib.request

from ..domain import nueva_vulnerabilidad

OSV_QUERY_URL = "https://api.osv.dev/v1/query"
OSV_BATCH_URL = "https://api.osv.dev/v1/querybatch"
TIMEOUT = 30
USER_AGENT = "ResolveCore-VulnScanner/1.0 (+https://github.com/Haplee)"


def _http_post(url, cuerpo):
    # POST JSON que nunca peta: si algo falla devuelve None.
    ctx = ssl.create_default_context()
    datos = json.dumps(cuerpo).encode("utf-8")
    cabeceras = {"User-Agent": USER_AGENT, "Content-Type": "application/json"}
    req = urllib.request.Request(url, data=datos, headers=cabeceras, method="POST")
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=TIMEOUT) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, OSError, ValueError):
        return None


def _payload(product, version, ecosistema):
    paquete = {"name": product}
    if ecosistema:
        paquete["ecosystem"] = ecosistema
    cuerpo = {"package": paquete}
    if version:
        cuerpo["version"] = version
    return cuerpo


def _id_preferido(vuln):
    # Preferimos el identificador CVE si esta entre los alias; si no, el id OSV.
    for alias in vuln.get("aliases", []):
        if isinstance(alias, str) and alias.startswith("CVE-"):
            return alias
    return vuln.get("id", "")


def _score(vuln):
    # OSV trae "severity" como lista de vectores CVSS (cadenas), no como numero.
    # Si encontramos un valor que sea numerico lo usamos; si no, None.
    for sev in vuln.get("severity", []):
        valor = sev.get("score", "")
        try:
            return float(valor)
        except (ValueError, TypeError):
            continue
    return None


def _parsear(data):
    if not data:
        return []
    salida = []
    for vuln in data.get("vulns", []):
        ident = _id_preferido(vuln)
        if not ident:
            continue
        resumen = vuln.get("summary") or vuln.get("details") or ""
        salida.append(nueva_vulnerabilidad(ident, _score(vuln), resumen[:400]))
    return salida


def get_vulns(product, version, ecosistema=""):
    """Devuelve los CVEs/avisos de OSV para product/version. Nunca lanza."""
    if not product:
        return []
    data = _http_post(OSV_QUERY_URL, _payload(product, version, ecosistema))
    # Si fallo con ecosistema, reintentamos sin el (OSV casa por nombre).
    if data is None and ecosistema:
        data = _http_post(OSV_QUERY_URL, _payload(product, version, ""))
    return _parsear(data)


def get_vulns_batch(paquetes, ecosistema=""):
    """Consulta varios paquetes de una vez con /v1/querybatch.

    paquetes: lista de dicts {"nombre", "version"}.
    Devuelve un dict {nombre: [vulnerabilidades...]}. El batch de OSV solo
    devuelve ids; aqui los envolvemos en nueva_vulnerabilidad sin score ni
    resumen (para enriquecer luego haria falta /v1/vulns/<id>). Nunca lanza.
    """
    resultado = {}
    if not paquetes:
        return resultado
    consultas = []
    for p in paquetes:
        consultas.append(_payload(p.get("nombre", ""), p.get("version", ""), ecosistema))
    data = _http_post(OSV_BATCH_URL, {"queries": consultas})
    if not data:
        return resultado
    bloques = data.get("results", [])
    for i, bloque in enumerate(bloques):
        if i >= len(paquetes):
            break
        nombre = paquetes[i].get("nombre", "")
        vulns = []
        for v in (bloque or {}).get("vulns", []):
            ident = v.get("id", "")
            if ident:
                vulns.append(nueva_vulnerabilidad(ident, None, ""))
        if vulns:
            resultado[nombre] = vulns
    return resultado
