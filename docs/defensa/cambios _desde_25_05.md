# Fase 4 — Sistema de facturación electrónica

> **Fecha**: 2026-05-25
> **Autor**: Francisco Vidal Mateo (Haplee) — TFG ASIR ResolveCore
> **Rama**: `feat/facturacion-clonacion-congelacion`

---

## 1. Objetivo

Cerrar el ciclo del servicio técnico (solicitud → conexión remota → diagnóstico
→ resolución → informe → **facturación → entrega al cliente**) sin que el
técnico tenga que salir de la TUI principal ni copiar datos manualmente.

La factura es ficticia (TFG no constituye actividad económica real), pero el
flujo replica el de un autónomo informático: emisión, registro contable,
adjunto al ticket, envío al cliente y trazabilidad del estado.

---

## 2. Componentes nuevos

| Fichero | LOC | Función |
|---|---:|---|
| `scripts/common/generar_factura.py` v1.1.0 | ~620 | CLI interactivo + batch + registro contable |
| `reports/factura.html` | ~150 | Plantilla HTML/PDF (tabla conceptos, IVA, totales) |
| `scripts/server/mantis-webhook-factura.py` | ~150 | Servicio HTTP receptor de webhooks MantisBT |

Total: ~920 líneas de Python + HTML, sin dependencias `pip` (política
**stdlib-only**: `smtplib`, `email.mime`, `http.server`, `csv`, `json`,
`webbrowser`, `subprocess`).

---

## 3. Funcionalidades

### 3.1 Persistencia de configuración del técnico

Directorio `~/.resolvecore/`:

| Fichero | Contenido | Uso |
|---|---|---|
| `tecnico.json` | nombre, NIF, email, teléfono del emisor | Pre-rellena prompts |
| `servicios.json` | Catálogo de 8 servicios típicos con precios | Selección rápida por nº/código |
| `contador.json` | `{ "2026": 12, ... }` | Numeración automática `RC-YYYY-NNNN` |
| `facturas.jsonl` | Libro contable append-only | Estado por factura: emitida / enviada / pagada |
| `email-template.txt` | Plantilla con placeholders | Personalización del cuerpo del email |
| `.env` | `MANTIS_*`, `SMTP_*`, `WEBHOOK_TOKEN` | Credenciales fuera de git |

Catálogo por defecto (sembrado al primer uso):

```
DIAG    Diagnóstico remoto AnyDesk (1h)        35,00 €
OPTIM   Optimización del sistema               45,00 €
MALW    Limpieza de malware                    60,00 €
CVE     Revisión vulnerabilidades + parches    50,00 €
BACKUP  Configuración de copia de seguridad    40,00 €
CLON    Clonación / restauración de equipo     80,00 €
INSTALL Instalación/configuración de software  30,00 €
HORA    Hora adicional de soporte técnico      30,00 €
```

### 3.2 Modos de operación

#### Interactivo

```bash
python3 scripts/common/generar_factura.py --pdf --upload --send-email --open
```

Prompts:
- Datos generales (número auto, fechas, ticket Mantis).
- Técnico (reutilizado desde `tecnico.json`).
- Cliente (nombre, NIF, email, dirección).
- Conceptos: por número de catálogo / código / descripción libre.
- IVA, método de pago, notas.

#### Desde JSON

```bash
python3 scripts/common/generar_factura.py --datos factura.json --no-interactive --pdf
```

Reproducible y útil para tests / CI.

#### Lote (CSV)

```bash
python3 scripts/common/generar_factura.py --batch facturas-mayo.csv --pdf --send-email
```

CSV con cabecera:

```
cliente_nombre,cliente_email,cliente_nif,cliente_direccion,ticket_id,
descripcion,cantidad,precio_unitario,iva_pct,notas
```

Filas se agrupan por `(cliente_nombre + ticket_id)`, una factura por grupo.
Pensado para cierre de mes.

#### Registro contable

```bash
# Listar todas
python3 scripts/common/generar_factura.py --listar

# Filtrar
python3 scripts/common/generar_factura.py --listar --estado pagada

# Cambiar estado
python3 scripts/common/generar_factura.py --marcar RC-2026-0001 pagada

# Resumen periodo
python3 scripts/common/generar_factura.py --resumen 2026-05
```

Salida del resumen:

```
Resumen 2026-05
----------------------------------------
  Facturas:        12
    pagadas:       8
    pendientes:    4
  Base imponible:    1.240,00 €
  IVA repercutido:     260,40 €
  TOTAL facturado:   1.500,40 €
```

### 3.3 Integraciones

| Integración | Mecanismo |
|---|---|
| MantisBT (adjuntar) | Reutiliza `adjuntar_informe_mantis.py` (API REST con `MANTIS_TOKEN`) |
| Email cliente | `smtplib` + STARTTLS + PDF adjunto MIME multipart |
| Webhook auto-envío | HTTP listener en `:8765`, token compartido, dispara reenvío al cerrar ticket |
| TUI técnico | Nueva opción `[FACTURA]` en `ResolveCore.{ps1,sh}` (Windows/Linux/macOS) |

### 3.4 Webhook MantisBT → envío automático

Arquitectura:

```
MantisBT (VPS)
    │ EVENT_BUG_RESOLVED
    ▼
plugin Webhook (HTTP POST)
    │ body: {"ticket_id":42, "status":"resolved", "token":"<secret>"}
    ▼
mantis-webhook-factura.py (0.0.0.0:8765)
    │ valida WEBHOOK_TOKEN
    │ busca factura en facturas.jsonl con ese ticket_id
    ▼
generar_factura.py --enviar-numero RC-2026-NNNN
    │ reutiliza PDF + JSON sidecar
    ▼
SMTP → cliente
```

Endpoints:
- `GET /health` → `{"status":"ok"}` (probe systemd / monitor)
- `POST /` → JSON body, requiere token en body o header `X-Resolvecore-Token`

### 3.5 Identidad visual

Favicon corporativo (logo ResolveCore SVG) embebido en base64 dentro del
`<head>` de `factura.html` e `informe.html`. Autocontenido: funciona offline,
en PDF y sin servidor web.

---

## 4. Correcciones técnicas en esta iteración

### 4.1 Bug de unidades en diagnóstico Windows

`Win32_OperatingSystem.FreePhysicalMemory` devuelve **KB**, no bytes.
Conversión `/1MB` (1.048.576) reportaba "Memoria libre: 2 MB" cuando el real
era 2.128 MB.

**Fix** (`scripts/windows/diagnostico.ps1` líneas 243-244, 261-262):

```powershell
# Antes
[math]::Round($os.FreePhysicalMemory / 1MB, 0)
# Después
[math]::Round($os.FreePhysicalMemory / 1024, 0)
```

### 4.2 `datetime.utcnow()` deprecated en Python 3.12+

Sustituido por timezone-aware:

```python
datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
```

---

## 5. Decisiones de arquitectura

| Decisión | Justificación |
|---|---|
| **stdlib-only** (sin pip) | Reproducibilidad y portabilidad. Técnico no necesita `pip install` en cada equipo. |
| **JSON sidecar** junto a HTML/PDF | Permite al webhook reenviar la factura sin re-prompts. |
| **JSONL append-only** como libro contable | Legible humano + sin SQLite + sin race conditions en append. |
| **Token compartido** para webhook | Suficiente para tráfico VPS↔MantisBT en red privada. Sin secretos en URL. |
| **wkhtmltopdf** (no DomPDF) | Mejor soporte JS para renderizar tabla y totales. LGPL. |
| **Embebido base64 del favicon** | Funciona en HTML aislado y dentro de PDFs sin servidor web. |

---

## 6. Flujo cerrado del técnico (golden path)

```
1. Cliente → ticket WP/MantisBT          (Fase 1: solicitud)
2. Técnico ↔ cliente vía AnyDesk         (Fase 2: conexión remota)
3. ResolveCore opción 1: diagnóstico     (Fase 3: análisis)
4. ResolveCore opción 2-3: optimización  (Fase 4: resolución)
5. ResolveCore opción 4: informe PDF     (Fase 5: documentación)
6. ResolveCore opción 5: FACTURA         (Fase 6: cobro)  ← NUEVO
   ├─ HTML + PDF en scripts/diagnosticos/
   ├─ Registro en ~/.resolvecore/facturas.jsonl
   ├─ Adjunto en ticket MantisBT
   └─ Email al cliente
7. Técnico marca ticket "resolved"       (Fase 7: cierre)
   └─ Webhook reenvía automáticamente
```

---

## 7. Mejoras futuras planificadas

| Código | Mejora | Esfuerzo |
|---|---|---|
| **J** | QR Bizum/IBAN en factura (concepto + importe) | Bajo (lib `segno` o `qrcode`) |
| **I** | Retención IRPF 15% / 7% (autónomos España) | Bajo |
| **M** | Validación NIF español (regex + letra control) | Bajo |
| **N** | Exportación Facturae 3.2.x (XML AEAT) | Medio — bonus académico |
| **H** | Plantilla configurable: logo cliente, color, IBAN, cláusula RGPD | Medio |
| Auto-pdf-merge | Adjuntar informe técnico + factura en un único PDF | Medio |

---

## 8. Métricas de la sesión

| Métrica | Valor |
|---|---:|
| Ficheros nuevos | 3 |
| Ficheros modificados | 6 (TUI x3, setup técnico x2, diagnostico.ps1) |
| LOC añadidas | ~1.000 |
| Software FOSS integrado | AnyDesk¹, Clonezilla (GPL), BTRFS+snapper (GPL), Reboot Restore Rx Free, wkhtmltopdf (LGPL), MantisBT (GPL) |
| Plataformas soportadas | Windows 10/11, Ubuntu/Fedora, macOS, Android (ADB) |
| Dependencias `pip` nuevas | 0 |

¹ AnyDesk es freeware no FOSS; mantiene el modelo de despliegue rápido sin pago.

---

## 9. Pruebas realizadas (2026-05-25)

| Test | Estado | Notas |
|---|---|---|
| Diagnóstico Windows opción 1 | OK | HTML + JSON generados en `scripts/diagnosticos/` |
| Informe HTML opción 4 | OK | Apertura en navegador funciona |
| PDF informe wkhtmltopdf | OK | PDF generado correctamente |
| Adjuntar a Mantis ticket #8 | Pendiente | `.env` sin `MANTIS_TOKEN` (esperado) |
| Factura interactiva opción 5 | OK | Catálogo y persistencia técnico funcionan |
| Factura PDF wkhtmltopdf | OK | PDF correcto, totales calculados |
| Envío SMTP | Pendiente | `.env` sin `SMTP_PASSWORD` (esperado) |
| Webhook health-check | No ejecutado | Pendiente despliegue VPS |

---

## 10. Referencias en el repositorio

- Plantilla email: `~/.resolvecore/email-template.txt` (auto-generada al primer envío).
- Esquema JSON factura: ver docstring de `build_invoice_data_interactive()` en `generar_factura.py`.
- Variables de entorno: `.env.example` en la raíz del repo.
- Documentación de despliegue webhook (systemd unit): pendiente en
  `docs/tecnica/webhook-factura.md`.

---

**Fin del documento de Fase 4.**

---

# Fase 5 — Servicios adicionales + Portal de técnicos

> **Fecha**: 2026-05-25 (sesión tarde)
> **Autor**: Francisco Vidal Mateo (Haplee) — TFG ASIR ResolveCore
> **Rama**: `feat/facturacion-clonacion-congelacion`

---

## 1. Objetivo

Implementar los tres servicios adicionales del catálogo ResolveCore con scripts
totalmente autónomos (cero intervención manual del técnico) e integrarlos en el
menú principal y en un portal web de descarga.

---

## 2. Componentes nuevos / modificados

### 2.1 Scripts de servicios (implementados desde stubs)

| Fichero | Plataforma | Estado anterior | Estado actual |
|---|---|---|---|
| `scripts/servicios/congelacion/congelacion-windows.ps1` | Windows | Stub | Implementado |
| `scripts/servicios/congelacion/congelacion-linux.sh` | Linux | Stub | Implementado |
| `scripts/servicios/clonacion/registrar-imagen.sh` | Multiplataforma | Stub | Implementado |
| `scripts/servicios/clonacion/verificar-imagen.sh` | Multiplataforma | Stub | Implementado |
| `scripts/servicios/kit/construir-kit.ps1` | Windows | Stub | Implementado |

### 2.2 Integración en launchers

| Fichero | Cambio |
|---|---|
| `scripts/windows/ResolveCore.ps1` | Nueva opción 6 `[SERVICIOS]` (antes 6=Ayuda, 7=Salir → ahora 7 y 8) |
| `scripts/linux/ResolveCore.sh` | Nueva opción 6 `[SERVICIOS]` (mismo desplazamiento) |

### 2.3 Auto-install y bootstraps

| Fichero | Función |
|---|---|
| `scripts/servicios/install.ps1` | Bootstrap Windows: instala Chocolatey + WSL + jq + AnyDesk + RRRx |
| `scripts/servicios/install.sh` | Bootstrap Linux: instala jq + curl + btrfs-progs + snapper |

### 2.4 Portal web técnicos

| Fichero | Función |
|---|---|
| `wordpress/resolvecore-theme/page-tecnicos.php` | Página WP "Área de Técnicos" con tabs Windows/Linux/Kit + botones descarga |
| `wordpress/resolvecore-theme/functions.php` | Handler `rc_handle_technician_download()` — sirve ficheros con auth WP |
| `scripts/server/setup-downloads-dir.sh` | Setup VPS: crea `/opt/resolvecore-downloads/`, htpasswd, nginx conf |

### 2.5 Documentación

| Fichero | Cambio |
|---|---|
| `docs/scripting/schema-servicios-adicionales.md` | Nuevo: esquemas JSON de congelación y manifiesto de clonación |
| `docs/INDEX.md` | Añadida entrada `schema-servicios-adicionales.md` |
| `docs/defensa/defensa-tfg.md` | Sección 15b añadida, O11–O13 marcados ✅, changelog 2026-05-25 |
| `scripts/servicios/README.md` | Stubs → Implementado, referencia a schemas |

---

## 3. Funcionalidades implementadas

### 3.1 Congelación Windows (`congelacion-windows.ps1`)

- Auto-detecta Reboot Restore Rx Free / Deep Freeze instalados
- Si no hay ninguno: descarga e instala RRRx Free silenciosamente (`/S`)
- Acciones: `Status` · `Configure` · `Freeze -Confirm` · `Thaw -Confirm`
- `-Ticket <id>` crea nota automática en MantisBT al Freeze/Thaw
- Salida `[PSCustomObject]` → JSON por stdout

### 3.2 Congelación Linux (`congelacion-linux.sh`)

- Auto-instala `jq`, `btrfs-progs`, `snapper` (apt/dnf/pacman)
- Acciones: `status` · `configure` (root) · `snapshot` · `rollback --confirm` (root)
- Fix B2: `rollback` verifica que existe ≥1 snapshot antes de ejecutar
- `--ticket <id>` crea nota en MantisBT al snapshot/rollback
- JSON por stdout; integración MantisBT vía `curl`

### 3.3 Clonación — registrar-imagen.sh

- Auto-instala `jq` si falta (apt/dnf/pacman/brew)
- Calcula SHA-256 de fichero o árbol de carpeta Clonezilla (hash determinista)
- Fix B4: escritura atómica del manifiesto (`.tmp.XXXXXX` → `jq empty` → `mv`)
- `--ticket <id>` crea nota en MantisBT con hash + id de imagen

### 3.4 Clonación — verificar-imagen.sh

- Auto-instala `jq` si falta
- Fix B3: conversión ruta con `readlink -f` / `realpath` (antes frágil con caracteres especiales)
- Busca entrada en manifiesto por ruta o por `--id`
- `--ticket <id>` crea nota OK/CORRUPTA en MantisBT

### 3.5 Kit de implantación (`construir-kit.ps1`)

- Auto-descarga AnyDesk portable desde `download.anydesk.com` si no se proporciona
- Fix B1: scripts diagnóstico faltantes → `exit 1` (antes `Write-Warn` y continuaba generando ZIP incompleto)
- MANIFEST.txt con checksums SHA256 de todos los ficheros del kit
- `resolvecore-kit.zip` listo para enviar al cliente

### 3.6 Integración en menús TUI

Submenú `[SERVICIOS]` en ambos launchers:

**Windows (opción 6):**
- Congelación → Status / Configure / Freeze / Thaw
- Clonación → Registrar / Verificar (vía WSL o Git Bash; auto-detecta)
- Kit cliente → construir-kit.ps1 interactivo

**Linux (opción 6):**
- Congelación → status / configure / snapshot / rollback
- Clonación → Registrar / Verificar

### 3.7 Portal web de descarga

Página WP `/tecnicos/` visible solo para usuarios con rol `editor`/`administrator`:

- **Tab Windows**: one-liner para copiar + botón verde "Descargar install-servicios.ps1" + pasos + tabla deps
- **Tab Linux**: one-liner + botón "Descargar install-servicios.sh" + pasos + tabla deps
- **Tab Kit cliente**: botón "Descargar resolvecore-kit.zip" + instrucciones de entrega

Handler PHP en `functions.php`:
- Whitelist estricta de ficheros descargables (`windows|linux|kit|rrrx`)
- Requiere login WP + rol técnico (no pública)
- Log de descarga: usuario + IP + timestamp en error_log WP
- Bloquea path traversal

---

## 4. Bugs corregidos

| ID | Fichero | Descripción |
|---|---|---|
| B1 | `construir-kit.ps1` | Scripts diagnóstico faltantes → ZIP incompleto sin avisar |
| B2 | `congelacion-linux.sh` | `rollback` sin snapshot previo retornaba éxito sin hacer nada |
| B3 | `verificar-imagen.sh` | Conversión ruta relativa→absoluta fallaba con caracteres especiales |
| B4 | `registrar-imagen.sh` | `mv` fallido perdía el manifiesto original (no era atómico) |

---

## 5. Arquitectura de auto-install (flujo técnico)

```
Técnico abre resolvecore.website/tecnicos/
    │ (login WP requerido, rol editor/admin)
    ▼
Página WP muestra botones por plataforma
    │ clic en botón
    ▼
functions.php rc_handle_technician_download()
    │ verifica rol → sirve fichero desde /opt/resolvecore-downloads/
    ▼
Técnico ejecuta install.ps1 / install.sh
    │ instala todo automáticamente
    ▼
.\ResolveCore.ps1  →  opción 6 SERVICIOS  →  submenú
    │ cada script se auto-instala si le faltan deps
    ▼
--ticket <id>  →  nota automática en MantisBT
```

---

## 6. Métricas de la sesión

| Métrica | Valor |
|---|---:|
| Ficheros nuevos | 7 (`install.ps1`, `install.sh`, `page-tecnicos.php`, `setup-downloads-dir.sh`, `schema-servicios-adicionales.md`) |
| Ficheros modificados | 10 (`congelacion-*.ps1/.sh`, `registrar-imagen.sh`, `verificar-imagen.sh`, `construir-kit.ps1`, `ResolveCore.ps1`, `ResolveCore.sh`, `functions.php`, `defensa-tfg.md`, `INDEX.md`) |
| Bugs corregidos | 4 (B1–B4) |
| Objetivos TFG completados | O11, O12, O13 → ✅ |
| Deps auto-instaladas | Windows: Chocolatey, WSL, jq, AnyDesk, RRRx · Linux: jq, curl, btrfs-progs, snapper |

---

**Fin del documento de Fase 5.**
