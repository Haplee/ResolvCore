# -*- coding: utf-8 -*-
"""Port: destino de adjuntos para tickets MantisBT.

Contrato para subir un fichero a un ticket existente. Implementacion actual:
mantis_rest.MantisRestSink (API REST oficial /api/rest/issues/{id}/files).
"""

from pathlib import Path
from typing import Protocol, runtime_checkable

from ..domain import AttachmentResult


@runtime_checkable
class MantisAttachmentSink(Protocol):
    """Adjunta un fichero a un ticket MantisBT.

    Nunca lanza excepcion — devuelve AttachmentResult con ok=False si falla.
    """

    def attach(self, ticket_id: int, file_path: Path) -> AttachmentResult:
        ...
