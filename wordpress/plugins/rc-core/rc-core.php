<?php
/**
 * Plugin Name: RC Core
 * Plugin URI:  https://resolvecore.website
 * Description: Funciones específicas del cliente — shortcodes [rc_cliente_dashboard]
 *              (tickets + solicitar informes) y [rc_registro_cliente] (alta de
 *              cuenta rol rc_cliente con enlace de activación por email).
 * Version:     1.5.2
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
 * Resultado cacheado 60 s con set_transient para no castigar la API de
 * MantisBT en cada visita a la página (la clave incluye el hash del email).
 */
function rc_mantis_listar_tickets( $user_email ) {

	$cache_key = 'rc_mantis_tickets_' . md5( strtolower( trim( $user_email ) ) );
	$cached    = get_transient( $cache_key );
	if ( false !== $cached ) {
		return $cached;
	}

	$tickets = rc_mantis_listar_tickets_uncached( $user_email );

	// Cache corta (60 s): suficiente para absorber refrescos/navegación rápida
	// sin servir datos perceptiblemente obsoletos al cliente.
	set_transient( $cache_key, $tickets, 60 );

	return $tickets;
}

/**
 * Lógica real de consulta a MantisBT (sin cache). No llamar directamente desde
 * las vistas: usar rc_mantis_listar_tickets(), que añade la capa de transient.
 */
function rc_mantis_listar_tickets_uncached( $user_email ) {

	$issues = array();

	// Vía preferente: RC_Mantis_API::search_issues (transporte centralizado).
	if ( function_exists( 'rc_mantis_get_api' ) ) {
		$api = rc_mantis_get_api();
		if ( $api && method_exists( $api, 'search_issues' ) ) {
			$res    = $api->search_issues( $user_email, 50 );
			$issues = is_wp_error( $res ) ? array() : $res;
			return rc_mantis_filtrar_por_cliente( $issues, $user_email );
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

	$body   = json_decode( wp_remote_retrieve_body( $response ), true );
	$issues = isset( $body['issues'] ) ? $body['issues'] : array();
	return rc_mantis_filtrar_por_cliente( $issues, $user_email );
}

/**
 * Filtra una lista de issues dejando SOLO los del cliente indicado.
 *
 * Imprescindible por seguridad: el endpoint `/api/rest/issues` de Mantis
 * **ignora** el parámetro `search` y devuelve TODOS los tickets, así que sin
 * este filtro el dashboard de un cliente mostraría los tickets de los demás
 * (fuga de datos). El criterio de pertenencia es robusto:
 *   1) email del reporter == email del cliente, o
 *   2) el email aparece en la descripción (lo inyectamos como
 *      «Solicitado por: <email>» en rc_mantis_crear_ticket()).
 *
 * @param array  $issues      Lista de issues tal cual la devuelve Mantis.
 * @param string $user_email  Email del cliente logueado.
 * @return array              Solo los issues que pertenecen al cliente.
 */
function rc_mantis_filtrar_por_cliente( $issues, $user_email ) {
	$email = strtolower( trim( (string) $user_email ) );
	if ( '' === $email || empty( $issues ) || ! is_array( $issues ) ) {
		return array();
	}

	$mios = array();
	foreach ( $issues as $issue ) {
		if ( ! is_array( $issue ) ) {
			continue;
		}

		$reporter_email = strtolower( trim( (string) ( $issue['reporter']['email'] ?? '' ) ) );
		$descripcion    = strtolower( (string) ( $issue['description'] ?? '' ) );

		if ( ( '' !== $reporter_email && $reporter_email === $email )
			|| ( '' !== $descripcion && false !== strpos( $descripcion, $email ) ) ) {
			$mios[] = $issue;
		}
	}

	return $mios;
}

/**
 * Un ticket es editable por el cliente solo mientras está «nuevo» (status < 30).
 * A partir de 30 (acknowledged) ya está en manos del técnico y no debe poder
 * modificarse ni borrarse desde el dashboard. Enum Mantis:
 * 10 new · 20 feedback · 30 acknowledged · 40 confirmed · 50 assigned · 80 resolved · 90 closed.
 */
function rc_cliente_ticket_editable( $status_id ) {
	return (int) $status_id < 30;
}

/**
 * Devuelve el ID del primer ticket en estado «feedback» (20 = esperando respuesta
 * del cliente), o 0 si no hay ninguno. Sirve para avisar al cliente de que tiene
 * un ticket pendiente de su respuesta antes de que abra uno nuevo.
 */
function rc_cliente_ticket_en_feedback( $tickets ) {
	foreach ( (array) $tickets as $t ) {
		$sid = isset( $t['status']['id'] ) ? (int) $t['status']['id'] : 0;
		if ( 20 === $sid ) {
			return isset( $t['id'] ) ? (int) $t['id'] : 0;
		}
	}
	return 0;
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
		<?php echo rc_cliente_render_form( $tickets ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
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
		// Por ID, no por nombre: Mantis localiza los nombres de estado (es/en) y
		// comparar strings rompía el conteo. 80=resolved, 90=closed (enum Mantis).
		$status_id = isset( $t['status']['id'] ) ? (int) $t['status']['id'] : 0;
		if ( $status_id >= 80 ) {
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
		<div class="rc-pill rc-pill--total">
			<span class="rc-pill-num"><?php echo intval( $stats['total'] ); ?></span>
			<span class="rc-pill-label">Tickets en total</span>
		</div>
		<div class="rc-pill rc-pill--progress">
			<span class="rc-pill-num"><?php echo intval( $stats['abiertos'] ); ?></span>
			<span class="rc-pill-label">En curso</span>
		</div>
		<div class="rc-pill rc-pill--done">
			<span class="rc-pill-num"><?php echo intval( $stats['cerrados'] ); ?></span>
			<span class="rc-pill-label">Cerrados</span>
		</div>
	</div>
	<?php
	return ob_get_clean();
}

function rc_cliente_render_form( $tickets = array() ) {
	$feedback_id = rc_cliente_ticket_en_feedback( $tickets );
	ob_start();
	?>
	<?php if ( $feedback_id ) : ?>
		<div class="rc-cliente-msg rc-cliente-msg--feedback">
			Tienes un ticket esperando tu respuesta. Revisa el ticket
			#<?php echo (int) $feedback_id; ?> antes de crear uno nuevo.
		</div>
	<?php endif; ?>
	<?php
	// Abierto por defecto. Solo lo colapsamos si se acaba de enviar ESTE
	// formulario (no cualquier POST del sitio). El nonce ya lo validó
	// rc_cliente_procesar_form() antes de llegar aquí.
	$rc_form_enviado = isset( $_POST['rc_solicitar_informe'] ); // phpcs:ignore WordPress.Security.NonceVerification.Missing
	?>
	<details id="solicitar" class="rc-cliente-solicitar" <?php echo $rc_form_enviado ? '' : 'open'; ?>>
		<summary>
			<span class="rc-solicitar-summary-main">
				<span class="rc-solicitar-icon" aria-hidden="true">+</span>
				<span class="rc-solicitar-summary-text">
					<strong>Solicitar nuevo informe</strong>
					<small>Abre un ticket de soporte — respuesta en menos de 2 horas</small>
				</span>
			</span>
			<span class="rc-solicitar-chevron" aria-hidden="true">&#9662;</span>
		</summary>

		<form method="post" class="rc-cliente-form">
			<?php wp_nonce_field( 'rc_solicitar_informe' ); ?>

			<label class="rc-cliente-label">
				Resumen del problema
				<input type="text" name="rc_summary" maxlength="120" autocomplete="off" required>
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
			$status_label = isset( $ticket['status']['label'] ) ? $ticket['status']['label'] : ( $status_name ?: '—' );
			$status_id    = isset( $ticket['status']['id'] ) ? (int) $ticket['status']['id'] : 0;
			$priority     = isset( $ticket['priority']['label'] ) ? $ticket['priority']['label'] : '-';
			$prio_name    = isset( $ticket['priority']['name'] ) ? $ticket['priority']['name'] : '';
			$created_at   = isset( $ticket['created_at'] ) ? $ticket['created_at'] : '';
			$updated_at   = isset( $ticket['updated_at'] ) ? $ticket['updated_at'] : '';
			$adjuntos     = isset( $ticket['attachments'] ) ? $ticket['attachments'] : array();

			// Familia de estado para el borde-acento: <50 pendiente, 50-79 en curso, >=80 hecho.
			if ( $status_id >= 80 ) {
				$estado_clase = 'is-hecho';
			} elseif ( $status_id >= 50 ) {
				$estado_clase = 'is-progreso';
			} else {
				$estado_clase = 'is-pendiente';
			}
			?>
			<li class="rc-cliente-ticket <?php echo esc_attr( $estado_clase ); ?>">

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
					<span>Creado <?php echo $created_at ? esc_html( gmdate( 'd/m/Y', strtotime( $created_at ) ) ) : '-'; ?></span>
					<?php if ( $updated_at && $updated_at !== $created_at ) : ?>
						<span class="rc-ticket-meta-sep">·</span>
						<span>Actualizado <?php echo esc_html( gmdate( 'd/m/Y', strtotime( $updated_at ) ) ); ?></span>
					<?php endif; ?>
					<span class="rc-ticket-meta-sep">·</span>
					<span class="rc-ticket-prio is-<?php echo esc_attr( $prio_name ); ?>"><?php echo esc_html( $priority ); ?></span>
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

				<?php
				// Progreso de la incidencia para el cliente — 4 fases derivadas del
				// estado del ticket. NO se expone enlace a MantisBT: el cliente solo
				// debe ver en qué punto está su incidencia, nunca la herramienta interna.
				// Mapeo igual que resolvecore_handle_ticket_status() (theme functions.php):
				// 10 new · 20 feedback · 30 ack · 40 confirmed · 50 assigned · 80 resolved · 90 closed.
				$fase  = ( $status_id >= 80 ) ? 4 : ( ( $status_id >= 50 ) ? 3 : ( ( $status_id >= 30 ) ? 2 : 1 ) );
				$fases = array( 'Recibido', 'En diagnóstico', 'En resolución', 'Resuelto' );
				?>
				<div class="rc-ticket-progress" role="img"
				     aria-label="<?php echo esc_attr( 'Progreso: ' . $fases[ $fase - 1 ] . ' — fase ' . $fase . ' de 4' ); ?>">
					<?php foreach ( $fases as $i => $nombre ) :
						$n   = $i + 1;
						$cls = ( $n < $fase ) ? 'is-done' : ( ( $n === $fase ) ? 'is-active' : '' );
						?>
						<div class="rc-prog-step <?php echo esc_attr( $cls ); ?>">
							<span class="rc-prog-dot" aria-hidden="true"></span>
							<span class="rc-prog-label"><?php echo esc_html( $nombre ); ?></span>
						</div>
					<?php endforeach; ?>
				</div>

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

	// Guard defensivo: este formulario solo CREA tickets. Si en el futuro se
	// añade edición, no debe permitirse modificar un ticket que ya gestiona el
	// técnico (status >= 30). Hoy el alta nunca envía rc_ticket_id, así que
	// cualquier valor es ilegítimo y se rechaza.
	$edit_id = isset( $_POST['rc_ticket_id'] ) ? absint( wp_unslash( $_POST['rc_ticket_id'] ) ) : 0;
	if ( $edit_id > 0 ) {
		return array(
			'tipo' => 'err',
			'msg'  => 'No es posible modificar un ticket en curso desde el panel. Crea una solicitud nueva o responde desde el ticket.',
		);
	}

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
 * Procesa el alta de cliente ANTES de renderizar (en template_redirect), para
 * poder iniciar sesión (set-cookie) y redirigir sin "headers already sent".
 * El resultado se guarda en $GLOBALS['rc_registro_resultado'] para que el
 * shortcode lo pinte (errores) sin reprocesar el POST.
 */
add_action(
	'template_redirect',
	function () {
		if ( ! isset( $_POST['rc_crear_cuenta'] ) ) {
			return;
		}
		$res = rc_registro_cliente_procesar();
		$GLOBALS['rc_registro_resultado'] = $res;

		// Alta correcta con contraseña: login + redirección al dashboard.
		if ( ! empty( $res['tipo'] ) && 'ok' === $res['tipo'] && ! empty( $res['user_id'] ) && ! empty( $res['pass'] ) ) {
			$user   = get_userdata( (int) $res['user_id'] );
			$signon = $user ? wp_signon(
				array(
					'user_login'    => $user->user_login,
					'user_password' => $res['pass'],
					'remember'      => true,
				),
				is_ssl()
			) : null;
			if ( $signon && ! is_wp_error( $signon ) ) {
				wp_safe_redirect( home_url( '/dashboard/' ) );
				exit;
			}
			// Alta OK pero el auto-login falló: no dejamos al usuario con un mensaje
			// engañoso. Lo mandamos a la pestaña de login con la cuenta ya creada.
			wp_safe_redirect(
				add_query_arg(
					array( 'tab' => 'login', 'alta' => 'ok' ),
					home_url( '/registro/' )
				)
			);
			exit;
		}
	}
);

/**
 * Si el login falla y venía de nuestra página /registro, devolvemos al usuario
 * a esa página con ?login=failed para mostrar el error en la pestaña de login
 * (en vez de mandarlo a wp-login.php). Mantiene el flujo dentro del sitio.
 */
add_action(
	'wp_login_failed',
	function () {
		$ref = wp_get_referer();
		if ( $ref && false !== strpos( $ref, '/registro' ) ) {
			wp_safe_redirect( add_query_arg( array( 'tab' => 'login', 'login' => 'failed' ), $ref ) );
			exit;
		}
	}
);

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

	// El POST ya lo procesó rc_registro_handle_post() en template_redirect; aquí
	// solo leemos el resultado para pintarlo (si lo hay).
	$resultado = isset( $GLOBALS['rc_registro_resultado'] ) ? (array) $GLOBALS['rc_registro_resultado'] : array();

	// Tras un alta correcta abrimos la pestaña de registro (muestra el OK);
	// si llega ?tab=login o hubo un error de login, abrimos Iniciar sesión.
	$tab   = isset( $_GET['tab'] ) ? sanitize_key( wp_unslash( $_GET['tab'] ) ) : 'registro';
	$login = isset( $_GET['login'] ) ? sanitize_key( wp_unslash( $_GET['login'] ) ) : '';
	if ( 'failed' === $login ) {
		$tab = 'login';
	}
	$is_login = ( 'login' === $tab );

	$dash = home_url( '/dashboard/' );

	ob_start();
	?>
	<div class="rc-cliente rc-registro rc-auth">

		<div class="rc-auth-tabs" role="tablist">
			<button type="button" class="rc-auth-tab<?php echo $is_login ? '' : ' active'; ?>"
					role="tab" aria-selected="<?php echo $is_login ? 'false' : 'true'; ?>"
					data-tab="registro">Crear cuenta</button>
			<button type="button" class="rc-auth-tab<?php echo $is_login ? ' active' : ''; ?>"
					role="tab" aria-selected="<?php echo $is_login ? 'true' : 'false'; ?>"
					data-tab="login">Iniciar sesión</button>
		</div>

		<?php if ( ! empty( $resultado['msg'] ) ) : ?>
			<div class="rc-cliente-msg rc-cliente-msg--<?php echo esc_attr( $resultado['tipo'] ); ?>">
				<?php echo esc_html( $resultado['msg'] ); ?>
			</div>
		<?php endif; ?>

		<?php if ( 'failed' === $login ) : ?>
			<div class="rc-cliente-msg rc-cliente-msg--err">
				Usuario o contraseña incorrectos. Inténtalo de nuevo.
			</div>
		<?php endif; ?>

		<?php // Alta correcta pero el auto-login no entró: confirmamos y pedimos login. ?>
		<?php if ( isset( $_GET['alta'] ) && 'ok' === sanitize_key( wp_unslash( $_GET['alta'] ) ) ) : ?>
			<div class="rc-cliente-msg rc-cliente-msg--ok">
				Cuenta creada correctamente. Inicia sesión con tu email y contraseña.
			</div>
		<?php endif; ?>

		<?php // ── Panel: Crear cuenta ───────────────────────────────────── ?>
		<div class="rc-auth-panel rc-auth-panel--registro" data-panel="registro"<?php echo $is_login ? ' hidden' : ''; ?>>
		<?php if ( empty( $resultado ) || $resultado['tipo'] !== 'ok' ) : ?>
			<form method="post" class="rc-cliente-form rc-registro-form">
				<?php wp_nonce_field( 'rc_registro_cliente' ); ?>

				<label class="rc-cliente-label">
					Nombre
					<input type="text" name="rc_nombre" maxlength="80" autocomplete="name" required>
				</label>

				<label class="rc-cliente-label">
					Email
					<input type="email" name="rc_email" maxlength="120" autocomplete="email" inputmode="email" spellcheck="false" required>
				</label>

				<label class="rc-cliente-label">
					Contraseña
					<input type="password" name="rc_pass" minlength="8" maxlength="72" autocomplete="new-password" required>
				</label>

				<label class="rc-cliente-label">
					Repetir contraseña
					<input type="password" name="rc_pass2" minlength="8" maxlength="72" autocomplete="new-password" required>
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
					<a href="#" class="rc-auth-switch" data-tab="login">Inicia sesión</a>.
				</p>
			</form>
		<?php endif; ?>
		</div>

		<?php // ── Panel: Iniciar sesión ─────────────────────────────────── ?>
		<div class="rc-auth-panel rc-auth-panel--login" data-panel="login"<?php echo $is_login ? '' : ' hidden'; ?>>
			<?php
			wp_login_form(
				array(
					'echo'           => true,
					'redirect'       => $dash,
					'form_id'        => 'rc-login-form',
					'label_username' => 'Email o usuario',
					'label_password' => 'Contraseña',
					'label_remember' => 'Recordarme',
					'label_log_in'   => 'Entrar',
					'remember'       => true,
				)
			);
			?>
			<p class="rc-registro-nota">
				<a href="<?php echo esc_url( wp_lostpassword_url( $dash ) ); ?>">¿Olvidaste tu contraseña?</a>
				· ¿No tienes cuenta?
				<a href="#" class="rc-auth-switch" data-tab="registro">Crea una</a>.
			</p>
		</div>

	</div>

	<script>
	( function () {
		var root = document.currentScript.previousElementSibling;
		if ( ! root || ! root.classList.contains( 'rc-auth' ) ) {
			root = document.querySelector( '.rc-auth' );
		}
		if ( ! root ) return;
		function show( tab ) {
			root.querySelectorAll( '.rc-auth-tab' ).forEach( function ( b ) {
				var on = b.dataset.tab === tab;
				b.classList.toggle( 'active', on );
				b.setAttribute( 'aria-selected', on ? 'true' : 'false' );
			} );
			root.querySelectorAll( '.rc-auth-panel' ).forEach( function ( p ) {
				p.hidden = ( p.dataset.panel !== tab );
			} );
		}
		root.addEventListener( 'click', function ( e ) {
			var t = e.target.closest( '[data-tab]' );
			if ( ! t ) return;
			if ( t.classList.contains( 'rc-auth-switch' ) ) e.preventDefault();
			show( t.dataset.tab );
		} );
	} )();
	</script>
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

	// Rate limit: máx. 3 altas por IP por hora. Solo COMPROBAMOS aquí; el
	// incremento se hace más abajo, justo antes de crear la cuenta, para que un
	// error de formulario (contraseñas que no coinciden, email mal escrito) no
	// gaste la cuota y bloquee a un usuario legítimo que está corrigiendo.
	$rate_key = 'rc_registro_' . rc_cliente_ip_hash();
	$intentos = (int) get_transient( $rate_key );
	if ( $intentos >= 3 ) {
		return array( 'tipo' => 'err', 'msg' => 'Demasiados intentos. Espera un rato antes de volver a probar.' );
	}

	$nombre = isset( $_POST['rc_nombre'] ) ? sanitize_text_field( wp_unslash( $_POST['rc_nombre'] ) ) : '';
	$email  = isset( $_POST['rc_email'] ) ? sanitize_email( wp_unslash( $_POST['rc_email'] ) ) : '';
	// La contraseña NO se sanea (alteraría caracteres válidos); se valida tal cual.
	$pass   = isset( $_POST['rc_pass'] ) ? (string) wp_unslash( $_POST['rc_pass'] ) : '';
	$pass2  = isset( $_POST['rc_pass2'] ) ? (string) wp_unslash( $_POST['rc_pass2'] ) : '';

	if ( strlen( $nombre ) < 2 || ! is_email( $email ) ) {
		return array( 'tipo' => 'err', 'msg' => 'Revisa el nombre y el email: son obligatorios y deben ser válidos.' );
	}

	if ( strlen( $pass ) < 8 ) {
		return array( 'tipo' => 'err', 'msg' => 'La contraseña debe tener al menos 8 caracteres.' );
	}
	if ( $pass !== $pass2 ) {
		return array( 'tipo' => 'err', 'msg' => 'Las contraseñas no coinciden.' );
	}

	if ( email_exists( $email ) ) {
		return array(
			'tipo' => 'err',
			'msg'  => 'Ya existe una cuenta con ese email. Inicia sesión o recupera tu contraseña.',
		);
	}

	// Datos válidos: ahora sí consumimos cuota antes del alta real.
	set_transient( $rate_key, $intentos + 1, HOUR_IN_SECONDS );

	$res = rc_crear_cuenta_cliente( $email, $nombre, $pass );

	if ( $res['created'] ) {
		// Devolvemos user_id + la contraseña en claro SOLO para que el handler de
		// template_redirect (rc_registro_handle_post) haga el login y la redirección
		// antes de que se envíen las cabeceras. No se persiste en ningún sitio.
		return array(
			'tipo'    => 'ok',
			'msg'     => 'Cuenta creada. Ya puedes iniciar sesión con tu email y contraseña.',
			'user_id' => (int) $res['user_id'],
			'pass'    => $pass,
		);
	}

	return array(
		'tipo' => 'err',
		'msg'  => $res['msg'] ?? 'No se pudo crear la cuenta. Inténtalo más tarde.',
	);
}

/**
 * Crea (si no existe) la cuenta de cliente rol rc_cliente y le envía el email
 * de activación con el enlace para fijar contraseña.
 *
 * Reutilizable: lo usan el shortcode [rc_registro_cliente] y el formulario de
 * contacto de la home (functions.php). Idempotente por email: si ya hay cuenta
 * no hace nada y devuelve created=false, reason=exists.
 *
 * @param string $email    Email ya validado.
 * @param string $nombre   Nombre del cliente (ya saneado).
 * @param string $password Contraseña elegida por el cliente. Si está vacía se
 *                         usa el flujo passwordless (email con enlace de activación);
 *                         si se pasa, la cuenta queda activa al instante.
 * @return array{created:bool, reason?:string, msg?:string, user_id?:int}
 */
function rc_crear_cuenta_cliente( $email, $nombre, $password = '' ) {

	if ( ! is_email( $email ) ) {
		return array( 'created' => false, 'reason' => 'invalid', 'msg' => 'Email inválido.' );
	}
	if ( email_exists( $email ) ) {
		return array( 'created' => false, 'reason' => 'exists' );
	}

	$has_password = ( '' !== $password );

	// A3 (auditoría): throttle por-email. Solo aplica al flujo passwordless, que
	// envía email: sin esto un atacante podría bombardear el buzón de una víctima.
	// Con contraseña elegida no se envía email de activación, así que no aplica.
	$email_key = 'rc_alta_email_' . hash( 'sha256', strtolower( $email ) . wp_salt( 'auth' ) );
	if ( ! $has_password && get_transient( $email_key ) ) {
		return array( 'created' => false, 'reason' => 'throttled', 'msg' => 'Ya enviamos un email de activación a esa dirección hace poco. Revisa tu bandeja (y spam).' );
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

	// Con contraseña elegida usamos esa; sin ella, una aleatoria fuerte que NUNCA
	// se envía (el cliente la fija vía el enlace de activación).
	$user_id = wp_insert_user(
		array(
			'user_login'   => $login,
			'user_email'   => $email,
			'user_pass'    => $has_password ? $password : wp_generate_password( 24, true ),
			'display_name' => $nombre !== '' ? $nombre : $login,
			'first_name'   => $nombre,
			'role'         => 'rc_cliente',
		)
	);

	if ( is_wp_error( $user_id ) ) {
		error_log( '[rc-core] alta cliente fallida: ' . $user_id->get_error_message() );
		return array( 'created' => false, 'reason' => 'error', 'msg' => 'No se pudo crear la cuenta.' );
	}

	// Flujo con contraseña: cuenta activa al instante. Aun así enviamos un correo
	// de bienvenida (el cliente espera recibir confirmación de que su cuenta se
	// creó). No incluye contraseña: solo confirma el alta y enlaza al panel.
	if ( $has_password ) {
		rc_cliente_email_bienvenida( $email, $nombre, $login );
		return array( 'created' => true, 'user_id' => (int) $user_id );
	}

	// Flujo passwordless: marca la cuenta como pendiente de activación (verificación
	// de email). Se limpia en rc_cliente_on_password_reset() al fijar contraseña vía
	// el enlace. rc_cliente_purgar_pendientes() (cron) borra las que nunca se activan.
	update_user_meta( $user_id, 'rc_pending_activation', time() );
	set_transient( $email_key, 1, HOUR_IN_SECONDS );

	// Enlace de fijar contraseña: clave de reset nativa + URL de wp-login.
	$user = get_user_by( 'id', $user_id );
	$key  = get_password_reset_key( $user );
	if ( is_wp_error( $key ) ) {
		error_log( '[rc-core] reset key fallida: ' . $key->get_error_message() );
		return array(
			'created' => true,
			'user_id' => (int) $user_id,
			'reason'  => 'no_key',
			'msg'     => 'Cuenta creada, pero no se pudo generar el enlace. Usa "He olvidado mi contraseña" en el login.',
		);
	}
	$reset_url = network_site_url(
		'wp-login.php?action=rp&key=' . rawurlencode( $key ) . '&login=' . rawurlencode( $user->user_login ),
		'login'
	);

	rc_registro_cliente_email( $email, $nombre, $login, $reset_url );

	return array( 'created' => true, 'user_id' => (int) $user_id );
}

/**
 * Envía al cliente el email de activación con el enlace para fijar su contraseña.
 *
 * No se envía ninguna contraseña: el enlace usa la clave de reset nativa de
 * WordPress, que caduca y es de un solo uso.
 *
 * @param string $email
 * @param string $nombre
 * @param string $login      Nombre de usuario asignado.
 * @param string $reset_url  URL de fijar contraseña (wp-login action=rp).
 * @return bool true si wp_mail aceptó el envío.
 */
function rc_registro_cliente_email( $email, $nombre, $login, $reset_url ) {

	$e_nombre = esc_html( $nombre );
	$e_login  = esc_html( $login );
	$e_url    = esc_url( $reset_url );

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
		. 'Activa tu cuenta</h1>'
		. '<p style="margin:0 0 20px;color:#c5c8cf;font-family:Arial,sans-serif;font-size:14px;line-height:1.6;">'
		. 'Hola <strong>' . $e_nombre . '</strong>, hemos creado tu cuenta de cliente en ResolveCore. '
		. 'Tu usuario es el siguiente; pulsa el botón para fijar tu contraseña y entrar:</p>'
		. '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" '
		. 'style="margin:0 0 24px;border:1px solid rgba(0,229,160,.3);border-radius:10px;background:#0f1f1a;">'
		. '<tr><td style="padding:18px 22px;">'
		. '<div style="color:#7a7f8e;font-family:monospace;font-size:10px;letter-spacing:.12em;'
		. 'text-transform:uppercase;">Usuario</div>'
		. '<div style="color:#00e5a0;font-family:monospace;font-size:16px;font-weight:700;margin:4px 0 0;">'
		. $e_login . '</div>'
		. '</td></tr></table>'
		. '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:8px 0 4px;">'
		. '<tr><td style="border-radius:8px;background:#00e5a0;">'
		. '<a href="' . $e_url . '" style="display:inline-block;padding:13px 26px;color:#05140f;'
		. 'font-size:14px;font-weight:700;text-decoration:none;font-family:Arial,sans-serif;">'
		. 'Fijar mi contraseña &rarr;</a>'
		. '</td></tr></table>'
		. '<p style="margin:20px 0 0;color:#7a7f8e;font-family:Arial,sans-serif;font-size:12px;line-height:1.6;">'
		. 'El enlace caduca y es de un solo uso. Si expira, usa '
		. '«He olvidado mi contraseña» en la pantalla de acceso.</p>'
		. '</td></tr>'
		. '<tr><td style="padding:18px 32px;background:#0a0c10;border-top:1px solid #1f232c;">'
		. '<p style="margin:0;color:#5a5f6c;font-family:Arial,sans-serif;font-size:11px;line-height:1.6;">'
		. 'Este correo es automático.<br>'
		. 'ResolveCore — Solución a tus problemas informáticos.</p>'
		. '</td></tr>'
		. '</table></td></tr></table></body></html>';

	$text  = "Activa tu cuenta\n\n";
	$text .= 'Hola ' . $nombre . ", hemos creado tu cuenta de cliente en ResolveCore.\n\n";
	$text .= 'Usuario: ' . $login . "\n\n";
	$text .= "Fija tu contraseña y entra desde este enlace (un solo uso, caduca):\n";
	$text .= $reset_url . "\n\n";
	$text .= "Si expira, usa 'He olvidado mi contraseña' en la pantalla de acceso.\n\n";
	$text .= "—\nEste correo es automático.\nResolveCore — Solución a tus problemas informáticos.\n";

	$headers = array(
		'Content-Type: text/html; charset=UTF-8',
		'Reply-To: ' . get_option( 'admin_email' ),
	);

	$alt_body = static function ( $phpmailer ) use ( $text ) {
		$phpmailer->AltBody = $text;
	};
	add_action( 'phpmailer_init', $alt_body );
	$sent = wp_mail( $email, 'ResolveCore — Activa tu cuenta', $html, $headers );
	remove_action( 'phpmailer_init', $alt_body );

	if ( ! $sent ) {
		error_log( '[rc-core] email credenciales: wp_mail devolvió false para ' . $email );
	}
	return (bool) $sent;
}

/**
 * Email de bienvenida para el alta CON contraseña (cuenta ya activa). No envía
 * contraseña ni enlace de reset: confirma el alta y enlaza al panel de cliente.
 *
 * @return bool true si wp_mail aceptó el envío.
 */
function rc_cliente_email_bienvenida( $email, $nombre, $login ) {

	$e_nombre = esc_html( $nombre );
	$e_login  = esc_html( $login );
	$dash_url = esc_url( home_url( '/dashboard/' ) );

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
		. 'Bienvenido a ResolveCore</h1>'
		. '<p style="margin:0 0 20px;color:#c5c8cf;font-family:Arial,sans-serif;font-size:14px;line-height:1.6;">'
		. 'Hola <strong>' . $e_nombre . '</strong>, tu cuenta de cliente ya está activa. '
		. 'Tu usuario es <strong style="color:#00e5a0;font-family:monospace;">' . $e_login . '</strong>. '
		. 'Entra a tu panel para solicitar informes y seguir tus tickets:</p>'
		. '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:8px 0 4px;">'
		. '<tr><td style="border-radius:8px;background:#00e5a0;">'
		. '<a href="' . $dash_url . '" style="display:inline-block;padding:13px 26px;color:#05140f;'
		. 'font-size:14px;font-weight:700;text-decoration:none;font-family:Arial,sans-serif;">'
		. 'Ir a mi panel &rarr;</a>'
		. '</td></tr></table>'
		. '<p style="margin:20px 0 0;color:#7a7f8e;font-family:Arial,sans-serif;font-size:12px;line-height:1.6;">'
		. 'Inicia sesión con tu email y la contraseña que elegiste. Si la olvidas, usa '
		. '«He olvidado mi contraseña» en la pantalla de acceso.</p>'
		. '</td></tr>'
		. '<tr><td style="padding:18px 32px;background:#0a0c10;border-top:1px solid #1f232c;">'
		. '<p style="margin:0;color:#5a5f6c;font-family:Arial,sans-serif;font-size:11px;line-height:1.6;">'
		. 'Este correo es automático.<br>'
		. 'ResolveCore — Solución a tus problemas informáticos.</p>'
		. '</td></tr>'
		. '</table></td></tr></table></body></html>';

	$text  = "Bienvenido a ResolveCore\n\n";
	$text .= 'Hola ' . $nombre . ", tu cuenta de cliente ya esta activa.\n\n";
	$text .= 'Usuario: ' . $login . "\n";
	$text .= 'Panel: ' . home_url( '/dashboard/' ) . "\n\n";
	$text .= "Inicia sesion con tu email y la contrasena que elegiste.\n\n";
	$text .= "—\nEste correo es automatico.\nResolveCore — Solucion a tus problemas informaticos.\n";

	$headers = array(
		'Content-Type: text/html; charset=UTF-8',
		'Reply-To: ' . get_option( 'admin_email' ),
	);

	$alt_body = static function ( $phpmailer ) use ( $text ) {
		$phpmailer->AltBody = $text;
	};
	add_action( 'phpmailer_init', $alt_body );
	$sent = wp_mail( $email, 'ResolveCore — Tu cuenta está lista', $html, $headers );
	remove_action( 'phpmailer_init', $alt_body );

	if ( ! $sent ) {
		error_log( '[rc-core] email bienvenida: wp_mail devolvió false para ' . $email );
	}
	return (bool) $sent;
}

/**
 * A3 — Activación = verificación de email. Al fijar la contraseña vía el enlace
 * de reset (que solo llega al buzón real), la cuenta queda verificada: se borra
 * el marcador `rc_pending_activation` para que el cron no la purgue.
 *
 * @param WP_User $user Usuario que acaba de resetear/fijar su contraseña.
 */
function rc_cliente_on_password_reset( $user ) {
	if ( $user instanceof WP_User ) {
		delete_user_meta( $user->ID, 'rc_pending_activation' );
	}
}
add_action( 'after_password_reset', 'rc_cliente_on_password_reset' );

/**
 * A3 — Limpieza de cuentas nunca activadas. Las altas públicas que no se confirman
 * (nadie clicó el enlace de email) son ruido en wp_users y posible spam dirigido a
 * terceros. Se borran las cuentas rc_cliente con `rc_pending_activation` de más de
 * 7 días. Programado por wp-cron diario (registrado en la activación del plugin).
 */
function rc_cliente_purgar_pendientes() {
	$limite = time() - ( 7 * DAY_IN_SECONDS );
	$users  = get_users(
		array(
			'role'       => 'rc_cliente',
			'meta_key'   => 'rc_pending_activation',
			'meta_value' => $limite,
			'meta_type'  => 'NUMERIC',
			'meta_compare' => '<',
			'fields'     => 'ID',
		)
	);
	if ( empty( $users ) ) {
		return;
	}
	require_once ABSPATH . 'wp-admin/includes/user.php';
	foreach ( $users as $uid ) {
		wp_delete_user( (int) $uid );
	}
	error_log( '[rc-core] purga de cuentas no activadas: ' . count( $users ) . ' eliminadas.' );
}
add_action( 'rc_cliente_purga_evento', 'rc_cliente_purgar_pendientes' );

/**
 * Programa el evento de purga al activar el plugin. Idempotente.
 */
function rc_cliente_programar_purga() {
	if ( ! wp_next_scheduled( 'rc_cliente_purga_evento' ) ) {
		wp_schedule_event( time() + HOUR_IN_SECONDS, 'daily', 'rc_cliente_purga_evento' );
	}
}
register_activation_hook( __FILE__, 'rc_cliente_programar_purga' );

/**
 * Desprograma el evento al desactivar el plugin.
 */
function rc_cliente_desprogramar_purga() {
	$ts = wp_next_scheduled( 'rc_cliente_purga_evento' );
	if ( $ts ) {
		wp_unschedule_event( $ts, 'rc_cliente_purga_evento' );
	}
}
register_deactivation_hook( __FILE__, 'rc_cliente_desprogramar_purga' );
