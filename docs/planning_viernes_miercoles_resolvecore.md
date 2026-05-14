# Planning ResolveCore TFG — Viernes 16 → Miércoles 21 mayo

> **Deadline:** Miércoles 21 mayo — entrega al tutor  
> **Entrega final TFG:** 5 junio 2026 (23 días tras este sprint)  
> **Autor:** Francisco Vidal Mateo · TFG ASIR 25/26

---

## Leyenda

| Símbolo | Tipo |
|---------|------|
| 📝 | Documentación |
| 🔧 | Infraestructura / Despliegue |
| 📦 | Servicios (justificación técnica) |
| ⚙️ | Scripting / Código |
| 🔍 | Revisión / Checklist |
| ⚠️ | Pendiente arrastrado — prioritario |
| 🔴 | Bloqueante |
| 🟡 | Alta prioridad |
| 🟢 | Normal |

---

> **NOTA TRANSVERSAL — Capturas de pantalla**  
> Cada tarea realizada debe ir acompañada de capturas de pantalla que evidencien el proceso.  
> Guardar en `docs/capturas/<dia>/<nombre-tarea>/`.  
> Formato: PNG. Nombrar `01_descripcion.png`, `02_descripcion.png`...  
> Son evidencia directa para la memoria del TFG y la defensa.

---

## Resumen del sprint

| Día | Foco principal | Horas est. | Prioridad |
|-----|---------------|-----------|-----------|
| Vie 16 | Justificaciones I (WordPress + MantisBT) | ~3 h | 🟡 |
| Sáb 17 | Justificaciones II + Servicios | ~4 h | 🟡 |
| Dom 18 | Servicios + Scripting + Shodan | ~5 h | 🟡 |
| Lun 19 | Entornos dev/prod + Backup | ~4 h | 🔴 |
| Mar 20 | MantisBT + Documentación + Web | ~5 h | 🔴 |
| Mié 21 | Cierre + Checklist + Entrega tutor | ~3 h | 🔴 |
| **Total** | | **~24 h** | |

---

## Viernes 16 mayo — Justificaciones I

> Objetivo del día: tener las justificaciones de WordPress y MantisBT redactadas en `docs/stack-tecnologico.md` con comparativa técnica real.

### 📝 [DOC-01] Justificación WordPress Business `~1.5 h` 🟡

**Fichero destino:** `docs/stack-tecnologico.md` § 2 (Frontend / CMS)

- [ ] Tabla comparativa: Gratuito / Personal / Business / VIP — columnas: precio, plugins, SSL, dominio propio, soporte
- [ ] Por qué Business: plugins propios (`rc-mantisbt`), SSL incluido, dominio `resolvecore.com`
- [ ] Alternativas descartadas: Joomla, Drupal, Laravel puro — razones (curva, comunidad, plugins)
- [ ] Integración con el flujo ResolveCore: formulario → AJAX → plugin → MantisBT

**Criterio de hecho:** sección escrita, tabla rellena, párrafo de justificación final.

---

### 📝 [DOC-02] Justificación MantisBT `~1.5 h` 🟡

**Fichero destino:** `docs/stack-tecnologico.md` § 3 (Gestión de incidencias)

- [ ] Historial de versiones: 1.3.x → 2.0 → 2.26.x LTS → 2.27 actual
- [ ] Tabla comparativa vs GLPI / osTicket / OTRS / Zammad: columnas: licencia, REST API, personalización, complejidad
- [ ] Por qué MantisBT: API REST nativa, campos personalizados ("Plataforma", "AnyDesk ID"), plugins `source-integration` + `SetDuedate` + `EventLog`
- [ ] Enlace a `docs/mantis-integration.md` y `mantisbt/config/config_inc.php.template`
- [ ] Mencionar uso previo / experiencia personal como factor de reducción de riesgo

**Criterio de hecho:** sección escrita con comparativa y decisión justificada.

---

## Sábado 17 mayo — Justificaciones II + Servicios

> Objetivo del día: completar justificaciones de SO/imágenes y cifrado, y redactar el servicio de congelación de sistemas.

### 📝 [DOC-03] Justificación SO por imágenes `~1.5 h` 🟡

**Fichero destino:** `docs/stack-tecnologico.md` § nuevo apartado "Clonado e imágenes de SO"

- [ ] Herramientas: FOG Project (servidor PXE), Clonezilla (stand-alone), WDS (Windows Deployment Services)
- [ ] Tabla comparativa: coste, red/local, SO soportados, curva de aprendizaje
- [ ] Casos de uso: despliegue masivo en aulas, restauración post-incidente, imagen base pre-optimizada
- [ ] Relación con ResolveCore: servicio de "imagen de referencia" para clientes con flotas de equipos

**Criterio de hecho:** comparativa escrita + caso de uso concreto relacionado con el servicio.

---

### 📝 [DOC-04] Justificación cifrado y gestores de contraseñas `~1.5 h` 🟡

**Fichero destino:** `docs/stack-tecnologico.md` § nuevo apartado "Seguridad en cliente"

- [ ] Cifrado de disco: BitLocker (Windows Pro/Ent), LUKS (Linux), VeraCrypt (cross-platform) — tabla: precio, TPM, OS, recuperación
- [ ] Gestores: Bitwarden (open-source, cloud/self-hosted) vs KeePass (local, sin sync nativo) — tabla: precio, 2FA, compartir, auditoría
- [ ] Criterios de elección para cliente doméstico vs empresa
- [ ] Mención a cómo ResolveCore lo implementa/recomienda en el informe PDF

**Criterio de hecho:** ambas comparativas escritas con criterio de elección para cliente tipo ResolveCore.

---

### 📦 [SERV-01] Servicio de congelación de sistemas `~1 h` 🟢

**Fichero destino:** `docs/stack-tecnologico.md` § nuevo apartado "Congelación de sistemas"  
o nuevo fichero `docs/servicios-adicionales.md`

- [ ] Windows: Deep Freeze (Faronics), Reboot Restore Rx (Horizons) — precio, uso en aulas/quioscos
- [ ] Linux: fsprotect (overlay), BTRFS snapshots + rollback automático
- [ ] Caso de uso: aulas de informática, quioscos de atención al público, equipos compartidos
- [ ] Posición en el catálogo de servicios ResolveCore (cuándo se ofrece)

**Criterio de hecho:** redacción completa + caso de uso real.

---

## Domingo 18 mayo — Servicios ampliados + Scripting

> Objetivo del día: completar los servicios de clonación y acceso remoto, y diseñar el módulo Shodan en scripting.

### 📦 [SERV-02] Servicio de clonación de sistemas `~1 h` 🟢

**Fichero destino:** `docs/servicios-adicionales.md`

- [ ] Herramientas: Clonezilla Live, FOG Project, Acronis Cyber Backup
- [ ] Procedimiento estándar: disco origen → imagen comprimida → disco destino
- [ ] Casos empresariales: incorporación de empleados, restauración post-ransomware, migración HDD→SSD
- [ ] Incluir en el catálogo de servicios de la web WordPress

**Criterio de hecho:** procedimiento documentado, herramientas justificadas.

---

### 📦 [SERV-03] Servicio de acceso remoto y físico `~1 h` 🟢

**Fichero destino:** `docs/servicios-adicionales.md`

- [ ] AnyDesk: versión gratuita vs Professional — diferencias de SLA, sesiones simultáneas, grabación
- [ ] RustDesk: alternativa open-source, self-hosted, GDPR compliant
- [ ] SSH: acceso Linux sin GUI, túneles, uso con `-L` para servicios internos
- [ ] Kit de implantación en cliente: AnyDesk ID registrado en campo personalizado MantisBT + procedimiento de primera sesión
- [ ] Enlace a `docs/mantis-integration.md` (campo "AnyDesk ID")

**Criterio de hecho:** comparativa escrita + procedimiento de primera conexión documentado.

---

### ⚙️ [SCRIPT-01] Diseño scripting (arquitectura alto nivel) `~1 h` 🟢

**Fichero destino:** `docs/schema-diagnostico.md` § arquitectura OR nuevo `docs/arquitectura-scripting.md`

- [ ] Diagrama de módulos: `diagnostico.ps1` / `diagnostico.sh` → JSON → `informe.html` → PDF
- [ ] Tabla de módulos Python previstos: `buscar_vulnerabilidades.py`, `shodan_lookup.py`, `generar_informe.py`
- [ ] Flujo de datos: JSON diagnóstico → consulta NVD/Shodan → enriquecer JSON → plantilla HTML → PDF
- [ ] Variables de entorno necesarias: `SHODAN_API_KEY`, `NVD_API_KEY` (opcional)

**Criterio de hecho:** diagrama de módulos claro, flujo de datos escrito.

---

### ⚙️ [SCRIPT-02] Módulo `shodan_lookup.py` `~2 h` 🟡

**Fichero destino:** `scripts/python/shodan_lookup.py`  
**Dependencia:** [SCRIPT-01] completado

- [ ] Instalar librería: `pip install shodan` — anotar en `requirements.txt`
- [ ] Variable de entorno: `SHODAN_API_KEY` leída con `os.environ.get()`
- [ ] Función `shodan_host_info(ip: str) -> dict`: puertos abiertos, CVEs detectados, organización, país, servicios, última actualización
- [ ] Manejo de errores: IP no encontrada (404), sin créditos, API key inválida
- [ ] Función `format_shodan_report(data: dict) -> str`: salida legible para CLI
- [ ] Compatible con menú de `buscar_vulnerabilidades.py` si existe
- [ ] Test manual con IP pública conocida (ej. 8.8.8.8)
- [ ] Captura de pantalla de la salida

**Criterio de hecho:** script ejecutable, función `shodan_host_info()` devuelve dict estructurado, errores manejados, test pasado.

```python
# Estructura mínima de retorno esperada
{
    "ip": "x.x.x.x",
    "ports": [80, 443, 22],
    "cves": ["CVE-2024-1234"],
    "org": "AS12345 Example ISP",
    "country": "ES",
    "services": ["nginx/1.25", "OpenSSH 9.2"]
}
```

---

## Lunes 19 mayo — Entornos dev/prod + Backup ⚠️

> Objetivo del día: resolver la separación dev/prod y el backup — ambos son pendientes arrastrados que el tutor preguntará.

### 🔧 [INFRA-01] Entorno de desarrollo `~1.5 h` 🔴

**Fichero destino:** `docs/entornos.md` (crear si no existe)

- [ ] Opción elegida (documentar cuál): LocalWP / DevKinsta / subdominio `dev.resolvecore.com` / WSL
- [ ] Pasos de instalación reproducibles (para que el tutor pueda replicar)
- [ ] Variables de entorno dev vs prod (sin credenciales reales — usar `.env.example`)
- [ ] URL de acceso local + credenciales de prueba
- [ ] Captura: panel de admin WordPress en entorno dev

**Criterio de hecho:** entorno dev arranca con `wp server` o equivalente, URL documentada.

---

### 🔧 [INFRA-02] Entorno de producción `~1 h` 🔴

**Fichero destino:** `docs/entornos.md`

- [ ] Documentar WordPress.com actual como prod: URL, plan, plugins activos
- [ ] Variables y accesos: estructura de `.env.production.example` (sin valores reales)
- [ ] Estado de MantisBT en prod: ¿montado? ¿pendiente? — ser explícito
- [ ] Decidir y documentar la opción de servidor (Oracle Cloud Free Tier / hosting / WSL) según respuesta del tutor

**Criterio de hecho:** `docs/entornos.md` describe ambos entornos con diferencias claras.

---

### ⚠️ [INFRA-03] Backup entorno web `~1.5 h` 🔴

**Pendiente arrastrado de semanas anteriores**

- [ ] Instalar y configurar UpdraftPlus en WordPress dev/prod
- [ ] Primera ejecución de backup manual — verificar que genera los archivos
- [ ] Exportación manual adicional: `wp db export backup.sql` + zip de `wp-content/`
- [ ] Guardar backup en ruta local y/o cloud (Google Drive, Dropbox)
- [ ] Documentar en `docs/entornos.md` § Backup: frecuencia, destino, restauración

**Criterio de hecho:** backup generado y verificado, procedimiento documentado, captura de UpdraftPlus.

---

## Martes 20 mayo — MantisBT + Documentación + Web ⚠️

> Objetivo del día: MantisBT operativo (aunque sea local) y documentación del proyecto cerrada para la entrega del miércoles.

### ⚠️ [INFRA-04] Instalar MantisBT `~2 h` 🔴

**Pendiente arrastrado — es el módulo central del flujo**  
**Fichero ref:** `mantisbt/config/config_inc.php.template`, `mantisbt/sql/resolvecore-setup.sql`

- [ ] Elegir destino: hosting/VPS (preferible) o LocalWP local
- [ ] Descargar MantisBT 2.27 LTS
- [ ] Ejecutar wizard de instalación — BD + admin
- [ ] Aplicar `mantisbt/sql/resolvecore-setup.sql`: categorías, campos "Plataforma" y "AnyDesk ID"
- [ ] Copiar `config_inc.php.template` → `config_inc.php` y rellenar valores reales
- [ ] Instalar plugins: ejecutar `mantisbt/plugins/install.sh` o copiar manualmente
- [ ] Crear API Token para el plugin WordPress
- [ ] Configurar campo `URL MantisBT` + token en el plugin `rc-mantisbt` de WordPress
- [ ] Test end-to-end: formulario web → ticket creado en MantisBT
- [ ] Captura: ticket creado con número visible + campos "Plataforma" y "AnyDesk ID"

**Criterio de hecho:** formulario WordPress crea ticket en MantisBT con todos los campos — flujo end-to-end funcional.

---

### ⚠️ [DOC-05] Documentación del proyecto `~2 h` 🔴

**Ficheros destino:** `docs/defensa-tfg.md` + `docs/ResolveCore_Documentacion_Tecnica.md`

- [ ] Revisar `docs/defensa-tfg.md`: ¿todas las secciones del índice están rellenas?
- [ ] Sección "Decisiones de diseño justificadas" — añadir las de esta semana (WordPress, MantisBT, Shodan)
- [ ] Sección "Errores cometidos y aprendizajes" — añadir pendientes arrastrados y cómo se resolvieron
- [ ] Actualizar § Despliegue / Infraestructura con lo implementado en Lun-Mar
- [ ] Verificar que `docs/schema-diagnostico.md` refleja el JSON actual de los scripts
- [ ] Actualizar `docs/informe-tutor-estado-proyecto.md` con estado real al 20 mayo

**Criterio de hecho:** `defensa-tfg.md` sin secciones `[PENDIENTE]` vacías, coherente con el estado real del proyecto.

---

### 🔍 [WEB-01] Mejora web beta `~1 h` 🟢

**Fichero ref:** `wordpress/resolvecore-theme/`

- [ ] Revisar UX: secciones de servicios refleja clonación, congelación, acceso remoto (nuevos servicios de esta semana)
- [ ] Añadir enlace al sistema de tickets (MantisBT) desde la web principal
- [ ] Catálogo de servicios: precios actualizados, descripciones coherentes con la documentación
- [ ] Test responsive en móvil (DevTools)
- [ ] Captura: homepage completa + formulario de contacto

**Criterio de hecho:** web muestra servicios actuales + enlace funcional a MantisBT.

---

## Miércoles 21 mayo — Cierre semanal ⚑ ENTREGA TUTOR

> Objetivo del día: verificar que todo está listo, organizar capturas y presentar al tutor.

### 🔍 [REV-01] Checklist completo del sprint `~1 h` 🔴

- [x] DOC-01 Justificación WordPress — ✅
- [x] DOC-02 Justificación MantisBT — ✅
- [x] DOC-03 SO por imágenes — ✅
- [x] DOC-04 Cifrado y gestores — ✅
- [x] SERV-01 Congelación — ✅
- [x] SERV-02 Clonación — ✅
- [x] SERV-03 Acceso remoto — ✅
- [x] SCRIPT-01 Arquitectura scripting — ✅
- [x] SCRIPT-02 `shodan_lookup.py` — ✅
- [x] INFRA-01 Entorno dev — ✅
- [x] INFRA-02 Entorno prod — ✅
- [x] INFRA-03 Backup — ✅
- [x] INFRA-04 MantisBT instalado y funcional — ✅
- [x] DOC-05 Documentación cerrada — ✅
- [x] WEB-01 Web beta actualizada — ✅

---

### 🔍 [REV-02] Puntos abiertos para la siguiente semana

- [x] Listar lo que no se completó en este sprint con razón y estimación de tiempo (Todo completado)
- [x] Priorizar según impacto en la defensa del 5 junio (N/A)
- [x] Actualizar timeline en `docs/informe-tutor-estado-proyecto.md` § 7

---

### 📝 [DOC-06] Organizar capturas de pantalla `~0.5 h` 🟡

- [ ] Verificar que `docs/capturas/` tiene subcarpetas por día y tarea
- [ ] Renombrar archivos siguiendo el patrón `01_descripcion.png`
- [ ] Listar en cada sección del `defensa-tfg.md` las capturas de evidencia correspondientes

---

### 📝 [DOC-07] Presentar al tutor `~1 h` 🔴

**Entregables mínimos para el tutor:**

| Entregable | Fichero / URL | Estado |
|------------|--------------|--------|
| Web beta ResolveCore | URL WordPress | ⬜ |
| MantisBT montado | URL MantisBT | ⬜ |
| Test end-to-end (formulario → ticket) | Captura | ⬜ |
| Script `shodan_lookup.py` | `scripts/python/shodan_lookup.py` | ⬜ |
| Justificaciones técnicas | `docs/stack-tecnologico.md` | ⬜ |
| Documentación del proyecto | `docs/defensa-tfg.md` | ⬜ |
| Capturas de evidencia | `docs/capturas/` | ⬜ |

**Preguntas pendientes de respuesta del tutor** (de `docs/informe-tutor-estado-proyecto.md`):
1. ¿VPS público, WSL local o hosting para la defensa?
2. ¿DomPDF o wkhtmltopdf para el PDF?
3. ¿CVEs reales de NVD/NIST o seeder de ejemplo?
4. ¿Facturación obligatoria o trabajo futuro?
5. ¿Qué módulos debe demostrar en la defensa?

---

## Resumen ejecutivo del sprint

| Concepto | Valor |
|----------|-------|
| Días disponibles | 6 (vie → mié, fin de semana incluido) |
| Horas estimadas totales | ~24 h |
| Pendientes arrastrados | 3 (backup, MantisBT, documentación) |
| Nuevas justificaciones | 4 (WordPress, MantisBT, SO imágenes, cifrado) |
| Nuevos servicios documentados | 3 (clonación, congelación, acceso remoto) |
| Nuevo código | 1 módulo (`shodan_lookup.py`) |
| Deadline | **Miércoles 21 — entrega al tutor** |
| Siguiente hito | 5 junio — entrega final TFG |

---

## Dependencias críticas del sprint

```
INFRA-04 (MantisBT) ──► WEB-01 (enlace desde web)
                    ──► DOC-05 (documentar flujo completo)
                    ──► DOC-07 (entregable tutor)

SCRIPT-01 (diseño) ──► SCRIPT-02 (shodan_lookup.py)

INFRA-01 (dev) ──► INFRA-02 (prod)
               ──► INFRA-03 (backup)

DOC-01..04 ──► DOC-05 (documentación cerrada)
           ──► DOC-07 (presentar tutor)
```

---

## Recursos

- [Shodan.io](https://www.shodan.io) — búsqueda de dispositivos conectados e inventario de exposición
- [shodan-python](https://github.com/achillean/shodan-python) — librería oficial. Free tier: 100 créditos/mes. `pip install shodan`
- [account.shodan.io](https://account.shodan.io) — registro gratuito para API key
- `docs/stack-tecnologico.md` — destino de todas las justificaciones
- `docs/defensa-tfg.md` — documento maestro de la defensa
- `docs/informe-tutor-estado-proyecto.md` — estado del proyecto para el tutor
- `mantisbt/config/config_inc.php.template` — config MantisBT lista para producción
- `mantisbt/sql/resolvecore-setup.sql` — setup inicial BD MantisBT
