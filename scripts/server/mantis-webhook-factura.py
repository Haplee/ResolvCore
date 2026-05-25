#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ResolveCore - mantis-webhook-factura.py
Webhook receptor: cuando MantisBT marca un ticket como 'resolved' envía la
factura emitida asociada al cliente por email.

Diseño (stdlib only, sin Flask/Django):
    - Escucha en HTTP (default 0.0.0.0:8765).
    - Espera POST JSON: {"ticket_id": 42, "status": "resolved", "token": "<secret>"}
    - Verifica WEBHOOK_TOKEN contra .env (defensa contra triggers externos).
    - Busca en ~/.resolvecore/facturas.jsonl la factura más reciente con ese
      ticket_id (estado != 'enviada' / != 'pagada').
    - Lanza `generar_factura.py --enviar-numero <NUMERO>` que reutiliza el PDF
      ya generado y el JSON sidecar para reenviar.

Configuración en .env:
    WEBHOOK_TOKEN=<cadena-secreta-larga>
    WEBHOOK_PORT=8765            (opcional)
    WEBHOOK_HOST=0.0.0.0          (opcional)

Uso:
    # Lanzar como servicio (en VPS):
    python3 scripts/server/mantis-webhook-factura.py

    # Como systemd unit (production): ver docs/tecnica/webhook-factura.md

MantisBT no envía webhooks nativos en todas las versiones; usar:
    - Plugin "Webhook" (https://github.com/mantisbt-plugins/Webhook) o
    - Hook custom: en mantisbt/plugins/Resolvecore/Resolvecore.php registrar
      EVENT_BUG_RESOLVED y hacer POST con curl.

Autor: Francisco Vidal Mateo (Haplee) - TFG ASIR ResolveCore
"""

import json
import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_GENERATOR = _REPO / 'scripts' / 'common' / 'generar_factura.py'
_REGISTRO = Path.home() / '.resolvecore' / 'facturas.jsonl'


def _load_dotenv() -> None:
    for p in (Path.home() / '.resolvecore' / '.env', _REPO / '.env'):
        if not p.exists():
            continue
        try:
            for line in p.read_text(encoding='utf-8').splitlines():
                line = line.strip()
                if not line or line.startswith('#') or '=' not in line:
                    continue
                k, _, v = line.partition('=')
                k, v = k.strip(), v.strip().strip('"').strip("'")
                if k and k not in os.environ:
                    os.environ[k] = v
        except OSError:
            pass


def _find_invoice_for_ticket(ticket_id: str):
    if not _REGISTRO.exists():
        return None
    candidates = []
    for line in _REGISTRO.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            r = json.loads(line)
        except json.JSONDecodeError:
            continue
        if str(r.get('ticket_id') or '') == str(ticket_id):
            candidates.append(r)
    if not candidates:
        return None
    pending = [r for r in candidates if r.get('estado') not in ('enviada', 'pagada')]
    return (pending or candidates)[-1]


def _trigger_send(numero: str) -> tuple:
    cmd = [sys.executable, str(_GENERATOR), '--enviar-numero', numero]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        return res.returncode, (res.stdout or '') + (res.stderr or '')
    except Exception as exc:
        return 99, str(exc)


class Handler(BaseHTTPRequestHandler):

    def _respond(self, code: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        sys.stderr.write(f'[webhook] {self.address_string()} - {fmt % args}\n')

    def do_GET(self):
        if self.path == '/health':
            self._respond(200, {'status': 'ok', 'service': 'mantis-webhook-factura'})
            return
        self._respond(404, {'error': 'not found'})

    def do_POST(self):
        expected = os.getenv('WEBHOOK_TOKEN', '')
        if not expected:
            self._respond(503, {'error': 'WEBHOOK_TOKEN no configurado en .env'})
            return
        length = int(self.headers.get('Content-Length') or 0)
        if length <= 0 or length > 65536:
            self._respond(400, {'error': 'payload vacío o demasiado grande'})
            return
        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw.decode('utf-8'))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            self._respond(400, {'error': f'JSON inválido: {exc}'})
            return

        token = payload.get('token') or self.headers.get('X-Resolvecore-Token', '')
        if token != expected:
            self._respond(401, {'error': 'token inválido'})
            return

        ticket_id = payload.get('ticket_id') or payload.get('issue_id')
        status = (payload.get('status') or '').lower()
        if not ticket_id:
            self._respond(400, {'error': 'falta ticket_id'})
            return
        if status not in ('resolved', 'closed', 'finalizado', 'resuelto'):
            self._respond(202, {'skipped': True, 'reason': f'estado={status} no dispara envío'})
            return

        inv = _find_invoice_for_ticket(ticket_id)
        if not inv:
            self._respond(404, {'error': f'sin factura emitida para ticket #{ticket_id}'})
            return

        rc, output = _trigger_send(inv['numero'])
        if rc == 0:
            self._respond(200, {'sent': True, 'numero': inv['numero'],
                                'cliente': inv.get('cliente_email')})
        else:
            self._respond(500, {'sent': False, 'numero': inv['numero'],
                                'exit': rc, 'output': output[:500]})


def main() -> int:
    _load_dotenv()
    host = os.getenv('WEBHOOK_HOST', '0.0.0.0')
    port = int(os.getenv('WEBHOOK_PORT', '8765'))
    if not os.getenv('WEBHOOK_TOKEN'):
        print('[!] WEBHOOK_TOKEN no definido en .env — el servicio arrancará pero rechazará POSTs.',
              file=sys.stderr)
    print(f'[✓] ResolveCore webhook escuchando en http://{host}:{port}')
    print(f'    health-check: GET /health')
    print(f'    trigger:      POST /  body {{ticket_id, status, token}}')
    try:
        HTTPServer((host, port), Handler).serve_forever()
    except KeyboardInterrupt:
        print('\n[i] Webhook detenido.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
