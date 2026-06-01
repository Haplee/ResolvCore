# -*- coding: utf-8 -*-
"""Port: fuente de vulnerabilidades CVE.

Un "port" aquí es solo un contrato escrito: describe qué función debe
ofrecer cualquier adapter de vulnerabilidades, sin usar clases.

CONTRATO VulnSource
-------------------
El adapter debe exponer una función:

    get_vulns(product: str, version: str) -> list[dict]

- Devuelve lista de vulnerabilidades (dicts creados con
  domain.nueva_vulnerabilidad) para ese product/version.
- Nunca lanza excepción: devuelve lista vacía si falla o no hay datos.

Implementación actual: adapters/nvd_rest.py (get_vulns).
Permite testear con un get_vulns falso sin red.
"""
