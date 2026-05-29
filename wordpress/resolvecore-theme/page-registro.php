<?php
/**
 * Template Name: Registro cliente
 *
 * Misma idea que page-dashboard.php: pintamos a mano el hero corporativo y
 * dejamos que el contenido de la página sea el shortcode
 * [rc_registro_cliente], que pinta el formulario de alta y procesa el POST.
 */

get_header();
?>

<main id="main-content" class="rc-dash-page">

	<section class="rc-dash-hero">
		<div class="rc-dash-hero-inner">
			<p class="rc-section-label">// CREAR CUENTA</p>
			<h1 class="rc-dash-hero-title">Crea tu cuenta de cliente</h1>
			<p class="rc-dash-hero-sub">
				Regístrate para acceder a tu dashboard y seguir el estado de tus informes técnicos.
			</p>
		</div>
	</section>

	<section class="rc-dash-body">
		<div class="rc-dash-wrap">
		<?php while ( have_posts() ) : the_post(); ?>
			<?php the_content(); ?>
		<?php endwhile; ?>
		</div>
	</section>

</main>

<?php
get_footer();
