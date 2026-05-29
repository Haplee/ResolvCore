<?php
/**
 * Configuración local de MantisBT para ResolveCore.
 *
 * Este fichero NUNCA va al repositorio público con credenciales reales —
 * los valores sensibles se leen de variables de entorno y, si no existen,
 * caen al valor por defecto (solo válido en dev local con Docker).
 *
 * En producción (VPS Ionos) las constantes están sobrescritas a mano por
 * el técnico durante el deploy. Ver scripts/server/deploy-ionos.sh.
 */

// ── Conexión a base de datos ────────────────────────────────────────────────
// 'db' es el nombre del servicio en docker-compose; en VPS se cambia a
// 'localhost'. El usuario y la contraseña se generan en el deploy y se
// guardan en /etc/resolvecore/env.

$g_hostname        = getenv( 'MANTIS_DB_HOST' ) ?: 'db';
$g_db_type         = 'mysqli';
$g_database_name   = getenv( 'MANTIS_DB_NAME' ) ?: 'mantis';
$g_db_username     = getenv( 'MANTIS_DB_USER' ) ?: 'mantis';
$g_db_password     = getenv( 'MANTIS_DB_PASS' ) ?: 'mantis';

// ── Localización ────────────────────────────────────────────────────────────
$g_default_timezone = 'Europe/Madrid';

// ── Seguridad ───────────────────────────────────────────────────────────────
// El salt cifra los tokens de la API REST. Si se pierde se invalida toda
// la base de tokens emitidos — ojo al rotarlo.
$g_crypto_master_salt = getenv( 'MANTIS_SALT' ) ?: 'VYN83XZpOaNhKQ9C3G0J+jePI75myahTH4KW8R8rfao=';

$g_allow_rest_api        = ON;   // necesario para el dashboard del cliente
$g_allow_anonymous_login = OFF;
$g_api_token_lifetime    = 0;    // 0 = no expiran (los gestiona el admin)

$g_signup_use_captcha = OFF;     // simple, alta manual del técnico


// ── Permisos ResolveCore ────────────────────────────────────────────────────
// Criterio: mínimo privilegio. El cliente final es REPORTER (solo abre y
// comenta sus tickets); el técnico es DEVELOPER; manager / admin para
// configuración del proyecto.
// Matriz completa: docs/tecnica/mantis-permisos.md (si existe).

// Adjuntos — necesario que el cliente descargue los PDF de informes.
$g_view_attachments_threshold     = VIEWER;
$g_download_attachments_threshold = VIEWER;
$g_upload_bug_file_threshold      = REPORTER;
$g_delete_attachments_threshold   = DEVELOPER;

// Proyectos — solo admin crea/borra, el manager gestiona el suyo.
$g_manage_project_threshold  = MANAGER;
$g_create_project_threshold  = ADMINISTRATOR;
$g_delete_project_threshold  = ADMINISTRATOR;

// Usuarios — control absoluto solo admin.
$g_manage_user_threshold             = ADMINISTRATOR;
$g_notify_new_user_created_threshold = ADMINISTRATOR;
$g_show_user_email_threshold         = ADMINISTRATOR;

// Por defecto los nuevos registros son clientes (REPORTER).
$g_default_new_account_access_level = REPORTER;
