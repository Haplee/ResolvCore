# Estrategia de Backup del Entorno Web

> **Autor:** Francisco Vidal Mateo · TFG ASIR 2024/25
> **Estado:** Primera versión (Definición teórica y práctica)

---

## 1. Contexto

Actualmente el entorno de WordPress de **ResolveCore** se encuentra en una primera versión Beta ("Aceptable mínimo") alojado de forma local (vía LocalWP) y con proyección a migrar a un VPS de producción. La pérdida de la página web implica perder el formulario AJAX que conecta con MantisBT, parando toda la operativa de soporte.

Por ello, se definen tres opciones de contingencia y backup ordenadas por nivel de complejidad y escenario ASIR.

---

## 2. Opciones de Backup Evaluadas

### Opción A: Backup Integral a Nivel de Servidor (VPS / Producción Final)

Esta es la solución más robusta y agnóstica para cuando el WordPress se encuentre en un VPS propio corriendo con Nginx y PHP-FPM. Consiste en realizar una copia directa de los archivos físicos y un volcado de la base de datos MariaDB.

**Mecanismo:**
- **Base de datos:** Ejecución diaria de `mysqldump -u root -p[PASS] resolvecore_wp > /backups/db/wp_$(date +%F).sql`
- **Archivos:** Uso de `rsync` o `tar` del directorio `/var/www/resolvecore/` hacia un almacenamiento secundario (NFS, S3, o FTP).
- **Automatización:** Tarea `cron` en el sistema (`crontab -e`).

**Ventajas:** Copia bit a bit del estado exacto del servidor. No afecta al rendimiento del entorno web porque se ejecuta a nivel de OS. Independiente de vulnerabilidades en plugins de WordPress.

---

### Opción B: Backup Automatizado vía Plugin (Duplicator / UpdraftPlus)

Recomendado para entornos de hosting compartido o donde no se desee depender enteramente del acceso SSH/root para la recuperación.

**UpdraftPlus (Uso Programado):**
- Realiza copias incrementales y completas de: Base de datos, Plugins, Temas (incluyendo `resolvecore-theme`) y el directorio Uploads.
- **Destino:** Permite enviar el archivo encriptado directamente a Google Drive, Dropbox o un Bucket de AWS S3.
- **Frecuencia propuesta:** Semanal para archivos, diaria para BBDD.

**Duplicator (Migración y Snapshots puntuales):**
- Genera un archivo "Installer.php" junto con un paquete `.zip`. 
- **Caso de uso:** Ideal para mover la beta actual desde LocalWP al VPS de producción de forma limpia.

**Ventajas:** Interfaz gráfica accesible. Facilita la recuperación de un desastre (Disaster Recovery) en menos de 10 minutos sin tocar comandos SQL.

---

### Opción C: Snapshots del Entorno de Desarrollo (LocalWP)

Es la estrategia que se está utilizando actualmente durante la fase de desarrollo del TFG.

**Mecanismo:**
- El código fuente del tema (`resolvecore-theme`) y el plugin de conexión (`rc-mantisbt`) ya están versionados en el repositorio de **Git/GitHub**.
- **Base de datos local:** LocalWP permite exportar el sitio completo (archivos + BBDD) a un archivo `.zip` con un solo clic.

**Ventajas:** Al tener el código en GitHub, la base de datos es la única pieza crítica. Exportar el sitio desde LocalWP cada viernes garantiza la seguridad semanal del progreso.

---

## 3. Conclusión y Estrategia Adoptada

Para el alcance del TFG, la estrategia se divide en dos fases:
1. **Fase Actual (Beta en LocalWP):** Versionado del código en GitHub y exportación manual semanal del `.zip` del entorno LocalWP.
2. **Fase de Producción (VPS):** Implementación de la **Opción A** (Script Bash con `mysqldump` y `tar` enviado a un servidor de copias por `scp`) combinada con **UpdraftPlus** para mantener una redundancia en nube (Google Drive).
