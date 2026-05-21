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

/**
 * Menú de pie de página por defecto — se usa cuando no hay un menú
 * asignado a la ubicación 'footer' en Apariencia → Menús.
 */
function resolvecore_footer_menu_fallback(): void {
    $links = [
        '/docs/'         => 'Documentación',
        '/changelog/'    => 'Changelog',
        '/fleet-status/' => 'Estado de la flota',
        '/aviso-legal/'  => 'Aviso legal',
        '/privacidad/'   => 'Privacidad',
        '/cookies/'      => 'Cookies',
    ];
    echo '<ul class="rc-footer-links">';
    foreach ( $links as $path => $label ) {
        printf(
            '<li><a href="%s">%s</a></li>',
            esc_url( home_url( $path ) ),
            esc_html( $label )
        );
    }
    echo '</ul>';
}

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
    wp_enqueue_style( 'resolvecore-style', get_stylesheet_uri(), [], '3.1.1' );
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

    // 1) Crear ticket en MantisBT (canal primario)
    $ticket_id = 0;
    $ticket_err = '';
    if ( function_exists( 'rc_mantis_create_ticket' ) ) {
        $ticket = rc_mantis_create_ticket( [
            'name'    => $name,
            'email'   => $email,
            'type'    => $type,
            'message' => $message,
        ] );
        if ( is_wp_error( $ticket ) ) {
            $ticket_err = $ticket->get_error_message();
            error_log( '[resolvecore_handle_contact] Mantis: ' . $ticket_err );
        } elseif ( (int) $ticket > 0 ) {
            $ticket_id = (int) $ticket;
        }
    }

    // 2) Email (canal secundario, no bloquea respuesta)
    $admin_email = get_option( 'admin_email' );
    $subject     = sprintf( '[ResolveCore] %s%s — %s',
        $ticket_id ? "#{$ticket_id} " : '',
        $type,
        $name
    );
    $body  = "Nombre: {$name}\n";
    $body .= "Email: {$email}\n";
    $body .= "Tipo: {$type}\n";
    if ( $ticket_id ) {
        $body .= "Ticket MantisBT: #{$ticket_id}\n";
    }
    $body .= "\nMensaje:\n{$message}\n";
    $headers = [
        'Content-Type: text/plain; charset=UTF-8',
        sprintf( 'Reply-To: %s <%s>', $name, $email ),
    ];
    $mail_sent = @wp_mail( $admin_email, $subject, $body, $headers );

    // 3) Respuesta — éxito si AL MENOS uno funcionó
    if ( ! $ticket_id && ! $mail_sent ) {
        wp_send_json_error( [
            'msg'   => 'No pudimos procesar tu mensaje. Escríbenos directamente a ' . esc_html( $admin_email ) . '.',
            'debug' => $ticket_err ?: 'mail_failed',
        ] );
    }

    $msg = $ticket_id
        ? sprintf( '¡Mensaje recibido! Ticket #%d creado, te responderemos en menos de 2 horas.', $ticket_id )
        : '¡Mensaje recibido! Te responderemos en menos de 2 horas.';

    wp_send_json_success( array_filter( [
        'msg'       => $msg,
        'ticket_id' => $ticket_id ?: null,
    ] ) );
}
add_action( 'wp_ajax_resolvecore_contact',        'resolvecore_handle_contact' );
add_action( 'wp_ajax_nopriv_resolvecore_contact', 'resolvecore_handle_contact' );

/**
 * Consulta el estado de un ticket de MantisBT vía AJAX para mostrar timeline.
 * Solo expone status_id + 4 fases agregadas — no datos personales ni descripción.
 */
function resolvecore_handle_ticket_status() {
    check_ajax_referer( 'resolvecore_contact', 'nonce' );

    $id = absint( $_POST['ticket_id'] ?? 0 );
    if ( $id < 1 ) {
        wp_send_json_error( [ 'msg' => 'ID de ticket inválido.' ] );
    }

    // Rate limit: 30 consultas/hora por IP
    $rate_key = 'rc_status_' . resolvecore_client_ip_hash();
    $attempts = (int) get_transient( $rate_key );
    if ( $attempts >= 30 ) {
        wp_send_json_error( [ 'msg' => 'Demasiadas consultas. Espera un rato.' ] );
    }
    set_transient( $rate_key, $attempts + 1, HOUR_IN_SECONDS );

    if ( ! function_exists( 'rc_mantis_get_api' ) ) {
        wp_send_json_error( [ 'msg' => 'Integración MantisBT no disponible.' ] );
    }
    $api = rc_mantis_get_api();
    if ( ! $api ) {
        wp_send_json_error( [ 'msg' => 'MantisBT no configurado.' ] );
    }

    $res = $api->get_issue( $id );
    if ( is_wp_error( $res ) ) {
        wp_send_json_error( [ 'msg' => 'Ticket no encontrado.' ] );
    }

    $issue = $res['issues'][0] ?? null;
    if ( ! $issue ) {
        wp_send_json_error( [ 'msg' => 'Ticket vacío.' ] );
    }

    $status_name = (string) ( $issue['status']['name'] ?? 'new' );
    $status_id   = (int)    ( $issue['status']['id']   ?? 10 );

    // Mantis status enum → 4 fases UX
    // 10 new · 20 feedback · 30 acknowledged · 40 confirmed · 50 assigned · 80 resolved · 90 closed
    $phase = match ( true ) {
        $status_id >= 80 => 4,
        $status_id >= 50 => 3,
        $status_id >= 30 => 2,
        default          => 1,
    };

    $events = [
        [ 'phase' => 1, 'label' => 'Recibido',       'desc' => 'Ticket creado y en cola de revisión.' ],
        [ 'phase' => 2, 'label' => 'En diagnóstico', 'desc' => 'Técnico analizando el problema.' ],
        [ 'phase' => 3, 'label' => 'En resolución',  'desc' => 'Trabajando en la solución (AnyDesk).' ],
        [ 'phase' => 4, 'label' => 'Resuelto',       'desc' => 'Ticket cerrado. Resumen técnico en la nota del ticket.' ],
    ];

    wp_send_json_success( [
        'ticket_id'  => $id,
        'status'     => $status_name,
        'status_id'  => $status_id,
        'phase'      => $phase,
        'events'     => $events,
        'created_at' => $issue['created_at'] ?? null,
        'updated_at' => $issue['updated_at'] ?? null,
    ] );
}
add_action( 'wp_ajax_resolvecore_ticket_status',        'resolvecore_handle_ticket_status' );
add_action( 'wp_ajax_nopriv_resolvecore_ticket_status', 'resolvecore_handle_ticket_status' );
