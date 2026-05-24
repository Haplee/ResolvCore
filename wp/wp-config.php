<?php
// ResolveCore local dev — WordPress config with SQLite drop-in.
// No MySQL needed. DB_* defs are required by WP but unused (SQLite handles persistence).

define( 'DB_NAME',     'wordpress' );
define( 'DB_USER',     'wordpress' );
define( 'DB_PASSWORD', 'wordpress' );
define( 'DB_HOST',     'localhost' );
define( 'DB_CHARSET',  'utf8mb4' );
define( 'DB_COLLATE',  '' );

// Auth keys/salts — dev only.
define( 'AUTH_KEY',         'dev-auth-key-' . hash( 'sha256', __FILE__ ) );
define( 'SECURE_AUTH_KEY',  'dev-secure-auth-key-' . hash( 'sha256', __FILE__ ) );
define( 'LOGGED_IN_KEY',    'dev-logged-in-key-' . hash( 'sha256', __FILE__ ) );
define( 'NONCE_KEY',        'dev-nonce-key-' . hash( 'sha256', __FILE__ ) );
define( 'AUTH_SALT',        'dev-auth-salt-' . hash( 'sha256', __FILE__ ) );
define( 'SECURE_AUTH_SALT', 'dev-secure-auth-salt-' . hash( 'sha256', __FILE__ ) );
define( 'LOGGED_IN_SALT',   'dev-logged-in-salt-' . hash( 'sha256', __FILE__ ) );
define( 'NONCE_SALT',       'dev-nonce-salt-' . hash( 'sha256', __FILE__ ) );

$table_prefix = 'wp_';

define( 'WP_DEBUG',         true );
define( 'WP_DEBUG_LOG',     true );
define( 'WP_DEBUG_DISPLAY', true );
@ini_set( 'display_errors', 1 );
define( 'WP_ENVIRONMENT_TYPE', 'local' );

// rc-mantisbt plugin
define( 'RC_MANTIS_URL',        'http://localhost:8989' );
define( 'RC_MANTIS_TOKEN',      'dev-token-replace-in-real-env' );
define( 'RC_MANTIS_PROJECT_ID', 1 );

define( 'WP_HOME',    'http://localhost:8080' );
define( 'WP_SITEURL', 'http://localhost:8080' );

if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}
require_once ABSPATH . 'wp-settings.php';
