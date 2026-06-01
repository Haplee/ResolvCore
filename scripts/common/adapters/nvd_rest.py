# -*- coding: utf-8 -*-
"""
ResolveCore — Consulta de CVEs en la NVD (NIST), sin clases.

Pregunta a la API pública de la NVD por las vulnerabilidades conocidas de un
software/versión y devuelve una lista de dicts (creados con
domain.nueva_vulnerabilidad).

No usa nmap ni librerías de pip — solo la stdlib (`urllib`), así funciona en
cualquier máquina con Python 3.

Uso (desde otro script):
    from common.adapters import nvd_rest
    cves = nvd_rest.get_vulns("OpenSSH", "8.2")

Variable de entorno (opcional):
    NVD_API_KEY — sube el límite de 5 a 50 peticiones / 30s.

Autor:   Francisco Vidal Mateo (GitHub: Haplee)
Versión: 2.0
"""

import os
import re
import ssl
import time
import json
import urllib.error
import urllib.parse
import urllib.request

from ..domain import nueva_vulnerabilidad

NVD_API_URL = "https://services.nvd.nist.gov/rest/json/cves/2.0"

# La NVD exige >=6s entre peticiones si no tienes API key. Con key baja a 0.6s.
ESPERA_SIN_KEY = 6.0
ESPERA_CON_KEY = 0.6
TIMEOUT = 30
USER_AGENT = "ResolveCore-VulnScanner/1.0 (+https://github.com/Haplee)"


def _http_get(url, headers=None):
    # Petición GET que nunca peta: si algo falla devuelve None.
    ctx = ssl.create_default_context()
    cabeceras = {"User-Agent": USER_AGENT}
    if headers:
        cabeceras.update(headers)
    req = urllib.request.Request(url, headers=cabeceras)
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=TIMEOUT) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, OSError, ValueError):
        return None


def _normalizar(nombre):
    # Limpia el nombre del software: quita arquitectura y ediciones que solo
    # confunden a la búsqueda de la NVD (x64, Pro, Enterprise, paréntesis...).
    n = re.sub(r"\b(x64|x86|64-bit|32-bit|amd64)\b", "", nombre, flags=re.I)
    n = re.sub(r"\b(Professional|Enterprise|Standard|Home|Pro|LTSC)\b", "", n, flags=re.I)
    n = re.sub(r"\(.*?\)", "", n)
    return re.sub(r"\s+", " ", n).strip()


def _extraer_score(cve_obj):
    # Saca el baseScore CVSS. Probamos v3.1, luego v3.0, luego v2.
    metrics = cve_obj.get("metrics", {})
    for clave in ("cvssMetricV31", "cvssMetricV30", "cvssMetricV2"):
        if clave in metrics and metrics[clave]:
            cvss_data = metrics[clave][0].get("cvssData", {})
            score = cvss_data.get("baseScore")
            if score is not None:
                try:
                    return float(score)
                except (ValueError, TypeError):
                    pass
    return None


def _parsear(data):
    # Convierte la respuesta JSON de la NVD en lista de vulnerabilidades.
    if not data:
        return []
    salida = []
    for item in data.get("vulnerabilities", []):
        cve_obj = item.get("cve", {})
        cve_id = cve_obj.get("id", "")
        if not cve_id:
            continue
        score = _extraer_score(cve_obj)
        descs = cve_obj.get("descriptions", [])
        # Nos quedamos con la descripción en inglés (la NVD siempre la trae).
        resumen = next((x.get("value", "") for x in descs if x.get("lang") == "en"), "")
        salida.append(nueva_vulnerabilidad(cve_id, score, resumen[:400]))
    return salida


def get_vulns(product, version, api_key=None):
    """Devuelve los CVEs de la NVD para product/version. Nunca lanza excepción.

    api_key: si no se pasa, se lee de la variable de entorno NVD_API_KEY.
    """
    if not product:
        return []

    # Si no nos dan key, la buscamos en el entorno.
    if api_key is None:
        api_key = os.getenv("NVD_API_KEY", "")
    espera = ESPERA_CON_KEY if api_key else ESPERA_SIN_KEY

    norm_product = _normalizar(product)
    busqueda = (norm_product + " " + version).strip()

    # Probamos primero con producto+versión; si no hay nada, solo producto.
    consultas = [
        urllib.parse.urlencode({"keywordSearch": busqueda, "resultsPerPage": 10}),
        urllib.parse.urlencode({"keywordSearch": norm_product, "resultsPerPage": 10}),
    ]
    for consulta in consultas:
        cabeceras = {"apiKey": api_key} if api_key else {}
        data = _http_get(NVD_API_URL + "?" + consulta, cabeceras)
        time.sleep(espera)  # respetamos el rate limit de la NVD
        resultado = _parsear(data)
        if resultado:
            return resultado
    return []
