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
// la base de tokens emitidos — ojo al rotarlo. NO se hardcodea: debe venir
// SIEMPRE de la variable de entorno MANTIS_SALT (ver .env.example; generar con
// `openssl rand -base64 32`). Sin salt no se arranca, por seguridad.
$g_crypto_master_salt = getenv( 'MANTIS_SALT' );
if ( ! $g_crypto_master_salt ) {
	die( 'ResolveCore: falta la variable de entorno MANTIS_SALT (32+ bytes aleatorios). ' .
	     'Genera uno con: openssl rand -base64 32' );
}

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


// ── Branding White-Label ResolveCore (01-06-2026) ───────────────────────────
// Sustituye el logo y el título nativos de MantisBT por los de la empresa y
// oculta el footer «Powered by MantisBT, Copyright © 2000-202x» + enlaces de
// soporte integrados. El logo se copia a la web-root de Mantis con el script
// scripts/server/ops/mantis-branding.sh (cp del logo oscuro del repo WP).
$g_window_title  = 'ResolveCore · Soporte';
$g_logo_image    = 'images/rc-logo-light.png';  // copiado por mantis-branding.sh (claro: login con fondo oscuro)
$g_logo_url      = 'https://resolvecore.website';
// Favicon: variante simplificada multi-tamano (.ico 16/32/48), nitida en la
// pestana (el logo completo se empastaba al reducirse a 16px).
// Copiado por mantis-branding.sh desde favicon.ico.
$g_favicon_image = 'images/rc-favicon.ico';

// Footer: vaciar el copyright propio de Mantis y, vía página de inclusión
// inferior, inyectar CSS que oculta la firma «Powered by» y los enlaces de
// soporte que el core imprime de forma fija.
$g_copyright_statement = '';
$g_show_version        = OFF;
$g_bottom_include_page = __DIR__ . '/rc_footer.php';   // generado por el script
