<?php
if ( ! defined( 'ABSPATH' ) ) exit;

// Modo mantenimiento (actívalo cambiando a true)
define( 'RESOLVECORE_MAINTENANCE', false );

function resolvecore_maintenance_mode() {
    if ( RESOLVECORE_MAINTENANCE && ! current_user_can( 'administrator' ) && ! is_admin() ) {
        wp_die( '<html><head><meta charset="utf-8"><title>Mantenimiento</title><style>body{background:#0a0c10;color:#e8eaf0;font-family:system-ui;display:flex;align-items:center;justify-content:center;height:100vh;text-align:center}.loader{width:40px;height:40px;border:3px solid #1a1d24;border-top-color:#00e5a0;border-radius:50%;animation:spin 1s linear infinite}@keyframes spin{to{transform:rotate(360deg)}}</style></head><body><div style="max-width:400px"><div class="loader"></div><h1 style="margin:1.5rem 0 .5rem;font-size:1.5rem;font-weight:700">Volvemos pronto</h1><p style="color:#7a7f8e">ResolveCore está en mantenimiento. Volveremos en breve.</p></div></body></html>', 'Mantenimiento', [ 'response' => 503 ] );
    }
}
if ( RESOLVECORE_MAINTENANCE ) {
    add_action( 'get_header', 'resolvecore_maintenance_mode' );
}

function resolvecore_setup() {
    add_theme_support( 'title-tag' );
    add_theme_support( 'post-thumbnails' );
    add_theme_support( 'html5', ['style','script'] );
}
add_action( 'after_setup_theme', 'resolvecore_setup' );

function resolvecore_scripts() {
    wp_enqueue_style( 'resolvecore-fonts',
        'https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=DM+Sans:wght@300;400;500;600&display=swap',
        [], null );
    wp_enqueue_style( 'resolvecore-style', get_stylesheet_uri(), [], '2.0.0' );
}
add_action( 'wp_enqueue_scripts', 'resolvecore_scripts' );

// Manejo del formulario de contacto via AJAX
function resolvecore_handle_contact() {
    check_ajax_referer( 'resolvecore_contact', 'nonce' );

    // Honeypot anti-spam
    if ( ! empty( $_POST['rc_website'] ) ) {
        wp_send_json_error(['msg' => 'Spam detectado.']);
    }

    $name    = sanitize_text_field( $_POST['rc_name'] ?? '' );
    $email   = sanitize_email( $_POST['rc_email'] ?? '' );
    $message = sanitize_textarea_field( $_POST['rc_message'] ?? '' );
    $type    = sanitize_text_field( $_POST['rc_type'] ?? 'contacto' );

    if ( empty($name) || empty($email) || ! is_email($email) || empty($message) ) {
        wp_send_json_error(['msg' => 'Por favor rellena todos los campos correctamente.']);
    }

    $admin_email = get_option('admin_email');
    $subject = "[ResolveCore] Nuevo mensaje de $type — $name";
    $body  = "Nombre: $name\n";
    $body .= "Email: $email\n";
    $body .= "Tipo: $type\n\n";
    $body .= "Mensaje:\n$message";
    $headers = ['Content-Type: text/plain; charset=UTF-8', "Reply-To: $name <$email>"];

    $sent = wp_mail( $admin_email, $subject, $body, $headers );
    if ( $sent ) {
        wp_send_json_success(['msg' => '¡Mensaje enviado! Te responderemos pronto.']);
    } else {
        wp_send_json_error(['msg' => 'Error al enviar. Inténtalo de nuevo.']);
    }
}
add_action( 'wp_ajax_resolvecore_contact',        'resolvecore_handle_contact' );
add_action( 'wp_ajax_nopriv_resolvecore_contact', 'resolvecore_handle_contact' );
