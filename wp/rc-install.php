<?php
// Bootstrap installer for ResolveCore local dev.
// Runs wp_install() programmatically, activates theme + rc-mantisbt plugin.
// Run once: php -c ../php.ini wp/rc-install.php

define( 'WP_INSTALLING', true );
define( 'WP_USE_THEMES', false );
require_once __DIR__ . '/wp-load.php';
require_once __DIR__ . '/wp-admin/includes/upgrade.php';
require_once __DIR__ . '/wp-admin/includes/plugin.php';
require_once __DIR__ . '/wp-admin/includes/theme.php';

$site_title = 'ResolveCore (local dev)';
$user_name  = 'admin';
$user_pass  = 'admin';
$user_email = 'admin@example.test';

if ( is_blog_installed() ) {
    echo "Ya instalado. Re-aplicando ajustes...\n";
} else {
    $result = wp_install( $site_title, $user_name, $user_email, true, '', $user_pass, 'es_ES' );
    echo "Instalado. user_id={$result['user_id']}\n";
}

update_option( 'blogname',        $site_title );
update_option( 'blogdescription', 'Solución a tus problemas informáticos.' );
update_option( 'permalink_structure', '/%postname%/' );
update_option( 'timezone_string', 'Europe/Madrid' );

// Activate theme
switch_theme( 'resolvecore-theme' );
echo "Tema activo: " . get_option( 'stylesheet' ) . "\n";

// Activate plugin
$plugin = 'rc-mantisbt/rc-mantisbt.php';
if ( ! is_plugin_active( $plugin ) ) {
    $r = activate_plugin( $plugin );
    if ( is_wp_error( $r ) ) {
        echo "Plugin error: " . $r->get_error_message() . "\n";
    } else {
        echo "Plugin activado: $plugin\n";
    }
} else {
    echo "Plugin ya activo: $plugin\n";
}

// Create pages used by templates
$pages = [
    'inicio'   => [ 'title' => 'Inicio',   'template' => '' ],
    'contacto' => [ 'title' => 'Contacto', 'template' => 'page-contacto.php' ],
    'docs'     => [ 'title' => 'Docs',     'template' => 'page-docs.php' ],
    'changelog'=> [ 'title' => 'Changelog','template' => 'page-changelog.php' ],
];

foreach ( $pages as $slug => $p ) {
    $existing = get_page_by_path( $slug );
    if ( $existing ) {
        echo "Página existe: /$slug/ (ID {$existing->ID})\n";
        continue;
    }
    $id = wp_insert_post( [
        'post_title'   => $p['title'],
        'post_name'    => $slug,
        'post_status'  => 'publish',
        'post_type'    => 'page',
        'post_content' => '',
    ] );
    if ( $p['template'] && $id ) {
        update_post_meta( $id, '_wp_page_template', $p['template'] );
    }
    echo "Página creada: /$slug/ (ID $id)\n";
}

// Front page = inicio
$inicio = get_page_by_path( 'inicio' );
if ( $inicio ) {
    update_option( 'show_on_front', 'page' );
    update_option( 'page_on_front', $inicio->ID );
    echo "Front page = inicio (ID {$inicio->ID})\n";
}

// Flush rewrite rules
flush_rewrite_rules( false );
echo "Permalinks: " . get_option( 'permalink_structure' ) . "\n";

echo "\n--- LISTO ---\n";
echo "URL:      http://localhost:8080\n";
echo "Admin:    http://localhost:8080/wp-admin\n";
echo "Usuario:  $user_name\n";
echo "Pass:     $user_pass\n";
