<?php
/**
 * Plugin Name: RC Core
 * Plugin URI:  https://resolvecore.website
 * Description: Funciones específicas del cliente — shortcodes [rc_cliente_dashboard]
 *              (tickets + solicitar informes) y [rc_registro_cliente] (alta de
 *              cuenta rol rc_cliente con credenciales por email).
 * Version:     1.3.0
 * Author:      Francisco Vidal Mateo
 * Author URI:  https://github.com/Haplee
 * Text Domain: rc-core
 *
 * Notas:
 *   - Habla con MantisBT vía REST API (token en wp-config.php).
 *   - Usa el email del usuario WP como identificador en los tickets.
 *   - Las constantes RC_MANTIS_URL / RC_MANTIS_TOKEN / RC_MANTIS_PROJECT_ID
 *     deben estar definidas en wp-config.php antes de cargar el plugin.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// ── Constantes con valores por defecto ──────────────────────────────────────
// Si la instalación no las define explícitamente en wp-config.php usamos lo
// nuestro. En producción están siempre definidas; esto es solo red de
// seguridad para entornos de pruebas.

if ( ! defined( 'RC_MANTIS_URL' ) ) {
	define( 'RC_MANTIS_URL', 'https://mantis.resolvecore.website' );
}
if ( ! defined( 'RC_MANTIS_PROJECT_ID' ) ) {
	define( 'RC_MANTIS_PROJECT_ID', 1 );
}


// ── Registro del shortcode ──────────────────────────────────────────────────

add_shortcode( 'rc_cliente_dashboard', 'rc_cliente_dashboard_render' );

/**
 * Encola los estilos del dashboard solo en la página que use el shortcode.
 *
 * No queremos meter este CSS en TODAS las páginas, así que comprobamos por
 * `has_shortcode` sobre el contenido del post. Es un coste pequeño y el
 * cache de WP lo neutraliza.
 */
function rc_cliente_dashboard_assets() {
	if ( ! is_singular() ) {
		return;
	}
	global $post;
	if ( ! $post || ! has_shortcode( $post->post_content, 'rc_cliente_dashboard' ) ) {
		return;
	}

	// Vacío a propósito: el CSS vive en el style.css del tema (sección
	// "DASHBOARD CLIENTE"). Lo dejo enganchado por si en el futuro
	// queremos cargar un .css específico del plugin.
}
add_action( 'wp_enqueue_scripts', 'rc_cliente_dashboard_assets', 20 );


// ── Helpers de configuración ────────────────────────────────────────────────

function rc_mantis_token() {
	return defined( 'RC_MANTIS_TOKEN' ) ? RC_MANTIS_TOKEN : '';
}

function rc_mantis_base_url() {
	return untrailingslashit( RC_MANTIS_URL );
}


// ── REST Mantis: crear ticket ───────────────────────────────────────────────

/**
 * Crea un ticket de tipo "informe" en MantisBT vía REST.
 *
 * @param string $summary     Resumen corto (lo que el cliente escribe).
 * @param string $description Descripción detallada.
 * @param string $user_email  Email del cliente que lo solicita.
 * @return array{ok:bool,id?:int,msg?:string}
 */
function rc_mantis_crear_ticket( $summary, $description, $user_email ) {

	// Pegamos el email al final para que el técnico sepa quién lo abrió.
	$descripcion = $description . "\n\n---\nSolicitado por: " . $user_email;

	// Vía preferente: cliente robusto RC_Mantis_API (validación + manejo de
	// errores centralizado) si el plugin rc-mantisbt está activo.
	if ( function_exists( 'rc_mantis_get_api' ) ) {
		$api = rc_mantis_get_api();
		if ( $api ) {
			$res = $api->create_issue(
				array(
					'summary'     => $summary,
					'description' => $descripcion,
					'project_id'  => (int) RC_MANTIS_PROJECT_ID,
					'category'    => 'Soporte técnico',
				)
			);
			if ( is_wp_error( $res ) ) {
				return array( 'ok' => false, 'msg' => $res->get_error_message() );
			}
			$id = (int) ( $res['issue']['id'] ?? 0 );
			return $id > 0
				? array( 'ok' => true, 'id' => $id )
				: array( 'ok' => false, 'msg' => 'Mantis no devolvió ID de ticket.' );
		}
	}

	// Fallback: REST directo (entornos sin rc-mantisbt).
	$token = rc_mantis_token();
	if ( empty( $token ) ) {
		return array( 'ok' => false, 'msg' => 'Token Mantis no configurado.' );
	}

	$payload = array(
		'summary'     => $summary,
		'description' => $descripcion,
		'project'     => array( 'id' => (int) RC_MANTIS_PROJECT_ID ),
		'category'    => array( 'name' => 'Soporte técnico' ),
	);

	$response = wp_remote_post( rc_mantis_base_url() . '/api/rest/issues', array(
		'headers' => array(
			'Authorization' => $token,
			'Content-Type'  => 'application/json',
		),
		'body'    => wp_json_encode( $payload ),
		'timeout' => 10,
	) );

	if ( is_wp_error( $response ) ) {
		return array( 'ok' => false, 'msg' => 'No se pudo contactar con MantisBT.' );
	}

	$code = wp_remote_retrieve_response_code( $response );
	$body = json_decode( wp_remote_retrieve_body( $response ), true );

	if ( $code >= 200 && $code < 300 && ! empty( $body['issue']['id'] ) ) {
		return array(
			'ok' => true,
			'id' => (int) $body['issue']['id'],
		);
	}

	$msg = isset( $body['message'] ) ? $body['message'] : "Error HTTP $code";
	return array( 'ok' => false, 'msg' => $msg );
}


// ── REST Mantis: listar tickets del cliente ─────────────────────────────────

/**
 * Devuelve los tickets en los que aparece el email del cliente.
 *
 * Mantis no expone un filtro nativo por "email del reporter" en el endpoint
 * `/issues`, así que tiramos del parámetro `search` que mira en resumen y
 * descripción. Como nosotros mismos metemos el email en la descripción al
 * crear el ticket, esto basta.
 *
 * TODO: cuando el volumen crezca, cachear con set_transient 60s para no
 * castigar la API en cada visita a la página.
 */
function rc_mantis_listar_tickets( $user_email ) {

	// Vía preferente: RC_Mantis_API::search_issues (transporte centralizado).
	if ( function_exists( 'rc_mantis_get_api' ) ) {
		$api = rc_mantis_get_api();
		if ( $api && method_exists( $api, 'search_issues' ) ) {
			$res = $api->search_issues( $user_email, 50 );
			return is_wp_error( $res ) ? array() : $res;
		}
	}

	// Fallback: REST directo (entornos sin rc-mantisbt).
	$token = rc_mantis_token();
	if ( empty( $token ) ) {
		return array();
	}

	$url = add_query_arg(
		array(
			'search'    => $user_email,
			'page_size' => 50,
		),
		rc_mantis_base_url() . '/api/rest/issues'
	);

	$response = wp_remote_get( $url, array(
		'headers' => array( 'Authorization' => $token ),
		'timeout' => 10,
	) );

	if ( is_wp_error( $response ) ) {
		return array();
	}

	$body = json_decode( wp_remote_retrieve_body( $response ), true );
	return isset( $body['issues'] ) ? $body['issues'] : array();
}


// ── Render del shortcode ────────────────────────────────────────────────────

function rc_cliente_dashboard_render() {

	// Si no está logueado pintamos la pantalla de bienvenida con CTAs.
	if ( ! is_user_logged_in() ) {
		return rc_cliente_render_login();
	}

	$user      = wp_get_current_user();
	$resultado = rc_cliente_procesar_form( $user );

	$tickets = rc_mantis_listar_tickets( $user->user_email );
	$stats   = rc_cliente_calcular_stats( $tickets );

	ob_start();
	?>
	<div class="rc-cliente">

		<?php if ( ! empty( $resultado['msg'] ) ) : ?>
			<div class="rc-cliente-msg rc-cliente-msg--<?php echo esc_attr( $resultado['tipo'] ); ?>">
				<?php echo esc_html( $resultado['msg'] ); ?>
			</div>
		<?php endif; ?>

		<?php echo rc_cliente_render_stats( $stats ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped — HTML controlado ?>
		<?php echo rc_cliente_render_form(); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
		<?php echo rc_cliente_render_tickets( $tickets ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>

	</div>
	<?php
	return ob_get_clean();
}


// ── Subrenders ──────────────────────────────────────────────────────────────

function rc_cliente_render_login() {
	$login = wp_login_url( get_permalink() );
	$reg   = wp_registration_url();

	ob_start();
	?>
	<div class="rc-cliente-login">
		<p>Para acceder a tu dashboard tienes que iniciar sesión.</p>
		<p class="rc-cliente-login-actions">
			<a class="rc-btn rc-btn--accent" href="<?php echo esc_url( $login ); ?>">Iniciar sesión</a>
			<a class="rc-btn" href="<?php echo esc_url( $reg ); ?>">Crear cuenta</a>
		</p>
	</div>
	<?php
	return ob_get_clean();
}

function rc_cliente_calcular_stats( $tickets ) {
	$abiertos  = 0;
	$cerrados  = 0;

	foreach ( $tickets as $t ) {
		$status = isset( $t['status']['name'] ) ? $t['status']['name'] : '';
		if ( $status === 'closed' || $status === 'resolved' ) {
			$cerrados++;
		} else {
			$abiertos++;
		}
	}

	return array(
		'abiertos' => $abiertos,
		'cerrados' => $cerrados,
		'total'    => count( $tickets ),
	);
}

function rc_cliente_render_stats( $stats ) {
	ob_start();
	?>
	<div class="rc-cliente-stats">
		<div class="rc-stat">
			<div class="rc-stat-num"><?php echo intval( $stats['total'] ); ?></div>
			<div class="rc-stat-label">Tickets en total</div>
		</div>
		<div class="rc-stat">
			<div class="rc-stat-num rc-stat-num--warn"><?php echo intval( $stats['abiertos'] ); ?></div>
			<div class="rc-stat-label">En curso</div>
		</div>
		<div class="rc-stat">
			<div class="rc-stat-num rc-stat-num--ok"><?php echo intval( $stats['cerrados'] ); ?></div>
			<div class="rc-stat-label">Cerrados</div>
		</div>
	</div>
	<?php
	return ob_get_clean();
}

function rc_cliente_render_form() {
	ob_start();
	?>
	<details class="rc-cliente-solicitar" <?php echo empty( $_POST ) ? 'open' : ''; ?>>
		<summary><strong>Solicitar nuevo informe</strong></summary>

		<form method="post" class="rc-cliente-form">
			<?php wp_nonce_field( 'rc_solicitar_informe' ); ?>

			<label class="rc-cliente-label">
				Resumen del problema
				<input type="text" name="rc_summary" maxlength="120" required>
			</label>

			<label class="rc-cliente-label">
				Descripción detallada
				<textarea name="rc_description" rows="5" maxlength="2000" required></textarea>
			</label>

			<button type="submit" name="rc_solicitar_informe" value="1" class="rc-btn rc-btn--accent">
				Enviar solicitud
			</button>
		</form>
	</details>
	<?php
	return ob_get_clean();
}

function rc_cliente_render_tickets( $tickets ) {

	$base = rc_mantis_base_url();

	ob_start();
	?>
	<h3 class="rc-cliente-h3">Tu historial de informes</h3>

	<?php if ( empty( $tickets ) ) : ?>
		<div class="rc-cliente-empty">
			Aún no has solicitado ningún informe. Cuando envíes uno aparecerá aquí.
		</div>
	<?php else : ?>
		<ul class="rc-cliente-tickets">
		<?php foreach ( $tickets as $ticket ) :
			$status_name  = isset( $ticket['status']['name'] ) ? $ticket['status']['name'] : '';
			$status_label = isset( $ticket['status']['label'] ) ? $ticket['status']['label'] : '';
			$priority     = isset( $ticket['priority']['label'] ) ? $ticket['priority']['label'] : '-';
			$created_at   = isset( $ticket['created_at'] ) ? $ticket['created_at'] : '';
			$adjuntos     = isset( $ticket['attachments'] ) ? $ticket['attachments'] : array();
			?>
			<li class="rc-cliente-ticket">

				<div class="rc-ticket-head">
					<span class="rc-ticket-id">#<?php echo intval( $ticket['id'] ); ?></span>
					<span class="rc-ticket-status rc-status--<?php echo esc_attr( $status_name ); ?>">
						<?php echo esc_html( $status_label ); ?>
					</span>
				</div>

				<div class="rc-ticket-summary">
					<?php echo esc_html( isset( $ticket['summary'] ) ? $ticket['summary'] : '' ); ?>
				</div>

				<div class="rc-ticket-meta">
					<?php echo $created_at ? esc_html( gmdate( 'd/m/Y', strtotime( $created_at ) ) ) : '-'; ?>
					· prioridad <?php echo esc_html( $priority ); ?>
				</div>

				<?php if ( ! empty( $adjuntos ) ) : ?>
					<div class="rc-ticket-attachments">
						<strong>Informes adjuntos:</strong>
						<ul>
						<?php foreach ( $adjuntos as $att ) :
							$dl = $base . '/file_download.php?file_id=' . intval( $att['id'] ) . '&type=bug';
							$nm = isset( $att['filename'] ) ? $att['filename'] : 'archivo';
							?>
							<li>
								<a href="<?php echo esc_url( $dl ); ?>" target="_blank" rel="noopener">
									<?php echo esc_html( $nm ); ?>
								</a>
							</li>
						<?php endforeach; ?>
						</ul>
					</div>
				<?php endif; ?>

				<a class="rc-ticket-link"
				   href="<?php echo esc_url( $base . '/view.php?id=' . intval( $ticket['id'] ) ); ?>"
				   target="_blank" rel="noopener">
					Ver detalle en MantisBT
				</a>

			</li>
		<?php endforeach; ?>
		</ul>
	<?php endif; ?>
	<?php
	return ob_get_clean();
}


// ── Procesado del POST del formulario ───────────────────────────────────────

/**
 * Si llega un POST de solicitud, valida y crea el ticket. Devuelve un array
 * con el mensaje a pintar (tipo ok/err + texto). No imprime nada.
 *
 * Lo separo del render para que la lógica quede aislada y se pueda testear
 * a mano más fácil.
 */
function rc_cliente_procesar_form( $user ) {

	if ( ! isset( $_POST['rc_solicitar_informe'] ) ) {
		return array();
	}

	// Comprobación de nonce — si falla wp_die ya corta.
	check_admin_referer( 'rc_solicitar_informe' );

	$summary = isset( $_POST['rc_summary'] ) ? sanitize_text_field( wp_unslash( $_POST['rc_summary'] ) ) : '';
	$desc    = isset( $_POST['rc_description'] ) ? sanitize_textarea_field( wp_unslash( $_POST['rc_description'] ) ) : '';

	// Validaciones mínimas — Mantis luego también valida, pero damos feedback antes.
	if ( strlen( $summary ) < 5 || strlen( $desc ) < 10 ) {
		return array(
			'tipo' => 'err',
			'msg'  => 'El resumen y la descripción son obligatorios (resumen mínimo 5 caracteres, descripción 10).',
		);
	}

	$r = rc_mantis_crear_ticket( $summary, $desc, $user->user_email );

	if ( $r['ok'] ) {
		return array(
			'tipo' => 'ok',
			'msg'  => 'Solicitud creada — informe #' . $r['id'] . '. Te avisamos por email cuando esté listo.',
		);
	}

	return array(
		'tipo' => 'err',
		'msg'  => 'No se pudo crear la solicitud: ' . $r['msg'],
	);
}


// ─────────────────────────────────────────────────────────────────────────────
//  Registro de clientes — rol rc_cliente + CTA "Crear cuenta"
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Registra el rol `rc_cliente` (capacidades mínimas: leer su dashboard).
 *
 * Se ejecuta en activación del plugin y como red de seguridad en `init`
 * (idempotente: add_role no hace nada si ya existe).
 */
function rc_registrar_rol_cliente() {
	if ( ! get_role( 'rc_cliente' ) ) {
		add_role(
			'rc_cliente',
			'Cliente ResolveCore',
			array( 'read' => true )
		);
	}
}
register_activation_hook( __FILE__, 'rc_registrar_rol_cliente' );
add_action( 'init', 'rc_registrar_rol_cliente' );

/**
 * Hash estable de IP para rate-limiting (IPv4/IPv6). Local al plugin para no
 * depender del tema. Solo REMOTE_ADDR — no confiamos en X-Forwarded-For.
 */
function rc_cliente_ip_hash() {
	$ip = isset( $_SERVER['REMOTE_ADDR'] ) ? sanitize_text_field( wp_unslash( $_SERVER['REMOTE_ADDR'] ) ) : '';
	if ( ! filter_var( $ip, FILTER_VALIDATE_IP ) ) {
		$ip = '0.0.0.0';
	}
	return hash( 'sha256', $ip . wp_salt( 'auth' ) );
}

add_shortcode( 'rc_registro_cliente', 'rc_registro_cliente_render' );

/**
 * Render del formulario de alta de cliente (CTA separado del soporte).
 *
 * Procesa el POST en el propio render (mismo patrón que el dashboard). Crea el
 * usuario WP con rol rc_cliente y contraseña autogenerada, que se envía por
 * email junto al enlace de acceso.
 */
function rc_registro_cliente_render() {

	// Ya autenticado: no tiene sentido registrarse de nuevo.
	if ( is_user_logged_in() ) {
		$dash = home_url( '/dashboard/' );
		return '<div class="rc-cliente-msg rc-cliente-msg--ok">'
			. 'Ya tienes la sesión iniciada. '
			. '<a href="' . esc_url( $dash ) . '">Ir a mi dashboard</a>.'
			. '</div>';
	}

	$resultado = rc_registro_cliente_procesar();

	ob_start();
	?>
	<div class="rc-cliente rc-registro">

		<?php if ( ! empty( $resultado['msg'] ) ) : ?>
			<div class="rc-cliente-msg rc-cliente-msg--<?php echo esc_attr( $resultado['tipo'] ); ?>">
				<?php echo esc_html( $resultado['msg'] ); ?>
			</div>
		<?php endif; ?>

		<?php if ( empty( $resultado ) || $resultado['tipo'] !== 'ok' ) : ?>
		<form method="post" class="rc-cliente-form rc-registro-form">
			<?php wp_nonce_field( 'rc_registro_cliente' ); ?>

			<label class="rc-cliente-label">
				Nombre
				<input type="text" name="rc_nombre" maxlength="80" required>
			</label>

			<label class="rc-cliente-label">
				Email
				<input type="email" name="rc_email" maxlength="120" required>
			</label>

			<?php // Honeypot anti-spam — los bots rellenan campos ocultos. ?>
			<label class="rc-hp" aria-hidden="true" style="position:absolute;left:-9999px;" tabindex="-1">
				No rellenar
				<input type="text" name="rc_website" tabindex="-1" autocomplete="off">
			</label>

			<button type="submit" name="rc_crear_cuenta" value="1" class="rc-btn rc-btn--accent">
				Crear cuenta
			</button>

			<p class="rc-registro-nota">
				Te enviaremos tus credenciales de acceso por email. ¿Ya tienes cuenta?
				<a href="<?php echo esc_url( wp_login_url( home_url( '/dashboard/' ) ) ); ?>">Inicia sesión</a>.
			</p>
		</form>
		<?php endif; ?>

	</div>
	<?php
	return ob_get_clean();
}

/**
 * Valida y procesa el alta. Devuelve array{tipo,msg} para pintar; no imprime.
 *
 * @return array
 */
function rc_registro_cliente_procesar() {

	if ( ! isset( $_POST['rc_crear_cuenta'] ) ) {
		return array();
	}

	check_admin_referer( 'rc_registro_cliente' );

	// Honeypot: si viene relleno es un bot.
	if ( ! empty( $_POST['rc_website'] ) ) {
		return array( 'tipo' => 'err', 'msg' => 'No se pudo procesar el registro.' );
	}

	// Rate limit: máx. 3 altas por IP por hora.
	$rate_key = 'rc_registro_' . rc_cliente_ip_hash();
	$intentos = (int) get_transient( $rate_key );
	if ( $intentos >= 3 ) {
		return array( 'tipo' => 'err', 'msg' => 'Demasiados intentos. Espera un rato antes de volver a probar.' );
	}
	set_transient( $rate_key, $intentos + 1, HOUR_IN_SECONDS );

	$nombre = isset( $_POST['rc_nombre'] ) ? sanitize_text_field( wp_unslash( $_POST['rc_nombre'] ) ) : '';
	$email  = isset( $_POST['rc_email'] ) ? sanitize_email( wp_unslash( $_POST['rc_email'] ) ) : '';

	if ( strlen( $nombre ) < 2 || ! is_email( $email ) ) {
		return array( 'tipo' => 'err', 'msg' => 'Revisa el nombre y el email: son obligatorios y deben ser válidos.' );
	}

	if ( email_exists( $email ) ) {
		return array(
			'tipo' => 'err',
			'msg'  => 'Ya existe una cuenta con ese email. Inicia sesión o recupera tu contraseña.',
		);
	}

	// Username derivado del email, garantizando unicidad.
	$base_login = sanitize_user( current( explode( '@', $email ) ), true );
	if ( $base_login === '' ) {
		$base_login = 'cliente';
	}
	$login = $base_login;
	$n     = 1;
	while ( username_exists( $login ) ) {
		$login = $base_login . $n;
		$n++;
	}

	$password = wp_generate_password( 16, true );
	$user_id  = wp_insert_user(
		array(
			'user_login'   => $login,
			'user_email'   => $email,
			'user_pass'    => $password,
			'display_name' => $nombre,
			'first_name'   => $nombre,
			'role'         => 'rc_cliente',
		)
	);

	if ( is_wp_error( $user_id ) ) {
		error_log( '[rc-core] alta cliente fallida: ' . $user_id->get_error_message() );
		return array( 'tipo' => 'err', 'msg' => 'No se pudo crear la cuenta. Inténtalo más tarde.' );
	}

	rc_registro_cliente_email( $email, $nombre, $login, $password );

	return array(
		'tipo' => 'ok',
		'msg'  => 'Cuenta creada. Te hemos enviado tus credenciales de acceso a ' . $email . '.',
	);
}

/**
 * Envía al cliente sus credenciales recién creadas.
 *
 * El usuario eligió entrega de contraseña autogenerada por email. La clave
 * viaja en claro por correo (riesgo aceptado por diseño); se recomienda al
 * cliente cambiarla tras el primer acceso.
 *
 * @return bool true si wp_mail aceptó el envío.
 */
function rc_registro_cliente_email( $email, $nombre, $login, $password ) {

	$login_url = wp_login_url( home_url( '/dashboard/' ) );
	$e_nombre  = esc_html( $nombre );
	$e_login   = esc_html( $login );
	$e_pass    = esc_html( $password );
	$e_url     = esc_url( $login_url );

	$html =
			'<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">'
		. '<meta name="viewport" content="width=device-width,initial-scale=1"></head>'
		. '<body style="margin:0;padding:0;background:#0a0c10;">'
		. '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#0a0c10;">'
		. '<tr><td align="center" style="padding:28px 14px;">'
		. '<table role="presentation" width="600" cellpadding="0" cellspacing="0" '
		. 'style="max-width:600px;width:100%;background:#111318;border:1px solid #1f232c;border-radius:14px;overflow:hidden;">'
		. '<tr><td style="padding:22px 32px;background:#0a0c10;border-bottom:1px solid #1f232c;">'
		. '<span style="color:#f5f6f8;font-family:monospace;font-size:18px;font-weight:700;">ResolveCore</span>'
		. '<span style="color:#00e5a0;font-family:monospace;font-size:11px;letter-spacing:.12em;'
		. 'float:right;padding-top:6px;">// CUENTA</span>'
		. '</td></tr>'
		. '<tr><td style="padding:32px;">'
		. '<h1 style="margin:0 0 6px;color:#f5f6f8;font-family:Arial,sans-serif;font-size:21px;">'
		. 'Tu cuenta está lista</h1>'
		. '<p style="margin:0 0 20px;color:#c5c8cf;font-family:Arial,sans-serif;font-size:14px;line-height:1.6;">'
		. 'Hola <strong>' . $e_nombre . '</strong>, hemos creado tu cuenta de cliente en ResolveCore. '
		. 'Usa estas credenciales para acceder a tu dashboard:</p>'
		. '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" '
		. 'style="margin:0 0 24px;border:1px solid rgba(0,229,160,.3);border-radius:10px;background:#0f1f1a;">'
		. '<tr><td style="padding:18px 22px;">'
		. '<div style="color:#7a7f8e;font-family:monospace;font-size:10px;letter-spacing:.12em;'
		. 'text-transform:uppercase;">Usuario</div>'
		. '<div style="color:#00e5a0;font-family:monospace;font-size:16px;font-weight:700;margin:4px 0 12px;">'
		. $e_login . '</div>'
		. '<div style="color:#7a7f8e;font-family:monospace;font-size:10px;letter-spacing:.12em;'
		. 'text-transform:uppercase;">Contraseña</div>'
		. '<div style="color:#00e5a0;font-family:monospace;font-size:16px;font-weight:700;margin:4px 0 0;">'
		. $e_pass . '</div>'
		. '</td></tr></table>'
		. '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:8px 0 4px;">'
		. '<tr><td style="border-radius:8px;background:#00e5a0;">'
		. '<a href="' . $e_url . '" style="display:inline-block;padding:13px 26px;color:#05140f;'
		. 'font-size:14px;font-weight:700;text-decoration:none;font-family:Arial,sans-serif;">'
		. 'Acceder a mi dashboard &rarr;</a>'
		. '</td></tr></table>'
		. '<p style="margin:20px 0 0;color:#7a7f8e;font-family:Arial,sans-serif;font-size:12px;line-height:1.6;">'
		. 'Por seguridad, te recomendamos cambiar la contraseña tras el primer acceso '
		. 'desde tu perfil.</p>'
		. '</td></tr>'
		. '<tr><td style="padding:18px 32px;background:#0a0c10;border-top:1px solid #1f232c;">'
		. '<p style="margin:0;color:#5a5f6c;font-family:Arial,sans-serif;font-size:11px;line-height:1.6;">'
		. 'Este correo es automático.<br>'
		. 'ResolveCore — Solución a tus problemas informáticos.</p>'
		. '</td></tr>'
		. '</table></td></tr></table></body></html>';

	$text  = "Tu cuenta está lista\n\n";
	$text .= 'Hola ' . $nombre . ", hemos creado tu cuenta de cliente en ResolveCore.\n\n";
	$text .= 'Usuario: ' . $login . "\n";
	$text .= 'Contraseña: ' . $password . "\n\n";
	$text .= 'Accede a tu dashboard: ' . $login_url . "\n\n";
	$text .= "Por seguridad, cambia la contraseña tras el primer acceso.\n\n";
	$text .= "—\nEste correo es automático.\nResolveCore — Solución a tus problemas informáticos.\n";

	$headers = array(
		'Content-Type: text/html; charset=UTF-8',
		'Reply-To: ' . get_option( 'admin_email' ),
	);

	$alt_body = static function ( $phpmailer ) use ( $text ) {
		$phpmailer->AltBody = $text;
	};
	add_action( 'phpmailer_init', $alt_body );
	$sent = @wp_mail( $email, 'ResolveCore — Tus credenciales de acceso', $html, $headers );
	remove_action( 'phpmailer_init', $alt_body );

	if ( ! $sent ) {
		error_log( '[rc-core] email credenciales: wp_mail devolvió false para ' . $email );
	}
	return (bool) $sent;
}
