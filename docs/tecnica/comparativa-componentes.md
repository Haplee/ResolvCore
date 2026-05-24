# ResolveCore — Tablas Comparativas y Justificación Detallada de Componentes

> **Autor:** Francisco Vidal Mateo · TFG ASIR 2024/25
> **Propósito:** Justificación técnica exhaustiva y comparativa frente al tribunal sobre la elección de cada tecnología del stack.

---

## 1. CMS, Plataforma y Alojamiento

En la fase de diseño del portal, la decisión del motor y el alojamiento es clave para soportar la integración (plugins propios) minimizando el coste operativo.

| Opción Evaluada | Coste / Licencia | Características Clave | Decisión y Justificación ASIR |
| :--- | :--- | :--- | :--- |
| **WP.com Gratuito** | 0 € / mes | Subdominio, publicidad forzada. | **Descartado:** Imagen no profesional, sin dominio y no permite plugins de terceros. |
| **WP.com Personal** | ~4 € / mes | Dominio propio, sin publicidad. | **Descartado:** Aunque asume un coste bajo, sigue teniendo capada la instalación de plugins propios. Imposibilita cargar `rc-mantisbt` (esencial para el proyecto). |
| **WP.com Business** | ~25 € / mes | Plugins/temas libres, acceso SFTP. | **Descartado por coste:** Permite la arquitectura completa de ResolveCore, pero su precio es injustificable para la fase de TFG. |
| **WP.org (Autohospedado)** | **~4 € / mes (VPS) o 0 € (LocalWP)** | **Control total (Root), sin límites, plugins libres.** | **ELEGIDO:** Para el desarrollo se utiliza **LocalWP** (coste cero, emula servidor web). Para producción se migra a un **VPS Linux** (aprox 4€/mes). Esto proporciona la potencia del plan Business de 25€, pero aplicando conocimientos ASIR de despliegue web a un coste mínimo. |
| **Desarrollo Custom (PHP)** | Coste en horas | A medida, máxima flexibilidad. | **Descartado:** Reinventar la rueda (gestión de sesiones, XSS, routing) resta tiempo al núcleo del proyecto (integración y automatización). |

---

## 2. Soporte Técnico y Ticketing

El corazón de la trazabilidad requiere un sistema ligero, auditable y con API REST para conectarse con el CMS.

| Componente Evaluado | Tipo y Lenguaje | Consumo RAM / Backend | Decisión y Justificación Técnica |
| :--- | :--- | :--- | :--- |
| **MantisBT 2.27** | **GPL (Open Source) / PHP** | **Muy Bajo (<50 MB) / MySQL** | **ELEGIDO:** Comparte el mismo stack que WordPress (PHP+MariaDB), facilitando el mantenimiento en un único servidor. Su API REST madura y el ecosistema de plugins (MantisKanban, SetDuedate) cubren el flujo ASIR perfectamente. |
| **Jira Software** | Comercial (Atlassian) / Java | Muy Alto (Java Heap) | **Descartado:** Licencia de pago por usuario que compromete el modelo de bajo coste para autónomos. Requiere muchísima más memoria si es self-hosted. |
| **GitLab Issues** | GPL / Ruby & Go | Crítico (>4 GB RAM) | **Descartado:** Instalar un servidor GitLab local o en VPS consume recursos desproporcionados solo para aprovechar su módulo de ticketing. |
| **Redmine** | GPL / Ruby on Rails | Medio | **Descartado:** Mezclar entornos PHP (WordPress) y Ruby (Redmine) complica la administración del servidor y la estandarización. |

---

## 3. Control y Acceso Remoto

| Herramienta | Licencia / Coste | Rendimiento (Latencia) | Decisión y Justificación Técnica |
| :--- | :--- | :--- | :--- |
| **AnyDesk** | **Gratuito (Educativo)** | **Sobresaliente (DeskRT)** | **ELEGIDO:** Su codec (DeskRT) mantiene fluidez incluso en redes 4G deficientes. Es portable (no ensucia el equipo del cliente instalando servicios persistentes) y vincula un ID unívoco que se almacena en el ticket de Mantis. |
| **TeamViewer** | Gratuito condicionado | Alto | **Descartado:** Penaliza drásticamente las sesiones de soporte considerándolas "uso comercial", bloqueando las conexiones a los pocos minutos durante el diagnóstico. |
| **RustDesk** | GPL (Open Source) | Medio / Alto | **Descartado:** A pesar de ser libre, su mejor rendimiento se obtiene desplegando y administrando un servidor de relevo (Relay Server) propio, lo cual suma carga extra de administración de red innecesaria en este TFG. |

---

## 4. Scripting y Motor de Diagnóstico Local

| Sistema | Lenguaje Elegido | Alternativa Principal | Razones de la Decisión frente a la Alternativa |
| :--- | :--- | :--- | :--- |
| **Windows** | **PowerShell 7+** | Python / WMI (VBS) | **Decisión:** PS maneja **objetos nativos tipados** en lugar de cadenas de texto (como Bash/CMD). Accede directamente a las clases CIM/WMI sin dependencias. <br>**Descarte de Python:** Instalar el intérprete Python (`.exe`) más módulos pip (ej. `pywin32`) en el ordenador afectado del cliente rompe la filosofía de intervención limpia e inmediata. |
| **Linux y Android** | **Bash (sh-comp.)** | Python / Perl | **Decisión:** Compatibilidad universal. El script invoca binarios core del sistema (`df`, `free`, `ss`, `adb`) orquestándolos nativamente. <br>**Descarte de Python:** No todos los entornos de servidores embebidos o consolas ADB de Android tienen Python disponible out-of-the-box. Bash sí. |

---

## 5. Infraestructura Base: Base de Datos y Servidor Web

| Rol de Infraestructura | Componente Elegido | Alternativa Directa | Justificación de Arquitectura ASIR |
| :--- | :--- | :--- | :--- |
| **Servidor Web** | **Nginx + PHP-FPM** | Apache 2.4 (mod_php) | **Arquitectura asíncrona:** Nginx procesa conexiones mediante eventos no bloqueantes. Apache tradicional (prefork) abre un hilo por conexión web, disparando el consumo de RAM. Nginx protege al VPS contra agotamiento de memoria bajo picos de carga. |
| **Base de Datos** | **MariaDB 10.6+** | MySQL 8.0 | **Libertad y Rendimiento:** MariaDB es el fork verdaderamente comunitario (GPL pura frente a las licencias duales de Oracle de MySQL). Es el estándar de serie en Ubuntu/Debian y presenta optimizaciones superiores en lectura para el motor InnoDB. |

---

## 6. Ciberseguridad: Auditoría y Cifrado

| Categoría de Seguridad | Componente Elegido | Alternativas y Coste | Justificación |
| :--- | :--- | :--- | :--- |
| **Auditoría de Red (Pasiva)** | **Shodan REST API** | Nmap local / Censys | **Shodan (Free Tier):** Permite detectar servicios expuestos y CVEs vinculados desde el exterior de la IP del cliente *sin* lanzar un escaneo activo de puertos (que dispararía los IDS del cliente). Nmap requiere ser ejecutado localmente y consume más tiempo operativo. |
| **Cifrado Windows** | **BitLocker** | VeraCrypt / DiskCryptor | **BitLocker:** Integración con hardware moderno (TPM 2.0). Cifra el volumen en el arranque de forma transparente en Windows Pro/Enterprise. DiskCryptor carece de mantenimiento y VeraCrypt se reserva solo para versiones Windows Home sin soporte TPM. |
| **Cifrado Linux** | **LUKS (dm-crypt)** | ecryptfs | **LUKS:** Es el estándar robusto del kernel Linux operando a nivel de bloque (cifra la partición entera). Ecryptfs trabaja a nivel de archivo montado (solo cifra /home), lo que expone temporales y logs del sistema operativo. |
| **Gestor de Contraseñas** | **Bitwarden** | 1Password / LastPass | **Bitwarden:** Recomendado en los informes a clientes porque es Open Source, auditado por terceros, gratuito para usuarios básicos y permite despliegue self-hosted (Vaultwarden) para clientes corporativos severos. LastPass queda descartado tras las brechas de seguridad sufridas. |

---

## 7. Despliegue y Sistemas de Clonado

| Categoría de Intervención | Herramienta Elegida | Alternativa Directa | Justificación del Caso de Uso |
| :--- | :--- | :--- | :--- |
| **Desarrollo (Contenedores)** | **Docker Compose** | XAMPP / MAMP | **Aislamiento:** Docker permite reproducir la configuración exacta de MantisBT+MariaDB en cualquier máquina en 10 segundos, frente a los conflictos de puertos y versiones de PHP que acarrea XAMPP. |
| **Clonación Puntual (Física)** | **Clonezilla Live** | Macrium Reflect | **Escenario:** Técnico acude con pendrive. Es software libre (GPL), hace copias bit a bit sector por sector y funciona en Windows y Linux. Macrium es comercial. |
| **Despliegue Flotas (Red)** | **FOG Project** | WDS + MDT (Microsoft) | **Escenario:** Despliegue masivo en aulas. FOG se levanta en un servidor Linux gratuito (PXE boot). WDS/MDT requiere licencias obligatorias de Windows Server y no soporta imágenes Linux con la misma versatilidad. |
