# -*- coding: utf-8 -*-
"""Adapter: sube ficheros a un ticket MantisBT via API REST (sin clases).

Cumple el contrato del port ports/mantis_attachment_sink.py:

    attach(ticket_id, file_path) -> dict   (creado con domain.nuevo_attachment_result)

Endpoint: POST /api/rest/issues/{id}/files
Auth: header Authorization con token de usuario (Admin -> Mi cuenta -> Tokens).
Requiere $g_allow_token_auth = ON en config_inc.php de Mantis (v2.3.0+).

Politica: stdlib only — multipart/form-data construido a mano para no depender
de `requests` ni urllib3.

Autor:   Francisco Vidal Mateo (GitHub: Haplee)
Versión: 2.0
"""

import mimetypes
import os
import ssl
import urllib.error
import urllib.request
import uuid
from pathlib import Path

from ..domain import nuevo_attachment_result

USER_AGENT = "ResolveCore-MantisAdapter/2.0.0"
HTTP_TIMEOUT = 20


def config_desde_entorno():
    """Lee MANTIS_URL y MANTIS_TOKEN del entorno.

    Devuelve un dict {"url", "token"}. Lanza RuntimeError si falta alguno.
    """
    url = os.environ.get("MANTIS_URL", "").strip()
    token = os.environ.get("MANTIS_TOKEN", "").strip()
    if not url or not token:
        raise RuntimeError("MANTIS_URL y MANTIS_TOKEN requeridos en entorno")
    return {"url": url.rstrip("/"), "token": token}


def _construir_multipart(boundary, file_path, mime):
    with open(file_path, "rb") as fh:
        content = fh.read()
    crlf = b"\r\n"
    b = boundary.encode()
    return (
        b"--" + b + crlf
        + ('Content-Disposition: form-data; name="files[]"; filename="'
           + file_path.name + '"').encode() + crlf
        + ("Content-Type: " + mime).encode() + crlf + crlf
        + content + crlf
        + b"--" + b + b"--" + crlf
    )


def attach(ticket_id, file_path, config=None, timeout=HTTP_TIMEOUT):
    """Sube file_path al ticket MantisBT indicado.

    config: dict {"url", "token"}. Si es None, se lee del entorno.
    Devuelve siempre un dict (domain.nuevo_attachment_result); nunca lanza.
    """
    file_path = Path(file_path)
    if not file_path.is_file():
        return nuevo_attachment_result(
            False, ticket_id, str(file_path),
            error="fichero no existe: " + str(file_path),
        )

    if config is None:
        try:
            config = config_desde_entorno()
        except RuntimeError as exc:
            return nuevo_attachment_result(
                False, ticket_id, file_path.name, error=str(exc))

    base = config["url"].rstrip("/")
    token = config["token"]
    url = base + "/api/rest/issues/" + str(ticket_id) + "/files"
    mime = mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
    boundary = "----ResolveCore" + uuid.uuid4().hex

    try:
        body = _construir_multipart(boundary, file_path, mime)
    except OSError as exc:
        return nuevo_attachment_result(
            False, ticket_id, file_path.name,
            error="lectura fichero falla: " + str(exc))

    req = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            # MantisBT espera el token CRUDO en Authorization (su
            # ApiTokenAuthentication NO usa prefijo). Añadir "Bearer "/"Token "
            # provoca 401: por eso va sin prefijo a propósito. Si un proxy
            # inverso elimina la cabecera Authorization, configúralo para
            # preservarla (nginx: underscores_in_headers / pasar $http_authorization).
            "Authorization": token,
            "Content-Type": "multipart/form-data; boundary=" + boundary,
            "User-Agent": USER_AGENT,
        },
    )

    # Contexto SSL explícito (coherente con nvd_rest/osv_rest). Si MANTIS_URL es
    # https y el sistema no tiene las CA raíz (Docker/CI minimal), la verificación
    # falla; lo detectamos aparte para dar un error claro al técnico.
    ctx = ssl.create_default_context()

    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            return nuevo_attachment_result(
                200 <= resp.status < 300, ticket_id, file_path.name,
                status_code=resp.status)
    except urllib.error.HTTPError as exc:
        return nuevo_attachment_result(
            False, ticket_id, file_path.name,
            status_code=exc.code, error="HTTP " + str(exc.code) + ": " + str(exc.reason))
    except ssl.SSLError as exc:
        return nuevo_attachment_result(
            False, ticket_id, file_path.name,
            error="SSL (¿faltan certificados CA raíz en el sistema?): " + str(exc))
    except urllib.error.URLError as exc:
        # URLError envuelve también los errores de verificación de certificado.
        if isinstance(exc.reason, ssl.SSLError):
            return nuevo_attachment_result(
                False, ticket_id, file_path.name,
                error="SSL (¿faltan certificados CA raíz en el sistema?): " + str(exc.reason))
        return nuevo_attachment_result(
            False, ticket_id, file_path.name, error="red: " + str(exc.reason))
