#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fase 2 MantisBT — adjunta informe PDF a un ticket existente via API REST.

Arquitectura (hexagonal):
    CLI (este fichero) -> adapter MantisRestSink -> AttachmentResult (dominio)

Politica: stdlib only. Token via env MANTIS_TOKEN, URL via MANTIS_URL.

Uso:
    export MANTIS_URL=https://mantis.tu-dominio.tld
    export MANTIS_TOKEN=xxxxxxxxxxxxxxxx
    python scripts/common/adjuntar_informe_mantis.py --ticket 42 --pdf informe_42.pdf

Exit codes:
    0  exito
    1  fallo de subida (red, HTTP, fichero)
    2  argumentos invalidos o entorno mal configurado

Autor:   Francisco Vidal Mateo (GitHub: Haplee)
"""

import argparse
import os
import sys
from pathlib import Path

if __package__ in (None, ""):
    _here = os.path.dirname(os.path.abspath(__file__))
    _parent = os.path.dirname(_here)
    if _parent not in sys.path:
        sys.path.insert(0, _parent)
    from common.adapters import mantis_rest
else:
    from .adapters import mantis_rest

SCRIPT_VERSION = "2.0.0"


def main(argv=None):
    parser = argparse.ArgumentParser(description="Adjuntar PDF a ticket MantisBT")
    parser.add_argument("--ticket", type=int, required=True, help="ID del ticket")
    parser.add_argument("--pdf", type=Path, required=True, help="ruta al informe PDF")
    args = parser.parse_args(argv)

    try:
        config = mantis_rest.config_desde_entorno()
    except RuntimeError as exc:
        print(f"[ERR] {exc}", file=sys.stderr)
        return 2

    result = mantis_rest.attach(args.ticket, args.pdf, config=config)
    if result["ok"]:
        print(f"[OK] ticket #{result['ticket_id']}: {result['file_name']} subido ({result['status_code']})")
        return 0

    print(f"[FAIL] ticket #{result['ticket_id']}: {result['error']}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
