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
    add_theme_support( 'html5', [ 'style', 'script', 'search-form', 'comment-form', 'comment-list', 'gallery', 'caption' ] );
    add_theme_support( 'automatic-feed-links' );
    add_theme_support( 'responsive-embeds' );

    register_nav_menus( [
        'primary' => __( 'Menú principal', 'resolvecore' ),
        'footer'  => __( 'Menú pie de página', 'resolvecore' ),
    ] );
}
add_action( 'after_setup_theme', 'resolvecore_setup' );

// Preconnect a Google Fonts (FCP/LCP boost) — antes de wp_head
function resolvecore_resource_hints( $urls, $relation ) {
    if ( $relation === 'preconnect' ) {
        $urls[] = [ 'href' => 'https://fonts.googleapis.com', 'crossorigin' ];
        $urls[] = [ 'href' => 'https://fonts.gstatic.com',    'crossorigin' ];
    }
    return $urls;
}
add_filter( 'wp_resource_hints', 'resolvecore_resource_hints', 10, 2 );

// Quitar bloat: emojis, jQuery migrate, oEmbed
function resolvecore_disable_emoji() {
    remove_action( 'wp_head', 'print_emoji_detection_script', 7 );
    remove_action( 'admin_print_scripts', 'print_emoji_detection_script' );
    remove_action( 'wp_print_styles', 'print_emoji_styles' );
    remove_action( 'admin_print_styles', 'print_emoji_styles' );
    remove_filter( 'the_content_feed', 'wp_staticize_emoji' );
    remove_filter( 'comment_text_rss', 'wp_staticize_emoji' );
    remove_filter( 'wp_mail', 'wp_staticize_emoji_for_email' );
}
add_action( 'init', 'resolvecore_disable_emoji' );

function resolvecore_dequeue_block_styles() {
    // Tema custom — no usamos block styles del core ni classic-themes.css
    wp_dequeue_style( 'wp-block-library' );
    wp_dequeue_style( 'wp-block-library-theme' );
    wp_dequeue_style( 'global-styles' );
    wp_dequeue_style( 'classic-theme-styles' );
}
add_action( 'wp_enqueue_scripts', 'resolvecore_dequeue_block_styles', 100 );

// Security headers — solo front-end, nunca en admin
function resolvecore_security_headers() {
    if ( is_admin() || headers_sent() ) {
        return;
    }
    header( 'X-Content-Type-Options: nosniff' );
    header( 'Referrer-Policy: strict-origin-when-cross-origin' );
    header( 'Permissions-Policy: geolocation=(), microphone=(), camera=()' );
    header( 'X-Frame-Options: SAMEORIGIN' );
}
add_action( 'send_headers', 'resolvecore_security_headers' );

function resolvecore_favicon() {
    $uri = get_template_directory_uri();
    echo '<link rel="icon" type="image/svg+xml" href="' . esc_url( $uri . '/assets/logo/resolvcore-icon.svg' ) . '">' . "\n";
    echo '<link rel="icon" type="image/png" href="' . esc_url( $uri . '/assets/logo/resolvcore-icon.png' ) . '" sizes="32x32">' . "\n";
    echo '<link rel="apple-touch-icon" href="' . esc_url( $uri . '/assets/logo/resolvcore-icon.png' ) . '">' . "\n";
}
add_action( 'wp_head', 'resolvecore_favicon' );

function resolvecore_scripts() {
    wp_enqueue_style( 'resolvecore-fonts',
        'https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=DM+Sans:wght@300;400;500;600&display=swap',
        [], null );
    wp_enqueue_style( 'resolvecore-style', get_stylesheet_uri(), [], '2.0.1' );
}
add_action( 'wp_enqueue_scripts', 'resolvecore_scripts' );

// Defer scripts no críticos (todos excepto jQuery core si lo hay)
function resolvecore_defer_scripts( $tag, $handle ) {
    if ( is_admin() ) return $tag;
    $skip = [ 'jquery-core', 'jquery-migrate' ];
    if ( in_array( $handle, $skip, true ) ) return $tag;
    if ( strpos( $tag, ' defer' ) !== false || strpos( $tag, ' async' ) !== false ) return $tag;
    return str_replace( ' src=', ' defer src=', $tag );
}
add_filter( 'script_loader_tag', 'resolvecore_defer_scripts', 10, 2 );

// Hash de IP estable, IPv4/IPv6, robusto bajo proxies
function resolvecore_client_ip_hash(): string {
    $ip = $_SERVER['REMOTE_ADDR'] ?? '';
    // No confiar en X-Forwarded-For salvo whitelist; aquí solo REMOTE_ADDR para integridad.
    if ( ! filter_var( $ip, FILTER_VALIDATE_IP ) ) {
        $ip = '0.0.0.0';
    }
    return hash( 'sha256', $ip . wp_salt( 'auth' ) );
}

// Manejo del formulario de contacto via AJAX
function resolvecore_handle_contact() {
    check_ajax_referer( 'resolvecore_contact', 'nonce' );

    // Honeypot anti-spam
    if ( ! empty( $_POST['rc_website'] ) ) {
        wp_send_json_error( [ 'msg' => 'Spam detectado.' ] );
    }

    // Rate limiting: máx. 3 envíos por IP por hora
    $rate_key = 'rc_contact_' . resolvecore_client_ip_hash();
    $attempts = (int) get_transient( $rate_key );
    if ( $attempts >= 3 ) {
        wp_send_json_error( [ 'msg' => 'Demasiados intentos. Espera un rato antes de volver a enviar.' ] );
    }
    set_transient( $rate_key, $attempts + 1, HOUR_IN_SECONDS );

    $name    = sanitize_text_field( wp_unslash( $_POST['rc_name']    ?? '' ) );
    $email   = sanitize_email(      wp_unslash( $_POST['rc_email']   ?? '' ) );
    $message = sanitize_textarea_field( wp_unslash( $_POST['rc_message'] ?? '' ) );
    $type    = sanitize_text_field( wp_unslash( $_POST['rc_type']    ?? 'contacto' ) );

    // Whitelist tipo
    $allowed_types = [ 'soporte', 'bug', 'colaboracion', 'licencia', 'otro', 'contacto' ];
    if ( ! in_array( $type, $allowed_types, true ) ) {
        $type = 'contacto';
    }

    if ( $name === '' || $email === '' || ! is_email( $email ) || $message === '' ) {
        wp_send_json_error( [ 'msg' => 'Por favor rellena todos los campos correctamente.' ] );
    }
    if ( mb_strlen( $message ) > 500 ) {
        wp_send_json_error( [ 'msg' => 'El mensaje supera 500 caracteres.' ] );
    }

    $admin_email = get_option( 'admin_email' );
    $subject = sprintf( '[ResolveCore] Nuevo mensaje de %s — %s', $type, $name );
    $body  = "Nombre: {$name}\n";
    $body .= "Email: {$email}\n";
    $body .= "Tipo: {$type}\n\n";
    $body .= "Mensaje:\n{$message}";
    $headers = [
        'Content-Type: text/plain; charset=UTF-8',
        sprintf( 'Reply-To: %s <%s>', $name, $email ),
    ];

    $sent = wp_mail( $admin_email, $subject, $body, $headers );
    if ( ! $sent ) {
        wp_send_json_error( [ 'msg' => 'Error al enviar. Inténtalo de nuevo.' ] );
    }

    $response = [ 'msg' => '¡Mensaje enviado! Te responderemos pronto.' ];

    if ( function_exists( 'rc_mantis_create_ticket' ) ) {
        $ticket_id = rc_mantis_create_ticket( [
            'name'    => $name,
            'email'   => $email,
            'type'    => $type,
            'message' => $message,
        ] );
        if ( ! is_wp_error( $ticket_id ) && $ticket_id > 0 ) {
            $response['ticket_id'] = (int) $ticket_id;
            $response['msg']       = sprintf( '¡Mensaje enviado! Ticket #%d creado. Te responderemos pronto.', (int) $ticket_id );
        }
    }

    wp_send_json_success( $response );
}
add_action( 'wp_ajax_resolvecore_contact',        'resolvecore_handle_contact' );
add_action( 'wp_ajax_nopriv_resolvecore_contact', 'resolvecore_handle_contact' );
