<!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
  <meta charset="<?php bloginfo('charset'); ?>">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<header class="rc-header">
  <nav class="rc-nav">
    <a class="rc-nav__logo" href="<?php echo esc_url(home_url('/')); ?>">
      Resolve<span>Core</span>
    </a>
    <?php
    wp_nav_menu([
      'theme_location' => 'primary',
      'menu_class'     => 'rc-nav__links',
      'container'      => false,
      'fallback_cb'    => false,
    ]);
    ?>
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
