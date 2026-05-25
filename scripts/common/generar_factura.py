#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ResolveCore - generar_factura.py
Generador interactivo de facturas (HTML + PDF) con integración MantisBT y email.

Flujo del técnico:
    1. Prompts interactivos: datos del cliente, técnico, conceptos, precios.
    2. Genera factura HTML (reports/factura.html).
    3. Convierte a PDF con wkhtmltopdf (opcional).
    4. Sube el PDF al ticket MantisBT (opcional).
    5. Envía email al cliente con la factura adjunta (opcional, cuando se
       marca el ticket como resuelto).

Uso:
    # Interactivo (técnico introduce los valores)
    python3 generar_factura.py

    # Desde un JSON pre-rellenado
    python3 generar_factura.py --datos factura-borrador.json --pdf --send-email

    # Para CI/testing: --no-interactive
    python3 generar_factura.py --datos factura.json --no-interactive --pdf

Variables de entorno:
    MANTIS_URL          — URL base MantisBT (subir factura)
    MANTIS_TOKEN        — token API REST MantisBT
    SMTP_HOST           — servidor SMTP saliente
    SMTP_PORT           — puerto (default 587)
    SMTP_USER           — usuario SMTP
    SMTP_PASSWORD       — contraseña SMTP
    SMTP_FROM           — remitente (default: SMTP_USER)
    SMTP_FROM_NAME      — nombre del remitente (default: ResolveCore)

Política: stdlib only. Sin dependencias pip.

Autor: Francisco Vidal Mateo (Haplee) - TFG ASIR ResolveCore
"""

import argparse
import json
import os
import re
import shutil
import smtplib
import subprocess
import sys
import webbrowser
from datetime import datetime, timedelta
from email.mime.base import MIMEBase
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email import encoders
from pathlib import Path
from typing import Any, Dict, List, Optional

SCRIPT_VERSION = '1.0.0'

_HERE = Path(__file__).resolve().parent
_TEMPLATE = _HERE.parent.parent / 'reports' / 'factura.html'
_OUTPUT_DIR = _HERE.parent / 'diagnosticos'


# ---------------------------------------------------------------------------
# Helpers de prompt
# ---------------------------------------------------------------------------

def _prompt(label: str, default: str = '', required: bool = False) -> str:
    """Prompt con valor por defecto. Repite si requerido y vacío."""
    while True:
        suffix = f' [{default}]' if default else ''
        val = input(f'  {label}{suffix}: ').strip()
        if not val:
            val = default
        if required and not val:
            print('    [!] Campo obligatorio')
            continue
        return val


def _prompt_float(label: str, default: float = 0.0) -> float:
    while True:
        raw = input(f'  {label} [{default}]: ').strip().replace(',', '.')
        if not raw:
            return default
        try:
            return float(raw)
        except ValueError:
            print('    [!] Introduce un número (ej: 35.50)')


def _prompt_int(label: str, default: int = 1) -> int:
    while True:
        raw = input(f'  {label} [{default}]: ').strip()
        if not raw:
            return default
        if raw.isdigit():
            return int(raw)
        print('    [!] Introduce un entero')


def _prompt_yes(label: str, default: bool = True) -> bool:
    suffix = 'S/n' if default else 's/N'
    raw = input(f'  {label} [{suffix}]: ').strip().lower()
    if not raw:
        return default
    return raw in ('s', 'si', 'sí', 'y', 'yes')


# ---------------------------------------------------------------------------
# Construcción de los datos de la factura
# ---------------------------------------------------------------------------

def build_invoice_data_interactive() -> Dict[str, Any]:
    """Pregunta al técnico todos los datos necesarios."""
    print('')
    print('  ═══════════════════════════════════════════════')
    print('   ResolveCore — Generador de factura')
    print('  ═══════════════════════════════════════════════')
    print('')

    today = datetime.now()
    numero_default = f'RC-{today.strftime("%Y%m%d")}-{os.getpid() % 1000:03d}'

    print('  --- Datos generales ---')
    numero = _prompt('Número de factura', default=numero_default, required=True)
    fecha = _prompt('Fecha (YYYY-MM-DD)', default=today.strftime('%Y-%m-%d'))
    venc_default = (today + timedelta(days=30)).strftime('%Y-%m-%d')
    fecha_vencimiento = _prompt('Fecha vencimiento', default=venc_default)
    ticket_id = _prompt('ID ticket MantisBT (vacío si no aplica)', default='')

    print('')
    print('  --- Datos del técnico (emisor) ---')
    tec_default_email = os.getenv('SMTP_FROM', 'tecnicos@resolvecore.website')
    tecnico_nombre = _prompt('Nombre técnico', default='Francisco Vidal Mateo', required=True)
    tecnico_nif    = _prompt('NIF/DNI técnico', default='')
    tecnico_email  = _prompt('Email técnico', default=tec_default_email)
    tecnico_tel    = _prompt('Teléfono técnico', default='')

    print('')
    print('  --- Datos del cliente ---')
    cliente_nombre = _prompt('Nombre cliente', required=True)
    cliente_nif    = _prompt('NIF/DNI cliente', default='')
    cliente_email  = _prompt('Email cliente (para envío de factura)', required=False)
    cliente_direccion = _prompt('Dirección cliente', default='')

    print('')
    print('  --- Conceptos facturados ---')
    print('  (deja descripción vacía para terminar)')
    items: List[Dict[str, Any]] = []
    n = 1
    while True:
        print(f'')
        print(f'  Concepto #{n}:')
        desc = input('    Descripción: ').strip()
        if not desc:
            if not items:
                print('    [!] Añade al menos un concepto')
                continue
            break
        cant = _prompt_int('    Cantidad', default=1)
        precio = _prompt_float('    Precio unitario (€)', default=0.0)
        items.append({
            'descripcion': desc,
            'cantidad': cant,
            'precio_unitario': precio,
        })
        n += 1

    print('')
    iva_pct = _prompt_float('  IVA % (España 21 por defecto)', default=21.0)
    metodo_pago = _prompt('Método de pago', default='Transferencia bancaria')
    notas = _prompt('Notas técnicas (resumen del trabajo)', default='')

    return {
        'numero': numero,
        'fecha': fecha,
        'fecha_vencimiento': fecha_vencimiento,
        'ticket_id': ticket_id or None,
        'tecnico_nombre': tecnico_nombre,
        'tecnico_nif': tecnico_nif,
        'tecnico_email': tecnico_email,
        'tecnico_tel': tecnico_tel,
        'cliente_nombre': cliente_nombre,
        'cliente_nif': cliente_nif,
        'cliente_email': cliente_email,
        'cliente_direccion': cliente_direccion,
        'items': items,
        'iva_pct': iva_pct,
        'metodo_pago': metodo_pago,
        'notas': notas,
        '_meta': {
            'generado_en': datetime.utcnow().isoformat() + 'Z',
            'version_generador': SCRIPT_VERSION,
        },
    }


# ---------------------------------------------------------------------------
# Generación HTML + PDF
# ---------------------------------------------------------------------------

def _safe_json_for_html(data: Any) -> str:
    raw = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    return raw.replace('</', r'<\/')


def _slug(text: str) -> str:
    return re.sub(r'[^a-zA-Z0-9-]', '_', text)[:48]


def generate_html(data: Dict[str, Any], output_html: Optional[Path] = None) -> Path:
    if not _TEMPLATE.exists():
        raise FileNotFoundError(f'Plantilla no encontrada: {_TEMPLATE}')
    template = _TEMPLATE.read_text(encoding='utf-8')
    if '__JSON_DATA__' not in template:
        raise ValueError('Plantilla sin marcador __JSON_DATA__')
    html_content = template.replace('__JSON_DATA__', _safe_json_for_html(data))

    if output_html is None:
        _OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        cliente = _slug(data.get('cliente_nombre', 'cliente'))
        numero  = _slug(data.get('numero', 'factura'))
        output_html = _OUTPUT_DIR / f'factura_{numero}_{cliente}.html'

    output_html.write_text(html_content, encoding='utf-8')
    return output_html


def html_to_pdf(html_path: Path, pdf_path: Optional[Path] = None) -> Optional[Path]:
    if pdf_path is None:
        pdf_path = html_path.with_suffix('.pdf')
    exe = shutil.which('wkhtmltopdf')
    if not exe:
        print('[!] wkhtmltopdf no encontrado.', file=sys.stderr)
        return None
    cmd = [exe, '--quiet', '--enable-local-file-access',
           '--page-size', 'A4',
           '--margin-top', '12mm', '--margin-bottom', '12mm',
           '--margin-left', '12mm', '--margin-right', '12mm',
           '--javascript-delay', '1000',
           str(html_path), str(pdf_path)]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    except Exception as exc:
        print(f'[!] Error wkhtmltopdf: {exc}', file=sys.stderr)
        return None
    if res.returncode != 0:
        print(f'[!] wkhtmltopdf exit={res.returncode}: {res.stderr[:300]}', file=sys.stderr)
        return None
    return pdf_path


# ---------------------------------------------------------------------------
# Subir a MantisBT (via adjuntar_informe_mantis.py)
# ---------------------------------------------------------------------------

def upload_to_mantis(pdf_path: Path, ticket_id: int) -> bool:
    adjuntar = _HERE / 'adjuntar_informe_mantis.py'
    if not adjuntar.exists():
        print('[!] adjuntar_informe_mantis.py no encontrado', file=sys.stderr)
        return False
    cmd = [sys.executable, str(adjuntar), '--ticket', str(ticket_id), '--pdf', str(pdf_path)]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    except Exception as exc:
        print(f'[!] Error subiendo a Mantis: {exc}', file=sys.stderr)
        return False
    if res.returncode == 0:
        print(f'[✓] Factura adjuntada al ticket #{ticket_id}')
        return True
    print(f'[!] No se pudo adjuntar a Mantis (exit={res.returncode}): {res.stdout.strip()}',
          file=sys.stderr)
    return False


# ---------------------------------------------------------------------------
# Envío por email
# ---------------------------------------------------------------------------

def send_invoice_email(
    pdf_path: Path,
    data: Dict[str, Any],
    smtp_host: Optional[str] = None,
    smtp_port: int = 587,
    smtp_user: Optional[str] = None,
    smtp_password: Optional[str] = None,
    smtp_from: Optional[str] = None,
    smtp_from_name: str = 'ResolveCore',
) -> bool:
    """Envía la factura PDF al cliente vía SMTP."""
    to_addr = data.get('cliente_email', '').strip()
    if not to_addr:
        print('[!] Sin email del cliente — no se envía', file=sys.stderr)
        return False

    smtp_host = smtp_host or os.getenv('SMTP_HOST', '')
    smtp_user = smtp_user or os.getenv('SMTP_USER', '')
    smtp_password = smtp_password or os.getenv('SMTP_PASSWORD', '')
    smtp_from = smtp_from or os.getenv('SMTP_FROM', smtp_user)
    smtp_from_name = os.getenv('SMTP_FROM_NAME', smtp_from_name)

    if not smtp_host or not smtp_user or not smtp_password:
        print('[!] SMTP no configurado (SMTP_HOST/SMTP_USER/SMTP_PASSWORD)', file=sys.stderr)
        return False

    # Calcular total para el cuerpo del email
    items = data.get('items', [])
    subtotal = sum((float(i.get('cantidad', 0)) * float(i.get('precio_unitario', 0))) for i in items)
    iva_pct = float(data.get('iva_pct', 21))
    total = subtotal * (1 + iva_pct / 100)

    msg = MIMEMultipart('mixed')
    msg['From'] = f'{smtp_from_name} <{smtp_from}>'
    msg['To'] = to_addr
    msg['Subject'] = f'ResolveCore — Factura {data.get("numero","")} (Ticket #{data.get("ticket_id","-")})'

    cuerpo = f"""Hola {data.get('cliente_nombre','')},

Adjuntamos la factura {data.get('numero','')} por el servicio técnico
realizado{f" en relación al ticket #{data['ticket_id']}" if data.get('ticket_id') else ''}.

  Resumen del trabajo:
{(data.get('notas') or '  (sin notas)').strip()}

  Importe total: {total:.2f} €  (IVA {iva_pct:.0f}% incluido)
  Fecha emisión: {data.get('fecha','')}
  Vencimiento:   {data.get('fecha_vencimiento','')}
  Método de pago: {data.get('metodo_pago','')}

Encontrarás el detalle completo en el PDF adjunto.

Gracias por confiar en ResolveCore.

— {data.get('tecnico_nombre','ResolveCore')}
  {data.get('tecnico_email','')}
"""

    msg.attach(MIMEText(cuerpo, 'plain', 'utf-8'))

    # Adjuntar PDF
    with open(pdf_path, 'rb') as f:
        part = MIMEBase('application', 'pdf')
        part.set_payload(f.read())
    encoders.encode_base64(part)
    part.add_header('Content-Disposition', f'attachment; filename="{pdf_path.name}"')
    msg.attach(part)

    try:
        with smtplib.SMTP(smtp_host, smtp_port, timeout=30) as s:
            s.ehlo()
            s.starttls()
            s.login(smtp_user, smtp_password)
            s.send_message(msg)
        print(f'[✓] Factura enviada por email a {to_addr}')
        return True
    except Exception as exc:
        print(f'[!] Error enviando email: {exc}', file=sys.stderr)
        return False


# ---------------------------------------------------------------------------
# Carga de .env opcional
# ---------------------------------------------------------------------------

def _load_dotenv() -> None:
    """Carga ~/.resolvecore/.env si existe (no sobreescribe variables ya seteadas)."""
    candidates = [
        Path.home() / '.resolvecore' / '.env',
        _HERE.parent.parent / '.env',
    ]
    for p in candidates:
        if p.exists():
            try:
                for line in p.read_text(encoding='utf-8').splitlines():
                    line = line.strip()
                    if not line or line.startswith('#') or '=' not in line:
                        continue
                    k, _, v = line.partition('=')
                    k = k.strip()
                    v = v.strip().strip('"').strip("'")
                    if k and k not in os.environ:
                        os.environ[k] = v
            except OSError:
                pass


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog='generar_factura.py',
        description='ResolveCore — Generador interactivo de facturas',
    )
    p.add_argument('--datos', metavar='JSON',
                   help='Cargar datos de factura desde fichero JSON (en lugar de prompts)')
    p.add_argument('--out', metavar='RUTA',
                   help='Ruta de salida del HTML (default: diagnosticos/factura_<n>_<cliente>.html)')
    p.add_argument('--pdf', action='store_true',
                   help='Generar PDF además del HTML')
    p.add_argument('--upload', action='store_true',
                   help='Subir el PDF al ticket MantisBT (requiere --pdf y ticket_id)')
    p.add_argument('--send-email', action='store_true',
                   help='Enviar la factura por email al cliente (requiere SMTP_*)')
    p.add_argument('--open', action='store_true',
                   help='Abrir el HTML en el navegador al terminar')
    p.add_argument('--no-interactive', action='store_true',
                   help='No usar prompts (requiere --datos)')
    p.add_argument('--save-json', metavar='RUTA',
                   help='Guardar los datos introducidos como JSON (útil para reutilizar)')
    return p.parse_args()


def main() -> int:
    if sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except AttributeError:
            pass

    _load_dotenv()
    args = parse_args()

    if args.datos:
        try:
            with open(args.datos, encoding='utf-8') as f:
                data = json.load(f)
        except (OSError, json.JSONDecodeError) as exc:
            print(f'[X] No se pudo leer {args.datos}: {exc}', file=sys.stderr)
            return 1
    else:
        if args.no_interactive:
            print('[X] --no-interactive requiere --datos', file=sys.stderr)
            return 1
        data = build_invoice_data_interactive()

    if args.save_json:
        try:
            Path(args.save_json).write_text(json.dumps(data, ensure_ascii=False, indent=2),
                                            encoding='utf-8')
            print(f'[✓] Datos guardados en {args.save_json}')
        except OSError as exc:
            print(f'[!] No se pudo guardar JSON: {exc}', file=sys.stderr)

    # Generar HTML
    out_html = Path(args.out) if args.out else None
    try:
        html_path = generate_html(data, out_html)
        print(f'[✓] Factura HTML: {html_path}')
    except (FileNotFoundError, ValueError) as exc:
        print(f'[X] {exc}', file=sys.stderr)
        return 1

    # Abrir en navegador opcional
    if args.open:
        try:
            webbrowser.open(html_path.resolve().as_uri())
        except Exception:
            pass

    pdf_path: Optional[Path] = None
    if args.pdf or args.upload or args.send_email:
        pdf_path = html_to_pdf(html_path)
        if pdf_path:
            print(f'[✓] Factura PDF:  {pdf_path}')
        else:
            print('[!] No se generó PDF — se omiten upload/email', file=sys.stderr)

    # Subir a MantisBT
    if args.upload and pdf_path:
        tk = data.get('ticket_id')
        if tk and str(tk).isdigit():
            upload_to_mantis(pdf_path, int(tk))
        else:
            print('[!] Sin ticket_id válido — no se sube a MantisBT', file=sys.stderr)

    # Enviar email
    if args.send_email and pdf_path:
        send_invoice_email(pdf_path, data)

    return 0


if __name__ == '__main__':
    sys.exit(main())
