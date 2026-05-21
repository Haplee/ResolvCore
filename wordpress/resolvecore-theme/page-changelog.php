<?php
/* Template Name: ResolveCore Changelog */
get_header();
?>


<div class="rc-cl-layout">
  <aside class="rc-cl-sidebar">
    <div class="rc-cl-logo">
      <img src="<?php echo get_template_directory_uri(); ?>/assets/logo/resolvcore-logo-dark.png"
           alt="ResolveCore" class="rc-cl-logo-img" width="160" height="40">
    </div>
    <ul class="rc-cl-nav">
      <li><a href="#v1.2.0">v1.2.0</a></li>
      <li><a href="#v1.1.0">v1.1.0</a></li>
      <li><a href="#v1.0.0">v1.0.0</a></li>
      <li><a href="#v0.9.0">v0.9.0 beta</a></li>
    </ul>
  </aside>

  <main class="rc-cl-main" id="main-content">
    <header class="rc-cl-header">
      <h1 class="rc-cl-title">Changelog</h1>
      <p class="rc-cl-subtitle">Historial de versiones de ResolveCore</p>
    </header>

    <div class="rc-timeline">
      <div class="rc-timeline-item" id="v1.2.0">
        <div class="rc-timeline-version">v1.2.0</div>
        <div class="rc-timeline-date">21 de mayo de 2026</div>
        <span class="rc-timeline-badge rc-badge-feature">DESPLIEGUE</span>
        <ul class="rc-timeline-changes">
          <li>Script de despliegue VPS idempotente (<code>deploy-ionos.sh</code>): stack nginx + PHP-FPM 8.3 + MariaDB, WordPress y MantisBT con HTTPS Let's Encrypt y hardening (ufw, fail2ban, SSH)</li>
          <li>Subida de código al VPS automatizada desde Windows (<code>upload-to-vps.ps1</code>)</li>
          <li>Generador de informe técnico PDF (<code>generate-report.php</code>) — HTML → PDF vía wkhtmltopdf, con adjunto automático al ticket MantisBT</li>
          <li>Nuevo plugin <strong>Fleet Panel</strong>: los agentes publican su diagnóstico vía REST y se centralizan en un panel multiplataforma</li>
          <li>Página pública «Estado de la flota» con métricas agregadas (sin datos personales)</li>
          <li>Endpoint REST público <code>rc/v1/fleet/stats</code> de estadísticas agregadas</li>
          <li>Navegación con menú desplegable «Recursos» (Documentación, Changelog, Estado de la flota)</li>
        </ul>
      </div>

      <div class="rc-timeline-item" id="v1.1.0">
        <div class="rc-timeline-version">v1.1.0</div>
        <div class="rc-timeline-date">20 de mayo de 2026</div>
        <span class="rc-timeline-badge rc-badge-feature">WEB Y SEGURIDAD</span>
        <ul class="rc-timeline-changes">
          <li>Sprint web: páginas legales del sitio (aviso legal, privacidad, cookies) y página de contacto</li>
          <li>Plugin <code>rc-mantisbt</code>: integración del formulario de contacto con MantisBT vía REST API — cada solicitud crea un ticket automáticamente</li>
          <li>Diagnóstico Windows v4.0.0: datos de hardware unificados bajo la clave <code>hardware{}</code> del esquema JSON</li>
          <li>Módulo de reconocimiento de red en Python (Nmap + Shodan) con arquitectura Hexagonal</li>
          <li>Mejoras de accesibilidad y SEO: landmarks ARIA, skip-link, <code>:focus-visible</code>, <code>prefers-reduced-motion</code>, Schema.org JSON-LD</li>
          <li>Cabeceras de seguridad HTTP: X-Content-Type-Options, Referrer-Policy, Permissions-Policy, X-Frame-Options</li>
          <li>Corrección de seguridad: inyección JSON en el informe, modo <code>--dry-run</code> y reglas udev</li>
        </ul>
      </div>

      <div class="rc-timeline-item" id="v1.0.0">
        <div class="rc-timeline-version">v1.0.0</div>
        <div class="rc-timeline-date">28 de abril de 2026</div>
        <span class="rc-timeline-badge rc-badge-release">RELEASE</span>
        <ul class="rc-timeline-changes">
          <li>Lanzamiento inicial de ResolveCore</li>
          <li>Scripts PowerShell de diagnóstico y optimización para Windows 10/11</li>
          <li>Scripts Bash de diagnóstico y optimización para Linux (Ubuntu, Debian, Arch)</li>
          <li>Scripts de diagnóstico para Android vía ADB</li>
          <li>Análisis de vulnerabilidades contra base de datos CVE local</li>
          <li>Proyección de vida útil del hardware mediante datos S.M.A.R.T.</li>
          <li>Salida estructurada en JSON para generación de informes</li>
          <li>Tema WordPress ResolveCore — landing page, docs y changelog</li>
          <li>Formulario de contacto AJAX con protección honeypot y rate limiting</li>
        </ul>
      </div>

      <div class="rc-timeline-item" id="v0.9.0">
        <div class="rc-timeline-version">v0.9.0</div>
        <div class="rc-timeline-date">Enero — Abril 2026</div>
        <span class="rc-timeline-badge rc-badge-fix">BETA</span>
        <ul class="rc-timeline-changes">
          <li>Arquitectura del sistema — flujo de 7 fases (solicitud → ticket → diagnóstico → PDF → facturación)</li>
          <li>Prototipo de scripts PowerShell para recopilación de métricas Windows</li>
          <li>Prototipo de scripts Bash para sistemas Linux</li>
          <li>Diseño del sistema de diseño (design system): variables CSS, tipografía, dark theme</li>
          <li>Wireframes y maquetación inicial del tema WordPress</li>
          <li>Esquema JSON de salida de diagnóstico definido</li>
          <li>Investigación CVE API (NVD/NIST) para base de datos de vulnerabilidades</li>
        </ul>
      </div>
    </div>
  </main>
</div>

<?php get_footer(); ?>
