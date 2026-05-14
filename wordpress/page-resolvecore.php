<?php
/**
 * Template Name: ResolveCore Landing
 * Template Post Type: page
 *
 * Página personalizada para ResolveCore.
 * Uso: En WordPress > Páginas > (tu página) > Atributos > Plantilla > "ResolveCore Landing"
 *
 * Compatible con Twenty Twenty-Four y temas basados en FSE.
 * Coloca este archivo en: wp-content/themes/TU-TEMA/page-resolvecore.php
 *
 * @author Francisco Vidal Mateo
 */

// No mostrar barra lateral, header ni footer del tema
?>
<!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
  <meta charset="<?php bloginfo('charset'); ?>">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="ResolveCore — Solución a tus problemas informáticos. Plataforma cross-platform de mantenimiento y optimización.">
  <meta name="theme-color" content="#0a0c10">
  <meta name="color-scheme" content="dark">
  <link rel="canonical" href="<?php echo esc_url( get_permalink() ?: home_url( '/' ) ); ?>">
  <link rel="preconnect" href="https://fonts.googleapis.com" crossorigin>
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <?php wp_head(); ?>
  <style>
    /* ============================================================
       RESOLVECORE — ESTILOS GLOBALES
       ============================================================ */
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    html { scroll-behavior: smooth; scroll-padding-top: 80px; }

    :root {
      --rc-bg:       #0a0c10;
      --rc-bg2:      #06080b;
      --rc-surface:  #111318;
      --rc-surface2: #1a1d24;
      --rc-border:   rgba(255,255,255,0.07);
      --rc-border2:  rgba(255,255,255,0.13);
      --rc-accent:   #00e5a0;
      --rc-accent2:  #0099ff;
      --rc-warn:     #ff6b35;
      --rc-text:     #e8eaf0;
      --rc-muted:    #7a7f8e;
      --rc-mono:     'Space Mono', monospace;
      --rc-sans:     'DM Sans', sans-serif;
      --rc-grad:     linear-gradient(135deg, #00e5a0 0%, #0099ff 100%);
      --rc-shadow:   0 20px 60px -20px rgba(0,229,160,.25);
    }

    body.rc-page {
      background: var(--rc-bg);
      color: var(--rc-text);
      font-family: var(--rc-sans);
      font-size: 16px;
      line-height: 1.6;
      overflow-x: hidden;
    }

    /* Custom scrollbar */
    ::-webkit-scrollbar { width: 10px; height: 10px; }
    ::-webkit-scrollbar-track { background: var(--rc-bg2); }
    ::-webkit-scrollbar-thumb {
      background: var(--rc-surface2);
      border-radius: 5px; border: 2px solid var(--rc-bg2);
    }
    ::-webkit-scrollbar-thumb:hover { background: var(--rc-border2); }

    /* Selection */
    ::selection { background: var(--rc-accent); color: #000; }

    /* Animations */
    @keyframes rcFadeUp {
      from { opacity: 0; transform: translateY(24px); }
      to   { opacity: 1; transform: translateY(0); }
    }
    @keyframes rcFloat {
      0%,100% { transform: translateY(0); }
      50%     { transform: translateY(-8px); }
    }
    @keyframes rcScroll {
      0%   { transform: translateY(0);   opacity: 1; }
      100% { transform: translateY(12px); opacity: 0; }
    }

    /* a11y */
    :focus-visible { outline: 2px solid var(--rc-accent); outline-offset: 3px; border-radius: 2px; }
    .rc-skip-link {
      position: absolute; left: -9999px; top: 8px;
      background: var(--rc-accent); color: #000; font-family: var(--rc-mono);
      font-size: 12px; padding: 10px 16px; z-index: 99999; text-decoration: none;
    }
    .rc-skip-link:focus { left: 12px; }
    @media (prefers-reduced-motion: reduce) {
      *, *::before, *::after {
        animation-duration: 0.001ms !important;
        animation-iteration-count: 1 !important;
        transition-duration: 0.001ms !important;
        scroll-behavior: auto !important;
      }
    }

    /* ---- NAV ---- */
    .rc-nav {
      position: sticky; top: 0; z-index: 100;
      background: rgba(10,12,16,0.92);
      backdrop-filter: blur(12px);
      border-bottom: 1px solid var(--rc-border);
      padding: 0 2rem; height: 60px;
      display: flex; align-items: center; justify-content: space-between;
    }
    .rc-nav-logo {
      font-family: var(--rc-mono); font-size: 15px; font-weight: 700;
      color: var(--rc-accent); letter-spacing: .1em; text-decoration: none;
    }
    .rc-nav-logo span { color: var(--rc-muted); }
    .rc-nav ul { display: flex; gap: 2rem; list-style: none; }
    .rc-nav ul a {
      font-size: 13px; color: var(--rc-muted); text-decoration: none;
      font-weight: 500; letter-spacing: .03em; transition: color .2s;
    }
    .rc-nav ul a:hover { color: var(--rc-text); }
    .rc-nav-cta {
      font-family: var(--rc-mono); font-size: 12px;
      color: var(--rc-accent); border: 1px solid var(--rc-accent);
      padding: 7px 16px; text-decoration: none; letter-spacing: .05em;
      transition: all .2s;
    }
    .rc-nav-cta:hover { background: var(--rc-accent); color: #000; }

    /* ---- HERO ---- */
    .rc-hero {
      position: relative; min-height: 88vh;
      display: flex; align-items: center; justify-content: center;
      padding: 4rem 2rem; overflow: hidden;
      text-align: center;
    }
    .rc-hero-grid {
      position: absolute; inset: 0;
      background-image:
        linear-gradient(rgba(0,229,160,.03) 1px, transparent 1px),
        linear-gradient(90deg, rgba(0,229,160,.03) 1px, transparent 1px);
      background-size: 60px 60px;
      animation: rcGridScroll 30s linear infinite;
    }
    @keyframes rcGridScroll { to { transform: translateY(60px); } }
    .rc-hero-glow {
      position: absolute; width: 600px; height: 600px; border-radius: 50%;
      background: radial-gradient(circle, rgba(0,229,160,.06) 0%, transparent 70%);
      top: 50%; left: 50%; transform: translate(-50%, -50%); pointer-events: none;
    }
    .rc-hero-content {
      position: relative; max-width: 760px; width: 100%;
      margin: 0 auto; z-index: 2;
    }
    .rc-badge {
      display: inline-flex; align-items: center; gap: 8px;
      font-family: var(--rc-mono); font-size: 11px;
      color: var(--rc-accent);
      border: 1px solid rgba(0,229,160,.25);
      padding: 5px 12px; letter-spacing: .08em; margin-bottom: 2rem;
      background: rgba(0,229,160,.05);
    }
    .rc-badge::before {
      content: ''; width: 6px; height: 6px; border-radius: 50%;
      background: var(--rc-accent); animation: rcPulse 2s infinite;
    }
    @keyframes rcPulse { 50% { opacity: .3; } }
    .rc-hero h1 {
      font-family: var(--rc-mono);
      font-size: clamp(2.4rem, 5.5vw, 4.4rem);
      font-weight: 700; line-height: 1.05;
      margin-bottom: 1.25rem; letter-spacing: -.03em;
    }
    .rc-hero h1 .accent {
      background: var(--rc-grad);
      -webkit-background-clip: text;
      background-clip: text;
      color: transparent;
      display: inline-block;
    }
    .rc-hero h1 .dim    { color: var(--rc-muted); }
    .rc-hero-content > * { animation: rcFadeUp .8s cubic-bezier(.4,0,.2,1) backwards; }
    .rc-hero-content > *:nth-child(1) { animation-delay: .05s; }
    .rc-hero-content > *:nth-child(2) { animation-delay: .15s; }
    .rc-hero-content > *:nth-child(3) { animation-delay: .25s; }
    .rc-hero-content > *:nth-child(4) { animation-delay: .35s; }
    .rc-hero-content > *:nth-child(5) { animation-delay: .45s; }
    .rc-hero-sub {
      font-size: 1.1rem; color: var(--rc-muted);
      max-width: 560px; margin: 0 auto 2.5rem;
      font-weight: 300; line-height: 1.7;
    }
    .rc-hero-actions {
      display: flex; gap: 1rem; flex-wrap: wrap;
      justify-content: center;
    }
    .rc-btn-primary {
      font-family: var(--rc-mono); font-size: 12px; letter-spacing: .06em;
      color: #000; background: var(--rc-grad);
      border: none; padding: 14px 32px; cursor: pointer; font-weight: 700;
      transition: all .25s ease; text-decoration: none; display: inline-block;
      box-shadow: var(--rc-shadow);
      position: relative; overflow: hidden;
    }
    .rc-btn-primary:hover {
      transform: translateY(-2px);
      box-shadow: 0 24px 70px -18px rgba(0,229,160,.45);
    }
    .rc-btn-outline {
      font-family: var(--rc-mono); font-size: 12px; letter-spacing: .06em;
      color: var(--rc-text); background: transparent;
      border: 1px solid var(--rc-border2);
      padding: 14px 32px; cursor: pointer; transition: all .25s ease;
      text-decoration: none; display: inline-block;
    }
    .rc-btn-outline:hover {
      border-color: var(--rc-accent); color: var(--rc-accent);
      transform: translateY(-2px);
    }
    .rc-hero-stats {
      margin-top: 4rem;
      display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
      gap: 1.5rem 2rem;
      padding-top: 2rem; border-top: 1px solid var(--rc-border);
      text-align: center;
    }
    .rc-stat-num {
      font-family: var(--rc-mono); font-size: 2rem; font-weight: 700;
      background: var(--rc-grad);
      -webkit-background-clip: text;
      background-clip: text;
      color: transparent;
    }
    .rc-stat-label { font-size: 12px; color: var(--rc-muted); margin-top: 4px; letter-spacing: .03em; }

    /* Scroll indicator */
    .rc-scroll-hint {
      position: absolute; bottom: 1.5rem; left: 50%; transform: translateX(-50%);
      display: flex; flex-direction: column; align-items: center; gap: 6px;
      font-family: var(--rc-mono); font-size: 10px; letter-spacing: .15em;
      color: var(--rc-muted); pointer-events: none;
    }
    .rc-scroll-hint::after {
      content: ''; width: 1px; height: 20px;
      background: var(--rc-accent); animation: rcScroll 1.6s ease-in-out infinite;
    }

    /* ---- PLATAFORMAS ---- */
    .rc-platforms {
      background: var(--rc-surface);
      border-top: 1px solid var(--rc-border);
      border-bottom: 1px solid var(--rc-border);
      padding: 1.5rem 2rem;
    }
    .rc-platforms-inner {
      max-width: 1100px; margin: 0 auto;
      display: flex; align-items: center; justify-content: center;
      gap: 2rem 3rem; flex-wrap: wrap;
    }
    .rc-plat-label {
      font-family: var(--rc-mono); font-size: 11px;
      color: var(--rc-muted); letter-spacing: .08em;
    }
    .rc-plat-items { display: flex; gap: 2.5rem; flex-wrap: wrap; align-items: center; }
    .rc-plat-item {
      display: flex; align-items: center; gap: 8px;
      font-size: 13px; color: var(--rc-muted); font-weight: 500;
    }
    .rc-plat-icon {
      width: 28px; height: 28px; border-radius: 4px;
      display: flex; align-items: center; justify-content: center; font-size: 14px;
    }
    .pi-win { background: rgba(0,120,212,.15); color: #0078d4; }
    .pi-lin { background: rgba(255,165,0,.12);  color: #ff9f00; }
    .pi-mac { background: rgba(255,255,255,.08); color: #f5f5f7; }
    .pi-and { background: rgba(61,220,132,.12); color: #3ddc84; }

    /* ---- SECCIONES BASE ---- */
    .rc-section {
      padding: 5rem 2rem;
      max-width: 1100px; margin: 0 auto;
    }
    .rc-section-header {
      text-align: center; margin-bottom: 3rem;
    }
    .rc-section-label {
      font-family: var(--rc-mono); font-size: 11px;
      letter-spacing: .12em; color: var(--rc-accent); margin-bottom: .75rem;
      text-align: center;
    }
    .rc-section-title {
      font-family: var(--rc-mono);
      font-size: clamp(1.6rem, 3vw, 2.2rem);
      font-weight: 700; margin-bottom: 1rem; line-height: 1.2;
      text-align: center;
    }
    .rc-section-desc {
      color: var(--rc-muted); max-width: 580px;
      font-size: 1rem; margin: 0 auto 3rem;
      text-align: center;
    }

    /* ---- SERVICIOS ---- */
    .rc-services-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 1.25rem;
    }
    .rc-service-card {
      background: var(--rc-surface);
      border: 1px solid var(--rc-border);
      border-radius: 12px;
      padding: 2rem 1.75rem;
      transition: transform .3s ease, border-color .3s ease, box-shadow .3s ease;
      position: relative; overflow: hidden;
    }
    .rc-service-card::before {
      content: ''; position: absolute; inset: 0;
      background: radial-gradient(circle at top right, rgba(0,229,160,.08), transparent 60%);
      opacity: 0; transition: opacity .3s ease; pointer-events: none;
    }
    .rc-service-card:hover {
      transform: translateY(-4px);
      border-color: rgba(0,229,160,.3);
      box-shadow: 0 20px 40px -20px rgba(0,229,160,.2);
    }
    .rc-service-card:hover::before { opacity: 1; }
    .rc-service-icon {
      width: 48px; height: 48px;
      border: 1px solid var(--rc-border2);
      border-radius: 10px;
      display: flex; align-items: center; justify-content: center;
      margin-bottom: 1.25rem; font-size: 20px;
      background: var(--rc-bg2);
      color: var(--rc-accent);
      transition: all .3s ease;
    }
    .rc-service-card:hover .rc-service-icon {
      border-color: var(--rc-accent);
      transform: scale(1.05) rotate(-3deg);
    }
    .rc-service-tag {
      font-family: var(--rc-mono); font-size: 10px;
      letter-spacing: .08em; color: var(--rc-accent); margin-bottom: .5rem;
      font-weight: 700;
    }
    .rc-service-title {
      font-family: var(--rc-mono); font-size: 1.05rem; font-weight: 700;
      color: var(--rc-text); margin-bottom: .75rem; line-height: 1.3;
    }
    .rc-service-desc {
      font-size: .9rem; color: var(--rc-muted); line-height: 1.65;
    }
    .rc-service-features {
      margin-top: 1.25rem; padding-top: 1.25rem;
      border-top: 1px dashed var(--rc-border);
      display: flex; flex-direction: column; gap: 8px;
    }
    .rc-sf-item {
      font-size: 12px; color: var(--rc-text);
      display: flex; align-items: center; gap: 10px;
    }
    .rc-sf-item::before {
      content: '✓'; font-family: var(--rc-mono); font-weight: 700;
      color: var(--rc-accent); flex-shrink: 0; font-size: 11px;
    }

    /* ---- PIPELINE 7 FASES ---- */
    .rc-pipeline {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
      gap: 1rem;
      counter-reset: pipeline;
      margin-top: 1rem;
    }
    .rc-pipe-step {
      counter-increment: pipeline;
      background: var(--rc-surface);
      border: 1px solid var(--rc-border);
      border-radius: 10px;
      padding: 1.5rem 1rem 1.25rem;
      text-align: center; position: relative;
      transition: all .3s ease;
    }
    .rc-pipe-step:hover {
      border-color: var(--rc-accent);
      transform: translateY(-3px);
    }
    .rc-pipe-step::before {
      content: counter(pipeline, decimal-leading-zero);
      position: absolute; top: -14px; left: 50%; transform: translateX(-50%);
      font-family: var(--rc-mono); font-size: 11px; font-weight: 700;
      background: var(--rc-grad); color: #000;
      padding: 4px 10px; border-radius: 999px; letter-spacing: .05em;
    }
    .rc-pipe-icon { font-size: 22px; margin-bottom: .5rem; color: var(--rc-accent); }
    .rc-pipe-title {
      font-family: var(--rc-mono); font-size: .8rem; font-weight: 700;
      color: var(--rc-text); margin-bottom: .25rem; letter-spacing: .03em;
    }
    .rc-pipe-desc { font-size: 11px; color: var(--rc-muted); line-height: 1.5; }

    /* ---- DIAGNÓSTICO ---- */
    .rc-diag-layout {
      display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
      gap: 2rem; align-items: stretch;
      max-width: 980px; margin: 0 auto;
    }
    .rc-terminal {
      background: #0d0f13; border: 1px solid var(--rc-border2);
      padding: 1.25rem; font-family: var(--rc-mono);
      font-size: 12px; line-height: 1.8;
    }
    .rc-term-header {
      display: flex; align-items: center; gap: 6px;
      margin-bottom: 1rem; padding-bottom: .75rem;
      border-bottom: 1px solid var(--rc-border);
    }
    .rc-term-dot { width: 8px; height: 8px; border-radius: 50%; }
    .td1 { background: #ff5f57; } .td2 { background: #febc2e; } .td3 { background: #28c840; }
    .rc-term-title { margin-left: 6px; font-size: 11px; color: var(--rc-muted); }
    .tl-prompt { color: var(--rc-accent); }
    .tl-ok   { color: #28c840; }
    .tl-warn { color: #febc2e; }
    .tl-err  { color: #ff5f57; }
    .tl-dim  { color: var(--rc-muted); }
    .tl-info { color: var(--rc-accent2); }
    .rc-cursor {
      display: inline-block; width: 7px; height: 13px;
      background: var(--rc-accent);
      animation: rcBlink 1s step-end infinite; vertical-align: middle;
    }
    @keyframes rcBlink { 50% { opacity: 0; } }

    /* ---- VULNERABILIDADES ---- */
    .rc-vuln-section {
      background: var(--rc-surface);
      border: 1px solid var(--rc-border); padding: 1.75rem;
    }
    .rc-vuln-header {
      font-family: var(--rc-mono); font-size: 11px;
      color: var(--rc-muted); letter-spacing: .08em;
      margin-bottom: 1rem;
      display: flex; justify-content: space-between; align-items: center;
    }
    .rc-vuln-status {
      font-size: 10px; color: var(--rc-accent);
      border: 1px solid rgba(0,229,160,.2); padding: 3px 8px;
    }
    .rc-vuln-row {
      display: flex; align-items: center; padding: 10px 0;
      border-bottom: 1px solid var(--rc-border);
      gap: 12px; font-size: 12px;
    }
    .rc-vuln-row:last-child { border-bottom: none; }
    .rc-vuln-sev {
      font-family: var(--rc-mono); font-size: 9px;
      padding: 2px 7px; letter-spacing: .05em; font-weight: 700; flex-shrink: 0;
    }
    .sev-crit { background: rgba(255,107,53,.15); color: var(--rc-warn); border: 1px solid rgba(255,107,53,.25); }
    .sev-high { background: rgba(254,188,46,.1);  color: #febc2e;        border: 1px solid rgba(254,188,46,.2); }
    .sev-med  { background: rgba(0,153,255,.1);   color: var(--rc-accent2); border: 1px solid rgba(0,153,255,.2); }
    .rc-vuln-name { flex: 1; color: var(--rc-text); }
    .rc-vuln-fix  { font-family: var(--rc-mono); font-size: 10px; color: var(--rc-accent); cursor: pointer; }

    /* ---- PRECIOS ---- */
    .rc-pricing-grid {
      display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 1.25rem; margin-top: 2rem;
    }
    .rc-pricing-card {
      background: var(--rc-surface);
      border: 1px solid var(--rc-border);
      border-radius: 14px;
      padding: 2.25rem 1.75rem; position: relative;
      transition: transform .3s ease, border-color .3s ease;
    }
    .rc-pricing-card:hover { transform: translateY(-4px); border-color: var(--rc-border2); }
    .rc-pricing-card.featured {
      background: linear-gradient(180deg, rgba(0,229,160,.05), var(--rc-surface) 60%);
      border-color: rgba(0,229,160,.4);
      box-shadow: 0 30px 80px -30px rgba(0,229,160,.3);
      transform: translateY(-8px);
    }
    .rc-pricing-card.featured:hover { transform: translateY(-12px); }
    .rc-pricing-label {
      font-family: var(--rc-mono); font-size: 10px;
      letter-spacing: .1em; color: var(--rc-muted); margin-bottom: .75rem;
    }
    .rc-pricing-badge {
      font-family: var(--rc-mono); font-size: 9px; color: var(--rc-accent);
      border: 1px solid rgba(0,229,160,.3);
      padding: 2px 8px; letter-spacing: .06em; display: inline-block; margin-bottom: .75rem;
    }
    .rc-pricing-name {
      font-family: var(--rc-mono); font-size: 1.2rem; font-weight: 700; margin-bottom: .5rem;
    }
    .rc-pricing-price {
      margin: 1.25rem 0; display: flex; align-items: baseline; gap: 4px;
    }
    .price-currency { font-family: var(--rc-mono); font-size: 1rem; color: var(--rc-muted); }
    .price-num      { font-family: var(--rc-mono); font-size: 2.2rem; font-weight: 700; color: var(--rc-text); }
    .price-period   { font-size: 12px; color: var(--rc-muted); }
    .rc-pricing-divider { height: 1px; background: var(--rc-border); margin: 1.25rem 0; }
    .rc-pricing-feature {
      font-size: 13px; color: var(--rc-muted);
      padding: 5px 0; display: flex; align-items: center; gap: 8px;
    }
    .pf-check { color: var(--rc-accent); } .pf-none { color: var(--rc-border2); }

    /* ---- FAQ ---- */
    .rc-faq { display: flex; flex-direction: column; gap: 0.75rem; max-width: 760px; margin: 0 auto; }
    .rc-faq-item {
      background: var(--rc-surface); border: 1px solid var(--rc-border);
      border-radius: 10px; padding: 0; transition: border-color .25s;
    }
    .rc-faq-item[open] { border-color: rgba(0,229,160,.3); }
    .rc-faq-item summary {
      padding: 1.1rem 1.4rem; cursor: pointer; font-weight: 600;
      font-family: var(--rc-mono); font-size: .92rem;
      list-style: none; display: flex; justify-content: space-between; align-items: center;
      gap: 1rem; color: var(--rc-text);
    }
    .rc-faq-item summary::-webkit-details-marker { display: none; }
    .rc-faq-item summary::after {
      content: '+'; font-family: var(--rc-mono); color: var(--rc-accent);
      font-size: 1.2rem; transition: transform .25s ease; flex-shrink: 0;
    }
    .rc-faq-item[open] summary::after { transform: rotate(45deg); }
    .rc-faq-item .rc-faq-body {
      padding: 0 1.4rem 1.2rem; color: var(--rc-muted); font-size: .9rem; line-height: 1.7;
    }

    /* ---- CTA FINAL ---- */
    .rc-cta {
      background: linear-gradient(135deg, var(--rc-surface) 0%, var(--rc-bg) 100%);
      border: 1px solid var(--rc-border);
      border-radius: 16px;
      padding: 4rem 2rem;
      text-align: center;
      position: relative; overflow: hidden;
    }
    .rc-cta::before {
      content: ''; position: absolute; inset: 0;
      background: radial-gradient(circle at 50% 0%, rgba(0,229,160,.12), transparent 60%);
      pointer-events: none;
    }
    .rc-cta-title {
      font-family: var(--rc-mono); font-size: clamp(1.5rem, 3vw, 2rem);
      font-weight: 700; margin-bottom: .75rem; letter-spacing: -.02em;
      position: relative;
    }
    .rc-cta-sub { color: var(--rc-muted); margin-bottom: 2rem; max-width: 520px; margin-left: auto; margin-right: auto; position: relative; }
    .rc-cta-actions { display: flex; gap: 1rem; justify-content: center; flex-wrap: wrap; position: relative; }

    /* ---- NAV mobile menu ---- */
    .rc-nav-toggle {
      display: none; background: none; border: none; cursor: pointer;
      width: 32px; height: 32px; flex-direction: column;
      justify-content: center; gap: 5px; padding: 0;
    }
    .rc-nav-toggle span {
      display: block; width: 22px; height: 2px;
      background: var(--rc-text); transition: transform .25s, opacity .25s;
    }
    .rc-nav-toggle[aria-expanded="true"] span:nth-child(1) { transform: translateY(7px) rotate(45deg); }
    .rc-nav-toggle[aria-expanded="true"] span:nth-child(2) { opacity: 0; }
    .rc-nav-toggle[aria-expanded="true"] span:nth-child(3) { transform: translateY(-7px) rotate(-45deg); }

    /* ---- FOOTER ---- */
    .rc-footer {
      border-top: 1px solid var(--rc-border);
      padding: 2.5rem 2rem;
      max-width: 1100px; margin: 0 auto;
      display: flex; justify-content: center;
      align-items: center; flex-wrap: wrap; gap: 1.5rem 2.5rem;
      text-align: center;
    }
    .rc-footer-logo { font-family: var(--rc-mono); font-size: 14px; font-weight: 700; color: var(--rc-accent); }
    .rc-footer-copy { font-size: 12px; color: var(--rc-muted); }
    .rc-footer ul { display: flex; gap: 1.5rem; list-style: none; padding: 0; margin: 0; justify-content: center; flex-wrap: wrap; }
    .rc-footer ul a { font-size: 12px; color: var(--rc-muted); text-decoration: none; }
    .rc-footer ul a:hover { color: var(--rc-text); }

    /* ---- RESPONSIVE ---- */
    @media (max-width: 860px) {
      .rc-nav-toggle { display: flex; }
      .rc-nav ul {
        position: absolute; top: 60px; left: 0; right: 0;
        background: rgba(10,12,16,0.98); backdrop-filter: blur(12px);
        flex-direction: column; gap: 0;
        border-bottom: 1px solid var(--rc-border);
        max-height: 0; overflow: hidden;
        transition: max-height .3s ease;
      }
      .rc-nav ul.is-open { max-height: 320px; }
      .rc-nav ul li { padding: 0; border-top: 1px solid var(--rc-border); }
      .rc-nav ul a { display: block; padding: 1rem 2rem; }
      .rc-nav-cta { display: none; }
    }
    @media (max-width: 640px) {
      .rc-hero        { padding: 3rem 1.25rem; min-height: 78vh; }
      .rc-hero-stats  { gap: 1rem; margin-top: 3rem; }
      .rc-nav         { padding: 0 1rem; }
      .rc-section     { padding: 3.5rem 1.25rem; }
      .rc-stat-num    { font-size: 1.5rem; }
      .rc-cta         { padding: 3rem 1.25rem; }
      .rc-pricing-card.featured { transform: none; }
    }
  </style>
</head>
<body class="rc-page <?php echo esc_attr( implode( ' ', get_body_class() ) ); ?>">
<?php wp_body_open(); ?>

<a class="rc-skip-link" href="#rc-main">Saltar al contenido principal</a>

<!-- ========== NAV ========== -->
<nav class="rc-nav" aria-label="Navegación principal">
  <a href="<?php echo esc_url( home_url( '/' ) ); ?>" class="rc-nav-logo" aria-label="ResolveCore — inicio">RESOLVE<span>CORE</span></a>
  <ul id="rc-nav-list">
    <li><a href="#flujo">Cómo funciona</a></li>
    <li><a href="#servicios">Servicios</a></li>
    <li><a href="#diagnosticos">Diagnósticos</a></li>
    <li><a href="#precios">Precios</a></li>
    <li><a href="#faq">FAQ</a></li>
  </ul>
  <a href="#cta" class="rc-nav-cta">DESCARGAR</a>
  <button class="rc-nav-toggle" aria-controls="rc-nav-list" aria-expanded="false" aria-label="Abrir menú">
    <span></span><span></span><span></span>
  </button>
</nav>

<main id="rc-main">

<!-- ========== HERO ========== -->
<section class="rc-hero">
  <div class="rc-hero-grid"></div>
  <div class="rc-hero-glow"></div>
  <div class="rc-hero-content">
    <div class="rc-badge">PLATAFORMA CROSS-PLATFORM · v1.1 · TUI LAUNCHER</div>
    <h1>
      <span class="dim">Solución a tus</span><br>
      <span class="accent">problemas</span><br>
      informáticos.
    </h1>
    <p class="rc-hero-sub">Diagnóstico automatizado, proyección de vida útil del hardware y análisis de vulnerabilidades multi-feed (NVD · CISA KEV · OSV · EPSS) para Windows, Linux, macOS y Android.</p>
    <div class="rc-hero-actions">
      <a href="#" class="rc-btn-primary">DESCARGAR GRATIS</a>
      <a href="#servicios" class="rc-btn-outline">VER SERVICIOS</a>
    </div>
    <div class="rc-hero-stats">
      <div><div class="rc-stat-num">4</div><div class="rc-stat-label">Plataformas soportadas</div></div>
      <div><div class="rc-stat-num">4</div><div class="rc-stat-label">Feeds CVE integrados</div></div>
      <div><div class="rc-stat-num">4</div><div class="rc-stat-label">Niveles de optimización</div></div>
      <div><div class="rc-stat-num">100%</div><div class="rc-stat-label">Diagnóstico automatizado</div></div>
    </div>
  </div>
  <div class="rc-scroll-hint" aria-hidden="true">SCROLL</div>
</section>

<!-- ========== PLATAFORMAS ========== -->
<div class="rc-platforms">
  <div class="rc-platforms-inner">
    <span class="rc-plat-label">COMPATIBLE CON</span>
    <div class="rc-plat-items">
      <div class="rc-plat-item"><div class="rc-plat-icon pi-win">⊞</div> Windows 10 / 11</div>
      <div class="rc-plat-item"><div class="rc-plat-icon pi-lin">☰</div> Linux (Ubuntu, Debian, Arch)</div>
      <div class="rc-plat-item"><div class="rc-plat-icon pi-mac">◉</div> macOS 12+</div>
      <div class="rc-plat-item"><div class="rc-plat-icon pi-and">◈</div> Android 10+ (ADB)</div>
    </div>
  </div>
</div>

<!-- ========== PIPELINE 7 FASES ========== -->
<div class="rc-section" id="flujo">
  <div class="rc-section-label">// CÓMO FUNCIONA</div>
  <h2 class="rc-section-title">Flujo de servicio en 7 fases</h2>
  <p class="rc-section-desc">Desde la solicitud del cliente hasta la facturación. Cada fase está automatizada e integrada con MantisBT.</p>
  <div class="rc-pipeline">
    <?php
    $pipeline = [
      ['◎','Solicitud','El cliente abre incidencia desde la web'],
      ['◇','Ticket','MantisBT registra y asigna técnico'],
      ['⇄','Conexión','Sesión remota vía AnyDesk'],
      ['⬡','Diagnóstico','Scripts cross-platform analizan el equipo'],
      ['◈','Resolución','Optimización + parches CVE'],
      ['☷','Informe','PDF técnico autogenerado'],
      ['€','Facturación','Cierre y emisión automática'],
    ];
    foreach ( $pipeline as $p ): ?>
    <div class="rc-pipe-step">
      <div class="rc-pipe-icon"><?php echo $p[0]; ?></div>
      <div class="rc-pipe-title"><?php echo $p[1]; ?></div>
      <div class="rc-pipe-desc"><?php echo $p[2]; ?></div>
    </div>
    <?php endforeach; ?>
  </div>
</div>

<!-- ========== SERVICIOS ========== -->
<div class="rc-section" id="servicios">
  <div class="rc-section-label">// SERVICIOS</div>
  <h2 class="rc-section-title">¿Qué hace ResolveCore?</h2>
  <p class="rc-section-desc">Una plataforma unificada para mantener tus sistemas en perfecto estado, con herramientas automatizadas de nivel profesional.</p>

  <div class="rc-services-grid">
    <?php
    $services = [
      ['⬡','01','TUI Launcher modular','Menú interactivo cross-platform (ResolveCore.ps1 / .sh) con análisis previo del sistema y pass-through directo a los módulos.',['Detección automática de problemas críticos','Pass-through de flags a diagnóstico/optimización','Ayuda embebida y modo NoLoop para CI/CD']],
      ['◈','02','Diagnóstico automatizado','Análisis completo del sistema en segundos. Detecta cuellos de botella, errores de disco y problemas de memoria sin configuración manual.',['Escaneo de CPU, RAM y almacenamiento','S.M.A.R.T, sensores y red en tiempo real','Salida JSON estructurada + informe PDF/HTML']],
      ['⬡','03','CVE Engine multi-feed','Escanea el SO contra cuatro feeds públicos en paralelo y prioriza con EPSS. Sin dependencias pip — solo Python 3.8+ stdlib.',['NVD (NIST) + CISA KEV (explotadas)','OSV (Google) + EPSS-FIRST (probabilidad)','Histórico local y export CSV/JSON/email']],
      ['◇','04','Optimización por niveles','Cuatro perfiles configurables con backup previo del registro/sysctl y rollback total. Spooler siempre excluido.',['ligero · estandar · rendimiento · extreme','--dry-run para previsualizar cambios','--undo y --backup-only para reversión segura']],
      ['⬡','05','Suite cross-platform','Paridad de funcionalidad en Windows, Linux, macOS y Android desde una única arquitectura modular.',['PowerShell 7 + Bash 4+ con misma API','ADB shell para diagnóstico Android','macOS con paridad funcional respecto a Linux']],
      ['◈','06','Auto-instalación de dependencias','Instala paquetes opcionales (smartmontools, lm-sensors, nmap, jq) bajo demanda con winget/choco/apt/dnf.',['Confirmación interactiva (-I) o auto (-A)','Compatible con entornos sin conexión','Detección y skip si ya están presentes']],
    ];
    foreach ($services as $s): ?>
    <div class="rc-service-card">
      <div class="rc-service-icon"><?php echo $s[0]; ?></div>
      <div class="rc-service-tag">MÓDULO <?php echo $s[1]; ?></div>
      <div class="rc-service-title"><?php echo $s[2]; ?></div>
      <p class="rc-service-desc"><?php echo $s[3]; ?></p>
      <div class="rc-service-features">
        <?php foreach ($s[4] as $f): ?>
        <div class="rc-sf-item"><?php echo $f; ?></div>
        <?php endforeach; ?>
      </div>
    </div>
    <?php endforeach; ?>
  </div>
</div>

<!-- ========== DIAGNÓSTICO ========== -->
<div class="rc-section" id="diagnosticos" style="padding-top:0">
  <div class="rc-section-label">// DIAGNÓSTICO EN ACCIÓN</div>
  <h2 class="rc-section-title">Terminal de diagnóstico</h2>
  <p class="rc-section-desc">ResolveCore trabaja en segundo plano, analizando tu sistema y reportando resultados en tiempo real.</p>

  <div class="rc-diag-layout">
    <div class="rc-terminal">
      <div class="rc-term-header">
        <div class="rc-term-dot td1"></div>
        <div class="rc-term-dot td2"></div>
        <div class="rc-term-dot td3"></div>
        <span class="rc-term-title">resolvecore — diagnóstico completo</span>
      </div>
      <span style="display:block"><span class="tl-prompt">rc@system:~$</span> ./ResolveCore.sh</span>
      <span style="display:block" class="tl-dim">[*] Análisis previo del sistema...</span>
      <span style="display:block" class="tl-ok">✓ CPU: Intel Core i7-12700H — 8% carga</span>
      <span style="display:block" class="tl-ok">✓ RAM: 16GB DDR5 — 42% en uso</span>
      <span style="display:block" class="tl-warn">⚠ SSD: 87% lleno — acción recomendada</span>
      <span style="display:block" class="tl-ok">✓ Temperatura: 54°C — nominal</span>
      <span style="display:block" class="tl-dim">─────────────────────────────</span>
      <span style="display:block" class="tl-info">→ buscar_vulnerabilidades.py (NVD · KEV · OSV · EPSS)</span>
      <span style="display:block" class="tl-err">✗ CVE-2024-3049 — CRÍTICO (KEV · EPSS 0.94)</span>
      <span style="display:block" class="tl-warn">⚠ CVE-2024-1871 — ALTO (EPSS 0.71)</span>
      <span style="display:block" class="tl-ok">✓ 23 comprobaciones pasadas</span>
      <span style="display:block" class="tl-info">→ optimizacion.sh rendimiento --dry-run</span>
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

<!-- ========== PRECIOS ========== -->
<div class="rc-section" id="precios">
  <div class="rc-section-label">// PRECIOS</div>
  <h2 class="rc-section-title">Planes</h2>
  <p class="rc-section-desc">Elige el plan que se adapta a tus necesidades. Sin suscripciones ocultas.</p>

  <div class="rc-pricing-grid">
    <!-- FREE -->
    <div class="rc-pricing-card">
      <div class="rc-pricing-label">PLAN</div>
      <div class="rc-pricing-name">Free</div>
      <div class="rc-pricing-price">
        <span class="price-currency">€</span><span class="price-num">0</span><span class="price-period">/ siempre</span>
      </div>
      <div class="rc-pricing-divider"></div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> Diagnóstico básico + TUI</div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> 1 dispositivo</div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> Windows únicamente</div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> Optimización nivel ligero</div>
      <div class="rc-pricing-feature"><span class="pf-none">─</span> CVE Engine multi-feed</div>
      <div class="rc-pricing-feature"><span class="pf-none">─</span> Proyección de hardware</div>
      <div style="margin-top:1.5rem"><a href="#" class="rc-btn-outline" style="width:100%;text-align:center;font-size:11px;padding:10px">DESCARGAR</a></div>
    </div>
    <!-- PRO -->
    <div class="rc-pricing-card featured">
      <div class="rc-pricing-label">PLAN</div>
      <div class="rc-pricing-badge">MÁS POPULAR</div>
      <div class="rc-pricing-name">Pro</div>
      <div class="rc-pricing-price">
        <span class="price-currency">€</span><span class="price-num">4.99</span><span class="price-period">/ mes</span>
      </div>
      <div class="rc-pricing-divider"></div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> Diagnóstico completo + TUI</div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> 3 dispositivos</div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> Windows + Linux + macOS</div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> CVE Engine (NVD · KEV · OSV · EPSS)</div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> Optimización 4 niveles + Undo</div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> Proyección de hardware</div>
      <div style="margin-top:1.5rem"><a href="#" class="rc-btn-primary" style="width:100%;text-align:center;font-size:11px;padding:10px;display:block">EMPEZAR</a></div>
    </div>
    <!-- ENTERPRISE -->
    <div class="rc-pricing-card">
      <div class="rc-pricing-label">PLAN</div>
      <div class="rc-pricing-name">Enterprise</div>
      <div class="rc-pricing-price">
        <span class="price-currency">€</span><span class="price-num">14.99</span><span class="price-period">/ mes</span>
      </div>
      <div class="rc-pricing-divider"></div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> Todo en Pro</div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> Dispositivos ilimitados</div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> Windows + Linux + macOS + Android</div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> Integración MantisBT (REST API)</div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> BD CVE offline + auto-instalación deps</div>
      <div class="rc-pricing-feature"><span class="pf-check">■</span> Soporte prioritario</div>
      <div style="margin-top:1.5rem"><a href="#" class="rc-btn-outline" style="width:100%;text-align:center;font-size:11px;padding:10px">CONTACTAR</a></div>
    </div>
  </div>
</div>

<!-- ========== FAQ ========== -->
<div class="rc-section" id="faq">
  <div class="rc-section-label">// PREGUNTAS FRECUENTES</div>
  <h2 class="rc-section-title">FAQ</h2>
  <p class="rc-section-desc">Lo que más nos preguntan antes de contratar el servicio.</p>
  <div class="rc-faq">
    <?php
    $faqs = [
      ['¿Funciona en mi sistema operativo?','Soportamos Windows 10/11, distribuciones Linux modernas (Ubuntu, Debian, Arch, Fedora), macOS 12+ y Android 10+ vía ADB. La paridad de funciones está garantizada.'],
      ['¿Las optimizaciones son reversibles?','Sí. Cada nivel de optimización (ligero, estándar, rendimiento, extreme) genera un backup previo del registro y sysctl. Usa <code>--undo</code> para revertir en cualquier momento.'],
      ['¿De dónde salen los CVEs?','El motor consulta cuatro feeds públicos en paralelo: NVD (NIST), CISA KEV (vulnerabilidades activamente explotadas), OSV (Google) y EPSS-FIRST para priorizar por probabilidad de explotación.'],
      ['¿Necesito instalar dependencias?','No es obligatorio. Las herramientas opcionales (smartmontools, lm-sensors, nmap, jq) se autoinstalan bajo demanda con <code>-I</code> o <code>-A</code> usando winget/choco/apt/dnf según el SO.'],
      ['¿Hay integración con sistemas de tickets?','Sí, integración nativa con MantisBT vía REST API. El plan Enterprise adjunta automáticamente el informe técnico al ticket al cerrar la incidencia.'],
      ['¿Es software libre?','El motor de scripts y el scanner de vulnerabilidades son software libre bajo GPL-3.0. Solo usamos APIs públicas y dependencias open source.'],
    ];
    foreach ( $faqs as $f ): ?>
    <details class="rc-faq-item">
      <summary><?php echo esc_html( $f[0] ); ?></summary>
      <div class="rc-faq-body"><?php echo wp_kses_post( $f[1] ); ?></div>
    </details>
    <?php endforeach; ?>
  </div>
</div>

<!-- ========== CTA FINAL ========== -->
<div class="rc-section" id="cta">
  <div class="rc-cta">
    <h2 class="rc-cta-title">¿Listo para automatizar tu soporte?</h2>
    <p class="rc-cta-sub">Descarga el TUI Launcher y empieza a diagnosticar en menos de 60 segundos. Sin registro, sin tarjeta.</p>
    <div class="rc-cta-actions">
      <a href="https://github.com/Haplee/ResolvCore" class="rc-btn-primary" target="_blank" rel="noopener">DESCARGAR EN GITHUB</a>
      <a href="#precios" class="rc-btn-outline">VER PLANES</a>
    </div>
  </div>
</div>

<!-- ========== FOOTER ========== -->
</main><!-- /#rc-main -->

<footer class="rc-footer" id="contacto">
  <div>
    <div class="rc-footer-logo">RESOLVECORE</div>
    <div class="rc-footer-copy" style="margin-top:6px">© <?php echo esc_html( date_i18n( 'Y' ) ); ?> Francisco Vidal Mateo · TFG ASIR</div>
  </div>
  <ul>
    <li><a href="https://github.com/Haplee" target="_blank" rel="noopener noreferrer">GitHub</a></li>
    <li><a href="#flujo">Cómo funciona</a></li>
    <li><a href="#servicios">Servicios</a></li>
    <li><a href="#precios">Precios</a></li>
    <li><a href="#faq">FAQ</a></li>
  </ul>
  <div style="font-family:var(--rc-mono);font-size:11px;color:var(--rc-muted)">
    Solución a tus problemas informáticos.
  </div>
</footer>

<script>
(function () {
  var btn = document.querySelector('.rc-nav-toggle');
  var list = document.getElementById('rc-nav-list');
  if (!btn || !list) return;
  btn.addEventListener('click', function () {
    var open = btn.getAttribute('aria-expanded') === 'true';
    btn.setAttribute('aria-expanded', String(!open));
    list.classList.toggle('is-open', !open);
  });
  list.addEventListener('click', function (e) {
    if (e.target.tagName === 'A') {
      btn.setAttribute('aria-expanded', 'false');
      list.classList.remove('is-open');
    }
  });
})();
</script>
<?php wp_footer(); ?>
</body>
</html>
