# -*- coding: utf-8 -*-
"""Port: fuente de inventario de software instalado.

Un "port" aqui es solo un contrato escrito: describe que funcion debe ofrecer
cualquier adapter de inventario, sin usar clases.

CONTRATO InventorySource
------------------------
El adapter debe exponer una funcion:

    get_software(plataforma, serial=None, maximo=0) -> list[dict]

- Devuelve una lista de paquetes/programas instalados. Cada elemento es un dict:
      {"nombre": str, "version": str, "origen": str}
  donde "origen" indica de donde salio (dpkg, rpm, registro, adb...).
- "plataforma" es uno de: "linux", "windows", "android".
- "serial" solo se usa en android (dispositivo ADB concreto); en el resto se ignora.
- "maximo" limita cuantos paquetes se devuelven (0 = sin limite). Sirve para no
  saturar el rate limit de las APIs de CVE.
- Nunca lanza excepcion: si algo falla devuelve lista vacia.

Implementacion actual: adapters/inventario_local.py (get_software).
Permite testear con un get_software falso sin tocar el sistema.
"""
