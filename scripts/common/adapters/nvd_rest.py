# -*- coding: utf-8 -*-
"""Adapter: NvdRestAdapter — consulta NVD NIST REST API v2.

Implementa el Port VulnSource para integrarse en la arquitectura Hexagonal.
Sin dependencias pip — solo Python 3.8+ stdlib.

Variables de entorno:
    NVD_API_KEY  (opcional) — aumenta rate limit de 5 a 50 req/30s.
"""

import os
import re
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import List, Optional

from ..domain import Vulnerability

NVD_API_URL = 'https://services.nvd.nist.gov/rest/json/cves/2.0'
_SLEEP_NO_KEY = 6.0   # rate limit sin API key (NVD exige >=6s entre peticiones)
_SLEEP_WITH_KEY = 0.6
_TIMEOUT = 30
_USER_AGENT = 'ResolveCore-VulnScanner/1.0 (+https://github.com/Haplee)'


def _http_get(url: str, headers: dict | None = None, timeout: int = _TIMEOUT) -> Optional[dict]:
    import json as _json
    ctx = ssl.create_default_context()
    req = urllib.request.Request(url, headers={
        'User-Agent': _USER_AGENT,
        **(headers or {}),
    })
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=timeout) as resp:
            return _json.loads(resp.read().decode('utf-8'))
    except (urllib.error.URLError, OSError, ValueError):
        return None


class NvdRestAdapter:
    """Consulta NVD API v2 para un software/version y devuelve Vulnerability[]."""

    def __init__(self, api_key: Optional[str] = None) -> None:
        self._api_key = api_key or os.getenv('NVD_API_KEY', '')
        self._sleep = _SLEEP_WITH_KEY if self._api_key else _SLEEP_NO_KEY

    def get_vulns(self, product: str, version: str) -> List[Vulnerability]:
        """Devuelve CVEs de NVD para product/version. Nunca lanza excepción."""
        if not product:
            return []
        norm_product = self._normalize(product)
        kw = f'{norm_product} {version}'.strip()

        for query in [
            urllib.parse.urlencode({'keywordSearch': kw, 'resultsPerPage': 10}),
            urllib.parse.urlencode({'keywordSearch': norm_product, 'resultsPerPage': 10}),
        ]:
            headers = {'apiKey': self._api_key} if self._api_key else {}
            data = _http_get(f'{NVD_API_URL}?{query}', headers=headers)
            time.sleep(self._sleep)
            result = self._parse(data, product, version)
            if result:
                return result
        return []

    def _parse(self, data: Optional[dict], product: str, version: str) -> List[Vulnerability]:
        if not data:
            return []
        out: List[Vulnerability] = []
        for item in data.get('vulnerabilities', []):
            cve_obj = item.get('cve', {})
            cve_id = cve_obj.get('id', '')
            if not cve_id:
                continue
            score = self._extract_score(cve_obj)
            descs = cve_obj.get('descriptions', [])
            summary = next((x.get('value', '') for x in descs if x.get('lang') == 'en'), '')
            out.append(Vulnerability(cve=cve_id, cvss=score, summary=summary[:400]))
        return out

    @staticmethod
    def _extract_score(cve_obj: dict) -> Optional[float]:
        metrics = cve_obj.get('metrics', {})
        for key in ('cvssMetricV31', 'cvssMetricV30', 'cvssMetricV2'):
            if key in metrics and metrics[key]:
                cvss_data = metrics[key][0].get('cvssData', {})
                score = cvss_data.get('baseScore')
                if score is not None:
                    try:
                        return float(score)
                    except (ValueError, TypeError):
                        pass
        return None

    @staticmethod
    def _normalize(name: str) -> str:
        """Limpia el nombre de software para mejorar resultados NVD."""
        n = re.sub(r'\b(x64|x86|64-bit|32-bit|amd64)\b', '', name, flags=re.I)
        n = re.sub(r'\b(Professional|Enterprise|Standard|Home|Pro|LTSC)\b', '', n, flags=re.I)
        n = re.sub(r'\(.*?\)', '', n)
        return re.sub(r'\s+', ' ', n).strip()
