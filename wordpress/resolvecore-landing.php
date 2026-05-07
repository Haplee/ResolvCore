<?php
/**
 * Plugin Name: ResolveCore Landing Shortcode
 * Plugin URI:  https://github.com/Haplee
 * Description: Shortcode [resolvecore_landing] para incrustar la landing page de ResolveCore en cualquier página o entrada de WordPress.
 * Version:     1.0.0
 * Author:      Francisco Vidal Mateo
 * Author URI:  https://github.com/Haplee
 * License:     GPL-2.0+
 *
 * ============================================================
 * INSTALACIÓN
 * ============================================================
 * 1. Sube esta carpeta a: wp-content/plugins/resolvecore-landing/
 * 2. Activa el plugin en WordPress > Plugins > "ResolveCore Landing Shortcode"
 * 3. En cualquier página o entrada usa el shortcode: [resolvecore_landing]
 *
 * PARÁMETROS OPCIONALES DEL SHORTCODE:
 *   show_nav="true|false"     → Mostrar/ocultar barra de navegación (default: true)
 *   show_pricing="true|false" → Mostrar/ocultar sección de precios (default: true)
 *   show_footer="true|false"  → Mostrar/ocultar footer (default: true)
 *
 * EJEMPLO:
 *   [resolvecore_landing show_nav="false" show_pricing="false"]
 * ============================================================
 */

if ( ! defined( 'ABSPATH' ) ) exit; // Seguridad: evitar acceso directo

/* ============================================================
   1. REGISTRAR ESTILOS Y SCRIPTS
   ============================================================ */
function resolvecore_enqueue_assets() {
    // Google Fonts (solo se carga si el shortcode está en la página actual)
    $post = get_post();
    if ( $post && has_shortcode( (string) $post->post_content, 'resolvecore_landing' ) ) {
        wp_enqueue_style(
            'resolvecore-fonts',
            'https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=DM+Sans:wght@300;400;500;600&display=swap',
            [],
            null
        );
    }
}
add_action( 'wp_enqueue_scripts', 'resolvecore_enqueue_assets' );

/* Preconnect a Google Fonts solo si shortcode presente — mejora LCP */
function resolvecore_landing_resource_hints( $urls, $relation ) {
    if ( $relation !== 'preconnect' ) return $urls;
    $post = get_post();
    if ( $post && has_shortcode( (string) $post->post_content, 'resolvecore_landing' ) ) {
        $urls[] = [ 'href' => 'https://fonts.googleapis.com', 'crossorigin' ];
        $urls[] = [ 'href' => 'https://fonts.gstatic.com',    'crossorigin' ];
    }
    return $urls;
}
add_filter( 'wp_resource_hints', 'resolvecore_landing_resource_hints', 10, 2 );

/* ============================================================
   2. CSS INLINE — se inyecta una sola vez en el <head>
   ============================================================ */
function resolvecore_inject_styles() {
    global $post;
    if ( ! is_a( $post, 'WP_Post' ) ) return;
    if ( ! has_shortcode( $post->post_content, 'resolvecore_landing' ) ) return;
    ?>
    <style id="resolvecore-styles">
      /* Prefijamos todo con .rc-wrap para no interferir con el tema */
      .rc-wrap *, .rc-wrap *::before, .rc-wrap *::after { box-sizing: border-box; margin: 0; padding: 0; }
      .rc-wrap {
        --rc-bg:      #0a0c10;
        --rc-surface: #111318;
        --rc-surface2:#1a1d24;
        --rc-border:  rgba(255,255,255,0.07);
        --rc-border2: rgba(255,255,255,0.13);
        --rc-accent:  #00e5a0;
        --rc-accent2: #0099ff;
        --rc-warn:    #ff6b35;
        --rc-text:    #e8eaf0;
        --rc-muted:   #7a7f8e;
        --rc-mono:    'Space Mono', monospace;
        --rc-sans:    'DM Sans', sans-serif;
        background: var(--rc-bg);
        color: var(--rc-text);
        font-family: var(--rc-sans);
        font-size: 16px;
        line-height: 1.6;
        overflow-x: hidden;
        width: 100%;
      }
      /* NAV */
      .rc-wrap .rc-nav {
        background: rgba(10,12,16,0.95);
        border-bottom: 1px solid var(--rc-border);
        padding: 0 2rem; height: 60px;
        display: flex; align-items: center; justify-content: space-between;
        position: sticky; top: 0; z-index: 100;
      }
      .rc-wrap .rc-nav-logo {
        font-family: var(--rc-mono); font-size: 15px; font-weight: 700;
        color: var(--rc-accent); letter-spacing: .1em; text-decoration: none;
      }
      .rc-wrap .rc-nav-logo span { color: var(--rc-muted); }
      .rc-wrap .rc-nav ul { display: flex; gap: 2rem; list-style: none; }
      .rc-wrap .rc-nav ul a {
        font-size: 13px; color: var(--rc-muted); text-decoration: none;
        font-weight: 500; transition: color .2s;
      }
      .rc-wrap .rc-nav ul a:hover { color: var(--rc-text); }
      .rc-wrap .rc-nav-cta {
        font-family: var(--rc-mono); font-size: 12px;
        color: var(--rc-accent); border: 1px solid var(--rc-accent);
        padding: 7px 16px; text-decoration: none; transition: all .2s;
      }
      .rc-wrap .rc-nav-cta:hover { background: var(--rc-accent); color: #000; }
      /* HERO */
      .rc-wrap .rc-hero {
        position: relative; min-height: 85vh;
        display: flex; align-items: center;
        padding: 0 2rem; overflow: hidden;
      }
      .rc-wrap .rc-hero-grid {
        position: absolute; inset: 0;
        background-image:
          linear-gradient(rgba(0,229,160,.03) 1px, transparent 1px),
          linear-gradient(90deg, rgba(0,229,160,.03) 1px, transparent 1px);
        background-size: 60px 60px;
        animation: rcGrid 30s linear infinite;
      }
      @keyframes rcGrid { to { transform: translateY(60px); } }
      .rc-wrap .rc-hero-glow {
        position: absolute; width: 600px; height: 600px; border-radius: 50%;
        background: radial-gradient(circle, rgba(0,229,160,.06) 0%, transparent 70%);
        top: -100px; right: -100px; pointer-events: none;
      }
      .rc-wrap .rc-hero-content { position: relative; max-width: 700px; z-index: 2; }
      .rc-wrap .rc-badge {
        display: inline-flex; align-items: center; gap: 8px;
        font-family: var(--rc-mono); font-size: 11px; color: var(--rc-accent);
        border: 1px solid rgba(0,229,160,.25); padding: 5px 12px;
        letter-spacing: .08em; margin-bottom: 2rem; background: rgba(0,229,160,.05);
      }
      .rc-wrap .rc-badge::before {
        content: ''; width: 6px; height: 6px; border-radius: 50%;
        background: var(--rc-accent); animation: rcPulse 2s infinite;
      }
      @keyframes rcPulse { 50% { opacity: .3; } }
      .rc-wrap .rc-hero h1 {
        font-family: var(--rc-mono);
        font-size: clamp(2.2rem, 5vw, 3.8rem);
        font-weight: 700; line-height: 1.1; margin-bottom: 1rem;
      }
      .rc-wrap .rc-hero h1 .accent { color: var(--rc-accent); }
      .rc-wrap .rc-hero h1 .dim    { color: var(--rc-muted); }
      .rc-wrap .rc-hero-sub {
        font-size: 1.05rem; color: var(--rc-muted);
        max-width: 520px; margin-bottom: 2.5rem; font-weight: 300;
      }
      .rc-wrap .rc-hero-actions { display: flex; gap: 1rem; flex-wrap: wrap; }
      .rc-wrap .rc-btn-primary {
        font-family: var(--rc-mono); font-size: 12px; letter-spacing: .06em;
        color: #000 !important; background: var(--rc-accent); border: none;
        padding: 13px 28px; cursor: pointer; font-weight: 700;
        transition: all .2s; text-decoration: none; display: inline-block;
      }
      .rc-wrap .rc-btn-primary:hover { background: #00ffb3 !important; }
      .rc-wrap .rc-btn-outline {
        font-family: var(--rc-mono); font-size: 12px; letter-spacing: .06em;
        color: var(--rc-text) !important; background: transparent;
        border: 1px solid var(--rc-border2);
        padding: 13px 28px; cursor: pointer; transition: all .2s;
        text-decoration: none; display: inline-block;
      }
      .rc-wrap .rc-hero-stats {
        margin-top: 4rem; display: flex; gap: 3rem;
        padding-top: 2rem; border-top: 1px solid var(--rc-border);
      }
      .rc-wrap .rc-stat-num {
        font-family: var(--rc-mono); font-size: 1.8rem;
        font-weight: 700; color: var(--rc-accent);
      }
      .rc-wrap .rc-stat-label { font-size: 12px; color: var(--rc-muted); margin-top: 2px; }
      /* PLATFORMS */
      .rc-wrap .rc-platforms {
        background: var(--rc-surface);
        border-top: 1px solid var(--rc-border); border-bottom: 1px solid var(--rc-border);
        padding: 1.5rem 2rem;
      }
      .rc-wrap .rc-plat-inner { display: flex; align-items: center; gap: 3rem; flex-wrap: wrap; }
      .rc-wrap .rc-plat-label {
        font-family: var(--rc-mono); font-size: 11px; color: var(--rc-muted); letter-spacing: .08em;
      }
      .rc-wrap .rc-plat-items { display: flex; gap: 2.5rem; flex-wrap: wrap; align-items: center; }
      .rc-wrap .rc-plat-item {
        display: flex; align-items: center; gap: 8px;
        font-size: 13px; color: var(--rc-muted); font-weight: 500;
      }
      .rc-wrap .rc-plat-icon {
        width: 28px; height: 28px; border-radius: 4px;
        display: flex; align-items: center; justify-content: center; font-size: 14px;
      }
      .rc-wrap .pi-win { background: rgba(0,120,212,.15); color: #0078d4; }
      .rc-wrap .pi-lin { background: rgba(255,165,0,.12);  color: #ff9f00; }
      .rc-wrap .pi-and { background: rgba(61,220,132,.12); color: #3ddc84; }
      /* SECTION */
      .rc-wrap .rc-section {
        padding: 5rem 2rem; max-width: 1100px; margin: 0 auto;
      }
      .rc-wrap .rc-section-label {
        font-family: var(--rc-mono); font-size: 11px;
        letter-spacing: .12em; color: var(--rc-accent); margin-bottom: .75rem;
      }
      .rc-wrap .rc-section-title {
        font-family: var(--rc-mono); font-size: clamp(1.6rem,3vw,2.2rem);
        font-weight: 700; margin-bottom: 1rem; line-height: 1.2;
      }
      .rc-wrap .rc-section-desc {
        color: var(--rc-muted); max-width: 540px; font-size: 1rem; margin-bottom: 3rem;
      }
      /* SERVICES */
      .rc-wrap .rc-services-grid {
        display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
        gap: 1.5px; background: var(--rc-border); border: 1px solid var(--rc-border);
      }
      .rc-wrap .rc-service-card {
        background: var(--rc-surface); padding: 2rem 1.75rem;
        transition: background .2s; position: relative; overflow: hidden;
      }
      .rc-wrap .rc-service-card:hover { background: var(--rc-surface2); }
      .rc-wrap .rc-service-card::before {
        content: ''; position: absolute; top: 0; left: 0; width: 3px; height: 100%;
        background: transparent; transition: background .2s;
      }
      .rc-wrap .rc-service-card:hover::before { background: var(--rc-accent); }
      .rc-wrap .rc-service-icon {
        width: 42px; height: 42px; border: 1px solid var(--rc-border2);
        display: flex; align-items: center; justify-content: center;
        margin-bottom: 1.25rem; font-size: 18px;
      }
      .rc-wrap .rc-service-tag {
        font-family: var(--rc-mono); font-size: 10px;
        letter-spacing: .08em; color: var(--rc-muted); margin-bottom: .5rem;
      }
      .rc-wrap .rc-service-title {
        font-family: var(--rc-mono); font-size: .95rem; font-weight: 700;
        margin-bottom: .75rem; line-height: 1.3;
      }
      .rc-wrap .rc-service-desc {
        font-size: .875rem; color: var(--rc-muted); line-height: 1.65;
      }
      .rc-wrap .rc-service-features {
        margin-top: 1.25rem; display: flex; flex-direction: column; gap: 6px;
      }
      .rc-wrap .rc-sf-item {
        font-size: 12px; color: var(--rc-muted);
        display: flex; align-items: center; gap: 8px;
      }
      .rc-wrap .rc-sf-item::before {
        content: ''; width: 4px; height: 4px; background: var(--rc-accent); flex-shrink: 0;
      }
      /* DIAG */
      .rc-wrap .rc-diag-layout { display: grid; grid-template-columns: 1fr 1fr; gap: 3rem; align-items: center; }
      .rc-wrap .rc-terminal {
        background: #0d0f13; border: 1px solid var(--rc-border2);
        padding: 1.25rem; font-family: var(--rc-mono); font-size: 12px; line-height: 1.8;
      }
      .rc-wrap .rc-term-header {
        display: flex; align-items: center; gap: 6px;
        margin-bottom: 1rem; padding-bottom: .75rem; border-bottom: 1px solid var(--rc-border);
      }
      .rc-wrap .rc-term-dot { width: 8px; height: 8px; border-radius: 50%; }
      .rc-wrap .td1 { background: #ff5f57; } .rc-wrap .td2 { background: #febc2e; } .rc-wrap .td3 { background: #28c840; }
      .rc-wrap .rc-term-title { margin-left: 6px; font-size: 11px; color: var(--rc-muted); }
      .rc-wrap .tl-prompt { color: var(--rc-accent); } .rc-wrap .tl-ok { color: #28c840; }
      .rc-wrap .tl-warn { color: #febc2e; } .rc-wrap .tl-err { color: #ff5f57; }
      .rc-wrap .tl-dim { color: var(--rc-muted); } .rc-wrap .tl-info { color: var(--rc-accent2); }
      .rc-wrap .rc-cursor {
        display: inline-block; width: 7px; height: 13px; background: var(--rc-accent);
        animation: rcBlink 1s step-end infinite; vertical-align: middle;
      }
      @keyframes rcBlink { 50% { opacity: 0; } }
      /* VULN */
      .rc-wrap .rc-vuln-section {
        background: var(--rc-surface); border: 1px solid var(--rc-border); padding: 1.75rem;
      }
      .rc-wrap .rc-vuln-header {
        font-family: var(--rc-mono); font-size: 11px; color: var(--rc-muted);
        letter-spacing: .08em; margin-bottom: 1rem;
        display: flex; justify-content: space-between; align-items: center;
      }
      .rc-wrap .rc-vuln-status { font-size: 10px; color: var(--rc-accent); border: 1px solid rgba(0,229,160,.2); padding: 3px 8px; }
      .rc-wrap .rc-vuln-row {
        display: flex; align-items: center; padding: 10px 0;
        border-bottom: 1px solid var(--rc-border); gap: 12px; font-size: 12px;
      }
      .rc-wrap .rc-vuln-row:last-child { border-bottom: none; }
      .rc-wrap .rc-vuln-sev {
        font-family: var(--rc-mono); font-size: 9px; padding: 2px 7px;
        letter-spacing: .05em; font-weight: 700; flex-shrink: 0;
      }
      .rc-wrap .sev-crit { background: rgba(255,107,53,.15); color: var(--rc-warn); border: 1px solid rgba(255,107,53,.25); }
      .rc-wrap .sev-high { background: rgba(254,188,46,.1); color: #febc2e; border: 1px solid rgba(254,188,46,.2); }
      .rc-wrap .sev-med  { background: rgba(0,153,255,.1); color: var(--rc-accent2); border: 1px solid rgba(0,153,255,.2); }
      .rc-wrap .rc-vuln-name { flex: 1; } .rc-wrap .rc-vuln-fix { font-family: var(--rc-mono); font-size: 10px; color: var(--rc-accent); cursor: pointer; }
      /* PRICING */
      .rc-wrap .rc-pricing-grid {
        display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
        gap: 1px; background: var(--rc-border); border: 1px solid var(--rc-border); margin-top: 2rem;
      }
      .rc-wrap .rc-pricing-card { background: var(--rc-surface); padding: 2rem 1.75rem; }
      .rc-wrap .rc-pricing-card.featured { background: var(--rc-surface2); border-top: 2px solid var(--rc-accent); }
      .rc-wrap .rc-pricing-label { font-family: var(--rc-mono); font-size: 10px; letter-spacing: .1em; color: var(--rc-muted); margin-bottom: .75rem; }
      .rc-wrap .rc-pricing-badge { font-family: var(--rc-mono); font-size: 9px; color: var(--rc-accent); border: 1px solid rgba(0,229,160,.3); padding: 2px 8px; display: inline-block; margin-bottom: .75rem; }
      .rc-wrap .rc-pricing-name { font-family: var(--rc-mono); font-size: 1.2rem; font-weight: 700; margin-bottom: .5rem; }
      .rc-wrap .rc-pricing-price { margin: 1.25rem 0; display: flex; align-items: baseline; gap: 4px; }
      .rc-wrap .price-currency { font-family: var(--rc-mono); font-size: 1rem; color: var(--rc-muted); }
      .rc-wrap .price-num { font-family: var(--rc-mono); font-size: 2.2rem; font-weight: 700; }
      .rc-wrap .price-period { font-size: 12px; color: var(--rc-muted); }
      .rc-wrap .rc-pricing-divider { height: 1px; background: var(--rc-border); margin: 1.25rem 0; }
      .rc-wrap .rc-pricing-feature { font-size: 13px; color: var(--rc-muted); padding: 5px 0; display: flex; align-items: center; gap: 8px; }
      .rc-wrap .pf-check { color: var(--rc-accent); } .rc-wrap .pf-none { color: var(--rc-border2); }
      /* FOOTER */
      .rc-wrap .rc-footer {
        border-top: 1px solid var(--rc-border); padding: 2.5rem 2rem;
        max-width: 1100px; margin: 0 auto;
        display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem;
      }
      .rc-wrap .rc-footer-logo { font-family: var(--rc-mono); font-size: 14px; font-weight: 700; color: var(--rc-accent); }
      .rc-wrap .rc-footer-copy { font-size: 12px; color: var(--rc-muted); }
      .rc-wrap .rc-footer ul { display: flex; gap: 1.5rem; list-style: none; }
      .rc-wrap .rc-footer ul a { font-size: 12px; color: var(--rc-muted); text-decoration: none; }
      .rc-wrap .rc-footer ul a:hover { color: var(--rc-text); }
      @media (max-width: 640px) {
        .rc-wrap .rc-diag-layout { grid-template-columns: 1fr; }
        .rc-wrap .rc-hero-stats { gap: 2rem; }
        .rc-wrap .rc-nav ul { display: none; }
      }
    </style>
    <?php
}
add_action( 'wp_head', 'resolvecore_inject_styles' );

/* ============================================================
   3. SHORTCODE PRINCIPAL [resolvecore_landing]
   ============================================================ */
function resolvecore_landing_shortcode( $atts ) {
    $atts = shortcode_atts([
        'show_nav'     => 'true',
        'show_pricing' => 'true',
        'show_footer'  => 'true',
    ], $atts, 'resolvecore_landing' );

    $show_nav     = filter_var( $atts['show_nav'],     FILTER_VALIDATE_BOOLEAN );
    $show_pricing = filter_var( $atts['show_pricing'], FILTER_VALIDATE_BOOLEAN );
    $show_footer  = filter_var( $atts['show_footer'],  FILTER_VALIDATE_BOOLEAN );

    $services = [
        ['⬡','01','Diagnóstico automatizado','Análisis completo del sistema en segundos. Detecta cuellos de botella, errores de disco y problemas de memoria sin configuración manual.',['Escaneo de CPU, RAM y almacenamiento','Análisis de procesos en tiempo real','Informe exportable en PDF/JSON']],
        ['◈','02','Proyección de vida útil del hardware','Algoritmos predictivos que estiman cuándo podrían fallar tus componentes.',['Temperatura y desgaste de disco (S.M.A.R.T)','Historial de uso de batería','Alertas preventivas configurables']],
        ['⬡','03','Análisis de vulnerabilidades del SO','Escanea el SO contra una base de datos de CVEs y aplica reparaciones automáticas.',['Base de datos de vulnerabilidades propia','Reparación con un clic','Compatible con políticas empresariales']],
        ['◇','04','Optimización del sistema','Limpieza profunda, gestión de inicio y liberación de espacio en disco de forma segura.',['Limpieza de archivos temporales y caché','Gestión de programas de inicio','Modo seguro de limpieza']],
        ['⬡','05','Panel multiplataforma','Gestiona Windows, Linux y Android desde una única interfaz.',['Panel unificado multi-dispositivo','Histórico de diagnósticos','Exportación de reportes']],
        ['◈','06','Actualizaciones automáticas','Actualizaciones silenciosas y programadas con rollback instantáneo.',['Actualizaciones programadas en silencio','Rollback instantáneo ante fallos','Compatible con entornos sin conexión']],
    ];

    ob_start(); ?>
<div class="rc-wrap">

  <?php if ( $show_nav ): ?>
  <nav class="rc-nav">
    <a href="<?php echo esc_url( home_url('/') ); ?>" class="rc-nav-logo">RESOLVE<span>CORE</span></a>
    <ul>
      <li><a href="#rc-servicios">Servicios</a></li>
      <li><a href="#rc-diagnosticos">Diagnósticos</a></li>
      <?php if ( $show_pricing ): ?><li><a href="#rc-precios">Precios</a></li><?php endif; ?>
      <li><a href="#rc-contacto">Contacto</a></li>
    </ul>
    <a href="#" class="rc-nav-cta">DESCARGAR</a>
  </nav>
  <?php endif; ?>

  <!-- HERO -->
  <section class="rc-hero">
    <div class="rc-hero-grid"></div>
    <div class="rc-hero-glow"></div>
    <div class="rc-hero-content">
      <div class="rc-badge">PLATAFORMA CROSS-PLATFORM · v1.0</div>
      <h1>
        <span class="dim">Solución a tus</span><br>
        <span class="accent">problemas</span><br>
        informáticos.
      </h1>
      <p class="rc-hero-sub">Diagnóstico automatizado, proyección de vida útil del hardware y análisis de vulnerabilidades del SO para Windows, Linux y Android.</p>
      <div class="rc-hero-actions">
        <a href="#" class="rc-btn-primary">DESCARGAR GRATIS</a>
        <a href="#rc-servicios" class="rc-btn-outline">VER SERVICIOS</a>
      </div>
      <div class="rc-hero-stats">
        <div><div class="rc-stat-num">3</div><div class="rc-stat-label">Plataformas</div></div>
        <div><div class="rc-stat-num">500+</div><div class="rc-stat-label">Vulnerabilidades en BD</div></div>
        <div><div class="rc-stat-num">100%</div><div class="rc-stat-label">Diagnóstico automatizado</div></div>
      </div>
    </div>
  </section>

  <!-- PLATAFORMAS -->
  <div class="rc-platforms">
    <div class="rc-plat-inner">
      <span class="rc-plat-label">COMPATIBLE CON</span>
      <div class="rc-plat-items">
        <div class="rc-plat-item"><div class="rc-plat-icon pi-win">⊞</div> Windows 10 / 11</div>
        <div class="rc-plat-item"><div class="rc-plat-icon pi-lin">☰</div> Linux (Ubuntu, Debian, Arch)</div>
        <div class="rc-plat-item"><div class="rc-plat-icon pi-and">◈</div> Android 10+</div>
      </div>
    </div>
  </div>

  <!-- SERVICIOS -->
  <div class="rc-section" id="rc-servicios">
    <div class="rc-section-label">// SERVICIOS</div>
    <h2 class="rc-section-title">¿Qué hace ResolveCore?</h2>
    <p class="rc-section-desc">Una plataforma unificada para mantener tus sistemas en perfecto estado, con herramientas automatizadas de nivel profesional.</p>
    <div class="rc-services-grid">
      <?php foreach ( $services as $s ): ?>
      <div class="rc-service-card">
        <div class="rc-service-icon"><?php echo esc_html( $s[0] ); ?></div>
        <div class="rc-service-tag">MÓDULO <?php echo esc_html( $s[1] ); ?></div>
        <div class="rc-service-title"><?php echo esc_html( $s[2] ); ?></div>
        <p class="rc-service-desc"><?php echo esc_html( $s[3] ); ?></p>
        <div class="rc-service-features">
          <?php foreach ( $s[4] as $f ): ?>
          <div class="rc-sf-item"><?php echo esc_html( $f ); ?></div>
          <?php endforeach; ?>
        </div>
      </div>
      <?php endforeach; ?>
    </div>
  </div>

  <!-- DIAGNÓSTICO -->
  <div class="rc-section" id="rc-diagnosticos" style="padding-top:0">
    <div class="rc-section-label">// DIAGNÓSTICO EN ACCIÓN</div>
    <h2 class="rc-section-title">Terminal de diagnóstico</h2>
    <p class="rc-section-desc">ResolveCore trabaja en segundo plano, analizando tu sistema y reportando resultados en tiempo real.</p>
    <div class="rc-diag-layout">
      <div class="rc-terminal">
        <div class="rc-term-header">
          <div class="rc-term-dot td1"></div><div class="rc-term-dot td2"></div><div class="rc-term-dot td3"></div>
          <span class="rc-term-title">resolvecore — diagnóstico completo</span>
        </div>
        <span style="display:block"><span class="tl-prompt">rc@system:~$</span> resolvecore --scan --full</span>
        <span style="display:block" class="tl-dim">Iniciando análisis del sistema...</span>
        <span style="display:block" class="tl-ok">✓ CPU: Intel Core i7-12700H — 8% carga</span>
        <span style="display:block" class="tl-ok">✓ RAM: 16GB DDR5 — 42% en uso</span>
        <span style="display:block" class="tl-warn">⚠ SSD: 87% lleno — acción recomendada</span>
        <span style="display:block" class="tl-ok">✓ Temperatura: 54°C — nominal</span>
        <span style="display:block" class="tl-dim">─────────────────────────────</span>
        <span style="display:block" class="tl-info">→ Escaneando vulnerabilidades...</span>
        <span style="display:block" class="tl-err">✗ CVE-2024-3049 detectado — CRÍTICO</span>
        <span style="display:block" class="tl-warn">⚠ CVE-2024-1871 detectado — ALTO</span>
        <span style="display:block" class="tl-ok">✓ 23 comprobaciones pasadas</span>
        <span style="display:block"><span class="tl-prompt">rc@system:~$</span> <span class="rc-cursor"></span></span>
      </div>
      <div>
        <div class="rc-vuln-section">
          <div class="rc-vuln-header">VULNERABILIDADES DETECTADAS <span class="rc-vuln-status">LIVE</span></div>
          <div class="rc-vuln-row"><span class="rc-vuln-sev sev-crit">CRÍTICO</span><span class="rc-vuln-name">CVE-2024-3049 — Kernel privilege escalation</span><span class="rc-vuln-fix">[REPARAR]</span></div>
          <div class="rc-vuln-row"><span class="rc-vuln-sev sev-high">ALTO</span><span class="rc-vuln-name">CVE-2024-1871 — SMB remote code exec</span><span class="rc-vuln-fix">[REPARAR]</span></div>
          <div class="rc-vuln-row"><span class="rc-vuln-sev sev-med">MEDIO</span><span class="rc-vuln-name">CVE-2023-4911 — glibc buffer overflow</span><span class="rc-vuln-fix">[PARCHE]</span></div>
          <div class="rc-vuln-row"><span class="rc-vuln-sev sev-med">MEDIO</span><span class="rc-vuln-name">CVE-2023-2650 — OpenSSL DoS</span><span class="rc-vuln-fix">[PARCHE]</span></div>
        </div>
      </div>
    </div>
  </div>

  <?php if ( $show_pricing ): ?>
  <!-- PRECIOS -->
  <div class="rc-section" id="rc-precios">
    <div class="rc-section-label">// PRECIOS</div>
    <h2 class="rc-section-title">Planes</h2>
    <p class="rc-section-desc">Elige el plan que se adapta a tus necesidades. Sin suscripciones ocultas.</p>
    <div class="rc-pricing-grid">
      <div class="rc-pricing-card">
        <div class="rc-pricing-label">PLAN</div>
        <div class="rc-pricing-name">Free</div>
        <div class="rc-pricing-price"><span class="price-currency">€</span><span class="price-num">0</span><span class="price-period">/ siempre</span></div>
        <div class="rc-pricing-divider"></div>
        <div class="rc-pricing-feature"><span class="pf-check">■</span> Diagnóstico básico</div>
        <div class="rc-pricing-feature"><span class="pf-check">■</span> 1 dispositivo · Windows</div>
        <div class="rc-pricing-feature"><span class="pf-none">─</span> Análisis de vulnerabilidades</div>
        <div class="rc-pricing-feature"><span class="pf-none">─</span> Proyección de hardware</div>
        <div style="margin-top:1.5rem"><a href="#" class="rc-btn-outline" style="width:100%;text-align:center;font-size:11px;padding:10px">DESCARGAR</a></div>
      </div>
      <div class="rc-pricing-card featured">
        <div class="rc-pricing-label">PLAN</div>
        <div class="rc-pricing-badge">MÁS POPULAR</div>
        <div class="rc-pricing-name">Pro</div>
        <div class="rc-pricing-price"><span class="price-currency">€</span><span class="price-num">4.99</span><span class="price-period">/ mes</span></div>
        <div class="rc-pricing-divider"></div>
        <div class="rc-pricing-feature"><span class="pf-check">■</span> Diagnóstico completo</div>
        <div class="rc-pricing-feature"><span class="pf-check">■</span> 3 dispositivos · Win + Linux</div>
        <div class="rc-pricing-feature"><span class="pf-check">■</span> Análisis de vulnerabilidades</div>
        <div class="rc-pricing-feature"><span class="pf-check">■</span> Proyección de hardware</div>
        <div style="margin-top:1.5rem"><a href="#" class="rc-btn-primary" style="width:100%;text-align:center;font-size:11px;padding:10px;display:block">EMPEZAR</a></div>
      </div>
      <div class="rc-pricing-card">
        <div class="rc-pricing-label">PLAN</div>
        <div class="rc-pricing-name">Enterprise</div>
        <div class="rc-pricing-price"><span class="price-currency">€</span><span class="price-num">14.99</span><span class="price-period">/ mes</span></div>
        <div class="rc-pricing-divider"></div>
        <div class="rc-pricing-feature"><span class="pf-check">■</span> Todo en Pro</div>
        <div class="rc-pricing-feature"><span class="pf-check">■</span> Dispositivos ilimitados</div>
        <div class="rc-pricing-feature"><span class="pf-check">■</span> Win + Linux + Android</div>
        <div class="rc-pricing-feature"><span class="pf-check">■</span> BD de vulnerabilidades offline</div>
        <div style="margin-top:1.5rem"><a href="#" class="rc-btn-outline" style="width:100%;text-align:center;font-size:11px;padding:10px">CONTACTAR</a></div>
      </div>
    </div>
  </div>
  <?php endif; ?>

  <?php if ( $show_footer ): ?>
  <footer class="rc-footer" id="rc-contacto">
    <div>
      <div class="rc-footer-logo">RESOLVECORE</div>
      <div class="rc-footer-copy" style="margin-top:6px">© <?php echo esc_html( date_i18n( 'Y' ) ); ?> Francisco Vidal Mateo · TFG ASIR</div>
    </div>
    <ul>
      <li><a href="https://github.com/Haplee" target="_blank" rel="noopener noreferrer">GitHub</a></li>
      <li><a href="#">Documentación</a></li>
      <li><a href="#">Privacidad</a></li>
    </ul>
    <div style="font-family:var(--rc-mono);font-size:11px;color:var(--rc-muted)">
      Solución a tus problemas informáticos.
    </div>
  </footer>
  <?php endif; ?>

</div><!-- .rc-wrap -->
    <?php
    return ob_get_clean();
}
add_shortcode( 'resolvecore_landing', 'resolvecore_landing_shortcode' );
