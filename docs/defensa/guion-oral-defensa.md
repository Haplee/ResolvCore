# Guion oral de defensa — ResolveCore (para estudiar y ensayar)

> Duración objetivo: **10-12 minutos** hablando tranquilo (~130 palabras/minuto).
> Cada bloque lleva su tiempo orientativo. Las indicaciones entre [corchetes] no
> se leen: son para ensayar (pausas, gestos, slide).
> Ensayo recomendado: leerlo 2 veces en voz alta, luego ensayar solo con los
> títulos de bloque, y la última vez cronometrado de pie.

---

## BLOQUE 0 — Saludo (15 segundos)

Buenos días. Soy Francisco Vidal Mateo y vengo a presentar mi Trabajo de Fin de
Grado del ciclo de ASIR: **ResolveCore**, una plataforma de soporte técnico remoto.

[Pausa. Mirar al tribunal. Slide de portada.]

---

## BLOQUE 1 — El problema y la idea (1,5 minutos)

La idea nace de un problema que he visto de cerca: pequeñas empresas, autónomos y
usuarios domésticos tienen los equipos degradados por falta de mantenimiento.
Discos llenos, vulnerabilidades sin parchear, hardware al final de su vida útil.
Y el soporte que tienen a mano es presencial, caro y, sobre todo, **reactivo**:
se actúa cuando ya ha fallado algo.

Mi propuesta es darle la vuelta a eso con un servicio estructurado, trazable y
parcialmente automatizado. Y lo resumiría en una frase:

[Pausa breve. Esta frase, de memoria y mirando al tribunal:]

**"ResolveCore convierte una solicitud de ayuda informática en un proceso trazable
de siete fases, donde cada fase deja evidencia: un ticket, un JSON de diagnóstico,
un informe y una factura."**

Además, todo el software que uso es libre o gratuito, y todas las APIs que consumo
son públicas. No dependo de ningún proveedor.

---

## BLOQUE 2 — El flujo de siete fases (2 minutos)

[Slide del flujo. Ir señalando fase a fase, sin prisa.]

**Uno, la solicitud.** El cliente entra en la web pública, hecha en WordPress, y se
registra. Aquí un matiz importante: el formulario de la home **no crea tickets**;
da de alta la cuenta de cliente y le manda un email de activación. Una vez dentro
de su panel, ahí es donde crea la solicitud.

**Dos, el ticket.** El panel del cliente crea el ticket en MantisBT a través de su
API REST, autenticada por token. De eso se encarga mi plugin rc-mantisbt.

**Tres, la asignación.** El administrador asigna el ticket a un técnico, que lo ve en su bandeja
del portal interno de técnicos.

**Cuatro, la conexión remota o presencial.** El técnico se conecta al equipo del cliente con
AnyDesk; el propio portal incluye el lanzador.

**Cinco, diagnóstico y resolución.** El técnico ejecuta el script de diagnóstico de
la plataforma que toque — Windows, Linux o Android — y obtiene un JSON estructurado
y, al publicarlo, una puntuación de salud de cero a cien. Si hace falta, cruza el
inventario del equipo con el escáner de vulnerabilidades y aplica la optimización.

**Seis, el informe.** Se genera una plantilla de informe en texto plano, el técnico
la rellena a mano y la sube él mismo al ticket como txt en las boxes de Mantis —
ningún script la sube por él.

**Y siete, la facturación**, que se gestiona desde el propio MantisBT al cerrar el
ticket, con dos modelos: pago por servicio o suscripción con revisiones programadas.

---

## BLOQUE 3 — La web y el gestor de tickets (2 minutos)

[Slide de arquitectura.]

La parte web es un tema de WordPress hecho a mano, sin Bootstrap ni Tailwind, y
**cuatro plugins propios**, cada uno con una responsabilidad única:

**rc-core** gestiona el alta de clientes, con throttle por IP y por email, honeypot
anti-spam y una purga programada de cuentas sin activar.

**rc-mantisbt** es el puente con MantisBT: una clase que encapsula las llamadas
REST para crear el ticket, añadir notas, adjuntar ficheros y consultar el estado.

**rc-fleet** es el panel de flota: los diagnósticos pueden publicar su JSON por una
API REST con token, y un endpoint público muestra estadísticas agregadas — score
medio y recuento por sistema operativo — sin exponer nunca emails, hostnames ni IPs.

**Y rc-tech** lleva la operativa del portal de técnicos: cola de tickets, SLA,
alertas y timeline.

¿Por qué cuatro plugins y no uno? Porque cada uno versiona por separado y puedo
desactivar, por ejemplo, el panel de flota sin tocar la integración de tickets.

En cuanto al gestor de incidencias, elegí **MantisBT** frente a alternativas como
Jira o GitHub Issues por tres razones: es software libre, lo autoalojo en mi propio
VPS sin coste por usuario, y trae una API REST completa con autenticación por token
y campos personalizados sin programar nada. Le añadí categorías y campos propios
del servicio — la plataforma del equipo y el ID de AnyDesk — y un plugin de marca
blanca. El modelo de datos lo documenté por ingeniería inversa.

---

## BLOQUE 4 — El motor: los scripts de diagnóstico (1,5 minutos)

[Slide de scripts.]

El motor del servicio son los scripts de diagnóstico y optimización. Hay tres
plataformas: Windows en PowerShell, Linux en Bash y Android con Bash y ADB. Y aquí
viene una decisión de diseño que quiero justificar:

¿Por qué Bash y PowerShell y no todo en Python? Porque estos scripts corren **en el
equipo del cliente**, donde no puedo asumir que haya Python instalado. PowerShell y
Bash vienen de serie. Python lo reservo para la máquina del técnico, donde sí
controlo el entorno.

Los tres diagnósticos miden lo esencial de cada sistema — CPU, memoria, disco,
servicios, salud S.M.A.R.T. de los discos, seguridad — y los tres emiten **el mismo
esquema JSON unificado**, validable con JSON Schema.

La optimización tiene salvaguardas: exige un flag de confirmación para evitar
ejecuciones accidentales, puede detener los procesos de mayor consumo pero nunca
los críticos, y hay una regla innegociable: **el servicio de impresión no se toca
jamás**, en ninguna plataforma, porque la cola de impresión es crítica para el
usuario final.

---

## BLOQUE 5 — Ciberseguridad y arquitectura Python (1,5 minutos)

[Slide CVE + hexagonal.]

La parte de ciberseguridad va en Python, solo con la biblioteca estándar: cero
dependencias externas.

El escáner de vulnerabilidades cruza el inventario de software del equipo con tres
fuentes públicas: **NVD**, la base de datos del NIST; **CISA KEV**, que es el
catálogo de vulnerabilidades con explotación activa confirmada — si un CVE está en
KEV, se prioriza siempre —; y **OSV**, para paquetes open source. Para no inundar
al técnico de ruido, solo muestra avisos que estén en KEV o tengan un CVSS de siete
o más.

Estos scripts siguen una **arquitectura hexagonal**, pero con una particularidad:
sin clases. El dominio son diccionarios creados por funciones constructoras; los
ports son contratos escritos en docstrings; y los adapters son funciones de módulo,
uno por cada fuente. ¿Por qué sin clases? Porque mi dominio son datos inmutables
que viajan entre funciones: los diccionarios me dan el mismo contrato con menos
ceremonia, y la separación de capas se mantiene — el dominio no sabe nada de HTTP,
y cambiar de fuente de vulnerabilidades es escribir otro adapter sin tocar la lógica.

Del diagnóstico sale también el informe: una plantilla de texto plano con las
secciones obligatorias, que se pre-rellena con los datos del JSON y que el técnico
completa a mano. Texto plano a propósito: cien por cien ASCII, sin problemas de
codificación y sin vectores de inyección.

---

## BLOQUE 6 — Producción y calidad (1 minuto)

[Slide de despliegue.]

Y todo esto no es un prototipo de laboratorio: está **desplegado en producción** en
un VPS de IONOS con nginx, PHP-FPM, MariaDB y certificados de Let's Encrypt.
WordPress y MantisBT conviven en la misma máquina, y el tema se sirve por un enlace
simbólico al repositorio clonado, así que un git pull actualiza la web al instante.

La operación del día a día está automatizada con scripts propios: backups,
restauración, healthcheck, despliegue, y la configuración de SPF, DKIM y DMARC para
que los correos de activación no acaben en spam.

Y la calidad del código la vigila una integración continua **bloqueante**:
shellcheck para Bash, PSScriptAnalyzer para PowerShell, los WordPress Coding
Standards para PHP y ruff para Python. Nada entra en el repositorio sin pasar el
lint.

---

## BLOQUE 7 — Cierre (45 segundos)

[Slide de cierre. Bajar el ritmo.]

En resumen: ResolveCore es un proceso completo y trazable, de la solicitud a la
factura, que integra todos los bloques del ciclo: sistemas operativos en tres
plataformas, redes y servicios, bases de datos, aplicaciones web, seguridad y
lenguajes de marcas. Construido entero sobre software libre, y funcionando en
producción.

Como mejoras futuras quedan el cliente para macOS y la automatización de la
facturación, que hoy se gestiona de forma manual desde MantisBT con sus dos
modelos: pago por servicio y suscripción.

Muchas gracias por vuestra atención. Quedo a disposición del tribunal para las
preguntas.

[Respirar. Sonreír. Esperar.]

---
---

# CHULETA DE ENSAYO (no se lee, se memoriza)

## Los 7 títulos de bloque (ensayo sin papel)
1. Saludo → 2. Problema + FRASE → 3. Las 7 fases → 4. Web (4 plugins) + Mantis →
5. Scripts (¿por qué Bash/PS?) → 6. CVE + hexagonal sin clases + informe →
7. Producción + CI → Cierre (+ mejoras futuras).

## Las 3 justificaciones estrella (de memoria, palabra por palabra el argumento)
- **¿Por qué Mantis?** Libre + autoalojado sin coste por usuario + REST con token
  y campos personalizados sin programar.
- **¿Por qué Bash/PowerShell?** Corren en el equipo del cliente, no puedo asumir
  Python; vienen de serie. Python = máquina del técnico.
- **¿Por qué hexagonal sin clases?** Datos inmutables entre funciones; mismo
  contrato con menos ceremonia; cambiar de feed = otro adapter sin tocar la lógica.

## Los 5 "no" que no se me pueden escapar al revés
- El informe NO es PDF → .txt a mano (el PDF de rc-tech es legacy).
- El formulario NO crea tickets → solo da de alta la cuenta.
- La factura NO la genera un script → se gestiona en MantisBT (automatizarla es
  mejora futura, junto con macOS).
- macOS NO existe → roadmap.
- El Spooler NO se toca → nunca, en ninguna plataforma.

## Dato técnico fino (por si pregunta el tribunal)
- **¿Dónde se calcula el score 0-100?** En el servidor: `rc_fleet_score()` del
  plugin rc-fleet, cuando el agente publica el JSON por la API REST. El script
  del cliente emite el JSON; el score viene en la respuesta de la publicación.

## Si me quedo en blanco
Volver a la frase ancla: *"…cada fase deja evidencia: un ticket, un JSON, un
informe y una factura"* — y seguir por la fase que toque. El flujo de 7 fases es
el esqueleto de toda la presentación: si lo tengo, tengo la defensa.

## Control de tiempo en ensayo
| Bloque | Acumulado objetivo |
|---|---|
| 0-1 Problema | 2:00 |
| 2 Fases | 4:00 |
| 3 Web + Mantis | 6:00 |
| 4 Scripts | 7:30 |
| 5 Python/CVE | 9:00 |
| 6 Producción | 10:00 |
| 7 Cierre | 10:45 |

Si en el ensayo paso de 12 minutos: recortar primero del Bloque 3 (detalle de
rc-core) y del Bloque 6 (lista de scripts de ops), nunca de las justificaciones.
