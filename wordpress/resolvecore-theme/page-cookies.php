<?php
/* Template Name: Política de cookies */
get_header();
$updated = '2026-05-20';
?>
<style>
.rc-legal { max-width: 820px; margin: 4rem auto; padding: 0 2rem; color: var(--rc-text); font-family: var(--rc-sans); }
.rc-legal h1 { font-family: var(--rc-mono); font-size: 2rem; font-weight: 700; margin-bottom: .5rem; }
.rc-legal .updated { font-family: var(--rc-mono); font-size: 12px; color: var(--rc-muted); margin-bottom: 2.5rem; letter-spacing: .04em; }
.rc-legal h2 { font-family: var(--rc-mono); font-size: 1.15rem; margin: 2rem 0 .75rem; color: var(--rc-accent); }
.rc-legal p, .rc-legal li { color: var(--rc-text); line-height: 1.75; margin-bottom: .75rem; }
.rc-legal ul { margin: 0 0 1rem 1.5rem; }
.rc-legal a { color: var(--rc-accent); }
.rc-legal table { width: 100%; border-collapse: collapse; margin: 1rem 0; font-size: 13px; }
.rc-legal th, .rc-legal td { border: 1px solid var(--rc-border); padding: 10px 12px; text-align: left; vertical-align: top; }
.rc-legal th { background: var(--rc-surface); font-family: var(--rc-mono); font-size: 11px; letter-spacing: .04em; color: var(--rc-accent); }
.rc-legal code { font-family: var(--rc-mono); font-size: 12px; background: var(--rc-surface2); padding: 2px 6px; border-radius: 3px; }
</style>

<article class="rc-legal">
  <h1>Política de cookies</h1>
  <div class="updated">Última actualización: <?php echo esc_html( $updated ); ?></div>

  <p>De acuerdo con el artículo 22.2 de la Ley 34/2002 (LSSI-CE), modificado por el RDL 13/2012, se informa al usuario sobre las cookies utilizadas en este sitio web.</p>

  <h2>1. ¿Qué es una cookie?</h2>
  <p>Una cookie es un pequeño fichero de texto que un sitio web almacena en el navegador del usuario para guardar información sobre la visita, mantener sesiones o analizar el uso del sitio.</p>

  <h2>2. Cookies utilizadas en resolvecore.website</h2>
  <p>Este sitio utiliza <strong>únicamente cookies técnicas estrictamente necesarias</strong> para el funcionamiento del sitio. No se utilizan cookies de seguimiento, publicidad, analítica de terceros ni redes sociales.</p>

  <table>
    <thead>
      <tr><th>Cookie</th><th>Propietario</th><th>Finalidad</th><th>Duración</th><th>Tipo</th></tr>
    </thead>
    <tbody>
      <tr>
        <td><code>wordpress_*</code></td>
        <td>WordPress (primera parte)</td>
        <td>Identificar sesión de usuarios autenticados (admin)</td>
        <td>Sesión / 14 días</td>
        <td>Técnica estrictamente necesaria</td>
      </tr>
      <tr>
        <td><code>wp-settings-*</code></td>
        <td>WordPress (primera parte)</td>
        <td>Personalizar la interfaz del panel de administración</td>
        <td>1 año</td>
        <td>Técnica estrictamente necesaria</td>
      </tr>
      <tr>
        <td><code>PHPSESSID</code></td>
        <td>PHP (primera parte)</td>
        <td>Mantener la sesión del lado servidor</td>
        <td>Sesión</td>
        <td>Técnica estrictamente necesaria</td>
      </tr>
    </tbody>
  </table>

  <p>Estas cookies <strong>no requieren consentimiento previo</strong> (art. 22.2 LSSI), ya que son imprescindibles para prestar el servicio solicitado por el usuario.</p>

  <h2>3. Cookies de terceros</h2>
  <p>El sitio puede cargar tipografías web de Google Fonts (<code>fonts.googleapis.com</code> y <code>fonts.gstatic.com</code>). Google puede registrar la IP del usuario para servir la fuente. Si deseas evitar esta carga, puedes:</p>
  <ul>
    <li>Configurar tu navegador para bloquear conexiones a dominios de Google.</li>
    <li>Utilizar extensiones como uBlock Origin o NoScript.</li>
  </ul>

  <h2>4. Gestión de cookies en el navegador</h2>
  <p>El usuario puede en cualquier momento configurar, restringir o eliminar las cookies desde los ajustes de su navegador:</p>
  <ul>
    <li><a href="https://support.google.com/chrome/answer/95647" target="_blank" rel="noopener noreferrer">Google Chrome</a></li>
    <li><a href="https://support.mozilla.org/es/kb/habilitar-y-deshabilitar-cookies-sitios-web-rastrear-preferencias" target="_blank" rel="noopener noreferrer">Mozilla Firefox</a></li>
    <li><a href="https://support.microsoft.com/es-es/microsoft-edge/eliminar-las-cookies-en-microsoft-edge" target="_blank" rel="noopener noreferrer">Microsoft Edge</a></li>
    <li><a href="https://support.apple.com/es-es/guide/safari/sfri11471/mac" target="_blank" rel="noopener noreferrer">Apple Safari</a></li>
  </ul>
  <p>La desactivación de las cookies técnicas puede impedir el funcionamiento correcto de algunas partes del sitio (panel de administración WP).</p>

  <h2>5. Actualizaciones</h2>
  <p>Esta política puede actualizarse cuando varíe el uso de cookies del sitio. La fecha de la última revisión aparece en la cabecera.</p>

  <p style="margin-top:2rem;font-size:13px;color:var(--rc-muted)">Plantilla informativa orientada a un sitio sin cookies de análisis ni publicidad de terceros. Si en el futuro se añade Google Analytics, Matomo o similar, esta política deberá actualizarse y se requerirá un banner de consentimiento previo.</p>
</article>

<?php get_footer(); ?>
