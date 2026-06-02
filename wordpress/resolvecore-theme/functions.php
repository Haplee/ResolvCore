<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// ── Descarga segura de ficheros para área técnicos ─────────────────────────
// Añade en wp-config.php: define('RC_DOWNLOADS_PATH', '/opt/resolvecore-downloads');
function rc_handle_technician_download(): void {
	if ( ! isset( $_GET['rc_download'] ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		return;
	}

	// Requiere login
	if ( ! is_user_logged_in() ) {
		wp_safe_redirect( wp_login_url( get_permalink() ) );
		exit;
	}

	// Solo editores/administradores (roles técnico)
	if ( ! current_user_can( 'editor' ) && ! current_user_can( 'administrator' ) ) {
		wp_die( 'Sin permiso para descargar.', 'Sin acceso', array( 'response' => 403 ) );
	}

	check_admin_referer( 'rc_download' );
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

	header( 'Content-Type: ' . $allowed[ $key ]['type'] );
	header( 'Content-Disposition: attachment; filename="' . basename( $filepath ) . '"' );
	header( 'Content-Length: ' . filesize( $filepath ) );
	header( 'Cache-Control: no-cache, no-store, must-revalidate' );
	header( 'Pragma: no-cache' );
	header( 'X-Content-Type-Options: nosniff' );
	readfile( $filepath ); // phpcs:ignore WordPress.WP.AlternativeFunctions.file_system_operations_readfile
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

// Modo mantenimiento. Se puede forzar desde wp-config.php; si no, default false.
// El guard evita el notice "constant already defined" cuando ya viene de wp-config.
if ( ! defined( 'RESOLVECORE_MAINTENANCE' ) ) {
	define( 'RESOLVECORE_MAINTENANCE', false );
}

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

// =============================================================================
//  SEO — sitemap discovery, meta description y noindex de páginas privadas
// =============================================================================

/**
 * Anuncia el sitemap XML del core en robots.txt.
 *
 * WordPress sirve /wp-sitemap.xml desde 5.5 pero no añade la línea
 * `Sitemap:` al robots.txt virtual. Sin ella, los crawlers no descubren el
 * mapa salvo que lo declares en Search Console. Respeta el flag de
 * visibilidad: si el sitio está marcado como privado, no lo anuncia.
 */
function resolvecore_robots_txt( string $output, $public ): string {
	if ( '0' === (string) $public ) {
		return $output;
	}
	$output .= "\nSitemap: " . esc_url( home_url( '/wp-sitemap.xml' ) ) . "\n";
	return $output;
}
add_filter( 'robots_txt', 'resolvecore_robots_txt', 10, 2 );

/**
 * Marca como noindex las páginas privadas (registro, dashboard de cliente y
 * área de técnicos). Son pantallas de login/cliente sin valor de búsqueda y
 * no deben aparecer en Google. Usa el filtro nativo `wp_robots` (WP 5.7+),
 * que emite la etiqueta <meta name="robots"> correcta.
 */
function resolvecore_noindex_private( array $robots ): array {
	if ( is_page( array( 'registro', 'dashboard', 'tecnicos' ) ) ) {
		$robots['noindex']  = true;
		$robots['nofollow'] = true;
	}
	return $robots;
}
add_filter( 'wp_robots', 'resolvecore_noindex_private' );

/**
 * Meta description dinámica para páginas internas (la portada trae la suya
 * en front-page.php). Prioriza el extracto manual; si no hay, recorta el
 * contenido; como último recurso usa el lema del sitio. Se trunca a ~160
 * caracteres, el límite útil del snippet de Google.
 */
function resolvecore_meta_description(): string {
	$desc = '';

	if ( is_front_page() ) {
		return ''; // la portada ya emite su propia description
	}

	if ( is_singular() ) {
		$post = get_queried_object();
		if ( $post instanceof WP_Post ) {
			$desc = has_excerpt( $post )
				? get_the_excerpt( $post )
				: wp_strip_all_tags( strip_shortcodes( $post->post_content ) );
		}
	}

	if ( '' === trim( $desc ) ) {
		$desc = get_bloginfo( 'description' );
	}

	$desc = trim( preg_replace( '/\s+/', ' ', wp_strip_all_tags( $desc ) ) );
	if ( mb_strlen( $desc ) > 160 ) {
		$desc = rtrim( mb_substr( $desc, 0, 157 ) ) . '…';
	}
	return $desc;
}

function resolvecore_scripts() {
	wp_enqueue_style(
		'resolvecore-fonts',
		'https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=DM+Sans:wght@300;400;500;600&display=swap',
		array(),
		null
	);
	wp_enqueue_style( 'resolvecore-style', get_stylesheet_uri(), array(), '3.2.1' );
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

	// 1) Alta de cuenta de cliente + email de activación (fijar contraseña).
	// La home NO crea tickets: el cliente los genera luego desde su dashboard.
	// Idempotente: si ya tiene cuenta, no hace nada.
	$cuenta_creada = false;
	if ( function_exists( 'rc_crear_cuenta_cliente' ) ) {
		$cuenta        = rc_crear_cuenta_cliente( $email, $name );
		$cuenta_creada = ! empty( $cuenta['created'] );
	}

	// 2) Aviso al admin — lead de solicitud de acceso (no bloquea respuesta).
	$admin_email = get_option( 'admin_email' );
	$subject     = sprintf( '[ResolveCore] Solicitud de acceso — %s', $name );
	$body        = "Nombre: {$name}\n";
	$body       .= "Email: {$email}\n";
	$body       .= "Tipo: {$type}\n";
	$body       .= 'Cuenta creada: ' . ( $cuenta_creada ? 'sí' : 'no (ya existía o error)' ) . "\n";
	$body       .= "\nMensaje:\n{$message}\n";
	$headers     = array(
		'Content-Type: text/plain; charset=UTF-8',
		sprintf( 'Reply-To: %s <%s>', $name, $email ),
	);
	$mail_sent   = @wp_mail( $admin_email, $subject, $body, $headers );

	// 3) Respuesta — éxito si se creó cuenta O se avisó al admin.
	if ( ! $cuenta_creada && ! $mail_sent ) {
		wp_send_json_error(
			array(
				'msg'   => 'No pudimos procesar tu solicitud. Escríbenos directamente a ' . esc_html( $admin_email ) . '.',
				'debug' => 'no_account_no_mail',
			)
		);
	}

	$msg = $cuenta_creada
		? '¡Solicitud recibida! Te hemos enviado un email para fijar tu contraseña y acceder a tu panel.'
		: '¡Solicitud recibida! Si ya tienes cuenta, inicia sesión; si no, te contactaremos en menos de 2 horas.';

	wp_send_json_success(
		array_filter(
			array(
				'msg'    => $msg,
				'cuenta' => $cuenta_creada ? 1 : null,
			)
		)
	);
}
// Endpoint de contacto DESACTIVADO (auditoría 01-06-2026). El formulario público
// «Escríbenos» se eliminó de la portada para mitigar saturación/DDoS contra
// admin-ajax (alta de cuenta + wp_mail sin login). El alta de cliente se hace
// ahora únicamente desde /registro/ (plugin rc-core, con honeypot + nonce). La
// función resolvecore_handle_contact() se conserva inerte por si se reactiva con
// captcha en el futuro; sin estos hooks, la acción AJAX no está registrada.
// add_action( 'wp_ajax_resolvecore_contact', 'resolvecore_handle_contact' );
// add_action( 'wp_ajax_nopriv_resolvecore_contact', 'resolvecore_handle_contact' );

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
 * (Eliminada en A7 / auditoría 2026-05-29) `resolvecore_send_client_confirmation()`.
 *
 * Enviaba al cliente un correo de confirmación con nº de ticket + timeline. Quedó
 * huérfana al separar flujos: la home ya solo crea cuenta (sin ticket), así que no
 * tenía callers. El alta de cliente envía su propio correo de activación desde
 * `rc_crear_cuenta_cliente()` (plugin rc-core). El tracker público de tickets
 * (`resolvecore_handle_ticket_status` + `?rc_ticket=N&rc_t=TOKEN`) sigue vivo y se
 * mantiene como feature reutilizable.
 */

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
			'desc'  => 'Incidencia cerrada. El informe técnico está disponible en el historial de tu cuenta.',
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
			$last      = end( $pub_notes );
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

/**
 * Redirección tras iniciar sesión según el rol del usuario.
 *
 * Sin esto, técnicos y clientes aterrizan en la URL por defecto de WordPress
 * (/wp-admin/ o la página de origen). Cada rol va a su panel:
 *   - editor (técnico)  -> /tecnicos/
 *   - rc_cliente         -> /dashboard/
 *   - administrator y resto: comportamiento por defecto de WP.
 */
function rc_login_redirect( $redirect_to, $request, $user ) {
	if ( ! is_wp_error( $user ) && isset( $user->roles ) && is_array( $user->roles ) ) {
		if ( in_array( 'administrator', $user->roles, true ) ) {
			return $redirect_to; // admin: no tocar (suele ir a wp-admin).
		}
		if ( in_array( 'editor', $user->roles, true ) ) {
			return home_url( '/tecnicos/' );
		}
		if ( in_array( 'rc_cliente', $user->roles, true ) ) {
			return home_url( '/dashboard/' );
		}
	}
	return $redirect_to;
}
add_filter( 'login_redirect', 'rc_login_redirect', 10, 3 );

// =============================================================================
//  Área de técnicos — backend
// =============================================================================

/**
 * Limpieza one-shot: elimina la tabla rc_download_log y su opción de versión.
 *
 * El registro de descargas (contador del hero + tail logs) se retiró del área
 * de técnicos. Esta función borra los restos en instalaciones existentes. Es
 * idempotente (DROP TABLE IF EXISTS) y corre una sola vez gracias al guard de
 * opción. Tras desplegarse y ejecutarse una vez, esta función puede borrarse.
 */
function rc_cleanup_download_log(): void {
	if ( get_option( 'rc_download_log_removed' ) === '1' ) {
		return;
	}
	global $wpdb;
	$table = $wpdb->prefix . 'rc_download_log';
	$wpdb->query( "DROP TABLE IF EXISTS {$table}" ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching,WordPress.DB.PreparedSQL.InterpolatedNotPrepared
	delete_option( 'rc_dl_log_schema_ver' );
	update_option( 'rc_download_log_removed', '1' );
}
add_action( 'after_setup_theme', 'rc_cleanup_download_log' );

/**
 * Provisiona (idempotente) las páginas WP que el flujo y el menú de navegación
 * dan por hechas: /registro/, /dashboard/ y las páginas de recursos/legales.
 *
 * Sin esto, al instalar el tema en un WordPress limpio los enlaces del nav
 * (incluido «Acceso clientes → /registro/») devuelven 404 porque la plantilla
 * existe pero ninguna entrada de tipo «page» la usa. Se ejecuta al activar el
 * tema y, como red de seguridad, una sola vez en init (guard por opción).
 */
const RC_PAGES_PROVISION_VER = '2';

function rc_provision_pages() {
	if ( get_option( 'rc_pages_provision_ver' ) === RC_PAGES_PROVISION_VER ) {
		return;
	}

	// slug => [ título, plantilla, contenido (shortcode o vacío) ].
	$pages = array(
		'registro'      => array( 'Crear cuenta',        'page-registro.php',     '[rc_registro_cliente]' ),
		'dashboard'     => array( 'Mi panel',            'page-dashboard.php',    '[rc_cliente_dashboard]' ),
		'docs'          => array( 'Documentación',       'page-docs.php',         '' ),
		'changelog'     => array( 'Changelog',           'page-changelog.php',    '' ),
		'fleet-status'  => array( 'Estado de la flota',  'page-fleet-status.php', '' ),
		'tecnicos'      => array( 'Área de técnicos',    'page-tecnicos.php',     '' ),
		'contacto'      => array( 'Contacto',            'page-contacto.php',     '' ),
		'aviso-legal'   => array( 'Aviso legal',         'page-aviso-legal.php',  '' ),
		'privacidad'    => array( 'Política de privacidad', 'page-privacidad.php', '' ),
		'cookies'       => array( 'Política de cookies', 'page-cookies.php',      '' ),
	);

	foreach ( $pages as $slug => $cfg ) {
		list( $title, $template, $content ) = $cfg;

		// Extrae el nombre del shortcode (sin corchetes) si la página lo necesita.
		$shortcode = ( '' !== $content && preg_match( '/^\[([a-z0-9_]+)\]$/', $content, $m ) ) ? $m[1] : '';

		$existing = get_page_by_path( $slug );
		if ( $existing instanceof WP_Post ) {
			// Página ya existe: aseguramos plantilla correcta…
			if ( get_page_template_slug( $existing->ID ) !== $template ) {
				update_post_meta( $existing->ID, '_wp_page_template', $template );
			}
			// …y, si necesita un shortcode que no está en el contenido, lo añadimos.
			// (Bug en producción: la página /registro/ existía vacía y el formulario
			//  [rc_registro_cliente] no se pintaba porque el template hace the_content().)
			if ( $shortcode && ! has_shortcode( $existing->post_content, $shortcode ) ) {
				$nuevo = trim( $existing->post_content . "\n\n" . $content );
				wp_update_post(
					array(
						'ID'           => $existing->ID,
						'post_content' => $nuevo,
					)
				);
			}
			continue;
		}

		$page_id = wp_insert_post(
			array(
				'post_title'   => $title,
				'post_name'    => $slug,
				'post_status'  => 'publish',
				'post_type'    => 'page',
				'post_content' => $content,
			)
		);

		if ( $page_id && ! is_wp_error( $page_id ) ) {
			update_post_meta( $page_id, '_wp_page_template', $template );
		}
	}

	update_option( 'rc_pages_provision_ver', RC_PAGES_PROVISION_VER );
}
add_action( 'after_switch_theme', 'rc_provision_pages' );
add_action( 'init', 'rc_provision_pages' );

/**
 * Marca de ResolveCore en las pantallas de wp-login.php (login, recuperar
 * contraseña y reset `action=rp` de los emails de activación).
 *
 * No reemplaza el flujo nativo de WordPress (seguro y probado): solo lo viste
 * con el logo y la paleta del sitio para que el usuario no aterrice en una
 * pantalla genérica de WordPress al pulsar «¿Olvidaste tu contraseña?».
 */
function rc_login_branding() {
	// Logo CLARO: el fondo del login es oscuro (#0a0c10); el logo oscuro era
	// invisible y parecia que la pantalla estaba rota.
	$logo = get_template_directory_uri() . '/assets/logo/resolvcore-logo-light.svg';
	?>
	<style>
		body.login {
			background: #0a0c10;
			background-image:
				radial-gradient(1200px 600px at 70% -10%, rgba(0,229,160,.10), transparent 60%),
				radial-gradient(900px 500px at 0% 10%, rgba(0,153,255,.08), transparent 55%);
			color: #e8eaf0;
			font-family: 'DM Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
		}
		.login h1 a {
			background-image: url('<?php echo esc_url( $logo ); ?>');
			background-size: contain;
			background-position: center;
			width: 260px; height: 64px;
			margin: 0 auto 20px;
		}
		.login #login { padding: 6% 0 0; width: 340px; }
		.login form {
			background: #111318;
			border: 1px solid rgba(255,255,255,0.07);
			border-radius: 12px;
			box-shadow: 0 12px 40px rgba(0,0,0,0.45);
		}
		.login label { color: #8b909e; font-size: 13px; }
		.login input[type="text"],
		.login input[type="password"],
		.login input[type="email"] {
			background: #1a1d24;
			border: 1px solid rgba(255,255,255,0.13);
			color: #e8eaf0;
			border-radius: 8px;
		}
		.login input[type="text"]:focus,
		.login input[type="password"]:focus,
		.login input[type="email"]:focus {
			border-color: #00e5a0;
			box-shadow: 0 0 0 1px #00e5a0;
			outline: none;
		}
		.wp-core-ui .button-primary {
			background: #00e5a0 !important;
			border: none !important;
			color: #000 !important;
			font-weight: 700;
			text-shadow: none !important;
			box-shadow: none !important;
			border-radius: 8px;
		}
		.wp-core-ui .button-primary:hover { background: #00ffb3 !important; }
		.login #nav a, .login #backtoblog a, .login #nav, .login #backtoblog { color: #8b909e !important; }
		.login #nav a:hover, .login #backtoblog a:hover { color: #00e5a0 !important; }
		.login .message, .login #login_error, .login .notice {
			background: #1a1d24;
			border-left-color: #00e5a0;
			color: #e8eaf0;
		}
		.login #login_error { border-left-color: #ff6b35; }
	</style>
	<?php
}
add_action( 'login_enqueue_scripts', 'rc_login_branding' );

/** El logo de wp-login enlaza al sitio, no a wordpress.org. */
function rc_login_logo_url() {
	return home_url( '/' );
}
add_filter( 'login_headerurl', 'rc_login_logo_url' );

function rc_login_logo_text() {
	return get_bloginfo( 'name' );
}
add_filter( 'login_headertext', 'rc_login_logo_text' );

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
	// CSRF: mismo nonce que el resto de endpoints del panel técnico.
	check_ajax_referer( 'rc_tech_nonce', 'nonce' );

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
			$out[ $name ] = array(
				'ok'   => false,
				'code' => 0,
				'ms'   => $ms,
				'err'  => $res->get_error_message(),
			);
		} else {
			$code         = wp_remote_retrieve_response_code( $res );
			$out[ $name ] = array(
				'ok'   => $code >= 200 && $code < 400,
				'code' => $code,
				'ms'   => $ms,
			);
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
		wp_send_json_success(
			array(
				'tickets' => array(),
				'note'    => 'API sin list_issues',
			)
		);
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

	// El filtro casa el login WP contra handler/reporter de Mantis. Si los dos
	// sistemas usan logins distintos el filtro deja 0 resultados aunque haya
	// tickets: avisamos en vez de mostrar un panel vacío sin explicación.
	$out = array( 'tickets' => array_slice( $filtered, 0, 10 ) );
	if ( ! $filtered && $issues ) {
		$out['note'] = 'Hay tickets en Mantis pero ninguno casa con tu usuario «' . $user_hint . '». Revisa que tu login coincida con el de MantisBT.';
	}
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

	// phpcs:ignore WordPress.Security.ValidatedSanitizedInput.InputNotSanitized -- tmp_name/size validated below; name sanitized via sanitize_file_name before use
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
	wp_send_json_success(
		array(
			'msg'  => 'Informe adjuntado al ticket #' . $id,
			'file' => $safe_name,
		)
	);
}
add_action( 'wp_ajax_rc_tech_upload_informe', 'rc_tech_upload_informe' );

/**
 * Tabla de facturas (numeración contable secuencial persistida).
 */
function rc_invoices_table(): string {
	global $wpdb;
	return $wpdb->prefix . 'rc_invoices';
}

const RC_INVOICES_DB_VER = '1';

/**
 * Crea/actualiza el esquema de la tabla de facturas.
 */
function rc_invoices_install(): void {
	global $wpdb;
	$table   = rc_invoices_table();
	$charset = $wpdb->get_charset_collate();

	$sql = "CREATE TABLE {$table} (
		id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
		year SMALLINT(6) NOT NULL,
		seq INT(11) NOT NULL,
		numero VARCHAR(20) NOT NULL,
		ticket_id INT(11) NOT NULL,
		cliente VARCHAR(190) NOT NULL DEFAULT '',
		tecnico VARCHAR(190) NOT NULL DEFAULT '',
		horas DECIMAL(8,2) NOT NULL DEFAULT 0,
		tarifa DECIMAL(8,2) NOT NULL DEFAULT 0,
		base DECIMAL(10,2) NOT NULL DEFAULT 0,
		iva DECIMAL(10,2) NOT NULL DEFAULT 0,
		total DECIMAL(10,2) NOT NULL DEFAULT 0,
		created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
		PRIMARY KEY  (id),
		UNIQUE KEY uniq_year_seq (year, seq),
		UNIQUE KEY uniq_numero (numero),
		KEY idx_ticket (ticket_id)
	) {$charset};";

	require_once ABSPATH . 'wp-admin/includes/upgrade.php';
	dbDelta( $sql );
	update_option( 'rc_invoices_db_ver', RC_INVOICES_DB_VER );
}

add_action( 'after_setup_theme', function () {
	if ( (string) get_option( 'rc_invoices_db_ver', '0' ) !== RC_INVOICES_DB_VER ) {
		rc_invoices_install();
	}
} );

/**
 * Devuelve la factura del ticket; si no existe, asigna el siguiente número
 * secuencial del año y la persiste. La factura es INMUTABLE: una vez emitida
 * no se renumera ni recalcula (los importes se congelan en el momento de emitir).
 *
 * @return array{numero:string,cliente:string,tecnico:string,horas:float,tarifa:float,base:float,iva:float,total:float,fecha:string}
 */
function rc_invoice_get_or_create( int $ticket_id, string $cliente, string $tecnico, float $horas, float $tarifa ): array {
	global $wpdb;
	$table = rc_invoices_table();

	$row = $wpdb->get_row( $wpdb->prepare(
		"SELECT * FROM {$table} WHERE ticket_id = %d ORDER BY id ASC LIMIT 1",
		$ticket_id
	), ARRAY_A );

	if ( $row ) {
		return array(
			'numero'  => $row['numero'],
			'cliente' => $row['cliente'],
			'tecnico' => $row['tecnico'],
			'horas'   => (float) $row['horas'],
			'tarifa'  => (float) $row['tarifa'],
			'base'    => (float) $row['base'],
			'iva'     => (float) $row['iva'],
			'total'   => (float) $row['total'],
			'fecha'   => substr( (string) $row['created_at'], 0, 10 ),
		);
	}

	$year = (int) wp_date( 'Y' );
	$base = round( $horas * $tarifa, 2 );
	$iva  = round( $base * 0.21, 2 );

	// Reintenta ante colisión de seq (UNIQUE year+seq) por emisiones concurrentes.
	for ( $attempt = 0; $attempt < 5; $attempt++ ) {
		$seq    = 1 + (int) $wpdb->get_var( $wpdb->prepare(
			"SELECT COALESCE(MAX(seq),0) FROM {$table} WHERE year = %d",
			$year
		) );
		$numero = sprintf( 'F-%d-%04d', $year, $seq );

		$ok = $wpdb->insert( $table, array(
			'year'      => $year,
			'seq'       => $seq,
			'numero'    => $numero,
			'ticket_id' => $ticket_id,
			'cliente'   => $cliente,
			'tecnico'   => $tecnico,
			'horas'     => $horas,
			'tarifa'    => $tarifa,
			'base'      => $base,
			'iva'       => $iva,
			'total'     => round( $base + $iva, 2 ),
		) );

		if ( false !== $ok ) {
			break;
		}
	}

	return array(
		'numero'  => $numero,
		'cliente' => $cliente,
		'tecnico' => $tecnico,
		'horas'   => $horas,
		'tarifa'  => $tarifa,
		'base'    => $base,
		'iva'     => $iva,
		'total'   => round( $base + $iva, 2 ),
		'fecha'   => wp_date( 'Y-m-d' ),
	);
}

/**
 * Genera factura HTML imprimible inline para un ticket. La numeración es
 * secuencial contable y se persiste en BD (tabla rc_invoices); las horas/tarifa
 * solo se usan la primera vez (al emitir), después la factura es inmutable.
 * Acceso: /tecnicos/?rc_factura=<ID>&cliente=<nombre>&horas=<n>
 */
function rc_tech_factura_inline(): void {
	if ( ! isset( $_GET['rc_factura'] ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		return;
	}
	if ( ! current_user_can( 'editor' ) && ! current_user_can( 'administrator' ) ) {
		wp_die( 'forbidden', 'error', array( 'response' => 403 ) );
	}
	check_admin_referer( 'rc_factura' );
	$id      = absint( wp_unslash( $_GET['rc_factura'] ) );
	$cliente = sanitize_text_field( wp_unslash( $_GET['cliente'] ?? 'Cliente' ) );
	// Clamp de cordura: evita facturas con cifras absurdas por un enlace manipulado.
	$horas   = min( 1000.0, max( 0.25, (float) sanitize_text_field( wp_unslash( $_GET['horas'] ?? '1' ) ) ) );
	$tarifa  = min( 1000.0, max( 0.0, (float) sanitize_text_field( wp_unslash( $_GET['tarifa'] ?? '35.0' ) ) ) );
	$tecnico = wp_get_current_user()->display_name;

	// Persistir con numeración secuencial contable real. Si el ticket ya tiene
	// factura, se reutiliza (inmutable): no se renumera ni recalcula importes.
	$factura = rc_invoice_get_or_create( $id, $cliente, $tecnico, $horas, $tarifa );
	$num     = $factura['numero'];
	$cliente = $factura['cliente'];
	$tecnico = $factura['tecnico'];
	$horas   = (float) $factura['horas'];
	$tarifa  = (float) $factura['tarifa'];
	$base    = (float) $factura['base'];
	$iva     = (float) $factura['iva'];
	$total   = (float) $factura['total'];
	$fecha   = $factura['fecha'];

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
