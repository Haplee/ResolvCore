<?php
/**
 * Plantilla de error 404 (página no encontrada).
 *
 * Antes no existía 404.php: WordPress caía a index.php (vacío) y mostraba una
 * página en blanco. Esta plantilla da un mensaje claro y enlaces de salida
 * con el estilo del tema.
 */

get_header();
?>
<style>
.rc-404 { max-width: 680px; margin: 6rem auto; padding: 0 2rem; text-align: center; color: var(--rc-text); font-family: var(--rc-sans); }
.rc-404 .code { font-family: var(--rc-mono); font-size: clamp(5rem, 18vw, 9rem); font-weight: 700; line-height: 1; color: var(--rc-accent); letter-spacing: -2px; }
.rc-404 h1 { font-family: var(--rc-mono); font-size: 1.5rem; margin: 1rem 0 .75rem; }
.rc-404 p { color: var(--rc-muted); line-height: 1.7; margin: 0 auto 2rem; max-width: 460px; }
.rc-404 .rc-404-actions { display: flex; gap: 1rem; justify-content: center; flex-wrap: wrap; }
.rc-404 .rc-404-hint { margin-top: 3rem; font-size: 13px; color: var(--rc-muted); font-family: var(--rc-mono); }
.rc-404 .rc-404-hint a { color: var(--rc-accent); }
</style>

<main id="main-content" class="rc-404">
	<div class="code" aria-hidden="true">404</div>
	<h1>Página no encontrada</h1>
	<p>
		La dirección que has introducido no existe o se ha movido. Revisa la URL
		o vuelve al inicio para seguir navegando.
	</p>

	<div class="rc-404-actions">
		<a class="rc-btn rc-btn--accent" href="<?php echo esc_url( home_url( '/' ) ); ?>">Volver al inicio</a>
		<a class="rc-btn" href="<?php echo esc_url( home_url( '/contacto/' ) ); ?>">Contactar con soporte</a>
	</div>

	<p class="rc-404-hint">
		¿Buscabas el gestor de tickets? Entra en
		<a href="https://mantis.resolvecore.website">mantis.resolvecore.website</a>
	</p>
</main>

<?php
get_footer();
