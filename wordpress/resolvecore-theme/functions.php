<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// ── Descarga segura de ficheros para área técnicos ─────────────────────────
// Añade en wp-config.php: define('RC_DOWNLOADS_PATH', '/opt/resolvecore-downloads');
function rc_handle_technician_download(): void {
	if ( ! isset( $_GET['rc_download'] ) ) {
		return;
	}

	// Requiere login
	if ( ! is_user_logged_in() ) {
		wp_redirect( wp_login_url( get_permalink() ) );
		exit;
	}

	// Solo editores/administradores (roles técnico)
	if ( ! current_user_can( 'editor' ) && ! current_user_can( 'administrator' ) ) {
		wp_die( 'Sin permiso para descargar.', 'Sin acceso', array( 'response' => 403 ) );
	}

	$key = sanitize_key( wp_unslash( $_GET['rc_download'] ) );

	$allowed = array(
		'windows' => array(
			'file' => 'install-servicios.ps1',
			'type' => 'application/octet-stream',
		),
		'linux'   => array(
			'file' => 'install-servicios.sh',
			'type' => 'application/octet-stream',
		),
		'kit'     => array(
			'file' => 'resolvecore-kit.zip',
			'type' => 'application/zip',
		),
	);

	if ( ! array_key_exists( $key, $allowed ) ) {
		wp_die( 'Descarga no válida.', 'Error', array( 'response' => 404 ) );
	}

	$downloads_dir = defined( 'RC_DOWNLOADS_PATH' )
		? RC_DOWNLOADS_PATH
		: '/opt/resolvecore-downloads';

	$filepath = trailingslashit( $downloads_dir ) . $allowed[ $key ]['file'];

	if ( ! file_exists( $filepath ) ) {
		wp_die( 'Fichero no disponible en este momento.', 'No encontrado', array( 'response' => 404 ) );
	}

	// Log de descarga (error_log + tabla rc_download_log)
	$user = wp_get_current_user();
	$ip   = sanitize_text_field( wp_unslash( $_SERVER['REMOTE_ADDR'] ?? '' ) );
	error_log( sprintf(
		'[ResolveCore] Descarga: %s | usuario: %s | IP: %s | %s',
		esc_html( $key ),
		esc_html( $user->user_login ),
		$ip,
		gmdate( 'Y-m-d H:i:s' )
	) );
	rc_log_download( $key, $user->user_login, $ip );

	header( 'Content-Type: ' . $allowed[ $key ]['type'] );
	header( 'Content-Disposition: attachment; filename="' . basename( $filepath ) . '"' );
	header( 'Content-Length: ' . filesize( $filepath ) );
	header( 'Cache-Control: no-cache, no-store, must-revalidate' );
	header( 'Pragma: no-cache' );
	header( 'X-Content-Type-Options: nosniff' );
	readfile( $filepath ); // phpcs:ignore WordPress.WP.AlternativeFunctions.file_system_read_readfile
	exit;
}
add_action( 'template_redirect', 'rc_handle_technician_download', 5 );

// Ocultar admin bar en frontend para técnicos (editores) — solo admin la ve
function rc_hide_adminbar_for_editors(): void {
	if ( is_user_logged_in() && ! current_user_can( 'administrator' ) ) {
		show_admin_bar( false );
	}
}
add_action( 'after_setup_theme', 'rc_hide_adminbar_for_editors' );

// Modo mantenimiento (actívalo cambiando a true)
define( 'RESOLVECORE_MAINTENANCE', false );

function resolvecore_maintenance_mode() {
	if ( RESOLVECORE_MAINTENANCE && ! current_user_can( 'administrator' ) && ! is_admin() ) {
		wp_die( '<html><head><meta charset="utf-8"><title>Mantenimiento</title><style>body{background:#0a0c10;color:#e8eaf0;font-family:system-ui;display:flex;align-items:center;justify-content:center;height:100vh;text-align:center}.loader{width:40px;height:40px;border:3px solid #1a1d24;border-top-color:#00e5a0;border-radius:50%;animation:spin 1s linear infinite}@keyframes spin{to{transform:rotate(360deg)}}</style></head><body><div style="max-width:400px"><div class="loader"></div><h1 style="margin:1.5rem 0 .5rem;font-size:1.5rem;font-weight:700">Volvemos pronto</h1><p style="color:#7a7f8e">ResolveCore está en mantenimiento. Volveremos en breve.</p></div></body></html>', 'Mantenimiento', array( 'response' => 503 ) );
	}
}
if ( RESOLVECORE_MAINTENANCE ) {
	add_action( 'get_header', 'resolvecore_maintenance_mode' );
}

function resolvecore_setup() {
	add_theme_support( 'title-tag' );
	add_theme_support( 'post-thumbnails' );
	add_theme_support( 'html5', array( 'style', 'script', 'search-form', 'comment-form', 'comment-list', 'gallery', 'caption' ) );
	add_theme_support( 'automatic-feed-links' );
	add_theme_support( 'responsive-embeds' );

	register_nav_menus(
		array(
			'primary' => __( 'Menú principal', 'resolvecore' ),
			'footer'  => __( 'Menú pie de página', 'resolvecore' ),
		)
	);
}
add_action( 'after_setup_theme', 'resolvecore_setup' );

/**
 * Menú de pie de página por defecto — se usa cuando no hay un menú
 * asignado a la ubicación 'footer' en Apariencia → Menús.
 */
function resolvecore_footer_menu_fallback(): void {
	$links = array(
		'/docs/'         => 'Documentación',
		'/changelog/'    => 'Changelog',
		'/fleet-status/' => 'Estado de la flota',
		'/aviso-legal/'  => 'Aviso legal',
		'/privacidad/'   => 'Privacidad',
		'/cookies/'      => 'Cookies',
	);
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
		$urls[] = array(
			'href' => 'https://fonts.googleapis.com',
			'crossorigin',
		);
		$urls[] = array(
			'href' => 'https://fonts.gstatic.com',
			'crossorigin',
		);
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
	wp_enqueue_style(
		'resolvecore-fonts',
		'https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=DM+Sans:wght@300;400;500;600&display=swap',
		array(),
		null
	);
	wp_enqueue_style( 'resolvecore-style', get_stylesheet_uri(), array(), '3.1.3' );
}
add_action( 'wp_enqueue_scripts', 'resolvecore_scripts' );

// Defer scripts no críticos (todos excepto jQuery core si lo hay)
function resolvecore_defer_scripts( $tag, $handle ) {
	if ( is_admin() ) {
		return $tag;
	}
	$skip = array( 'jquery-core', 'jquery-migrate' );
	if ( in_array( $handle, $skip, true ) ) {
		return $tag;
	}
	if ( strpos( $tag, ' defer' ) !== false || strpos( $tag, ' async' ) !== false ) {
		return $tag;
	}
	return str_replace( ' src=', ' defer src=', $tag );
}
add_filter( 'script_loader_tag', 'resolvecore_defer_scripts', 10, 2 );

// Hash de IP estable, IPv4/IPv6, robusto bajo proxies
function resolvecore_client_ip_hash(): string {
	$ip = isset( $_SERVER['REMOTE_ADDR'] ) ? sanitize_text_field( wp_unslash( $_SERVER['REMOTE_ADDR'] ) ) : '';
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
		wp_send_json_error( array( 'msg' => 'Spam detectado.' ) );
	}

	// Rate limiting: máx. 3 envíos por IP por hora
	$rate_key = 'rc_contact_' . resolvecore_client_ip_hash();
	$attempts = (int) get_transient( $rate_key );
	if ( $attempts >= 3 ) {
		wp_send_json_error( array( 'msg' => 'Demasiados intentos. Espera un rato antes de volver a enviar.' ) );
	}
	set_transient( $rate_key, $attempts + 1, HOUR_IN_SECONDS );

	$name    = sanitize_text_field( wp_unslash( $_POST['rc_name'] ?? '' ) );
	$email   = sanitize_email( wp_unslash( $_POST['rc_email'] ?? '' ) );
	$message = sanitize_textarea_field( wp_unslash( $_POST['rc_message'] ?? '' ) );
	$type    = sanitize_text_field( wp_unslash( $_POST['rc_type'] ?? 'contacto' ) );

	// Whitelist tipo
	$allowed_types = array( 'soporte', 'bug', 'colaboracion', 'licencia', 'otro', 'contacto' );
	if ( ! in_array( $type, $allowed_types, true ) ) {
		$type = 'contacto';
	}

	if ( $name === '' || $email === '' || ! is_email( $email ) || $message === '' ) {
		wp_send_json_error( array( 'msg' => 'Por favor rellena todos los campos correctamente.' ) );
	}
	if ( mb_strlen( $message ) > 500 ) {
		wp_send_json_error( array( 'msg' => 'El mensaje supera 500 caracteres.' ) );
	}

	// 1) Crear ticket en MantisBT (canal primario)
	$ticket_id  = 0;
	$ticket_err = '';
	if ( function_exists( 'rc_mantis_create_ticket' ) ) {
		$ticket = rc_mantis_create_ticket(
			array(
				'name'    => $name,
				'email'   => $email,
				'type'    => $type,
				'message' => $message,
			)
		);
		if ( is_wp_error( $ticket ) ) {
			$ticket_err = $ticket->get_error_message();
			error_log( '[resolvecore_handle_contact] Mantis: ' . $ticket_err );
		} elseif ( (int) $ticket > 0 ) {
			$ticket_id = (int) $ticket;
		}
	}

	// 2) Email al técnico (canal secundario, no bloquea respuesta)
	$admin_email = get_option( 'admin_email' );
	$subject     = sprintf(
		'[ResolveCore] %s%s — %s',
		$ticket_id ? "#{$ticket_id} " : '',
		$type,
		$name
	);
	$body        = "Nombre: {$name}\n";
	$body       .= "Email: {$email}\n";
	$body       .= "Tipo: {$type}\n";
	if ( $ticket_id ) {
		$body .= "Ticket MantisBT: #{$ticket_id}\n";
	}
	$body     .= "\nMensaje:\n{$message}\n";
	$headers   = array(
		'Content-Type: text/plain; charset=UTF-8',
		sprintf( 'Reply-To: %s <%s>', $name, $email ),
	);
	$mail_sent = @wp_mail( $admin_email, $subject, $body, $headers );

	// 2b) Email de confirmación al cliente — incidencia + seguimiento.
	// Canal informativo: si falla, solo se registra; no altera la respuesta.
	resolvecore_send_client_confirmation( $email, $name, $ticket_id, $type, $message );

	// 3) Respuesta — éxito si AL MENOS uno funcionó
	if ( ! $ticket_id && ! $mail_sent ) {
		wp_send_json_error(
			array(
				'msg'   => 'No pudimos procesar tu mensaje. Escríbenos directamente a ' . esc_html( $admin_email ) . '.',
				'debug' => $ticket_err ?: 'mail_failed',
			)
		);
	}

	$msg = $ticket_id
		? sprintf( '¡Mensaje recibido! Ticket #%d creado, te responderemos en menos de 2 horas.', $ticket_id )
		: '¡Mensaje recibido! Te responderemos en menos de 2 horas.';

	wp_send_json_success(
		array_filter(
			array(
				'msg'          => $msg,
				'ticket_id'    => $ticket_id ?: null,
				'ticket_token' => $ticket_id ? resolvecore_ticket_token( $ticket_id ) : null,
			)
		)
	);
}
add_action( 'wp_ajax_resolvecore_contact', 'resolvecore_handle_contact' );
add_action( 'wp_ajax_nopriv_resolvecore_contact', 'resolvecore_handle_contact' );

/**
 * Remitente unificado del correo saliente.
 *
 * Por defecto WordPress envía como `WordPress <wordpress@dominio>`: nombre
 * genérico y dirección que no coincide con el buzón autenticado del relay
 * SMTP. Los filtros antispam (Ionos incluido) lo penalizan. Se fija el From
 * al buzón del dominio (= usuario del relay) con el nombre del proyecto.
 */
function resolvecore_mail_from( string $from ): string {
	$admin = get_option( 'admin_email' );
	return is_email( $admin ) ? $admin : $from;
}
add_filter( 'wp_mail_from', 'resolvecore_mail_from' );

function resolvecore_mail_from_name(): string {
	return 'ResolveCore';
}
add_filter( 'wp_mail_from_name', 'resolvecore_mail_from_name' );

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

	$type_labels = array(
		'soporte'      => 'Soporte técnico',
		'bug'          => 'Reporte de error',
		'colaboracion' => 'Colaboración',
		'licencia'     => 'Licencia',
		'otro'         => 'Consulta general',
		'contacto'     => 'Consulta general',
	);
	$type_label  = $type_labels[ $type ] ?? 'Consulta general';

	// Las 4 fases coinciden con el timeline de resolvecore_handle_ticket_status().
	$fases      = array(
		array( 'Recibido', 'Ticket creado y en cola de revisión.' ),
		array( 'En diagnóstico', 'El técnico analiza el problema.' ),
		array( 'En resolución', 'Trabajo sobre la solución mediante AnyDesk.' ),
		array( 'Resuelto', 'Ticket cerrado con resumen técnico adjunto.' ),
	);
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
		? add_query_arg(
			array(
				'rc_ticket' => $ticket_id,
				'rc_t'      => resolvecore_ticket_token( $ticket_id ),
			),
			home_url( '/' )
		) . '#contacto'
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

	$headers = array(
		'Content-Type: text/html; charset=UTF-8',
		'Reply-To: ' . get_option( 'admin_email' ),
		'List-Unsubscribe: <mailto:' . get_option( 'admin_email' ) . '?subject=baja-resolvecore>',
	);

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
		wp_send_json_error( array( 'msg' => 'ID de ticket inválido.' ) );
	}

	// Token anti-enumeración: impide consultar el estado de tickets ajenos
	// cambiando el número. Lo emite resolvecore_handle_contact() y el correo.
	$token = sanitize_text_field( wp_unslash( $_POST['token'] ?? '' ) );
	if ( ! hash_equals( resolvecore_ticket_token( $id ), $token ) ) {
		wp_send_json_error( array( 'msg' => 'Enlace de seguimiento no válido.' ) );
	}

	// Rate limit: 30 consultas/hora por IP
	$rate_key = 'rc_status_' . resolvecore_client_ip_hash();
	$attempts = (int) get_transient( $rate_key );
	if ( $attempts >= 30 ) {
		wp_send_json_error( array( 'msg' => 'Demasiadas consultas. Espera un rato.' ) );
	}
	set_transient( $rate_key, $attempts + 1, HOUR_IN_SECONDS );

	if ( ! function_exists( 'rc_mantis_get_api' ) ) {
		wp_send_json_error( array( 'msg' => 'Integración MantisBT no disponible.' ) );
	}
	$api = rc_mantis_get_api();
	if ( ! $api ) {
		wp_send_json_error( array( 'msg' => 'MantisBT no configurado.' ) );
	}

	$res = $api->get_issue( $id );
	if ( is_wp_error( $res ) ) {
		wp_send_json_error( array( 'msg' => 'Ticket no encontrado.' ) );
	}

	$issue = $res['issues'][0] ?? null;
	if ( ! $issue ) {
		wp_send_json_error( array( 'msg' => 'Ticket vacío.' ) );
	}

	$status_name = (string) ( $issue['status']['name'] ?? 'new' );
	$status_id   = (int) ( $issue['status']['id'] ?? 10 );

	// Mantis status enum → 4 fases UX
	// 10 new · 20 feedback · 30 acknowledged · 40 confirmed · 50 assigned · 80 resolved · 90 closed
	$phase = match ( true ) {
		$status_id >= 80 => 4,
		$status_id >= 50 => 3,
		$status_id >= 30 => 2,
		default          => 1,
	};

	$events = array(
		array(
			'phase' => 1,
			'label' => 'Recibido',
			'desc'  => 'Ticket creado y en cola de revisión. En menos de 2 horas un técnico revisará la incidencia.',
		),
		array(
			'phase' => 2,
			'label' => 'En diagnóstico',
			'desc'  => 'Técnico analizando el problema. Se recopilan datos del sistema para identificar la causa raíz.',
		),
		array(
			'phase' => 3,
			'label' => 'En resolución',
			'desc'  => 'Trabajando en la solución vía AnyDesk. El técnico aplica los cambios necesarios en tu equipo.',
		),
		array(
			'phase' => 4,
			'label' => 'Resuelto',
			'desc'  => 'Incidencia cerrada. El informe técnico está adjunto al ticket en MantisBT.',
		),
	);

	// Datos extra para el panel ampliado
	$summary  = (string) ( $issue['summary'] ?? '' );
	$category = (string) ( $issue['category']['name'] ?? '' );
	$priority = (string) ( $issue['priority']['name'] ?? '' );
	$handler  = (string) ( $issue['handler']['real_name'] ?? $issue['handler']['name'] ?? '' );
	$reporter = (string) ( $issue['reporter']['real_name'] ?? $issue['reporter']['name'] ?? '' );

	// Última nota pública del ticket (si existe)
	$last_note = '';
	$notes_raw = $issue['notes'] ?? array();
	if ( is_array( $notes_raw ) ) {
		// Las notas vienen en orden ascendente; tomar la última pública del técnico
		$pub_notes = array_filter(
			$notes_raw,
			static fn( $n ) => isset( $n['view_state']['name'] ) && 'public' === $n['view_state']['name']
		);
		if ( $pub_notes ) {
			$last = end( $pub_notes );
			$last_note = (string) ( $last['text'] ?? '' );
			// Truncar a 300 caracteres para el modal
			if ( mb_strlen( $last_note ) > 300 ) {
				$last_note = mb_substr( $last_note, 0, 297 ) . '…';
			}
		}
	}

	wp_send_json_success(
		array(
			'ticket_id'  => $id,
			'status'     => $status_name,
			'status_id'  => $status_id,
			'phase'      => $phase,
			'events'     => $events,
			'summary'    => $summary,
			'category'   => $category,
			'priority'   => $priority,
			'handler'    => $handler,
			'reporter'   => $reporter,
			'last_note'  => $last_note,
			'created_at' => $issue['created_at'] ?? null,
			'updated_at' => $issue['updated_at'] ?? null,
		)
	);
}
add_action( 'wp_ajax_resolvecore_ticket_status', 'resolvecore_handle_ticket_status' );
add_action( 'wp_ajax_nopriv_resolvecore_ticket_status', 'resolvecore_handle_ticket_status' );

// =============================================================================
//  Área de técnicos — backend
// =============================================================================

/**
 * Crea la tabla rc_download_log si no existe.
 */
function rc_create_download_log_table(): void {
	global $wpdb;
	$table   = $wpdb->prefix . 'rc_download_log';
	$charset = $wpdb->get_charset_collate();
	$sql     = "CREATE TABLE IF NOT EXISTS {$table} (
		id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
		file_key VARCHAR(64) NOT NULL,
		user_login VARCHAR(128) NOT NULL,
		ip VARCHAR(45) NOT NULL,
		ua VARCHAR(255) NOT NULL DEFAULT '',
		downloaded_at DATETIME NOT NULL,
		PRIMARY KEY (id),
		KEY idx_user (user_login),
		KEY idx_file (file_key),
		KEY idx_date (downloaded_at)
	) {$charset};";
	require_once ABSPATH . 'wp-admin/includes/upgrade.php';
	dbDelta( $sql );
}
add_action( 'after_setup_theme', 'rc_create_download_log_table' );

function rc_log_download( string $key, string $user_login, string $ip ): void {
	global $wpdb;
	$wpdb->insert(
		$wpdb->prefix . 'rc_download_log',
		array(
			'file_key'      => $key,
			'user_login'    => $user_login,
			'ip'            => $ip,
			'ua'            => substr( sanitize_text_field( wp_unslash( $_SERVER['HTTP_USER_AGENT'] ?? '' ) ), 0, 255 ),
			'downloaded_at' => current_time( 'mysql' ),
		),
		array( '%s', '%s', '%s', '%s', '%s' )
	);
}

/**
 * Metadata real de cada fichero descargable (size + sha256 + mtime).
 * Cacheado 5 min para no recalcular el hash en cada visita.
 */
function rc_get_download_meta( string $key ): array {
	$cache_key = "rc_dl_meta_{$key}";
	$cached    = get_transient( $cache_key );
	if ( is_array( $cached ) ) {
		return $cached;
	}

	$files = array(
		'windows' => 'install-servicios.ps1',
		'linux'   => 'install-servicios.sh',
		'kit'     => 'resolvecore-kit.zip',
	);
	if ( ! isset( $files[ $key ] ) ) {
		return array();
	}

	$dir  = defined( 'RC_DOWNLOADS_PATH' ) ? RC_DOWNLOADS_PATH : '/opt/resolvecore-downloads';
	$path = trailingslashit( $dir ) . $files[ $key ];

	if ( ! file_exists( $path ) ) {
		$meta = array(
			'exists' => false,
			'size'   => 0,
			'sha256' => '',
			'mtime'  => 0,
		);
		set_transient( $cache_key, $meta, 60 );
		return $meta;
	}

	$meta = array(
		'exists' => true,
		'size'   => filesize( $path ),
		'sha256' => hash_file( 'sha256', $path ),
		'mtime'  => filemtime( $path ),
	);
	set_transient( $cache_key, $meta, 5 * MINUTE_IN_SECONDS );
	return $meta;
}

/**
 * Formato humano de bytes.
 */
function rc_format_bytes( int $bytes ): string {
	if ( $bytes <= 0 ) {
		return '—';
	}
	$units = array( 'B', 'KB', 'MB', 'GB' );
	$i     = (int) floor( log( $bytes, 1024 ) );
	$i     = min( $i, count( $units ) - 1 );
	return round( $bytes / pow( 1024, $i ), 1 ) . ' ' . $units[ $i ];
}

/**
 * AJAX: estado de infraestructura (mantis, nginx, fleet).
 * Cacheado 60s — no machaca backends.
 */
function rc_tech_infra_status(): void {
	if ( ! current_user_can( 'editor' ) && ! current_user_can( 'administrator' ) ) {
		wp_send_json_error( array( 'msg' => 'forbidden' ), 403 );
	}

	$cached = get_transient( 'rc_tech_infra_status' );
	if ( is_array( $cached ) ) {
		wp_send_json_success( $cached );
	}

	$targets = array(
		'mantis' => 'https://mantis.resolvecore.website/',
		'web'    => home_url( '/' ),
		'fleet'  => home_url( '/fleet-status/' ),
	);

	$out = array();
	foreach ( $targets as $name => $url ) {
		$t0  = microtime( true );
		$res = wp_remote_head(
			$url,
			array(
				'timeout'     => 4,
				'redirection' => 2,
				'sslverify'   => true,
			)
		);
		$ms  = (int) ( ( microtime( true ) - $t0 ) * 1000 );
		if ( is_wp_error( $res ) ) {
			$out[ $name ] = array( 'ok' => false, 'code' => 0, 'ms' => $ms, 'err' => $res->get_error_message() );
		} else {
			$code         = wp_remote_retrieve_response_code( $res );
			$out[ $name ] = array( 'ok' => $code >= 200 && $code < 400, 'code' => $code, 'ms' => $ms );
		}
	}
	$out['checked_at'] = gmdate( 'c' );

	set_transient( 'rc_tech_infra_status', $out, MINUTE_IN_SECONDS );
	wp_send_json_success( $out );
}
add_action( 'wp_ajax_rc_tech_infra_status', 'rc_tech_infra_status' );

/**
 * AJAX: tickets asignados / reportados por el técnico actual en MantisBT.
 */
function rc_tech_my_tickets(): void {
	if ( ! current_user_can( 'editor' ) && ! current_user_can( 'administrator' ) ) {
		wp_send_json_error( array( 'msg' => 'forbidden' ), 403 );
	}
	check_ajax_referer( 'rc_tech_nonce', 'nonce' );

	if ( ! function_exists( 'rc_mantis_get_api' ) ) {
		wp_send_json_error( array( 'msg' => 'Integración MantisBT no disponible.' ) );
	}
	$api = rc_mantis_get_api();
	if ( ! $api ) {
		wp_send_json_error( array( 'msg' => 'MantisBT no configurado.' ) );
	}

	$user      = wp_get_current_user();
	$user_hint = strtolower( $user->user_login );

	$cache_key = 'rc_tech_tickets_' . $user->ID;
	$cached    = get_transient( $cache_key );
	if ( is_array( $cached ) ) {
		wp_send_json_success( $cached );
	}

	if ( ! method_exists( $api, 'list_issues' ) ) {
		wp_send_json_success( array( 'tickets' => array(), 'note' => 'API sin list_issues' ) );
	}

	$res = $api->list_issues( array( 'page_size' => 25 ) );
	if ( is_wp_error( $res ) ) {
		wp_send_json_error( array( 'msg' => $res->get_error_message() ) );
	}

	$issues   = $res['issues'] ?? array();
	$filtered = array();
	foreach ( $issues as $iss ) {
		$status_id = (int) ( $iss['status']['id'] ?? 0 );
		if ( $status_id >= 90 ) {
			continue; // cerrados fuera
		}
		$handler  = strtolower( (string) ( $iss['handler']['name'] ?? '' ) );
		$reporter = strtolower( (string) ( $iss['reporter']['name'] ?? '' ) );
		if ( $handler === $user_hint || $reporter === $user_hint ) {
			$filtered[] = array(
				'id'       => (int) ( $iss['id'] ?? 0 ),
				'summary'  => (string) ( $iss['summary'] ?? '' ),
				'status'   => (string) ( $iss['status']['name'] ?? '' ),
				'priority' => (string) ( $iss['priority']['name'] ?? '' ),
				'updated'  => (string) ( $iss['updated_at'] ?? '' ),
			);
		}
	}

	$out = array( 'tickets' => array_slice( $filtered, 0, 10 ) );
	set_transient( $cache_key, $out, 2 * MINUTE_IN_SECONDS );
	wp_send_json_success( $out );
}
add_action( 'wp_ajax_rc_tech_my_tickets', 'rc_tech_my_tickets' );

/**
 * AJAX: genera README-cliente.txt personalizado (cliente + ticket).
 * Devuelve texto plano descargable.
 */
function rc_tech_build_readme(): void {
	if ( ! current_user_can( 'editor' ) && ! current_user_can( 'administrator' ) ) {
		wp_die( 'forbidden', 'error', array( 'response' => 403 ) );
	}
	check_admin_referer( 'rc_tech_readme' );

	$cliente   = sanitize_text_field( wp_unslash( $_POST['cliente'] ?? '' ) );
	$ticket_id = absint( $_POST['ticket'] ?? 0 );
	$tecnico   = wp_get_current_user()->display_name;

	if ( $cliente === '' ) {
		wp_die( 'Falta nombre del cliente', 'error', array( 'response' => 400 ) );
	}

	$ticket_line = $ticket_id ? "Incidencia MantisBT: #{$ticket_id}" : 'Incidencia MantisBT: (pendiente)';
	$fecha       = wp_date( 'Y-m-d H:i' );

	$txt = <<<TXT
================================================================
  ResolveCore — Kit de soporte para {$cliente}
================================================================

Hola {$cliente},

Tu técnico asignado es {$tecnico}.
{$ticket_line}
Fecha de entrega: {$fecha}

----------------------------------------------------------------
  Cómo iniciar la sesión de soporte remoto
----------------------------------------------------------------

1. Haz doble clic en "anydesk-portable.exe"
2. Espera a que aparezca tu ID AnyDesk (9-10 dígitos)
3. Llama o envía un WhatsApp a tu técnico con ese ID
4. El técnico te pedirá aceptar la conexión: pulsa "Aceptar"

Cuando la sesión termine, simplemente cierra AnyDesk.

----------------------------------------------------------------
  Privacidad y RGPD
----------------------------------------------------------------

- El técnico solo accede mientras AnyDesk está abierto.
- Puedes cerrar la conexión en cualquier momento.
- No se instala nada permanente: AnyDesk es portable.
- Se generará un informe técnico que recibirás por email.

----------------------------------------------------------------
  Contacto
----------------------------------------------------------------

Web:    https://resolvecore.website
Email:  fvidalmateo@gmail.com

ResolveCore — Solución a tus problemas informáticos.
TXT;

	$filename = 'README-' . sanitize_file_name( strtolower( $cliente ) ) . '.txt';
	header( 'Content-Type: text/plain; charset=UTF-8' );
	header( 'Content-Disposition: attachment; filename="' . $filename . '"' );
	header( 'X-Content-Type-Options: nosniff' );
	echo $txt; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
	exit;
}
add_action( 'admin_post_rc_tech_build_readme', 'rc_tech_build_readme' );

/**
 * AJAX: últimas 20 descargas de la tabla rc_download_log (todas, no solo del user).
 */
function rc_tech_logs_tail(): void {
	if ( ! current_user_can( 'editor' ) && ! current_user_can( 'administrator' ) ) {
		wp_send_json_error( array( 'msg' => 'forbidden' ), 403 );
	}
	check_ajax_referer( 'rc_tech_nonce', 'nonce' );

	global $wpdb;
	$table = $wpdb->prefix . 'rc_download_log';
	$rows  = $wpdb->get_results(
		"SELECT id, file_key, user_login, ip, downloaded_at
		 FROM {$table}
		 ORDER BY id DESC
		 LIMIT 20",
		ARRAY_A
	);
	wp_send_json_success( array( 'rows' => $rows ?: array() ) );
}
add_action( 'wp_ajax_rc_tech_logs_tail', 'rc_tech_logs_tail' );

/**
 * AJAX: añade nota pública al ticket Mantis.
 */
function rc_tech_add_note(): void {
	if ( ! current_user_can( 'editor' ) && ! current_user_can( 'administrator' ) ) {
		wp_send_json_error( array( 'msg' => 'forbidden' ), 403 );
	}
	check_ajax_referer( 'rc_tech_nonce', 'nonce' );

	$id   = absint( $_POST['ticket_id'] ?? 0 );
	$text = sanitize_textarea_field( wp_unslash( $_POST['text'] ?? '' ) );
	if ( $id < 1 || $text === '' ) {
		wp_send_json_error( array( 'msg' => 'Faltan datos.' ) );
	}
	if ( ! function_exists( 'rc_mantis_get_api' ) ) {
		wp_send_json_error( array( 'msg' => 'Mantis no disponible.' ) );
	}
	$api = rc_mantis_get_api();
	if ( ! $api ) {
		wp_send_json_error( array( 'msg' => 'Mantis no configurado.' ) );
	}
	$user = wp_get_current_user();
	$body = "[{$user->display_name}] {$text}";
	$res  = $api->add_note( $id, $body );
	if ( is_wp_error( $res ) ) {
		wp_send_json_error( array( 'msg' => $res->get_error_message() ) );
	}
	wp_send_json_success( array( 'msg' => 'Nota añadida al ticket #' . $id ) );
}
add_action( 'wp_ajax_rc_tech_add_note', 'rc_tech_add_note' );

/**
 * AJAX: sube informe PDF y lo adjunta al ticket.
 * Acepta multipart con file[informe] y ticket_id.
 */
function rc_tech_upload_informe(): void {
	if ( ! current_user_can( 'editor' ) && ! current_user_can( 'administrator' ) ) {
		wp_send_json_error( array( 'msg' => 'forbidden' ), 403 );
	}
	check_ajax_referer( 'rc_tech_nonce', 'nonce' );

	$id = absint( $_POST['ticket_id'] ?? 0 );
	if ( $id < 1 ) {
		wp_send_json_error( array( 'msg' => 'ticket_id inválido' ) );
	}
	if ( empty( $_FILES['informe']['tmp_name'] ) ) {
		wp_send_json_error( array( 'msg' => 'Falta fichero.' ) );
	}

	$file = $_FILES['informe'];
	if ( (int) $file['size'] > 10 * 1024 * 1024 ) {
		wp_send_json_error( array( 'msg' => 'Fichero > 10 MB.' ) );
	}

	$mime = mime_content_type( $file['tmp_name'] );
	if ( ! in_array( $mime, array( 'application/pdf', 'text/html' ), true ) ) {
		wp_send_json_error( array( 'msg' => 'Solo PDF o HTML.' ) );
	}

	if ( ! function_exists( 'rc_mantis_get_api' ) ) {
		wp_send_json_error( array( 'msg' => 'Mantis no disponible.' ) );
	}
	$api = rc_mantis_get_api();
	if ( ! $api ) {
		wp_send_json_error( array( 'msg' => 'Mantis no configurado.' ) );
	}

	$safe_name = sanitize_file_name( $file['name'] );
	$res       = $api->attach_file( $id, $file['tmp_name'], $safe_name );
	if ( is_wp_error( $res ) ) {
		wp_send_json_error( array( 'msg' => $res->get_error_message() ) );
	}
	wp_send_json_success( array( 'msg' => 'Informe adjuntado al ticket #' . $id, 'file' => $safe_name ) );
}
add_action( 'wp_ajax_rc_tech_upload_informe', 'rc_tech_upload_informe' );

/**
 * Genera factura HTML imprimible inline para un ticket.
 * Acceso: /tecnicos/?rc_factura=<ID>&cliente=<nombre>&horas=<n>
 */
function rc_tech_factura_inline(): void {
	if ( ! isset( $_GET['rc_factura'] ) ) {
		return;
	}
	if ( ! current_user_can( 'editor' ) && ! current_user_can( 'administrator' ) ) {
		wp_die( 'forbidden', 'error', array( 'response' => 403 ) );
	}
	$id      = absint( $_GET['rc_factura'] );
	$cliente = sanitize_text_field( wp_unslash( $_GET['cliente'] ?? 'Cliente' ) );
	$horas   = max( 0.25, (float) ( $_GET['horas'] ?? 1 ) );
	$tarifa  = (float) ( $_GET['tarifa'] ?? 35.0 );
	$tecnico = wp_get_current_user()->display_name;
	$fecha   = wp_date( 'Y-m-d' );
	$num     = sprintf( 'F-%s-%04d', gmdate( 'Ym' ), $id );
	$base    = round( $horas * $tarifa, 2 );
	$iva     = round( $base * 0.21, 2 );
	$total   = round( $base + $iva, 2 );

	header( 'Content-Type: text/html; charset=UTF-8' );
	?>
<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Factura <?php echo esc_html( $num ); ?></title>
<style>
*{box-sizing:border-box}body{font-family:system-ui,Arial,sans-serif;color:#222;max-width:800px;margin:2rem auto;padding:2rem;background:#fff}
header{display:flex;justify-content:space-between;align-items:flex-start;border-bottom:3px solid #00c988;padding-bottom:1rem;margin-bottom:2rem}
h1{margin:0;color:#00c988;font-size:1.8rem}
.meta{text-align:right;font-size:.9rem;color:#555}
.meta strong{color:#222}
table{width:100%;border-collapse:collapse;margin:1.5rem 0}
th,td{padding:.7rem;text-align:left;border-bottom:1px solid #ddd}
th{background:#f5f7fa;font-size:.8rem;text-transform:uppercase;letter-spacing:.05em;color:#666}
tfoot td{border:none;font-weight:600}
tfoot tr:last-child td{border-top:2px solid #00c988;color:#00c988;font-size:1.2rem}
.right{text-align:right}
footer{margin-top:3rem;font-size:.8rem;color:#888;border-top:1px solid #eee;padding-top:1rem}
@media print {body{margin:0;padding:1cm}.noprint{display:none}}
.noprint{position:fixed;top:1rem;right:1rem;background:#00c988;color:#fff;padding:.6rem 1.2rem;border:none;border-radius:6px;cursor:pointer;font-weight:600}
</style></head><body>
<button class="noprint" onclick="window.print()">Imprimir / Guardar PDF</button>
<header>
	<div><h1>ResolveCore</h1><div>Soporte técnico remoto<br>fvidalmateo@gmail.com</div></div>
	<div class="meta">
		<strong>Factura <?php echo esc_html( $num ); ?></strong><br>
		Fecha: <?php echo esc_html( $fecha ); ?><br>
		Ticket: #<?php echo (int) $id; ?>
	</div>
</header>
<p><strong>Cliente:</strong> <?php echo esc_html( $cliente ); ?></p>
<p><strong>Técnico:</strong> <?php echo esc_html( $tecnico ); ?></p>
<table>
	<thead><tr><th>Concepto</th><th class="right">Cantidad</th><th class="right">Precio</th><th class="right">Importe</th></tr></thead>
	<tbody>
		<tr>
			<td>Intervención de soporte técnico remoto (ticket #<?php echo (int) $id; ?>)</td>
			<td class="right"><?php echo esc_html( number_format( $horas, 2, ',', '.' ) ); ?> h</td>
			<td class="right"><?php echo esc_html( number_format( $tarifa, 2, ',', '.' ) ); ?> €</td>
			<td class="right"><?php echo esc_html( number_format( $base, 2, ',', '.' ) ); ?> €</td>
		</tr>
	</tbody>
	<tfoot>
		<tr><td colspan="3" class="right">Base imponible</td><td class="right"><?php echo esc_html( number_format( $base, 2, ',', '.' ) ); ?> €</td></tr>
		<tr><td colspan="3" class="right">IVA 21%</td><td class="right"><?php echo esc_html( number_format( $iva, 2, ',', '.' ) ); ?> €</td></tr>
		<tr><td colspan="3" class="right">TOTAL</td><td class="right"><?php echo esc_html( number_format( $total, 2, ',', '.' ) ); ?> €</td></tr>
	</tfoot>
</table>
<footer>
	Factura simplificada (RD 1619/2012 art. 7). Para factura completa, contactar.<br>
	ResolveCore — Solución a tus problemas informáticos.
</footer>
</body></html>
	<?php
	exit;
}
add_action( 'template_redirect', 'rc_tech_factura_inline', 4 );

/**
 * Estadísticas rápidas del técnico (descargas propias últimas 30d).
 */
function rc_tech_my_stats(): array {
	global $wpdb;
	$user  = wp_get_current_user();
	$table = $wpdb->prefix . 'rc_download_log';
	$row   = $wpdb->get_row(
		$wpdb->prepare(
			"SELECT COUNT(*) AS total, MAX(downloaded_at) AS last_at
			 FROM {$table}
			 WHERE user_login = %s
			   AND downloaded_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)",
			$user->user_login
		),
		ARRAY_A
	);
	return array(
		'total'   => (int) ( $row['total'] ?? 0 ),
		'last_at' => (string) ( $row['last_at'] ?? '' ),
	);
}
