<!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
  <meta charset="<?php bloginfo('charset'); ?>">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="ResolveCore — Solución a tus problemas informáticos. Diagnóstico automatizado, análisis de vulnerabilidades y optimización para Windows, Linux y Android.">
  <title>ResolveCore — Solución a tus problemas informáticos</title>

  <!-- Open Graph -->
  <meta property="og:title" content="ResolveCore — Solución a tus problemas informáticos">
  <meta property="og:description" content="Plataforma cross-platform de mantenimiento y optimización para Windows, Linux y Android. Diagnóstico automatizado y análisis de vulnerabilidades.">
  <meta property="og:type" content="website">
  <meta property="og:locale" content="es_ES">
  <meta property="og:url" content="<?php echo esc_url( home_url( '/' ) ); ?>">
  <meta property="og:image" content="<?php echo esc_url( get_template_directory_uri() . '/og-image.png' ); ?>">
  <meta property="og:image:alt" content="ResolveCore — diagnóstico y optimización cross-platform">
  <meta property="og:site_name" content="ResolveCore">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="ResolveCore">
  <meta name="twitter:description" content="Plataforma cross-platform de mantenimiento y optimización para Windows, Linux y Android.">
  <meta name="twitter:image" content="<?php echo esc_url( get_template_directory_uri() . '/og-image.png' ); ?>">

  <!-- Theme color + canonical -->
  <meta name="theme-color" content="#0a0c10">
  <meta name="color-scheme" content="dark">
  <link rel="canonical" href="<?php echo esc_url( home_url( '/' ) ); ?>">

  <!-- Schema.org JSON-LD -->
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "name": "ResolveCore",
    "description": "Plataforma cross-platform de mantenimiento y optimización para Windows, Linux y Android. Diagnóstico automatizado, análisis de vulnerabilidades y proyección de vida útil del hardware.",
    "operatingSystem": ["Windows", "Linux", "Android"],
    "applicationCategory": "UtilitiesApplication",
    "author": {
      "@type": "Person",
      "name": "Francisco Vidal Mateo",
      "url": "https://github.com/Haplee"
    },
    "offer": {
      "@type": "Offer",
      "price": "0",
      "priceCurrency": "EUR"
    }
  }
  </script>

  <?php wp_head(); ?>
  <style>
    /* ============================================================
       RESET & VARIABLES
    ============================================================ */
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    :root {
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
    }
    html { scroll-behavior: smooth; }
    body {
      background: var(--rc-bg); color: var(--rc-text);
      font-family: var(--rc-sans); font-size: 16px;
      line-height: 1.6; overflow-x: hidden;
    }

    /* ============================================================
       A11Y — focus visible, skip-link, reduced motion
    ============================================================ */
    :focus-visible {
      outline: 2px solid var(--rc-accent);
      outline-offset: 3px;
      border-radius: 2px;
    }
    .rc-skip-link {
      position: absolute; left: -9999px; top: 8px;
      background: var(--rc-accent); color: #000;
      font-family: var(--rc-mono); font-size: 12px;
      padding: 10px 16px; z-index: 99999;
      letter-spacing: .06em; text-decoration: none;
      border-radius: 4px;
    }
    .rc-skip-link:focus {
      left: 12px; outline: 2px solid #000; outline-offset: 2px;
    }
    .rc-sr-only {
      position: absolute; width: 1px; height: 1px;
      padding: 0; margin: -1px; overflow: hidden;
      clip: rect(0,0,0,0); white-space: nowrap; border: 0;
    }
    @media (prefers-reduced-motion: reduce) {
      *, *::before, *::after {
        animation-duration: 0.001ms !important;
        animation-iteration-count: 1 !important;
        transition-duration: 0.001ms !important;
        scroll-behavior: auto !important;
      }
      .rc-particle, .rc-hero-glow, .rc-hero-glow2,
      .rc-hero-grid, .rc-hero-scroll-line, .rc-cursor { display: none !important; }
      .rc-reveal { opacity: 1 !important; transform: none !important; }
    }

    /* ============================================================
       SCROLL PROGRESS BAR
    ============================================================ */
    #rc-progress {
      position: fixed; top: 0; left: 0; height: 2px; width: 0%;
      background: var(--rc-accent); z-index: 9999;
      transition: width 0.1s linear;
    }

    /* ============================================================
       NAV
    ============================================================ */
    .rc-nav {
      position: fixed; top: 0; left: 0; right: 0; z-index: 1000;
      background: rgba(10,12,16,0); backdrop-filter: blur(0px);
      border-bottom: 1px solid transparent;
      padding: 0 2.5rem; height: 64px;
      display: flex; align-items: center; justify-content: space-between;
      transition: background .4s, backdrop-filter .4s, border-color .4s;
    }
    .rc-nav.scrolled {
      background: rgba(10,12,16,0.95);
      backdrop-filter: blur(16px);
      border-color: var(--rc-border);
    }
    .rc-nav-logo { text-decoration: none; display: flex; align-items: center; }
    .rc-nav-logo-img {
      width: 180px; height: 45px;
      object-fit: contain; object-position: left center;
    }
    .rc-nav-links { display: flex; gap: 2rem; list-style: none; }
    .rc-nav-links a {
      font-size: 13px; color: var(--rc-muted); text-decoration: none;
      font-weight: 500; letter-spacing: .03em; transition: color .2s;
      position: relative; padding-bottom: 2px;
    }
    .rc-nav-links a::after {
      content: ''; position: absolute; bottom: 0; left: 0;
      width: 0; height: 1px; background: var(--rc-accent); transition: width .3s;
    }
    .rc-nav-links a:hover { color: var(--rc-text); }
    .rc-nav-links a:hover::after { width: 100%; }
    /* Dropdown Recursos */
    .rc-nav-dd { position: relative; }
    .rc-nav-dd-btn {
      font-family: var(--rc-sans); font-size: 13px; color: var(--rc-muted);
      background: none; border: none; cursor: pointer; font-weight: 500;
      letter-spacing: .03em; transition: color .2s;
      display: flex; align-items: center; gap: 5px; padding: 0; line-height: inherit;
    }
    .rc-nav-dd-btn:hover,
    .rc-nav-dd:hover .rc-nav-dd-btn,
    .rc-nav-dd-btn[aria-expanded="true"] { color: var(--rc-text); }
    .rc-nav-dd-caret { font-size: 9px; transition: transform .25s; }
    .rc-nav-dd:hover .rc-nav-dd-caret,
    .rc-nav-dd-btn[aria-expanded="true"] .rc-nav-dd-caret { transform: rotate(180deg); }
    .rc-nav-dd-menu {
      position: absolute; top: calc(100% + 12px); left: 50%;
      transform: translateX(-50%) translateY(-6px);
      background: rgba(17,19,24,0.98); border: 1px solid var(--rc-border2);
      border-radius: 8px; padding: 6px; min-width: 210px; list-style: none;
      display: flex; flex-direction: column; gap: 2px;
      opacity: 0; visibility: hidden;
      transition: opacity .2s, transform .2s, visibility .2s;
      backdrop-filter: blur(16px); box-shadow: 0 12px 32px rgba(0,0,0,.45);
    }
    .rc-nav-dd:hover .rc-nav-dd-menu,
    .rc-nav-dd-menu.open {
      opacity: 1; visibility: visible; transform: translateX(-50%) translateY(0);
    }
    .rc-nav-dd-menu li { list-style: none; }
    .rc-nav-dd-menu a {
      display: block; padding: 9px 12px; border-radius: 5px;
      font-size: 13px; color: var(--rc-muted);
    }
    .rc-nav-dd-menu a::after { display: none; }
    .rc-nav-dd-menu a:hover { background: var(--rc-surface2); color: var(--rc-accent); }
    .rc-mobile-menu-label {
      font-family: var(--rc-mono); font-size: 10px; letter-spacing: .12em;
      text-transform: uppercase; color: var(--rc-accent);
      padding-top: .5rem; border-top: 1px solid var(--rc-border);
    }
    .rc-nav-cta {
      font-family: var(--rc-mono); font-size: 12px; letter-spacing: .06em;
      color: var(--rc-accent); border: 1px solid var(--rc-accent);
      padding: 8px 18px; text-decoration: none; transition: all .25s;
    }
    .rc-nav-cta:hover { background: var(--rc-accent); color: #000; }
    .rc-hamburger {
      display: none; flex-direction: column; gap: 5px;
      cursor: pointer; background: none; border: none; padding: 4px;
    }
    .rc-hamburger span {
      display: block; width: 22px; height: 1.5px;
      background: var(--rc-text); transition: all .3s;
    }
    .rc-mobile-menu {
      display: none; position: fixed; top: 64px; left: 0; right: 0;
      background: rgba(10,12,16,0.98); border-bottom: 1px solid var(--rc-border);
      padding: 1.5rem 2.5rem; z-index: 999; flex-direction: column; gap: 1.25rem;
    }
    .rc-mobile-menu.open { display: flex; }
    .rc-mobile-menu a {
      font-size: 14px; color: var(--rc-muted); text-decoration: none; font-weight: 500;
    }

    /* ============================================================
       HERO
    ============================================================ */
    .rc-hero {
      position: relative; min-height: 100vh;
      display: flex; align-items: center; justify-content: center;
      padding: 80px 2.5rem 0; overflow: hidden;
      text-align: center;
    }
    .rc-hero-grid {
      position: absolute; inset: 0;
      background-image:
        linear-gradient(rgba(0,229,160,.03) 1px, transparent 1px),
        linear-gradient(90deg, rgba(0,229,160,.03) 1px, transparent 1px);
      background-size: 60px 60px;
      animation: rcGrid 25s linear infinite;
    }
    @keyframes rcGrid { to { transform: translateY(60px); } }
    .rc-hero-glow {
      position: absolute; width: 700px; height: 700px; border-radius: 50%;
      background: radial-gradient(circle, rgba(0,229,160,.07) 0%, transparent 65%);
      top: -150px; right: -150px; pointer-events: none;
      animation: rcGlowPulse 6s ease-in-out infinite;
    }
    .rc-hero-glow2 {
      position: absolute; width: 500px; height: 500px; border-radius: 50%;
      background: radial-gradient(circle, rgba(0,153,255,.04) 0%, transparent 65%);
      bottom: -100px; left: -100px; pointer-events: none;
      animation: rcGlowPulse 8s ease-in-out infinite reverse;
    }
    @keyframes rcGlowPulse {
      0%, 100% { transform: scale(1); opacity: 1; }
      50% { transform: scale(1.1); opacity: 0.7; }
    }
    .rc-hero-particles {
      position: absolute; inset: 0; pointer-events: none; overflow: hidden;
    }
    .rc-particle {
      position: absolute; width: 2px; height: 2px;
      background: var(--rc-accent); border-radius: 50%; opacity: 0;
      animation: rcFloat linear infinite;
    }
    @keyframes rcFloat {
      0%   { transform: translateY(100vh) translateX(0); opacity: 0; }
      10%  { opacity: 0.6; }
      90%  { opacity: 0.3; }
      100% { transform: translateY(-10vh) translateX(30px); opacity: 0; }
    }
    .rc-hero-content {
      position: relative; max-width: 850px; z-index: 2;
      margin: 0 auto; text-align: center;
    }
    .rc-hero-sub { margin-left: auto; margin-right: auto; }
    .rc-hero-actions { justify-content: center; }
    .rc-hero-stats { justify-content: center; }
    .rc-badge { margin-left: auto; margin-right: auto; }
    .rc-badge {
      display: inline-flex; align-items: center; gap: 8px;
      font-family: var(--rc-mono); font-size: 11px; color: var(--rc-accent);
      border: 1px solid rgba(0,229,160,.25); padding: 5px 14px;
      letter-spacing: .08em; margin-bottom: 2rem;
      background: rgba(0,229,160,.05);
      animation: rcFadeUp .8s ease both;
    }
    .rc-badge::before {
      content: ''; width: 6px; height: 6px; border-radius: 50%;
      background: var(--rc-accent); animation: rcPulse 2s infinite;
    }
    @keyframes rcPulse { 50% { opacity: .25; } }
    .rc-hero h1 {
      font-family: var(--rc-mono);
      font-size: clamp(2.6rem, 5.5vw, 4.2rem);
      font-weight: 700; line-height: 1.08; margin-bottom: 1.25rem;
      letter-spacing: -.02em;
      animation: rcFadeUp .8s .1s ease both;
    }
    .rc-hero h1 .accent { color: var(--rc-accent); }
    .rc-hero h1 .dim    { color: var(--rc-muted); }
    .rc-hero-sub {
      font-size: 1.1rem; color: var(--rc-muted); max-width: 540px;
      margin-bottom: 2.5rem; font-weight: 300; line-height: 1.75;
      animation: rcFadeUp .8s .2s ease both;
    }
    .rc-hero-actions {
      display: flex; gap: 1rem; flex-wrap: wrap;
      animation: rcFadeUp .8s .3s ease both;
    }
    .rc-btn-primary {
      font-family: var(--rc-mono); font-size: 12px; letter-spacing: .06em;
      color: #000; background: var(--rc-accent); border: none;
      padding: 14px 30px; cursor: pointer; font-weight: 700;
      transition: all .25s; text-decoration: none; display: inline-flex;
      align-items: center; gap: 8px;
    }
    .rc-btn-primary:hover { background: #00ffb3; transform: translateY(-2px); box-shadow: 0 8px 24px rgba(0,229,160,.25); }
    .rc-btn-outline {
      font-family: var(--rc-mono); font-size: 12px; letter-spacing: .06em;
      color: var(--rc-text); background: transparent;
      border: 1px solid var(--rc-border2); padding: 14px 30px;
      cursor: pointer; transition: all .25s; text-decoration: none;
      display: inline-flex; align-items: center; gap: 8px;
    }
    .rc-btn-outline:hover { border-color: var(--rc-accent); color: var(--rc-accent); }
    .rc-hero-stats {
      margin-top: 3rem;
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 1.5rem 2.5rem;
      padding-top: 2rem; border-top: 1px solid var(--rc-border);
      animation: rcFadeUp .8s .4s ease both;
    }
    @media (max-width: 768px) {
      .rc-hero-stats { grid-template-columns: repeat(2, 1fr); gap: 1.25rem; }
    }
    @media (max-width: 380px) {
      .rc-hero-stats { grid-template-columns: 1fr; gap: 1rem; }
    }
    .rc-stat-num {
      font-family: var(--rc-mono); font-size: 1.9rem;
      font-weight: 700; color: var(--rc-accent);
    }
    .rc-stat-label { font-size: 12px; color: var(--rc-muted); margin-top: 3px; }
    .rc-hero-scroll {
      position: absolute; bottom: 2.5rem; left: 2rem;
      display: flex; flex-direction: column; align-items: center; gap: 10px;
      font-family: var(--rc-mono); font-size: 9px; color: var(--rc-muted);
      letter-spacing: .14em; animation: rcFadeUp .8s .6s ease both;
      writing-mode: vertical-rl; transform: rotate(180deg);
    }
    .rc-hero-scroll-mouse {
      width: 22px; height: 36px; border: 1.5px solid var(--rc-muted);
      border-radius: 12px; display: flex; justify-content: center;
      padding-top: 6px; box-sizing: border-box; writing-mode: horizontal-tb;
      transform: rotate(180deg);
      transition: border-color .25s;
    }
    .rc-hero-scroll:hover .rc-hero-scroll-mouse { border-color: var(--rc-accent); }
    .rc-hero-scroll-wheel {
      width: 2px; height: 6px; background: var(--rc-accent); border-radius: 2px;
      animation: rcMouseWheel 1.8s ease-in-out infinite;
    }
    @keyframes rcMouseWheel {
      0%   { transform: translateY(0);   opacity: 1;  }
      50%  { transform: translateY(8px); opacity: .35; }
      100% { transform: translateY(0);   opacity: 1;  }
    }
    @media (max-width: 768px) {
      .rc-hero-scroll { left: 1rem; bottom: 1.5rem; font-size: 8px; }
    }
    @media (max-width: 480px) {
      .rc-hero-scroll { display: none; }
    }

    /* ============================================================
       FADE UP ANIMATION (scroll reveal)
    ============================================================ */
    @keyframes rcFadeUp {
      from { opacity: 0; transform: translateY(24px); }
      to   { opacity: 1; transform: translateY(0); }
    }
    .rc-reveal { opacity: 0; transform: translateY(32px); transition: opacity .7s ease, transform .7s ease; }
    .rc-reveal.visible { opacity: 1; transform: translateY(0); }

    /* ============================================================
       PLATFORMS STRIP
    ============================================================ */
    .rc-platforms {
      background: var(--rc-surface);
      border-top: 1px solid var(--rc-border); border-bottom: 1px solid var(--rc-border);
      padding: 1.5rem 2.5rem; overflow: hidden;
    }
    .rc-plat-inner { max-width: 1100px; margin: 0 auto; display: flex; align-items: center; gap: 3rem; flex-wrap: wrap; }
    .rc-plat-label { font-family: var(--rc-mono); font-size: 11px; color: var(--rc-muted); letter-spacing: .08em; white-space: nowrap; }
    .rc-plat-items { display: flex; gap: 2.5rem; flex-wrap: wrap; align-items: center; }
    .rc-plat-item { display: flex; align-items: center; gap: 8px; font-size: 13px; color: var(--rc-muted); font-weight: 500; }
    .rc-plat-icon { width: 30px; height: 30px; border-radius: 4px; display: flex; align-items: center; justify-content: center; font-size: 15px; }
    .pi-win { background: rgba(0,120,212,.15); color: #0078d4; }
    .pi-lin { background: rgba(255,165,0,.12);  color: #ff9f00; }
    .pi-and { background: rgba(61,220,132,.12); color: #3ddc84; }

    /* ============================================================
       SECTION BASE
    ============================================================ */
    .rc-section { padding: 6rem 2.5rem; max-width: 1100px; margin: 0 auto; }
    .rc-section-label { font-family: var(--rc-mono); font-size: 11px; letter-spacing: .12em; color: var(--rc-accent); margin-bottom: .75rem; }
    .rc-section-title { font-family: var(--rc-mono); font-size: clamp(1.7rem,3vw,2.3rem); font-weight: 700; margin-bottom: 1rem; line-height: 1.2; }
    .rc-section-desc { color: var(--rc-muted); max-width: 540px; font-size: 1rem; margin-bottom: 3rem; line-height: 1.7; }
    .rc-section-divider { border: none; border-top: 1px solid var(--rc-border); margin: 0; }

    /* ============================================================
       SERVICES
    ============================================================ */
    .rc-services-grid {
      display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 1.5px; background: var(--rc-border); border: 1px solid var(--rc-border);
    }
    .rc-service-card {
      background: var(--rc-surface); padding: 2rem 1.75rem;
      transition: background .25s; position: relative; overflow: hidden; cursor: default;
    }
    .rc-service-card:hover { background: var(--rc-surface2); }
    .rc-service-card::before {
      content: ''; position: absolute; top: 0; left: 0;
      width: 3px; height: 100%; background: transparent; transition: background .25s;
    }
    .rc-service-card:hover::before { background: var(--rc-accent); }
    .rc-service-card::after {
      content: ''; position: absolute; top: 0; left: 0; right: 0; bottom: 0;
      background: radial-gradient(circle at var(--mx,50%) var(--my,50%), rgba(0,229,160,.04) 0%, transparent 60%);
      pointer-events: none; opacity: 0; transition: opacity .3s;
    }
    .rc-service-card:hover::after { opacity: 1; }
    .rc-service-icon { width: 44px; height: 44px; border: 1px solid var(--rc-border2); display: flex; align-items: center; justify-content: center; margin-bottom: 1.25rem; font-size: 20px; }
    .rc-service-tag { font-family: var(--rc-mono); font-size: 10px; letter-spacing: .08em; color: var(--rc-muted); margin-bottom: .5rem; }
    .rc-service-title { font-family: var(--rc-mono); font-size: .95rem; font-weight: 700; margin-bottom: .75rem; line-height: 1.3; }
    .rc-service-desc { font-size: .875rem; color: var(--rc-muted); line-height: 1.65; }
    .rc-service-features { margin-top: 1.25rem; display: flex; flex-direction: column; gap: 6px; }
    .rc-sf-item { font-size: 12px; color: var(--rc-muted); display: flex; align-items: center; gap: 8px; }
    .rc-sf-item::before { content: ''; width: 4px; height: 4px; background: var(--rc-accent); flex-shrink: 0; }

    /* ============================================================
       DEMO INTERACTIVA
    ============================================================ */
    .rc-demo-layout { display: grid; grid-template-columns: 1fr 1fr; gap: 2.5rem; align-items: start; }
    .rc-demo-platforms { display: flex; gap: .5rem; margin-bottom: 1rem; }
    .rc-demo-plat {
      flex: 1; font-family: var(--rc-mono); font-size: 11px; letter-spacing: .04em;
      color: var(--rc-muted); background: var(--rc-surface);
      border: 1px solid var(--rc-border2); padding: 8px 6px; cursor: pointer;
      transition: all .2s; display: flex; align-items: center; justify-content: center; gap: 6px;
    }
    .rc-demo-plat:hover, .rc-demo-plat.active {
      color: var(--rc-accent); border-color: rgba(0,229,160,.4); background: rgba(0,229,160,.05);
    }
    .rc-demo-controls { display: flex; flex-direction: column; gap: .75rem; margin-bottom: 1.25rem; }
    .rc-demo-btn {
      font-family: var(--rc-mono); font-size: 12px; letter-spacing: .05em;
      color: var(--rc-muted); background: var(--rc-surface);
      border: 1px solid var(--rc-border2); padding: 10px 16px;
      cursor: pointer; transition: all .2s; text-align: left;
      display: flex; align-items: center; gap: 10px;
    }
    .rc-demo-btn:hover, .rc-demo-btn.active {
      color: var(--rc-accent); border-color: rgba(0,229,160,.4);
      background: rgba(0,229,160,.05);
    }
    .rc-demo-btn .rc-demo-btn-dot {
      width: 6px; height: 6px; border-radius: 50%; background: var(--rc-border2); flex-shrink: 0;
    }
    .rc-demo-btn.active .rc-demo-btn-dot { background: var(--rc-accent); }
    .rc-demo-replay {
      margin-top: 1rem; font-family: var(--rc-mono); font-size: 11px; letter-spacing: .04em;
      color: var(--rc-muted); background: transparent; border: 1px solid var(--rc-border2);
      padding: 8px 14px; cursor: pointer; transition: all .2s;
    }
    .rc-demo-replay:hover { color: var(--rc-accent); border-color: rgba(0,229,160,.4); }
    .rc-demo-replay:disabled { opacity: .4; cursor: not-allowed; }
    .rc-terminal {
      background: #0d0f13; border: 1px solid var(--rc-border2);
      padding: 1.25rem; font-family: var(--rc-mono); font-size: 12px; line-height: 1.85;
      min-height: 320px;
    }
    .rc-term-header { display: flex; align-items: center; gap: 6px; margin-bottom: 1rem; padding-bottom: .75rem; border-bottom: 1px solid var(--rc-border); }
    .rc-term-dot { width: 8px; height: 8px; border-radius: 50%; }
    .td1 { background: #ff5f57; } .td2 { background: #febc2e; } .td3 { background: #28c840; }
    .rc-term-title { margin-left: 6px; font-size: 11px; color: var(--rc-muted); }
    .tl-p { color: var(--rc-accent); }
    .tl-typed { color: var(--rc-text); }
    .tl-ok   { color: #28c840; display: block; }
    .tl-warn { color: #febc2e; display: block; }
    .tl-err  { color: #ff5f57; display: block; }
    .tl-dim  { color: var(--rc-muted); display: block; }
    .tl-info { color: var(--rc-accent2); display: block; }
    .tl-cmd  { display: block; }
    .rc-cursor { display: inline-block; width: 7px; height: 13px; background: var(--rc-accent); animation: rcBlink 1s step-end infinite; vertical-align: middle; margin-left: 2px; }
    @keyframes rcBlink { 50% { opacity: 0; } }
    #rc-term-output { transition: opacity .3s; max-height: 300px; overflow-y: auto; }
    #rc-term-output::-webkit-scrollbar { width: 4px; }
    #rc-term-output::-webkit-scrollbar-thumb { background: var(--rc-border2); border-radius: 2px; }
    .rc-demo-progress { margin-top: 1.25rem; }
    .rc-demo-progress-label { font-family: var(--rc-mono); font-size: 11px; color: var(--rc-muted); margin-bottom: 6px; display: flex; justify-content: space-between; }
    .rc-demo-bar { height: 4px; background: var(--rc-border2); position: relative; overflow: hidden; border-radius: 2px; }
    .rc-demo-bar-fill { height: 100%; background: var(--rc-accent); width: 0%; transition: width .25s ease; }

    /* Panel de resultado de la demo */
    .rc-demo-result { margin-top: 2.5rem; animation: rcFadeUp .4s ease; }
    .rc-demo-result[hidden] { display: none; }
    @keyframes rcFadeUp { from { opacity: 0; transform: translateY(12px); } to { opacity: 1; transform: none; } }
    .rc-demo-result-grid { display: grid; grid-template-columns: auto 1fr; gap: 1.75rem; align-items: center; margin-bottom: 1.5rem; }
    .rc-demo-gauge-card { text-align: center; }
    .rc-demo-gauge { position: relative; width: 124px; height: 124px; margin: 0 auto; }
    .rc-demo-gauge-val { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; font-family: var(--rc-mono); font-size: 1.7rem; font-weight: 700; }
    .rc-demo-gauge-lbl { font-family: var(--rc-mono); font-size: 10px; letter-spacing: .1em; color: var(--rc-muted); text-transform: uppercase; margin-top: .55rem; }
    .rc-demo-stats { display: grid; grid-template-columns: repeat(3,1fr); gap: 1rem; }
    .rc-demo-stat { background: var(--rc-surface); border: 1px solid var(--rc-border); padding: 1rem .75rem; text-align: center; }
    .rc-demo-stat-num { font-family: var(--rc-mono); font-size: 1.65rem; font-weight: 700; color: var(--rc-accent); }
    .rc-demo-stat-lbl { font-size: 11px; color: var(--rc-muted); margin-top: 4px; }
    .rc-compare { background: var(--rc-surface); border: 1px solid var(--rc-border); padding: 1.5rem; }
    .rc-compare-title { font-family: var(--rc-mono); font-size: 11px; letter-spacing: .08em; color: var(--rc-muted); text-transform: uppercase; margin-bottom: 1rem; }
    .rc-compare-row { display: grid; grid-template-columns: 1fr auto auto auto; gap: 1rem; align-items: center; padding: 9px 0; border-bottom: 1px solid var(--rc-border); font-size: 13px; }
    .rc-compare-row:last-child { border-bottom: none; }
    .rc-compare-lbl { color: var(--rc-muted); }
    .rc-compare-before { font-family: var(--rc-mono); color: var(--rc-warn); }
    .rc-compare-arrow { color: var(--rc-muted); }
    .rc-compare-after { font-family: var(--rc-mono); color: var(--rc-accent); font-weight: 700; }
    .rc-demo-cta {
      display: inline-block; margin-top: 1.5rem; font-family: var(--rc-mono);
      font-size: 12px; letter-spacing: .04em; color: var(--rc-accent);
      border: 1px solid var(--rc-accent); padding: 11px 22px; text-decoration: none; transition: all .25s;
    }
    .rc-demo-cta:hover { background: var(--rc-accent); color: #000; }
    @media (max-width: 880px) {
      .rc-demo-result-grid { grid-template-columns: 1fr; }
    }

    /* ============================================================
       VULNERABILITY TABLE
    ============================================================ */
    .rc-vuln-section { background: var(--rc-surface); border: 1px solid var(--rc-border); padding: 1.75rem; }
    .rc-vuln-header { font-family: var(--rc-mono); font-size: 11px; color: var(--rc-muted); letter-spacing: .08em; margin-bottom: 1rem; display: flex; justify-content: space-between; align-items: center; }
    .rc-vuln-status { font-size: 10px; color: var(--rc-accent); border: 1px solid rgba(0,229,160,.2); padding: 3px 8px; }
    .rc-vuln-row { display: flex; align-items: center; padding: 10px 0; border-bottom: 1px solid var(--rc-border); gap: 12px; font-size: 12px; }
    .rc-vuln-row:last-child { border-bottom: none; }
    .rc-vuln-sev { font-family: var(--rc-mono); font-size: 9px; padding: 2px 7px; letter-spacing: .05em; font-weight: 700; flex-shrink: 0; }
    .sev-crit { background: rgba(255,107,53,.15); color: var(--rc-warn); border: 1px solid rgba(255,107,53,.25); }
    .sev-high { background: rgba(254,188,46,.1);  color: #febc2e;        border: 1px solid rgba(254,188,46,.2); }
    .sev-med  { background: rgba(0,153,255,.1);   color: var(--rc-accent2); border: 1px solid rgba(0,153,255,.2); }
    .rc-vuln-name { flex: 1; }
    .rc-vuln-name a { color: var(--rc-accent2); text-decoration: none; border-bottom: 1px dotted rgba(0,153,255,.45); }
    .rc-vuln-name a:hover { color: var(--rc-accent); }
    .rc-vuln-fix { font-family: var(--rc-mono); font-size: 10px; color: var(--rc-accent); cursor: pointer; padding: 3px 8px; border: 1px solid rgba(0,229,160,.2); transition: all .2s; background: transparent; }
    .rc-vuln-fix:hover { background: rgba(0,229,160,.1); }
    .rc-vuln-fix:disabled { cursor: default; opacity: .7; }
    .rc-vuln-fix.fixed { color: #28c840; border-color: rgba(40,200,64,.2); cursor: default; }

    /* ============================================================
       DOWNLOAD SECTION
    ============================================================ */
    .rc-download-section {
      background: var(--rc-surface);
      border: 1px solid var(--rc-border);
      padding: 3rem 2.5rem;
      position: relative; overflow: hidden;
    }
    .rc-download-section::before {
      content: ''; position: absolute; top: 0; left: 0; right: 0; height: 2px;
      background: linear-gradient(90deg, var(--rc-accent), var(--rc-accent2), transparent);
    }
    .rc-download-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; margin-top: 2rem; }
    .rc-download-card {
      background: var(--rc-surface2); border: 1px solid var(--rc-border2);
      padding: 1.5rem; display: flex; flex-direction: column; gap: 1rem;
      transition: all .25s; position: relative; overflow: hidden;
    }
    .rc-download-card:hover { border-color: rgba(0,229,160,.3); transform: translateY(-2px); }
    .rc-download-card-icon { font-size: 24px; }
    .rc-download-card-os { font-family: var(--rc-mono); font-size: 13px; font-weight: 700; }
    .rc-download-card-ver { font-size: 11px; color: var(--rc-muted); font-family: var(--rc-mono); }
    .rc-download-card-size { font-size: 11px; color: var(--rc-muted); }
    .rc-download-card-btn {
      font-family: var(--rc-mono); font-size: 11px; letter-spacing: .05em;
      color: var(--rc-accent); border: 1px solid rgba(0,229,160,.25);
      padding: 8px 14px; text-decoration: none; display: inline-flex;
      align-items: center; gap: 6px; transition: all .2s; width: fit-content;
    }
    .rc-download-card-btn:hover { background: rgba(0,229,160,.08); }
    .rc-download-github {
      margin-top: 2rem; padding: 1.5rem;
      background: var(--rc-surface2); border: 1px solid var(--rc-border2);
      display: flex; align-items: center; justify-content: space-between;
      flex-wrap: wrap; gap: 1rem;
    }
    .rc-download-github-info { display: flex; align-items: center; gap: 1rem; }
    .rc-github-icon { font-size: 28px; }
    .rc-github-name { font-family: var(--rc-mono); font-size: 14px; font-weight: 700; }
    .rc-github-desc { font-size: 12px; color: var(--rc-muted); margin-top: 2px; }
    .rc-github-stats { display: flex; gap: 1.5rem; }
    .rc-github-stat { font-family: var(--rc-mono); font-size: 11px; color: var(--rc-muted); display: flex; align-items: center; gap: 5px; }

    /* ============================================================
       PRICING
    ============================================================ */
    .rc-pricing-grid {
      display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
      gap: 1px; background: var(--rc-border); border: 1px solid var(--rc-border);
      margin-top: 2rem;
    }
    .rc-pricing-card { background: var(--rc-surface); padding: 2rem 1.75rem; position: relative; }
    .rc-pricing-card.featured { background: var(--rc-surface2); border-top: 2px solid var(--rc-accent); }
    .rc-pricing-label { font-family: var(--rc-mono); font-size: 10px; letter-spacing: .1em; color: var(--rc-muted); margin-bottom: .75rem; }
    .rc-pricing-badge { font-family: var(--rc-mono); font-size: 9px; color: var(--rc-accent); border: 1px solid rgba(0,229,160,.3); padding: 2px 8px; display: inline-block; margin-bottom: .75rem; }
    .rc-pricing-name { font-family: var(--rc-mono); font-size: 1.2rem; font-weight: 700; margin-bottom: .5rem; }
    .rc-pricing-price { margin: 1.25rem 0; display: flex; align-items: baseline; gap: 4px; }
    .price-currency { font-family: var(--rc-mono); font-size: 1rem; color: var(--rc-muted); }
    .price-num { font-family: var(--rc-mono); font-size: 2.3rem; font-weight: 700; }
    .price-period { font-size: 12px; color: var(--rc-muted); }
    .rc-pricing-divider { height: 1px; background: var(--rc-border); margin: 1.25rem 0; }
    .rc-pricing-feature { font-size: 13px; color: var(--rc-muted); padding: 5px 0; display: flex; align-items: center; gap: 8px; }
    .rc-beta-tag {
      display: inline-block; padding: 1px 6px; margin-left: 4px;
      font-family: var(--rc-mono); font-size: 9px; letter-spacing: .1em;
      background: rgba(0,153,255,.18); color: var(--rc-accent2);
      border: 1px solid rgba(0,153,255,.35); border-radius: 2px;
    }
    .pf-check { color: var(--rc-accent); } .pf-none { color: var(--rc-border2); }

    /* ============================================================
       CONTACT FORM
    ============================================================ */
    .rc-contact-layout { display: grid; grid-template-columns: 1fr 1.4fr; gap: 3rem; align-items: start; }
    .rc-contact-info { display: flex; flex-direction: column; gap: 1.5rem; }
    .rc-contact-item { display: flex; align-items: flex-start; gap: 1rem; }
    .rc-contact-item-icon { font-size: 18px; margin-top: 2px; }
    .rc-contact-item-label { font-family: var(--rc-mono); font-size: 11px; color: var(--rc-muted); letter-spacing: .06em; margin-bottom: 3px; }
    .rc-contact-item-val { font-size: 14px; color: var(--rc-text); }
    .rc-contact-item-val a { color: var(--rc-accent); text-decoration: none; }
    .rc-form { display: flex; flex-direction: column; gap: 1rem; }
    .rc-form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
    .rc-form-group { display: flex; flex-direction: column; gap: 6px; }
    .rc-form-label { font-family: var(--rc-mono); font-size: 10px; letter-spacing: .08em; color: var(--rc-muted); }
    .rc-form-input, .rc-form-select, .rc-form-textarea {
      background: var(--rc-surface2); border: 1px solid var(--rc-border2);
      color: var(--rc-text); font-family: var(--rc-sans); font-size: 14px;
      padding: 10px 14px; transition: border-color .2s; outline: none;
      width: 100%;
    }
    .rc-form-input:focus, .rc-form-select:focus, .rc-form-textarea:focus {
      border-color: var(--rc-accent);
    }
    .rc-form-select { appearance: none; cursor: pointer; }
    .rc-form-textarea { resize: vertical; min-height: 110px; font-family: var(--rc-sans); }
    .rc-form-submit {
      font-family: var(--rc-mono); font-size: 12px; letter-spacing: .06em;
      color: #000; background: var(--rc-accent); border: none;
      padding: 13px 28px; cursor: pointer; font-weight: 700;
      transition: all .25s; align-self: flex-start;
    }
    .rc-form-submit:hover { background: #00ffb3; transform: translateY(-1px); }
    .rc-form-submit:disabled { opacity: .5; cursor: not-allowed; transform: none; }
    .rc-form-msg { font-family: var(--rc-mono); font-size: 12px; padding: 10px 14px; display: none; }
    .rc-form-msg.success { background: rgba(40,200,64,.08); border: 1px solid rgba(40,200,64,.2); color: #28c840; display: block; }
    .rc-form-msg.error   { background: rgba(255,107,53,.08); border: 1px solid rgba(255,107,53,.2); color: var(--rc-warn); display: block; }

    /* ============================================================
       FOOTER
    ============================================================ */
    .rc-footer-outer { border-top: 1px solid var(--rc-border); background: var(--rc-surface); }
    .rc-footer { padding: 2.5rem 2.5rem; max-width: 1100px; margin: 0 auto; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem; }
    .rc-footer-logo { display: flex; align-items: center; }
    .rc-footer-logo-img {
      width: 160px; height: 40px;
      object-fit: contain; object-position: left center;
    }
    .rc-footer-copy { font-size: 12px; color: var(--rc-muted); margin-top: 4px; }
    .rc-footer-links { display: flex; gap: 1.5rem; list-style: none; }
    .rc-footer-links a { font-size: 12px; color: var(--rc-muted); text-decoration: none; transition: color .2s; }
    .rc-footer-links a:hover { color: var(--rc-accent); }
    .rc-footer-slogan { font-family: var(--rc-mono); font-size: 11px; color: var(--rc-muted); letter-spacing: .04em; }

    /* ============================================================
       BACK TO TOP
    ============================================================ */
    #rc-back-top {
      position: fixed; bottom: 2rem; right: 2rem;
      width: 40px; height: 40px; background: var(--rc-surface2);
      border: 1px solid var(--rc-border2); cursor: pointer;
      display: flex; align-items: center; justify-content: center;
      font-size: 16px; color: var(--rc-muted); transition: all .25s;
      opacity: 0; pointer-events: none; z-index: 500;
    }
    #rc-back-top.visible { opacity: 1; pointer-events: auto; }
    #rc-back-top:hover { border-color: var(--rc-accent); color: var(--rc-accent); transform: translateY(-3px); }

    /* ============================================================
       RESPONSIVE
    ============================================================ */
    /* ============================================================
       CTA BAND
    ============================================================ */
    .rc-cta-band {
      background: var(--rc-surface); border: 1px solid var(--rc-border);
      padding: 3rem 2.5rem; position: relative; overflow: hidden;
      display: grid; grid-template-columns: 1fr auto; gap: 3rem; align-items: center;
    }
    .rc-cta-band::before {
      content: ''; position: absolute; top: 0; left: 0; right: 0; height: 2px;
      background: linear-gradient(90deg, var(--rc-accent), var(--rc-accent2), transparent);
    }
    .rc-cta-band-stats { display: flex; gap: 2.5rem; flex-shrink: 0; }
    .rc-cta-stat { text-align: center; }
    @media (max-width: 768px) {
      .rc-cta-band { grid-template-columns: 1fr; }
      .rc-cta-band-stats { gap: 1.5rem; }
    }

    /* ============================================================
       FLUJO DE SERVICIO (Cómo funciona)
    ============================================================ */
    .rc-flow { display: flex; align-items: flex-start; margin-top: 2.5rem; flex-wrap: wrap; }
    .rc-flow-step {
      flex: 1; min-width: 110px; text-align: center; padding: 1.5rem .5rem;
    }
    .rc-flow-step:hover .rc-flow-icon {
      border-color: rgba(0,229,160,.45); background: rgba(0,229,160,.04);
    }
    .rc-flow-num {
      font-family: var(--rc-mono); font-size: 10px; color: var(--rc-muted);
      letter-spacing: .1em; margin-bottom: .75rem;
    }
    .rc-flow-icon {
      width: 46px; height: 46px; border: 1px solid var(--rc-border2);
      display: flex; align-items: center; justify-content: center;
      font-size: 18px; margin: 0 auto .75rem;
      transition: border-color .3s, background .3s;
    }
    .rc-flow-title {
      font-family: var(--rc-mono); font-size: 10px; font-weight: 700;
      margin-bottom: .4rem; letter-spacing: .06em;
    }
    .rc-flow-desc { font-size: 11px; color: var(--rc-muted); line-height: 1.5; }
    .rc-flow-arrow {
      display: flex; align-items: center; padding-top: 3.5rem;
      color: var(--rc-border2); font-size: 18px; flex-shrink: 0;
    }

    @media (max-width: 768px) {
      .rc-demo-layout, .rc-contact-layout { grid-template-columns: 1fr; }
      .rc-nav-links { display: none; }
      .rc-nav-cta { display: none; }
      .rc-hamburger { display: flex; }
      .rc-form-row { grid-template-columns: 1fr; }
      .rc-download-github { flex-direction: column; }
      .rc-flow { justify-content: center; gap: .25rem; }
      .rc-flow-step { min-width: 90px; flex: 0 0 calc(33% - .5rem); }
      .rc-flow-arrow { display: none; }
      .rc-section { padding: 4rem 1.5rem; }
      .rc-nav { padding: 0 1.25rem; }
      .rc-hero { padding: 80px 1.5rem 2rem; }
      .rc-hero h1 { font-size: clamp(2rem, 8vw, 3rem); }
      .rc-hero-sub { font-size: 1rem; }
      .rc-hero-actions { flex-direction: column; align-items: stretch; gap: .75rem; }
      .rc-hero-actions a { text-align: center; width: 100%; padding: 14px; }
      .rc-services-grid { grid-template-columns: 1fr; }
      .rc-pricing-grid { grid-template-columns: 1fr; }
      .rc-vuln-row { flex-wrap: wrap; }
      .rc-vuln-name { flex: 1 0 100%; order: 2; margin: 4px 0; }
      .rc-quick-channels { grid-template-columns: 1fr; }
    }
    @media (max-width: 480px) {
      .rc-section { padding: 3rem 1rem; }
      .rc-hero { padding: 72px 1rem 1.5rem; }
      .rc-hero h1 { font-size: clamp(1.75rem, 9vw, 2.5rem); line-height: 1.15; }
      .rc-badge { font-size: 10px; padding: 4px 10px; }
      .rc-section-title { font-size: 1.5rem; }
      .rc-platforms { padding: 1rem; }
      .rc-plat-items { gap: 1rem; }
      .rc-service-card { padding: 1.5rem 1.25rem; }
      .rc-terminal { font-size: 11px; padding: 1rem; min-height: 240px; }
      .rc-faq-q { font-size: 13px; padding: 1rem; }
      .rc-form-input, .rc-form-select, .rc-form-textarea { font-size: 16px; } /* iOS no zoom on focus */
    }
    /* Touch tap targets ≥ 44px (WCAG) */
    @media (hover: none) {
      .rc-btn-primary, .rc-btn-outline, .rc-nav-cta, .rc-form-submit {
        min-height: 44px;
      }
      .rc-nav-links a, .rc-footer-col a { padding: 8px 0; display: inline-block; }
    }
  </style>
</head>
<body <?php body_class(); ?>>
<?php wp_body_open(); ?>

<a class="rc-skip-link" href="#main-content">Saltar al contenido principal</a>

<!-- SCROLL PROGRESS -->
<div id="rc-progress" aria-hidden="true"></div>

<!-- BACK TO TOP -->
<button type="button" id="rc-back-top" aria-label="Volver arriba">↑</button>

<!-- ==================== NAV ==================== -->
<nav class="rc-nav" id="rc-nav" aria-label="Navegación principal">
  <a href="<?php echo esc_url( home_url( '/' ) ); ?>" class="rc-nav-logo" aria-label="ResolveCore — ir al inicio">
    <picture>
      <source srcset="<?php echo esc_url( get_template_directory_uri() . '/assets/logo/resolvcore-logo-dark.svg' ); ?>" type="image/svg+xml">
      <img src="<?php echo esc_url( get_template_directory_uri() . '/assets/logo/resolvcore-logo-dark.png' ); ?>"
           alt="ResolveCore"
           class="rc-nav-logo-img" width="180" height="45"
           fetchpriority="high" decoding="async">
    </picture>
  </a>
  <ul class="rc-nav-links">
    <li><a href="#servicios">Servicios</a></li>
    <li><a href="#como-funciona">Proceso</a></li>
    <li><a href="#precios">Precios</a></li>
    <li><a href="#faq">FAQ</a></li>
    <li class="rc-nav-dd">
      <button type="button" class="rc-nav-dd-btn" id="rc-dd-btn"
              aria-expanded="false" aria-haspopup="true" aria-controls="rc-dd-recursos">
        Recursos <span class="rc-nav-dd-caret" aria-hidden="true">▾</span>
      </button>
      <ul class="rc-nav-dd-menu" id="rc-dd-recursos" aria-labelledby="rc-dd-btn">
        <li><a href="<?php echo esc_url( home_url( '/docs/' ) ); ?>">Documentación</a></li>
        <li><a href="<?php echo esc_url( home_url( '/changelog/' ) ); ?>">Changelog</a></li>
        <li><a href="<?php echo esc_url( home_url( '/fleet-status/' ) ); ?>">Estado de la flota</a></li>
      </ul>
    </li>
    <li><a href="#contacto">Contacto</a></li>
  </ul>
  <a href="#contacto" class="rc-nav-cta">SOLICITAR SOPORTE</a>
  <button type="button" class="rc-hamburger" id="rc-hamburger"
          aria-label="Abrir menú" aria-expanded="false" aria-controls="rc-mobile-menu">
    <span aria-hidden="true"></span><span aria-hidden="true"></span><span aria-hidden="true"></span>
  </button>
</nav>

<!-- MOBILE MENU -->
<div class="rc-mobile-menu" id="rc-mobile-menu" role="dialog" aria-label="Menú de navegación" aria-hidden="true">
  <a href="#servicios">Servicios</a>
  <a href="#como-funciona">Proceso</a>
  <a href="#precios">Precios</a>
  <a href="#faq">FAQ</a>
  <a href="#contacto">Contacto</a>
  <span class="rc-mobile-menu-label">Recursos</span>
  <a href="<?php echo esc_url( home_url( '/docs/' ) ); ?>">Documentación</a>
  <a href="<?php echo esc_url( home_url( '/changelog/' ) ); ?>">Changelog</a>
  <a href="<?php echo esc_url( home_url( '/fleet-status/' ) ); ?>">Estado de la flota</a>
</div>

<main id="main-content">

<!-- ==================== HERO ==================== -->
<section class="rc-hero">
  <div class="rc-hero-grid"></div>
  <div class="rc-hero-glow"></div>
  <div class="rc-hero-glow2"></div>
  <div class="rc-hero-particles" id="rc-particles"></div>
  <div class="rc-hero-content">
    <div class="rc-badge">SERVICIO TÉCNICO REMOTO · WINDOWS · LINUX · ANDROID</div>
    <h1>
      <span class="dim">Solución a tus</span><br>
      <span class="accent">problemas</span><br>
      informáticos.
    </h1>
    <p class="rc-hero-sub">Diagnóstico automatizado, proyección de vida útil del hardware y análisis de vulnerabilidades del SO para Windows, Linux y Android.</p>
    <div class="rc-hero-actions">
      <a href="#contacto" class="rc-btn-primary">SOLICITAR SOPORTE →</a>
      <a href="#servicios" class="rc-btn-outline">VER SERVICIOS</a>
    </div>
    <div class="rc-hero-stats">
      <div><div class="rc-stat-num">&lt;2h</div><div class="rc-stat-label">Respuesta inicial</div></div>
      <div><div class="rc-stat-num">3</div><div class="rc-stat-label">Plataformas soportadas</div></div>
      <div><div class="rc-stat-num">7</div><div class="rc-stat-label">Fases del proceso</div></div>
      <div><div class="rc-stat-num">GPL-3</div><div class="rc-stat-label">Open Source</div></div>
    </div>
  </div>
  <div class="rc-hero-scroll" aria-hidden="true">
    <div class="rc-hero-scroll-mouse"><div class="rc-hero-scroll-wheel"></div></div>
    <span>SCROLL</span>
  </div>
</section>

<!-- PLATFORMS -->
<div class="rc-platforms rc-reveal">
  <div class="rc-plat-inner">
    <span class="rc-plat-label">COMPATIBLE CON</span>
    <div class="rc-plat-items">
      <div class="rc-plat-item"><div class="rc-plat-icon pi-win">⊞</div> Windows 10 / 11</div>
      <div class="rc-plat-item"><div class="rc-plat-icon pi-lin">☰</div> Linux (Ubuntu, Debian, Arch)</div>
      <div class="rc-plat-item"><div class="rc-plat-icon pi-and">◈</div> Android 10+</div>
    </div>
  </div>
</div>

<!-- ==================== SERVICIOS ==================== -->
<section class="rc-section" id="servicios" aria-label="Servicios">
  <div class="rc-reveal">
    <div class="rc-section-label">// SERVICIOS</div>
    <h2 class="rc-section-title">¿Qué hace ResolveCore?</h2>
    <p class="rc-section-desc">Una plataforma unificada para mantener tus sistemas en perfecto estado, con herramientas automatizadas de nivel profesional.</p>
  </div>
  <div class="rc-services-grid rc-reveal">
    <?php
    $services = [
      ['⬡','01','Diagnóstico automatizado','Análisis completo del sistema en segundos. Detecta cuellos de botella, errores de disco y problemas de memoria sin configuración manual.',['Escaneo de CPU, RAM y almacenamiento','Análisis de procesos en tiempo real','Informe exportable en PDF/JSON']],
      ['◈','02','Proyección de vida útil del hardware','Algoritmos predictivos que analizan el estado actual de tus componentes y estiman cuándo podrían fallar, con antelación.',['Temperatura y desgaste de disco (S.M.A.R.T)','Historial de uso de batería','Alertas preventivas configurables']],
      ['⬡','03','Análisis de vulnerabilidades del SO','Escanea el sistema operativo contra una base de datos de CVEs actualizada, detecta parches pendientes y aplica reparaciones automáticas.',['Base de datos de vulnerabilidades propia','Reparación con un clic','Compatible con políticas empresariales']],
      ['◇','04','Optimización del sistema','Limpieza profunda, desfragmentación inteligente, gestión de servicios de inicio y liberación de espacio en disco de forma segura.',['Limpieza de archivos temporales y caché','Gestión de programas de inicio','Modo seguro de limpieza']],
      ['⬡','05','Panel multiplataforma (Beta)','Dashboard centralizado en wp-admin que recibe el JSON de diagnóstico de cada agente (Win/Linux/Android) vía REST autenticado, calcula un score 0-100 de salud y agrupa los hosts por cliente y SO.',['Endpoint REST <code>/wp-json/rc/v1/fleet</code>','Score salud + filtros por SO','Listado ordenable y exportable']],
      ['◈','06','Actualizaciones automáticas','Mantén todos tus sistemas al día con actualizaciones silenciosas y programadas con control total y rollback instantáneo.',['Actualizaciones programadas en silencio','Rollback instantáneo ante fallos','Compatible con entornos sin conexión']],
    ];
    foreach ($services as $s): ?>
    <div class="rc-service-card" onmousemove="cardGlow(event,this)">
      <div class="rc-service-icon"><?php echo $s[0]; ?></div>
      <div class="rc-service-tag">MÓDULO <?php echo $s[1]; ?></div>
      <div class="rc-service-title"><?php echo esc_html($s[2]); ?></div>
      <p class="rc-service-desc"><?php echo esc_html($s[3]); ?></p>
      <div class="rc-service-features">
        <?php foreach ($s[4] as $f): ?>
        <div class="rc-sf-item"><?php echo esc_html($f); ?></div>
        <?php endforeach; ?>
      </div>
    </div>
    <?php endforeach; ?>
  </div>
</section>

<hr class="rc-section-divider">

<!-- ==================== CÓMO FUNCIONA ==================== -->
<section class="rc-section" id="como-funciona" aria-label="Cómo funciona">
  <div class="rc-reveal">
    <div class="rc-section-label">// CÓMO FUNCIONA</div>
    <h2 class="rc-section-title">El flujo de servicio</h2>
    <p class="rc-section-desc">De la solicitud al cierre en 7 pasos. Proceso trazable, automatizado y documentado.</p>
  </div>
  <div class="rc-flow rc-reveal">
    <div class="rc-flow-step">
      <div class="rc-flow-num">01</div>
      <div class="rc-flow-icon">◎</div>
      <div class="rc-flow-title">SOLICITUD</div>
      <div class="rc-flow-desc">El usuario abre una petición vía formulario web o email</div>
    </div>
    <div class="rc-flow-arrow">→</div>
    <div class="rc-flow-step">
      <div class="rc-flow-num">02</div>
      <div class="rc-flow-icon">◈</div>
      <div class="rc-flow-title">TICKET</div>
      <div class="rc-flow-desc">Se crea incidencia en MantisBT con prioridad y categoría</div>
    </div>
    <div class="rc-flow-arrow">→</div>
    <div class="rc-flow-step">
      <div class="rc-flow-num">03</div>
      <div class="rc-flow-icon">⊞</div>
      <div class="rc-flow-title">CONEXIÓN</div>
      <div class="rc-flow-desc">Acceso remoto seguro al equipo del usuario vía AnyDesk</div>
    </div>
    <div class="rc-flow-arrow">→</div>
    <div class="rc-flow-step">
      <div class="rc-flow-num">04</div>
      <div class="rc-flow-icon">⬡</div>
      <div class="rc-flow-title">DIAGNÓSTICO</div>
      <div class="rc-flow-desc">Scripts PowerShell/Bash analizan el sistema y generan un informe JSON</div>
    </div>
    <div class="rc-flow-arrow">→</div>
    <div class="rc-flow-step">
      <div class="rc-flow-num">05</div>
      <div class="rc-flow-icon">◇</div>
      <div class="rc-flow-title">RESOLUCIÓN</div>
      <div class="rc-flow-desc">Optimización, parches de seguridad y corrección de fallos detectados</div>
    </div>
    <div class="rc-flow-arrow">→</div>
    <div class="rc-flow-step">
      <div class="rc-flow-num">06</div>
      <div class="rc-flow-icon">◎</div>
      <div class="rc-flow-title">INFORME PDF</div>
      <div class="rc-flow-desc">Informe técnico completo generado y adjunto al ticket en MantisBT</div>
    </div>
    <div class="rc-flow-arrow">→</div>
    <div class="rc-flow-step">
      <div class="rc-flow-num">07</div>
      <div class="rc-flow-icon">⬡</div>
      <div class="rc-flow-title">FACTURACIÓN</div>
      <div class="rc-flow-desc">Factura automática por intervención o cargo a suscripción mensual</div>
    </div>
  </div>
</section>

<hr class="rc-section-divider">

<!-- ==================== DEMO INTERACTIVA ==================== -->
<section class="rc-section" id="demo" aria-label="Demo interactiva">
  <div class="rc-reveal">
    <div class="rc-section-label">// DEMO INTERACTIVA</div>
    <h2 class="rc-section-title">Prueba el diagnóstico</h2>
    <p class="rc-section-desc">Elige plataforma y módulo para ver cómo actúa ResolveCore. Simulación con datos de ejemplo.</p>
  </div>
  <div class="rc-demo-layout rc-reveal">
    <div>
      <div class="rc-demo-platforms" role="tablist" aria-label="Plataforma de la demo">
        <button class="rc-demo-plat active" role="tab" aria-selected="true" onclick="selectPlatform('windows',this)"><span aria-hidden="true">⊞</span> Windows</button>
        <button class="rc-demo-plat" role="tab" aria-selected="false" onclick="selectPlatform('linux',this)"><span aria-hidden="true">☰</span> Linux</button>
        <button class="rc-demo-plat" role="tab" aria-selected="false" onclick="selectPlatform('android',this)"><span aria-hidden="true">◈</span> Android</button>
      </div>
      <div class="rc-demo-controls">
        <button class="rc-demo-btn active" onclick="selectModule('diagnostico',this)">
          <div class="rc-demo-btn-dot"></div> Diagnóstico completo
        </button>
        <button class="rc-demo-btn" onclick="selectModule('vulnerabilidades',this)">
          <div class="rc-demo-btn-dot"></div> Escaneo de vulnerabilidades
        </button>
        <button class="rc-demo-btn" onclick="selectModule('hardware',this)">
          <div class="rc-demo-btn-dot"></div> Proyección de hardware
        </button>
        <button class="rc-demo-btn" onclick="selectModule('optimizacion',this)">
          <div class="rc-demo-btn-dot"></div> Optimización del sistema
        </button>
      </div>
      <div class="rc-demo-progress">
        <div class="rc-demo-progress-label"><span id="rc-prog-label">Listo</span><span id="rc-prog-pct">—</span></div>
        <div class="rc-demo-bar" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0" aria-label="Progreso del análisis">
          <div class="rc-demo-bar-fill" id="rc-demo-bar"></div>
        </div>
      </div>
      <button type="button" class="rc-demo-replay" id="rc-demo-replay" onclick="replayDemo()">↻ Repetir análisis</button>
    </div>
    <div class="rc-terminal">
      <div class="rc-term-header">
        <div class="rc-term-dot td1"></div><div class="rc-term-dot td2"></div><div class="rc-term-dot td3"></div>
        <span class="rc-term-title" id="rc-term-title">resolvecore — diagnóstico</span>
      </div>
      <div id="rc-term-output" aria-live="polite" aria-atomic="false"></div>
    </div>
  </div>

  <!-- PANEL DE RESULTADO -->
  <div class="rc-demo-result" id="rc-demo-result" hidden>
    <div class="rc-demo-result-grid">
      <div class="rc-demo-gauge-card">
        <div class="rc-demo-gauge" id="rc-demo-gauge"></div>
        <div class="rc-demo-gauge-lbl">Salud del sistema</div>
      </div>
      <div class="rc-demo-stats" id="rc-demo-stats"></div>
    </div>
    <div id="rc-demo-context"></div>
    <a class="rc-demo-cta" href="#contacto">Solicitar diagnóstico real de mi equipo →</a>
  </div>
</section>


<hr class="rc-section-divider">

<!-- ==================== PRECIOS ==================== -->
<section class="rc-section" id="precios" aria-label="Precios">
  <div class="rc-reveal">
    <div class="rc-section-label">// PRECIOS</div>
    <h2 class="rc-section-title">Planes</h2>
    <p class="rc-section-desc">Elige el plan que se adapta a tus necesidades. Sin suscripciones ocultas.</p>
  </div>
  <div class="rc-pricing-grid rc-reveal">
    <div class="rc-pricing-card">
      <div class="rc-pricing-label">PLAN</div>
      <div class="rc-pricing-name">Free</div>
      <div class="rc-pricing-price"><span class="price-currency">€</span><span class="price-num">0</span><span class="price-period">/ siempre</span></div>
      <div class="rc-pricing-divider"></div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> Diagnóstico básico</div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> 1 dispositivo · Windows</div>
      <div class="rc-pricing-feature"><span class="pf-none">─</span> Análisis de vulnerabilidades</div>
      <div class="rc-pricing-feature"><span class="pf-none">─</span> Proyección de hardware</div>
      <div class="rc-pricing-feature"><span class="pf-none">─</span> Panel multiplataforma</div>
      <div style="margin-top:1.5rem"><a href="https://github.com/Haplee/ResolveCore" target="_blank" rel="noopener noreferrer" class="rc-btn-outline" style="width:100%;justify-content:center;font-size:11px;padding:10px">DESCARGAR EN GITHUB →</a></div>
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
      <div class="rc-pricing-feature"><span class="pf-none">─</span> Panel multiplataforma</div>
      <div style="margin-top:1.5rem"><a href="#contacto" class="rc-btn-primary" style="width:100%;justify-content:center;font-size:11px;padding:10px;display:flex">EMPEZAR PRO</a></div>
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
      <div class="rc-pricing-feature"><span class="pf-check">■</span> Panel multiplataforma <span class="rc-beta-tag">BETA</span></div>
      <div style="margin-top:1.5rem"><a href="#contacto" class="rc-btn-outline" style="width:100%;justify-content:center;font-size:11px;padding:10px;display:flex">CONTACTAR</a></div>
    </div>
  </div>
</section>

<hr class="rc-section-divider">

<!-- ==================== FAQ ==================== -->
<section class="rc-section" id="faq" aria-label="Preguntas frecuentes">
  <div class="rc-reveal">
    <div class="rc-section-label">// FAQ</div>
    <h2 class="rc-section-title">Preguntas frecuentes</h2>
    <p class="rc-section-desc">Lo que la gente suele preguntar antes de contratar el servicio.</p>
  </div>
  <div class="rc-faq rc-reveal" itemscope itemtype="https://schema.org/FAQPage">
    <?php
    $faqs = [
      [
        '¿Cómo accedéis a mi equipo?',
        'Via AnyDesk, herramienta de acceso remoto cifrado. Tú aceptas la conexión cada sesión y puedes cortarla cuando quieras. Nunca dejamos acceso permanente.',
      ],
      [
        '¿En qué sistemas operativos funciona?',
        'Windows 10/11, Linux (Ubuntu, Debian, Arch y derivadas) y Android 10+. macOS está en roadmap.',
      ],
      [
        '¿Cuánto tarda un diagnóstico?',
        'El escaneo automatizado tarda 3–5 minutos. La sesión completa (diagnóstico + resolución + informe) ronda 30–90 min según incidencia.',
      ],
      [
        '¿Qué incluye el informe PDF?',
        'Resumen ejecutivo, incidencias detectadas, problemas solucionados, estado actual del equipo, recomendaciones y proyección de vida útil del hardware.',
      ],
      [
        '¿Mis datos están seguros?',
        'Sí. Conexión cifrada AnyDesk, scripts open-source auditables en GitHub, base de datos local en tu equipo. No subimos información personal a servidores externos.',
      ],
      [
        '¿Hay garantía o devolución?',
        'Si la incidencia no se resuelve, no se factura. Pago por servicio sin compromiso. Suscripciones cancelables en cualquier momento.',
      ],
      [
        '¿Puedo ver los scripts antes de ejecutarlos?',
        'Sí. Todo el código está en github.com/Haplee/ResolveCore bajo GPL v2. Auditable, modificable y libre.',
      ],
    ];
    foreach ( $faqs as $i => $f ) :
      $open = $i === 0 ? ' open' : '';
    ?>
    <details class="rc-faq-item" itemscope itemprop="mainEntity" itemtype="https://schema.org/Question"<?php echo $open; ?>>
      <summary class="rc-faq-q" itemprop="name">
        <span><?php echo esc_html( $f[0] ); ?></span>
        <span class="rc-faq-icon" aria-hidden="true">+</span>
      </summary>
      <div class="rc-faq-a" itemscope itemprop="acceptedAnswer" itemtype="https://schema.org/Answer">
        <p itemprop="text"><?php echo esc_html( $f[1] ); ?></p>
      </div>
    </details>
    <?php endforeach; ?>
  </div>
  <style>
    .rc-faq { display: flex; flex-direction: column; gap: .5rem; max-width: 820px; margin: 0 auto; }
    .rc-faq-item {
      background: var(--rc-surface); border: 1px solid var(--rc-border);
      transition: border-color .2s, background .2s;
    }
    .rc-faq-item[open] { border-color: rgba(0,229,160,.25); background: var(--rc-surface2); }
    .rc-faq-q {
      cursor: pointer; list-style: none;
      padding: 1.1rem 1.3rem;
      display: flex; justify-content: space-between; align-items: center;
      gap: 1rem;
      font-family: var(--rc-mono); font-size: 14px; font-weight: 700;
      color: var(--rc-text);
      transition: color .2s;
    }
    .rc-faq-q::-webkit-details-marker { display: none; }
    .rc-faq-q:hover { color: var(--rc-accent); }
    .rc-faq-icon {
      font-family: var(--rc-mono); font-size: 18px;
      color: var(--rc-accent); flex-shrink: 0;
      transition: transform .25s;
      width: 18px; text-align: center;
    }
    .rc-faq-item[open] .rc-faq-icon { transform: rotate(45deg); }
    .rc-faq-a {
      padding: 0 1.3rem 1.2rem;
      color: var(--rc-muted); font-size: 14px; line-height: 1.7;
    }
    .rc-faq-a p { margin: 0; }
  </style>
</section>

<hr class="rc-section-divider">

<!-- ==================== CONTACTO ==================== -->
<section class="rc-section" id="contacto" aria-label="Contacto">
  <div class="rc-reveal">
    <div class="rc-section-label">// CONTACTO</div>
    <h2 class="rc-section-title">Escríbenos</h2>
    <p class="rc-section-desc">¿Necesitas soporte técnico? Cuéntanos el problema y te respondemos en menos de 2 horas.</p>
  </div>

  <!-- Canales rápidos -->
  <div class="rc-quick-channels rc-reveal">
    <a class="rc-channel" href="mailto:fvidalmateo@gmail.com" aria-label="Enviar email">
      <div class="rc-channel-icon">✉</div>
      <div class="rc-channel-body">
        <div class="rc-channel-label">EMAIL DIRECTO</div>
        <div class="rc-channel-val">fvidalmateo@gmail.com</div>
      </div>
    </a>
    <a class="rc-channel" href="https://github.com/Haplee/ResolveCore/issues/new" target="_blank" rel="noopener noreferrer" aria-label="Abrir issue en GitHub">
      <div class="rc-channel-icon">◈</div>
      <div class="rc-channel-body">
        <div class="rc-channel-label">REPORTE TÉCNICO</div>
        <div class="rc-channel-val">GitHub Issues →</div>
      </div>
    </a>
    <a class="rc-channel" href="<?php echo esc_url( home_url( '/docs/' ) ); ?>" aria-label="Consultar documentación">
      <div class="rc-channel-icon">⬡</div>
      <div class="rc-channel-body">
        <div class="rc-channel-label">AUTOSERVICIO</div>
        <div class="rc-channel-val">Docs &amp; guías →</div>
      </div>
    </a>
  </div>
  <style>
    .rc-quick-channels {
      display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
      gap: 1rem; margin-bottom: 2.5rem;
    }
    .rc-channel {
      display: flex; align-items: center; gap: 1rem;
      background: var(--rc-surface); border: 1px solid var(--rc-border);
      padding: 1.1rem 1.25rem; text-decoration: none;
      transition: border-color .2s, transform .2s, background .2s;
    }
    .rc-channel:hover {
      border-color: rgba(0,229,160,.35);
      background: var(--rc-surface2);
      transform: translateY(-2px);
      text-decoration: none;
    }
    .rc-channel-icon {
      width: 38px; height: 38px; flex-shrink: 0;
      border: 1px solid var(--rc-border2);
      display: flex; align-items: center; justify-content: center;
      color: var(--rc-accent); font-size: 16px;
    }
    .rc-channel-label {
      font-family: var(--rc-mono); font-size: 10px; letter-spacing: .08em;
      color: var(--rc-muted); margin-bottom: 3px;
    }
    .rc-channel-val { font-size: 13px; color: var(--rc-text); font-weight: 500; }
  </style>
  <div class="rc-contact-layout rc-reveal">
    <div class="rc-contact-info">
      <div class="rc-contact-item">
        <div class="rc-contact-item-icon">◎</div>
        <div>
          <div class="rc-contact-item-label">AUTOR</div>
          <div class="rc-contact-item-val">Francisco Vidal Mateo</div>
        </div>
      </div>
      <div class="rc-contact-item">
        <div class="rc-contact-item-icon">⌥</div>
        <div>
          <div class="rc-contact-item-label">GITHUB</div>
          <div class="rc-contact-item-val"><a href="https://github.com/Haplee" target="_blank" rel="noopener noreferrer">github.com/Haplee</a></div>
        </div>
      </div>
      <div class="rc-contact-item">
        <div class="rc-contact-item-icon">◈</div>
        <div>
          <div class="rc-contact-item-label">TWITTER / X</div>
          <div class="rc-contact-item-val"><a href="https://x.com/FranVidalMateo" target="_blank" rel="noopener noreferrer">@FranVidalMateo</a></div>
        </div>
      </div>
      <div class="rc-contact-item">
        <div class="rc-contact-item-icon">⬡</div>
        <div>
          <div class="rc-contact-item-label">EMAIL</div>
          <div class="rc-contact-item-val"><a href="mailto:fvidalmateo@gmail.com">fvidalmateo@gmail.com</a></div>
        </div>
      </div>
      <div class="rc-contact-item">
        <div class="rc-contact-item-icon">◎</div>
        <div>
          <div class="rc-contact-item-label">PROYECTO</div>
          <div class="rc-contact-item-val">TFG ASIR · Barbate, Cádiz</div>
        </div>
      </div>
    </div>
    <form class="rc-form" id="rc-contact-form" onsubmit="submitForm(event)">
      <?php wp_nonce_field('resolvecore_contact','rc_nonce'); ?>
      <input type="text" name="rc_website" id="rc_website" class="rc-form-input" style="position:absolute;left:-9999px" tabindex="-1" autocomplete="off">
      <div class="rc-form-row">
        <div class="rc-form-group">
          <label class="rc-form-label" for="rc_name">NOMBRE</label>
          <input class="rc-form-input" type="text" id="rc_name" name="rc_name" placeholder="Tu nombre" required data-validate>
        </div>
        <div class="rc-form-group">
          <label class="rc-form-label" for="rc_email">EMAIL</label>
          <input class="rc-form-input" type="email" id="rc_email" name="rc_email" placeholder="tu@email.com" required data-validate>
        </div>
      </div>
      <div class="rc-form-group">
        <label class="rc-form-label" for="rc_type">TIPO DE CONSULTA</label>
        <select class="rc-form-select" id="rc_type" name="rc_type">
          <option value="soporte">Soporte técnico</option>
          <option value="bug">Reportar un bug</option>
          <option value="colaboracion">Colaboración / contribuir</option>
          <option value="licencia">Licencia Pro / Enterprise</option>
          <option value="otro">Otro</option>
        </select>
      </div>
      <div class="rc-form-group">
        <label class="rc-form-label" for="rc_message">MENSAJE <span id="rc-char-count" style="float:right;font-weight:400"></span></label>
        <textarea class="rc-form-textarea" id="rc_message" name="rc_message" placeholder="Cuéntanos en qué podemos ayudarte..." required maxlength="500" data-validate></textarea>
      </div>
      <div id="rc-form-msg" class="rc-form-msg"></div>
      <button type="submit" class="rc-form-submit" id="rc-submit-btn">ENVIAR MENSAJE →</button>
    </form>
  </div>
</section>

</main><!-- /#main-content -->

<!-- ==================== FOOTER ==================== -->
<div class="rc-footer-outer">
  <footer class="rc-footer-pro" role="contentinfo">
    <div class="rc-footer-grid">
      <div class="rc-footer-brand">
        <div class="rc-footer-logo">
          <picture>
            <source srcset="<?php echo esc_url( get_template_directory_uri() . '/assets/logo/resolvcore-logo-dark.svg' ); ?>" type="image/svg+xml">
            <img src="<?php echo esc_url( get_template_directory_uri() . '/assets/logo/resolvcore-logo-dark.png' ); ?>"
                 alt="ResolveCore"
                 class="rc-footer-logo-img" width="160" height="40"
                 loading="lazy" decoding="async">
          </picture>
        </div>
        <p class="rc-footer-slogan">Solución a tus problemas informáticos.</p>
        <p class="rc-footer-copy">© <?php echo esc_html( date_i18n( 'Y' ) ); ?> Francisco Vidal Mateo · TFG ASIR</p>
      </div>

      <nav class="rc-footer-col" aria-label="Producto">
        <div class="rc-footer-col-title">Producto</div>
        <ul>
          <li><a href="#servicios">Servicios</a></li>
          <li><a href="#como-funciona">Proceso</a></li>
          <li><a href="#precios">Precios</a></li>
          <li><a href="#faq">FAQ</a></li>
        </ul>
      </nav>

      <nav class="rc-footer-col" aria-label="Recursos">
        <div class="rc-footer-col-title">Recursos</div>
        <ul>
          <li><a href="<?php echo esc_url( home_url( '/docs/' ) ); ?>">Documentación</a></li>
          <li><a href="<?php echo esc_url( home_url( '/changelog/' ) ); ?>">Changelog</a></li>
          <li><a href="<?php echo esc_url( home_url( '/fleet-status/' ) ); ?>">Estado de la flota</a></li>
          <li><a href="https://github.com/Haplee/ResolveCore" target="_blank" rel="noopener noreferrer">GitHub <span aria-hidden="true">↗</span></a></li>
          <li><a href="#contacto">Contacto</a></li>
        </ul>
      </nav>

      <nav class="rc-footer-col" aria-label="Legal">
        <div class="rc-footer-col-title">Legal</div>
        <ul>
          <li><a href="<?php echo esc_url( home_url( '/aviso-legal/' ) ); ?>">Aviso legal</a></li>
          <li><a href="<?php echo esc_url( home_url( '/privacidad/' ) ); ?>">Privacidad (RGPD)</a></li>
          <li><a href="<?php echo esc_url( home_url( '/cookies/' ) ); ?>">Cookies</a></li>
        </ul>
      </nav>
    </div>

    <div class="rc-footer-bottom">
      <span>GPL-3.0-or-later · Open Source</span>
      <span class="rc-footer-bottom-divider" aria-hidden="true">·</span>
      <span>Hecho en España</span>
    </div>
  </footer>
  <style>
    .rc-footer-pro {
      max-width: 1200px; margin: 0 auto;
      padding: 3rem 2.5rem 2rem;
      color: var(--rc-text); font-family: var(--rc-sans);
    }
    .rc-footer-grid {
      display: grid;
      grid-template-columns: 1.4fr 1fr 1fr 1fr;
      gap: 2.5rem;
      padding-bottom: 2.5rem;
      border-bottom: 1px solid var(--rc-border);
    }
    .rc-footer-brand .rc-footer-logo-img { width: 160px; height: 40px; object-fit: contain; object-position: left center; }
    .rc-footer-slogan { color: var(--rc-muted); font-size: 13px; margin: 1rem 0 .5rem; line-height: 1.6; max-width: 260px; }
    .rc-footer-copy { color: var(--rc-muted); font-size: 12px; }
    .rc-footer-col-title {
      font-family: var(--rc-mono); font-size: 11px; letter-spacing: .12em;
      color: var(--rc-accent); margin-bottom: 1rem; text-transform: uppercase;
    }
    .rc-footer-col ul { list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 8px; }
    .rc-footer-col a { font-size: 13px; color: var(--rc-muted); text-decoration: none; transition: color .2s; }
    .rc-footer-col a:hover { color: var(--rc-accent); }
    .rc-footer-bottom {
      padding-top: 1.5rem;
      display: flex; gap: .75rem; flex-wrap: wrap;
      font-family: var(--rc-mono); font-size: 11px; color: var(--rc-muted);
      letter-spacing: .04em;
    }
    @media (max-width: 768px) {
      .rc-footer-grid { grid-template-columns: 1fr 1fr; gap: 2rem; }
      .rc-footer-brand { grid-column: 1 / -1; }
    }
    @media (max-width: 480px) {
      .rc-footer-grid { grid-template-columns: 1fr; gap: 1.75rem; }
    }
  </style>
</div>

<!-- ==================== JAVASCRIPT ==================== -->
<script>
/* --- NAV scroll (rAF throttled) --- */
const nav = document.getElementById('rc-nav');
const backTop = document.getElementById('rc-back-top');
const progress = document.getElementById('rc-progress');
let scrollTicking = false;
function onScroll() {
  const s = window.scrollY;
  nav.classList.toggle('scrolled', s > 60);
  backTop.classList.toggle('visible', s > 400);
  const h = document.documentElement.scrollHeight - window.innerHeight;
  progress.style.width = (h > 0 ? (s / h * 100) : 0) + '%';
  scrollTicking = false;
}
window.addEventListener('scroll', () => {
  if (!scrollTicking) { requestAnimationFrame(onScroll); scrollTicking = true; }
}, { passive: true });
backTop.addEventListener('click', () => window.scrollTo({ top: 0, behavior: 'smooth' }));

/* --- Mobile menu --- */
const hamburger = document.getElementById('rc-hamburger');
const mobileMenu = document.getElementById('rc-mobile-menu');
function setMenuOpen(open) {
  mobileMenu.classList.toggle('open', open);
  hamburger.setAttribute('aria-expanded', open ? 'true' : 'false');
  mobileMenu.setAttribute('aria-hidden', open ? 'false' : 'true');
  hamburger.setAttribute('aria-label', open ? 'Cerrar menú' : 'Abrir menú');
}
hamburger.addEventListener('click', () => setMenuOpen(!mobileMenu.classList.contains('open')));
mobileMenu.querySelectorAll('a').forEach(a => a.addEventListener('click', () => setMenuOpen(false)));
document.addEventListener('keydown', e => { if (e.key === 'Escape' && mobileMenu.classList.contains('open')) setMenuOpen(false); });

/* --- Nav dropdown "Recursos" (click + teclado; hover lo cubre CSS) --- */
document.querySelectorAll('.rc-nav-dd').forEach(dd => {
  const btn  = dd.querySelector('.rc-nav-dd-btn');
  const menu = dd.querySelector('.rc-nav-dd-menu');
  const close = () => { menu.classList.remove('open'); btn.setAttribute('aria-expanded', 'false'); };
  btn.addEventListener('click', e => {
    e.stopPropagation();
    const open = menu.classList.toggle('open');
    btn.setAttribute('aria-expanded', open ? 'true' : 'false');
  });
  document.addEventListener('click', e => { if (!dd.contains(e.target)) close(); });
  dd.addEventListener('keydown', e => { if (e.key === 'Escape') { close(); btn.focus(); } });
});

/* --- Scroll reveal --- */
const reveals = document.querySelectorAll('.rc-reveal');
const revealObserver = new IntersectionObserver((entries) => {
  entries.forEach(e => { if (e.isIntersecting) { e.target.classList.add('visible'); } });
}, { threshold: 0.1 });
reveals.forEach(r => revealObserver.observe(r));

/* --- Count-up animation --- */
function countUp(el, target, suffix) {
  let current = 0;
  const step = target / 60;
  const timer = setInterval(() => {
    current += step;
    if (current >= target) { current = target; clearInterval(timer); }
    el.textContent = Math.round(current) + (suffix || '');
  }, 20);
}
const statsObserver = new IntersectionObserver((entries) => {
  entries.forEach(e => {
    if (e.isIntersecting) {
      document.querySelectorAll('[data-count]').forEach(el => {
        const val = parseInt(el.dataset.count);
        const suffix = el.dataset.count === '100' ? '%' : (el.dataset.count === '500' ? '+' : '');
        countUp(el, val, suffix);
      });
      statsObserver.disconnect();
    }
  });
}, { threshold: 0.5 });
const statsSection = document.querySelector('.rc-hero-stats');
if (statsSection) statsObserver.observe(statsSection);

/* --- Card glow effect --- */
function cardGlow(e, card) {
  const rect = card.getBoundingClientRect();
  const x = ((e.clientX - rect.left) / rect.width * 100).toFixed(1) + '%';
  const y = ((e.clientY - rect.top) / rect.height * 100).toFixed(1) + '%';
  card.style.setProperty('--mx', x);
  card.style.setProperty('--my', y);
}

/* --- Particles (skip si reduced-motion) --- */
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const particleContainer = document.getElementById('rc-particles');
if (particleContainer && !reducedMotion) {
  for (let i = 0; i < 18; i++) {
    const p = document.createElement('div');
    p.className = 'rc-particle';
    p.style.left = Math.random() * 100 + '%';
    p.style.animationDuration = (8 + Math.random() * 12) + 's';
    p.style.animationDelay = (Math.random() * 10) + 's';
    p.style.width = p.style.height = (1 + Math.random() * 2) + 'px';
    particleContainer.appendChild(p);
  }
}

/* --- Vuln fix buttons (delegación) --- */
document.querySelectorAll('.rc-vuln-fix').forEach(btn => btn.addEventListener('click', () => fixVuln(btn)));

/* --- Demo interactiva --- */
/* ── Plataformas: prompt + comando real por SO ── */
const demoPlatforms = {
  windows: { label: 'Windows', prompt: 'PS C:\\>',
    cmd: { diagnostico: '.\\ResolveCore.ps1 -Scan -Full',
           vulnerabilidades: '.\\ResolveCore.ps1 -VulnScan',
           hardware: '.\\ResolveCore.ps1 -HardwareCheck',
           optimizacion: '.\\ResolveCore.ps1 -Optimize -Safe' } },
  linux:   { label: 'Linux', prompt: 'rc@linux:~$',
    cmd: { diagnostico: 'bash diagnostico.sh --full',
           vulnerabilidades: 'python3 buscar_vulnerabilidades.py',
           hardware: 'bash diagnostico.sh --hardware',
           optimizacion: 'bash optimizacion.sh --safe' } },
  android: { label: 'Android', prompt: 'rc@android:/ $',
    cmd: { diagnostico: 'bash diagnostico.sh --adb',
           vulnerabilidades: 'python3 buscar_vulnerabilidades.py --platform A',
           hardware: 'bash diagnostico.sh --battery',
           optimizacion: 'bash optimizacion.sh --trim-cache' } },
};

/* Un texto puede ser string o un objeto {windows,linux,android} */
function pickPlat(v, plat) {
  return (v && typeof v === 'object') ? (v[plat] || v.windows) : v;
}

/* ── Módulos: contenido del escenario (independiente del SO) ── */
const demoModules = {
  diagnostico: {
    title: 'diagnóstico', label: 'Ejecutando diagnóstico...', score: 68,
    lines: [
      ['dim', 'Iniciando análisis del sistema...'],
      ['ok', { windows: '✓ CPU: Intel Core i7-12700H — 8% carga',
               linux:   '✓ CPU: AMD Ryzen 7 5800X — 6% carga',
               android: '✓ SoC: Snapdragon 8 Gen 2 — 11% carga' }],
      ['ok', { windows: '✓ RAM: 16 GB DDR5 — 42% en uso',
               linux:   '✓ RAM: 32 GB DDR4 — 28% en uso',
               android: '✓ RAM: 8 GB LPDDR5 — 61% en uso' }],
      ['warn', { windows: '⚠ SSD C: 87% lleno — acción recomendada',
                 linux:   '⚠ Partición /: 87% llena — acción recomendada',
                 android: '⚠ Almacenamiento: 91% lleno — crítico' }],
      ['ok', '✓ Temperatura: 54°C — nominal'],
      ['dim', '─────────────────────────────'],
      ['info', '→ 2 vulnerabilidades críticas encontradas'],
      ['ok', '✓ Análisis completado en 3.2 s'],
    ],
    stats: [ { num: 68, label: 'Salud /100' }, { num: 87, label: '% disco usado' }, { num: 2, label: 'vulns críticas' } ],
    vulns: [
      { sev: 'crit', cve: 'CVE-2024-3049', desc: 'Kernel privilege escalation', action: 'REPARAR' },
      { sev: 'high', cve: 'CVE-2024-1871', desc: 'SMB remote code exec', action: 'REPARAR' },
    ],
    compare: null,
  },
  vulnerabilidades: {
    title: 'vulnerabilidades', label: 'Escaneando vulnerabilidades...', score: 54,
    lines: [
      ['dim', 'Cargando base de datos CVE (NVD · CISA KEV · OSV)...'],
      ['info', '→ Comparando el inventario con 500+ entradas conocidas'],
      ['err', '✗ CVE-2024-3049 — Kernel priv. escalation [CRÍTICO]'],
      ['warn', '⚠ CVE-2024-1871 — SMB remote code exec [ALTO]'],
      ['warn', '⚠ CVE-2023-4911 — glibc buffer overflow [MEDIO]'],
      ['warn', '⚠ CVE-2023-2650 — OpenSSL DoS [MEDIO]'],
      ['dim', '─────────────────────────────'],
      ['info', '→ 4 vulnerabilidades encontradas · parches disponibles'],
      ['ok', '✓ Escaneo completado en 4.7 s'],
    ],
    stats: [ { num: 54, label: 'Salud /100' }, { num: 4, label: 'CVE detectados' }, { num: 1, label: 'en CISA KEV' } ],
    vulns: [
      { sev: 'crit', cve: 'CVE-2024-3049', desc: 'Kernel privilege escalation', action: 'REPARAR' },
      { sev: 'high', cve: 'CVE-2024-1871', desc: 'SMB remote code exec', action: 'REPARAR' },
      { sev: 'med',  cve: 'CVE-2023-4911', desc: 'glibc buffer overflow', action: 'PARCHE' },
      { sev: 'med',  cve: 'CVE-2023-2650', desc: 'OpenSSL DoS', action: 'PARCHE' },
    ],
    compare: null,
  },
  hardware: {
    title: 'hardware', label: 'Analizando hardware...', score: 79,
    lines: [
      ['dim', 'Leyendo datos S.M.A.R.T...'],
      ['ok', { windows: '✓ SSD Samsung 970 EVO — 94% salud',
               linux:   '✓ SSD WD Black SN770 — 96% salud',
               android: '✓ UFS 3.1 128 GB — 92% salud' }],
      ['warn', '⚠ Temperatura del disco: 61°C — elevada'],
      ['ok', { windows: '✓ RAM: sin errores detectados',
               linux:   '✓ RAM ECC: sin errores detectados',
               android: '✓ Memoria: sin errores detectados' }],
      ['ok', { windows: '✓ Batería: 91% de capacidad original',
               linux:   '✓ Batería: 88% de capacidad original',
               android: '✓ Batería: 86% — 320 ciclos' }],
      ['dim', '─────────────────────────────'],
      ['info', '→ Vida útil estimada: ~18 meses'],
      ['ok', '✓ Proyección guardada en el informe PDF'],
    ],
    stats: [ { num: 79, label: 'Salud /100' }, { num: 94, label: '% salud SSD' }, { num: 18, label: 'meses de vida' } ],
    vulns: [],
    compare: {
      title: 'Proyección a 12 meses',
      rows: [
        { label: 'Salud del SSD', before: '94%', after: '81%' },
        { label: 'Capacidad de batería', before: '91%', after: '78%' },
        { label: 'Ciclos de batería', before: '320', after: '~680' },
      ],
    },
  },
  optimizacion: {
    title: 'optimización', label: 'Optimizando sistema...', score: 84,
    lines: [
      ['dim', 'Analizando archivos temporales y arranque...'],
      ['info', '→ 4.0 GB en archivos temporales detectados'],
      ['info', { windows: '→ 23 procesos de inicio innecesarios',
                 linux:   '→ 14 servicios systemd innecesarios',
                 android: '→ 19 apps activas en segundo plano' }],
      ['ok', '✓ Caché y temporales limpiados — 4.0 GB liberados'],
      ['ok', { windows: '✓ 12 procesos de inicio desactivados',
               linux:   '✓ 8 servicios desactivados',
               android: '✓ Caché de 19 apps recortada' }],
      ['dim', '─────────────────────────────'],
      ['ok', '✓ Sistema optimizado — +18% de rendimiento estimado'],
    ],
    stats: [ { num: 84, label: 'Salud /100' }, { num: 4, label: 'GB liberados' }, { num: 18, label: '% más rápido' } ],
    vulns: [],
    compare: {
      title: 'Antes / después',
      rows: [
        { label: 'Disco usado', before: '87%', after: '71%' },
        { label: 'Procesos al inicio', before: '23', after: '11' },
        { label: 'Tiempo de arranque', before: '23 s', after: '11 s' },
        { label: 'Salud del sistema', before: '61', after: '84' },
      ],
    },
  },
};

const demoState = { platform: 'windows', module: 'diagnostico', running: false };
const demoReduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

function selectPlatform(p, btn) {
  if (demoState.running) return;
  demoState.platform = p;
  document.querySelectorAll('.rc-demo-plat').forEach(b => {
    const on = b === btn;
    b.classList.toggle('active', on);
    b.setAttribute('aria-selected', on ? 'true' : 'false');
  });
  runDemo();
}
function selectModule(m, btn) {
  if (demoState.running) return;
  demoState.module = m;
  document.querySelectorAll('.rc-demo-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  runDemo();
}
function replayDemo() { if (!demoState.running) runDemo(); }

function runDemo(instant) {
  const plat   = demoPlatforms[demoState.platform];
  const mod    = demoModules[demoState.module];
  const cmdStr = plat.cmd[demoState.module];
  const lines  = mod.lines;
  const output = document.getElementById('rc-term-output');
  const bar    = document.getElementById('rc-demo-bar');
  const barWrap = bar.parentElement;
  const replay = document.getElementById('rc-demo-replay');
  const reduce = demoReduceMotion || instant === true;
  const totalSteps = lines.length + 1;
  let step = 0;

  function setProgress() {
    const pct = Math.round(step / totalSteps * 100);
    bar.style.width = pct + '%';
    barWrap.setAttribute('aria-valuenow', pct);
    document.getElementById('rc-prog-pct').textContent = pct + '%';
  }
  function addLine(i) {
    const ln = lines[i];
    const span = document.createElement('span');
    span.className = 'tl-' + ln[0];
    span.textContent = pickPlat(ln[1], demoState.platform);
    output.appendChild(span);
    step++; setProgress();
    output.scrollTop = output.scrollHeight;
  }
  function finish() {
    const cur = document.createElement('span');
    cur.className = 'tl-cmd';
    const p = document.createElement('span'); p.className = 'tl-p'; p.textContent = plat.prompt + ' ';
    const c = document.createElement('span'); c.className = 'rc-cursor';
    cur.appendChild(p); cur.appendChild(c);
    output.appendChild(cur);
    output.scrollTop = output.scrollHeight;
    document.getElementById('rc-prog-label').textContent = 'Completado';
    demoState.running = false;
    replay.disabled = false;
    showDemoResult(mod, reduce);
  }

  document.getElementById('rc-term-title').textContent = 'resolvecore — ' + mod.title;
  document.getElementById('rc-prog-label').textContent = mod.label;
  output.innerHTML = '';
  bar.style.width = '0%';
  document.getElementById('rc-demo-result').hidden = true;
  demoState.running = true;
  replay.disabled = true;

  const cmdEl = document.createElement('span');
  cmdEl.className = 'tl-cmd';
  const pEl = document.createElement('span'); pEl.className = 'tl-p'; pEl.textContent = plat.prompt + ' ';
  const tEl = document.createElement('span'); tEl.className = 'tl-typed';
  cmdEl.appendChild(pEl); cmdEl.appendChild(tEl);
  output.appendChild(cmdEl);

  if (reduce) {
    tEl.textContent = cmdStr;
    step++; setProgress();
    for (let i = 0; i < lines.length; i++) addLine(i);
    finish();
    return;
  }

  let ci = 0;
  (function type() {
    if (ci <= cmdStr.length) {
      tEl.textContent = cmdStr.slice(0, ci++);
      setTimeout(type, 26);
    } else {
      step++; setProgress();
      let li = 0;
      (function nextLine() {
        if (li < lines.length) { addLine(li++); setTimeout(nextLine, 230); }
        else finish();
      })();
    }
  })();
}

function animateCount(el, target, dur) {
  const start = performance.now();
  (function tick(now) {
    const p = Math.min(1, (now - start) / dur);
    el.textContent = Math.round(p * target);
    if (p < 1) requestAnimationFrame(tick);
  })(start);
}

function showDemoResult(mod, instant) {
  document.getElementById('rc-demo-result').hidden = false;

  /* Gauge SVG */
  const gauge = document.getElementById('rc-demo-gauge');
  const color = mod.score >= 80 ? '#00e5a0' : mod.score >= 60 ? '#ffc107' : '#ff4757';
  const r = 42, circ = 2 * Math.PI * r;
  gauge.innerHTML =
    '<svg width="124" height="124" viewBox="0 0 110 110">'
    + '<circle cx="55" cy="55" r="' + r + '" fill="none" stroke="#1e2330" stroke-width="8"/>'
    + '<circle id="rc-gauge-arc" cx="55" cy="55" r="' + r + '" fill="none" stroke="' + color
    + '" stroke-width="8" stroke-linecap="round" stroke-dasharray="0 ' + circ
    + '" transform="rotate(-90 55 55)"/></svg>'
    + '<div class="rc-demo-gauge-val" style="color:' + color + '">0</div>';
  const arc = gauge.querySelector('#rc-gauge-arc');
  const val = gauge.querySelector('.rc-demo-gauge-val');
  const targetDash = mod.score / 100 * circ;
  if (instant) {
    arc.setAttribute('stroke-dasharray', targetDash + ' ' + circ);
    val.textContent = mod.score;
  } else {
    arc.style.transition = 'stroke-dasharray 1.1s ease';
    requestAnimationFrame(() => arc.setAttribute('stroke-dasharray', targetDash + ' ' + circ));
    animateCount(val, mod.score, 1100);
  }

  /* Contadores */
  const stats = document.getElementById('rc-demo-stats');
  stats.innerHTML = mod.stats.map(s =>
    '<div class="rc-demo-stat"><div class="rc-demo-stat-num" data-num="' + s.num + '">0</div>'
    + '<div class="rc-demo-stat-lbl">' + s.label + '</div></div>').join('');
  stats.querySelectorAll('.rc-demo-stat-num').forEach(el => {
    const n = parseInt(el.dataset.num, 10);
    if (instant) el.textContent = n; else animateCount(el, n, 1000);
  });

  /* Contexto: vulnerabilidades o comparativa */
  const ctx = document.getElementById('rc-demo-context');
  if (mod.vulns && mod.vulns.length) ctx.innerHTML = renderDemoVulns(mod.vulns);
  else if (mod.compare)              ctx.innerHTML = renderDemoCompare(mod.compare);
  else                               ctx.innerHTML = '';
}

function renderDemoVulns(vulns) {
  const sevLbl = { crit: 'CRÍTICO', high: 'ALTO', med: 'MEDIO' };
  let h = '<div class="rc-vuln-section" style="margin-top:0">'
    + '<div class="rc-vuln-header">VULNERABILIDADES DETECTADAS <span class="rc-vuln-status">SIMULACIÓN</span></div>';
  vulns.forEach(v => {
    h += '<div class="rc-vuln-row">'
      + '<span class="rc-vuln-sev sev-' + v.sev + '">' + sevLbl[v.sev] + '</span>'
      + '<span class="rc-vuln-name"><a href="https://nvd.nist.gov/vuln/detail/' + v.cve
      + '" target="_blank" rel="noopener noreferrer">' + v.cve + '</a> — ' + v.desc + '</span>'
      + '<button type="button" class="rc-vuln-fix" onclick="fixVuln(this)" aria-label="'
      + (v.action === 'REPARAR' ? 'Reparar ' : 'Aplicar parche ') + v.cve + '">[' + v.action + ']</button>'
      + '</div>';
  });
  return h + '</div>';
}

function renderDemoCompare(cmp) {
  let h = '<div class="rc-compare"><div class="rc-compare-title">' + cmp.title + '</div>';
  cmp.rows.forEach(r => {
    h += '<div class="rc-compare-row">'
      + '<span class="rc-compare-lbl">' + r.label + '</span>'
      + '<span class="rc-compare-before">' + r.before + '</span>'
      + '<span class="rc-compare-arrow" aria-hidden="true">→</span>'
      + '<span class="rc-compare-after">' + r.after + '</span></div>';
  });
  return h + '</div>';
}

/* --- Reparar vulnerabilidad (simulación) --- */
function fixVuln(el) {
  if (el.classList.contains('fixed')) return;
  el.textContent = '[APLICANDO...]';
  el.disabled = true;
  setTimeout(() => {
    el.textContent = '[✓ HECHO]';
    el.classList.add('fixed');
    el.closest('.rc-vuln-row').style.opacity = '0.45';
  }, 1100);
}

/* Render inicial sin animación */
runDemo(true);

/* --- Form validation & counter --- */
const textarea = document.getElementById('rc_message');
const charCount = document.getElementById('rc-char-count');
const MAX_CHARS = 500;
if (textarea && charCount) {
  textarea.addEventListener('input', () => {
    const len = textarea.value.length;
    charCount.textContent = len + ' / ' + MAX_CHARS;
    charCount.style.color = len > MAX_CHARS ? '#ff6b35' : (len > MAX_CHARS - 50 ? '#febc2e' : '');
  });
  charCount.textContent = '0 / ' + MAX_CHARS;
}

document.querySelectorAll('[data-validate]').forEach(input => {
  input.addEventListener('blur', function() {
    const isValid = this.checkValidity();
    this.style.borderColor = isValid ? '' : '#ff6b35';
  });
  input.addEventListener('input', function() {
    if (this.checkValidity()) this.style.borderColor = '';
  });
});

/* --- Contact form AJAX --- */
function submitForm(e) {
  e.preventDefault();
  const honeypot = document.getElementById('rc_website').value;
  if (honeypot) return;
  const btn = document.getElementById('rc-submit-btn');
  const msg = document.getElementById('rc-form-msg');
  btn.disabled = true;
  btn.textContent = 'ENVIANDO...';
  msg.className = 'rc-form-msg';
  msg.style.display = 'none';
  const form = document.getElementById('rc-contact-form');
  const data = new FormData(form);
  data.append('action', 'resolvecore_contact');
  data.append('nonce', document.querySelector('[name="rc_nonce"]').value);
  fetch('<?php echo admin_url("admin-ajax.php"); ?>', { method: 'POST', body: data })
    .then(r => r.json())
    .then(res => {
      if (res.success) {
        msg.className = 'rc-form-msg success';
        msg.textContent = res.data.msg;
        if (res.data.ticket_id) {
          const link = document.createElement('a');
          link.href = '#';
          link.className = 'rc-ticket-link';
          link.dataset.ticket = res.data.ticket_id;
          link.style.cssText = 'color:var(--rc-accent);margin-left:6px;font-family:var(--rc-mono);font-size:11px;cursor:pointer;text-decoration:underline;';
          link.textContent = '[VER TICKET #' + res.data.ticket_id + ']';
          msg.appendChild(link);
        }
        form.reset();
        charCount.textContent = '0 / ' + MAX_CHARS;
      } else {
        msg.className = 'rc-form-msg error';
        msg.textContent = res.data.msg || 'Error al enviar.';
      }
      msg.style.display = 'block';
      btn.disabled = false;
      btn.textContent = 'ENVIAR MENSAJE →';
    })
    .catch(() => {
      msg.className = 'rc-form-msg error';
      msg.textContent = 'Error de conexión. Inténtalo de nuevo.';
      msg.style.display = 'block';
      btn.disabled = false;
      btn.textContent = 'ENVIAR MENSAJE →';
    });
}
</script>

<!-- ==================== MODAL TRACKING TICKET ==================== -->
<div class="rc-ticket-modal" id="rc-ticket-modal" role="dialog" aria-modal="true" aria-labelledby="rc-ticket-modal-title" aria-hidden="true">
  <div class="rc-ticket-modal-overlay" data-rc-close></div>
  <div class="rc-ticket-modal-box">
    <button class="rc-ticket-modal-close" aria-label="Cerrar" data-rc-close>&times;</button>
    <div class="rc-ticket-modal-head">
      <div class="rc-ticket-modal-label">// SEGUIMIENTO DEL TICKET</div>
      <div class="rc-ticket-modal-title" id="rc-ticket-modal-title">Cargando…</div>
    </div>
    <div class="rc-ticket-modal-body" id="rc-ticket-modal-body">
      <div class="rc-ticket-loading">
        <div class="rc-ticket-spin"></div>
        <span>Consultando estado en MantisBT…</span>
      </div>
    </div>
    <div class="rc-ticket-modal-foot">
      <button type="button" class="rc-ticket-refresh" id="rc-ticket-refresh">↻ Actualizar</button>
      <span class="rc-ticket-foot-note">Estado en tiempo real desde MantisBT.</span>
    </div>
  </div>
</div>
<style>
.rc-ticket-modal {
  position: fixed; inset: 0; z-index: 10000;
  display: none; align-items: center; justify-content: center;
  padding: 1.5rem; box-sizing: border-box;
}
.rc-ticket-modal.open { display: flex; animation: rcFadeUp .25s ease both; }
.rc-ticket-modal-overlay {
  position: absolute; inset: 0; background: rgba(0,0,0,.78);
  backdrop-filter: blur(6px);
}
.rc-ticket-modal-box {
  position: relative; max-width: 560px; width: 100%;
  background: var(--rc-surface); border: 1px solid var(--rc-border2);
  box-shadow: 0 24px 60px rgba(0,0,0,.55);
  max-height: 90vh; overflow: hidden;
  display: flex; flex-direction: column;
}
.rc-ticket-modal-close {
  position: absolute; top: 10px; right: 10px;
  width: 32px; height: 32px; background: transparent;
  border: 1px solid var(--rc-border); color: var(--rc-muted);
  cursor: pointer; font-size: 18px; line-height: 1;
  transition: all .2s; font-family: var(--rc-mono);
}
.rc-ticket-modal-close:hover { color: var(--rc-warn); border-color: var(--rc-warn); }
.rc-ticket-modal-head {
  padding: 1.5rem 1.75rem 1rem;
  border-bottom: 1px solid var(--rc-border);
}
.rc-ticket-modal-label {
  font-family: var(--rc-mono); font-size: 10px; letter-spacing: .12em;
  color: var(--rc-accent); margin-bottom: .5rem;
}
.rc-ticket-modal-title {
  font-family: var(--rc-mono); font-size: 1.3rem; font-weight: 700;
  color: var(--rc-text);
}
.rc-ticket-modal-body {
  padding: 1.5rem 1.75rem; overflow-y: auto; flex: 1 1 auto;
}
.rc-ticket-modal-foot {
  padding: .9rem 1.75rem; border-top: 1px solid var(--rc-border);
  display: flex; align-items: center; justify-content: space-between;
  gap: 1rem; flex-wrap: wrap;
}
.rc-ticket-refresh {
  font-family: var(--rc-mono); font-size: 11px; letter-spacing: .06em;
  background: transparent; border: 1px solid var(--rc-border2);
  color: var(--rc-accent); padding: 6px 12px; cursor: pointer;
  transition: all .2s;
}
.rc-ticket-refresh:hover { border-color: var(--rc-accent); background: rgba(0,229,160,.06); }
.rc-ticket-foot-note {
  font-family: var(--rc-mono); font-size: 10px; color: var(--rc-muted);
  letter-spacing: .04em;
}

.rc-ticket-loading {
  display: flex; flex-direction: column; align-items: center; gap: 1rem;
  padding: 2rem 0; color: var(--rc-muted);
  font-family: var(--rc-mono); font-size: 12px;
}
.rc-ticket-spin {
  width: 32px; height: 32px;
  border: 2px solid var(--rc-border2); border-top-color: var(--rc-accent);
  border-radius: 50%; animation: rcSpin 0.9s linear infinite;
}
@keyframes rcSpin { to { transform: rotate(360deg); } }

.rc-ticket-error {
  padding: 1rem; border: 1px solid var(--rc-warn);
  background: rgba(255,107,53,.06); color: var(--rc-warn);
  font-family: var(--rc-mono); font-size: 12px;
}

.rc-ticket-status-pill {
  display: inline-flex; align-items: center; gap: 6px;
  font-family: var(--rc-mono); font-size: 10px; letter-spacing: .1em;
  text-transform: uppercase; padding: 4px 10px; border-radius: 999px;
  background: rgba(0,229,160,.1); color: var(--rc-accent);
  border: 1px solid rgba(0,229,160,.3);
}
.rc-ticket-status-pill::before {
  content: ''; width: 6px; height: 6px; border-radius: 50%;
  background: var(--rc-accent); animation: rcPulse 1.6s ease-in-out infinite;
}
@keyframes rcPulse { 50% { opacity: .35; } }

/* Timeline tracking — package-style */
.rc-track {
  position: relative; padding-left: 0; margin: 1.5rem 0 0;
  list-style: none;
}
.rc-track-step {
  position: relative; display: flex; gap: 14px;
  padding-bottom: 1.5rem;
}
.rc-track-step:last-child { padding-bottom: 0; }
.rc-track-step::before {
  content: ''; position: absolute; left: 9px; top: 22px;
  width: 2px; height: calc(100% - 16px);
  background: var(--rc-border2);
}
.rc-track-step:last-child::before { display: none; }
.rc-track-step.done::before { background: var(--rc-accent); }
.rc-track-dot {
  width: 20px; height: 20px; flex-shrink: 0;
  border-radius: 50%; border: 2px solid var(--rc-border2);
  background: var(--rc-surface); margin-top: 2px;
  display: flex; align-items: center; justify-content: center;
  font-size: 11px; color: transparent; font-weight: 700;
}
.rc-track-step.done .rc-track-dot {
  background: var(--rc-accent); border-color: var(--rc-accent); color: #000;
}
.rc-track-step.done .rc-track-dot::after { content: '✓'; }
.rc-track-step.active .rc-track-dot {
  background: var(--rc-surface); border-color: var(--rc-accent);
  box-shadow: 0 0 0 4px rgba(0,229,160,.18);
  animation: rcDotPulse 1.6s ease-in-out infinite;
}
@keyframes rcDotPulse {
  50% { box-shadow: 0 0 0 8px rgba(0,229,160,.05); }
}
.rc-track-info { flex: 1; min-width: 0; }
.rc-track-label {
  font-family: var(--rc-mono); font-size: 13px; font-weight: 700;
  color: var(--rc-muted); margin-bottom: 2px;
}
.rc-track-step.done    .rc-track-label { color: var(--rc-text); }
.rc-track-step.active  .rc-track-label { color: var(--rc-accent); }
.rc-track-desc {
  font-size: 12px; color: var(--rc-muted); line-height: 1.5;
}

.rc-ticket-meta-grid {
  display: grid; grid-template-columns: 1fr 1fr; gap: .75rem 1rem;
  margin-top: 1.5rem; padding-top: 1rem;
  border-top: 1px dashed var(--rc-border);
  font-family: var(--rc-mono); font-size: 11px;
}
.rc-ticket-meta-grid dt {
  color: var(--rc-muted); letter-spacing: .06em; text-transform: uppercase;
  font-size: 10px;
}
.rc-ticket-meta-grid dd {
  color: var(--rc-text); margin: 0;
}
@media (max-width: 480px) {
  .rc-ticket-modal-box  { max-height: 95vh; }
  .rc-ticket-modal-head { padding: 1.25rem 1.25rem .75rem; }
  .rc-ticket-modal-body { padding: 1.25rem; }
  .rc-ticket-modal-foot { padding: .75rem 1.25rem; }
  .rc-ticket-meta-grid  { grid-template-columns: 1fr; }
}
</style>
<script>
(function() {
  const modal    = document.getElementById('rc-ticket-modal');
  const titleEl  = document.getElementById('rc-ticket-modal-title');
  const bodyEl   = document.getElementById('rc-ticket-modal-body');
  const refresh  = document.getElementById('rc-ticket-refresh');
  let currentId  = null;

  function openModal() {
    modal.classList.add('open');
    modal.setAttribute('aria-hidden', 'false');
    document.body.style.overflow = 'hidden';
  }
  function closeModal() {
    modal.classList.remove('open');
    modal.setAttribute('aria-hidden', 'true');
    document.body.style.overflow = '';
    currentId = null;
  }

  modal.addEventListener('click', e => {
    if (e.target.matches('[data-rc-close]')) closeModal();
  });
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && modal.classList.contains('open')) closeModal();
  });

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, c => ({
      '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
    })[c]);
  }

  function renderLoading() {
    bodyEl.innerHTML = `
      <div class="rc-ticket-loading">
        <div class="rc-ticket-spin"></div>
        <span>Consultando estado en MantisBT…</span>
      </div>`;
  }

  function renderError(msg) {
    bodyEl.innerHTML = `<div class="rc-ticket-error">${escapeHtml(msg || 'Error desconocido.')}</div>`;
  }

  function formatDate(s) {
    if (!s) return '—';
    try {
      const d = new Date(s);
      if (isNaN(d.getTime())) return s;
      return d.toLocaleString('es-ES', {
        day:'2-digit', month:'short', year:'numeric',
        hour:'2-digit', minute:'2-digit'
      });
    } catch { return s; }
  }

  function renderTicket(data) {
    titleEl.textContent = 'Ticket #' + data.ticket_id;
    const steps = (data.events || []).map(ev => {
      let cls = 'pending';
      if (ev.phase <  data.phase) cls = 'done';
      if (ev.phase === data.phase) cls = 'active';
      return `
        <li class="rc-track-step ${cls}">
          <div class="rc-track-dot"></div>
          <div class="rc-track-info">
            <div class="rc-track-label">${escapeHtml(ev.label)}</div>
            <div class="rc-track-desc">${escapeHtml(ev.desc)}</div>
          </div>
        </li>`;
    }).join('');

    bodyEl.innerHTML = `
      <span class="rc-ticket-status-pill">${escapeHtml((data.status || '').toUpperCase())}</span>
      <ul class="rc-track">${steps}</ul>
      <dl class="rc-ticket-meta-grid">
        <dt>Creado</dt>     <dd>${escapeHtml(formatDate(data.created_at))}</dd>
        <dt>Actualizado</dt><dd>${escapeHtml(formatDate(data.updated_at))}</dd>
      </dl>`;
  }

  function fetchStatus(id) {
    currentId = id;
    renderLoading();
    openModal();

    const fd = new FormData();
    fd.append('action', 'resolvecore_ticket_status');
    fd.append('nonce', document.querySelector('[name="rc_nonce"]').value);
    fd.append('ticket_id', id);

    fetch('<?php echo admin_url("admin-ajax.php"); ?>', { method: 'POST', body: fd })
      .then(r => r.json())
      .then(res => {
        if (res.success) renderTicket(res.data);
        else renderError(res.data && res.data.msg);
      })
      .catch(() => renderError('Error de red. Inténtalo de nuevo.'));
  }

  // Delegación: cualquier .rc-ticket-link en la página
  document.addEventListener('click', e => {
    const link = e.target.closest('.rc-ticket-link');
    if (!link) return;
    e.preventDefault();
    const id = link.dataset.ticket;
    if (id) fetchStatus(id);
  });

  refresh.addEventListener('click', () => { if (currentId) fetchStatus(currentId); });
})();
</script>

<!-- ==================== FAB CONTACTO ==================== -->
<a class="rc-fab-contact" href="#contacto" aria-label="Contacta con nosotros">
  <span class="rc-fab-icon" aria-hidden="true">✉</span>
  <span class="rc-fab-text">Contacta</span>
</a>
<style>
.rc-fab-contact {
  position: fixed; right: 1.5rem; bottom: 1.5rem; z-index: 9000;
  display: inline-flex; align-items: center; gap: 8px;
  background: var(--rc-accent); color: #000;
  font-family: var(--rc-mono); font-size: 13px; font-weight: 700;
  letter-spacing: .04em; padding: 12px 20px;
  border-radius: 999px; text-decoration: none;
  box-shadow: 0 8px 28px rgba(0,229,160,.28), 0 2px 6px rgba(0,0,0,.25);
  transition: transform .25s, box-shadow .25s, background .25s;
}
.rc-fab-contact:hover {
  background: #00ffb3; transform: translateY(-3px);
  box-shadow: 0 12px 32px rgba(0,229,160,.4), 0 4px 10px rgba(0,0,0,.3);
}
.rc-fab-contact:focus-visible { outline: 2px solid #fff; outline-offset: 3px; }
.rc-fab-icon { font-size: 16px; line-height: 1; }
.rc-fab-contact::after {
  content: ''; position: absolute; inset: 0; border-radius: 999px;
  box-shadow: 0 0 0 0 rgba(0,229,160,.55);
  animation: rcFabPulse 2.4s ease-out infinite; pointer-events: none;
}
@keyframes rcFabPulse {
  0%   { box-shadow: 0 0 0 0   rgba(0,229,160,.45); }
  70%  { box-shadow: 0 0 0 14px rgba(0,229,160,0);   }
  100% { box-shadow: 0 0 0 0   rgba(0,229,160,0);   }
}
@media (max-width: 480px) {
  .rc-fab-text { display: none; }
  .rc-fab-contact { padding: 14px; }
  .rc-fab-icon { font-size: 18px; }
}
@media (prefers-reduced-motion: reduce) {
  .rc-fab-contact::after { animation: none; }
  .rc-fab-contact:hover { transform: none; }
}
/* Ocultar FAB cuando la sección #contacto está visible */
body.rc-at-contact .rc-fab-contact { opacity: 0; pointer-events: none; transform: translateY(20px); }
.rc-fab-contact { transition: opacity .3s, transform .3s, box-shadow .25s, background .25s; }
</style>
<script>
(function() {
  var section = document.getElementById('contacto');
  if (!section) return;
  var io = new IntersectionObserver(function(entries) {
    entries.forEach(function(e) {
      document.body.classList.toggle('rc-at-contact', e.isIntersecting);
    });
  }, { threshold: 0.25 });
  io.observe(section);
})();
</script>

<?php wp_footer(); ?>
</body>
</html>
