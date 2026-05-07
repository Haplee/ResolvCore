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

## Apéndice — Glosario técnico

### ¿Qué es un VPS?

**VPS** (*Virtual Private Server*, servidor privado virtual) es una máquina virtual con
recursos dedicados (CPU, RAM, disco, IP pública) que se aloja sobre un servidor físico
compartido por varios clientes mediante un hipervisor (KVM, Xen, VMware). A diferencia
del hosting compartido, ofrece:

- Acceso `root` / SSH completo.
- Sistema operativo a elegir (Ubuntu, Debian, AlmaLinux…).
- IP pública fija y puertos arbitrarios.
- Aislamiento real frente a otros tenants.

Frente a un servidor dedicado físico, el VPS es más barato y escalable; frente a la nube
gestionada (PaaS), exige administrar el SO pero da control total.

### ¿Es necesario un VPS en ResolveCore?

**Sí, para el despliegue final del TFG.** Lo justifica la propia arquitectura del proyecto:

| Componente | Requisito | ¿Hosting compartido? | ¿VPS? |
|------------|-----------|----------------------|-------|
| WordPress (frontend soporte) | PHP-FPM + MariaDB | Sí | Sí |
| MantisBT (REST API + cron) | PHP + cron + acceso a BD | Limitado | Sí |
| Plugin `rc-mantisbt` (llamadas REST internas) | URLs internas accesibles | No fiable | Sí |
| Generador PDF (wkhtmltopdf o DomPDF) | Binario/sistema instalable | No (wkhtmltopdf) | Sí |
| Sincronización CVE/NVD (cron semanal) | `cron` de sistema, salida a internet | No | Sí |
| AnyDesk + scripts diagnóstico | Ejecución del lado del cliente | N/A | N/A |

Resumen: cualquier módulo que requiera **cron de sistema, binarios externos
(wkhtmltopdf), o llamadas REST entre WordPress y MantisBT en el mismo host** descarta
el hosting compartido. Un VPS es la opción mínima viable.

### Opciones evaluadas para el TFG

1. **Oracle Cloud Free Tier (VM Ampere ARM, 4 vCPU / 24 GB RAM gratis indefinido).**
   Pros: coste 0 €, IP pública, recursos sobrados. Contras: alta inicial estricta, ARM
   exige paquetes compatibles.
2. **VPS de pago económico (Hetzner CX11, Contabo VPS S, OVH VPS Starter — 4–7 €/mes).**
   Pros: x86_64 estándar, sin restricciones. Contras: coste mensual.
3. **WSL/DevKinsta local.** Solo para desarrollo y pruebas; no sirve para defensa con URL
   pública.

> **Pregunta abierta al tutor (Bloque A):** ¿se exige URL pública en defensa o basta con
> demo local? La respuesta determina si el VPS es obligatorio o opcional para la entrega.

---

*Última actualización: 7 de mayo de 2026*
