# -*- coding: utf-8 -*-
"""Adapter: implementa HostIntelSource sobre la API REST de Shodan.

Politica: stdlib only. No requiere `pip install shodan`.
"""

import ipaddress
import json
import os
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Dict, List, Optional

from ..domain import Host, Service, Vulnerability

SHODAN_HOST_URL = "https://api.shodan.io/shodan/host/{ip}"
SHODAN_INFO_URL = "https://api.shodan.io/api-info"
USER_AGENT = "ResolveCore-ShodanAdapter/1.0.0"
HTTP_TIMEOUT = 10


def _load_dotenv(script_dir: str) -> None:
    """Carga .env si existe en cwd, script_dir o raiz del repo."""
    paths = [
        os.path.join(os.getcwd(), ".env"),
        os.path.join(script_dir, ".env"),
        os.path.join(script_dir, "..", "..", "..", ".env"),
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


class ShodanRestAdapter:
    """Implementacion de HostIntelSource sobre Shodan REST API.

    Lee SHODAN_API_KEY de env si no se inyecta explicitamente.
    Free tier: 100 query credits/mes. 1 credito por host lookup.
    """

    def __init__(self, api_key: Optional[str] = None, timeout: int = HTTP_TIMEOUT):
        self._api_key = api_key or os.environ.get("SHODAN_API_KEY")
        self._timeout = timeout

    def get_host_info(self, ip: str) -> Host:
        # Validar IP antes de gastar credito
        try:
            ip_obj = ipaddress.ip_address(ip)
            if ip_obj.is_private or ip_obj.is_loopback:
                return Host(ip=ip, error="IP privada/loopback no indexable en Shodan publico.")
        except ValueError:
            return Host(ip=ip, error=f"'{ip}' no es una IP valida.")

        if not self._api_key:
            return Host(
                ip=ip,
                error="SHODAN_API_KEY no configurada. https://account.shodan.io",
            )

        url = SHODAN_HOST_URL.format(ip=urllib.parse.quote(ip, safe=""))
        params = urllib.parse.urlencode({"key": self._api_key})
        req = urllib.request.Request(
            f"{url}?{params}", headers={"User-Agent": USER_AGENT}
        )

        try:
            with urllib.request.urlopen(req, timeout=self._timeout) as resp:
                raw = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            return self._map_http_error(ip, e)
        except urllib.error.URLError as e:
            return Host(ip=ip, error=f"Error de red: {e.reason}")
        except json.JSONDecodeError as e:
            return Host(ip=ip, error=f"Respuesta JSON invalida: {e}")

        return self._map_response(ip, raw)

    def get_api_info(self) -> Dict[str, Any]:
        """Devuelve estado del plan + creditos restantes. No consume creditos."""
        if not self._api_key:
            return {"error": "SHODAN_API_KEY no configurada."}
        url = f"{SHODAN_INFO_URL}?{urllib.parse.urlencode({'key': self._api_key})}"
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=self._timeout) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            return {"error": f"HTTP {e.code}"}
        except urllib.error.URLError as e:
            return {"error": f"Error de red: {e.reason}"}
        except json.JSONDecodeError:
            return {"error": "Respuesta JSON invalida"}

    @staticmethod
    def _map_http_error(ip: str, e: urllib.error.HTTPError) -> Host:
        body = ""
        try:
            body = e.read().decode("utf-8", errors="replace")
        except Exception:
            pass
        if e.code == 404:
            return Host(ip=ip, error="Host no encontrado en Shodan (sin datos indexados).")
        if e.code == 401:
            return Host(ip=ip, error="API key invalida o sin permisos.")
        if e.code == 402:
            return Host(ip=ip, error="Sin creditos Shodan. Free tier: 100/mes.")
        return Host(ip=ip, error=f"HTTP {e.code}: {body[:200]}")

    @staticmethod
    def _map_response(ip: str, raw: Dict[str, Any]) -> Host:
        ports: List[int] = sorted(raw.get("ports", []))

        vulns_raw: Dict[str, Any] = raw.get("vulns", {})
        vulns: List[Vulnerability] = []
        for cve_id, vuln_data in vulns_raw.items():
            raw_cvss = vuln_data.get("cvss", None)
            try:
                cvss_float: Optional[float] = float(raw_cvss) if raw_cvss is not None else None
            except (ValueError, TypeError):
                cvss_float = None
            vulns.append(Vulnerability(
                cve=cve_id,
                cvss=cvss_float,
                summary=vuln_data.get("summary", ""),
            ))
        vulns.sort(key=lambda v: v.cvss or 0.0, reverse=True)

        services: List[Service] = []
        seen = set()
        for item in raw.get("data", []):
            svc = Service(
                port=int(item.get("port", 0) or 0),
                transport=item.get("transport", "tcp") or "tcp",
                product=item.get("product", "") or "",
                version=item.get("version", "") or "",
            )
            key = (svc.port, svc.transport, svc.product, svc.version)
            if key in seen:
                continue
            seen.add(key)
            services.append(svc)

        return Host(
            ip=ip,
            hostnames=raw.get("hostnames", []) or [],
            org=raw.get("org", "") or "",
            isp=raw.get("isp", "") or "",
            country=raw.get("country_name", "") or "",
            country_code=raw.get("country_code", "") or "",
            os=raw.get("os", None),
            asn=raw.get("asn", "") or "",
            last_update=raw.get("last_update", "") or "",
            ports=ports,
            services=services,
            vulnerabilities=vulns,
        )
