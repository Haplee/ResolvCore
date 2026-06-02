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


def leer_diagnostico(ruta):
    """Lee el JSON de diagnostico y devuelve un dict con los datos de cabecera.

    Nunca lanza excepcion: si el fichero no existe o no es JSON valido, devuelve
    un dict con los campos vacios para que la plantilla salga igual.
    """
    cabecera = nueva_cabecera()
    if not ruta:
        return cabecera
    try:
        with open(ruta, encoding="utf-8-sig") as f:
            datos = json.load(f)
    except (OSError, ValueError):
        return cabecera

    cabecera["equipo"] = (
        datos.get("hostname")
        or datos.get("dispositivo")
        or datos.get("_meta", {}).get("hostname", "")
    )
    cabecera["sistema"] = datos.get("os") or datos.get("android", "")
    cabecera["plataforma"] = datos.get("_meta", {}).get("plataforma", "")
    cabecera["fecha_diagnostico"] = datos.get("timestamp", "")
    return cabecera


def nueva_cabecera():
    """Dict de cabecera con los datos que pueden venir del diagnostico."""
    return {
        "equipo": "",
        "sistema": "",
        "plataforma": "",
        "fecha_diagnostico": "",
    }


def _apartado(titulo, lineas_blanco=4):
    """Devuelve un bloque de texto: titulo subrayado + lineas en blanco."""
    bloque = []
    bloque.append(titulo.upper())
    bloque.append("-" * len(titulo))
    bloque.append("")
    for _ in range(lineas_blanco):
        bloque.append("")
    bloque.append("")
    return "\n".join(bloque)


def construir_plantilla(cabecera):
    """Construye el texto completo de la plantilla a partir de la cabecera."""
    hoy = datetime.now().strftime("%Y-%m-%d %H:%M")
    ancho = 64
    sep = "=" * ancho

    partes = []
    partes.append(sep)
    partes.append("  RESOLVECORE - INFORME TECNICO")
    partes.append("  Solucion a tus problemas informaticos")
    partes.append(sep)
    partes.append("")
    partes.append("DATOS DEL SERVICIO")
    partes.append("-" * len("DATOS DEL SERVICIO"))
    partes.append("  Nº de informe ....: ")
    partes.append("  Nº de ticket .....: ")
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
    fecha_diag = cabecera.get("fecha_diagnostico", "")
    partes.append("  Fecha diagnostico : {0}".format(fecha_diag))
    partes.append("")
    partes.append(sep)
    partes.append("")

    # Secciones obligatorias del servicio (no se acortan: son fijas por diseno).
    partes.append(_apartado("1. Resumen ejecutivo"))
    partes.append(_apartado("2. Incidencias detectadas"))
    partes.append(_apartado("3. Problemas solucionados"))
    partes.append(_apartado("4. Estado actual del sistema"))
    partes.append(_apartado("5. Recomendaciones"))
    partes.append(_apartado("6. Proyeccion de vida util del equipo"))

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
    args = parser.parse_args()

    cabecera = leer_diagnostico(args.json)
    texto = construir_plantilla(cabecera)

    if args.salida:
        ruta = args.salida
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
