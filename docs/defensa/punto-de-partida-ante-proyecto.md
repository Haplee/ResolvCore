# Anteproyecto y Punto de Partida — ResolveCore

Este documento constituye la propuesta inicial de Trabajo Fin de Grado (TFG) para el Ciclo Formativo de Grado Superior en **Administración de Sistemas Informáticos en Red (ASIR)**. En él se definen las bases, objetivos y el alcance conceptual del ecosistema de mantenimiento y soporte proactivo ResolveCore.

---

## Ficha del Proyecto

* **Centro Educativo:** I.E.S. Trafalgar (Barbate, Cádiz)
* **Ciclo:** Ciclo Formativo de Grado Superior en Administración de Sistemas Informáticos en Red (ASIR)
* **Curso Académico:** 2025 / 2026
* **Proyecto:** ResolveCore — Plataforma de mantenimiento y optimización remota para Windows, Linux y Android
* **Eslogan:** *"Solución a tus problemas informáticos"*
* **Alumno:** Francisco Vidal Mateo
* **Tutor Académico:** Juan Carlos Jiménez Hernández

---

## 1. Punto de partida

Esta propuesta marca el inicio del desarrollo del TFG. El propósito principal es asentar las bases del sistema, evaluar la viabilidad de la arquitectura propuesta y definir una hoja de ruta estructurada. A estas alturas del desarrollo, ciertas decisiones técnicas finales están supeditadas a pruebas de rendimiento en entornos reales de laboratorio.

La concepción del proyecto surge a partir de una problemática común en la microempresa y el sector doméstico: el soporte técnico informático tradicional es puramente **reactivo**. Por lo general, se espera a que la infraestructura quede inoperativa para solicitar asistencia. Este enfoque ocasiona periodos de inactividad críticos, cobros imprevistos por intervenciones de urgencia y una carencia absoluta de trazabilidad sobre las tareas de mantenimiento realizadas.

**ResolveCore** propone un cambio de paradigma hacia el soporte **proactivo y automatizado**. En lugar de resolver fallos de manera presencial e individualizada, se plantea un sistema capaz de:
1. Realizar diagnósticos de salud automáticos en los sistemas finales de los usuarios.
2. Registrar un histórico detallado e inmutable de cada acción correctora sobre la máquina.
3. Facilitar un informe técnico en formato PDF para el cliente final, promoviendo la total transparencia del servicio.

---

## 2. Idea del proyecto

**ResolveCore** es una plataforma de soporte y mantenimiento remoto de extremo a extremo, especialmente dimensionada para autónomos, pequeñas empresas (PYMEs) y usuarios domésticos sin departamento de IT dedicado.

El ecosistema descansa sobre tres pilares arquitectónicos:
* **Diagnóstico Automatizado Multiplataforma:** Un núcleo de scripts ligeros que se ejecutan localmente en la máquina del cliente (Windows, Linux y Android) capturando el estado del hardware, red, servicios críticos y seguridad en una salida estructurada JSON común.
* **Motor de Auditoría de Vulnerabilidades:** Módulo en Python que cruza el inventario de software recogido en el diagnóstico con múltiples repositorios públicos y APIs de seguridad de gran relevancia (NVD del NIST, CISA KEV, Google OSV y métricas de probabilidad de explotación EPSS).
* **Gestión Centralizada y Reporting:** Un canal web público (WordPress) con un formulario de contacto seguro conectado de forma asíncrona a un gestor de incidencias (MantisBT via REST API). Tras la resolución del ticket por parte del técnico, se adjunta un reporte en PDF de alto nivel generado automáticamente.

---

## 3. Por qué este proyecto

La elección del proyecto responde a dos motivaciones principales:

1. **Multidisciplinariedad y Cobertura Curricular:** ASIR es un grado con un perfil profesional extremadamente transversal. ResolveCore abarca competencias clave de la totalidad de los módulos del ciclo formativo:
   * **Sistemas Operativos:** Administración e interactuación interna a bajo nivel con sistemas Windows (PowerShell 7), Linux (Bash) y Android (Android Debug Bridge - ADB).
   * **Bases de Datos:** Persistencia estructural e histórica en MariaDB/MySQL.
   * **Servicios de Red y Aplicaciones Web:** Despliegue de servidores Nginx, PHP-FPM, contenedores Docker y pasarelas AJAX asíncronas en WordPress.
   * **Seguridad y Alta Disponibilidad:** Implementación de cifrado SSL/TLS con Let's Encrypt, hardening del CMS, rate-limiting, saneamiento de entradas ante ataques XSS/SQLi y auditoría CVE.
2. **Viabilidad de Negocio y Continuidad:** Más allá de los fines puramente académicos del TFG, el proyecto se concibe como una alternativa real de emprendimiento técnico, ofreciendo un modelo de suscripción competitivo de mantenimiento informático corporativo para autónomos y pequeñas empresas.

---

## 4. Objetivos

### 4.1. Objetivo general

Construir y desplegar un entorno de soporte informático proactivo completo que unifique la recepción de tickets a través de una web segura, el diagnóstico automatizado remoto de las plataformas de cliente (Windows, Linux, Android), el análisis inteligente de vulnerabilidades locales y la entrega automatizada de informes de resolución.

### 4.2. Objetivos específicos

* **Scripts de Diagnóstico Nativos:**
  * PowerShell 7 para la obtención de métricas y estados del kernel en entornos Windows.
  * Bash estructurado y optimizado para sistemas GNU/Linux.
  * Captura de métricas internas en Android aprovechando comandos directos de la shell de ADB.
* **Modelo de Datos Unificado:** Definición de un esquema JSON común e interoperable que consolide los inventarios de los tres entornos de sistemas.
* **Mapeador CVE Multi-feed:** Implementación de un motor robusto en Python sin dependencias externas pesadas que realice la extracción y priorización de vulnerabilidades explotadas.
* **Middleware WordPress - MantisBT:** Desarrollo de un plugin corporativo en PHP que sirva de puente asíncrono entre el frontend y la base de incidencias MantisBT aprovechando sus APIs REST nativas.
* **Interfaz de Usuario de Alto Rendimiento:** Programación de un tema a medida para el CMS enfocado en rendimiento (puntuación Lighthouse ≥ 90) y cumplimiento riguroso de accesibilidad WCAG 2.1 nivel AA.
* **Generación de Reportes Dinámicos:** Módulo compilador que transforme la salida estructurada de los diagnósticos a plantillas PDF estandarizadas.
* **Despliegue e Infraestructura:** Configuración y securización de la infraestructura completa en un VPS Linux de producción real bajo el stack Nginx, PHP-FPM, MariaDB y certificados automatizados Let's Encrypt.

### 4.3. Límites del proyecto (Fuera de alcance)

Para asegurar la viabilidad del TFG dentro de los plazos académicos establecidos, se excluyen los siguientes aspectos:
* **Aplicación móvil Android nativa:** El soporte a dispositivos Android se limita al motor interno ADB operado desde consola de técnico o Termux. Una app nativa queda relegada al roadmap futuro.
* **Soporte completo para macOS:** Se mantiene una estructura básica funcional (stub) a nivel demostrativo de comandos nativos de BSD, posponiendo un desarrollo completo de mantenimiento.
* **Integración fiscal Verifactu / AEAT:** La generación de facturación final será simulada en el PDF de cierre, sin implementar la conexión telemática con las agencias tributarias.
* **Modelos predictivos por Machine Learning:** Los avisos por degradación o fallos inminentes se calculan a través de heurísticas estables basadas en los parámetros SMART de almacenamiento y la vida útil estimada del hardware.

---

## 5. Tecnologías previstas

| Capa / Módulo | Tecnología de Elección | Justificación Técnica |
|---------------|-------------------------|------------------------|
| **Presentación y Frontend** | WordPress 6.x + Tema Custom | CMS de rápida implantación y fácil escalabilidad con un tema optimizado desde cero. |
| **Gestión de Soporte** | MantisBT 2.27+ LTS | Gestor de incidencias ligero con una API REST madura y consumo de recursos mínimo en contenedores. |
| **Base de Datos** | MariaDB 10.6+ / MySQL | Cumplimiento del estándar relacional con alta compatibilidad y rendimiento de lectura. |
| **Diagnóstico Windows** | PowerShell 7 (novedades del SDK) | Acceso al motor WMI, CIM y llamadas de administración del sistema nativas de Microsoft. |
| **Diagnóstico Linux** | Bash 4+ | Scripting de sistema universal, sin dependencias e integrable en cualquier shell POSIX. |
| **Diagnóstico Android** | Bash + ADB / Termux | Extracción de telemetría sin requerir root en el terminal cliente. |
| **Auditoría de Seguridad** | Python 3.8+ (Stdlib) | Máxima portabilidad. Sin dependencias externas de librerías de terceros (`pip`) para auditorías limpias. |
| **Acceso Remoto** | AnyDesk / RustDesk | Conexiones seguras supervisadas y cifradas. |
| **Compilador PDF** | DomPDF / wkhtmltopdf | Conversión de HTML semántico enriquecido a hojas de estilo PDF imprimibles. |

> [!NOTE]
> Uno de los principios fundamentales de diseño del proyecto es la **exclusión de plataformas de pago cerradas** (como Snyk, Nessus o Qualys) para el análisis local de seguridad. Toda la lógica del TFG se basa en APIs de acceso público y bases de datos libres, permitiendo la total reproducibilidad y despliegue del entorno sin costes de licenciamiento.

---

## 6. Gestión de riesgos y contingencias

| Riesgo Detectado | Impacto | Estrategia de Mitigación |
|------------------|---------|--------------------------|
| **Límites de tasa (Rate limits) de la API de NVD** | Alto | Implementación de una caché relacional local en MariaDB combinada con políticas de *exponential backoff* en las peticiones. |
| **Restricciones de licenciamiento en AnyDesk** | Medio | Mantener un plan de contingencia operativo enfocado en la migración a **RustDesk**, una alternativa robusta y de código abierto. |
| **Degradación de rendimiento y Lighthouse en WordPress** | Medio | Desarrollo de un tema ligero minimalista (CSS vanilla, JavaScript asíncrono no intrusivo y carga diferida de librerías multimedia). |
| **Cuestionamiento del stub de macOS en el tribunal** | Bajo | Justificación técnica del stub como un principio de modularidad y escalabilidad futura honesta, evitando código destructivo sin validación previa adecuada. |

---

## 7. Bibliografía inicial

* **WordPress Developer Resources:** <https://developer.wordpress.org/>
* **MantisBT REST API Reference:** <https://documenter.getpostman.com/view/29959/RVu8CTDL>
* **Microsoft Learn - PowerShell Documentation:** <https://learn.microsoft.com/en-us/powershell/>
* **NIST National Vulnerability Database:** <https://nvd.nist.gov/>
* **CISA Known Exploited Vulnerabilities Catalog:** <https://www.cisa.gov/known-exploited-vulnerabilities-catalog>
* **W3C Web Content Accessibility Guidelines (WCAG 2.1):** <https://www.w3.org/TR/WCAG21/>
* **Repositorio del proyecto en GitHub:** <https://github.com/Haplee/ResolveCore>
