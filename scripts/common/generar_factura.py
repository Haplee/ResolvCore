#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ResolveCore - generar_factura.py
Generador de facturas (HTML + PDF) con integración MantisBT y email.

Mejoras v1.1.0:
  - Persistencia del técnico (~/.resolvecore/tecnico.json).
  - Catálogo de servicios reutilizable (~/.resolvecore/servicios.json).
  - Numeración automática por año (~/.resolvecore/contador.json).
  - Modo --batch CSV para múltiples facturas en una pasada.
  - Registro contable JSONL (~/.resolvecore/facturas.jsonl) + --listar / --marcar-pagada / --resumen.
  - Plantilla de email configurable (~/.resolvecore/email-template.txt).

Política: stdlib only. Sin dependencias pip.

Autor:   Francisco Vidal Mateo (GitHub: Haplee)
"""

import argparse
import csv
import json
import os
import re
import shutil
import smtplib
import subprocess
import sys
import webbrowser
from datetime import datetime, timedelta, timezone
from email.mime.base import MIMEBase
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email import encoders
from pathlib import Path
from typing import Any, Dict, List, Optional

SCRIPT_VERSION = '1.1.0'

_HERE = Path(__file__).resolve().parent
_TEMPLATE = _HERE.parent.parent / 'reports' / 'factura.html'
_OUTPUT_DIR = _HERE.parent / 'diagnosticos'

_CONFIG_DIR = Path.home() / '.resolvecore'
_TECNICO_FILE   = _CONFIG_DIR / 'tecnico.json'
_SERVICIOS_FILE = _CONFIG_DIR / 'servicios.json'
_CONTADOR_FILE  = _CONFIG_DIR / 'contador.json'
_REGISTRO_FILE  = _CONFIG_DIR / 'facturas.jsonl'
_EMAIL_TPL_FILE = _CONFIG_DIR / 'email-template.txt'


# ---------------------------------------------------------------------------
# Persistencia (config dir)
# ---------------------------------------------------------------------------

def _ensure_config_dir() -> None:
    _CONFIG_DIR.mkdir(parents=True, exist_ok=True)


def _read_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except (OSError, json.JSONDecodeError):
        return default


def _write_json(path: Path, data: Any) -> None:
    _ensure_config_dir()
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')


# ---------------------------------------------------------------------------
# Numeración automática (C)
# ---------------------------------------------------------------------------

def next_invoice_number() -> str:
    """Devuelve siguiente número RC-YYYY-NNNN. Persiste contador."""
    year = datetime.now().year
    data = _read_json(_CONTADOR_FILE, {})
    last = int(data.get(str(year), 0))
    nxt = last + 1
    data[str(year)] = nxt
    _write_json(_CONTADOR_FILE, data)
    return f'RC-{year}-{nxt:04d}'


# ---------------------------------------------------------------------------
# Técnico persistente (A)
# ---------------------------------------------------------------------------

_DEFAULT_TECNICO = {
    'nombre': 'Francisco Vidal Mateo',
    'nif': '',
    'email': 'tecnicos@resolvecore.website',
    'tel': '',
}


def load_tecnico() -> Dict[str, str]:
    data = _read_json(_TECNICO_FILE, None)
    if isinstance(data, dict):
        return {**_DEFAULT_TECNICO, **data}
    return dict(_DEFAULT_TECNICO)


def save_tecnico(tec: Dict[str, str]) -> None:
    _write_json(_TECNICO_FILE, tec)


# ---------------------------------------------------------------------------
# Catálogo de servicios (B)
# ---------------------------------------------------------------------------

_DEFAULT_SERVICIOS = [
    {'codigo': 'DIAG',  'descripcion': 'Diagnóstico remoto AnyDesk (1h)', 'precio': 35.00},
    {'codigo': 'OPTIM', 'descripcion': 'Optimización del sistema',         'precio': 45.00},
    {'codigo': 'MALW',  'descripcion': 'Limpieza de malware',              'precio': 60.00},
    {'codigo': 'CVE',   'descripcion': 'Revisión de vulnerabilidades + parches', 'precio': 50.00},
    {'codigo': 'BACKUP','descripcion': 'Configuración de copia de seguridad',    'precio': 40.00},
    {'codigo': 'CLON',  'descripcion': 'Clonación / restauración de equipo',     'precio': 80.00},
    {'codigo': 'INSTALL','descripcion':'Instalación/configuración de software',  'precio': 30.00},
    {'codigo': 'HORA',  'descripcion': 'Hora adicional de soporte técnico',      'precio': 30.00},
]


def load_servicios() -> List[Dict[str, Any]]:
    data = _read_json(_SERVICIOS_FILE, None)
    if isinstance(data, list) and data:
        return data
    _write_json(_SERVICIOS_FILE, _DEFAULT_SERVICIOS)
    return list(_DEFAULT_SERVICIOS)


# ---------------------------------------------------------------------------
# Registro contable (F)
# ---------------------------------------------------------------------------

def _registry_append(entry: Dict[str, Any]) -> None:
    _ensure_config_dir()
    with _REGISTRO_FILE.open('a', encoding='utf-8') as f:
        f.write(json.dumps(entry, ensure_ascii=False) + '\n')


def _registry_read() -> List[Dict[str, Any]]:
    if not _REGISTRO_FILE.exists():
        return []
    out = []
    for line in _REGISTRO_FILE.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return out


def registrar_factura(data: Dict[str, Any], html_path: Path, pdf_path: Optional[Path]) -> None:
    total = _compute_total(data)
    entry = {
        'numero': data.get('numero'),
        'fecha': data.get('fecha'),
        'cliente': data.get('cliente_nombre'),
        'cliente_email': data.get('cliente_email'),
        'ticket_id': data.get('ticket_id'),
        'subtotal': round(total['subtotal'], 2),
        'iva_pct': total['iva_pct'],
        'iva_importe': round(total['iva_importe'], 2),
        'total': round(total['total'], 2),
        'estado': 'emitida',
        'html': str(html_path),
        'pdf':  str(pdf_path) if pdf_path else None,
        'creada_en': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    }
    _registry_append(entry)


def marcar_estado(numero: str, nuevo_estado: str) -> bool:
    rows = _registry_read()
    found = False
    for r in rows:
        if r.get('numero') == numero:
            r['estado'] = nuevo_estado
            r['actualizada_en'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
            found = True
    if not found:
        return False
    _ensure_config_dir()
    with _REGISTRO_FILE.open('w', encoding='utf-8') as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + '\n')
    return True


def listar_facturas(estado: Optional[str] = None) -> None:
    rows = _registry_read()
    if estado:
        rows = [r for r in rows if r.get('estado') == estado]
    if not rows:
        print('(sin facturas)')
        return
    print(f'{"NUMERO":<18} {"FECHA":<11} {"CLIENTE":<24} {"TOTAL":>10}  ESTADO')
    print('-' * 78)
    for r in rows:
        print(f'{r.get("numero",""):<18} {r.get("fecha",""):<11} '
              f'{(r.get("cliente") or "")[:24]:<24} '
              f'{r.get("total",0):>8.2f} €  {r.get("estado","")}')


def resumen_periodo(periodo: str) -> None:
    """periodo: 'YYYY' o 'YYYY-MM'."""
    rows = _registry_read()
    rows = [r for r in rows if str(r.get('fecha', '')).startswith(periodo)]
    if not rows:
        print(f'(sin facturas en {periodo})')
        return
    base   = sum(r.get('subtotal', 0) for r in rows)
    iva    = sum(r.get('iva_importe', 0) for r in rows)
    total  = sum(r.get('total', 0) for r in rows)
    pagadas = sum(1 for r in rows if r.get('estado') == 'pagada')
    print(f'Resumen {periodo}')
    print('-' * 40)
    print(f'  Facturas:        {len(rows)}')
    print(f'    pagadas:       {pagadas}')
    print(f'    pendientes:    {len(rows) - pagadas}')
    print(f'  Base imponible:  {base:>10.2f} €')
    print(f'  IVA repercutido: {iva:>10.2f} €')
    print(f'  TOTAL facturado: {total:>10.2f} €')


# ---------------------------------------------------------------------------
# Cálculo totales
# ---------------------------------------------------------------------------

def _compute_total(data: Dict[str, Any]) -> Dict[str, float]:
    items = data.get('items', [])
    subtotal = sum(float(i.get('cantidad', 0)) * float(i.get('precio_unitario', 0)) for i in items)
    iva_pct = float(data.get('iva_pct', 21))
    iva_importe = subtotal * iva_pct / 100
    total = subtotal + iva_importe
    return {'subtotal': subtotal, 'iva_pct': iva_pct,
            'iva_importe': iva_importe, 'total': total}


# ---------------------------------------------------------------------------
# Helpers de prompt
# ---------------------------------------------------------------------------

def _prompt(label: str, default: str = '', required: bool = False) -> str:
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
# Selección de servicio desde catálogo (B)
# ---------------------------------------------------------------------------

def _print_catalogo(catalogo: List[Dict[str, Any]]) -> None:
    print('')
    print('  Catálogo de servicios disponibles:')
    for idx, s in enumerate(catalogo, 1):
        print(f'    {idx:>2}. [{s.get("codigo",""):<7}] {s.get("descripcion","")} '
              f'— {float(s.get("precio",0)):.2f} €')
    print('     0. (introducir concepto libre)')


def _pick_servicio(catalogo: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    raw = input('    Nº catálogo / código / ENTER libre: ').strip()
    if not raw:
        return None
    # Por número
    if raw.isdigit():
        n = int(raw)
        if n == 0:
            return None
        if 1 <= n <= len(catalogo):
            return dict(catalogo[n - 1])
    # Por código
    for s in catalogo:
        if s.get('codigo', '').lower() == raw.lower():
            return dict(s)
    print('    [!] No reconocido, se introducirá manual')
    return None


# ---------------------------------------------------------------------------
# Construcción de los datos de la factura
# ---------------------------------------------------------------------------

def build_invoice_data_interactive() -> Dict[str, Any]:
    print('')
    print('  ═══════════════════════════════════════════════')
    print('   ResolveCore — Generador de factura')
    print('  ═══════════════════════════════════════════════')
    print('')

    tecnico_saved = load_tecnico()
    catalogo = load_servicios()
    today = datetime.now()
    numero_default = next_invoice_number()

    print('  --- Datos generales ---')
    numero = _prompt('Número de factura', default=numero_default, required=True)
    fecha = _prompt('Fecha (YYYY-MM-DD)', default=today.strftime('%Y-%m-%d'))
    venc_default = (today + timedelta(days=30)).strftime('%Y-%m-%d')
    fecha_vencimiento = _prompt('Fecha vencimiento', default=venc_default)
    ticket_id = _prompt('ID ticket MantisBT (vacío si no aplica)', default='')

    print('')
    print('  --- Datos del técnico (emisor) ---')
    print('  (Enter para usar el valor guardado en ~/.resolvecore/tecnico.json)')
    tecnico_nombre = _prompt('Nombre técnico', default=tecnico_saved['nombre'], required=True)
    tecnico_nif    = _prompt('NIF/DNI técnico', default=tecnico_saved['nif'])
    tecnico_email  = _prompt('Email técnico', default=tecnico_saved['email'])
    tecnico_tel    = _prompt('Teléfono técnico', default=tecnico_saved['tel'])
    nuevo_tec = {'nombre': tecnico_nombre, 'nif': tecnico_nif,
                 'email': tecnico_email, 'tel': tecnico_tel}
    if nuevo_tec != tecnico_saved:
        save_tecnico(nuevo_tec)
        print('  [✓] Datos del técnico actualizados')

    print('')
    print('  --- Datos del cliente ---')
    cliente_nombre = _prompt('Nombre cliente', required=True)
    cliente_nif    = _prompt('NIF/DNI cliente', default='')
    cliente_email  = _prompt('Email cliente (para envío de factura)', required=False)
    cliente_direccion = _prompt('Dirección cliente', default='')

    print('')
    print('  --- Conceptos facturados ---')
    _print_catalogo(catalogo)
    print('  (deja descripción vacía para terminar)')
    items: List[Dict[str, Any]] = []
    n = 1
    while True:
        print('')
        print(f'  Concepto #{n}:')
        srv = _pick_servicio(catalogo)
        if srv is None:
            desc = input('    Descripción libre: ').strip()
            if not desc:
                if not items:
                    print('    [!] Añade al menos un concepto')
                    continue
                break
            cant = _prompt_int('    Cantidad', default=1)
            precio = _prompt_float('    Precio unitario (€)', default=0.0)
        else:
            print(f'    → {srv["descripcion"]} ({srv["precio"]:.2f} €)')
            cant = _prompt_int('    Cantidad', default=1)
            precio = _prompt_float('    Precio unitario (€)', default=float(srv['precio']))
            desc = srv['descripcion']
        items.append({'descripcion': desc, 'cantidad': cant, 'precio_unitario': precio})
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
            'generado_en': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
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
# Subir a MantisBT
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
# Plantilla de email (K)
# ---------------------------------------------------------------------------

_DEFAULT_EMAIL_TEMPLATE = """Asunto: ResolveCore — Factura {numero} {ticket_ref}

Hola {cliente_nombre},

Adjuntamos la factura {numero} por el servicio técnico realizado{ticket_inline}.

  Resumen del trabajo:
{notas}

  Base imponible: {subtotal:.2f} €
  IVA ({iva_pct:.0f}%): {iva_importe:.2f} €
  TOTAL:          {total:.2f} €

  Fecha emisión: {fecha}
  Vencimiento:   {fecha_vencimiento}
  Método de pago: {metodo_pago}

Encontrarás el detalle completo en el PDF adjunto.

Gracias por confiar en ResolveCore.

— {tecnico_nombre}
  {tecnico_email}
"""


def _ensure_email_template() -> str:
    if not _EMAIL_TPL_FILE.exists():
        _ensure_config_dir()
        _EMAIL_TPL_FILE.write_text(_DEFAULT_EMAIL_TEMPLATE, encoding='utf-8')
        return _DEFAULT_EMAIL_TEMPLATE
    return _EMAIL_TPL_FILE.read_text(encoding='utf-8')


def _render_email(data: Dict[str, Any]) -> Dict[str, str]:
    tpl = _ensure_email_template()
    totals = _compute_total(data)
    ctx = {
        'numero': data.get('numero', ''),
        'fecha': data.get('fecha', ''),
        'fecha_vencimiento': data.get('fecha_vencimiento', ''),
        'cliente_nombre': data.get('cliente_nombre', ''),
        'cliente_email': data.get('cliente_email', ''),
        'tecnico_nombre': data.get('tecnico_nombre', 'ResolveCore'),
        'tecnico_email': data.get('tecnico_email', ''),
        'metodo_pago': data.get('metodo_pago', ''),
        'notas': (data.get('notas') or '  (sin notas)').strip(),
        'ticket_id': data.get('ticket_id') or '',
        'ticket_ref': f'(Ticket #{data["ticket_id"]})' if data.get('ticket_id') else '',
        'ticket_inline': f' en relación al ticket #{data["ticket_id"]}' if data.get('ticket_id') else '',
        'subtotal': totals['subtotal'],
        'iva_pct': totals['iva_pct'],
        'iva_importe': totals['iva_importe'],
        'total': totals['total'],
    }
    rendered = tpl.format(**ctx)
    # Primera línea con "Asunto:" es opcional
    subject = f'ResolveCore — Factura {ctx["numero"]} {ctx["ticket_ref"]}'.strip()
    body = rendered
    if rendered.lower().startswith('asunto:'):
        first_nl = rendered.find('\n')
        subject = rendered[len('asunto:'):first_nl].strip()
        body = rendered[first_nl + 1:].lstrip('\n')
    return {'subject': subject, 'body': body}


# ---------------------------------------------------------------------------
# Envío por email
# ---------------------------------------------------------------------------

def send_invoice_email(pdf_path: Path, data: Dict[str, Any]) -> bool:
    to_addr = (data.get('cliente_email') or '').strip()
    if not to_addr:
        print('[!] Sin email del cliente — no se envía', file=sys.stderr)
        return False

    smtp_host = os.getenv('SMTP_HOST', '')
    smtp_port = int(os.getenv('SMTP_PORT', '587') or '587')
    smtp_user = os.getenv('SMTP_USER', '')
    smtp_password = os.getenv('SMTP_PASSWORD', '')
    smtp_from = os.getenv('SMTP_FROM', smtp_user)
    smtp_from_name = os.getenv('SMTP_FROM_NAME', 'ResolveCore')

    if not smtp_host or not smtp_user or not smtp_password:
        print('[!] SMTP no configurado (SMTP_HOST/SMTP_USER/SMTP_PASSWORD)', file=sys.stderr)
        return False

    rendered = _render_email(data)
    msg = MIMEMultipart('mixed')
    msg['From'] = f'{smtp_from_name} <{smtp_from}>'
    msg['To'] = to_addr
    msg['Subject'] = rendered['subject']
    msg.attach(MIMEText(rendered['body'], 'plain', 'utf-8'))

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
        marcar_estado(data.get('numero', ''), 'enviada')
        return True
    except Exception as exc:
        print(f'[!] Error enviando email: {exc}', file=sys.stderr)
        return False


# ---------------------------------------------------------------------------
# Modo batch CSV (E)
# ---------------------------------------------------------------------------

# CSV esperado (cabecera obligatoria):
#   cliente_nombre,cliente_email,cliente_nif,ticket_id,descripcion,cantidad,precio_unitario,iva_pct,notas
# Una fila por concepto. Facturas se agrupan por (cliente_nombre + ticket_id).

def procesar_batch(csv_path: Path, do_pdf: bool, do_upload: bool, do_email: bool) -> int:
    if not csv_path.exists():
        print(f'[X] CSV no encontrado: {csv_path}', file=sys.stderr)
        return 1
    tecnico = load_tecnico()
    today = datetime.now().strftime('%Y-%m-%d')
    venc  = (datetime.now() + timedelta(days=30)).strftime('%Y-%m-%d')

    grupos: Dict[str, Dict[str, Any]] = {}
    with csv_path.open(encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            key = f'{(row.get("cliente_nombre") or "").strip()}|{(row.get("ticket_id") or "").strip()}'
            g = grupos.setdefault(key, {
                'cliente_nombre': row.get('cliente_nombre', '').strip(),
                'cliente_email':  row.get('cliente_email', '').strip(),
                'cliente_nif':    row.get('cliente_nif', '').strip(),
                'cliente_direccion': row.get('cliente_direccion', '').strip(),
                'ticket_id':      (row.get('ticket_id') or '').strip() or None,
                'items': [],
                'iva_pct': float(row.get('iva_pct') or 21),
                'notas': (row.get('notas') or '').strip(),
            })
            g['items'].append({
                'descripcion': row.get('descripcion', '').strip(),
                'cantidad': int(row.get('cantidad') or 1),
                'precio_unitario': float((row.get('precio_unitario') or '0').replace(',', '.')),
            })

    if not grupos:
        print('[!] CSV vacío o sin filas', file=sys.stderr)
        return 1

    errores = 0
    for key, g in grupos.items():
        data = {
            'numero': next_invoice_number(),
            'fecha': today,
            'fecha_vencimiento': venc,
            'tecnico_nombre': tecnico['nombre'],
            'tecnico_nif':    tecnico['nif'],
            'tecnico_email':  tecnico['email'],
            'tecnico_tel':    tecnico['tel'],
            'metodo_pago': 'Transferencia bancaria',
            **g,
            '_meta': {
                'generado_en': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
                'version_generador': SCRIPT_VERSION,
                'origen': 'batch-csv',
            },
        }
        try:
            html_path = generate_html(data)
            pdf_path = html_to_pdf(html_path) if (do_pdf or do_upload or do_email) else None
            registrar_factura(data, html_path, pdf_path)
            print(f'[✓] {data["numero"]} — {data["cliente_nombre"]} '
                  f'({_compute_total(data)["total"]:.2f} €)')
            if do_upload and pdf_path and data.get('ticket_id') and str(data['ticket_id']).isdigit():
                upload_to_mantis(pdf_path, int(data['ticket_id']))
            if do_email and pdf_path:
                send_invoice_email(pdf_path, data)
        except Exception as exc:
            print(f'[X] Error en factura {key}: {exc}', file=sys.stderr)
            errores += 1

    print('')
    print(f'Batch terminado. Facturas: {len(grupos)} — errores: {errores}')
    return 0 if errores == 0 else 2


# ---------------------------------------------------------------------------
# Carga de .env opcional
# ---------------------------------------------------------------------------

def _load_dotenv() -> None:
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
        description='ResolveCore — Generador de facturas (interactivo / batch / registro)',
    )
    p.add_argument('--datos', metavar='JSON',
                   help='Cargar datos de factura desde fichero JSON')
    p.add_argument('--out', metavar='RUTA',
                   help='Ruta de salida del HTML')
    p.add_argument('--pdf', action='store_true', help='Generar PDF además del HTML')
    p.add_argument('--upload', action='store_true', help='Subir el PDF al ticket MantisBT')
    p.add_argument('--send-email', action='store_true', help='Enviar factura al cliente')
    p.add_argument('--open', action='store_true', help='Abrir HTML en navegador')
    p.add_argument('--no-interactive', action='store_true',
                   help='No usar prompts (requiere --datos)')
    p.add_argument('--save-json', metavar='RUTA',
                   help='Guardar los datos introducidos como JSON')

    # Batch
    p.add_argument('--batch', metavar='CSV',
                   help='Procesar lote de facturas desde CSV (ver cabeceras en docstring)')

    # Registro / contabilidad
    p.add_argument('--listar', action='store_true', help='Listar facturas registradas')
    p.add_argument('--estado', metavar='ESTADO',
                   help='Filtrar --listar por estado (emitida|enviada|pagada|cancelada)')
    p.add_argument('--marcar', nargs=2, metavar=('NUMERO', 'ESTADO'),
                   help='Cambiar estado de una factura (ej: --marcar RC-2026-0001 pagada)')
    p.add_argument('--resumen', metavar='PERIODO',
                   help='Resumen de un periodo (YYYY o YYYY-MM)')

    # Email enviado manualmente desde registro (L: webhook)
    p.add_argument('--enviar-numero', metavar='NUMERO',
                   help='Reenviar factura ya emitida (busca PDF en registro)')

    return p.parse_args()


def _enviar_por_numero(numero: str) -> int:
    rows = _registry_read()
    target = next((r for r in rows if r.get('numero') == numero), None)
    if not target:
        print(f'[X] Factura {numero} no encontrada en registro', file=sys.stderr)
        return 1
    pdf = target.get('pdf')
    if not pdf or not Path(pdf).exists():
        print(f'[X] PDF no disponible para {numero}', file=sys.stderr)
        return 1
    json_path = Path(pdf).with_suffix('.json')
    if json_path.exists():
        try:
            data = json.loads(json_path.read_text(encoding='utf-8'))
        except Exception:
            data = None
    else:
        data = None
    if not data:
        data = {
            'numero': target.get('numero'),
            'cliente_nombre': target.get('cliente'),
            'cliente_email':  target.get('cliente_email'),
            'ticket_id':      target.get('ticket_id'),
            'fecha':          target.get('fecha'),
            'items': [], 'iva_pct': target.get('iva_pct', 21),
        }
    ok = send_invoice_email(Path(pdf), data)
    return 0 if ok else 1


def main() -> int:
    if sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except AttributeError:
            pass

    _load_dotenv()
    args = parse_args()

    # Acciones de registro (no requieren datos)
    if args.listar:
        listar_facturas(args.estado)
        return 0
    if args.marcar:
        numero, nuevo = args.marcar
        if marcar_estado(numero, nuevo):
            print(f'[✓] {numero} → estado={nuevo}')
            return 0
        print(f'[X] {numero} no encontrada', file=sys.stderr)
        return 1
    if args.resumen:
        resumen_periodo(args.resumen)
        return 0
    if args.enviar_numero:
        return _enviar_por_numero(args.enviar_numero)

    # Modo batch
    if args.batch:
        return procesar_batch(Path(args.batch), args.pdf, args.upload, args.send_email)

    # Origen de datos
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

    # HTML
    out_html = Path(args.out) if args.out else None
    try:
        html_path = generate_html(data, out_html)
        print(f'[✓] Factura HTML: {html_path}')
    except (FileNotFoundError, ValueError) as exc:
        print(f'[X] {exc}', file=sys.stderr)
        return 1

    # Guardar JSON al lado del HTML (necesario para --enviar-numero y webhook)
    try:
        html_path.with_suffix('.json').write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    except OSError:
        pass

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

    # Registrar en libro contable
    try:
        registrar_factura(data, html_path, pdf_path)
    except Exception as exc:
        print(f'[!] No se pudo registrar en libro: {exc}', file=sys.stderr)

    if args.upload and pdf_path:
        tk = data.get('ticket_id')
        if tk and str(tk).isdigit():
            upload_to_mantis(pdf_path, int(tk))
        else:
            print('[!] Sin ticket_id válido — no se sube a MantisBT', file=sys.stderr)

    if args.send_email and pdf_path:
        send_invoice_email(pdf_path, data)

    return 0


if __name__ == '__main__':
    sys.exit(main())
