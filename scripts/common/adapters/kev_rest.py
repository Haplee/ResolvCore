# -*- coding: utf-8 -*-
"""
ResolveCore - Catalogo CISA KEV (Known Exploited Vulnerabilities), sin clases.

La CISA publica una lista de CVEs que se sabe que estan siendo EXPLOTADOS
activamente. Cruzar nuestros CVEs con esta lista permite avisar al tecnico de
cuales son urgentes de verdad, no solo "teoricamente" peligrosos.

Descarga el catalogo una vez y lo cachea en un fichero temporal durante el dia
para no bajarlo en cada ejecucion.

Uso:
    from common.adapters import kev_rest
    kev = kev_rest.cargar_kev()         # set de CVE ids (o set() si falla)
    if kev_rest.es_kev("CVE-2024-1234", kev): ...

Autor:   Francisco Vidal Mateo (GitHub: Haplee)
Version: 1.0
"""

import os
import sys
import ssl
import json
import time
import tempfile
import urllib.error
import urllib.request

KEV_URL = "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json"
TIMEOUT = 30
USER_AGENT = "ResolveCore-VulnScanner/1.0 (+https://github.com/Haplee)"

# Cache local: valida 24h.
_CACHE = os.path.join(tempfile.gettempdir(), "resolvecore_kev.json")
_CACHE_TTL = 86400


def _http_get(url):
    ctx = ssl.create_default_context()
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=TIMEOUT) as resp:
            return resp.read().decode("utf-8")
    except (urllib.error.URLError, OSError):
        return ""


def _leer_cache():
    try:
        if not os.path.exists(_CACHE):
            return None
        if (time.time() - os.path.getmtime(_CACHE)) > _CACHE_TTL:
            return None
        with open(_CACHE, encoding="utf-8") as f:
            return f.read()
    except OSError:
        return None


def _guardar_cache(texto):
    try:
        with open(_CACHE, "w", encoding="utf-8") as f:
            f.write(texto)
    except OSError:
        pass


def cargar_kev():
    """Devuelve un set con los CVE ids del catalogo KEV. set() si falla."""
    texto = _leer_cache()
    if texto is None:
        texto = _http_get(KEV_URL)
        if texto:
            _guardar_cache(texto)
        else:
            # Sin cache y sin descarga: el set vacío resultante haría que NINGÚN
            # CVE se marque como explotado. Avisamos para no dar falsa calma.
            print("[!] No se pudo descargar el catálogo CISA KEV: ningún CVE se "
                  "marcará como explotado activamente.", file=sys.stderr)
    if not texto:
        return set()
    try:
        data = json.loads(texto)
    except ValueError:
        return set()
    ids = set()
    for item in data.get("vulnerabilities", []):
        cve = item.get("cveID", "")
        if cve:
            ids.add(cve)
    return ids


def es_kev(cve, kev_set):
    """True si el CVE esta en el catalogo de explotados activamente."""
    return bool(cve) and cve in kev_set
