# -*- coding: utf-8 -*-
"""Port: destino de adjuntos para tickets MantisBT.

Contrato escrito (sin clases) para subir un fichero a un ticket existente.

CONTRATO MantisAttachmentSink
-----------------------------
El adapter debe exponer una función:

    attach(ticket_id: int, file_path: Path) -> dict

- Devuelve un resultado (dict creado con domain.nuevo_attachment_result).
- Nunca lanza excepción: devuelve el dict con ok=False si falla.

Implementación: _archivo/common/adapters/mantis_rest.py (archivada).
"""
