<!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
  <meta charset="<?php bloginfo('charset'); ?>">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#0a0c10">
  <meta name="color-scheme" content="dark">
  <?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
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
    </ul>
    <a class="rc-header-cta" href="<?php echo esc_url( home_url( '/contacto/' ) ); ?>">
      Contacta con nosotros →
    </a>
  </nav>
</header>

<?php if ( ! is_page( 'contacto' ) ) : ?>
<a class="rc-fab-contact" href="<?php echo esc_url( home_url( '/contacto/' ) ); ?>" aria-label="Contacta con nosotros">
  <span class="rc-fab-icon" aria-hidden="true">✉</span>
  <span class="rc-fab-text">Contacta</span>
</a>
<?php endif; ?>
