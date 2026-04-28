Eres un agente de desarrollo experto en WordPress theme development, PHP, HTML, CSS y JavaScript vanilla.

## CONTEXTO

El tema de WordPress "ResolveCore" ya está desarrollado y publicado en WordPress.com plan Personal.
El archivo base es `resolvecore-theme/front-page.php` con su correspondiente `style.css`, `functions.php` e `index.php`.

El proyecto es el TFG ASIR de Francisco Vidal Mateo (GitHub: Haplee, Twitter: @FranVidalMateo).
ResolveCore es una plataforma cross-platform de mantenimiento y optimización para Windows, Linux y Android.
Eslogan: "Solución a tus problemas informáticos."

La web ya está publicada y funcionando. NO toques la estructura base ni los estilos globales salvo que sea estrictamente necesario para una nueva funcionalidad.

## LO QUE YA EXISTE (NO MODIFICAR)

- Navbar fija con scroll effect, hamburger mobile y barra de progreso
- Hero con grid animado, partículas, glows, count-up stats y badge
- Strip de plataformas (Windows, Linux, Android)
- Grid de 6 servicios con card glow effect
- Demo interactiva con 4 escenarios (diagnóstico, vulnerabilidades, hardware, optimización) y terminal typewriter
- Tabla de vulnerabilidades con botones [REPARAR] funcionales
- Sección de descarga con tarjetas por plataforma y bloque GitHub
- Grid de 3 planes de precios (Free, Pro, Enterprise)
- Formulario de contacto con AJAX a WordPress, nonce, tipos de consulta y validación
- Footer con redes sociales (github.com/Haplee, x.com/FranVidalMateo)

## TAREAS A COMPLETAR

Trabaja sobre los archivos existentes y aplica los siguientes cambios en orden:

### 1. ENLACES DE DESCARGA REALES
En `front-page.php`, localiza la sección `id="descargar"` y actualiza los `href` de los tres botones de descarga:
- Windows .exe → sustituir por la URL real del release de GitHub cuando esté disponible. Por ahora dejar `href="#"` con un atributo `data-platform="windows"` y mostrar un tooltip "Próximamente" al hover.
- Linux .deb → igual con `data-platform="linux"`
- Android .apk → igual con `data-platform="android"`
Añade CSS para el tooltip y el JS que lo muestra al hover sobre botones con `data-platform`.

### 2. PÁGINA DE DOCUMENTACIÓN
Crea un nuevo archivo `page-docs.php` dentro del tema con `Template Name: ResolveCore Docs`.
Debe mantener la navbar y footer del tema principal.
Estructura de la documentación:
- Sidebar izquierda fija con índice navegable (Introducción, Instalación, Uso, Módulos, API, FAQ)
- Contenido principal a la derecha con scroll independiente
- Mismos estilos CSS del tema (dark, mono, accent verde)
- Sección "Instalación" con bloques de código por plataforma (Windows, Linux, Android) con botón copiar al portapapeles
- Sección "Módulos" que detalla los 6 módulos del sistema

### 3. PÁGINA DE CHANGELOG
Crea `page-changelog.php` con `Template Name: ResolveCore Changelog`.
Misma navbar y footer.
Timeline vertical de versiones con:
- v1.0.0 (actual) — lanzamiento inicial, lista las 6 funcionalidades principales
- Cada entrada con fecha, número de versión en mono, badge de tipo (RELEASE / FIX / FEATURE) y lista de cambios
- Estilo de línea vertical con puntos conectores, color accent

### 4. MEJORA DEL FORMULARIO
En el formulario existente (`id="rc-contact-form"`), añade:
- Validación en tiempo real campo a campo (borde rojo si vacío al salir del campo, verde si válido)
- Contador de caracteres en el textarea (máximo 500, mostrado como "123 / 500")
- Campo honeypot oculto anti-spam (`rc_website`, si tiene valor el PHP lo rechaza)
- En `functions.php` añade la comprobación del honeypot antes de enviar el email

### 5. META TAGS Y SEO BÁSICO
En el `<head>` de `front-page.php` añade:
- Open Graph tags (og:title, og:description, og:type, og:url, og:image)
- Twitter Card tags
- Meta description
- Canonical URL con `home_url('/')`
- Schema.org JSON-LD de tipo SoftwareApplication con name, description, operatingSystem (Windows, Linux, Android), applicationCategory "UtilitiesApplication", author

### 6. MODO MANTENIMIENTO OPCIONAL
En `functions.php` añade una constante `RESOLVECORE_MAINTENANCE` que si está en `true` redirige todas las visitas a una página de mantenimiento simple (mismos estilos, mensaje "Volvemos pronto", barra de progreso animada). No afecta al admin de WordPress.

## REGLAS

- Trabaja archivo por archivo, muestra el diff o el bloque modificado, no el archivo completo salvo que sea nuevo.
- Prefija todas las clases CSS nuevas con `rc-` para evitar conflictos con el tema de WordPress.
- Todo el JS debe ser vanilla, sin jQuery ni librerías externas.
- Los archivos nuevos (`page-docs.php`, `page-changelog.php`) deben subirse a la misma carpeta del tema y activarse desde WordPress > Páginas > Atributos > Plantilla.
- Cuando termines cada tarea indica exactamente qué archivo modificaste y en qué línea aproximada.