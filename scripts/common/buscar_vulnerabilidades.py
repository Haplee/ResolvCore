#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ResolveCore - buscar_vulnerabilidades.py
Escaneo unificado de vulnerabilidades para Windows / Linux / Android / macOS.

Politica: solo software libre / open source. APIs publicas (NVD, CISA KEV, OSV,
EPSS-FIRST). Sin dependencias pip. Solo Python 3.8+ stdlib.

Autor: Francisco Vidal Mateo (Haplee) - TFG ASIR ResolveCore
Licencia: GPL-3.0 (mismo proyecto)
"""

import argparse
import base64
import csv
import datetime as _dt
import io
import json
import os
import platform
import re
import socket
import smtplib
import ssl
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from email.mime.base import MIMEBase
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email import encoders
from typing import Any, Dict, List, Optional, Tuple

# -----------------------------------------------------------------------------
# Constantes globales
# -----------------------------------------------------------------------------

SCRIPT_VERSION = "1.0.0"
USER_AGENT = f"ResolveCore-VulnScanner/{SCRIPT_VERSION} (+https://github.com/Haplee)"

NVD_API = "https://services.nvd.nist.gov/rest/json/cves/2.0"
KEV_FEED = "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json"
OSV_API = "https://api.osv.dev/v1/query"
EPSS_API = "https://api.first.org/data/v1/epss"

NVD_SLEEP = 6.0          # rate limit sin API key
EPSS_SLEEP = 1.0
OSV_TIMEOUT = 10
HTTP_TIMEOUT = 10

MAX_SOFTWARE_QUERIES = 25

PUERTOS_RIESGO = {
    21: ("FTP (sin cifrar)", "HIGH"),
    23: ("Telnet (sin cifrar)", "CRITICAL"),
    25: ("SMTP abierto", "MEDIUM"),
    135: ("RPC/DCOM (Windows)", "MEDIUM"),
    139: ("NetBIOS", "HIGH"),
    445: ("SMB", "HIGH"),
    1433: ("SQL Server expuesto", "HIGH"),
    3306: ("MySQL expuesto", "HIGH"),
    3389: ("RDP expuesto", "HIGH"),
    5900: ("VNC sin cifrar", "HIGH"),
    6379: ("Redis sin auth", "CRITICAL"),
    27017: ("MongoDB sin auth", "CRITICAL"),
}

DEPS_FILES = {
    "requirements.txt": "PyPI",
    "package.json": "npm",
    "pom.xml": "Maven",
    "build.gradle": "Maven",
    "Gemfile": "RubyGems",
    "go.sum": "Go",
    "composer.json": "Packagist",
}

# Patrones de ruido a descartar del inventario (no aportan valor de CVE)
SOFTWARE_NOISE_PATTERNS = [
    re.compile(r"^Update for Microsoft", re.I),
    re.compile(r"^Security Update", re.I),
    re.compile(r"^Hotfix\s", re.I),
    re.compile(r"^Microsoft \.NET (Host|Targeting Pack|SDK|Runtime).*Bundle", re.I),
    re.compile(r"^Windows Software Development Kit", re.I),
    re.compile(r"^Microsoft Visual Studio Tools for", re.I),
    re.compile(r"^Application Verifier", re.I),
    re.compile(r"^Windows App Certification Kit", re.I),
    re.compile(r"^vs_minshell", re.I),
    re.compile(r"^vcpp_crt\.redist", re.I),
    re.compile(r"^Microsoft (Edge|Office|Project|Visio).*Click-to-Run", re.I),
    re.compile(r"Click-to-Run Localization", re.I),
    re.compile(r"^Microsoft OneDrive$", re.I),
    re.compile(r"^Microsoft Edge WebView2", re.I),
    re.compile(r"^FACEIT", re.I),
    re.compile(r"^R\.E\.P\.O\.", re.I),
    re.compile(r"^TeamSpeak", re.I),
]

# Mapeo de nombres comunes a keywords NVD efectivos
SOFTWARE_KEYWORD_MAP = [
    (re.compile(r"Microsoft Visual C\+\+ (\d{4})", re.I), r"vcredist \1"),
    (re.compile(r"Microsoft \.NET Runtime", re.I), ".NET Runtime"),
    (re.compile(r"Microsoft \.NET Host", re.I), ".NET Host"),
    (re.compile(r"Eclipse Temurin JDK", re.I), "openjdk"),
    (re.compile(r"Oracle VirtualBox", re.I), "virtualbox"),
    (re.compile(r"Android Studio", re.I), "android studio"),
    (re.compile(r"GitHub CLI", re.I), "github cli"),
    (re.compile(r"Mozilla Firefox", re.I), "firefox"),
    (re.compile(r"Google Chrome", re.I), "chrome"),
    (re.compile(r"Microsoft Edge\b", re.I), "microsoft edge"),
]


def normalize_software(name: str, version: str) -> Tuple[str, str]:
    """Normaliza nombre y version para queries efectivas en NVD."""
    if not name:
        return name, version
    n = name
    for pat, repl in SOFTWARE_KEYWORD_MAP:
        if pat.search(n):
            n = pat.sub(repl, n)
            break
    n = re.sub(r"\b(x64|x86|64-bit|32-bit|amd64|ia32)\b", "", n, flags=re.I)
    n = re.sub(r"\b(Additional Runtime|Minimum Runtime|Redistributable)\b", "", n, flags=re.I)
    n = re.sub(r"\b(Profesional|Professional|Enterprise|Standard|Home|Pro)\b", "", n, flags=re.I)
    n = re.sub(r"\b(LTSC|en-us|es-es|en-gb)\b", "", n, flags=re.I)
    n = re.sub(r"\b(con Hotspot|with Hotspot|HotSpot)\b", "", n, flags=re.I)
    n = re.sub(r"\(.*?\)", "", n)
    n = re.sub(r"\s+", " ", n).strip()
    v_short = version.split(".")
    if len(v_short) >= 2:
        v = ".".join(v_short[:2])
    else:
        v = version
    return n, v


def is_noise_software(name: str) -> bool:
    if not name:
        return True
    for pat in SOFTWARE_NOISE_PATTERNS:
        if pat.search(name):
            return True
    return False


def dedupe_software(items: List[Dict[str, str]]) -> List[Dict[str, str]]:
    """Elimina duplicados por nombre normalizado, conserva version mas alta."""
    seen: Dict[str, Dict[str, str]] = {}
    for sw in items:
        n, _ = normalize_software(sw.get("nombre", ""), sw.get("version", ""))
        key = n.lower()
        if not key or is_noise_software(sw.get("nombre", "")):
            continue
        prev = seen.get(key)
        if prev is None or _ver_key(sw.get("version", "")) > _ver_key(prev.get("version", "")):
            seen[key] = sw
    return list(seen.values())


def _ver_key(v: str) -> Tuple:
    out = []
    for part in re.split(r"[.\-_]", v or ""):
        m = re.match(r"(\d+)", part)
        if m:
            out.append(int(m.group(1)))
        else:
            out.append(0)
    return tuple(out) or (0,)


def _cmp_version(a: str, b: str) -> int:
    """Compara dos strings de version. Retorna -1/0/1."""
    ka = _ver_key(a)
    kb = _ver_key(b)
    if ka < kb:
        return -1
    if ka > kb:
        return 1
    return 0


def cve_affects_version(cve_obj: dict, name: str, version: str) -> Tuple[bool, str]:
    """Verifica si CVE realmente afecta a la version instalada via CPE matching.

    Retorna (affects, razon). Si CVE no tiene configurations CPE, retorna False
    (mejor silencio que falso positivo).
    """
    configs = cve_obj.get("configurations", [])
    if not configs:
        return False, "no-cpe-config"

    name_norm = re.sub(r"[\s_]+", "", name.lower())
    version = (version or "").strip()
    if not version:
        return False, "no-version"

    matched_any_cpe = False
    for config in configs:
        nodes = config.get("nodes", []) if isinstance(config, dict) else []
        for node in nodes:
            for match in node.get("cpeMatch", []) or []:
                if not match.get("vulnerable", True):
                    continue
                criteria = (match.get("criteria") or "").lower()
                # cpe:2.3:a:vendor:product:version:...
                parts = criteria.split(":")
                if len(parts) < 5:
                    continue
                product = parts[4]
                if not product:
                    continue
                product_norm = re.sub(r"[\s_\-]+", "", product)
                # Coincidencia laxa: producto del CPE debe aparecer en el nombre
                if product_norm not in name_norm and name_norm not in product_norm:
                    continue
                matched_any_cpe = True

                cpe_ver = parts[5] if len(parts) > 5 else "*"
                vsi = match.get("versionStartIncluding")
                vse = match.get("versionStartExcluding")
                vei = match.get("versionEndIncluding")
                vee = match.get("versionEndExcluding")

                # Si CPE indica version exacta no-wildcard
                if cpe_ver not in ("*", "-", ""):
                    if _cmp_version(version, cpe_ver) == 0:
                        return True, f"exact-match {cpe_ver}"
                    # Si solo hay version exacta y no rango, no afecta
                    if not any([vsi, vse, vei, vee]):
                        continue

                # Aplicar rangos
                ok = True
                if vsi and _cmp_version(version, vsi) < 0:
                    ok = False
                if ok and vse and _cmp_version(version, vse) <= 0:
                    ok = False
                if ok and vei and _cmp_version(version, vei) > 0:
                    ok = False
                if ok and vee and _cmp_version(version, vee) >= 0:
                    ok = False
                if ok and (vsi or vse or vei or vee):
                    return True, f"range-match {vsi or vse or '*'}..{vei or vee or '*'}"

    if matched_any_cpe:
        return False, "product-match-but-version-out-of-range"
    return False, "no-product-match"

# -----------------------------------------------------------------------------
# Utilidades de consola (sin dependencias)
# -----------------------------------------------------------------------------

class C:
    if sys.platform == "win32":
        try:
            import ctypes
            kernel32 = ctypes.windll.kernel32
            kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
        except Exception:
            pass
    R = "\033[0;31m"
    G = "\033[0;32m"
    Y = "\033[1;33m"
    B = "\033[0;34m"
    M = "\033[0;35m"
    CY = "\033[0;36m"
    W = "\033[1;37m"
    GR = "\033[0;90m"
    NC = "\033[0m"


def cprint(msg: str, color: str = "", silent: bool = False) -> None:
    if silent:
        return
    print(f"{color}{msg}{C.NC}")


def now_iso() -> str:
    return _dt.datetime.now().strftime("%Y-%m-%dT%H:%M:%S")


def now_stamp() -> str:
    return _dt.datetime.now().strftime("%Y%m%d_%H%M%S")


def safe_run(cmd: List[str], timeout: int = 30) -> Tuple[int, str, str]:
    """Ejecuta comando y retorna (rc, stdout, stderr). Nunca lanza excepcion."""
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        return proc.returncode, proc.stdout or "", proc.stderr or ""
    except FileNotFoundError:
        return 127, "", "command not found"
    except subprocess.TimeoutExpired:
        return 124, "", "timeout"
    except Exception as e:
        return 1, "", str(e)


def http_get_json(url: str, timeout: int = HTTP_TIMEOUT, verbose: bool = False) -> Optional[dict]:
    if verbose:
        cprint(f"  [HTTP] GET {url}", C.GR)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ssl.create_default_context()) as resp:
            data = resp.read().decode("utf-8", errors="replace")
            return json.loads(data)
    except (urllib.error.URLError, urllib.error.HTTPError, ssl.SSLError, socket.timeout, json.JSONDecodeError) as e:
        if verbose:
            cprint(f"  [HTTP] error: {e}", C.R)
        return None
    except Exception as e:
        if verbose:
            cprint(f"  [HTTP] error: {e}", C.R)
        return None


def http_post_json(url: str, payload: dict, timeout: int = HTTP_TIMEOUT, verbose: bool = False,
                   extra_headers: Optional[Dict[str, str]] = None) -> Optional[dict]:
    body = json.dumps(payload).encode("utf-8")
    headers = {"User-Agent": USER_AGENT, "Content-Type": "application/json", "Accept": "application/json"}
    if extra_headers:
        headers.update(extra_headers)
    if verbose:
        cprint(f"  [HTTP] POST {url}", C.GR)
    req = urllib.request.Request(url, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ssl.create_default_context()) as resp:
            return json.loads(resp.read().decode("utf-8", errors="replace"))
    except Exception as e:
        if verbose:
            cprint(f"  [HTTP] error: {e}", C.R)
        return None


def is_admin() -> bool:
    if sys.platform == "win32":
        try:
            import ctypes
            return bool(ctypes.windll.shell32.IsUserAnAdmin())
        except Exception:
            return False
    try:
        return os.geteuid() == 0
    except AttributeError:
        return False


def cmd_exists(name: str) -> bool:
    if sys.platform == "win32":
        rc, _, _ = safe_run(["where", name], timeout=5)
    else:
        rc, _, _ = safe_run(["which", name], timeout=5)
    return rc == 0


# -----------------------------------------------------------------------------
# 1. PlatformDetector
# -----------------------------------------------------------------------------

class PlatformDetector:
    """Detecta SO y recolecta software/versiones."""

    def __init__(self, force_platform: Optional[str] = None, adb_serial: Optional[str] = None,
                 verbose: bool = False):
        self.force = force_platform
        self.adb_serial = adb_serial
        self.verbose = verbose
        self.platform_code = self._detect()
        self.hostname = socket.gethostname()
        self.os_info: Dict[str, Any] = {}
        self.software: List[Dict[str, str]] = []
        self.servicios: List[str] = []

    def _detect(self) -> str:
        if self.force:
            return self.force.upper()
        s = platform.system().lower()
        if "windows" in s:
            return "W"
        if "darwin" in s:
            return "M"
        if "linux" in s:
            return "L"
        return "L"

    def detect_all(self) -> None:
        if self.platform_code == "W":
            self._detect_windows()
        elif self.platform_code == "L":
            self._detect_linux()
        elif self.platform_code == "M":
            self._detect_macos()
        elif self.platform_code == "A":
            self._detect_android()

    # ---------- Windows ----------
    def _detect_windows(self) -> None:
        try:
            import winreg  # noqa
        except ImportError:
            cprint("  [!] winreg no disponible (no es Windows real?)", C.Y)
            return
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows NT\CurrentVersion") as k:
                build = winreg.QueryValueEx(k, "CurrentBuild")[0]
                product = winreg.QueryValueEx(k, "ProductName")[0]
                try:
                    display_v = winreg.QueryValueEx(k, "DisplayVersion")[0]
                except FileNotFoundError:
                    display_v = ""
            self.os_info = {
                "producto": product,
                "build": build,
                "version": display_v,
                "kernel": platform.release(),
            }
        except Exception as e:
            self.os_info = {"producto": platform.platform(), "build": "?", "version": "", "kernel": platform.release()}
            if self.verbose:
                cprint(f"  [!] winreg fallo: {e}", C.Y)

        seen: set = set()
        for hive_name, hive in (("HKLM", winreg.HKEY_LOCAL_MACHINE), ("HKCU", winreg.HKEY_CURRENT_USER)):
            for sub in (
                r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
            ):
                try:
                    with winreg.OpenKey(hive, sub) as parent:
                        i = 0
                        while True:
                            try:
                                child_name = winreg.EnumKey(parent, i)
                                i += 1
                            except OSError:
                                break
                            try:
                                with winreg.OpenKey(parent, child_name) as ck:
                                    name = ""
                                    ver = ""
                                    try:
                                        name = str(winreg.QueryValueEx(ck, "DisplayName")[0])
                                    except FileNotFoundError:
                                        continue
                                    try:
                                        ver = str(winreg.QueryValueEx(ck, "DisplayVersion")[0])
                                    except FileNotFoundError:
                                        ver = ""
                                    key = (name.lower(), ver)
                                    if not name or key in seen:
                                        continue
                                    seen.add(key)
                                    self.software.append({"nombre": name, "version": ver, "fuente": f"{hive_name}/Uninstall"})
                            except Exception:
                                continue
                except FileNotFoundError:
                    continue

        rc, out, _ = safe_run(["sc", "query", "type=", "service", "state=", "running"], timeout=10)
        if rc == 0:
            for line in out.splitlines():
                m = re.match(r"\s*SERVICE_NAME:\s*(\S+)", line)
                if m:
                    self.servicios.append(m.group(1))

    # ---------- Linux ----------
    def _detect_linux(self) -> None:
        rel = {}
        try:
            with open("/etc/os-release", "r", encoding="utf-8") as f:
                for line in f:
                    if "=" in line:
                        k, v = line.strip().split("=", 1)
                        rel[k] = v.strip('"')
        except Exception:
            pass
        self.os_info = {
            "producto": rel.get("PRETTY_NAME", platform.platform()),
            "id": rel.get("ID", ""),
            "version": rel.get("VERSION_ID", ""),
            "kernel": platform.release(),
        }

        if cmd_exists("dpkg"):
            rc, out, _ = safe_run(["dpkg-query", "-W", "-f=${Package}\t${Version}\n"], timeout=20)
            if rc == 0:
                for line in out.splitlines():
                    parts = line.split("\t")
                    if len(parts) == 2 and parts[0]:
                        self.software.append({"nombre": parts[0], "version": parts[1], "fuente": "dpkg"})
        elif cmd_exists("rpm"):
            rc, out, _ = safe_run(["rpm", "-qa", "--queryformat", "%{NAME}\t%{VERSION}-%{RELEASE}\n"], timeout=20)
            if rc == 0:
                for line in out.splitlines():
                    parts = line.split("\t")
                    if len(parts) == 2 and parts[0]:
                        self.software.append({"nombre": parts[0], "version": parts[1], "fuente": "rpm"})
        elif cmd_exists("pacman"):
            rc, out, _ = safe_run(["pacman", "-Q"], timeout=20)
            if rc == 0:
                for line in out.splitlines():
                    parts = line.split(" ", 1)
                    if len(parts) == 2:
                        self.software.append({"nombre": parts[0], "version": parts[1], "fuente": "pacman"})

        if cmd_exists("systemctl"):
            rc, out, _ = safe_run(["systemctl", "list-units", "--type=service", "--state=running",
                                   "--no-pager", "--no-legend"], timeout=10)
            if rc == 0:
                for line in out.splitlines():
                    name = line.strip().split(" ", 1)[0]
                    if name.endswith(".service"):
                        self.servicios.append(name)

    # ---------- macOS ----------
    def _detect_macos(self) -> None:
        rc, out, _ = safe_run(["sw_vers"], timeout=5)
        info = {}
        for line in out.splitlines():
            if ":" in line:
                k, v = line.split(":", 1)
                info[k.strip()] = v.strip()
        self.os_info = {
            "producto": info.get("ProductName", "macOS"),
            "version": info.get("ProductVersion", ""),
            "build": info.get("BuildVersion", ""),
            "kernel": platform.release(),
        }
        if cmd_exists("brew"):
            rc, out, _ = safe_run(["brew", "list", "--versions"], timeout=15)
            if rc == 0:
                for line in out.splitlines():
                    parts = line.split(" ", 1)
                    if len(parts) >= 2:
                        self.software.append({"nombre": parts[0], "version": parts[1].split(" ")[0], "fuente": "brew"})
        try:
            for entry in os.listdir("/Applications"):
                if entry.endswith(".app"):
                    plist = os.path.join("/Applications", entry, "Contents", "Info.plist")
                    if os.path.isfile(plist):
                        rc, out, _ = safe_run(
                            ["defaults", "read", os.path.join("/Applications", entry, "Contents", "Info"),
                             "CFBundleShortVersionString"], timeout=5)
                        ver = out.strip() if rc == 0 else ""
                        self.software.append({"nombre": entry[:-4], "version": ver, "fuente": "Applications"})
        except Exception:
            pass

    # ---------- Android (ADB) ----------
    def _detect_android(self) -> None:
        if not cmd_exists("adb"):
            cprint("  [X] ADB no encontrado. Instalalo (Linux: 'apt install adb', Mac: 'brew install android-platform-tools')",
                   C.R)
            sys.exit(3)
        adb = ["adb"]
        if self.adb_serial:
            adb += ["-s", self.adb_serial]
        rc, out, _ = safe_run(adb + ["devices"], timeout=10)
        if rc != 0 or "device\n" not in out and not re.search(r"\sdevice\s*$", out, re.M):
            cprint("  [X] No hay dispositivos ADB autorizados.", C.R)
            sys.exit(3)

        rc, ver, _ = safe_run(adb + ["shell", "getprop", "ro.build.version.release"], timeout=10)
        rc, patch, _ = safe_run(adb + ["shell", "getprop", "ro.build.version.security_patch"], timeout=10)
        rc, model, _ = safe_run(adb + ["shell", "getprop", "ro.product.model"], timeout=10)
        rc, brand, _ = safe_run(adb + ["shell", "getprop", "ro.product.brand"], timeout=10)
        self.os_info = {
            "producto": f"{brand.strip()} {model.strip()}".strip(),
            "version": ver.strip(),
            "security_patch": patch.strip(),
            "kernel": "",
        }
        rc, out, _ = safe_run(adb + ["shell", "pm", "list", "packages", "-3"], timeout=15)
        if rc == 0:
            for line in out.splitlines():
                pkg = line.replace("package:", "").strip()
                if pkg:
                    rc2, vout, _ = safe_run(adb + ["shell", "dumpsys", "package", pkg], timeout=10)
                    m = re.search(r"versionName=([^\s]+)", vout) if rc2 == 0 else None
                    self.software.append({"nombre": pkg, "version": m.group(1) if m else "", "fuente": "adb"})


# -----------------------------------------------------------------------------
# 2. KEV cache + 3. EPSS + 4. VulnScanner
# -----------------------------------------------------------------------------

class CISAKEVCache:
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.data: Dict[str, dict] = {}

    def load(self) -> None:
        cprint("  [>] Descargando feed CISA KEV...", C.GR)
        d = http_get_json(KEV_FEED, timeout=20, verbose=self.verbose)
        if not d or "vulnerabilities" not in d:
            cprint("  [!] No se pudo cargar CISA KEV (continuando sin)", C.Y)
            return
        for v in d.get("vulnerabilities", []):
            cve = v.get("cveID")
            if cve:
                self.data[cve] = v
        cprint(f"  [OK] CISA KEV: {len(self.data)} CVEs cargados", C.G)


class VulnScanner:
    """Consulta NVD + OSV + EPSS, cruza con KEV."""

    def __init__(self, kev: CISAKEVCache, min_score: float = 7.0, verbose: bool = False):
        self.kev = kev
        self.min_score = min_score
        self.verbose = verbose
        self._lock = threading.Lock()

    def _parse_nvd_response(self, d: Optional[dict], name: str, version: str,
                            strict_version: bool = True) -> List[dict]:
        if not d:
            return []
        out: List[dict] = []
        for item in d.get("vulnerabilities", []):
            cve = item.get("cve", {})
            cve_id = cve.get("id")
            if not cve_id:
                continue

            # Filtro CPE por version - elimina falsos positivos
            if strict_version:
                affects, _reason = cve_affects_version(cve, name, version)
                if not affects:
                    if self.verbose:
                        cprint(f"  [skip] {cve_id} {name} {version}: {_reason}", C.GR)
                    continue

            descs = cve.get("descriptions", [])
            desc = next((x.get("value", "") for x in descs if x.get("lang") == "en"), "")
            metrics = cve.get("metrics", {})
            score = 0.0
            severity = "UNKNOWN"
            for key in ("cvssMetricV31", "cvssMetricV30", "cvssMetricV2"):
                if key in metrics and metrics[key]:
                    m = metrics[key][0]
                    cvd = m.get("cvssData", {})
                    score = float(cvd.get("baseScore", 0.0) or 0.0)
                    severity = cvd.get("baseSeverity") or m.get("baseSeverity") or "UNKNOWN"
                    break
            out.append({
                "cve_id": cve_id,
                "cvss": score,
                "severity": severity,
                "descripcion": desc[:400],
                "fuente": "NVD",
                "software": name,
                "version": version,
            })
        return out

    def query_nvd(self, name: str, version: str) -> List[dict]:
        norm_name, norm_ver = normalize_software(name, version)
        if not norm_name:
            return []
        # Intento 1: keyword search (nombre + version corta)
        kw = f"{norm_name} {norm_ver}".strip()
        params = urllib.parse.urlencode({"keywordSearch": kw, "resultsPerPage": 5})
        d = http_get_json(f"{NVD_API}?{params}", timeout=HTTP_TIMEOUT, verbose=self.verbose)
        time.sleep(NVD_SLEEP)
        out = self._parse_nvd_response(d, name, version)
        if out:
            return out
        # Intento 2: keyword search solo nombre normalizado
        params = urllib.parse.urlencode({"keywordSearch": norm_name, "resultsPerPage": 5})
        d = http_get_json(f"{NVD_API}?{params}", timeout=HTTP_TIMEOUT, verbose=self.verbose)
        time.sleep(NVD_SLEEP)
        out = self._parse_nvd_response(d, name, version)
        if out:
            return out
        # Intento 3: virtualMatchString CPE-like (vendor:product)
        slug = norm_name.lower().replace(" ", "_")
        cpe = f"cpe:2.3:a:*:{slug}:{norm_ver}"
        params = urllib.parse.urlencode({"virtualMatchString": cpe, "resultsPerPage": 5})
        d = http_get_json(f"{NVD_API}?{params}", timeout=HTTP_TIMEOUT, verbose=self.verbose)
        time.sleep(NVD_SLEEP)
        return self._parse_nvd_response(d, name, version)

    def query_osv(self, name: str, version: str, ecosystem: Optional[str] = None) -> List[dict]:
        payload: Dict[str, Any] = {"package": {"name": name}}
        if ecosystem:
            payload["package"]["ecosystem"] = ecosystem
        if version:
            payload["version"] = version
        d = http_post_json(OSV_API, payload, timeout=OSV_TIMEOUT, verbose=self.verbose)
        if not d:
            return []
        out: List[dict] = []
        for v in d.get("vulns", []):
            sev = "UNKNOWN"
            score = 0.0
            for s in v.get("severity", []) or []:
                if s.get("type") == "CVSS_V3":
                    txt = s.get("score", "")
                    m = re.search(r"/AV:.*", txt)
                    sev = "HIGH" if "/I:H" in txt or "/A:H" in txt else "MEDIUM"
            out.append({
                "cve_id": v.get("id", ""),
                "cvss": score,
                "severity": sev,
                "descripcion": (v.get("summary") or v.get("details") or "")[:400],
                "fuente": "OSV",
                "software": name,
                "version": version,
            })
        return out

    def query_epss(self, cve_id: str) -> Tuple[float, float]:
        if not cve_id.startswith("CVE-"):
            return 0.0, 0.0
        url = f"{EPSS_API}?cve={cve_id}"
        d = http_get_json(url, timeout=HTTP_TIMEOUT, verbose=self.verbose)
        time.sleep(EPSS_SLEEP)
        if not d or not d.get("data"):
            return 0.0, 0.0
        try:
            row = d["data"][0]
            return float(row.get("epss", 0)), float(row.get("percentile", 0))
        except Exception:
            return 0.0, 0.0

    def scan_software(self, software: List[Dict[str, str]],
                      whitelist: Optional[set] = None,
                      progress_cb=None) -> List[dict]:
        whitelist = whitelist or set()
        results: List[dict] = []
        seen_cves: set = set()
        clean = dedupe_software(software)
        targets = clean[:MAX_SOFTWARE_QUERIES]
        total = len(targets)
        for idx, sw in enumerate(targets, 1):
            name = sw.get("nombre", "").strip()
            ver = sw.get("version", "").strip()
            if not name:
                continue
            if progress_cb:
                progress_cb(idx, total, name, ver)
            local: List[dict] = []
            t1 = []
            t2 = []

            def _nvd():
                t1.extend(self.query_nvd(name, ver))

            def _osv():
                t2.extend(self.query_osv(name, ver))

            th1 = threading.Thread(target=_nvd, daemon=True)
            th2 = threading.Thread(target=_osv, daemon=True)
            th1.start()
            th2.start()
            th1.join(timeout=60)
            th2.join(timeout=30)
            local.extend(t1)
            local.extend(t2)

            for v in local:
                cid = v.get("cve_id", "")
                if not cid or cid in seen_cves:
                    continue
                seen_cves.add(cid)
                if cid in whitelist:
                    v["estado"] = "EXCEPCION ACEPTADA"
                kev = self.kev.data.get(cid)
                v["kev"] = bool(kev)
                if kev:
                    v["kev_action"] = kev.get("requiredAction", "")
                    v["kev_due"] = kev.get("dueDate", "")
                epss, pct = self.query_epss(cid)
                v["epss"] = epss
                v["epss_percentile"] = pct
                if v.get("cvss", 0) < self.min_score and not v["kev"] and pct < 0.5:
                    continue
                results.append(v)

        results.sort(key=lambda x: (not x.get("kev", False), -float(x.get("cvss", 0)), -float(x.get("epss", 0))))
        return results


# -----------------------------------------------------------------------------
# 5. ConfigAuditor
# -----------------------------------------------------------------------------

class ConfigAuditor:
    """Auditoria local de configuracion sin APIs."""

    def __init__(self, platform_code: str, adb_serial: Optional[str] = None, verbose: bool = False):
        self.pc = platform_code
        self.adb_serial = adb_serial
        self.verbose = verbose
        self.results: List[dict] = []

    def _add(self, check: str, estado: str, riesgo: str, actual: str, esperado: str,
             corregido: bool = False, accion: str = "") -> None:
        self.results.append({
            "check": check,
            "estado": estado,
            "riesgo": riesgo,
            "valor_actual": actual,
            "valor_esperado": esperado,
            "corregido": corregido,
            "accion": accion,
        })

    def run(self) -> List[dict]:
        if self.pc == "W":
            self._windows()
        elif self.pc == "L":
            self._linux()
        elif self.pc == "M":
            self._macos()
        elif self.pc == "A":
            self._android()
        return self.results

    # ---------- Windows ----------
    def _windows(self) -> None:
        try:
            import winreg
        except ImportError:
            return

        def regdw(hive, path, value):
            try:
                with winreg.OpenKey(hive, path) as k:
                    v, _ = winreg.QueryValueEx(k, value)
                    return v
            except Exception:
                return None

        v = regdw(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System", "EnableLUA")
        self._add("UAC habilitado",
                  "OK" if v == 1 else "FALLO",
                  "HIGH", str(v), "1")

        rdp_disabled = regdw(winreg.HKEY_LOCAL_MACHINE,
                              r"SYSTEM\CurrentControlSet\Control\Terminal Server", "fDenyTSConnections")
        if rdp_disabled == 0:
            v = regdw(winreg.HKEY_LOCAL_MACHINE,
                      r"SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp",
                      "UserAuthentication")
            if v is not None:
                self._add("RDP NLA habilitado",
                          "OK" if v == 1 else "FALLO",
                          "HIGH", str(v), "1")
        # else: RDP deshabilitado - no aplica check NLA

        v = regdw(winreg.HKEY_LOCAL_MACHINE,
                  r"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer", "NoDriveTypeAutoRun")
        # None = clave no presente = default Win10/11 (AutoRun para CDROM solo) - aceptable
        if v is None:
            self._add("AutoRun politica explicita",
                      "OK", "LOW", "default", "configurada o default")
        else:
            self._add("AutoRun deshabilitado",
                      "OK" if v in (255, 0xFF) else "FALLO",
                      "MEDIUM", str(v), "0xFF (255)")

        rc, out, _ = safe_run(["powershell", "-NoProfile", "-Command",
                               "Get-SmbServerConfiguration | Select-Object -ExpandProperty EnableSMB1Protocol"],
                              timeout=15)
        if rc == 0:
            val = out.strip()
            self._add("SMBv1 deshabilitado",
                      "OK" if val.lower() == "false" else "FALLO",
                      "HIGH", val, "False")

        rc, out, _ = safe_run(["netsh", "advfirewall", "show", "allprofiles", "state"], timeout=10)
        if rc == 0:
            on = out.upper().count("ON")
            off = out.upper().count("OFF")
            self._add("Firewall activo (3 perfiles)",
                      "OK" if off == 0 and on >= 3 else "FALLO",
                      "HIGH", f"ON={on} OFF={off}", "ON=3 OFF=0")

        # Defender: probar varias rutas (algunas requieren admin)
        defender_ok = None
        rc, out, err = safe_run(["powershell", "-NoProfile", "-Command",
                                  "try{(Get-MpComputerStatus -ErrorAction Stop).AntivirusEnabled}catch{'ERR'}"],
                                 timeout=15)
        val = out.strip()
        if rc == 0 and val and val != "ERR":
            defender_ok = val.lower() == "true"
        else:
            # Fallback registro (no requiere admin)
            v = regdw(winreg.HKEY_LOCAL_MACHINE,
                      r"SOFTWARE\Microsoft\Windows Defender", "DisableAntiSpyware")
            if v is not None:
                defender_ok = v == 0
            else:
                defender_ok = True  # ausencia = enabled por defecto
        self._add("Defender habilitado",
                  "OK" if defender_ok else "FALLO",
                  "CRITICAL",
                  "True" if defender_ok else "False", "True")

        for svc in ("Telnet", "TFTP", "RemoteRegistry", "SSDPSRV"):
            rc, out, _ = safe_run(["sc", "qc", svc], timeout=5)
            if rc == 0 and "AUTO_START" in out:
                self._add(f"Servicio innecesario: {svc}",
                          "FALLO", "MEDIUM", "AUTO_START", "DISABLED")

    # ---------- Linux ----------
    def _linux(self) -> None:
        sshd = "/etc/ssh/sshd_config"
        if os.path.isfile(sshd):
            try:
                with open(sshd, "r", encoding="utf-8", errors="ignore") as f:
                    cfg = f.read()
                root_login = re.search(r"^\s*PermitRootLogin\s+(\S+)", cfg, re.M)
                pw_auth = re.search(r"^\s*PasswordAuthentication\s+(\S+)", cfg, re.M)
                self._add("SSH PermitRootLogin",
                          "OK" if root_login and root_login.group(1).lower() == "no" else "FALLO",
                          "HIGH",
                          root_login.group(1) if root_login else "default(yes)", "no")
                self._add("SSH PasswordAuthentication",
                          "OK" if pw_auth and pw_auth.group(1).lower() == "no" else "FALLO",
                          "MEDIUM",
                          pw_auth.group(1) if pw_auth else "default(yes)", "no")
            except Exception:
                pass

        if cmd_exists("ufw"):
            rc, out, _ = safe_run(["ufw", "status"], timeout=5)
            self._add("UFW activo",
                      "OK" if rc == 0 and "active" in out.lower() else "FALLO",
                      "HIGH", out.strip().splitlines()[0] if out else "", "active")
        elif cmd_exists("iptables"):
            rc, out, _ = safe_run(["iptables", "-L", "-n"], timeout=5)
            self._add("iptables tiene reglas",
                      "OK" if rc == 0 and len(out.splitlines()) > 8 else "FALLO",
                      "HIGH", f"{len(out.splitlines())} lineas", ">8")

        if os.path.isfile("/etc/shadow") and os.access("/etc/shadow", os.R_OK):
            empty = 0
            try:
                with open("/etc/shadow", "r") as f:
                    for line in f:
                        parts = line.split(":")
                        if len(parts) > 1 and parts[1] == "":
                            empty += 1
            except Exception:
                pass
            self._add("Cuentas con password vacio",
                      "OK" if empty == 0 else "FALLO",
                      "CRITICAL", str(empty), "0")

        try:
            with open("/proc/sys/kernel/randomize_va_space", "r") as f:
                v = f.read().strip()
            self._add("ASLR (randomize_va_space)",
                      "OK" if v == "2" else "FALLO",
                      "MEDIUM", v, "2")
        except Exception:
            pass

    # ---------- macOS ----------
    def _macos(self) -> None:
        rc, out, _ = safe_run(["csrutil", "status"], timeout=5)
        if rc == 0:
            self._add("SIP activo",
                      "OK" if "enabled" in out.lower() else "FALLO",
                      "HIGH", out.strip(), "enabled")
        rc, out, _ = safe_run(["spctl", "--status"], timeout=5)
        if rc == 0:
            self._add("Gatekeeper activo",
                      "OK" if "enabled" in out.lower() else "FALLO",
                      "HIGH", out.strip(), "enabled")
        rc, out, _ = safe_run(["fdesetup", "status"], timeout=5)
        if rc == 0:
            self._add("FileVault activo",
                      "OK" if "On" in out else "FALLO",
                      "HIGH", out.strip(), "On")

    # ---------- Android ----------
    def _android(self) -> None:
        adb = ["adb"]
        if self.adb_serial:
            adb += ["-s", self.adb_serial]
        rc, out, _ = safe_run(adb + ["shell", "getprop", "ro.debuggable"], timeout=10)
        if rc == 0:
            v = out.strip()
            self._add("USB Debugging userdebug",
                      "OK" if v == "0" else "FALLO",
                      "MEDIUM", v, "0")
        rc, out, _ = safe_run(adb + ["shell", "getprop", "ro.build.version.security_patch"], timeout=10)
        if rc == 0 and out.strip():
            try:
                patch = _dt.datetime.strptime(out.strip(), "%Y-%m-%d")
                age = (_dt.datetime.now() - patch).days
                self._add("Patch de seguridad reciente",
                          "OK" if age <= 90 else "FALLO",
                          "HIGH" if age > 180 else "MEDIUM",
                          f"{age} dias", "<=90 dias")
            except Exception:
                pass


# -----------------------------------------------------------------------------
# 6. NetworkScanner
# -----------------------------------------------------------------------------

class NetworkScanner:
    def __init__(self, target: str = "127.0.0.1", verbose: bool = False):
        self.target = target
        self.verbose = verbose
        self.results: List[dict] = []

    def _probe(self, port: int) -> bool:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(1.0)
                return s.connect_ex((self.target, port)) == 0
        except Exception:
            return False

    def scan(self) -> List[dict]:
        threads: List[threading.Thread] = []
        open_ports: List[int] = []
        lock = threading.Lock()

        def worker(p):
            if self._probe(p):
                with lock:
                    open_ports.append(p)

        for port in PUERTOS_RIESGO:
            t = threading.Thread(target=worker, args=(port,), daemon=True)
            t.start()
            threads.append(t)
        for t in threads:
            t.join(timeout=3)

        for p in sorted(open_ports):
            servicio, riesgo = PUERTOS_RIESGO[p]
            self.results.append({
                "puerto": p,
                "servicio": servicio,
                "riesgo": riesgo,
                "estado": "ABIERTO",
            })
        return self.results


# -----------------------------------------------------------------------------
# 7. RemediationEngine
# -----------------------------------------------------------------------------

class RemediationEngine:
    def __init__(self, platform_code: str, dry_run: bool = False, verbose: bool = False,
                 adb_serial: Optional[str] = None):
        self.pc = platform_code
        self.dry_run = dry_run
        self.verbose = verbose
        self.adb_serial = adb_serial
        self.admin = is_admin()

    def _label(self, action: str) -> str:
        return f"[DRY-RUN] {action}" if self.dry_run else action

    def remediate_software(self, vuln: dict) -> str:
        name = vuln.get("software", "")
        if not name:
            return "OMITIDO (sin software)"
        if self.dry_run:
            return self._label(f"Actualizar {name}")
        if self.pc == "W":
            return self._win_update_pkg(name)
        if self.pc == "L":
            return self._linux_update_pkg(name)
        if self.pc == "M":
            return self._mac_update_pkg(name)
        if self.pc == "A":
            return f"PENDIENTE manual: {name}"
        return "OMITIDO"

    def _win_update_pkg(self, name: str) -> str:
        if cmd_exists("scoop"):
            rc, _, err = safe_run(["scoop", "update", name], timeout=180)
            if rc == 0:
                return f"CORREGIDO via scoop"
        if cmd_exists("choco"):
            if not self.admin:
                return "OMITIDO (sin permisos admin para choco)"
            rc, _, err = safe_run(["choco", "upgrade", name, "--yes", "--no-progress"], timeout=300)
            if rc == 0:
                return "CORREGIDO via chocolatey"
        return "PENDIENTE (sin scoop/choco - actualizar manualmente desde web oficial)"

    def _linux_update_pkg(self, name: str) -> str:
        if not self.admin:
            return "OMITIDO (sin sudo)"
        if cmd_exists("apt-get"):
            rc, _, _ = safe_run(["apt-get", "install", "--only-upgrade", "-y", name], timeout=300)
            return "CORREGIDO via apt" if rc == 0 else "PENDIENTE (apt fallo)"
        if cmd_exists("dnf"):
            rc, _, _ = safe_run(["dnf", "upgrade", "-y", name], timeout=300)
            return "CORREGIDO via dnf" if rc == 0 else "PENDIENTE (dnf fallo)"
        if cmd_exists("pacman"):
            rc, _, _ = safe_run(["pacman", "-Syu", "--noconfirm", name], timeout=300)
            return "CORREGIDO via pacman" if rc == 0 else "PENDIENTE (pacman fallo)"
        return "PENDIENTE (gestor no detectado)"

    def _mac_update_pkg(self, name: str) -> str:
        if cmd_exists("brew"):
            rc, _, _ = safe_run(["brew", "upgrade", name], timeout=300)
            return "CORREGIDO via brew" if rc == 0 else "PENDIENTE (brew fallo)"
        return "PENDIENTE (sin brew)"

    def remediate_config(self, check: dict) -> str:
        if check.get("estado") != "FALLO":
            return "OMITIDO"
        if self.dry_run:
            return self._label(f"Corregir: {check['check']}")
        if self.pc == "L" and self.admin:
            return self._fix_linux_config(check)
        if self.pc == "W" and self.admin:
            return self._fix_windows_config(check)
        return "OMITIDO (sin permisos)"

    def _fix_linux_config(self, check: dict) -> str:
        name = check["check"]
        if "PermitRootLogin" in name:
            try:
                with open("/etc/ssh/sshd_config", "r") as f:
                    cfg = f.read()
                new = re.sub(r"^\s*#?\s*PermitRootLogin\s+.*$", "PermitRootLogin no", cfg, flags=re.M)
                if "PermitRootLogin" not in new:
                    new += "\nPermitRootLogin no\n"
                with open("/etc/ssh/sshd_config", "w") as f:
                    f.write(new)
                safe_run(["systemctl", "restart", "sshd"], timeout=15)
                return "CORREGIDO"
            except Exception as e:
                return f"PENDIENTE ({e})"
        if "UFW" in name:
            rc, _, _ = safe_run(["ufw", "--force", "enable"], timeout=10)
            return "CORREGIDO" if rc == 0 else "PENDIENTE"
        if "ASLR" in name:
            try:
                with open("/proc/sys/kernel/randomize_va_space", "w") as f:
                    f.write("2\n")
                with open("/etc/sysctl.d/99-resolvecore.conf", "a") as f:
                    f.write("kernel.randomize_va_space = 2\n")
                return "CORREGIDO"
            except Exception:
                return "PENDIENTE"
        return "PENDIENTE (regla no automatizada)"

    def _fix_windows_config(self, check: dict) -> str:
        name = check["check"]
        if "SMBv1" in name:
            rc, _, _ = safe_run(["powershell", "-NoProfile", "-Command",
                                 "Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force"], timeout=15)
            return "CORREGIDO" if rc == 0 else "PENDIENTE"
        if "Servicio innecesario" in name:
            svc = name.split(":")[-1].strip()
            safe_run(["sc", "stop", svc], timeout=10)
            rc, _, _ = safe_run(["sc", "config", svc, "start=", "disabled"], timeout=10)
            return "CORREGIDO" if rc == 0 else "PENDIENTE"
        if "Firewall" in name:
            rc, _, _ = safe_run(["netsh", "advfirewall", "set", "allprofiles", "state", "on"], timeout=10)
            return "CORREGIDO" if rc == 0 else "PENDIENTE"
        return "PENDIENTE (regla no automatizada)"


# -----------------------------------------------------------------------------
# 8. HistoryManager
# -----------------------------------------------------------------------------

class HistoryManager:
    def __init__(self, output_dir: str):
        self.path = os.path.join(output_dir, "vuln_history.json")

    def load(self) -> List[dict]:
        if not os.path.isfile(self.path):
            return []
        try:
            with open(self.path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return []

    def save_entry(self, entry: dict) -> None:
        hist = self.load()
        hist.append(entry)
        try:
            os.makedirs(os.path.dirname(self.path), exist_ok=True)
            with open(self.path, "w", encoding="utf-8") as f:
                json.dump(hist, f, indent=2, ensure_ascii=False)
        except Exception:
            pass

    def diff(self, prev: dict, current: dict) -> dict:
        prev_cves = {v["cve_id"] for v in prev.get("vulnerabilidades", []) if v.get("cve_id")}
        cur_cves = {v["cve_id"] for v in current.get("vulnerabilidades", []) if v.get("cve_id")}
        return {
            "fecha_previa": prev.get("meta", {}).get("fecha", ""),
            "nuevos": sorted(cur_cves - prev_cves),
            "resueltos": sorted(prev_cves - cur_cves),
            "score_prev": prev.get("meta", {}).get("risk_score"),
            "score_actual": current.get("meta", {}).get("risk_score"),
        }


# -----------------------------------------------------------------------------
# 9. WhitelistManager
# -----------------------------------------------------------------------------

class WhitelistManager:
    def __init__(self, output_dir: str):
        self.path = os.path.join(output_dir, "vuln_whitelist.json")

    def load(self) -> dict:
        if not os.path.isfile(self.path):
            return {"excepciones": []}
        try:
            with open(self.path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {"excepciones": []}

    def save(self, data: dict) -> None:
        try:
            os.makedirs(os.path.dirname(self.path), exist_ok=True)
            with open(self.path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
        except Exception:
            pass

    def active_set(self) -> set:
        today = _dt.date.today().isoformat()
        out = set()
        for e in self.load().get("excepciones", []):
            if e.get("expira", "9999-12-31") >= today:
                out.add(e.get("cve_id"))
        return out

    def add(self, cve_id: str, motivo: str, tecnico: str = "", expira: str = "") -> None:
        data = self.load()
        data.setdefault("excepciones", []).append({
            "cve_id": cve_id,
            "motivo": motivo,
            "tecnico": tecnico or os.environ.get("USERNAME", "desconocido"),
            "fecha": _dt.date.today().isoformat(),
            "expira": expira or (_dt.date.today() + _dt.timedelta(days=180)).isoformat(),
        })
        self.save(data)

    def list_active(self) -> List[dict]:
        today = _dt.date.today().isoformat()
        return [e for e in self.load().get("excepciones", []) if e.get("expira", "9999-12-31") >= today]

    def list_expired(self) -> List[dict]:
        today = _dt.date.today().isoformat()
        return [e for e in self.load().get("excepciones", []) if e.get("expira", "9999-12-31") < today]


# -----------------------------------------------------------------------------
# 10. DepsScanner
# -----------------------------------------------------------------------------

class DepsScanner:
    def __init__(self, scanner: VulnScanner, max_depth: int = 4, verbose: bool = False):
        self.scanner = scanner
        self.max_depth = max_depth
        self.verbose = verbose

    def find_files(self, roots: List[str]) -> List[Tuple[str, str]]:
        found: List[Tuple[str, str]] = []
        for root in roots:
            if not os.path.isdir(root):
                continue
            base_depth = root.rstrip(os.sep).count(os.sep)
            for dirpath, dirs, files in os.walk(root, topdown=True):
                depth = dirpath.count(os.sep) - base_depth
                if depth > self.max_depth:
                    dirs[:] = []
                    continue
                dirs[:] = [d for d in dirs if d not in (".git", "node_modules", "__pycache__", ".venv", "venv")]
                for f in files:
                    if f in DEPS_FILES:
                        found.append((os.path.join(dirpath, f), DEPS_FILES[f]))
        return found

    def parse_requirements(self, path: str) -> List[Tuple[str, str]]:
        out = []
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    m = re.match(r"^([A-Za-z0-9_.\-]+)\s*[=<>~!]+\s*([0-9A-Za-z._\-]+)", line)
                    if m:
                        out.append((m.group(1), m.group(2)))
        except Exception:
            pass
        return out

    def parse_package_json(self, path: str) -> List[Tuple[str, str]]:
        out = []
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            for k in ("dependencies", "devDependencies"):
                for n, v in (data.get(k) or {}).items():
                    out.append((n, str(v).lstrip("^~>=< ")))
        except Exception:
            pass
        return out

    def scan(self, roots: List[str]) -> List[dict]:
        results: List[dict] = []
        files = self.find_files(roots)
        for path, ecosystem in files:
            if path.endswith("requirements.txt"):
                pkgs = self.parse_requirements(path)
            elif path.endswith("package.json"):
                pkgs = self.parse_package_json(path)
            else:
                continue
            for name, ver in pkgs[:10]:
                vulns = self.scanner.query_osv(name, ver, ecosystem)
                for v in vulns:
                    v["origen"] = path
                    v["ecosystem"] = ecosystem
                    results.append(v)
        return results


# -----------------------------------------------------------------------------
# 11. LogAnalyzer
# -----------------------------------------------------------------------------

class LogAnalyzer:
    def __init__(self, platform_code: str, adb_serial: Optional[str] = None, verbose: bool = False):
        self.pc = platform_code
        self.adb_serial = adb_serial
        self.verbose = verbose

    def run(self) -> List[dict]:
        if self.pc == "L":
            return self._linux()
        if self.pc == "W":
            return self._windows()
        if self.pc == "A":
            return self._android()
        return []

    def _linux(self) -> List[dict]:
        out: List[dict] = []
        for path in ("/var/log/auth.log", "/var/log/secure"):
            if not os.path.isfile(path) or not os.access(path, os.R_OK):
                continue
            try:
                with open(path, "r", errors="ignore") as f:
                    text = f.read()[-200000:]
                ips = re.findall(r"Failed password.*from\s+(\d+\.\d+\.\d+\.\d+)", text)
                from collections import Counter
                cnt = Counter(ips)
                for ip, n in cnt.items():
                    if n > 10:
                        out.append({
                            "tipo": "BruteForce",
                            "fuente": path,
                            "detalle": f"{n} intentos fallidos desde {ip}",
                            "riesgo": "HIGH",
                            "recomendacion": f"sudo ufw deny from {ip}",
                        })
            except Exception:
                pass
        return out

    def _windows(self) -> List[dict]:
        out: List[dict] = []
        rc, ev, _ = safe_run(
            ["powershell", "-NoProfile", "-Command",
             "(Get-WinEvent -FilterHashtable @{LogName='Security';Id=4625;StartTime=(Get-Date).AddHours(-1)} -ErrorAction SilentlyContinue).Count"],
            timeout=20)
        if rc == 0:
            try:
                n = int(ev.strip() or "0")
                if n > 10:
                    out.append({
                        "tipo": "BruteForce",
                        "fuente": "EventLog Security 4625",
                        "detalle": f"{n} logins fallidos en 1h",
                        "riesgo": "HIGH",
                        "recomendacion": "Revisar IPs de origen y bloquear en firewall",
                    })
            except Exception:
                pass
        return out

    def _android(self) -> List[dict]:
        return []


# -----------------------------------------------------------------------------
# 12. RiskScorer
# -----------------------------------------------------------------------------

def compute_risk_score(vulns: List[dict], cfg_checks: List[dict], net: List[dict],
                       iocs: List[dict], remediated: int) -> Tuple[int, str, List[str]]:
    """Devuelve (score, nivel, desglose). Desglose = lista legible de penalizaciones."""
    score = 100
    desglose: List[str] = ["Base inicial: +100"]

    for v in vulns:
        if (v.get("estado") or "").startswith("CORREGIDO"):
            continue
        sev = (v.get("severity") or "").upper()
        if sev == "CRITICAL":
            score -= 15
            desglose.append(f"-15 CVE CRITICAL: {v.get('cve_id', '?')}")
        elif sev == "HIGH":
            score -= 8
            desglose.append(f"-8 CVE HIGH: {v.get('cve_id', '?')}")
        elif sev == "MEDIUM":
            score -= 3
            desglose.append(f"-3 CVE MEDIUM: {v.get('cve_id', '?')}")
        if v.get("kev"):
            score -= 20
            desglose.append(f"-20 CVE en CISA KEV: {v.get('cve_id', '?')}")

    for c in cfg_checks:
        if c.get("estado") != "FALLO":
            continue
        riesgo = (c.get("riesgo") or "").upper()
        if riesgo == "CRITICAL":
            score -= 20
            desglose.append(f"-20 Config CRITICAL FALLO: {c.get('check')}")
        elif riesgo == "HIGH":
            score -= 10
            desglose.append(f"-10 Config HIGH FALLO: {c.get('check')}")
        elif riesgo == "MEDIUM":
            score -= 4
            desglose.append(f"-4 Config MEDIUM FALLO: {c.get('check')}")

    for n in net:
        riesgo = (n.get("riesgo") or "").upper()
        penal = 8 if riesgo == "CRITICAL" else (5 if riesgo == "HIGH" else 3)
        score -= penal
        desglose.append(f"-{penal} Puerto abierto {n.get('puerto')} ({n.get('servicio')})")

    for ioc in iocs:
        if (ioc.get("riesgo") or "").upper() == "HIGH":
            score -= 25
            desglose.append(f"-25 IOC HIGH: {ioc.get('tipo')}")

    if remediated:
        score += 5 * remediated
        desglose.append(f"+{5 * remediated} Remediaciones aplicadas ({remediated})")

    score = max(0, min(100, score))
    if score >= 80:
        nivel = "BUENO"
    elif score >= 50:
        nivel = "MEJORABLE"
    else:
        nivel = "CRITICO"
    return score, nivel, desglose


def build_severity_summary(vulns: List[dict]) -> Dict[str, int]:
    out = {"critical": 0, "high": 0, "medium": 0, "low": 0, "kev": 0, "unknown": 0}
    for v in vulns:
        if (v.get("estado") or "").startswith("CORREGIDO"):
            continue
        sev = (v.get("severity") or "UNKNOWN").upper()
        key = sev.lower() if sev.lower() in out else "unknown"
        out[key] += 1
        if v.get("kev"):
            out["kev"] += 1
    return out


def build_client_message(nivel: str, vulns: List[dict], cfg_checks: List[dict],
                         net: List[dict], iocs: List[dict]) -> str:
    """Construye mensaje cliente personalizado por hallazgos reales."""
    pendientes_cves = [v for v in vulns if not (v.get("estado") or "").startswith("CORREGIDO")
                       and v.get("estado") != "EXCEPCION ACEPTADA"]
    kev_count = sum(1 for v in pendientes_cves if v.get("kev"))
    crit_count = sum(1 for v in pendientes_cves if (v.get("severity") or "").upper() == "CRITICAL")
    cfg_critical = [c for c in cfg_checks if c.get("estado") == "FALLO"
                    and (c.get("riesgo") or "").upper() == "CRITICAL"]
    high_ports = [n for n in net if (n.get("riesgo") or "").upper() in ("HIGH", "CRITICAL")]

    parts: List[str] = []
    if nivel == "BUENO":
        parts.append("Su equipo presenta un buen nivel de seguridad.")
    elif nivel == "MEJORABLE":
        parts.append("Su equipo necesita atencion: se han detectado puntos de mejora.")
    else:
        parts.append("Su equipo presenta riesgos criticos. Es necesario actuar de inmediato.")

    if kev_count:
        parts.append(f"Se han detectado {kev_count} vulnerabilidad(es) en explotacion activa "
                     "segun la lista CISA KEV. Estas requieren parche urgente.")
    if crit_count:
        parts.append(f"Hay {crit_count} CVE de severidad critica en software instalado.")
    if cfg_critical:
        nombres = ", ".join(c.get("check", "") for c in cfg_critical[:3])
        parts.append(f"Configuracion de seguridad insuficiente en: {nombres}.")
    if high_ports:
        servicios = ", ".join(f"{n.get('puerto')} ({n.get('servicio', '').split(' ')[0]})"
                              for n in high_ports[:3])
        parts.append(f"Hay servicios sensibles expuestos en red local: {servicios}. "
                     "Se recomienda revisar firewall y autenticacion.")
    if iocs:
        parts.append(f"Se han detectado {len(iocs)} indicador(es) de compromiso en logs. "
                     "Revisar acceso al equipo.")

    if nivel == "BUENO" and len(parts) == 1:
        parts.append("Continuar con el mantenimiento periodico recomendado.")

    return " ".join(parts)


def next_review_date(nivel: str) -> str:
    days = {"BUENO": 90, "MEJORABLE": 30, "CRITICO": 7}.get(nivel, 90)
    target = _dt.date.today() + _dt.timedelta(days=days)
    return f"En {days} dias ({target.isoformat()})"


def render_score_bar(score: int) -> str:
    filled = int(score / 5)
    return "[" + "#" * filled + "." * (20 - filled) + f"] {score}/100"


# -----------------------------------------------------------------------------
# 13. ReportGenerator
# -----------------------------------------------------------------------------

class ReportGenerator:
    def __init__(self, output_dir: str, hostname: str, platform_label: str):
        self.output_dir = output_dir
        self.hostname = hostname
        self.platform_label = platform_label
        os.makedirs(output_dir, exist_ok=True)

    def _base(self) -> str:
        return os.path.join(self.output_dir, f"vuln_{self.hostname}_{now_stamp()}")

    def write_json(self, data: dict) -> str:
        path = self._base() + ".json"
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        return path

    def write_txt(self, data: dict) -> str:
        path = self._base() + ".txt"
        meta = data.get("meta", {})
        res = data.get("resumen", {})
        os_info = data.get("os", {})
        sev = data.get("por_severidad", {})

        score = meta.get("risk_score", 0)
        nivel = meta.get("risk_nivel", "")
        bar = render_score_bar(score)
        emoji = {"BUENO": "[OK]", "MEJORABLE": "[!]", "CRITICO": "[X]"}.get(nivel, "[?]")

        try:
            fecha_obj = _dt.datetime.fromisoformat(meta.get("fecha", ""))
            fecha_humana = fecha_obj.strftime("%d de %B de %Y, %H:%M")
        except Exception:
            fecha_humana = meta.get("fecha", "")

        lines = [
            "=" * 75,
            "  RESOLVECORE -- INFORME DE VULNERABILIDADES",
            "=" * 75,
            "",
            "  IDENTIFICACION",
            "  " + "-" * 73,
            f"  Equipo:        {meta.get('hostname', '')}",
            f"  Sistema:       {os_info.get('producto', meta.get('plataforma', ''))}",
            f"  Build/Version: {os_info.get('build', '?')} / {os_info.get('version', '?')}",
            f"  Kernel:        {os_info.get('kernel', '?')}",
            f"  Fecha scan:    {fecha_humana}",
            f"  Tecnico admin: {'si' if meta.get('admin') else 'no'}",
            f"  Modo:          {'DRY-RUN (sin cambios)' if meta.get('dry_run') else 'NORMAL'}",
            f"  Duracion:      {meta.get('duracion_segundos', 0)}s",
            "",
            "  PUNTUACION DE RIESGO",
            "  " + "-" * 73,
            f"  RiskScore:  {bar}",
            f"  Nivel:      {emoji} {nivel}",
            "",
            "  RESUMEN EJECUTIVO",
            "  " + "-" * 73,
            f"  CVEs detectados:  {res.get('total_cves', 0):>3}   "
            f"(KEV: {sev.get('kev', 0)} | CRIT: {sev.get('critical', 0)} | "
            f"HIGH: {sev.get('high', 0)} | MED: {sev.get('medium', 0)})",
            f"  CVEs corregidos:  {res.get('corregidos', 0):>3}",
            f"  CVEs pendientes:  {res.get('pendientes', 0):>3}",
            f"  Config auditados: {res.get('checks_config', 0):>3}   "
            f"(fallidos: {res.get('checks_fallidos', 0)})",
            f"  Puertos riesgo:   {res.get('puertos_riesgo', 0):>3}",
            f"  IOCs en logs:     {len(data.get('iocs', [])):>3}",
            f"  Excepciones:      {len(data.get('excepciones_activas', [])):>3}",
            "",
        ]

        # Vulnerabilidades
        lines += ["  VULNERABILIDADES (CVEs)", "  " + "-" * 73]
        vulns = data.get("vulnerabilidades", [])
        if not vulns:
            lines.append("  Sin CVEs detectados sobre el umbral configurado.")
        else:
            for v in vulns:
                kev_tag = " [KEV]" if v.get("kev") else ""
                cvss = v.get("cvss", 0)
                epss = v.get("epss", 0)
                pct = v.get("epss_percentile", 0)
                lines.append(
                    f"  * {v.get('cve_id', '?'):<18}{kev_tag}"
                )
                lines.append(
                    f"      Software:    {v.get('software', '')[:55]} {v.get('version', '')}"
                )
                lines.append(
                    f"      Severidad:   {v.get('severity', 'UNKNOWN')} | CVSS {cvss} | EPSS {epss:.3f} (pct {pct:.0%})"
                )
                lines.append(
                    f"      Estado:      {v.get('estado', 'PENDIENTE')}"
                )
                desc = (v.get("descripcion", "") or "").replace("\n", " ")[:200]
                if desc:
                    lines.append(f"      Descripcion: {desc}")
                lines.append("")
        lines.append("")

        # Config checks
        lines += ["  AUDITORIA DE CONFIGURACION", "  " + "-" * 73]
        for c in data.get("config_checks", []):
            mark = "[OK]" if c.get("estado", "").startswith("OK") else "[X] "
            lines.append(
                f"  {mark} {c.get('check', ''):<40} riesgo={c.get('riesgo', ''):<8} "
                f"actual={c.get('valor_actual', '')[:20]}"
            )
            if c.get("estado") == "FALLO":
                lines.append(
                    f"        -> esperado={c.get('valor_esperado', '')} | accion={c.get('accion', 'PENDIENTE')}"
                )
        lines.append("")

        # Network
        lines += ["  PUERTOS DE RIESGO ABIERTOS", "  " + "-" * 73]
        red = data.get("red", [])
        if not red:
            lines.append("  Sin puertos de la lista de riesgo expuestos.")
        else:
            for n in red:
                lines.append(
                    f"  [X] tcp/{n.get('puerto', '?'):<5} {n.get('servicio', ''):<35} riesgo={n.get('riesgo', '')}"
                )
        lines.append("")

        # IOCs
        if data.get("iocs"):
            lines += ["  INDICADORES DE COMPROMISO (IOCs)", "  " + "-" * 73]
            for i in data["iocs"]:
                lines.append(
                    f"  [!] {i.get('tipo', ''):<15} {i.get('detalle', '')}"
                )
                lines.append(
                    f"      Recomendacion: {i.get('recomendacion', '')}"
                )
            lines.append("")

        # Comparativa
        if data.get("comparativa"):
            comp = data["comparativa"]
            delta = (comp.get("score_actual") or 0) - (comp.get("score_prev") or 0)
            arrow = "MEJORADO" if delta > 0 else ("EMPEORADO" if delta < 0 else "IGUAL")
            lines += [
                "  COMPARATIVA CON ESCANEO ANTERIOR",
                "  " + "-" * 73,
                f"  Fecha previa:   {comp.get('fecha_previa', '?')}",
                f"  CVEs nuevos:    +{len(comp.get('nuevos', []))}",
                f"  CVEs resueltos: -{len(comp.get('resueltos', []))}",
                f"  RiskScore:      {comp.get('score_prev', '?')} -> {comp.get('score_actual', '?')} "
                f"({'+' if delta >= 0 else ''}{delta}) {arrow}",
                "",
            ]

        # Pendientes priorizados
        lines += ["  ACCIONES PRIORIZADAS PARA EL TECNICO", "  " + "-" * 73]
        pendientes = data.get("pendientes_tecnico", [])
        if not pendientes:
            lines.append("  Sin acciones pendientes.")
        else:
            for i, p in enumerate(pendientes, 1):
                lines.append(f"  {i:>2}. {p}")
        lines.append("")

        # Mensaje cliente
        lines += [
            "  MENSAJE PARA EL CLIENTE",
            "  " + "-" * 73,
            "  " + (data.get("mensaje_cliente", "") or "").replace("\n", "\n  "),
            "",
            "  PROXIMA REVISION RECOMENDADA",
            "  " + "-" * 73,
            f"  {meta.get('proxima_revision', 'En 90 dias')}",
            "",
            "=" * 75,
            f"  Generado por ResolveCore VulnScanner v{meta.get('script_version', SCRIPT_VERSION)}",
            "=" * 75,
        ]

        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
        return path

    def write_html(self, data: dict) -> str:
        path = self._base() + ".html"
        meta = data.get("meta", {})
        res = data.get("resumen", {})
        score = meta.get("risk_score", 0)
        nivel = meta.get("risk_nivel", "")
        nivel_class = {"BUENO": "ok", "MEJORABLE": "warn", "CRITICO": "crit"}.get(nivel, "warn")

        # SVG gauge
        radius = 80
        circ = 2 * 3.14159 * radius
        offset = circ * (1 - score / 100)
        gauge_color = {"BUENO": "var(--accent)", "MEJORABLE": "var(--yellow)", "CRITICO": "var(--red)"}[nivel] \
            if nivel in ("BUENO", "MEJORABLE", "CRITICO") else "var(--yellow)"

        def esc(s: Any) -> str:
            return (str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))

        rows_cve = []
        for v in data.get("vulnerabilidades", []):
            sev = (v.get("severity") or "").upper()
            kev = v.get("kev")
            cls = "row-crit" if (sev == "CRITICAL" or kev) else ("row-warn" if sev == "HIGH" else "")
            if (v.get("estado") or "").startswith("CORREGIDO"):
                cls = "row-ok"
            rows_cve.append(
                f'<tr class="{cls}"><td>{esc(v.get("cve_id", ""))}{" <b>[KEV]</b>" if kev else ""}</td>'
                f'<td>{esc(v.get("software", ""))} {esc(v.get("version", ""))}</td>'
                f'<td>{esc(v.get("cvss", 0))}</td>'
                f'<td>{esc(round(float(v.get("epss", 0)), 3))}</td>'
                f'<td>{"&#10003;" if kev else "&mdash;"}</td>'
                f'<td>{esc(v.get("estado", "PENDIENTE"))}</td>'
                f'<td>{esc(v.get("descripcion", ""))[:200]}</td></tr>'
            )

        rows_cfg = []
        for c in data.get("config_checks", []):
            cls = "row-warn" if c.get("estado") == "FALLO" else "row-ok"
            rows_cfg.append(
                f'<tr class="{cls}"><td>{esc(c.get("check", ""))}</td>'
                f'<td>{esc(c.get("estado", ""))}</td>'
                f'<td>{esc(c.get("riesgo", ""))}</td>'
                f'<td>{esc(c.get("valor_actual", ""))}</td>'
                f'<td>{esc(c.get("valor_esperado", ""))}</td>'
                f'<td>{esc(c.get("accion", ""))}</td></tr>'
            )

        rows_net = []
        for n in data.get("red", []):
            rows_net.append(
                f'<tr class="row-warn"><td>{esc(n.get("puerto", ""))}</td>'
                f'<td>{esc(n.get("servicio", ""))}</td>'
                f'<td>{esc(n.get("riesgo", ""))}</td>'
                f'<td>{esc(n.get("estado", ""))}</td></tr>'
            )

        ioc_section = ""
        if data.get("iocs"):
            rows_ioc = []
            for i in data["iocs"]:
                rows_ioc.append(
                    f'<tr class="row-warn"><td>{esc(i.get("tipo", ""))}</td>'
                    f'<td>{esc(i.get("fuente", ""))}</td>'
                    f'<td>{esc(i.get("detalle", ""))}</td>'
                    f'<td>{esc(i.get("riesgo", ""))}</td>'
                    f'<td>{esc(i.get("recomendacion", ""))}</td></tr>'
                )
            ioc_section = (
                '<section><h2>IOCs detectados (logs)</h2>'
                '<table><thead><tr><th>Tipo</th><th>Fuente</th><th>Detalle</th><th>Riesgo</th><th>Recomendacion</th></tr></thead>'
                f'<tbody>{"".join(rows_ioc)}</tbody></table></section>'
            )

        deps_section = ""
        if data.get("dependencias_vulnerables"):
            rows_d = []
            for d in data["dependencias_vulnerables"]:
                rows_d.append(
                    f'<tr><td>{esc(d.get("origen", ""))}</td>'
                    f'<td>{esc(d.get("ecosystem", ""))}</td>'
                    f'<td>{esc(d.get("software", ""))} {esc(d.get("version", ""))}</td>'
                    f'<td>{esc(d.get("cve_id", ""))}</td>'
                    f'<td>{esc(d.get("severity", ""))}</td></tr>'
                )
            deps_section = (
                '<section><h2>Dependencias vulnerables</h2>'
                '<table><thead><tr><th>Origen</th><th>Eco</th><th>Paquete</th><th>CVE</th><th>Sev</th></tr></thead>'
                f'<tbody>{"".join(rows_d)}</tbody></table></section>'
            )

        comp_section = ""
        if data.get("comparativa"):
            comp = data["comparativa"]
            comp_section = (
                f'<section><h2>Comparativa con escaneo anterior</h2>'
                f'<p>Fecha previa: <b>{esc(comp.get("fecha_previa", ""))}</b></p>'
                f'<p>CVEs nuevos: <b>{len(comp.get("nuevos", []))}</b> | resueltos: <b>{len(comp.get("resueltos", []))}</b></p>'
                f'<p>RiskScore: {esc(comp.get("score_prev", "?"))} &rarr; {esc(comp.get("score_actual", "?"))}</p>'
                f'</section>'
            )

        pend_items = "".join(f"<li>{esc(p)}</li>" for p in data.get("pendientes_tecnico", []))

        sev = data.get("por_severidad", {})
        sev_chips = (
            f'<span class="chip chip-kev">KEV: {sev.get("kev", 0)}</span>'
            f'<span class="chip chip-crit">CRITICAL: {sev.get("critical", 0)}</span>'
            f'<span class="chip chip-high">HIGH: {sev.get("high", 0)}</span>'
            f'<span class="chip chip-med">MEDIUM: {sev.get("medium", 0)}</span>'
        )

        desglose_html = "".join(f"<li>{esc(d)}</li>" for d in data.get("score_desglose", []))

        os_info = data.get("os", {})
        msg_class = nivel_class
        msg_cliente = data.get("mensaje_cliente", "")
        proxima = meta.get("proxima_revision", "")
        duracion = meta.get("duracion_segundos", 0)

        html = f"""<!DOCTYPE html>
<html lang="es"><head><meta charset="utf-8"><title>ResolveCore - Vulnerabilidades {esc(self.hostname)}</title>
<style>
:root {{
  --bg:#0a0c10; --surface:#0f1117; --surface2:#141720; --border:#1e2330;
  --accent:#00e5a0; --accent-d:rgba(0,229,160,.12);
  --text:#e8eaf0; --muted:#7a7f8e;
  --red:#ff4757; --red-d:rgba(255,71,87,.13);
  --yellow:#ffc107; --yellow-d:rgba(255,193,7,.12);
  --mono:'Space Mono','Courier New',monospace;
  --sans:'DM Sans',system-ui,sans-serif;
}}
* {{ box-sizing:border-box; }}
body {{ margin:0; font-family:var(--sans); background:var(--bg); color:var(--text); line-height:1.5; }}
header {{ background:var(--surface); border-bottom:1px solid var(--border); padding:24px 32px; }}
header h1 {{ margin:0; font-family:var(--mono); color:var(--accent); letter-spacing:2px; }}
header .meta {{ color:var(--muted); font-size:14px; margin-top:8px; }}
main {{ max-width:1200px; margin:0 auto; padding:24px 32px; }}
section {{ margin-bottom:32px; }}
h2 {{ font-family:var(--mono); border-left:3px solid var(--accent); padding-left:12px; }}
.cards {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(180px,1fr)); gap:16px; margin:16px 0; }}
.card {{ background:var(--surface); border:1px solid var(--border); border-radius:8px; padding:18px; }}
.card .num {{ font-size:32px; font-weight:bold; font-family:var(--mono); color:var(--accent); }}
.card .lbl {{ color:var(--muted); font-size:12px; text-transform:uppercase; letter-spacing:1px; }}
.gauge-wrap {{ display:flex; align-items:center; gap:24px; background:var(--surface); border:1px solid var(--border); border-radius:8px; padding:24px; }}
.gauge-wrap .info h3 {{ margin:0; font-family:var(--mono); }}
.gauge-wrap.ok h3 {{ color:var(--accent); }}
.gauge-wrap.warn h3 {{ color:var(--yellow); }}
.gauge-wrap.crit h3 {{ color:var(--red); }}
table {{ width:100%; border-collapse:collapse; background:var(--surface); border:1px solid var(--border); border-radius:8px; overflow:hidden; }}
th, td {{ padding:10px 12px; border-bottom:1px solid var(--border); text-align:left; font-size:14px; }}
th {{ background:var(--surface2); font-family:var(--mono); color:var(--muted); text-transform:uppercase; font-size:12px; }}
tr.row-crit {{ background:var(--red-d); }}
tr.row-warn {{ background:var(--yellow-d); }}
tr.row-ok {{ background:var(--accent-d); }}
ul.pend li {{ background:var(--red-d); border-left:3px solid var(--red); padding:8px 12px; margin:6px 0; border-radius:4px; }}
.chip {{ display:inline-block; padding:4px 10px; margin-right:6px; border-radius:12px; font-family:var(--mono); font-size:12px; border:1px solid var(--border); }}
.chip-kev {{ background:var(--red-d); color:var(--red); border-color:var(--red); font-weight:bold; }}
.chip-crit {{ background:var(--red-d); color:var(--red); }}
.chip-high {{ background:var(--yellow-d); color:var(--yellow); }}
.chip-med {{ background:var(--surface2); color:var(--muted); }}
.banner {{ padding:20px 24px; border-radius:8px; margin:20px 0; border-left:4px solid var(--accent); background:var(--surface); }}
.banner.warn {{ border-left-color:var(--yellow); background:var(--yellow-d); }}
.banner.crit {{ border-left-color:var(--red); background:var(--red-d); }}
.banner h3 {{ margin:0 0 8px 0; font-family:var(--mono); }}
.banner p {{ margin:0; line-height:1.6; }}
details.score-detail summary {{ cursor:pointer; color:var(--accent); font-family:var(--mono); padding:8px 0; }}
details.score-detail ul {{ list-style:none; padding:0; font-family:var(--mono); font-size:12px; color:var(--muted); }}
details.score-detail li {{ padding:2px 0; border-bottom:1px solid var(--border); }}
.os-info {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(180px,1fr)); gap:8px; font-family:var(--mono); font-size:13px; color:var(--muted); }}
.os-info span b {{ color:var(--text); }}
footer {{ color:var(--muted); padding:24px 32px; border-top:1px solid var(--border); font-family:var(--mono); font-size:12px; }}
@media print {{ body {{ background:white; color:black; }} table, .card, .gauge-wrap {{ break-inside:avoid; }} }}
</style></head><body>
<header>
  <h1>RESOLVECORE</h1>
  <div class="meta">Vulnerabilidades | {esc(meta.get('hostname', ''))} | {esc(meta.get('plataforma', ''))} | {esc(meta.get('fecha', ''))}</div>
</header>
<main>
<section class="os-info">
  <span><b>Hostname:</b> {esc(meta.get('hostname', ''))}</span>
  <span><b>Sistema:</b> {esc(os_info.get('producto', ''))}</span>
  <span><b>Build:</b> {esc(os_info.get('build', '?'))} / {esc(os_info.get('version', '?'))}</span>
  <span><b>Kernel:</b> {esc(os_info.get('kernel', '?'))}</span>
  <span><b>Admin:</b> {'si' if meta.get('admin') else 'no'}</span>
  <span><b>Modo:</b> {'DRY-RUN' if meta.get('dry_run') else 'Normal'}</span>
  <span><b>Duracion:</b> {duracion}s</span>
  <span><b>Proxima revision:</b> {esc(proxima)}</span>
</section>
<section><div class="gauge-wrap {nivel_class}">
  <svg width="200" height="200" viewBox="0 0 200 200">
    <circle cx="100" cy="100" r="{radius}" stroke="var(--border)" stroke-width="14" fill="none"/>
    <circle cx="100" cy="100" r="{radius}" stroke="{gauge_color}" stroke-width="14" fill="none"
            stroke-dasharray="{circ:.2f}" stroke-dashoffset="{offset:.2f}"
            transform="rotate(-90 100 100)" stroke-linecap="round"/>
    <text x="100" y="95" text-anchor="middle" font-family="Space Mono,monospace" font-size="36" fill="var(--text)">{score}</text>
    <text x="100" y="120" text-anchor="middle" font-family="Space Mono,monospace" font-size="14" fill="var(--muted)">/ 100</text>
  </svg>
  <div class="info">
    <h3>{esc(nivel)}</h3>
    <p>RiskScore del sistema</p>
    <p>{sev_chips}</p>
    <details class="score-detail"><summary>Ver desglose del calculo</summary>
      <ul>{desglose_html}</ul>
    </details>
  </div>
</div></section>
<section><div class="banner {msg_class}">
  <h3>Mensaje para el cliente</h3>
  <p>{esc(msg_cliente)}</p>
</div></section>
<section><div class="cards">
  <div class="card"><div class="num">{res.get('total_cves', 0)}</div><div class="lbl">CVEs totales</div></div>
  <div class="card"><div class="num">{res.get('corregidos', 0)}</div><div class="lbl">Corregidos</div></div>
  <div class="card"><div class="num">{res.get('pendientes', 0)}</div><div class="lbl">Pendientes</div></div>
  <div class="card"><div class="num">{res.get('checks_fallidos', 0)}</div><div class="lbl">Config fallos</div></div>
  <div class="card"><div class="num">{res.get('puertos_riesgo', 0)}</div><div class="lbl">Puertos riesgo</div></div>
</div></section>
<section><h2>Vulnerabilidades (CVEs)</h2>
<table><thead><tr><th>CVE</th><th>Software</th><th>CVSS</th><th>EPSS</th><th>KEV</th><th>Estado</th><th>Descripcion</th></tr></thead>
<tbody>{''.join(rows_cve) or '<tr><td colspan="7">Sin CVEs</td></tr>'}</tbody></table></section>
<section><h2>Auditoria de configuracion</h2>
<table><thead><tr><th>Check</th><th>Estado</th><th>Riesgo</th><th>Actual</th><th>Esperado</th><th>Accion</th></tr></thead>
<tbody>{''.join(rows_cfg) or '<tr><td colspan="6">Sin checks</td></tr>'}</tbody></table></section>
<section><h2>Puertos de riesgo</h2>
<table><thead><tr><th>Puerto</th><th>Servicio</th><th>Riesgo</th><th>Estado</th></tr></thead>
<tbody>{''.join(rows_net) or '<tr><td colspan="4">Sin puertos abiertos en lista de riesgo</td></tr>'}</tbody></table></section>
{ioc_section}
{deps_section}
{comp_section}
<section><h2>Pendiente para el tecnico</h2><ul class="pend">{pend_items or '<li>Sin pendientes</li>'}</ul></section>
</main>
<footer>ResolveCore VulnScanner v{SCRIPT_VERSION} | {esc(self.hostname)} | Generado {esc(meta.get('fecha', ''))}</footer>
</body></html>"""
        with open(path, "w", encoding="utf-8") as f:
            f.write(html)
        return path


# -----------------------------------------------------------------------------
# 14. Notifier (smtplib only)
# -----------------------------------------------------------------------------

class Notifier:
    def __init__(self, recipient: str, verbose: bool = False):
        self.recipient = recipient
        self.verbose = verbose

    def _build(self, subject: str, body: str, attachments: List[str]) -> MIMEMultipart:
        msg = MIMEMultipart("mixed")
        msg["From"] = os.environ.get("SMTP_FROM", "resolvecore@localhost")
        msg["To"] = self.recipient
        msg["Subject"] = subject
        msg.attach(MIMEText(body, "plain", "utf-8"))
        for path in attachments:
            if not os.path.isfile(path):
                continue
            with open(path, "rb") as f:
                part = MIMEBase("application", "octet-stream")
                part.set_payload(f.read())
            encoders.encode_base64(part)
            part.add_header("Content-Disposition", f'attachment; filename="{os.path.basename(path)}"')
            msg.attach(part)
        return msg

    def send(self, subject: str, body: str, attachments: List[str], output_dir: str) -> bool:
        msg = self._build(subject, body, attachments)
        host = os.environ.get("SMTP_HOST", "")
        port = int(os.environ.get("SMTP_PORT", "0") or 0)
        user = os.environ.get("SMTP_USER", "")
        pw = os.environ.get("SMTP_PASS", "")

        candidates: List[Tuple[str, int, bool]] = []
        if host and port:
            candidates.append((host, port, bool(user)))
        candidates.append(("localhost", 25, False))
        candidates.append(("localhost", 1025, False))

        for h, p, auth in candidates:
            try:
                with smtplib.SMTP(h, p, timeout=10) as s:
                    if auth:
                        s.starttls(context=ssl.create_default_context())
                        s.login(user, pw)
                    s.send_message(msg)
                    cprint(f"  [OK] Email enviado via {h}:{p}", C.G)
                    return True
            except Exception as e:
                if self.verbose:
                    cprint(f"  [!] SMTP {h}:{p} fallo: {e}", C.GR)
                continue

        if cmd_exists("msmtp"):
            try:
                proc = subprocess.run(["msmtp", "-t"], input=msg.as_bytes(), timeout=15, check=False)
                if proc.returncode == 0:
                    cprint("  [OK] Email enviado via msmtp", C.G)
                    return True
            except Exception:
                pass

        fallback = os.path.join(output_dir, f"email_pendiente_{now_stamp()}.eml")
        try:
            with open(fallback, "wb") as f:
                f.write(msg.as_bytes())
            cprint(f"  [!] No SMTP disponible. Email guardado en {fallback}", C.Y)
        except Exception:
            pass
        return False


# -----------------------------------------------------------------------------
# 15. MantisBTClient
# -----------------------------------------------------------------------------

class MantisBTClient:
    def __init__(self, url: str, token: str, project_id: int = 1, verbose: bool = False):
        self.url = url.rstrip("/")
        self.token = token
        self.project_id = project_id
        self.verbose = verbose

    def is_configured(self) -> bool:
        return bool(self.url and self.token)

    def _req(self, method: str, path: str, body: Optional[bytes] = None,
             ctype: str = "application/json", extra: Optional[dict] = None) -> Optional[dict]:
        url = f"{self.url}{path}"
        headers = {"Authorization": self.token, "User-Agent": USER_AGENT}
        if ctype:
            headers["Content-Type"] = ctype
        if extra:
            headers.update(extra)
        req = urllib.request.Request(url, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                txt = resp.read().decode("utf-8", errors="replace")
                return json.loads(txt) if txt else {}
        except Exception as e:
            if self.verbose:
                cprint(f"  [!] Mantis {method} {path} fallo: {e}", C.Y)
            return None

    def create_issue(self, summary: str, description: str, has_kev: bool, has_critical: bool) -> Optional[int]:
        payload = {
            "summary": summary,
            "description": description,
            "project": {"id": self.project_id},
            "category": {"name": "Seguridad"},
            "priority": {"name": "high" if has_kev else "normal"},
            "severity": {"name": "major" if has_critical else "minor"},
        }
        d = self._req("POST", "/api/rest/issues", body=json.dumps(payload).encode("utf-8"))
        if not d:
            return None
        try:
            return int(d.get("issue", {}).get("id"))
        except Exception:
            return None

    def attach_file(self, issue_id: int, filepath: str) -> bool:
        if not os.path.isfile(filepath):
            return False
        boundary = f"----RC{int(time.time())}"
        with open(filepath, "rb") as f:
            content = f.read()
        body_parts = [
            f"--{boundary}".encode(),
            b'Content-Disposition: form-data; name="files[]"; filename="' + os.path.basename(filepath).encode() + b'"',
            b"Content-Type: application/octet-stream",
            b"",
            content,
            f"--{boundary}--".encode(),
            b"",
        ]
        body = b"\r\n".join(body_parts)
        d = self._req("POST", f"/api/rest/issues/{issue_id}/files",
                      body=body, ctype=f"multipart/form-data; boundary={boundary}")
        return d is not None


# -----------------------------------------------------------------------------
# 16. MultiHostRunner (esqueleto SSH/ADB)
# -----------------------------------------------------------------------------

class MultiHostRunner:
    def __init__(self, hosts_file: str, verbose: bool = False):
        self.hosts_file = hosts_file
        self.verbose = verbose

    def parse(self) -> List[dict]:
        out = []
        try:
            with open(self.hosts_file, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    parts = re.split(r"\s+", line)
                    if len(parts) < 2:
                        continue
                    out.append({
                        "tipo": parts[0],
                        "host": parts[1],
                        "user": parts[2] if len(parts) > 2 and parts[2] != "-" else None,
                    })
        except Exception:
            pass
        return out

    def run_remote(self, hosts: List[dict], script_path: str) -> List[dict]:
        with open(script_path, "rb") as f:
            blob = base64.b64encode(f.read()).decode()
        results = []
        for h in hosts:
            tipo = h["tipo"]
            host = h["host"]
            user = h.get("user")
            target = f"{user}@{host}" if user else host
            if tipo in ("linux", "macos"):
                cmd = ["ssh", "-o", "StrictHostKeyChecking=no", target,
                       f"echo {blob} | base64 -d | python3 -"]
                rc, out, err = safe_run(cmd, timeout=300)
                results.append({"host": host, "tipo": tipo, "rc": rc, "stdout_tail": out[-2000:], "stderr_tail": err[-1000:]})
            elif tipo == "android":
                results.append({"host": host, "tipo": tipo, "rc": 0,
                                "nota": "Android multihost requiere ejecutar local con --serial"})
            else:
                results.append({"host": host, "tipo": tipo, "rc": -1, "nota": "tipo no soportado en remoto"})
        return results


# -----------------------------------------------------------------------------
# 17. Banner / progreso
# -----------------------------------------------------------------------------

def show_banner(hostname: str, platform_label: str, silent: bool = False) -> None:
    if silent:
        return
    cprint("", "")
    cprint("  +---------------------------------------------------------------+", C.CY)
    cprint("  |              RESOLVECORE -- ANALISIS DE VULNERABILIDADES      |", C.CY)
    cprint("  +---------------------------------------------------------------+", C.CY)
    cprint(f"  Equipo: {hostname} | Plataforma: {platform_label} | Fecha: {now_iso()}", C.W)
    cprint("", "")


def progress_line(idx: int, total: int, name: str, ver: str, n_cves: int, n_kev: int, silent: bool):
    if silent:
        return
    pad = name[:30].ljust(30)
    dots = "." * max(1, 30 - len(pad))
    cprint(f"  [{idx}/{total}] {pad} {ver[:12]:<12} {dots} {n_cves} CVEs ({n_kev} KEV)", C.GR)


# -----------------------------------------------------------------------------
# 18. Main
# -----------------------------------------------------------------------------

def _close_port(platform_code: str, port: int, dry_run: bool, admin: bool) -> str:
    """Cierra puerto via firewall del SO. Retorna estado."""
    if dry_run:
        return f"[DRY-RUN] cerrar tcp/{port}"
    if not admin:
        return "OMITIDO (sin permisos admin)"
    if platform_code == "W":
        rule = f"ResolveCore-Block-{port}"
        rc, _, _ = safe_run([
            "netsh", "advfirewall", "firewall", "add", "rule",
            f"name={rule}", "dir=in", "action=block", "protocol=TCP",
            f"localport={port}",
        ], timeout=10)
        return "CORREGIDO via netsh" if rc == 0 else "PENDIENTE (netsh fallo)"
    if platform_code == "L":
        if cmd_exists("ufw"):
            rc, _, _ = safe_run(["ufw", "deny", str(port)], timeout=10)
            return "CORREGIDO via ufw" if rc == 0 else "PENDIENTE"
        if cmd_exists("iptables"):
            rc, _, _ = safe_run([
                "iptables", "-A", "INPUT", "-p", "tcp", "--dport", str(port), "-j", "DROP"
            ], timeout=10)
            return "CORREGIDO via iptables" if rc == 0 else "PENDIENTE"
        return "PENDIENTE (sin firewall detectado)"
    if platform_code == "M":
        return "PENDIENTE (gestion firewall macOS manual)"
    return "OMITIDO"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="buscar_vulnerabilidades.py",
        description="ResolveCore - Escaneo de vulnerabilidades multiplataforma (open source)",
    )
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--no-fix", action="store_true", help="alias de --dry-run")
    p.add_argument("--silent", action="store_true")
    p.add_argument("--verbose", action="store_true")
    p.add_argument("--compare", action="store_true")
    p.add_argument("--output", default=None)
    p.add_argument("--report-html", action="store_true")
    p.add_argument("--notify", default=None)
    p.add_argument("--mantis-ticket", action="store_true")
    p.add_argument("--mantis-url", default=None)
    p.add_argument("--mantis-token", default=None)
    p.add_argument("--platform", choices=["W", "L", "A", "M"], default=None)
    p.add_argument("--min-score", type=float, default=7.0)
    p.add_argument("--serial", default=None)
    p.add_argument("--whitelist-add", default=None, metavar="CVE-ID")
    p.add_argument("--whitelist-list", action="store_true")
    p.add_argument("--whitelist-expire", action="store_true")
    p.add_argument("--hosts", default=None)
    p.add_argument("--scan-deps", action="store_true", help="Escanear ficheros de dependencias del proyecto (lento)")
    p.add_argument("--no-net-scan", action="store_true", help="Saltar escaneo de puertos")
    p.add_argument("--no-logs", action="store_true", help="Saltar analisis de logs")
    p.add_argument("--no-config", action="store_true", help="Saltar auditoria de configuracion")
    p.add_argument("--auto-fix", action="store_true",
                   help="Aplicar todas las correcciones sin preguntar")
    p.add_argument("--yes", "-y", action="store_true",
                   help="Asumir SI a todos los prompts (alias de --auto-fix)")
    return p.parse_args()


def ask_yes_no(prompt: str, default: bool = False) -> bool:
    suffix = " [S/n]: " if default else " [s/N]: "
    try:
        resp = input(f"  {prompt}{suffix}").strip().lower()
    except EOFError:
        return default
    if not resp:
        return default
    return resp in ("s", "si", "y", "yes")


def load_dotenv(script_dir: str) -> None:
    env_path = os.path.join(script_dir, ".env")
    if not os.path.isfile(env_path):
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


def main() -> int:
    args = parse_args()
    silent = args.silent
    verbose = args.verbose
    dry_run = args.dry_run or args.no_fix
    t0 = time.time()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    load_dotenv(script_dir)

    output_dir = args.output or os.path.join(script_dir, "diagnosticos")
    os.makedirs(output_dir, exist_ok=True)

    # ---------- Whitelist commands (cortocircuito) ----------
    wlm = WhitelistManager(output_dir)
    if args.whitelist_list:
        for e in wlm.list_active():
            print(json.dumps(e, ensure_ascii=False))
        return 0
    if args.whitelist_expire:
        for e in wlm.list_expired():
            print(json.dumps(e, ensure_ascii=False))
        return 0
    if args.whitelist_add:
        try:
            motivo = input("Motivo: ").strip()
        except EOFError:
            motivo = "sin motivo"
        wlm.add(args.whitelist_add, motivo)
        cprint(f"  [OK] {args.whitelist_add} anadido a la whitelist", C.G)
        return 0

    # ---------- Multihost ----------
    if args.hosts:
        runner = MultiHostRunner(args.hosts, verbose=verbose)
        hosts = runner.parse()
        cprint(f"  [>] Multihost: {len(hosts)} objetivos", C.CY, silent)
        results = runner.run_remote(hosts, os.path.abspath(__file__))
        out_path = os.path.join(output_dir, f"vuln_multihost_{now_stamp()}.json")
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump({"meta": {"fecha": now_iso(), "version": SCRIPT_VERSION},
                       "hosts": results}, f, indent=2, ensure_ascii=False)
        cprint(f"  [OK] Informe multihost: {out_path}", C.G, silent)
        return 0

    # ---------- Plataforma + inventario ----------
    detector = PlatformDetector(force_platform=args.platform, adb_serial=args.serial, verbose=verbose)
    detector.detect_all()

    plat_label = {
        "W": f"Windows ({detector.os_info.get('producto', '')})",
        "L": f"Linux ({detector.os_info.get('producto', '')})",
        "M": f"macOS ({detector.os_info.get('producto', '')})",
        "A": f"Android ({detector.os_info.get('version', '')})",
    }.get(detector.platform_code, "Desconocido")

    show_banner(detector.hostname, plat_label, silent)
    cprint(f"  [>] Software detectado: {len(detector.software)} entradas", C.GR, silent)

    # ---------- KEV + Scanner ----------
    kev = CISAKEVCache(verbose=verbose)
    kev.load()
    scanner = VulnScanner(kev, min_score=args.min_score, verbose=verbose)

    whitelist = wlm.active_set()
    if whitelist:
        cprint(f"  [>] Excepciones activas: {len(whitelist)}", C.CY, silent)

    cprint("  [>] Consultando NVD + OSV + EPSS...", C.GR, silent)
    total = min(MAX_SOFTWARE_QUERIES, len(detector.software))

    def cb(i, t, n, v):
        progress_line(i, t, n, v, 0, 0, silent)

    vulns = scanner.scan_software(detector.software, whitelist=whitelist, progress_cb=cb)

    # ---------- ConfigAuditor ----------
    cfg_checks: List[dict] = []
    if not args.no_config:
        cprint("  [>] Auditoria de configuracion...", C.GR, silent)
        try:
            cfg_checks = ConfigAuditor(detector.platform_code, adb_serial=args.serial, verbose=verbose).run()
        except Exception as e:
            if verbose:
                cprint(f"  [!] Auditoria fallo: {e}", C.Y, silent)

    # ---------- NetworkScanner ----------
    net_results: List[dict] = []
    if not args.no_net_scan:
        cprint("  [>] Escaneo de puertos locales...", C.GR, silent)
        try:
            net_results = NetworkScanner("127.0.0.1", verbose=verbose).scan()
        except Exception as e:
            if verbose:
                cprint(f"  [!] NetScan fallo: {e}", C.Y, silent)

    # ---------- LogAnalyzer ----------
    iocs: List[dict] = []
    if not args.no_logs:
        cprint("  [>] Analisis de logs (IOCs)...", C.GR, silent)
        try:
            iocs = LogAnalyzer(detector.platform_code, adb_serial=args.serial, verbose=verbose).run()
        except Exception as e:
            if verbose:
                cprint(f"  [!] LogAnalyzer fallo: {e}", C.Y, silent)

    # ---------- DepsScanner (opt-in, lento) ----------
    deps_vulns: List[dict] = []
    if args.scan_deps:
        cprint("  [>] Escaneo de dependencias de proyectos (--scan-deps)...", C.GR, silent)
        deps_roots = []
        cwd = os.getcwd()
        if detector.platform_code == "W":
            deps_roots = [cwd, os.path.join(os.environ.get("USERPROFILE", "C:\\Users"), "proyecto"),
                          os.path.join(os.environ.get("USERPROFILE", "C:\\Users"), "Projects")]
        else:
            deps_roots = [cwd, os.path.expanduser("~/proyecto"), os.path.expanduser("~/Projects"),
                          "/var/www", "/opt"]
        try:
            deps_scanner = DepsScanner(scanner, max_depth=3, verbose=verbose)
            valid_roots = [r for r in deps_roots if r and os.path.isdir(r)]
            deps_vulns = deps_scanner.scan(valid_roots)
        except Exception as e:
            if verbose:
                cprint(f"  [!] DepsScanner fallo: {e}", C.Y, silent)

    # ---------- Remediacion (interactiva) ----------
    auto_fix = args.auto_fix or args.yes
    remediator = RemediationEngine(detector.platform_code, dry_run=dry_run, verbose=verbose,
                                   adb_serial=args.serial)
    remediated = 0

    cves_pendientes = [v for v in vulns if v.get("estado") != "EXCEPCION ACEPTADA"]
    cfg_fallos = [c for c in cfg_checks if c.get("estado") == "FALLO"]
    ports_open = list(net_results)

    cprint("", "")
    cprint("  +-------------------------------------------------------------+", C.CY, silent)
    cprint(f"  |  HALLAZGOS: {len(cves_pendientes)} CVEs | {len(cfg_fallos)} config | {len(ports_open)} puertos"
           .ljust(64) + "|", C.CY, silent)
    cprint("  +-------------------------------------------------------------+", C.CY, silent)

    fix_cves = False
    fix_cfg = False
    fix_ports = False

    if dry_run:
        cprint("  [i] Modo DRY-RUN: solo simulacion, no se aplican cambios", C.Y, silent)
    elif silent or auto_fix:
        fix_cves = bool(cves_pendientes)
        fix_cfg = bool(cfg_fallos)
        fix_ports = bool(ports_open)
        if auto_fix and not silent:
            cprint("  [i] --auto-fix activo: aplicando todas las correcciones", C.Y)
    else:
        if cves_pendientes:
            cprint("", "")
            cprint(f"  CVEs detectados: {len(cves_pendientes)} pendientes", C.Y)
            for v in cves_pendientes[:5]:
                tag = "[KEV]" if v.get("kev") else f"[{v.get('severity', '?')}]"
                cprint(f"    {tag} {v.get('cve_id')} - {v.get('software', '')} {v.get('version', '')} (CVSS {v.get('cvss', 0)})", C.GR)
            if len(cves_pendientes) > 5:
                cprint(f"    ... y {len(cves_pendientes) - 5} mas", C.GR)
            fix_cves = ask_yes_no(f"Intentar corregir los {len(cves_pendientes)} CVEs?", default=False)

        if cfg_fallos:
            cprint("", "")
            cprint(f"  Config fallos: {len(cfg_fallos)}", C.Y)
            for c in cfg_fallos:
                cprint(f"    [{c.get('riesgo', '?')}] {c.get('check')} (actual={c.get('valor_actual')})", C.GR)
            fix_cfg = ask_yes_no(f"Aplicar correcciones de configuracion?", default=False)

        if ports_open:
            cprint("", "")
            cprint(f"  Puertos riesgo abiertos: {len(ports_open)}", C.Y)
            for n in ports_open:
                cprint(f"    tcp/{n.get('puerto')} {n.get('servicio')} ({n.get('riesgo')})", C.GR)
            fix_ports = ask_yes_no("Cerrar puertos via firewall?", default=False)

    # Aplicar fix CVEs
    if fix_cves:
        cprint("", "")
        cprint("  [>] Aplicando correcciones de software...", C.CY, silent)
        for v in cves_pendientes:
            try:
                estado = remediator.remediate_software(v)
            except Exception as e:
                estado = f"PENDIENTE (error: {e})" if verbose else "PENDIENTE"
            v["estado"] = estado
            if estado.startswith("CORREGIDO"):
                remediated += 1
                cprint(f"    [OK] {v.get('cve_id')} - {estado}", C.G, silent)
            else:
                cprint(f"    [..] {v.get('cve_id')} - {estado}", C.GR, silent)
    else:
        for v in cves_pendientes:
            if v.get("estado") in (None, ""):
                v["estado"] = "PENDIENTE (no aplicado por usuario)"

    # Aplicar fix config
    if fix_cfg:
        cprint("", "")
        cprint("  [>] Aplicando correcciones de configuracion...", C.CY, silent)
        for c in cfg_fallos:
            try:
                res = remediator.remediate_config(c)
            except Exception:
                res = "PENDIENTE"
            c["accion"] = res
            if res.startswith("CORREGIDO"):
                c["corregido"] = True
                c["estado"] = "OK (corregido)"
                remediated += 1
                cprint(f"    [OK] {c.get('check')}", C.G, silent)
            else:
                cprint(f"    [..] {c.get('check')} - {res}", C.GR, silent)
    else:
        for c in cfg_fallos:
            if not c.get("accion"):
                c["accion"] = "PENDIENTE (no aplicado por usuario)"

    # Aplicar fix puertos (firewall)
    if fix_ports:
        cprint("", "")
        cprint("  [>] Cerrando puertos via firewall...", C.CY, silent)
        for n in ports_open:
            res = _close_port(detector.platform_code, n.get("puerto"), dry_run, remediator.admin)
            n["accion"] = res
            if res.startswith("CORREGIDO"):
                remediated += 1
                cprint(f"    [OK] tcp/{n.get('puerto')} cerrado", C.G, silent)
            else:
                cprint(f"    [..] tcp/{n.get('puerto')} - {res}", C.GR, silent)

    # ---------- RiskScore + agregados ----------
    score, nivel, desglose = compute_risk_score(vulns, cfg_checks, net_results, iocs, remediated)
    severidad = build_severity_summary(vulns)

    pendientes_cves = [v for v in vulns if not (v.get("estado") or "").startswith("CORREGIDO")
                       and v.get("estado") != "EXCEPCION ACEPTADA"]

    # Pendientes priorizados con accion sugerida
    pendientes_tecnico: List[str] = []
    # 1. KEV primero
    for v in [x for x in pendientes_cves if x.get("kev")]:
        pendientes_tecnico.append(
            f"[KEV-URGENTE] {v.get('cve_id')} - {v.get('software', '')} {v.get('version', '')} "
            f"(CVSS {v.get('cvss', 0)}). Accion: {v.get('kev_action') or 'parchear inmediatamente'}"
        )
    # 2. CRITICAL no-KEV
    for v in [x for x in pendientes_cves if not x.get("kev") and (x.get("severity") or "").upper() == "CRITICAL"]:
        pendientes_tecnico.append(
            f"[CRITICAL] {v.get('cve_id')} - {v.get('software', '')} {v.get('version', '')} "
            f"(CVSS {v.get('cvss', 0)}). Accion: actualizar paquete via gestor del SO"
        )
    # 3. Config fallidos por severidad
    cfg_sorted = sorted(
        [c for c in cfg_checks if c.get("estado") == "FALLO"],
        key=lambda c: {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3}.get((c.get("riesgo") or "").upper(), 4),
    )
    for c in cfg_sorted:
        pendientes_tecnico.append(
            f"[CFG-{c.get('riesgo', '?')}] {c.get('check')} | actual={c.get('valor_actual')} "
            f"-> esperado={c.get('valor_esperado')} | {c.get('accion', 'remediar manualmente')}"
        )
    # 4. Puertos
    for n in net_results:
        pendientes_tecnico.append(
            f"[PORT-{n.get('riesgo')}] tcp/{n.get('puerto')} {n.get('servicio')}. "
            f"Accion: cerrar via firewall o restringir al rango RFC1918"
        )
    # 5. IOCs
    for ioc in iocs:
        pendientes_tecnico.append(
            f"[IOC-{ioc.get('riesgo')}] {ioc.get('tipo')}: {ioc.get('detalle')}. "
            f"Accion: {ioc.get('recomendacion', 'investigar')}"
        )
    # 6. Resto CVEs HIGH/MEDIUM
    for v in [x for x in pendientes_cves if not x.get("kev") and (x.get("severity") or "").upper() in ("HIGH", "MEDIUM")][:15]:
        pendientes_tecnico.append(
            f"[{v.get('severity', '?')}] {v.get('cve_id')} - {v.get('software', '')} {v.get('version', '')} "
            f"(CVSS {v.get('cvss', 0)}, EPSS {v.get('epss', 0):.2f})"
        )

    # ---------- Mensaje cliente personalizado ----------
    msg_cliente = build_client_message(nivel, vulns, cfg_checks, net_results, iocs)
    proxima_rev = next_review_date(nivel)
    duracion = round(time.time() - t0, 1)

    # ---------- Construir informe ----------
    informe = {
        "_meta": {
            "version": SCRIPT_VERSION,
            "plataforma": plat_label,
            "hostname": detector.hostname,
        },
        "meta": {
            "fecha": now_iso(),
            "hostname": detector.hostname,
            "plataforma": plat_label,
            "script_version": SCRIPT_VERSION,
            "risk_score": score,
            "risk_nivel": nivel,
            "admin": is_admin(),
            "dry_run": dry_run,
            "duracion_segundos": duracion,
            "proxima_revision": proxima_rev,
        },
        "por_severidad": severidad,
        "score_desglose": desglose,
        "resumen": {
            "total_cves": len(vulns),
            "corregidos": sum(1 for v in vulns if (v.get("estado") or "").startswith("CORREGIDO")),
            "pendientes": len(pendientes_cves),
            "checks_config": len(cfg_checks),
            "checks_fallidos": sum(1 for c in cfg_checks if c.get("estado") == "FALLO"),
            "puertos_riesgo": len(net_results),
        },
        "os": detector.os_info,
        "vulnerabilidades": vulns,
        "config_checks": cfg_checks,
        "red": net_results,
        "iocs": iocs,
        "dependencias_vulnerables": deps_vulns,
        "excepciones_activas": wlm.list_active(),
        "pendientes_tecnico": pendientes_tecnico,
        "mensaje_cliente": msg_cliente,
    }

    # ---------- Comparativa ----------
    history = HistoryManager(output_dir)
    if args.compare:
        prev_list = history.load()
        if prev_list:
            prev = prev_list[-1]
            informe["comparativa"] = history.diff(prev, informe)

    history.save_entry({
        "meta": informe["meta"],
        "vulnerabilidades": [{"cve_id": v.get("cve_id")} for v in vulns],
    })

    # ---------- Reportes ----------
    rg = ReportGenerator(output_dir, detector.hostname, plat_label)
    json_path = rg.write_json(informe)
    txt_path = rg.write_txt(informe)
    html_path = rg.write_html(informe) if args.report_html else None

    # ---------- Notificacion ----------
    if args.notify:
        subj = f"[ResolveCore] Vulnerabilidades - {detector.hostname} - {now_iso()[:10]} - RiskScore: {score}"
        body = f"Resumen:\n  CVEs: {len(vulns)} (corregidos {informe['resumen']['corregidos']})\n" \
               f"  Config fallos: {informe['resumen']['checks_fallidos']}\n" \
               f"  Puertos riesgo: {len(net_results)}\n  RiskScore: {score}/100 ({nivel})\n\n" \
               f"Pendientes principales:\n" + "\n".join(f"  - {p}" for p in pendientes_tecnico[:15])
        attachments = [json_path, txt_path]
        if html_path:
            attachments.append(html_path)
        Notifier(args.notify, verbose=verbose).send(subj, body, attachments, output_dir)

    # ---------- MantisBT ----------
    if args.mantis_ticket:
        url = args.mantis_url or os.environ.get("MANTIS_URL", "")
        token = args.mantis_token or os.environ.get("MANTIS_TOKEN", "")
        proj_id = int(os.environ.get("MANTIS_PROJECT_ID", "1") or 1)
        client = MantisBTClient(url, token, proj_id, verbose=verbose)
        if client.is_configured():
            has_kev = any(v.get("kev") for v in pendientes_cves)
            has_critical = any((v.get("severity") or "").upper() == "CRITICAL" for v in pendientes_cves)
            summary = f"[VULN] {detector.hostname} - {len(pendientes_cves)} vulnerabilidades pendientes (RiskScore: {score})"
            md_lines = [
                f"## Resumen vulnerabilidades - {detector.hostname}",
                f"- Plataforma: {plat_label}",
                f"- RiskScore: **{score}/100** ({nivel})",
                "",
                "| CVE | Software | Score | EPSS | KEV | Estado |",
                "|-----|----------|-------|------|-----|--------|",
            ]
            for v in pendientes_cves[:50]:
                md_lines.append(
                    f"| {v.get('cve_id','?')} | {v.get('software','')} {v.get('version','')} "
                    f"| {v.get('cvss',0)} | {v.get('epss',0):.2f} "
                    f"| {'X' if v.get('kev') else ''} | {v.get('estado','')} |"
                )
            issue_id = client.create_issue(summary, "\n".join(md_lines), has_kev, has_critical)
            if issue_id:
                cprint(f"  [OK] Mantis issue #{issue_id} creado", C.G, silent)
                client.attach_file(issue_id, json_path)
            else:
                pending_path = os.path.join(output_dir, f"mantis_pendiente_{now_stamp()}.json")
                with open(pending_path, "w", encoding="utf-8") as f:
                    json.dump({"summary": summary, "report": informe}, f, indent=2, ensure_ascii=False)
                cprint(f"  [!] Mantis fallo. Payload guardado: {pending_path}", C.Y, silent)

    # ---------- Resumen consola ----------
    if not silent:
        bar = render_score_bar(score)
        cprint("", "")
        cprint("  +-------------------------------------------------------------+", C.CY)
        cprint("  |  RESUMEN FINAL                                              |", C.CY)
        cprint("  +-------------------------------------------------------------+", C.CY)
        cprint(f"   CVEs: {len(vulns)}   Corregidos: {informe['resumen']['corregidos']}   "
               f"Pendientes: {len(pendientes_cves)}", C.W)
        cprint(f"   Config fallos: {informe['resumen']['checks_fallidos']}   "
               f"Puertos riesgo: {len(net_results)}", C.W)
        color = C.G if nivel == "BUENO" else (C.Y if nivel == "MEJORABLE" else C.R)
        cprint(f"   RiskScore: {bar} {nivel}", color)
        cprint("", "")
        cprint(f"   Informe JSON: {json_path}", C.CY)
        cprint(f"   Informe TXT:  {txt_path}", C.CY)
        if html_path:
            cprint(f"   Informe HTML: {html_path}", C.CY)
        cprint("", "")
        if pendientes_tecnico:
            cprint("  PENDIENTE PARA EL TECNICO:", C.Y)
            for p in pendientes_tecnico[:10]:
                cprint(f"    * {p}", C.GR)

    return 0 if score >= 50 else 0  # codigo 0 siempre - el score ya informa


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        cprint("\n  [!] Interrumpido por el usuario", C.Y)
        sys.exit(130)
