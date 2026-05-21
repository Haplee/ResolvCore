# ResolveCore — Índice de Documentación

**TFG ASIR 2024/25 · Francisco Vidal Mateo**  
Última actualización: 21 de mayo de 2026

---

## defensa/ — Tribunal y tutor

| Fichero | Descripción |
|---------|-------------|
| [defensa-tfg.md](defensa/defensa-tfg.md) | Documento maestro de defensa: FAQs del tribunal, decisiones justificadas, errores y aprendizajes |
| [informe-tutor-estado-proyecto.md](defensa/informe-tutor-estado-proyecto.md) | Estado del proyecto al 20/05 para entrega al tutor |
| [origen-componentes.md](defensa/origen-componentes.md) | Autoría de cada componente: software de terceros, código propio, uso de IA |
| [planning_viernes_miercoles_resolvecore.md](defensa/planning_viernes_miercoles_resolvecore.md) | Sprint 16–21 mayo: tareas, criterios de hecho, checklist |
| [anotaciones-tutor.md](defensa/anotaciones-tutor.md) | Notas y feedback del tutor TFG |
| [punto-de-partida-ante-proyecto.md](defensa/punto-de-partida-ante-proyecto.md) | Contexto inicial del proyecto antes de empezar |
| [defensa-scripts-mantis.md](defensa/defensa-scripts-mantis.md) | Preparación defensa: scripts + MantisBT |
| [estudio-tribunal-scripts.md](defensa/estudio-tribunal-scripts.md) | Estudio de posibles preguntas del tribunal sobre scripting |
| [auditoria-mejoras.md](defensa/auditoria-mejoras.md) | Auditoría de mejoras aplicadas al proyecto |

---

## tecnica/ — Documentación del sistema

| Fichero | Descripción |
|---------|-------------|
| [ResolveCore_Documentacion_Tecnica.md](tecnica/ResolveCore_Documentacion_Tecnica.md) | Documentación técnica completa del proyecto |
| [stack-tecnologico.md](tecnica/stack-tecnologico.md) | Justificación del stack: WordPress, MantisBT, AnyDesk, herramientas |
| [entornos.md](tecnica/entornos.md) | Entornos dev (LocalWP) y prod (WordPress.com + VPS) + política de backup |
| [flujo-sistema.md](tecnica/flujo-sistema.md) | Diagrama del flujo completo: formulario → ticket → diagnóstico → informe |
| [mantis-integration.md](tecnica/mantis-integration.md) | Integración WordPress ↔ MantisBT vía REST API |
| [manual-usuario-mantis.md](tecnica/manual-usuario-mantis.md) | Manual técnico de configuración, BD, workflow y permisos de MantisBT |
| [mantis-permisos.md](tecnica/mantis-permisos.md) | Matriz de permisos por capacidad y rol — configuración de seguridad de MantisBT |
| [despliegue-ionos.md](tecnica/despliegue-ionos.md) | Despliegue producción en VPS Ionos Linux S: WP + Mantis + Let's Encrypt en mismo VPS (2,50 €/mes) |
| [servicios-adicionales.md](tecnica/servicios-adicionales.md) | Clonación, congelación, acceso remoto, cifrado, despliegue por imágenes |
| [tutorial-wordpress-manual.md](tecnica/tutorial-wordpress-manual.md) | Tutorial de instalación y configuración manual de WordPress |
| [so-especializado.md](tecnica/so-especializado.md) | Sistemas operativos especializados y su relación con ResolveCore |

---

## scripting/ — Arquitectura y esquemas de scripts

| Fichero | Descripción |
|---------|-------------|
| [arquitectura-scripting.md](scripting/arquitectura-scripting.md) | Diagrama de módulos: diagnóstico → JSON → informe → PDF |
| [schema-diagnostico.md](scripting/schema-diagnostico.md) | Esquema JSON de diagnóstico unificado (Windows/Linux/macOS/Android) |
| [schema-diagnostico.schema.json](scripting/schema-diagnostico.schema.json) | JSON Schema formal para validación |
| [schema-vulnerabilidades.md](scripting/schema-vulnerabilidades.md) | Esquema de la base de datos de vulnerabilidades |
| [regex-y-json-diagnostico.md](scripting/regex-y-json-diagnostico.md) | Patrones regex y técnicas de parsing JSON en los scripts |

---

## capturas/ — Evidencias del sprint

| Carpeta | Contenido |
|---------|-----------|
| [lun19-entornos-backup/](capturas/lun19-entornos-backup/) | Instalación LocalWP, creación entorno dev WordPress (16 capturas) |
| [mar20-mantisbt-web/](capturas/mar20-mantisbt-web/) | MantisBT operativo, API token, test end-to-end formulario→ticket, backup (9 capturas) |

---

## Documentos raíz relacionados

| Fichero | Descripción |
|---------|-------------|
| `../README.md` | Instalación del entorno local y comandos esenciales |
| `../.claude/CLAUDE.md` | Instrucciones para Claude Code (convenciones, arquitectura) |
| `../reports/informe.html` | Plantilla HTML del informe técnico generado por los scripts |
