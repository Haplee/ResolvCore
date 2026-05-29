<?php
/**
 * Plantilla genérica para páginas estáticas (page.php).
 *
 * Se usa como fallback cuando WordPress no encuentra una plantilla
 * más específica (page-{slug}.php, page-{id}.php). Renderiza el
 * contenido tal cual lo ha dejado el editor — sin sidebars ni
 * comentarios, que aquí no aplican.
 */

get_header();
?>

<main id="main-content" class="rc-page">
	<div class="rc-page-inner">
	<?php
	while ( have_posts() ) :
		the_post();
		?>
		<article <?php post_class( 'rc-page-article' ); ?>>
			<header class="rc-page-header">
				<h1 class="rc-page-title"><?php the_title(); ?></h1>
			</header>

			<div class="rc-page-content">
				<?php the_content(); ?>
			</div>
		</article>
	<?php endwhile; ?>
	</div>
</main>

<?php
get_footer();
