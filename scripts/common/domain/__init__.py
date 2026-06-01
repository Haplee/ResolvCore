"""Capa de dominio: entidades y reglas de negocio puras.

No importa de adapters/ ni ports/. Sin IO, sin red, sin filesystem.
Testeable sin fixtures externos.
"""

from .models import AttachmentResult, Host, Service, Vulnerability

__all__ = ["AttachmentResult", "Host", "Service", "Vulnerability"]
