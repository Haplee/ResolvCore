<footer class="rc-footer">
  <div class="rc-footer-inner">
    <span>© 2026 ResolveCore · Francisco Vidal Mateo</span>
    <?php
    wp_nav_menu([
      'theme_location' => 'footer',
      'menu_class'     => 'rc-footer-links',
      'container'      => false,
      'fallback_cb'    => 'resolvecore_footer_menu_fallback',
    ]);
    ?>
  </div>
</footer>
<script>
(function () {
  document.querySelectorAll('.rc-nav__dd').forEach(function (dd) {
    var btn  = dd.querySelector('.rc-nav__dd-btn');
    var menu = dd.querySelector('.rc-nav__dd-menu');
    if (!btn || !menu) return;
    function close() { menu.classList.remove('open'); btn.setAttribute('aria-expanded', 'false'); }
    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      var open = menu.classList.toggle('open');
      btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    document.addEventListener('click', function (e) { if (!dd.contains(e.target)) close(); });
    dd.addEventListener('keydown', function (e) { if (e.key === 'Escape') { close(); btn.focus(); } });
  });
})();
</script>
<?php wp_footer(); ?>
</body>
</html>
