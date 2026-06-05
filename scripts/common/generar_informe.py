#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ResolveCore - generar_informe.py

Genera una PLANTILLA de informe tecnico en texto plano (.txt) con los apartados
ya predefinidos y en blanco. El tecnico la abre, rellena cada apartado a mano y
la sube el mismo a MantisBT. No se genera HTML ni PDF: el unico documento que se
entrega al cliente es esta plantilla rellenada y la factura.

Si se le pasa --json (el diagnostico generado por diagnostico.sh / .ps1) se
intentan pre-rellenar algunos datos de cabecera (equipo, fecha, sistema) para
ahorrarle trabajo al tecnico; el resto queda en blanco.

Politica: solo stdlib, sin clases, sin anotaciones de tipo. Las entidades son
diccionarios creados por funciones.

Uso:
    python3 generar_informe.py
    python3 generar_informe.py --json diagnostico.json
    python3 generar_informe.py --json diagnostico.json --salida /ruta/informe.txt

Autor:   Francisco Vidal Mateo (GitHub: Haplee)
Version: 3.0
"""

import argparse
import json
import os
import sys
from datetime import datetime


# Carpeta de salida por defecto: scripts/diagnosticos (un nivel arriba de common).
_AQUI = os.path.dirname(os.path.abspath(__file__))
_DIR_SALIDA = os.path.join(os.path.dirname(_AQUI), "diagnosticos")


def nueva_cabecera():
    """Dict de cabecera con los datos que pueden venir del diagnostico."""
    return {
        "equipo": "",
        "sistema": "",
        "plataforma": "",
        "fecha_diagnostico": "",
        "ticket": "",
    }


def cargar_datos(ruta):
    """Lee y parsea el JSON de diagnostico. Devuelve {} si falta o es invalido.

    Nunca lanza excepcion: la plantilla debe salir igual aunque no haya JSON.
    """
    if not ruta:
        return {}
    try:
        with open(ruta, encoding="utf-8-sig") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def leer_cabecera(datos):
    """Extrae los datos de cabecera del dict de diagnostico (tolerante a vacios)."""
    cabecera = nueva_cabecera()
    if not datos:
        return cabecera
    meta = datos.get("_meta", {}) if isinstance(datos.get("_meta"), dict) else {}
    cabecera["equipo"] = (
        datos.get("hostname")
        or datos.get("dispositivo")
        or meta.get("hostname", "")
    )
    sistema = datos.get("sistema", {})
    if isinstance(sistema, dict) and sistema.get("nombre"):
        cabecera["sistema"] = sistema.get("nombre")
    else:
        cabecera["sistema"] = datos.get("os") or datos.get("android", "")
    cabecera["plataforma"] = meta.get("plataforma", "")
    cabecera["fecha_diagnostico"] = datos.get("timestamp", "")
    return cabecera


def _pct_ram_usada(datos):
    """Porcentaje de RAM usada (Windows free_gb / Linux libre_gb). None si no se puede."""
    ram = datos.get("ram", {})
    if not isinstance(ram, dict):
        return None
    total = ram.get("total_gb")
    libre = ram.get("free_gb")
    if libre is None:
        libre = ram.get("libre_gb")
    try:
        if total and total > 0 and libre is not None:
            return round((total - libre) / total * 100, 1)
    except (TypeError, ZeroDivisionError):
        return None
    return None


def cargar_vulns(ruta):
    """Devuelve los avisos KEV/criticos (CVSS>=7) de un JSON de vulnerabilidades."""
    datos = cargar_datos(ruta)
    avisos = datos.get("avisos", []) if isinstance(datos, dict) else []
    out = []
    for v in avisos:
        if v.get("kev") or (v.get("cvss") is not None and v.get("cvss") >= 7.0):
            out.append(v)
    out.sort(key=lambda v: (not v.get("kev"), -(v.get("cvss") or 0)))
    return out[:15]


def derivar_incidencias(datos, vulns):
    """Lista de incidencias derivadas del diagnostico (mismos umbrales que el menu)."""
    inc = []
    if not datos:
        return inc

    # Disco. Windows: discos[].free_gb (<10 critico, <20 bajo). Linux: disco.porcentaje_uso.
    discos = datos.get("discos")
    if isinstance(discos, list):
        for d in discos:
            libre = d.get("free_gb")
            if libre is not None and libre < 10:
                inc.append("Disco {0}: critico, solo {1} GB libres".format(d.get("drive", "?"), libre))
            elif libre is not None and libre < 20:
                inc.append("Disco {0}: espacio bajo, {1} GB libres".format(d.get("drive", "?"), libre))
    disco = datos.get("disco")
    if isinstance(disco, dict):
        pct = disco.get("porcentaje_uso")
        try:
            if pct is not None and int(pct) >= 90:
                inc.append("Disco raiz: uso al {0}%".format(pct))
        except (TypeError, ValueError):
            pass

    # RAM.
    pct = _pct_ram_usada(datos)
    if pct is not None and pct > 90:
        inc.append("Memoria RAM: critica, {0}% usada".format(pct))
    elif pct is not None and pct > 80:
        inc.append("Memoria RAM: alta, {0}% usada".format(pct))

    # Seguridad.
    seg = datos.get("seguridad", {})
    if isinstance(seg, dict):
        if seg.get("defender_activo") is False:
            inc.append("Windows Defender desactivado")
        if seg.get("firewall") is False:
            inc.append("Cortafuegos desactivado")
        if seg.get("uac") is False:
            inc.append("UAC desactivado")

    # Actualizaciones pendientes.
    act = datos.get("actualizaciones", {})
    if isinstance(act, dict):
        pend = act.get("pendientes")
        try:
            if pend and int(pend) > 0:
                inc.append("{0} actualizaciones pendientes".format(pend))
        except (TypeError, ValueError):
            pass

    # Servicios criticos detenidos (Spooler incluido: SIEMPRE se reporta).
    for s in datos.get("servicios_criticos", []) or []:
        estado = str(s.get("estado", "")).lower()
        if estado and estado not in ("running", "active"):
            inc.append("Servicio detenido: {0} ({1})".format(s.get("nombre", "?"), s.get("estado", "")))

    # Vulnerabilidades (si se paso un JSON de escaneo).
    for v in vulns:
        etiqueta = "KEV" if v.get("kev") else "CVSS {0}".format(v.get("cvss"))
        inc.append("Vulnerabilidad {0} [{1}] en {2} {3}".format(
            v.get("cve", "?"), etiqueta, v.get("paquete", ""), v.get("version", "")))

    return inc


def resumen_estado(datos):
    """Lineas clave-valor del estado actual del sistema (seccion 4)."""
    lineas = []
    if not datos:
        return lineas
    cpu = datos.get("cpu", {})
    if isinstance(cpu, dict):
        nombre = cpu.get("name") or cpu.get("modelo") or ""
        carga = cpu.get("load")
        if carga is None:
            carga = cpu.get("carga_1min")
        sufijo = "  (carga {0})".format(carga) if carga is not None else ""
        if nombre or sufijo:
            lineas.append("  CPU ..............: {0}{1}".format(nombre, sufijo))
    ram = datos.get("ram", {})
    if isinstance(ram, dict):
        total = ram.get("total_gb")
        libre = ram.get("free_gb")
        if libre is None:
            libre = ram.get("libre_gb")
        lineas.append("  Memoria RAM ......: {0} GB libres de {1} GB".format(libre, total))
    discos = datos.get("discos")
    if isinstance(discos, list) and discos:
        d = discos[0]
        lineas.append("  Disco {0} .........: {1} GB libres de {2} GB".format(
            d.get("drive", "?"), d.get("free_gb"), d.get("total_gb")))
    disco = datos.get("disco")
    if isinstance(disco, dict):
        lineas.append("  Disco raiz .......: {0} libres ({1}% usado)".format(
            disco.get("libre", "?"), disco.get("porcentaje_uso", "?")))
    so = ""
    sistema = datos.get("sistema", {})
    if isinstance(sistema, dict):
        so = sistema.get("nombre", "")
    so = so or datos.get("os", "")
    if so:
        lineas.append("  Sistema operativo : {0}".format(so))
    av = datos.get("antivirus")
    if isinstance(av, list) and av:
        lineas.append("  Antivirus ........: {0}".format(", ".join(str(x) for x in av)))
    return lineas


def derivar_recomendaciones(incidencias):
    """Checklist sugerido segun las incidencias detectadas."""
    rec = []
    texto = " ".join(incidencias).lower()
    if "disco" in texto:
        rec.append("[ ] Liberar espacio en disco (temporales, papelera, cache)")
    if "memoria" in texto or "ram" in texto:
        rec.append("[ ] Revisar procesos con alto consumo de RAM / ampliar memoria")
    if "defender" in texto or "cortafuegos" in texto or "uac" in texto:
        rec.append("[ ] Reactivar las protecciones de seguridad desactivadas")
    if "actualizaciones" in texto:
        rec.append("[ ] Aplicar las actualizaciones pendientes del sistema")
    if "servicio detenido" in texto:
        rec.append("[ ] Revisar y reiniciar los servicios criticos detenidos")
    if "vulnerabilidad" in texto:
        rec.append("[ ] Actualizar o desinstalar el software vulnerable detectado")
    if not rec:
        rec.append("[ ] Mantenimiento preventivo: limpieza y revision general")
    return rec


def _apartado(titulo, guia="", contenido=None, lineas_blanco=4):
    """Bloque de texto: titulo subrayado + (guia entre corchetes) + (contenido
    pre-rellenado) + lineas en blanco para que el tecnico escriba a mano."""
    bloque = []
    bloque.append(titulo.upper())
    bloque.append("-" * len(titulo))
    bloque.append("")
    if guia:
        bloque.append("[" + guia + "]")
        bloque.append("")
    if contenido:
        for linea in contenido:
            bloque.append(linea)
        bloque.append("")
    for _ in range(lineas_blanco):
        bloque.append("")
    bloque.append("")
    return "\n".join(bloque)


def construir_plantilla(cabecera, datos=None, vulns=None):
    """Construye el texto completo de la plantilla a partir de la cabecera y, si
    hay diagnostico, pre-rellena las secciones 2, 4 y 5 con datos derivados."""
    datos = datos or {}
    vulns = vulns or []
    hoy = datetime.now().strftime("%Y-%m-%d %H:%M")
    ancho = 64
    sep = "=" * ancho

    incidencias = derivar_incidencias(datos, vulns)
    estado      = resumen_estado(datos)
    recomendaciones = derivar_recomendaciones(incidencias) if incidencias else []

    partes = []
    partes.append(sep)
    partes.append("  RESOLVECORE - INFORME TECNICO")
    partes.append("  Solucion a tus problemas informaticos")
    partes.append(sep)
    partes.append("")
    partes.append("DATOS DEL SERVICIO")
    partes.append("-" * len("DATOS DEL SERVICIO"))
    partes.append("  Nro. de informe ..: ")
    partes.append("  Nro. de ticket ...: {0}".format(cabecera.get("ticket", "")))
    partes.append("  Fecha del informe : {0}".format(hoy))
    partes.append("  Tecnico ..........: ")
    partes.append("")
    partes.append("DATOS DEL CLIENTE")
    partes.append("-" * len("DATOS DEL CLIENTE"))
    partes.append("  Cliente / empresa : ")
    partes.append("  Contacto / email .: ")
    partes.append("")
    partes.append("DATOS DEL EQUIPO")
    partes.append("-" * len("DATOS DEL EQUIPO"))
    partes.append("  Equipo ...........: {0}".format(cabecera.get("equipo", "")))
    partes.append("  Sistema operativo : {0}".format(cabecera.get("sistema", "")))
    partes.append("  Plataforma .......: {0}".format(cabecera.get("plataforma", "")))
    partes.append("  Fecha diagnostico : {0}".format(cabecera.get("fecha_diagnostico", "")))
    partes.append("")
    partes.append(sep)
    partes.append("")

    # Secciones obligatorias del servicio (no se acortan: son fijas por diseno).
    # Donde hay datos del diagnostico, se pre-rellenan como ayuda; el tecnico
    # completa el resto a mano en las lineas en blanco.
    partes.append(_apartado(
        "1. Resumen ejecutivo",
        guia="Describe en 2-3 lineas el motivo de la intervencion y el resultado"))

    if incidencias:
        inc_lineas = ["  - " + x for x in incidencias]
        inc_lineas.insert(0, "Detectado automaticamente en el diagnostico:")
        partes.append(_apartado(
            "2. Incidencias detectadas",
            guia="Anade o matiza las incidencias encontradas durante el diagnostico",
            contenido=inc_lineas, lineas_blanco=3))
    else:
        partes.append(_apartado(
            "2. Incidencias detectadas",
            guia="Lista las incidencias encontradas durante el diagnostico"))

    partes.append(_apartado(
        "3. Problemas solucionados",
        guia="Indica las acciones realizadas para resolver cada incidencia"))

    if estado:
        estado_lineas = ["Lectura del diagnostico:"] + estado
        partes.append(_apartado(
            "4. Estado actual del sistema",
            contenido=estado_lineas, lineas_blanco=3))
    else:
        partes.append(_apartado(
            "4. Estado actual del sistema",
            guia="Resume el estado del equipo tras la intervencion"))

    if recomendaciones:
        partes.append(_apartado(
            "5. Recomendaciones",
            guia="Marca/ajusta el checklist sugerido y anade lo que corresponda",
            contenido=recomendaciones, lineas_blanco=3))
    else:
        partes.append(_apartado(
            "5. Recomendaciones",
            guia="Recomendaciones de mantenimiento o mejora para el cliente"))

    partes.append(_apartado(
        "6. Proyeccion de vida util del equipo",
        guia="Estimacion realista de cuanto aguantara el equipo y posible upgrade",
        contenido=[
            "  Antiguedad estimada ....: ___ anos",
            "  Vida util restante .....: ___ anos",
            "  Recomendacion de cambio : si / no",
        ], lineas_blanco=2))

    partes.append(sep)
    partes.append("  Firma del tecnico: ____________________________")
    partes.append("")
    partes.append("  ResolveCore - Francisco Vidal Mateo")
    partes.append(sep)
    partes.append("")
    return "\n".join(partes)


def nombre_fichero(cabecera):
    """Construye un nombre de fichero seguro para la plantilla."""
    equipo = cabecera.get("equipo", "") or "equipo"
    equipo = "".join(c if c.isalnum() or c in "-_" else "_" for c in equipo)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return "informe_{0}_{1}.txt".format(equipo, ts)


def main():
    parser = argparse.ArgumentParser(
        description="Genera una plantilla .txt de informe tecnico para rellenar a mano."
    )
    parser.add_argument("--json", default="", help="JSON de diagnostico para pre-rellenar la cabecera.")
    parser.add_argument("--salida", default="", help="Ruta de salida del .txt (opcional).")
    parser.add_argument("--dir-salida", default=_DIR_SALIDA, help="Carpeta de salida (por defecto scripts/diagnosticos).")
    parser.add_argument("--ticket", default="", help="Numero de ticket MantisBT: guarda en diagnosticos/tickets/<NNNNN>/informe.txt")
    parser.add_argument("--vuln-json", dest="vuln_json", default="",
                        help="JSON de buscar_vulnerabilidades.py: lista KEV/criticas en incidencias.")
    args = parser.parse_args()

    datos    = cargar_datos(args.json)
    cabecera = leer_cabecera(datos)
    cabecera["ticket"] = args.ticket or ""
    vulns    = cargar_vulns(args.vuln_json)
    texto    = construir_plantilla(cabecera, datos, vulns)

    if args.salida:
        ruta = args.salida
    elif args.ticket and args.ticket.isdigit():
        # Organiza la salida por ticket: diagnosticos/tickets/<NNNNN>/informe.txt.
        # Base configurable con RC_REPARACIONES_DIR; por defecto raiz del repo.
        repo_root = os.path.dirname(os.path.dirname(_AQUI))
        base = os.environ.get("RC_REPARACIONES_DIR") or os.path.join(repo_root, "diagnosticos", "tickets")
        dest = os.path.join(base, "{0:05d}".format(int(args.ticket)))
        os.makedirs(dest, exist_ok=True)
        ruta = os.path.join(dest, "informe.txt")
        if os.path.exists(ruta):
            # No sobrescribir: sufijo _vN y aviso.
            n = 2
            while os.path.exists(os.path.join(dest, "informe_v{0}.txt".format(n))):
                n += 1
            ruta = os.path.join(dest, "informe_v{0}.txt".format(n))
            print("[i] Ya existia informe.txt; guardando como {0}".format(os.path.basename(ruta)))
    else:
        os.makedirs(args.dir_salida, exist_ok=True)
        ruta = os.path.join(args.dir_salida, nombre_fichero(cabecera))

    try:
        with open(ruta, "w", encoding="utf-8") as f:
            f.write(texto)
    except OSError as e:
        print("[X] No se pudo escribir la plantilla: {0}".format(e), file=sys.stderr)
        sys.exit(1)

    print("[+] Plantilla de informe generada en:")
    print("    {0}".format(ruta))
    print("")
    print("[i] Rellena cada apartado a mano y sube tu el informe a MantisBT.")


if __name__ == "__main__":
    main()
