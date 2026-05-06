# Anotaciones de Tutoría — ResolveCore TFG ASIR

**Alumno:** Francisco Vidal Mateo  
**Repo:** https://github.com/Haplee/ResolveCore  
**Informe de estado completo:** [`docs/informe-tutor-estado-proyecto.md`](informe-tutor-estado-proyecto.md)

---

## Tutoría 1 — Pendiente de fijar fecha

### Bloque A: MantisBT (PRIORITARIO)

**Contexto para el tutor:**  
MantisBT es el gestor de incidencias del sistema. El formulario de contacto web (WordPress) crea automáticamente un ticket en MantisBT mediante su REST API. El plugin `rc-mantisbt` ya está desarrollado. El problema actual es que todo está en local y no hay servidor donde probarlo de extremo a extremo.

**Preguntas:**

- [ ] ¿Es suficiente demostrar la integración WordPress → MantisBT en local (WSL o DevKinsta) durante la defensa, o necesita ser accesible desde una URL pública?
- [ ] ¿Qué servidor recomienda para el despliegue? Opciones evaluadas:
  - Oracle Cloud Free Tier (VM Ampere, gratis indefinidamente, IP pública)
  - Hosting compartido (limitado, sin SSH completo)
  - WSL local (no accesible externamente)
- [ ] ¿Qué plugins de MantisBT son relevantes para el TFG? Los instalados son: `source-integration`, `MantisKanban`, `SetDuedate`, `Reminder`, `mailtemplate`, `EventLog`. ¿Es suficiente documentarlos o hay que demostrar todos?
- [ ] El campo personalizado "AnyDesk ID" en MantisBT — ¿se valora que esté integrado o es suficiente mencionarlo?

**Respuestas del tutor:**  
_[escribir aquí]_

---

### Bloque B: Generación de informes PDF

**Contexto:**  
Los scripts de diagnóstico generan un JSON estructurado. La fase de informe PDF convierte ese JSON en HTML y luego a PDF, que se adjunta al ticket al cerrar la incidencia. Ya existe `scripts/informe.html` como prototipo visual.

**Preguntas:**

- [ ] ¿DomPDF (PHP puro, sin dependencias del sistema) o wkhtmltopdf (mejor fidelidad HTML/CSS, requiere instalación en el servidor)?
- [ ] ¿La generación automática del PDF al cerrar el ticket en MantisBT es obligatoria para la nota, o es suficiente con la generación manual desde un script?
- [ ] ¿Qué secciones del informe son prioritarias para la defensa? Las previstas son: resumen ejecutivo, incidencias detectadas, problemas solucionados, estado actual del sistema, recomendaciones, proyección de vida útil.

**Respuestas del tutor:**  
_[escribir aquí]_

---

### Bloque C: Base de datos de vulnerabilidades (CVE/NVD)

**Contexto:**  
La tabla `rc_vulnerabilities` almacena CVEs para que los scripts de diagnóstico puedan alertar sobre software vulnerable. La sincronización se haría con la API pública de NVD/NIST.

**Preguntas:**

- [ ] ¿La tabla debe estar poblada con CVEs reales (requiere llamadas a la API de NVD) o es suficiente un seeder con datos de ejemplo para demostrar el mecanismo?
- [ ] ¿La sincronización automática (cron semanal) debe estar funcionando o basta con el script documentado?
- [ ] ¿Cuántos CVEs mínimos en la BD para que sea una demo convincente?

**Respuestas del tutor:**  
_[escribir aquí]_

---

### Bloque D: Módulo de facturación

**Contexto:**  
Previsto como pago por servicio (factura al cerrar ticket) y suscripción mensual (cron). Conceptualmente definido pero no implementado.

**Preguntas:**

- [ ] ¿Este módulo es necesario para la calificación o puede quedar como trabajo futuro documentado?
- [ ] Si es necesario: ¿qué nivel de implementación mínima se espera? ¿Generar una factura en PDF es suficiente?

**Respuestas del tutor:**  
_[escribir aquí]_

---

### Bloque E: Memoria TFG escrita

- [ ] ¿Hay plantilla oficial de la institución para la memoria?
- [ ] ¿Qué extensión mínima/máxima se pide?
- [ ] ¿La memoria incluye capturas de pantalla del sistema funcionando, o solo texto y diagramas?
- [ ] ¿El diagrama de flujo del sistema (7 fases) es suficiente o se requiere UML formal (casos de uso, secuencia, etc.)?

**Respuestas del tutor:**  
_[escribir aquí]_

---

### Bloque F: Defensa / demo

- [ ] ¿Se defiende en vivo con demo o con presentación + vídeo?
- [ ] ¿Qué módulos deben estar funcionando en la defensa como mínimo?
- [ ] ¿Hay tiempo límite para la exposición?

**Respuestas del tutor:**  
_[escribir aquí]_

---

## Acuerdos y próximos pasos

| # | Acción | Responsable | Fecha límite |
|---|--------|-------------|--------------|
| 1 | _[completar tras tutoría]_ | | |
| 2 | | | |
| 3 | | | |

---

## Próxima tutoría

**Fecha:** _[pendiente]_  
**Modalidad:** _[presencial / Teams / email]_  
**Temas a revisar:** _[pendiente]_

---

*Última actualización: 6 de mayo de 2026*
