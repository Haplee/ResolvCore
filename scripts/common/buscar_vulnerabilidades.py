#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ResolveCore - Escaner de vulnerabilidades (CVE) multi-fuente, sin clases.

Recoge el software instalado en el equipo (segun la plataforma) y consulta sus
vulnerabilidades conocidas cruzando varias fuentes:

  - OSV.dev   -> rapido y sin API key; fuente por defecto para paquetes Linux.
  - NVD/NIST  -> busqueda por palabra clave; se usa en Windows/Android. Tiene
                 rate limit (6s/peticion sin API key, 0.6s con NVD_API_KEY).
  - CISA KEV  -> marca los CVE que se sabe que estan siendo EXPLOTADOS de verdad.

Arquitectura hexagonal (sin clases, sin type hints): este modulo es el
orquestador; el inventario y las consultas viven en common/adapters/, los
contratos en common/ports/ y las entidades (dicts) en common/domain/.

Uso:
    python3 buscar_vulnerabilidades.py --plataforma linux
    python3 buscar_vulnerabilidades.py --plataforma windows --max 10
    python3 buscar_vulnerabilidades.py --plataforma android --serial ABC123
    python3 buscar_vulnerabilidades.py --puertos              # modo port-scan legacy
    python3 buscar_vulnerabilidades.py --puertos 192.168.1.10

Autor:   Francisco Vidal Mateo (GitHub: Haplee)
Version: 3.0
"""

import os
import sys
import json
import socket
import argparse
from datetime import datetime

# Para poder importar el paquete 'common' tanto si se ejecuta como script suelto
# como si se importa: metemos la carpeta scripts/ en el path.
_AQUI = os.path.dirname(os.path.abspath(__file__))
_SCRIPTS = os.path.dirname(_AQUI)
if _SCRIPTS not in sys.path:
    sys.path.insert(0, _SCRIPTS)

from common.adapters import inventario_local, kev_rest, nvd_rest, osv_rest  # noqa: E402
from common.domain import es_alta, es_critica  # noqa: E402


# ── Puertos (modo legacy --puertos) ──────────────────────────────────────────
PUERTOS = {
    21: "FTP", 22: "SSH", 23: "Telnet", 25: "SMTP", 53: "DNS", 80: "HTTP",
    110: "POP3", 143: "IMAP", 443: "HTTPS", 445: "SMB", 3306: "MySQL",
    3389: "RDP", 5432: "PostgreSQL", 6379: "Redis", 8080: "HTTP-Alt",
    8443: "HTTPS-Alt", 27017: "MongoDB",
}
PELIGROSOS = {21, 23, 445, 3389, 6379, 27017}


def escanear_puertos(host, timeout=1.0):
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
            pass
    return abiertos


def modo_puertos(host):
    try:
        ip = socket.gethostbyname(host)
    except socket.gaierror as e:
        print("Error resolviendo {0}: {1}".format(host, e), file=sys.stderr)
        sys.exit(1)
    print("Escaneando {0} ({1})...".format(host, ip), file=sys.stderr)
    abiertos = escanear_puertos(ip)
    resultado = {
        "modo": "puertos",
        "host": host,
        "ip": ip,
        "timestamp": datetime.now().isoformat(),
        "puertos_abiertos": abiertos,
        "avisos": [p for p in abiertos if p["peligroso"]],
    }
    print(json.dumps(resultado, indent=2, ensure_ascii=False))


# ── Modo CVE ─────────────────────────────────────────────────────────────────

def _ecosistema_linux():
    # Deriva el ecosistema OSV de /etc/os-release (Debian:12, Ubuntu, etc.).
    datos = {}
    try:
        with open("/etc/os-release", encoding="utf-8") as f:
            for linea in f:
                if "=" in linea:
                    clave, valor = linea.strip().split("=", 1)
                    datos[clave] = valor.strip().strip('"')
    except OSError:
        return ""
    idd = datos.get("ID", "").lower()
    version_id = datos.get("VERSION_ID", "")
    if idd == "debian":
        # OSV usa el numero mayor de version: "Debian:12".
        mayor = version_id.split(".")[0] if version_id else ""
        return "Debian:" + mayor if mayor else "Debian"
    if idd == "ubuntu":
        return "Ubuntu"
    return ""


def _vulns_de_paquete(paquete, plataforma, ecosistema, api_key):
    # En Linux usamos OSV (rapido, sin rate limit). En Windows/Android usamos la
    # NVD por palabra clave (mas lento, de ahi el --max).
    nombre = paquete.get("nombre", "")
    version = paquete.get("version", "")
    if plataforma == "linux":
        return osv_rest.get_vulns(nombre, version, ecosistema)
    return nvd_rest.get_vulns(nombre, version, api_key)


def evaluar_riesgo(vulns):
    # Probabilidad agregada de compromiso del equipo: P = 1 - prod(1 - p_i).
    # Cada CVE aporta una probabilidad individual de ser explotado segun su
    # severidad y explotacion real conocida. Asi un solo CVE en KEV (explotado
    # de verdad) ya dispara el riesgo, y muchos altos tambien saturan hacia 100%.
    # Es el indicador de exposicion que pide el registro del TFG.
    p_no = 1.0
    n_kev = n_crit = n_alta = n_otras = 0
    for v in vulns:
        if v.get("kev"):
            p = 0.85
            n_kev += 1
        elif es_critica(v):
            p = 0.30
            n_crit += 1
        elif es_alta(v):
            p = 0.12
            n_alta += 1
        else:
            p = 0.02
            n_otras += 1
        p_no *= (1.0 - p)
    prob = round((1.0 - p_no) * 100, 1)
    if prob >= 80:
        nivel = "CRITICO"
    elif prob >= 50:
        nivel = "ALTO"
    elif prob >= 25:
        nivel = "MEDIO"
    elif prob >= 5:
        nivel = "BAJO"
    else:
        nivel = "MINIMO"
    return {
        "probabilidad_compromiso_pct": prob,
        "nivel": nivel,
        "factores": {
            "kev": n_kev,
            "criticas": n_crit,
            "altas": n_alta,
            "otras": n_otras,
        },
    }


def modo_cve(plataforma, serial, maximo, api_key, salida_json=""):
    print("Recogiendo inventario de software ({0})...".format(plataforma), file=sys.stderr)
    inventario = inventario_local.get_software(plataforma, serial, maximo)
    if not inventario:
        print("[!] No se obtuvo inventario de software (¿faltan dpkg/adb/permisos?).", file=sys.stderr)

    print("Descargando catalogo CISA KEV...", file=sys.stderr)
    kev = kev_rest.cargar_kev()

    ecosistema = _ecosistema_linux() if plataforma == "linux" else ""

    software = []
    todas = []
    total = len(inventario)
    for i, paquete in enumerate(inventario, start=1):
        print("  [{0}/{1}] {2} {3}".format(i, total, paquete.get("nombre", ""),
                                            paquete.get("version", "")), file=sys.stderr)
        vulns = _vulns_de_paquete(paquete, plataforma, ecosistema, api_key)
        lista_pkg = []
        for v in vulns:
            registro = {
                "cve": v.get("cve", ""),
                "cvss": v.get("cvss"),
                "summary": v.get("summary", ""),
                "kev": kev_rest.es_kev(v.get("cve", ""), kev),
                "paquete": paquete.get("nombre", ""),
                "version": paquete.get("version", ""),
            }
            lista_pkg.append(registro)
            todas.append(registro)
        software.append({
            "nombre": paquete.get("nombre", ""),
            "version": paquete.get("version", ""),
            "origen": paquete.get("origen", ""),
            "n_vulnerabilidades": len(lista_pkg),
        })

    # Avisos = criticas, altas o explotadas activamente (KEV).
    avisos = [v for v in todas if v["kev"] or es_critica(v) or es_alta(v)]
    # Orden: primero KEV, luego por CVSS descendente.
    avisos.sort(key=lambda v: (not v["kev"], -(v["cvss"] or 0)))

    riesgo = evaluar_riesgo(todas)

    resultado = {
        "modo": "cve",
        "plataforma": plataforma,
        "timestamp": datetime.now().isoformat(),
        "n_software": len(software),
        "n_vulnerabilidades": len(todas),
        "riesgo": riesgo,
        "software": software,
        "vulnerabilidades": todas,
        "avisos": avisos,
    }
    print(json.dumps(resultado, indent=2, ensure_ascii=False))

    # Volcado a fichero para que el launcher lea un JSON limpio (sin mezclar con
    # las barras de progreso, que van por stderr). El menu de desinstalacion del
    # launcher consume este fichero.
    if salida_json:
        try:
            with open(salida_json, "w", encoding="utf-8") as f:
                json.dump(resultado, f, ensure_ascii=False, indent=2)
            print("[i] Resultado escrito en {0}".format(salida_json), file=sys.stderr)
        except OSError as e:
            print("[!] No se pudo escribir --salida-json: {0}".format(e), file=sys.stderr)

    # Resumen legible por stderr para el tecnico.
    n_kev = sum(1 for v in todas if v["kev"])
    n_crit = sum(1 for v in todas if es_critica(v))
    print("", file=sys.stderr)
    print("[i] {0} software analizado, {1} vulnerabilidades, {2} criticas, {3} en KEV.".format(
        len(software), len(todas), n_crit, n_kev), file=sys.stderr)
    print("[i] Probabilidad estimada de compromiso: {0}% [{1}]  "
          "(KEV={2} criticas={3} altas={4} otras={5})".format(
              riesgo["probabilidad_compromiso_pct"], riesgo["nivel"],
              riesgo["factores"]["kev"], riesgo["factores"]["criticas"],
              riesgo["factores"]["altas"], riesgo["factores"]["otras"]),
          file=sys.stderr)


def _forzar_utf8():
    # En consolas Windows (cp1252) imprimir nombres de software con acentos
    # reventaria con UnicodeEncodeError. Forzamos UTF-8 con reemplazo.
    for flujo in (sys.stdout, sys.stderr):
        try:
            flujo.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass


def main():
    _forzar_utf8()
    parser = argparse.ArgumentParser(
        description="Escaner de vulnerabilidades CVE (OSV + NVD + CISA KEV)."
    )
    parser.add_argument("--plataforma", choices=["linux", "windows", "android"],
                        help="Plataforma del equipo a analizar (modo CVE).")
    parser.add_argument("--serial", default=None, help="Serial ADB del dispositivo Android.")
    parser.add_argument("--max", type=int, default=20, dest="maximo",
                        help="Maximo de paquetes a consultar (0 = sin limite). Importante en "
                             "Windows/Android por el rate limit de la NVD.")
    parser.add_argument("--api-key", default=None, help="API key de la NVD (o variable NVD_API_KEY).")
    parser.add_argument("--puertos", nargs="?", const="127.0.0.1", default=None,
                        help="Modo legacy: escaneo de puertos del host indicado (def: 127.0.0.1).")
    parser.add_argument("--salida-json", dest="salida_json", default="",
                        help="Escribe el resultado completo (incluye 'avisos') a este fichero, "
                             "ademas de imprimirlo. Lo usa el launcher para el menu de desinstalacion.")
    args = parser.parse_args()

    if args.puertos is not None:
        modo_puertos(args.puertos)
        return

    if not args.plataforma:
        parser.error("indica --plataforma {linux,windows,android} o usa --puertos.")

    api_key = args.api_key if args.api_key is not None else os.getenv("NVD_API_KEY", "")
    modo_cve(args.plataforma, args.serial, args.maximo, api_key, args.salida_json)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[!] Escaneo cancelado por el usuario.")
        sys.exit(130)
