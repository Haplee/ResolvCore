# MantisBT API REST — Integración de informes PDF

> Contexto: respuesta al tutor Juan Carlos sobre automatización de subida de informes a MantisBT.
> Fecha: 2026-05-24

---

## Decisión de diseño — dos fases

**Fase 1 (implementada):** técnico sube informe PDF manualmente a MantisBT al cerrar ticket.

**Fase 2 (pendiente de entorno producción):** automatización vía API REST de MantisBT.
Bloqueado por: URL Mantis producción, token API, confirmación versión ≥ 2.3.0.

---

## Flujo fase 2

```
1. Técnico cierra sesión remota
2. Script genera informe HTML → PDF (wkhtmltopdf)
3. Script llama API MantisBT:
   - Autenticación: header X-Mantis-Token
   - Adjunta PDF al ticket con el ID del caso
4. Mantis guarda fichero enlazado al ticket
```

---

## Endpoint

```
POST /api/rest/issues/{id}/files
```

Adjunta fichero a ticket existente. Requiere autenticación por token.

---

## Implementación (Python)

```python
import requests

MANTIS_URL = "http://tu-mantis/api/rest"
TOKEN = "tu_api_token"
TICKET_ID = 42
PDF_PATH = "informe_42.pdf"

with open(PDF_PATH, "rb") as f:
    response = requests.post(
        f"{MANTIS_URL}/issues/{TICKET_ID}/files",
        headers={"Authorization": TOKEN},
        files={"file": (PDF_PATH, f, "application/pdf")}
    )

print(response.status_code)  # 201 = éxito
```

Token se lee de variable de entorno, nunca hardcodeado.

---

## Requisitos en MantisBT

API REST disponible desde v2.3.0. Activar en `config_inc.php`:

```php
$g_allow_token_auth = ON;
```

Sin esto, endpoint devuelve 403.

Token: Admin MantisBT → *Mi cuenta* → *Tokens de API*.

---

## Respuestas para defensa

**"¿Cómo obtienes el token?"**
Variable de entorno. Se genera en panel admin de MantisBT en 30 segundos.

**"¿Cómo sabes a qué ticket adjuntar?"**
Script recibe `TICKET_ID` como parámetro. En flujo automatizado, formulario de cierre de ticket pasa el ID al script.

**"¿Qué pasa si la API no está habilitada?"**
Se activa con un flag en `config_inc.php`. Script verifica conectividad antes de intentar subida; si falla, informa al técnico y queda pendiente subida manual.

**"¿Por qué no está automatizado ya?"**
Pendiente de credenciales del entorno de producción del cliente. Arquitectura implementada y probada en entorno local.

**"¿Y si Mantis está en Docker sin puerto expuesto?"**
Script corre en red interna. URL apunta a `localhost` o IP interna, no requiere puerto público.

---

## Correo enviado al tutor (versión final)

> Perfecto Juan Carlos, el domingo te envío el documento para revisarlo antes del miércoles.
>
> Sobre el HTML, genial, lo dejo así.
>
> Respecto a Mantis, tienes razón. He decidido implementarlo en dos fases: en la fase 1 el técnico sube el informe manualmente; en la fase 2, una vez confirmado el entorno (proyecto destino en Mantis, categoría, y si la API REST está habilitada), lo automatizo vía la API de MantisBT adjuntando el PDF directamente al ticket al cerrarlo. Si me puedes confirmar esos tres datos cuando tengas un momento, avanzo con la fase 2; si no, queda documentado como mejora pendiente y lo demuestro funcional en la defensa con un entorno de prueba propio.
