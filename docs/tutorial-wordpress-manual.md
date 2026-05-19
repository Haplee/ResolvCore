# Tutorial — Montaje manual de la web ResolveCore en WordPress (Linux/Ubuntu)

> Guía paso a paso para construir la web pública de ResolveCore **a mano**, módulo a módulo, sin builders ni automatismos. Sirve como manual de despliegue en Ubuntu/Debian y como evidencia técnica para el TFG.
>
> **Autor:** Francisco Vidal Mateo · TFG ASIR 2025/26
> **Última actualización:** 2026-05-18
> **Tiempo estimado total:** 4–6 h (primera vez), ~1 h (re-instalación)

---

## Índice

1. [Antes de empezar — requisitos y materiales](#1-antes-de-empezar)
2. [Módulo 1 — Entorno local (LocalWP en Linux)](#módulo-1--entorno-local-localwp)
3. [Módulo 2 — Tema `resolvecore-theme`](#módulo-2--tema-resolvecore-theme)
4. [Módulo 3 — Páginas y menús con WP-CLI](#módulo-3--páginas-y-menús)
5. [Módulo 4 — Integración y despliegue de MantisBT](#módulo-4--integración-con-mantisbt)
6. [Módulo 5 — Plugin `rc-mantisbt` y credenciales seguras](#módulo-5--plugin-rc-mantisbt)
7. [Módulo 6 — Formulario de contacto AJAX y seguridad](#módulo-6--formulario-de-contacto-ajax)
8. [Módulo 7 — Backup y despliegue a producción](#módulo-7--backup-y-despliegue)
9. [Checklist final + capturas obligatorias](#checklist-final)
10. [Troubleshooting de sistemas](#troubleshooting)

---

## 1. Antes de empezar

### Materiales necesarios

| Recurso | Descripción | Dónde se obtiene |
|---------|-------------|------------------|
| **LocalWP Linux** | Stack WordPress local (NGINX + PHP 8.2 + MySQL/MariaDB) | <https://localwp.com> |
| **MantisBT 2.27** | Bug tracker de control de tickets | Imagen Docker oficial |
| **Repositorio ResolvCore** | Código fuente del tema, plugins y scripts | `~/Escritorio/ResolvCore` |
| **Entorno OS** | Sistema operativo Linux (Ubuntu 22.04+ / Debian) | Entorno de desarrollo ASIR |

### Estructura que debes obtener al final

```
/home/usuario/Local Sites/resolvecore/app/public/
├── wp-content/
│   ├── themes/
│   │   └── resolvecore-theme/       ← Módulo 2 (Tema custom)
│   └── plugins/
│       └── rc-mantisbt/             ← Módulo 5 (Plugin integración)
```

### Carpeta de capturas

Crea la estructura de directorios en tu documentación para almacenar las evidencias de la instalación:

```bash
mkdir -p docs/capturas/tutorial-wordpress/{01-localwp,02-tema,03-paginas,04-mantis,05-config,06-formulario,07-backup}
```

> **Norma del proyecto** (`CLAUDE.md`): cada paso documentado debe ir acompañado de una captura PNG en `docs/capturas/`. Nombrado: `NN_descripcion.png`.

---

## Módulo 1 — Entorno local (LocalWP)

> **Objetivo:** WordPress levantado de forma nativa en Ubuntu utilizando LocalWP, y WP-CLI configurado con socket directo de MySQL.

### Paso 1.1 — Instalar LocalWP en Ubuntu

1. Descarga el paquete `.deb` de LocalWP para Linux desde la web oficial.
2. Abre la terminal e instala el paquete resolviendo dependencias rotas:
   ```bash
   sudo dpkg -i ~/Descargas/local-*.deb
   sudo apt --fix-broken install -y
   ```
3. Inicia la aplicación. Si surgen problemas de librerías faltantes al provisionar motores de bases de datos, instala el paquete completo de dependencias de MySQL/LocalWP:
   ```bash
   sudo apt install libaio1 libncurses5 libtinfo5 libtidy5deb1 \
     libavif13 libonig5 libzip4 libsodium23 libargon2-1 curl -y
   ```

📸 **Captura 1.1** → `docs/capturas/tutorial-wordpress/01-localwp/01_localwp_instalado.png`

### Paso 1.2 — Crear el sitio en LocalWP

Crea el sitio en la interfaz gráfica con los siguientes parámetros:

| Parámetro | Valor |
|-----------|-------|
| **Nombre** | `ResolveCore` |
| **PHP** | `8.2.29` |
| **Servidor web** | `NGINX 1.26.1` |
| **Base de datos** | `MySQL 8.4.0` |
| **Usuario WordPress** | `admin` |
| **Email de administración** | `fvidalmateo@gmail.com` |

📸 **Captura 1.2** → `02_localwp_sitio_creado.png`

### Paso 1.3 — Instalación y configuración de WP-CLI

WP-CLI nos permite automatizar la administración del sitio. Lo instalamos manualmente y lo vinculamos al binario PHP interno que usa LocalWP:

1. Descarga e instala el binario de WP-CLI:
   ```bash
   curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
   chmod +x wp-cli.phar
   sudo mv wp-cli.phar /usr/local/bin/wp
   ```
2. Añade un alias en tu archivo de configuración de shell (`~/.bashrc` o `~/.zshrc`) para que WP-CLI utilice el motor PHP de LocalWP:
   ```bash
   alias wp='/home/usuario/.config/Local/lightning-services/php-8.2.29+0/bin/linux/bin/php /usr/local/bin/wp'
   ```
3. Carga los cambios de la terminal:
   ```bash
   source ~/.bashrc
   ```
4. Configura el host de base de datos en WP-CLI apuntando directamente al socket Unix generado por LocalWP en lugar del localhost TCP (evita problemas de resolución):
   ```bash
   wp config set DB_HOST 'localhost:<ruta_socket>/mysqld.sock'
   ```

📸 **Captura 1.3** → `03_localwp_wp_admin.png`

---

## Módulo 2 — Tema `resolvecore-theme`

> **Objetivo:** Copiar y activar el diseño personalizado del frontend bajo los estándares WCAG 2.1 AA.

### Paso 2.1 — Despliegue del tema

El tema reside en el repositorio y se copia directamente al directorio de desarrollo de WordPress:

```bash
cp -r ~/Escritorio/ResolvCore/wordpress/resolvecore-theme/ \
  "/home/usuario/Local Sites/resolvecore/app/public/wp-content/themes/"
```

*Nota: Alternativamente, puedes usar un enlace simbólico (`ln -s`) para desarrollo activo.*

### Paso 2.2 — Estructura interna del tema

Valida que el directorio contiene los archivos esenciales:

| Archivo / Carpeta | Función |
|-------------------|---------|
| `style.css` | Hoja de estilos v3.0.0. Contiene variables CSS del proyecto. |
| `functions.php` | Configuración del tema (hooks), enqueues y handler AJAX. |
| `front-page.php` | Estructura del landing: sección hero, servicios, pricing y contacto. |
| `page-docs.php` | Template de Documentación con barra lateral fija de navegación. |
| `page-changelog.php` | Template de registro de cambios con un diseño de timeline de versiones. |
| `page-contacto.php` | Template para el formulario dedicado de contacto técnico. |
| `header.php` / `footer.php` | Cabecera y pie semánticos compartidos. |

#### Variables CSS Principales (`style.css`):
```css
:root {
  --rc-bg: #0a0c10;       /* Fondo oscuro profundo */
  --rc-accent: #00e5a0;   /* Verde aguamarina de realce */
  --rc-text: #e8eaf0;     /* Texto claro */
}
```

### Paso 2.3 — Activación del tema

Activa el tema utilizando WP-CLI para comprobar el correcto estado del entorno:

```bash
wp theme activate resolvecore-theme
```

📸 **Captura 2.1** → `02-tema/01_tema_activado.png`
📸 **Captura 2.2** → `02-tema/02_home_landing.png`

---

## Módulo 3 — Páginas y menús

> **Objetivo:** Generar la estructura de páginas y menús estáticos con WP-CLI aplicando las plantillas del tema.

### Paso 3.1 — Creación de páginas

Ejecuta los siguientes comandos para crear las páginas en WordPress asignándoles sus respectivas plantillas de página personalizadas:

```bash
# Crear página de Documentación
wp post create --post_type=page --post_title='Documentación' --post_status=publish \
  --post_name='docs' --page_template='page-docs.php'

# Crear página de Changelog
wp post create --post_type=page --post_title='Changelog' --post_status=publish \
  --post_name='changelog' --page_template='page-changelog.php'

# Crear página de Contacto
wp post create --post_type=page --post_title='Contacto' --post_status=publish \
  --post_name='contacto' --page_template='page-contacto.php'
```

📸 **Captura 3.1** → `03-paginas/01_pagina_docs.png`

### Paso 3.2 — Configurar menús de navegación

Configuramos el menú principal del header y el menú secundario de soporte en el pie de página usando WP-CLI:

```bash
# Crear y asignar menú Principal en el header
wp menu create 'Principal'
wp menu location assign principal primary

# Crear y asignar menú en el Footer
wp menu create 'Footer'
wp menu location assign footer footer

# Añadir enlace externo a GitHub en el menú del Footer
wp menu item add-custom footer 'GitHub' 'https://github.com/Haplee/ResolvCore'
```

📸 **Captura 3.2** → `03-paginas/02_menus_configurados.png`

---

## Módulo 4 — Integración con MantisBT

> **Objetivo:** Desplegar de forma aislada MantisBT usando contenedores y habilitar su API REST para recepción de incidencias.

### Paso 4.1 — Despliegue con Docker Compose

1. Instala el motor de contenedores en tu sistema Ubuntu:
   ```bash
   sudo apt install docker.io docker-compose -y
   sudo usermod -aG docker $USER && newgrp docker
   ```
2. Crea un archivo `docker-compose.yml` en la ruta de tu infraestructura con la siguiente estructura:
   ```yaml
   version: '3.8'
   services:
     db:
       image: mysql:5.7
       volumes:
         - db_data:/var/lib/mysql
       environment:
         MYSQL_ROOT_PASSWORD: root
         MYSQL_DATABASE: bugtracker
         MYSQL_USER: mantisbt
         MYSQL_PASSWORD: mantisbt_password
     mantisbt:
       image: mantisbt/mantisbt:2.27.0
       ports:
         - "8989:80"
       depends_on:
         - db
       environment:
         MANTIS_DB_HOST: db
         MANTIS_DB_USER: mantisbt
         MANTIS_DB_PASSWORD: mantisbt_password
         MANTIS_DB_NAME: bugtracker
   volumes:
     db_data:
   ```
3. Levanta la infraestructura de soporte técnico:
   ```bash
   docker-compose up -d
   ```

### Paso 4.2 — Habilitar API REST y crear Token

1. Inserta la directiva que habilita la API REST en el archivo de configuración de MantisBT dentro del contenedor en ejecución:
   ```bash
   docker exec mantisbt_mantisbt_1 bash -c \
     "echo '\$g_webservice_rest_enabled = ON;' >> /var/www/html/config/config_inc.php"
   ```
2. Entra en MantisBT a través de `http://localhost:8989`, loguéate, dirígete a **Mi cuenta → API Tokens** y genera un nuevo token de acceso. Guárdalo temporalmente en un archivo local seguro.

### Paso 4.3 — Pruebas de integración del API con cURL

Verifica la conectividad directa y la creación de componentes a través de peticiones HTTP:

```bash
# 1. Crear proyecto principal en MantisBT
curl -s -X POST -H 'Authorization: <TOKEN_API>' -H 'Content-Type: application/json' \
  -d '{"name":"ResolveCore"}' http://localhost:8989/api/rest/projects

# 2. Generar incidencia de prueba
curl -s -X POST -H 'Authorization: <TOKEN_API>' -H 'Content-Type: application/json' \
  -d '{"summary":"Test ticket manual","project":{"id":1},"category":{"name":"General"}}' \
  http://localhost:8989/api/rest/issues
```

📸 **Captura 4.1** → `04-mantis/01_mantis_token_creado.png`

---

## Módulo 5 — Plugin `rc-mantisbt`

> **Objetivo:** Instalar el plugin corporativo de ResolveCore para automatizar el volcado de solicitudes e implementar un almacenamiento seguro de credenciales.

### Paso 5.1 — Copiar y activar el plugin

1. Copia el plugin de integración desde el repositorio local al directorio de plugins de WordPress:
   ```bash
   cp -r ~/Escritorio/ResolvCore/wordpress/plugins/rc-mantisbt \
     "/home/usuario/Local Sites/resolvecore/app/public/wp-content/plugins/"
   ```
2. Activa el plugin mediante WP-CLI:
   ```bash
   wp plugin activate rc-mantisbt
   ```

📸 **Captura 5.1** → `04-plugin/02_plugin_activado.png`

### Paso 5.2 — Configuración segura con `wp-config.php`

Siguiendo las directrices de endurecimiento del TFG, los tokens del API no se almacenarán en la base de datos MySQL (`wp_options`) para mitigar ataques de inyección SQL o robo de credenciales. Los definiremos directamente como constantes de entorno seguras en el archivo de configuración del sistema.

Utilizando WP-CLI, añadimos las directivas directamente a `wp-config.php`:

```bash
wp config set RC_MANTIS_URL 'http://localhost:8989' --type=constant
wp config set RC_MANTIS_TOKEN '<TOKEN_MANTIS>' --type=constant
wp config set RC_MANTIS_PROJECT_ID '1' --type=constant
```

Esto inyectará de forma automática en tu `wp-config.php` el bloque de constantes correspondiente:
```php
define( 'RC_MANTIS_URL', 'http://localhost:8989' );
define( 'RC_MANTIS_TOKEN', 'tu_token_api_aqui' );
define( 'RC_MANTIS_PROJECT_ID', '1' );
```

📸 **Captura 5.2** → `05-config/01_wp_config_constantes.png`

---

## Módulo 6 — Formulario de contacto AJAX

> **Objetivo:** Gestionar el envío asíncrono de tickets técnicos de forma segura aplicando técnicas de sanitización y rate-limiting en base a transitorios de WordPress.

El formulario de contacto integrado en el template de la landing (`page-contacto.php`) utiliza la API AJAX de WordPress para canalizar las solicitudes al handler seguro de `functions.php`.

### Esquema de Seguridad del Envío de Tickets

| Protección | Implementación Técnica | Respuesta del Servidor |
|------------|------------------------|-------------------------|
| **CSRF** | Inyección de token nonce (`wp_nonce_field`) y validación rigurosa con `check_ajax_referer`. | Retorna HTTP `403 Forbidden` en caso de fallo de firma. |
| **Rate Limiting** | Monitorización de dirección IP utilizando `Transients` de WordPress. Máximo de 5 envíos por hora por IP. | Retorna HTTP `429 Too Many Requests` si excede el umbral. |
| **Inyección SQL / XSS** | Desinfección completa con `sanitize_text_field` e `is_email` para campos de texto, y `sanitize_textarea_field` para el cuerpo del mensaje. | Almacena y procesa solo datos limpios. |

📸 **Captura 6.1** → `06-formulario/01_formulario_enviado.png`
📸 **Captura 6.2** → `06-formulario/02_ticket_creado_mantis.png`
📸 **Captura 6.3** → `06-formulario/03_rate_limit_429.png`

---

## Módulo 7 — Backup y despliegue

> **Objetivo:** Respaldar la plataforma y definir los mecanismos de migración de datos hacia el entorno de producción real.

### Paso 7.1 — Backup automatizado en caliente (WP-CLI)

Ejecuta las tareas periódicas de respaldo directamente desde terminal, exportando la base de datos estructural y empaquetando el contenido cargado por los usuarios de forma nativa:

```bash
# Exportar base de datos estructural de WordPress con fecha
wp db export backup-$(date +%F).sql

# Empaquetar el directorio wp-content al completo
tar -czvf wp-content-$(date +%F).tar.gz wp-content/
```

📸 **Captura 7.1** → `07-backup/01_updraft_backup_ok.png`

### Paso 7.2 — Despliegue en VPS de Producción con Nginx y Let's Encrypt

Para el entorno real en un VPS Ubuntu, copiamos los archivos a través de canales seguros y configuramos el backend web:

1. Transfiere el tema y el plugin al servidor web de destino:
   ```bash
   scp -r wordpress/resolvecore-theme usuario@vps:/var/www/resolvecore/wp-content/themes/
   scp -r wordpress/plugins/rc-mantisbt usuario@vps:/var/www/resolvecore/wp-content/plugins/
   ```
2. Configura los hosts virtuales en Nginx (`/etc/nginx/sites-available/resolvecore`) y asegura el tráfico habilitando certificados SSL/TLS gratuitos mediante `certbot`:
   ```bash
   sudo certbot --nginx -d resolvecore.com -d www.resolvecore.com
   ```

📸 **Captura 7.2** → `07-backup/02_produccion_home.png`

---

## Checklist final

Marca cada casilla del checklist de defensa antes de la presentación:

- [ ] Entorno local WordPress levantado e instalado.
- [ ] Tema `resolvecore-theme` activado en el CMS.
- [ ] Landing page cargando correctamente.
- [ ] Enrutamiento y creación de páginas (`docs`, `changelog`, `contacto`) comprobado.
- [ ] Menús y asignación de ubicaciones de menús en el tema correctos.
- [ ] Contenedores de MantisBT activos y con el API REST habilitado.
- [ ] Constantes del token y URL movidas exitosamente a `wp-config.php`.
- [ ] Validación de la persistencia: base de datos sin rastros del token de MantisBT.
- [ ] Incidencias creadas con éxito tras envíos correctos del formulario AJAX.
- [ ] Protección contra spam y rate limit (HTTP 429) verificado y funcionando.
- [ ] Respaldos creados y verificados en formato tarball.

---

## Troubleshooting

| Síntoma | Causa probable | Solución |
|---------|----------------|----------|
| `libaio.so.1 not found` | Falta la biblioteca asíncrona de E/S del sistema. | Instalar la librería mediante `sudo apt install libaio1`. |
| `libncurses.so.5 not found` | Falta la librería heredada de terminal. | Instalar la versión mediante `sudo apt install libncurses5`. |
| `GLIBC_2.3x not found` | Ubuntu o Debian desactualizados para el binario MySQL. | Actualizar el sistema a Ubuntu 22.04 LTS o superior. |
| `wp: orden no encontrada` | WP-CLI no está instalado en el PATH global o el alias está mal configurado. | Instalar `wp-cli.phar` y registrar el alias correspondiente en `~/.bashrc`. |
| `Error establishing DB` | Socket incorrecto o puerto cerrado en LocalWP. | Buscar la ruta del socket de Local y reconfigurar DB_HOST: `wp config set DB_HOST 'localhost:<ruta>/mysqld.sock'`. |
| `MantisBT API 403` | Petición REST rechazada por deshabilitar la directiva REST. | Habilitar la directiva añadiendo `$g_webservice_rest_enabled = ON;` al archivo `config_inc.php`. |
| `API token not found` | Token API no válido, caducado o mal referenciado. | Regenerar el token en el panel de MantisBT y actualizar la constante en `wp-config.php`. |
| `Charset unknown` | Incompatibilidad de set de caracteres con MySQL 8.0 en Mantis. | Utilizar contenedores con motor MySQL 5.7 o MariaDB 10.6. |
| `DNS resolution failed` | El contenedor de docker carece de resolución de red externa. | Añadir directivas de red explícitas (`networks`) en el `docker-compose.yml`. |

---

## Referencias

* **Stack tecnológico justificado:** [`docs/stack-tecnologico.md`](stack-tecnologico.md)
* **Integración detallada con MantisBT:** [`docs/mantis-integration.md`](mantis-integration.md)
* **Esquema de datos de diagnóstico:** [`docs/schema-diagnostico.md`](schema-diagnostico.md)
* **Entornos dev / prod / backup:** [`docs/entornos.md`](entornos.md)
* **Defensa TFG (índice maestro):** [`docs/defensa-tfg.md`](defensa-tfg.md)
