# ResolveCore — Entornos y Backups

> Documentación de infraestructura de los entornos de desarrollo y producción, y políticas de copia de seguridad.  
> **Autor:** Francisco Vidal Mateo · TFG ASIR 25/26

---

## 1. Entorno de Desarrollo (Dev)

Para el desarrollo local del tema `resolvecore-theme` y la integración con el plugin de MantisBT, se utiliza un entorno encapsulado.

### Opción elegida: LocalWP (Local by Flywheel)

**Justificación:** Proporciona un entorno completo (NGINX, PHP 8.1+, MySQL/MariaDB) con gestión de SSL local automático y MailHog para pruebas de correos (crítico para MantisBT y notificaciones web) sin contaminar el SO del técnico con servicios sueltos.

### Reproducibilidad y despliegue local

Para replicar el entorno de desarrollo:

1.  Descargar e instalar [LocalWP](https://localwp.com/).
2.  Crear nuevo sitio:
    *   **Nombre:** ResolveCore Dev
    *   **Entorno:** Custom (PHP 8.2, NGINX, MariaDB 10.6) — *Mismo stack que producción VPS.*
    *   **WordPress admin:** `admin` / `resolvecore-dev` (credenciales de prueba efímeras).
3.  Acceder a la carpeta del sitio (ej. `~/Local Sites/resolvecore-dev/app/public/wp-content/themes/`).
4.  Ejecutar git clone (o symlink) de la carpeta del tema del repositorio:
    ```bash
    ln -s /path/to/proyecto/ResolvCore/wordpress/resolvecore-theme ./resolvecore-theme
    ```
5.  **URL de acceso local:** `https://resolvecore-dev.local`

### Entorno de variables (.env.development)

```env
WP_ENVIRONMENT_TYPE=development
WP_DEBUG=true
MANTIS_API_URL=http://localhost:8080/api/rest/
MANTIS_API_TOKEN=mock_token_for_dev_only
```

---

## 2. Entorno de Producción (Prod)

El entorno de producción se divide en el frontal público (WordPress) y el backend de gestión (MantisBT).

### Entorno Productivo Unificado (WordPress + MantisBT)

*   **Host actual:** VPS Linux en IONOS (Plan S+).
*   **Sistema Operativo:** Ubuntu 22.04 LTS.
*   **Servicios:** Nginx, PHP-FPM 8.2, MariaDB.
*   **URL WordPress:** `https://resolvecore.website`
*   **URL MantisBT:** `https://mantis.resolvecore.website`
*   **Correo Corporativo:** `tecnico@resolvecore.website`
*   **Gestión:** Acceso root vía SSH.
*   **Estado:** Operativo y público.

### Entorno de variables (.env.production.example)

Este archivo se mantendrá en el servidor VPS, nunca en el repositorio:

```env
WP_ENVIRONMENT_TYPE=production
WP_DEBUG=false
MANTIS_API_URL=https://support.resolvecore.com/api/rest/
MANTIS_API_TOKEN=your_secure_mantis_token_here
DB_NAME=resolvecore_prod
DB_USER=resolvecore_usr
DB_PASSWORD=secret_password_prod
```

---

## 3. Política de Backups y Recuperación Ante Desastres (DR)

### Backup del Entorno Web (WordPress)

Para garantizar la integridad del portal público y el catálogo de servicios, se aplica la regla de backup 3-2-1 apoyada en el plugin **UpdraftPlus**.

**Configuración en Producción:**

1.  **Frecuencia automática:** Semanal para archivos (Tema, Plugins, Uploads) y Diaria para Base de Datos.
2.  **Destino externo (Cloud):** Google Drive asociado a la cuenta de administración de ResolveCore.
3.  **Retención:** Conservar los últimos 4 backups (1 mes de cobertura).

**Exportación Manual (DRC Extremo):**

Antes de cada actualización mayor de WordPress o despliegue crítico de la web para la defensa del TFG, el administrador debe:

```bash
# Exportar base de datos limpia local/remota vía wp-cli
wp db export resolvecore_backup_$(date +%Y%m%d).sql

# Comprimir wp-content (evita empaquetar core innecesario)
tar -czvf resolvecore_wpcontent_$(date +%Y%m%d).tar.gz wp-content/
```

### Backup del Backend (MantisBT)

Dado que MantisBT almacenará datos sensibles (AnyDesk IDs, información de vulnerabilidades), el backup debe realizarse a nivel de SO en el VPS.

1.  **Dump de BBDD MariaDB:** Cronjob nocturno (`mysqldump`) para extraer la base de datos `bugtracker`.
2.  **Archivos adjuntos:** Sincronización mediante `rsync` del directorio de adjuntos si se almacenan en disco en lugar de base de datos.
3.  **Destino:** Almacenamiento S3 compatible (ej. AWS S3 free tier, Cloudflare R2) para copias externas.

### Restauración (RTO / RPO)

*   **RPO (Recovery Point Objective):** Máxima pérdida de datos aceptable de 24 horas (gracias a copias nocturnas automáticas).
*   **RTO (Recovery Time Objective):** Tiempo de recuperación estimado < 2 horas disponiendo de acceso root al VPS y las copias descargadas de Google Drive/S3.
