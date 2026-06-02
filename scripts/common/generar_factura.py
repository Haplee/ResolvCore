#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ResolveCore - generar_factura.py

Genera una PLANTILLA de factura en texto plano (.txt) con los campos ya
predefinidos y en blanco. El tecnico la abre, rellena los datos a mano y la
entrega al cliente. No se genera PDF ni HTML, no se sube a Mantis ni se envia
por email: el documento que recibe el cliente es esta plantilla rellenada (junto
con el informe tecnico, tambien en .txt).

Politica: solo stdlib, sin clases, sin anotaciones de tipo. Las entidades son
diccionarios creados por funciones.

Uso:
    python3 generar_factura.py
    python3 generar_factura.py --salida /ruta/factura.txt

Autor:   Francisco Vidal Mateo (GitHub: Haplee)
Version: 3.0
"""

import argparse
import os
import sys
from datetime import datetime


_AQUI = os.path.dirname(os.path.abspath(__file__))
_DIR_SALIDA = os.path.join(os.path.dirname(_AQUI), "diagnosticos")

# Contador local opcional de numero de factura por anio.
_DIR_CONFIG = os.path.join(os.path.expanduser("~"), ".resolvecore")
_FICHERO_CONTADOR = os.path.join(_DIR_CONFIG, "contador.txt")


def siguiente_numero():
    """Devuelve el siguiente numero de factura sugerido (RC-AAAA-NNNN).

    Lee y actualiza un contador local sencillo. Si algo falla, devuelve el
    formato con NNNN en blanco para que el tecnico lo ponga a mano.
    """
    anio = datetime.now().year
    try:
        os.makedirs(_DIR_CONFIG, exist_ok=True)
        ultimo = 0
        if os.path.exists(_FICHERO_CONTADOR):
            with open(_FICHERO_CONTADOR, encoding="utf-8") as f:
                texto = f.read().strip().split()
                # formato guardado: "ANIO NUMERO"
                if len(texto) == 2 and texto[0] == str(anio):
                    ultimo = int(texto[1])
        nuevo = ultimo + 1
        with open(_FICHERO_CONTADOR, "w", encoding="utf-8") as f:
            f.write("{0} {1}".format(anio, nuevo))
        return "RC-{0}-{1:04d}".format(anio, nuevo)
    except (OSError, ValueError):
        return "RC-{0}-".format(anio)


def construir_plantilla(numero):
    """Construye el texto completo de la plantilla de factura."""
    hoy = datetime.now().strftime("%Y-%m-%d")
    ancho = 64
    sep = "=" * ancho
    linea = "-" * ancho

    partes = []
    partes.append(sep)
    partes.append("  RESOLVECORE - FACTURA")
    partes.append("  Solucion a tus problemas informaticos")
    partes.append(sep)
    partes.append("")
    partes.append("  Nº de factura ....: {0}".format(numero))
    partes.append("  Fecha ............: {0}".format(hoy))
    partes.append("  Nº de ticket .....: ")
    partes.append("")
    partes.append("EMISOR (TECNICO)")
    partes.append("-" * len("EMISOR (TECNICO)"))
    partes.append("  Nombre / razon ...: ")
    partes.append("  NIF / DNI ........: ")
    partes.append("  Direccion ........: ")
    partes.append("  Email / telefono .: ")
    partes.append("")
    partes.append("CLIENTE")
    partes.append("-" * len("CLIENTE"))
    partes.append("  Nombre / empresa .: ")
    partes.append("  NIF / DNI ........: ")
    partes.append("  Direccion ........: ")
    partes.append("  Email / telefono .: ")
    partes.append("")
    partes.append("CONCEPTOS")
    partes.append("-" * len("CONCEPTOS"))
    partes.append("  {0:<34} {1:>8} {2:>8} {3:>10}".format("Descripcion", "Cant.", "Precio", "Importe"))
    partes.append("  " + linea[2:])
    for _ in range(6):
        partes.append("  {0:<34} {1:>8} {2:>8} {3:>10}".format("", "", "", ""))
    partes.append("  " + linea[2:])
    partes.append("")
    partes.append("TOTALES")
    partes.append("-" * len("TOTALES"))
    partes.append("  Base imponible ...: ")
    partes.append("  IVA (21%) ........: ")
    partes.append("  TOTAL A PAGAR ....: ")
    partes.append("")
    partes.append("FORMA DE PAGO")
    partes.append("-" * len("FORMA DE PAGO"))
    partes.append("  Metodo ...........: ")
    partes.append("  IBAN / detalle ...: ")
    partes.append("")
    partes.append(sep)
    partes.append("  ResolveCore - Francisco Vidal Mateo")
    partes.append(sep)
    partes.append("")
    return "\n".join(partes)


def nombre_fichero(numero):
    """Nombre de fichero seguro para la factura."""
    base = numero if numero else "factura"
    base = "".join(c if c.isalnum() or c in "-_" else "_" for c in base)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return "factura_{0}_{1}.txt".format(base, ts)


def main():
    parser = argparse.ArgumentParser(
        description="Genera una plantilla .txt de factura para rellenar a mano."
    )
    parser.add_argument("--salida", default="", help="Ruta de salida del .txt (opcional).")
    parser.add_argument("--dir-salida", default=_DIR_SALIDA, help="Carpeta de salida (por defecto scripts/diagnosticos).")
    parser.add_argument("--sin-numero", action="store_true", help="No usar el contador local; deja el numero en blanco.")
    args = parser.parse_args()

    numero = "RC-{0}-".format(datetime.now().year) if args.sin_numero else siguiente_numero()
    texto = construir_plantilla(numero)

    if args.salida:
        ruta = args.salida
    else:
        os.makedirs(args.dir_salida, exist_ok=True)
        ruta = os.path.join(args.dir_salida, nombre_fichero(numero))

    try:
        with open(ruta, "w", encoding="utf-8") as f:
            f.write(texto)
    except OSError as e:
        print("[X] No se pudo escribir la plantilla: {0}".format(e), file=sys.stderr)
        sys.exit(1)

    print("[+] Plantilla de factura generada en:")
    print("    {0}".format(ruta))
    print("")
    print("[i] Rellena los campos a mano y entrega la factura al cliente.")


if __name__ == "__main__":
    main()
