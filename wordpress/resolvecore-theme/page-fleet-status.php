<?php
/* Template Name: ResolveCore Fleet Status */
get_header();
?>

<main class="rc-fleet-page" id="main-content">
  <header class="rc-fleet-hero">
    <span class="rc-fleet-tag">// PANEL PÚBLICO</span>
    <h1 class="rc-fleet-h1">Estado de la flota</h1>
    <p class="rc-fleet-intro">
      Resumen agregado de los equipos monitorizados por ResolveCore.
      Solo métricas de salud — sin nombres de equipo, correos ni datos de diagnóstico.
    </p>
  </header>

  <section class="rc-fleet-block" aria-label="Panel de la flota">
    <?php
    if ( function_exists( 'rc_fleet_render_stats' ) ) {
        echo rc_fleet_render_stats(); // HTML de confianza generado por el plugin rc-fleet
    } else {
        echo '<div class="rc-fleet-panel"><div class="rc-fleet-empty">'
           . 'El módulo <strong>Fleet</strong> no está activo. Actívalo en Plugins para ver el panel.'
           . '</div></div>';
    }
    ?>
  </section>

  <section class="rc-fleet-block">
    <h2 class="rc-fleet-sec-h">// Cómo se monitoriza</h2>
    <ol class="rc-fleet-steps">
      <li class="rc-fleet-step">
        <span class="rc-fleet-step-n">01</span>
        <h3 class="rc-fleet-step-h">Diagnóstico local</h3>
        <p class="rc-fleet-step-p">
          El agente se ejecuta en el equipo del cliente (PowerShell en Windows,
          Bash en Linux/macOS, ADB en Android) y genera un JSON de salud.
        </p>
      </li>
      <li class="rc-fleet-step">
        <span class="rc-fleet-step-n">02</span>
        <h3 class="rc-fleet-step-h">Publicación segura</h3>
        <p class="rc-fleet-step-p">
          El JSON se envía vía <code>POST /wp-json/rc/v1/fleet</code> autenticado
          con token <code>Bearer</code>. Nada se publica sin credencial.
        </p>
      </li>
      <li class="rc-fleet-step">
        <span class="rc-fleet-step-n">03</span>
        <h3 class="rc-fleet-step-h">Score agregado</h3>
        <p class="rc-fleet-step-p">
          ResolveCore calcula un <em>score</em> 0-100 (disco, RAM, firewall,
          antivirus, CVEs) y solo expone aquí el agregado de toda la flota.
        </p>
      </li>
    </ol>
  </section>

  <section class="rc-fleet-block">
    <h2 class="rc-fleet-sec-h">// Agentes soportados</h2>
    <div class="rc-fleet-plats">
      <div class="rc-fleet-plat"><span class="rc-fleet-plat-i" aria-hidden="true">&#9636;</span> Windows 10/11</div>
      <div class="rc-fleet-plat"><span class="rc-fleet-plat-i" aria-hidden="true">&#9776;</span> Linux (Debian/Ubuntu)</div>
      <div class="rc-fleet-plat"><span class="rc-fleet-plat-i" aria-hidden="true">&#8997;</span> macOS</div>
      <div class="rc-fleet-plat"><span class="rc-fleet-plat-i" aria-hidden="true">&#9672;</span> Android (ADB)</div>
    </div>
  </section>

  <aside class="rc-fleet-privacy">
    <span class="rc-fleet-privacy-i" aria-hidden="true">&#128274;</span>
    <p>
      <strong>Privacidad.</strong> Este panel solo muestra recuentos, medias y
      distribución por sistema operativo. No expone correos, nombres de equipo,
      direcciones IP ni el JSON de diagnóstico. El detalle por equipo es accesible
      únicamente para el técnico desde <code>wp-admin</code>.
    </p>
  </aside>
</main>

<?php get_footer(); ?>
