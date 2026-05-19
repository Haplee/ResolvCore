<footer class="rc-footer">
  <div class="rc-footer-inner">
    <span>© 2026 ResolveCore · Francisco Vidal Mateo</span>
    <?php
    wp_nav_menu([
      'theme_location' => 'footer',
      'menu_class'     => 'rc-footer-links',
      'container'      => false,
      'fallback_cb'    => false,
    ]);
    ?>
  </div>
</footer>
<?php wp_footer(); ?>
</body>
</html>
