<!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
	<meta charset="<?php bloginfo( 'charset' ); ?>">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<meta name="theme-color" content="#0a0c10">
	<meta name="color-scheme" content="dark">
	<?php $rc_meta_desc = function_exists( 'resolvecore_meta_description' ) ? resolvecore_meta_description() : ''; ?>
	<?php if ( '' !== $rc_meta_desc ) : ?>
	<meta name="description" content="<?php echo esc_attr( $rc_meta_desc ); ?>">
	<?php endif; ?>
	<?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<?php
// Rol del usuario para adaptar el nav (técnico vs cliente vs público).
$rc_is_tech    = is_user_logged_in() && ( current_user_can( 'editor' ) || current_user_can( 'administrator' ) );
$rc_user_roles = is_user_logged_in() ? (array) wp_get_current_user()->roles : array();
$rc_is_cliente = ! $rc_is_tech && in_array( 'rc_cliente', $rc_user_roles, true );
?>
<a class="rc-skip-link" href="#main-content">Saltar al contenido principal</a>
<header class="rc-header">
	<nav class="rc-nav" aria-label="Navegación principal">
	<a class="rc-nav__logo" href="<?php echo esc_url( home_url( '/' ) ); ?>">
		Resolve<span>Core</span>
	</a>
	<ul class="rc-nav__links">
		<li><a href="<?php echo esc_url( home_url( '/#servicios' ) ); ?>">Servicios</a></li>
		<li><a href="<?php echo esc_url( home_url( '/#como-funciona' ) ); ?>">Proceso</a></li>
		<li><a href="<?php echo esc_url( home_url( '/#precios' ) ); ?>">Precios</a></li>
		<li><a href="<?php echo esc_url( home_url( '/#faq' ) ); ?>">FAQ</a></li>
		<?php // Recursos internos (Docs/Changelog/Flota): ocultos al cliente. ?>
		<?php if ( ! $rc_is_cliente ) : ?>
		<li class="rc-nav__dd">
		<button type="button" class="rc-nav__dd-btn" id="rc-hdr-dd-btn"
				aria-expanded="false" aria-haspopup="true" aria-controls="rc-hdr-dd">
			Recursos <span class="rc-nav__dd-caret" aria-hidden="true">▾</span>
		</button>
		<ul class="rc-nav__dd-menu" id="rc-hdr-dd" aria-labelledby="rc-hdr-dd-btn">
			<li><a href="<?php echo esc_url( home_url( '/docs/' ) ); ?>">Documentación</a></li>
			<li><a href="<?php echo esc_url( home_url( '/changelog/' ) ); ?>">Changelog</a></li>
			<li><a href="<?php echo esc_url( home_url( '/fleet-status/' ) ); ?>">Estado de la flota</a></li>
		</ul>
		</li>
		<?php endif; // cierra if !$rc_is_cliente (dropdown Recursos) ?>
		<?php if ( $rc_is_tech ) : ?>
		<li><a href="<?php echo esc_url( home_url( '/tecnicos/' ) ); ?>">Area de tecnicos</a></li>
		<?php endif; ?>
	</ul>
	<?php if ( $rc_is_tech ) : ?>
	<a class="rc-header-cta" href="<?php echo esc_url( home_url( '/tecnicos/' ) ); ?>">Panel tecnico</a>
	<?php elseif ( $rc_is_cliente ) : ?>
	<a class="rc-header-cta" href="<?php echo esc_url( home_url( '/dashboard/' ) ); ?>">Mi panel</a>
	<?php else : ?>
	<a class="rc-header-cta" href="<?php echo esc_url( home_url( '/contacto/' ) ); ?>">
		Contacta con nosotros →
	</a>
	<?php endif; // cierra el bloque de CTA por rol ?>
	</nav>
</header>

<?php if ( ! is_page( 'contacto' ) ) : ?>
<a class="rc-fab-contact" href="<?php echo esc_url( home_url( '/contacto/' ) ); ?>" aria-label="Contacta con nosotros">
	<span class="rc-fab-icon" aria-hidden="true">✉</span>
	<span class="rc-fab-text">Contacta</span>
</a>
<?php endif; ?>
