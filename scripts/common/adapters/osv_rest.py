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
import math
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


def _redondear_arriba(valor):
    # Redondeo "roundup" tal y como lo define la especificacion CVSS v3.1:
    # redondea hacia arriba al primer decimal.
    entero = int(round(valor * 100000))
    if entero % 10000 == 0:
        return entero / 100000.0
    return (math.floor(entero / 10000.0) + 1) / 10.0


def _cvss3_base(vector):
    # Calcula el baseScore CVSS v3.0/3.1 a partir del vector
    # ("CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H"). Devuelve float o None.
    # Pesos segun la especificacion oficial de FIRST.
    pesos = {
        "AV": {"N": 0.85, "A": 0.62, "L": 0.55, "P": 0.2},
        "AC": {"L": 0.77, "H": 0.44},
        "UI": {"N": 0.85, "R": 0.62},
        "C": {"H": 0.56, "L": 0.22, "N": 0.0},
        "I": {"H": 0.56, "L": 0.22, "N": 0.0},
        "A": {"H": 0.56, "L": 0.22, "N": 0.0},
    }
    # PR depende de si el alcance (Scope) cambia.
    pr_sin_cambio = {"N": 0.85, "L": 0.62, "H": 0.27}
    pr_con_cambio = {"N": 0.85, "L": 0.68, "H": 0.5}

    campos = {}
    for parte in vector.split("/"):
        if ":" in parte:
            clave, _, val = parte.partition(":")
            campos[clave] = val
    # Necesitamos las metricas base obligatorias.
    obligatorias = ("AV", "AC", "PR", "UI", "S", "C", "I", "A")
    if not all(c in campos for c in obligatorias):
        return None
    try:
        cambio = campos["S"] == "C"
        pr_tabla = pr_con_cambio if cambio else pr_sin_cambio
        isc_base = 1 - ((1 - pesos["C"][campos["C"]]) *
                        (1 - pesos["I"][campos["I"]]) *
                        (1 - pesos["A"][campos["A"]]))
        if cambio:
            impacto = 7.52 * (isc_base - 0.029) - 3.25 * (isc_base - 0.02) ** 15
        else:
            impacto = 6.42 * isc_base
        explotabilidad = (8.22 * pesos["AV"][campos["AV"]] *
                          pesos["AC"][campos["AC"]] *
                          pr_tabla[campos["PR"]] *
                          pesos["UI"][campos["UI"]])
        if impacto <= 0:
            return 0.0
        bruto = (impacto + explotabilidad)
        if cambio:
            bruto = 1.08 * bruto
        return _redondear_arriba(min(bruto, 10.0))
    except (KeyError, TypeError):
        return None


def _score(vuln):
    # OSV trae "severity" como lista de objetos con "type" y "score". El "score"
    # es un VECTOR CVSS (cadena), no un numero: hay que calcular el baseScore.
    for sev in vuln.get("severity", []):
        tipo = sev.get("type", "")
        valor = sev.get("score", "")
        if not valor:
            continue
        # Por compatibilidad, si alguna fuente diera ya un numero, lo aceptamos.
        try:
            return float(valor)
        except (ValueError, TypeError):
            pass
        if "CVSS_V3" in tipo or valor.startswith("CVSS:3"):
            base = _cvss3_base(valor)
            if base is not None:
                return base
    # Ultimo recurso: algunos avisos traen el baseScore numerico en
    # database_specific (p. ej. {"cvss": {"score": 7.5}}).
    db = vuln.get("database_specific", {})
    cvss = db.get("cvss") if isinstance(db, dict) else None
    if isinstance(cvss, dict):
        try:
            return float(cvss.get("score"))
        except (ValueError, TypeError):
            pass
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
