<?php
// PHP built-in server router for WordPress.
// Serves real static files directly; routes everything else to index.php.

$uri  = parse_url( $_SERVER['REQUEST_URI'], PHP_URL_PATH );
$file = __DIR__ . $uri;

if ( $uri !== '/' && file_exists( $file ) && ! is_dir( $file ) ) {
    return false; // serve the static file as-is
}

require_once __DIR__ . '/index.php';
