# PROPUESTA DE PROYECTO INTEGRADO

**Nombre del alumno/a:** Francisco Vidal Mateo  
**Título del proyecto:** ResolveCore — Plataforma de Mantenimiento, Diagnóstico y Optimización de Equipos Informáticos

## Breve descripción del proyecto
ResolveCore es una plataforma web para empresas de mantenimiento informático. La idea es tener en un solo sitio todo lo necesario para gestionar diagnósticos, reparaciones y optimización de equipos Windows, Linux/Ubuntu y Android, sin tener que saltar entre herramientas distintas.

El proyecto se divide en tres partes principales:

- **Diagnóstico del equipo:** genera una puntuación de 0 a 100 por categorías (hardware, sistema operativo, red y seguridad), comparada con un perfil de referencia según el tipo de equipo.
- **Vulnerabilidades:** cruza el software instalado contra la base de datos CVE/NVD del NIST, muestra la puntuación CVSS de cada riesgo y permite registrar qué se hizo con cada uno (parchear, desinstalar o dejarlo en monitorización), guardando el historial por equipo.
- **Vida útil:** estima cuánto le queda a cada componente usando datos reales: S.M.A.R.T. del disco, temperatura, ciclos de batería y uso de RAM. Si algo baja del umbral crítico, el sistema avisa al técnico y al cliente.

## Tecnologías a utilizar
### Frontend y CMS
- WordPress con tema personalizado (PHP + HTML + CSS + JS vanilla)
- CSS propio (style.css del tema WordPress)
- fetch() para las llamadas asíncronas a la API interna

### Backend y base de datos
- PHP 8.x — la lógica del negocio está integrada en el tema de WordPress
- MySQL / MariaDB como base de datos relacional
- $wpdb para acceder a la base de datos con queries preparadas
- Sesiones PHP nativas ($_SESSION) para la autenticación
- WP REST API / admin-ajax.php para los endpoints del frontend

### Autenticación y roles
- Login y logout con sesiones PHP clásicas
- Dos roles: cliente y técnico
- Control de acceso por rol en cada página y endpoint

### Vulnerabilidades
- API CVE/NVD del NIST
- CVSS Scoring para valorar la gravedad de cada vulnerabilidad

### Generación de PDF
- TCPDF o mPDF desde el servidor (PHP)
- Los archivos se guardan en wp-content/uploads/

### Automatización de sistemas
- Bash, Batch, PowerShell y ADB
- DISM, SFC y winget en Windows
- Lectura de S.M.A.R.T., sensores de temperatura y batería

### Virtualización
- VirtualBox
- Docker

### CI/CD
- GitHub Actions

## Justificación por módulos
### Implantación de Sistemas Operativos
El proyecto incluye scripts para automatizar el despliegue de sistemas: instalación desatendida, configuración inicial y firma de módulos del kernel para Secure Boot en Ubuntu. En Windows se automatizan los pasos de configuración más habituales después de una instalación limpia. VirtualBox permite al técnico probar configuraciones en un entorno aislado sin tocar el equipo del cliente. Su instalación también está automatizada dentro de las herramientas del proyecto.

### Gestión de Bases de Datos
El esquema en MySQL incluye todas las entidades del negocio: clientes, técnicos, citas, tipos de servicio, intervenciones e historial de vulnerabilidades. Se aplican claves foráneas, índices en las consultas más frecuentes y control de acceso desde PHP, ya que MySQL no tiene Row Level Security nativo. El panel de estadísticas usa vistas para calcular datos como intervenciones por período, valoraciones medias o servicios más demandados. La tabla de vulnerabilidades corregidas permite detectar si una vulnerabilidad ya tratada vuelve a aparecer en el mismo equipo.

### Fundamentos de Hardware
El módulo de diagnóstico lee sensores del sistema, extrae datos S.M.A.R.T. del disco (sectores defectuosos, temperatura, horas de uso), analiza el estado de la batería en portátiles (ciclos de carga, capacidad real frente al diseño) y mide el uso y temperatura de RAM y CPU bajo carga. Con esos datos se calcula la puntuación de salud y la estimación de vida útil de cada componente. Si algo baja del umbral crítico, el sistema manda una alerta al técnico y al cliente. Todo queda en el informe PDF de la intervención.

### Planificación y Administración de Redes
Las herramientas incluyen un bloque de configuración de red: parámetros TCP/IP, DNS de alto rendimiento, RSS (Receive Side Scaling) y análisis básico de conectividad. La categoría red dentro de la puntuación de salud evalúa latencia, pérdida de paquetes y configuración del adaptador. También se incluye la configuración de ProxyChains4 en Linux para trabajar en redes corporativas con restricciones de acceso.

### Lenguajes de Marca y Sistemas de Gestión de la Información
El portal usa HTML semántico, CSS propio y PHP para generar las páginas dentro del tema de WordPress. Al cerrar una intervención se generan dos PDFs desde el servidor con TCPDF o mPDF: un informe técnico completo para el expediente interno y un resumen en lenguaje sencillo para el cliente. Los dos quedan vinculados al registro de la intervención en la base de datos.

### Formación y Orientación Laboral
El proyecto simula una empresa real de mantenimiento informático. Se define el catálogo de servicios, las tarifas por tipo de intervención (estándar, urgente, remota), las condiciones del contrato de mantenimiento y un análisis básico de viabilidad económica. El sistema de valoración de técnicos de 1 a 5 estrellas y el historial visible para el cliente son parte del modelo de calidad de servicio que trabaja este módulo.

### Administración de Sistemas Operativos
La mayor parte de las herramientas del proyecto corresponde a este módulo. Se desarrollan utilidades para los tres sistemas objetivo:
- **Windows:** gestión de servicios, esquemas de energía, limpieza de temporales, actualización de paquetes con winget y reparación con DISM y SFC.
- **Ubuntu/Linux:** instalación automatizada de software, configuración del shell, gestión de módulos del kernel y hardening básico.
- **Android:** optimización con ADB, limpieza de caché y configuración de opciones de desarrollador.

Todas las herramientas son idempotentes: se pueden ejecutar varias veces sin efectos no deseados.

### Servicios en Red e Internet
La plataforma se despliega en un servidor con WordPress como base. Toda la lógica del negocio vive en PHP en el mismo servidor, sin depender de servicios de terceros para la funcionalidad principal. Se exponen endpoints con la WP REST API para que el frontend consulte datos sin recargar la página. Las notificaciones de cita se envían por correo desde el servidor PHP.

### Seguridad y Alta Disponibilidad
La seguridad se aplica por capas: autenticación con sesiones PHP, contraseñas almacenadas con password_hash() usando bcrypt, control de acceso por rol en cada endpoint, queries preparadas con $wpdb para evitar inyección SQL, y validación de los datos en el servidor antes de cualquier escritura. El módulo de vulnerabilidades refuerza esta parte: cruzar el software instalado contra CVE/NVD convierte a ResolveCore en una herramienta de seguridad activa, no solo reactiva. Docker aporta la parte de alta disponibilidad: contenerizar la aplicación y la base de datos garantiza que el entorno funcione igual en desarrollo, CI y producción.

### Implantación de Aplicaciones Web
ResolveCore funciona en cualquier servidor con soporte PHP y MySQL, sin servicios cloud de pago obligatorios. El despliegue está automatizado con GitHub Actions: cada push a main ejecuta los tests y despliega los cambios. El entorno local está contenerizado con Docker para que cualquier máquina levante el proyecto exactamente igual.

### Administración de Sistemas Gestores de Bases de Datos
El trabajo va más allá del diseño inicial: se hacen migraciones versionadas con historial de cambios, vistas para el panel de estadísticas (intervenciones por período, tiempo medio de resolución, carga por técnico, valoraciones), triggers compatibles con MySQL en las tablas más importantes y una política de backups automáticos con procedimiento de restauración documentado. La tabla de vulnerabilidades corregidas se actualiza periódicamente contra la API de NVD para tener los datos al día.

### Empresa e Iniciativa Emprendedora
El proyecto se plantea como una empresa ficticia de mantenimiento informático llamada ResolveCore. Se hace un análisis DAFO del sector, se define la propuesta de valor frente al mantenimiento reactivo tradicional y se diseña un modelo de negocio con dos modalidades: servicio puntual por intervención y contrato mensual con revisiones periódicas automatizadas. Se incluye también una proyección básica de ingresos y costes para el primer año.

## Alcance
Si el proyecto estuviera terminado, la exposición ante el tribunal cubriría:
- Demo en vivo del portal: registro de un cliente, selección de servicio con nivel de urgencia, elección de técnico disponible y confirmación de cita.
- Ejecución del diagnóstico sobre un equipo real o una VM: puntuación de salud por categorías, listado de CVEs activas con su CVSS y recomendaciones, estimación de vida útil por componente con gráfica de evolución.
- Panel del técnico: agenda semanal, ficha de cliente con historial de intervenciones y vulnerabilidades corregidas, checklist de tareas y notas internas.
- Generación del PDF de cierre: informe técnico completo y resumen para el cliente.
- Revisión del esquema MySQL, el control de acceso en PHP y el pipeline de CI/CD en GitHub Actions.

### Posibles ampliaciones:
- App Android nativa en Kotlin para gestionar citas desde el móvil en campo.
- Módulo de facturación automática integrado con la agenda.
- Diagnóstico predictivo: analizar el historial para anticipar fallos recurrentes en equipos concretos.
- Soporte a macOS.
- Integración con OSV (Open Source Vulnerabilities) para ampliar la cobertura en software open source.

## Aspectos novedosos
Lo que diferencia a ResolveCore de una herramienta de mantenimiento normal es que junta el diagnóstico activo de vulnerabilidades con CVE/NVD y la estimación de vida útil de los componentes en una sola plataforma. La mayoría de herramientas solo actúan cuando el problema ya ha pasado. Con ResolveCore, el técnico llega a la intervención sabiendo el estado real del equipo antes de tocarlo.

La arquitectura herramienta central con utilidades por sistema operativo imita el modelo de trabajo de un MSP real, donde una consola central coordina agentes en los equipos gestionados.

Al estar construido sobre WordPress, PHP y MySQL, el proyecto se puede desplegar en cualquier hosting compartido estándar. Eso lo hace viable para pequeñas empresas de mantenimiento informático que no tienen presupuesto para infraestructura cloud.
