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
    wp_enqueue_style( 'resolvecore-style', get_stylesheet_uri(), [], '3.1.3' );
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

    // 2) Email al técnico (canal secundario, no bloquea respuesta)
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

    // 2b) Email de confirmación al cliente — incidencia + seguimiento.
    //     Canal informativo: si falla, solo se registra; no altera la respuesta.
    resolvecore_send_client_confirmation( $email, $name, $ticket_id, $type, $message );

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
        'msg'          => $msg,
        'ticket_id'    => $ticket_id ?: null,
        'ticket_token' => $ticket_id ? resolvecore_ticket_token( $ticket_id ) : null,
    ] ) );
}
add_action( 'wp_ajax_resolvecore_contact',        'resolvecore_handle_contact' );
add_action( 'wp_ajax_nopriv_resolvecore_contact', 'resolvecore_handle_contact' );

/**
 * Token de seguimiento derivado del ID de ticket.
 *
 * Sin él, el parámetro `?rc_ticket=N` sería enumerable: cualquiera podría
 * consultar el estado de tickets ajenos incrementando el número. El token es
 * un HMAC-SHA256 con `wp_salt('auth')` — determinista (no requiere almacenarlo)
 * e imposible de falsificar sin la salt del sitio.
 */
function resolvecore_ticket_token( int $id ): string {
    return substr( hash_hmac( 'sha256', 'rc_ticket_' . $id, wp_salt( 'auth' ) ), 0, 20 );
}

/**
 * Envía al cliente un correo HTML de confirmación con el número de incidencia
 * y el enlace de seguimiento en tiempo real.
 *
 * Canal informativo: si wp_mail falla solo se registra en el log — nunca
 * bloquea ni altera la respuesta AJAX al usuario.
 *
 * @param string $email      Correo del cliente (ya validado en el handler).
 * @param string $name       Nombre del cliente (ya saneado).
 * @param int    $ticket_id  ID de MantisBT, o 0 si no se pudo crear.
 * @param string $type       Tipo de solicitud (whitelist del handler).
 * @param string $message    Mensaje del cliente (ya saneado).
 * @return bool  true si wp_mail aceptó el envío.
 */
function resolvecore_send_client_confirmation( string $email, string $name, int $ticket_id, string $type, string $message ): bool {
    if ( ! is_email( $email ) ) {
        return false;
    }

    $type_labels = [
        'soporte'      => 'Soporte técnico',
        'bug'          => 'Reporte de error',
        'colaboracion' => 'Colaboración',
        'licencia'     => 'Licencia',
        'otro'         => 'Consulta general',
        'contacto'     => 'Consulta general',
    ];
    $type_label = $type_labels[ $type ] ?? 'Consulta general';

    // Las 4 fases coinciden con el timeline de resolvecore_handle_ticket_status().
    $fases = [
        [ 'Recibido',       'Ticket creado y en cola de revisión.' ],
        [ 'En diagnóstico', 'El técnico analiza el problema.' ],
        [ 'En resolución',  'Trabajo sobre la solución mediante AnyDesk.' ],
        [ 'Resuelto',       'Ticket cerrado con resumen técnico adjunto.' ],
    ];
    $fases_html = '';
    foreach ( $fases as $i => $f ) {
        $fases_html .=
              '<tr>'
            . '<td style="width:28px;padding:5px 0;vertical-align:top;">'
            . '<span style="display:inline-block;width:22px;height:22px;line-height:22px;'
            . 'text-align:center;border-radius:50%;background:#1a1d24;border:1px solid #2a2e38;'
            . 'color:#00e5a0;font-family:monospace;font-size:11px;font-weight:700;">' . ( $i + 1 ) . '</span>'
            . '</td>'
            . '<td style="padding:5px 0 5px 10px;">'
            . '<div style="color:#e8eaed;font-size:13px;font-weight:600;">' . esc_html( $f[0] ) . '</div>'
            . '<div style="color:#7a7f8e;font-size:12px;">' . esc_html( $f[1] ) . '</div>'
            . '</td>'
            . '</tr>';
    }

    $track_url = $ticket_id
        ? add_query_arg( [
            'rc_ticket' => $ticket_id,
            'rc_t'      => resolvecore_ticket_token( $ticket_id ),
        ], home_url( '/' ) ) . '#contacto'
        : '';

    $subject = $ticket_id
        ? sprintf( 'ResolveCore — Incidencia #%d registrada', $ticket_id )
        : 'ResolveCore — Hemos recibido tu solicitud';

    $e_name = esc_html( $name );
    $e_type = esc_html( $type_label );
    $e_msg  = nl2br( esc_html( $message ) );

    // Bloque tarjeta de incidencia (solo si hay ticket).
    $ticket_block = '';
    if ( $ticket_id ) {
        $ticket_block =
              '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" '
            . 'style="margin:0 0 24px;border:1px solid rgba(0,229,160,.3);border-radius:10px;'
            . 'background:#0f1f1a;">'
            . '<tr><td style="padding:18px 22px;">'
            . '<div style="color:#7a7f8e;font-family:monospace;font-size:10px;letter-spacing:.12em;'
            . 'text-transform:uppercase;">Número de incidencia</div>'
            . '<div style="color:#00e5a0;font-family:monospace;font-size:30px;font-weight:700;'
            . 'margin:4px 0 8px;">#' . (int) $ticket_id . '</div>'
            . '<div style="color:#c5c8cf;font-size:13px;">Categoría: <strong>' . $e_type . '</strong></div>'
            . '</td></tr></table>';
    }

    // Botón de seguimiento (solo si hay ticket).
    $track_block = '';
    if ( $track_url ) {
        $track_block =
              '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:8px 0 4px;">'
            . '<tr><td style="border-radius:8px;background:#00e5a0;">'
            . '<a href="' . esc_url( $track_url ) . '" '
            . 'style="display:inline-block;padding:13px 26px;color:#05140f;font-size:14px;'
            . 'font-weight:700;text-decoration:none;font-family:Arial,sans-serif;">'
            . 'Ver estado en tiempo real &rarr;</a>'
            . '</td></tr></table>';
    }

    $intro = $ticket_id
        ? 'Tu solicitud ha quedado registrada con el número de incidencia que ves abajo. '
            . 'Un técnico la revisará en menos de 2 horas.'
        : 'Hemos recibido tu solicitud y un técnico la revisará en menos de 2 horas. '
            . 'En breve recibirás el número de incidencia.';

    $html =
          '<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">'
        . '<meta name="viewport" content="width=device-width,initial-scale=1"></head>'
        . '<body style="margin:0;padding:0;background:#0a0c10;">'
        . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#0a0c10;">'
        . '<tr><td align="center" style="padding:28px 14px;">'

        . '<table role="presentation" width="600" cellpadding="0" cellspacing="0" '
        . 'style="max-width:600px;width:100%;background:#111318;border:1px solid #1f232c;border-radius:14px;overflow:hidden;">'

        // Cabecera
        . '<tr><td style="padding:22px 32px;background:#0a0c10;border-bottom:1px solid #1f232c;">'
        . '<span style="color:#f5f6f8;font-family:monospace;font-size:18px;font-weight:700;">ResolveCore</span>'
        . '<span style="color:#00e5a0;font-family:monospace;font-size:11px;letter-spacing:.12em;'
        . 'float:right;padding-top:6px;">// SOPORTE</span>'
        . '</td></tr>'

        // Cuerpo
        . '<tr><td style="padding:32px;">'
        . '<h1 style="margin:0 0 6px;color:#f5f6f8;font-family:Arial,sans-serif;font-size:21px;">'
        . 'Hemos recibido tu solicitud</h1>'
        . '<p style="margin:0 0 20px;color:#c5c8cf;font-family:Arial,sans-serif;font-size:14px;'
        . 'line-height:1.6;">Hola <strong>' . $e_name . '</strong>, gracias por contactar con '
        . 'ResolveCore. ' . esc_html( $intro ) . '</p>'

        . $ticket_block

        // Mensaje del cliente
        . '<div style="color:#7a7f8e;font-family:monospace;font-size:10px;letter-spacing:.12em;'
        . 'text-transform:uppercase;margin-bottom:6px;">// Tu mensaje</div>'
        . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" '
        . 'style="margin:0 0 24px;border-left:3px solid #2a2e38;background:#0e1014;border-radius:0 8px 8px 0;">'
        . '<tr><td style="padding:14px 18px;color:#c5c8cf;font-family:Arial,sans-serif;'
        . 'font-size:13px;line-height:1.6;">' . $e_msg . '</td></tr></table>'

        // Seguimiento
        . '<div style="color:#7a7f8e;font-family:monospace;font-size:10px;letter-spacing:.12em;'
        . 'text-transform:uppercase;margin-bottom:10px;">// Seguimiento de la incidencia</div>'
        . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" '
        . 'style="margin:0 0 22px;">' . $fases_html . '</table>'

        . $track_block

        . '</td></tr>'

        // Pie
        . '<tr><td style="padding:18px 32px;background:#0a0c10;border-top:1px solid #1f232c;">'
        . '<p style="margin:0;color:#5a5f6c;font-family:Arial,sans-serif;font-size:11px;line-height:1.6;">'
        . 'Este correo es automático. Para añadir información a la incidencia, '
        . 'responde directamente a este mensaje.<br>'
        . 'ResolveCore — Solución a tus problemas informáticos.</p>'
        . '</td></tr>'

        . '</table></td></tr></table></body></html>';

    // Versión texto plano para multipart/alternative: mejora la entregabilidad
    // y da una alternativa legible si el cliente no renderiza HTML.
    $text  = "Hemos recibido tu solicitud\n\n";
    $text .= 'Hola ' . $name . ', gracias por contactar con ResolveCore. ' . $intro . "\n\n";
    if ( $ticket_id ) {
        $text .= 'Número de incidencia: #' . (int) $ticket_id . "\n";
        $text .= 'Categoría: ' . $type_label . "\n\n";
    }
    $text .= "Tu mensaje:\n" . $message . "\n\n";
    $text .= "Seguimiento de la incidencia:\n";
    foreach ( $fases as $i => $f ) {
        $text .= '  ' . ( $i + 1 ) . '. ' . $f[0] . ' — ' . $f[1] . "\n";
    }
    if ( $track_url ) {
        $text .= "\nVer estado en tiempo real:\n" . $track_url . "\n";
    }
    $text .= "\n—\nEste correo es automático. Para añadir información a la incidencia, "
        . "responde directamente a este mensaje.\n"
        . "ResolveCore — Solución a tus problemas informáticos.\n";

    $headers = [
        'Content-Type: text/html; charset=UTF-8',
        'Reply-To: ' . get_option( 'admin_email' ),
        'List-Unsubscribe: <mailto:' . get_option( 'admin_email' ) . '?subject=baja-resolvecore>',
    ];

    // Adjunta la parte de texto plano como AltBody solo para este envío.
    $alt_body = static function ( $phpmailer ) use ( $text ) {
        $phpmailer->AltBody = $text;
    };
    add_action( 'phpmailer_init', $alt_body );
    $sent = @wp_mail( $email, $subject, $html, $headers );
    remove_action( 'phpmailer_init', $alt_body );

    if ( ! $sent ) {
        error_log( '[resolvecore] confirmacion cliente: wp_mail devolvio false' );
    }
    return (bool) $sent;
}

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

    // Token anti-enumeración: impide consultar el estado de tickets ajenos
    // cambiando el número. Lo emite resolvecore_handle_contact() y el correo.
    $token = sanitize_text_field( wp_unslash( $_POST['token'] ?? '' ) );
    if ( ! hash_equals( resolvecore_ticket_token( $id ), $token ) ) {
        wp_send_json_error( [ 'msg' => 'Enlace de seguimiento no válido.' ] );
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
