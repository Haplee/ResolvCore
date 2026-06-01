<?php
/**
 * Template Name: Registro cliente
 *
 * Pantalla de autenticación enfocada: fondo a pantalla completa, marca arriba,
 * título compacto y la tarjeta de auth ([rc_registro_cliente]) centrada.
 * El shortcode pinta las pestañas Crear cuenta / Iniciar sesión y procesa el POST.
 */

get_header();
?>

<main id="main-content" class="rc-auth-page">
	<div class="rc-auth-shell">

		<a class="rc-auth-brand" href="<?php echo esc_url( home_url( '/' ) ); ?>" aria-label="ResolveCore — inicio">
			<picture>
				<source srcset="<?php echo esc_url( get_template_directory_uri() . '/assets/logo/resolvcore-logo-dark.svg' ); ?>" type="image/svg+xml">
				<img src="<?php echo esc_url( get_template_directory_uri() . '/assets/logo/resolvcore-logo-dark.png' ); ?>"
					alt="ResolveCore" width="180" height="45" decoding="async">
			</picture>
		</a>

		<p class="rc-auth-kicker">// ÁREA DE CLIENTES</p>
		<h1 class="rc-auth-title">Accede a tu cuenta</h1>
		<p class="rc-auth-lead">
			Crea tu cuenta o inicia sesión para abrir tickets de soporte y seguir
			el estado de tus informes técnicos.
		</p>

		<div class="rc-auth-card-host">
		<?php
		while ( have_posts() ) :
			the_post();
			the_content();
		endwhile;
		?>
		</div>

		<p class="rc-auth-back"><a href="<?php echo esc_url( home_url( '/' ) ); ?>">&larr; Volver al inicio</a></p>

	</div>
</main>

<style>
/* Pantalla de auth enfocada (rediseño 01-06-2026) */
.rc-auth-page {
	min-height: calc(100vh - 64px);
	display: flex; align-items: flex-start; justify-content: center;
	padding: clamp(2.5rem, 7vh, 5.5rem) 1.25rem 4rem;
	background: var(--rc-grad-hero, linear-gradient(180deg, var(--rc-surface) 0%, var(--rc-bg) 100%));
}
.rc-auth-shell { width: 100%; max-width: 440px; text-align: center; }
.rc-auth-brand { display: inline-flex; margin-bottom: 2.25rem; }
.rc-auth-brand img { height: 42px; width: auto; object-fit: contain; }
.rc-auth-kicker {
	font-family: var(--rc-mono); font-size: 11px; letter-spacing: .14em;
	text-transform: uppercase; color: var(--rc-accent); margin-bottom: .5rem;
}
.rc-auth-title {
	font-family: var(--rc-mono); font-size: clamp(1.6rem, 4vw, 2.1rem);
	font-weight: 700; line-height: 1.15; margin-bottom: .6rem;
}
.rc-auth-lead {
	color: var(--rc-muted); font-size: .95rem; line-height: 1.6;
	max-width: 380px; margin: 0 auto 2rem;
}
/* La tarjeta del shortcode ya viene estilada; aquí solo la encajamos sin su margen propio. */
.rc-auth-card-host { text-align: left; }
.rc-auth-card-host .rc-auth,
.rc-auth-card-host .rc-registro { margin: 0 auto; max-width: 100%; }
.rc-auth-back { margin-top: 1.75rem; font-size: .85rem; }
.rc-auth-back a { color: var(--rc-muted); text-decoration: none; transition: color .2s; }
.rc-auth-back a:hover { color: var(--rc-accent); }
@media (max-width: 460px) {
	.rc-auth-page { padding-top: 2rem; }
	.rc-auth-brand img { height: 36px; }
}
</style>

<?php
get_footer();
