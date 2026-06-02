<?php
/**
 * Template Name: Dashboard cliente
 *
 * Pintamos la cabecera del dashboard a mano (hero corporativo) y
 * dejamos que el contenido de la página sea el shortcode
 * [rc_cliente_dashboard], que es el que realmente lista los tickets
 * y pinta el formulario de solicitud.
 */

get_header();

$current_user = is_user_logged_in() ? wp_get_current_user() : null;
?>

<main id="main-content" class="rc-dash-page">

	<section class="rc-dash-hero">
		<div class="rc-dash-hero-inner">
			<p class="rc-section-label">// MI CUENTA</p>
			<h1 class="rc-dash-hero-title">
				<?php if ( $current_user ) : ?>
					Hola, <?php echo esc_html( $current_user->display_name ); ?>
				<?php else : ?>
					Centro del cliente
				<?php endif; ?>
			</h1>
			<p class="rc-dash-hero-sub">
				Solicita un informe técnico y consulta el estado de tus tickets en un solo sitio.
			</p>
			<?php if ( $current_user ) : ?>
				<div class="rc-dash-hero-meta">
					<span class="rc-dash-hero-chip">
						<span class="rc-dash-hero-dot" aria-hidden="true"></span>
						<?php echo esc_html( $current_user->user_email ); ?>
					</span>
					<a class="rc-dash-hero-logout" href="<?php echo esc_url( wp_logout_url( home_url( '/' ) ) ); ?>">
						<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true" style="vertical-align:-2px;margin-right:.35rem">
							<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/>
						</svg>Cerrar sesión
					</a>
				</div>
			<?php endif; ?>
		</div>
	</section>

	<section class="rc-dash-body">
		<div class="rc-dash-wrap">
		<?php
		while ( have_posts() ) :
			the_post();
			the_content();
		endwhile;
		?>

		<?php if ( $current_user ) : ?>
			<div class="rc-dash-foot-logout">
				<a class="rc-btn rc-btn--logout" href="<?php echo esc_url( wp_logout_url( home_url( '/' ) ) ); ?>">
					<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true" style="vertical-align:-3px;margin-right:.4rem">
						<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/>
					</svg>Cerrar sesión
				</a>
			</div>
		<?php endif; ?>
		</div>
	</section>

</main>

<?php
get_footer();
