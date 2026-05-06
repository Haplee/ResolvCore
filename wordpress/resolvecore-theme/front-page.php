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
  <meta property="og:url" content="<?php echo home_url('/'); ?>">
  <meta property="og:image" content="<?php echo get_template_directory_uri(); ?>/og-image.png">
  <meta property="og:site_name" content="ResolveCore">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="ResolveCore">
  <meta name="twitter:description" content="Plataforma cross-platform de mantenimiento y optimización para Windows, Linux y Android.">

  <!-- Canonical -->
  <link rel="canonical" href="<?php echo home_url('/'); ?>">

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
      display: flex; align-items: center;
      padding: 80px 2.5rem 0; overflow: hidden;
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
      position: relative; max-width: 750px; z-index: 2;
    }
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
      margin-top: 4rem; display: flex; gap: 3rem;
      padding-top: 2rem; border-top: 1px solid var(--rc-border);
      animation: rcFadeUp .8s .4s ease both;
    }
    .rc-stat-num {
      font-family: var(--rc-mono); font-size: 1.9rem;
      font-weight: 700; color: var(--rc-accent);
    }
    .rc-stat-label { font-size: 12px; color: var(--rc-muted); margin-top: 3px; }
    .rc-hero-scroll {
      position: absolute; bottom: 2.5rem; left: 50%; transform: translateX(-50%);
      display: flex; flex-direction: column; align-items: center; gap: 8px;
      font-family: var(--rc-mono); font-size: 10px; color: var(--rc-muted);
      letter-spacing: .1em; animation: rcFadeUp .8s .6s ease both;
    }
    .rc-hero-scroll-line {
      width: 1px; height: 40px; background: linear-gradient(to bottom, var(--rc-accent), transparent);
      animation: rcScrollLine 2s ease-in-out infinite;
    }
    @keyframes rcScrollLine {
      0%, 100% { transform: scaleY(1); opacity: 1; }
      50% { transform: scaleY(0.5); opacity: 0.4; }
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
    .rc-demo-controls { display: flex; flex-direction: column; gap: .75rem; margin-bottom: 1.5rem; }
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
    .tl-ok   { color: #28c840; display: block; }
    .tl-warn { color: #febc2e; display: block; }
    .tl-err  { color: #ff5f57; display: block; }
    .tl-dim  { color: var(--rc-muted); display: block; }
    .tl-info { color: var(--rc-accent2); display: block; }
    .tl-cmd  { display: block; }
    .rc-cursor { display: inline-block; width: 7px; height: 13px; background: var(--rc-accent); animation: rcBlink 1s step-end infinite; vertical-align: middle; margin-left: 2px; }
    @keyframes rcBlink { 50% { opacity: 0; } }
    #rc-term-output { transition: opacity .3s; }
    .rc-demo-progress { margin-top: 1.25rem; }
    .rc-demo-progress-label { font-family: var(--rc-mono); font-size: 11px; color: var(--rc-muted); margin-bottom: 6px; display: flex; justify-content: space-between; }
    .rc-demo-bar { height: 3px; background: var(--rc-border2); position: relative; overflow: hidden; }
    .rc-demo-bar-fill { height: 100%; background: var(--rc-accent); width: 0%; transition: width 2s ease; }

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
    .rc-vuln-fix { font-family: var(--rc-mono); font-size: 10px; color: var(--rc-accent); cursor: pointer; padding: 3px 8px; border: 1px solid rgba(0,229,160,.2); transition: all .2s; }
    .rc-vuln-fix:hover { background: rgba(0,229,160,.1); }
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
      .rc-hero-stats { gap: 1.5rem; flex-wrap: wrap; }
      .rc-nav-links { display: none; }
      .rc-nav-cta { display: none; }
      .rc-hamburger { display: flex; }
      .rc-form-row { grid-template-columns: 1fr; }
      .rc-download-github { flex-direction: column; }
      .rc-flow { justify-content: center; gap: .25rem; }
      .rc-flow-step { min-width: 90px; flex: 0 0 calc(33% - .5rem); }
      .rc-flow-arrow { display: none; }
    }
  </style>
</head>
<body <?php body_class(); ?>>
<?php wp_body_open(); ?>

<!-- SCROLL PROGRESS -->
<div id="rc-progress"></div>

<!-- BACK TO TOP -->
<button id="rc-back-top" onclick="window.scrollTo({top:0,behavior:'smooth'})">↑</button>

<!-- ==================== NAV ==================== -->
<nav class="rc-nav" id="rc-nav">
  <a href="<?php echo home_url('/'); ?>" class="rc-nav-logo" aria-label="ResolveCore — inicio">
    <img src="<?php echo get_template_directory_uri(); ?>/assets/logo/resolvcore-logo-dark.png"
         alt="ResolveCore — Solución a tus problemas informáticos"
         class="rc-nav-logo-img">
  </a>
  <ul class="rc-nav-links">
    <li><a href="#servicios">Servicios</a></li>
    <li><a href="#como-funciona">Proceso</a></li>
    <li><a href="#precios">Precios</a></li>
    <li><a href="#contacto">Contacto</a></li>
    <li><a href="<?php echo esc_url( home_url('/docs/') ); ?>">Docs</a></li>
  </ul>
  <a href="#contacto" class="rc-nav-cta">SOLICITAR SOPORTE</a>
  <button class="rc-hamburger" id="rc-hamburger" aria-label="Menú">
    <span></span><span></span><span></span>
  </button>
</nav>

<!-- MOBILE MENU -->
<div class="rc-mobile-menu" id="rc-mobile-menu">
  <a href="#servicios" onclick="closeMobileMenu()">Servicios</a>
  <a href="#como-funciona" onclick="closeMobileMenu()">Proceso</a>
  <a href="#precios" onclick="closeMobileMenu()">Precios</a>
  <a href="#contacto" onclick="closeMobileMenu()">Contacto</a>
  <a href="<?php echo esc_url( home_url('/docs/') ); ?>">Docs</a>
</div>

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
      <div><div class="rc-stat-num">&lt;2h</div><div class="rc-stat-label">Tiempo de respuesta</div></div>
      <div><div class="rc-stat-num" data-count="500">0</div><div class="rc-stat-label">CVEs en base de datos</div></div>
      <div><div class="rc-stat-num">Windows · Linux · Android</div><div class="rc-stat-label">Plataformas soportadas</div></div>
    </div>
  </div>
  <div class="rc-hero-scroll">
    <span>SCROLL</span>
    <div class="rc-hero-scroll-line"></div>
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
<div class="rc-section" id="servicios">
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
      ['⬡','05','Panel multiplataforma','Gestiona Windows, Linux y Android desde una única interfaz con historial de análisis y seguimiento continuo del estado del equipo.',['Panel unificado multi-dispositivo','Histórico de diagnósticos','Exportación de reportes']],
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
</div>

<hr class="rc-section-divider">

<!-- ==================== CÓMO FUNCIONA ==================== -->
<div class="rc-section" id="como-funciona">
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
</div>

<hr class="rc-section-divider">

<!-- ==================== DEMO INTERACTIVA ==================== -->
<div class="rc-section" id="demo">
  <div class="rc-reveal">
    <div class="rc-section-label">// DEMO INTERACTIVA</div>
    <h2 class="rc-section-title">Prueba el diagnóstico</h2>
    <p class="rc-section-desc">Selecciona un módulo para ver cómo actúa ResolveCore en tiempo real.</p>
  </div>
  <div class="rc-demo-layout rc-reveal">
    <div>
      <div class="rc-demo-controls">
        <button class="rc-demo-btn active" onclick="runDemo('diagnostico',this)">
          <div class="rc-demo-btn-dot"></div> Diagnóstico completo
        </button>
        <button class="rc-demo-btn" onclick="runDemo('vulnerabilidades',this)">
          <div class="rc-demo-btn-dot"></div> Escaneo de vulnerabilidades
        </button>
        <button class="rc-demo-btn" onclick="runDemo('hardware',this)">
          <div class="rc-demo-btn-dot"></div> Proyección de hardware
        </button>
        <button class="rc-demo-btn" onclick="runDemo('optimizacion',this)">
          <div class="rc-demo-btn-dot"></div> Optimización del sistema
        </button>
      </div>
      <div class="rc-demo-progress">
        <div class="rc-demo-progress-label"><span id="rc-prog-label">Listo</span><span id="rc-prog-pct">—</span></div>
        <div class="rc-demo-bar"><div class="rc-demo-bar-fill" id="rc-demo-bar"></div></div>
      </div>
      <div class="rc-vuln-section" style="margin-top:1.25rem" id="rc-vuln-table">
        <div class="rc-vuln-header">VULNERABILIDADES DETECTADAS <span class="rc-vuln-status">LIVE</span></div>
        <div class="rc-vuln-row"><span class="rc-vuln-sev sev-crit">CRÍTICO</span><span class="rc-vuln-name">CVE-2024-3049 — Kernel privilege escalation</span><span class="rc-vuln-fix" role="button" tabindex="0" aria-label="Reparar CVE-2024-3049" onclick="fixVuln(this)" onkeydown="if(event.key==='Enter'||event.key===' ')fixVuln(this)">[REPARAR]</span></div>
        <div class="rc-vuln-row"><span class="rc-vuln-sev sev-high">ALTO</span><span class="rc-vuln-name">CVE-2024-1871 — SMB remote code exec</span><span class="rc-vuln-fix" role="button" tabindex="0" aria-label="Reparar CVE-2024-1871" onclick="fixVuln(this)" onkeydown="if(event.key==='Enter'||event.key===' ')fixVuln(this)">[REPARAR]</span></div>
        <div class="rc-vuln-row"><span class="rc-vuln-sev sev-med">MEDIO</span><span class="rc-vuln-name">CVE-2023-4911 — glibc buffer overflow</span><span class="rc-vuln-fix" role="button" tabindex="0" aria-label="Aplicar parche CVE-2023-4911" onclick="fixVuln(this)" onkeydown="if(event.key==='Enter'||event.key===' ')fixVuln(this)">[PARCHE]</span></div>
        <div class="rc-vuln-row"><span class="rc-vuln-sev sev-med">MEDIO</span><span class="rc-vuln-name">CVE-2023-2650 — OpenSSL DoS</span><span class="rc-vuln-fix" role="button" tabindex="0" aria-label="Aplicar parche CVE-2023-2650" onclick="fixVuln(this)" onkeydown="if(event.key==='Enter'||event.key===' ')fixVuln(this)">[PARCHE]</span></div>
      </div>
    </div>
    <div class="rc-terminal">
      <div class="rc-term-header">
        <div class="rc-term-dot td1"></div><div class="rc-term-dot td2"></div><div class="rc-term-dot td3"></div>
        <span class="rc-term-title" id="rc-term-title">resolvecore — diagnóstico</span>
      </div>
      <div id="rc-term-output">
        <span class="tl-cmd"><span class="tl-p">rc@system:~$</span> resolvecore --scan --full</span>
        <span class="tl-dim">Iniciando análisis del sistema...</span>
        <span class="tl-ok">✓ CPU: Intel Core i7-12700H — 8% carga</span>
        <span class="tl-ok">✓ RAM: 16GB DDR5 — 42% en uso</span>
        <span class="tl-warn">⚠ SSD: 87% lleno — acción recomendada</span>
        <span class="tl-ok">✓ Temperatura: 54°C — nominal</span>
        <span class="tl-dim">─────────────────────────────</span>
        <span class="tl-info">→ 2 vulnerabilidades críticas encontradas</span>
        <span class="tl-ok">✓ Análisis completado en 3.2s</span>
        <span class="tl-cmd"><span class="tl-p">rc@system:~$</span> <span class="rc-cursor"></span></span>
      </div>
    </div>
  </div>
</div>

<hr class="rc-section-divider">

<!-- ==================== CTA ==================== -->
<div class="rc-section" id="soporte">
  <div class="rc-cta-band rc-reveal">
    <div>
      <div class="rc-section-label">// EMPEZAR</div>
      <h2 class="rc-section-title" style="margin-bottom:.75rem">¿Tienes un problema con tu equipo?</h2>
      <p style="color:var(--rc-muted);max-width:480px;margin-bottom:2rem;line-height:1.7">
        Cuéntanos qué ocurre. Un técnico analizará tu sistema en remoto, aplicará la solución y te entregará un informe técnico completo.
      </p>
      <div style="display:flex;gap:1rem;flex-wrap:wrap">
        <a href="#contacto" class="rc-btn-primary">SOLICITAR SOPORTE →</a>
        <a href="#precios" class="rc-btn-outline">VER PLANES</a>
      </div>
    </div>
    <div class="rc-cta-band-stats">
      <div class="rc-cta-stat">
        <div class="rc-stat-num">&lt;2h</div>
        <div class="rc-stat-label">Tiempo de respuesta</div>
      </div>
      <div class="rc-cta-stat">
        <div class="rc-stat-num">500+</div>
        <div class="rc-stat-label">CVEs analizados</div>
      </div>
      <div class="rc-cta-stat">
        <div class="rc-stat-num">3</div>
        <div class="rc-stat-label">Plataformas</div>
      </div>
    </div>
  </div>
</div>

<hr class="rc-section-divider">

<!-- ==================== PRECIOS ==================== -->
<div class="rc-section" id="precios">
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
      <div style="margin-top:1.5rem"><a href="#descargar" class="rc-btn-outline" style="width:100%;justify-content:center;font-size:11px;padding:10px">DESCARGAR GRATIS</a></div>
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
      <div class="rc-pricing-feature"><span class="pf-check">■</span> Panel multiplataforma</div>
      <div style="margin-top:1.5rem"><a href="#contacto" class="rc-btn-outline" style="width:100%;justify-content:center;font-size:11px;padding:10px;display:flex">CONTACTAR</a></div>
    </div>
  </div>
</div>

<hr class="rc-section-divider">

<!-- ==================== CONTACTO ==================== -->
<div class="rc-section" id="contacto">
  <div class="rc-reveal">
    <div class="rc-section-label">// CONTACTO</div>
    <h2 class="rc-section-title">Escríbenos</h2>
    <p class="rc-section-desc">¿Necesitas soporte técnico? Cuéntanos el problema y te respondemos en menos de 2 horas.</p>
  </div>
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
</div>

<!-- ==================== FOOTER ==================== -->
<div class="rc-footer-outer">
  <footer class="rc-footer">
    <div>
      <div class="rc-footer-logo">
        <img src="<?php echo get_template_directory_uri(); ?>/assets/logo/resolvcore-logo-dark.png"
             alt="ResolveCore"
             class="rc-footer-logo-img">
      </div>
      <div class="rc-footer-copy">© <?php echo date('Y'); ?> Francisco Vidal Mateo · TFG ASIR</div>
    </div>
    <ul class="rc-footer-links">
      <li><a href="<?php echo esc_url( home_url('/docs/') ); ?>">Docs</a></li>
      <li><a href="#servicios">Servicios</a></li>
      <li><a href="#precios">Precios</a></li>
      <li><a href="https://github.com/Haplee/ResolveCore" target="_blank" rel="noopener noreferrer" aria-label="ResolveCore en GitHub (abre en nueva pestaña)">GitHub</a></li>
      <li><a href="#contacto">Contacto</a></li>
    </ul>
    <div class="rc-footer-slogan">Solución a tus problemas informáticos.</div>
  </footer>
</div>

<!-- ==================== JAVASCRIPT ==================== -->
<script>
/* --- NAV scroll --- */
const nav = document.getElementById('rc-nav');
const backTop = document.getElementById('rc-back-top');
const progress = document.getElementById('rc-progress');
window.addEventListener('scroll', () => {
  const s = window.scrollY;
  if (s > 60) nav.classList.add('scrolled'); else nav.classList.remove('scrolled');
  if (s > 400) backTop.classList.add('visible'); else backTop.classList.remove('visible');
  const h = document.documentElement.scrollHeight - window.innerHeight;
  progress.style.width = (s / h * 100) + '%';
});

/* --- Mobile menu --- */
const hamburger = document.getElementById('rc-hamburger');
const mobileMenu = document.getElementById('rc-mobile-menu');
hamburger.addEventListener('click', () => mobileMenu.classList.toggle('open'));
function closeMobileMenu() { mobileMenu.classList.remove('open'); }

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

/* --- Particles --- */
const particleContainer = document.getElementById('rc-particles');
for (let i = 0; i < 18; i++) {
  const p = document.createElement('div');
  p.className = 'rc-particle';
  p.style.left = Math.random() * 100 + '%';
  p.style.animationDuration = (8 + Math.random() * 12) + 's';
  p.style.animationDelay = (Math.random() * 10) + 's';
  p.style.width = p.style.height = (1 + Math.random() * 2) + 'px';
  particleContainer.appendChild(p);
}

/* --- Demo interactiva --- */
const demoScenarios = {
  diagnostico: {
    title: 'resolvecore — diagnóstico',
    lines: [
      ['cmd', 'rc@system:~$ resolvecore --scan --full'],
      ['dim', 'Iniciando análisis del sistema...'],
      ['ok',  '✓ CPU: Intel Core i7-12700H — 8% carga'],
      ['ok',  '✓ RAM: 16GB DDR5 — 42% en uso'],
      ['warn','⚠ SSD: 87% lleno — acción recomendada'],
      ['ok',  '✓ Temperatura: 54°C — nominal'],
      ['dim', '─────────────────────────────'],
      ['info','→ 2 vulnerabilidades críticas encontradas'],
      ['ok',  '✓ Análisis completado en 3.2s'],
    ],
    label: 'Ejecutando diagnóstico...'
  },
  vulnerabilidades: {
    title: 'resolvecore — vulnerabilidades',
    lines: [
      ['cmd', 'rc@system:~$ resolvecore --vuln-scan'],
      ['dim', 'Cargando base de datos CVE...'],
      ['info','→ Comparando con 500+ entradas conocidas'],
      ['err', '✗ CVE-2024-3049 — Kernel priv. escalation [CRÍTICO]'],
      ['warn','⚠ CVE-2024-1871 — SMB remote code exec [ALTO]'],
      ['warn','⚠ CVE-2023-4911 — glibc buffer overflow [MEDIO]'],
      ['warn','⚠ CVE-2023-2650 — OpenSSL DoS [MEDIO]'],
      ['dim', '─────────────────────────────'],
      ['info','→ 4 vulnerabilidades encontradas'],
      ['ok',  '✓ Parches disponibles para todas'],
    ],
    label: 'Escaneando vulnerabilidades...'
  },
  hardware: {
    title: 'resolvecore — hardware',
    lines: [
      ['cmd', 'rc@system:~$ resolvecore --hardware-check'],
      ['dim', 'Leyendo datos S.M.A.R.T...'],
      ['ok',  '✓ SSD Samsung 970 EVO — 94% salud'],
      ['warn','⚠ Temperatura SSD: 61°C — elevada'],
      ['ok',  '✓ RAM: Sin errores detectados'],
      ['ok',  '✓ Batería: 91% capacidad original'],
      ['dim', '─────────────────────────────'],
      ['info','→ Vida útil estimada SSD: ~18 meses'],
      ['info','→ Vida útil estimada batería: ~24 meses'],
      ['ok',  '✓ Informe guardado en /reports/hw_2024.pdf'],
    ],
    label: 'Analizando hardware...'
  },
  optimizacion: {
    title: 'resolvecore — optimización',
    lines: [
      ['cmd', 'rc@system:~$ resolvecore --optimize --safe'],
      ['dim', 'Analizando archivos temporales...'],
      ['info','→ 4.2 GB en archivos temporales detectados'],
      ['info','→ 23 procesos de inicio innecesarios'],
      ['ok',  '✓ Limpieza de caché completada — 2.1 GB liberados'],
      ['ok',  '✓ Archivos temporales eliminados — 1.8 GB'],
      ['ok',  '✓ 12 procesos de inicio desactivados'],
      ['dim', '─────────────────────────────'],
      ['ok',  '✓ Sistema optimizado — +18% rendimiento estimado'],
    ],
    label: 'Optimizando sistema...'
  }
};

let demoRunning = false;
function runDemo(scenario, btn) {
  if (demoRunning) return;
  document.querySelectorAll('.rc-demo-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  const data = demoScenarios[scenario];
  document.getElementById('rc-term-title').textContent = data.title;
  document.getElementById('rc-prog-label').textContent = data.label;
  const bar = document.getElementById('rc-demo-bar');
  bar.style.width = '0%';
  const output = document.getElementById('rc-term-output');
  output.style.opacity = '0';
  setTimeout(() => {
    output.innerHTML = '';
    bar.style.width = '100%';
    demoRunning = true;
    data.lines.forEach((line, i) => {
      setTimeout(() => {
        const span = document.createElement('span');
        if (line[0] === 'cmd') {
          span.className = 'tl-cmd';
          span.innerHTML = '<span class="tl-p">' + line[1].split('$')[0] + '$</span>' + line[1].split('$')[1];
        } else {
          span.className = 'tl-' + line[0];
          span.textContent = line[1];
        }
        output.appendChild(span);
        if (i === data.lines.length - 1) {
          const cursor = document.createElement('span');
          cursor.className = 'tl-cmd';
          cursor.innerHTML = '<span class="tl-p">rc@system:~$</span> <span class="rc-cursor"></span>';
          output.appendChild(cursor);
          document.getElementById('rc-prog-label').textContent = 'Completado';
          document.getElementById('rc-prog-pct').textContent = '100%';
          demoRunning = false;
        }
      }, i * 280);
    });
    output.style.opacity = '1';
  }, 350);
}

/* --- Fix vulnerability buttons --- */
function fixVuln(el) {
  if (el.classList.contains('fixed')) return;
  el.textContent = '[APLICANDO...]';
  el.style.opacity = '0.5';
  setTimeout(() => {
    el.textContent = '[✓ REPARADO]';
    el.classList.add('fixed');
    el.style.opacity = '1';
    el.closest('.rc-vuln-row').style.opacity = '0.4';
  }, 1200);
}

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
          link.style.cssText = 'color:var(--rc-accent);margin-left:6px;font-family:var(--rc-mono);font-size:11px;';
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

<?php wp_footer(); ?>
</body>
</html>
