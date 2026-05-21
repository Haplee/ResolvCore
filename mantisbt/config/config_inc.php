<?php
$g_hostname               = 'db';
$g_db_type                = 'mysqli';
$g_database_name          = 'mantis';
$g_db_username            = 'mantis';
$g_db_password            = 'mantis';

$g_default_timezone       = 'Europe/Madrid';

$g_crypto_master_salt     = 'VYN83XZpOaNhKQ9C3G0J+jePI75myahTH4KW8R8rfao=';
$g_webservice_rest_enabled = ON;
$g_allow_anonymous_login = OFF;
$g_api_token_lifetime = 0;

# ── Gestión de permisos ResolveCore ──────────────────────────
# Criterio: mínimo privilegio. Cliente = REPORTER, técnico = DEVELOPER.
# Matriz completa documentada en docs/tecnica/mantis-permisos.md

# Adjuntos
$g_view_attachments_threshold     = VIEWER;
$g_download_attachments_threshold = VIEWER;
$g_upload_bug_file_threshold      = REPORTER;
$g_delete_attachments_threshold   = DEVELOPER;

# Filtros
$g_stored_query_create_threshold        = DEVELOPER;
$g_stored_query_create_shared_threshold = MANAGER;

# Proyectos
$g_manage_project_threshold  = MANAGER;
$g_project_user_threshold    = MANAGER;
$g_private_project_threshold = DEVELOPER;
$g_create_project_threshold  = ADMINISTRATOR;
$g_delete_project_threshold  = ADMINISTRATOR;

# Campos personalizados
$g_custom_field_link_threshold    = MANAGER;
$g_manage_custom_fields_threshold = ADMINISTRATOR;

# Otros
$g_view_summary_threshold            = DEVELOPER;
$g_add_profile_threshold             = DEVELOPER;
$g_show_user_email_threshold         = ADMINISTRATOR;
$g_manage_user_threshold             = ADMINISTRATOR;
$g_notify_new_user_created_threshold = ADMINISTRATOR;

# "Usar filtros guardados" y "Enviar recordatorios" se ajustan desde
# Gestionar → Configuración → Gestión de permisos (sin constante global fiable).
