# -*- coding: utf-8 -*-
"""Adapter: implementa MantisAttachmentSink sobre API REST de MantisBT.

Endpoint: POST /api/rest/issues/{id}/files
Auth: header Authorization con token de usuario (Admin -> Mi cuenta -> Tokens).
Requiere $g_allow_token_auth = ON en config_inc.php de Mantis (v2.3.0+).

Politica: stdlib only — multipart/form-data construido a mano para no depender
de `requests` ni urllib3.
"""

import mimetypes
import os
import urllib.error
import urllib.request
import uuid
from pathlib import Path

from ..domain import AttachmentResult
from ..ports.mantis_attachment_sink import MantisAttachmentSink

USER_AGENT = "ResolveCore-MantisAdapter/1.0.0"
HTTP_TIMEOUT = 20


class MantisRestSink(MantisAttachmentSink):
    """Sube ficheros a un ticket MantisBT via API REST."""

    def __init__(self, base_url: str, token: str, timeout: int = HTTP_TIMEOUT) -> None:
        if not base_url:
            raise ValueError("base_url vacio")
        if not token:
            raise ValueError("token vacio")
        self._base = base_url.rstrip("/")
        self._token = token
        self._timeout = timeout

    @classmethod
    def from_env(cls) -> "MantisRestSink":
        """Construye desde MANTIS_URL + MANTIS_TOKEN (variables de entorno)."""
        url = os.environ.get("MANTIS_URL", "").strip()
        token = os.environ.get("MANTIS_TOKEN", "").strip()
        if not url or not token:
            raise RuntimeError("MANTIS_URL y MANTIS_TOKEN requeridos en entorno")
        return cls(url, token)

    def attach(self, ticket_id: int, file_path: Path) -> AttachmentResult:
        file_path = Path(file_path)
        if not file_path.is_file():
            return AttachmentResult(
                ok=False, ticket_id=ticket_id, file_name=str(file_path),
                error=f"fichero no existe: {file_path}",
            )

        url = f"{self._base}/api/rest/issues/{ticket_id}/files"
        mime = mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
        boundary = f"----ResolveCore{uuid.uuid4().hex}"

        try:
            body = self._build_multipart(boundary, file_path, mime)
        except OSError as exc:
            return AttachmentResult(
                ok=False, ticket_id=ticket_id, file_name=file_path.name,
                error=f"lectura fichero falla: {exc}",
            )

        req = urllib.request.Request(
            url,
            data=body,
            method="POST",
            headers={
                "Authorization": self._token,
                "Content-Type": f"multipart/form-data; boundary={boundary}",
                "User-Agent": USER_AGENT,
            },
        )

        try:
            with urllib.request.urlopen(req, timeout=self._timeout) as resp:
                return AttachmentResult(
                    ok=200 <= resp.status < 300,
                    ticket_id=ticket_id,
                    file_name=file_path.name,
                    status_code=resp.status,
                )
        except urllib.error.HTTPError as exc:
            return AttachmentResult(
                ok=False, ticket_id=ticket_id, file_name=file_path.name,
                status_code=exc.code, error=f"HTTP {exc.code}: {exc.reason}",
            )
        except urllib.error.URLError as exc:
            return AttachmentResult(
                ok=False, ticket_id=ticket_id, file_name=file_path.name,
                error=f"red: {exc.reason}",
            )

    @staticmethod
    def _build_multipart(boundary: str, file_path: Path, mime: str) -> bytes:
        with open(file_path, "rb") as fh:
            content = fh.read()
        crlf = b"\r\n"
        b = boundary.encode()
        return (
            b"--" + b + crlf
            + f'Content-Disposition: form-data; name="files[]"; filename="{file_path.name}"'.encode() + crlf
            + f"Content-Type: {mime}".encode() + crlf + crlf
            + content + crlf
            + b"--" + b + b"--" + crlf
        )
