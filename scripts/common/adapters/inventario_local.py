# -*- coding: utf-8 -*-
"""
ResolveCore - Inventario de software instalado (sin clases, stdlib only).

Adapter que cumple el contrato ports/inventory_source.py. Recoge la lista de
software instalado en el equipo segun la plataforma:

  - linux:   dpkg-query (Debian/Ubuntu) o rpm (Fedora/RHEL).
  - windows: claves "Uninstall" del registro via winreg.
  - android: paquetes de terceros via adb (pm list packages -3) + el nivel de
             parche de seguridad (ro.build.version.security_patch).

Cada elemento es un dict {"nombre", "version", "origen"}. Ninguna funcion lanza
excepcion: ante cualquier fallo devuelven lista vacia.

Autor:   Francisco Vidal Mateo (GitHub: Haplee)
Version: 1.0
"""

import re
import subprocess
import sys


def _ejecutar(cmd):
    # Lanza un comando y devuelve su stdout como texto. Si falla, "".
    try:
        salida = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=60,
        )
        return salida.stdout.decode("utf-8", errors="replace")
    except (OSError, subprocess.SubprocessError):
        return ""


def _software_linux():
    paquetes = []
    # Debian/Ubuntu primero.
    texto = _ejecutar(["dpkg-query", "-W", "-f=${Package}\t${Version}\n"])
    origen = "dpkg"
    if not texto:
        # Fedora/RHEL/openSUSE.
        texto = _ejecutar(["rpm", "-qa", "--qf", "%{NAME}\t%{VERSION}\n"])
        origen = "rpm"
    for linea in texto.splitlines():
        if "\t" not in linea:
            continue
        nombre, version = linea.split("\t", 1)
        nombre = nombre.strip()
        # En dpkg el nombre puede traer ":arch" (ej. libc6:amd64); lo quitamos.
        if ":" in nombre:
            nombre = nombre.split(":", 1)[0]
        version = version.strip()
        # En dpkg la version trae a veces "epoch:" delante (1:2.3); la quitamos.
        if ":" in version:
            version = version.split(":", 1)[1]
        if nombre:
            paquetes.append({"nombre": nombre, "version": version, "origen": origen})
    return paquetes


def _software_windows():
    paquetes = []
    try:
        import winreg
    except ImportError:
        return paquetes

    rutas = [
        (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
        (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
        (winreg.HKEY_CURRENT_USER, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
    ]
    vistos = set()
    for raiz, ruta in rutas:
        try:
            clave = winreg.OpenKey(raiz, ruta)
        except OSError:
            continue
        try:
            total = winreg.QueryInfoKey(clave)[0]
        except OSError:
            total = 0
        for i in range(total):
            try:
                sub = winreg.EnumKey(clave, i)
                subclave = winreg.OpenKey(clave, sub)
            except OSError:
                continue
            nombre = _leer_valor(subclave, "DisplayName")
            version = _leer_valor(subclave, "DisplayVersion")
            try:
                subclave.Close()
            except OSError:
                pass
            if not nombre:
                continue
            etiqueta = nombre + "|" + version
            if etiqueta in vistos:
                continue
            vistos.add(etiqueta)
            paquetes.append({"nombre": nombre, "version": version, "origen": "registro"})
        try:
            clave.Close()
        except OSError:
            pass
    return paquetes


def _leer_valor(subclave, valor):
    try:
        import winreg
        dato, _ = winreg.QueryValueEx(subclave, valor)
        return str(dato).strip()
    except (OSError, ImportError):
        return ""


def _adb_base(serial):
    base = ["adb"]
    if serial:
        # Solo seriales con el formato habitual de ADB (alfanumérico y .:_-).
        # Se pasa como argumento de lista (no shell), pero validamos igualmente.
        if re.match(r"^[A-Za-z0-9._:-]+$", serial):
            base += ["-s", serial]
    return base


def _software_android(serial):
    paquetes = []
    base = _adb_base(serial)

    # Nivel de parche de seguridad: lo tratamos como un "paquete" especial para
    # poder cruzarlo con boletines/CVE de Android.
    patch = _ejecutar(base + ["shell", "getprop", "ro.build.version.security_patch"]).strip()
    release = _ejecutar(base + ["shell", "getprop", "ro.build.version.release"]).strip()
    if release:
        paquetes.append({"nombre": "Android", "version": release, "origen": "getprop"})
    if patch:
        paquetes.append({"nombre": "Android security patch", "version": patch, "origen": "getprop"})

    # Apps de terceros (-3 = no incluye las del sistema).
    texto = _ejecutar(base + ["shell", "pm", "list", "packages", "-3"])
    for linea in texto.splitlines():
        linea = linea.strip()
        if not linea.startswith("package:"):
            continue
        pkg = linea.split(":", 1)[1].strip()
        if not pkg:
            continue
        version = _version_app_android(base, pkg)
        paquetes.append({"nombre": pkg, "version": version, "origen": "adb"})
    return paquetes


def _version_app_android(base, pkg):
    # Saca versionName del dumpsys de la app. Si no aparece, "".
    texto = _ejecutar(base + ["shell", "dumpsys", "package", pkg])
    for linea in texto.splitlines():
        linea = linea.strip()
        if linea.startswith("versionName="):
            return linea.split("=", 1)[1].strip()
    return ""


def get_software(plataforma, serial=None, maximo=0):
    """Devuelve la lista de software instalado segun la plataforma.

    Cumple el contrato ports/inventory_source.py. Nunca lanza excepcion.
    """
    plataforma = (plataforma or "").lower()
    if plataforma == "linux":
        paquetes = _software_linux()
    elif plataforma == "windows":
        paquetes = _software_windows()
    elif plataforma == "android":
        paquetes = _software_android(serial)
    else:
        paquetes = []

    # Orden estable por nombre para que la salida sea reproducible.
    paquetes.sort(key=lambda p: p["nombre"].lower())
    if maximo and maximo > 0:
        return paquetes[:maximo]
    return paquetes


if __name__ == "__main__":
    # Util para depurar a mano: python3 inventario_local.py linux
    plat = sys.argv[1] if len(sys.argv) > 1 else "linux"
    for p in get_software(plat, maximo=20):
        print("{0}\t{1}\t{2}".format(p["nombre"], p["version"], p["origen"]))
