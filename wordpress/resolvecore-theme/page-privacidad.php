<?php
/* Template Name: Política de privacidad */
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
</style>

<article class="rc-legal">
  <h1>Política de privacidad</h1>
  <div class="updated">Última actualización: <?php echo esc_html( $updated ); ?></div>

  <p>De conformidad con el Reglamento (UE) 2016/679 (RGPD) y la Ley Orgánica 3/2018 de Protección de Datos Personales y Garantía de los Derechos Digitales (LOPDGDD), se informa al usuario sobre el tratamiento de sus datos personales en este sitio.</p>

  <h2>1. Responsable del tratamiento</h2>
  <p><strong>Francisco Vidal Mateo</strong> — TFG ASIR<br>
  Contacto: <a href="mailto:fvidalmateo@gmail.com">fvidalmateo@gmail.com</a></p>
  <p>Al ser un proyecto académico no profesional, no se ha designado Delegado de Protección de Datos (DPO); las consultas pueden dirigirse al email anterior.</p>

  <h2>2. Datos recogidos, finalidad y base legal</h2>
  <table>
    <thead>
      <tr><th>Dato</th><th>Origen</th><th>Finalidad</th><th>Base legal</th><th>Conservación</th></tr>
    </thead>
    <tbody>
      <tr>
        <td>Nombre, email, tipo de consulta, mensaje</td>
        <td>Formulario de contacto</td>
        <td>Responder a la solicitud y crear un ticket en MantisBT para trazabilidad técnica</td>
        <td>Consentimiento del interesado (art. 6.1.a RGPD) y ejecución de medidas precontractuales (art. 6.1.b)</td>
        <td>Hasta 12 meses desde la última interacción, salvo obligación legal de conservación</td>
      </tr>
      <tr>
        <td>Dirección IP (hash), user-agent</td>
        <td>Logs nginx + transient anti-spam</td>
        <td>Prevención de spam y abusos (rate-limit 3 envíos/hora)</td>
        <td>Interés legítimo del responsable (art. 6.1.f) — seguridad del sistema</td>
        <td>30 días</td>
      </tr>
      <tr>
        <td>Cookies técnicas de sesión</td>
        <td>WordPress / navegación</td>
        <td>Mantener la sesión, mostrar correctamente el sitio</td>
        <td>Exceptuadas del consentimiento (art. 22.2 LSSI), estrictamente necesarias</td>
        <td>Duración de la sesión</td>
      </tr>
    </tbody>
  </table>

  <h2>3. Destinatarios — cesiones de datos</h2>
  <p>Los datos del formulario se almacenan en:</p>
  <ul>
    <li>Servidor VPS propio del titular (Ionos, datacenter Madrid) — base de datos MariaDB local.</li>
    <li>Instancia local de MantisBT (mantis.resolvecore.website) — gestor de tickets en el mismo servidor.</li>
  </ul>
  <p>No se realizan transferencias internacionales fuera del Espacio Económico Europeo. No se comparten datos con terceros, salvo obligación legal.</p>

  <h2>4. Derechos del interesado</h2>
  <p>El usuario puede ejercer en cualquier momento los siguientes derechos:</p>
  <ul>
    <li><strong>Acceso</strong> — saber qué datos suyos se conservan.</li>
    <li><strong>Rectificación</strong> — corregir datos inexactos.</li>
    <li><strong>Supresión</strong> («derecho al olvido») — eliminar sus datos.</li>
    <li><strong>Oposición</strong> — oponerse al tratamiento.</li>
    <li><strong>Limitación</strong> — restringir el tratamiento.</li>
    <li><strong>Portabilidad</strong> — recibir los datos en formato estructurado.</li>
    <li><strong>Revocar el consentimiento</strong> prestado.</li>
  </ul>
  <p>Para ejercer estos derechos, envía un email a <a href="mailto:fvidalmateo@gmail.com">fvidalmateo@gmail.com</a> indicando el derecho que deseas ejercer y adjuntando, en su caso, documento que acredite tu identidad.</p>

  <h2>5. Reclamación ante la autoridad de control</h2>
  <p>Si consideras que tus derechos no han sido atendidos correctamente, tienes derecho a presentar una reclamación ante la Agencia Española de Protección de Datos (AEPD): <a href="https://www.aepd.es" target="_blank" rel="noopener noreferrer">www.aepd.es</a>.</p>

  <h2>6. Medidas de seguridad</h2>
  <ul>
    <li>HTTPS forzado en todo el sitio (Let's Encrypt, TLS 1.2/1.3).</li>
    <li>Hashing de IP (SHA-256 + salt) en el sistema anti-spam.</li>
    <li>Firewall (ufw), fail2ban, restricción de acceso root SSH.</li>
    <li>Backups periódicos de la base de datos.</li>
    <li>Software open-source auditable (GPL-3.0).</li>
  </ul>

  <p style="margin-top:2rem;font-size:13px;color:var(--rc-muted)">Documento generado como plantilla de cumplimiento RGPD/LOPDGDD para proyecto académico. Para uso comercial, valida con un asesor jurídico.</p>
</article>

<?php get_footer(); ?>
