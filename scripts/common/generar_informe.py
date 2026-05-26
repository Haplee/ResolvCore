#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ResolveCore - generar_informe.py
Genera un informe HTML (y opcionalmente PDF) a partir del JSON de diagnóstico.

Flujo:
    JSON diagnóstico (diagnostico.ps1 / diagnostico.sh)
        └─> [enriquecido opcionalmente por buscar_vulnerabilidades.py]
            └─> generar_informe.py
                └─> informe_<hostname>_<ts>.html
                    └─> [wkhtmltopdf] informe_<hostname>_<ts>.pdf

Uso:
    python3 generar_informe.py --json diagnostico.json
    python3 generar_informe.py --json diagnostico.json --pdf
    python3 generar_informe.py --json diagnostico.json --out /ruta/informe.html
    python3 generar_informe.py --json diagnostico.json --pdf --ticket 42

Autor: Francisco Vidal Mateo (Haplee) - TFG ASIR ResolveCore
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
import webbrowser
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Optional

SCRIPT_VERSION = '1.0.0'

# Ruta de la plantilla HTML relativa a este script
_HERE = Path(__file__).resolve().parent
_TEMPLATE = _HERE.parent.parent / 'reports' / 'informe.html'

# Directorio de salida por defecto: scripts/diagnosticos/ (un nivel arriba de common/)
_OUTPUT_DIR = _HERE.parent / 'diagnosticos'


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _load_json(path: str) -> Dict[str, Any]:
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def _load_template(template_path: Path) -> str:
    if not template_path.exists():
        raise FileNotFoundError(f'Plantilla no encontrada: {template_path}')
    return template_path.read_text(encoding='utf-8')


def _safe_json_for_html(data: Any) -> str:
    """Serializa a JSON y escapa '</script>' para embeber seguro en HTML."""
    raw = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    return raw.replace('</', r'<\/')


def _default_output_name(data: Dict[str, Any]) -> str:
    meta = data.get('_meta', {})
    hostname = meta.get('hostname', 'equipo')
    hostname = re.sub(r'[^\w\-]', '_', hostname)[:32]
    ts = datetime.now().strftime('%Y%m%d_%H%M%S')
    return f'informe_{hostname}_{ts}'


def _inject_json(template: str, json_str: str) -> str:
    """Reemplaza el placeholder __JSON_DATA__ por el JSON real."""
    if '__JSON_DATA__' not in template:
        raise ValueError(
            'La plantilla no contiene el marcador __JSON_DATA__. '
            f'Revisar {_TEMPLATE}'
        )
    return template.replace('__JSON_DATA__', json_str)


# ---------------------------------------------------------------------------
# PDF via wkhtmltopdf
# ---------------------------------------------------------------------------

def _html_to_pdf(html_path: str, pdf_path: str) -> bool:
    """Convierte HTML a PDF usando wkhtmltopdf. Devuelve True si tiene éxito."""
    exe = shutil.which('wkhtmltopdf')
    if not exe:
        print('[!] wkhtmltopdf no encontrado. Instálalo para generar PDF.', file=sys.stderr)
        print('    Descarga: https://wkhtmltopdf.org/downloads.html', file=sys.stderr)
        return False

    cmd = [
        exe,
        '--quiet',
        '--enable-local-file-access',
        '--page-size', 'A4',
        '--margin-top', '10mm',
        '--margin-bottom', '10mm',
        '--margin-left', '10mm',
        '--margin-right', '10mm',
        '--javascript-delay', '1500',   # tiempo para que el JS renderice el informe
        html_path,
        pdf_path,
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        print('[!] wkhtmltopdf tardó más de 120 segundos.', file=sys.stderr)
        return False
    except Exception as exc:
        print(f'[!] Error ejecutando wkhtmltopdf: {exc}', file=sys.stderr)
        return False

    if result.returncode != 0:
        print(f'[!] wkhtmltopdf salió con código {result.returncode}', file=sys.stderr)
        if result.stderr:
            print(result.stderr[:400], file=sys.stderr)
        return False
    return True


# ---------------------------------------------------------------------------
# Adjuntar a MantisBT (opcional)
# ---------------------------------------------------------------------------

def _attach_to_mantis(pdf_path: str, ticket_id: int) -> bool:
    """Llama a adjuntar_informe_mantis.py para subir el PDF al ticket."""
    adjuntar = _HERE / 'adjuntar_informe_mantis.py'
    if not adjuntar.exists():
        print('[!] adjuntar_informe_mantis.py no encontrado.', file=sys.stderr)
        return False
    cmd = [sys.executable, str(adjuntar), '--ticket', str(ticket_id), '--pdf', pdf_path]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    except Exception as exc:
        print(f'[!] Error adjuntando a MantisBT: {exc}', file=sys.stderr)
        return False
    if result.returncode == 0:
        print(f'[✓] PDF adjuntado al ticket #{ticket_id} en MantisBT.')
        return True
    print(f'[!] No se pudo adjuntar al ticket #{ticket_id}: {result.stdout.strip()}', file=sys.stderr)
    return False


# ---------------------------------------------------------------------------
# Función principal de generación
# ---------------------------------------------------------------------------

def generate(
    json_path: str,
    output_html: Optional[str] = None,
    generate_pdf: bool = False,
    ticket_id: Optional[int] = None,
    template_path: Optional[Path] = None,
    open_browser: bool = False,
) -> Dict[str, Any]:
    """
    Genera el informe HTML y opcionalmente PDF.

    Returns:
        dict con claves: html_path, pdf_path (o None), ok (bool), errors (list)
    """
    result = {'html_path': None, 'pdf_path': None, 'ok': False, 'errors': []}

    # Cargar datos
    try:
        data = _load_json(json_path)
    except (OSError, json.JSONDecodeError) as exc:
        result['errors'].append(f'JSON inválido: {exc}')
        return result

    # Cargar plantilla
    tpl_path = template_path or _TEMPLATE
    try:
        template = _load_template(tpl_path)
    except FileNotFoundError as exc:
        result['errors'].append(str(exc))
        return result

    # Determinar ruta de salida HTML
    if output_html:
        html_out = Path(output_html)
    else:
        _OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        html_out = _OUTPUT_DIR / (_default_output_name(data) + '.html')

    # Inyectar JSON en la plantilla
    json_str = _safe_json_for_html(data)
    html_content = _inject_json(template, json_str)

    # Escribir HTML
    html_out.write_text(html_content, encoding='utf-8')
    result['html_path'] = str(html_out)
    print(f'[✓] Informe HTML generado: {html_out}')

    # Abrir en navegador opcional
    if open_browser:
        try:
            webbrowser.open(html_out.resolve().as_uri())
            print('[✓] Abierto en el navegador.')
        except Exception as exc:
            print(f'[!] No se pudo abrir en navegador: {exc}', file=sys.stderr)

    # PDF opcional
    if generate_pdf:
        pdf_out = html_out.with_suffix('.pdf')
        ok = _html_to_pdf(str(html_out), str(pdf_out))
        if ok:
            result['pdf_path'] = str(pdf_out)
            print(f'[✓] PDF generado: {pdf_out}')
            if ticket_id:
                _attach_to_mantis(str(pdf_out), ticket_id)

    result['ok'] = True
    return result


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog='generar_informe.py',
        description='ResolveCore — Genera informe HTML/PDF desde JSON de diagnóstico',
    )
    p.add_argument('--json',   required=True, metavar='FICHERO',
                   help='Ruta al JSON de diagnóstico (salida de diagnostico.ps1 / .sh)')
    p.add_argument('--out',    default=None,  metavar='RUTA',
                   help='Ruta de salida del HTML (default: diagnosticos/informe_<host>_<ts>.html)')
    p.add_argument('--pdf',    action='store_true',
                   help='Generar PDF además del HTML (requiere wkhtmltopdf)')
    p.add_argument('--ticket', type=int, default=None, metavar='ID',
                   help='ID de ticket MantisBT al que adjuntar el PDF (requiere --pdf)')
    p.add_argument('--template', default=None, metavar='RUTA',
                   help=f'Ruta a plantilla HTML alternativa (default: {_TEMPLATE})')
    p.add_argument('--open',   action='store_true',
                   help='Abrir el HTML en el navegador por defecto al terminar')
    return p.parse_args()


def main() -> int:
    if sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except AttributeError:
            pass

    args = parse_args()

    if args.ticket and not args.pdf:
        print('[!] --ticket requiere --pdf. Activando generación de PDF.', file=sys.stderr)
        args.pdf = True

    tpl = Path(args.template) if args.template else None
    result = generate(
        json_path=args.json,
        output_html=args.out,
        generate_pdf=args.pdf,
        ticket_id=args.ticket,
        template_path=tpl,
        open_browser=args.open,
    )

    if result['errors']:
        for err in result['errors']:
            print(f'[✗] {err}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
