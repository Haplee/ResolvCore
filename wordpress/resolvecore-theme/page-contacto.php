<?php
/* Template Name: Contacto */
get_header();
?>
<style>
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
	--rc-muted:   #8b909e;
	--rc-mono:    'Space Mono', monospace;
	--rc-sans:    'DM Sans', sans-serif;
}
body { background: var(--rc-bg); color: var(--rc-text); font-family: var(--rc-sans); }

.rc-ct-hero {
	position: relative; overflow: hidden;
	padding: 6rem 2rem;
	background:
	radial-gradient(ellipse at 20% 0%, rgba(0,229,160,.08) 0%, transparent 55%),
	radial-gradient(ellipse at 80% 100%, rgba(0,153,255,.05) 0%, transparent 60%),
	var(--rc-bg);
}
.rc-ct-hero-inner { max-width: 760px; margin: 0 auto; text-align: center; }
.rc-ct-label {
	font-family: var(--rc-mono); font-size: 11px; letter-spacing: .12em;
	color: var(--rc-accent); margin-bottom: .75rem;
}
.rc-ct-title {
	font-family: var(--rc-mono); font-size: clamp(2rem, 5vw, 3.2rem);
	font-weight: 700; line-height: 1.1; margin-bottom: 1.25rem;
}
.rc-ct-title .accent { color: var(--rc-accent); }
.rc-ct-sub {
	color: var(--rc-muted); font-size: 1.1rem; max-width: 560px;
	line-height: 1.7; margin: 0 auto 2.25rem;
}
.rc-ct-cta {
	display: inline-block;
	font-family: var(--rc-mono); font-size: 14px; letter-spacing: .06em;
	color: #000; background: var(--rc-accent); border: none; text-decoration: none;
	padding: 18px 40px; cursor: pointer; font-weight: 700;
	transition: background-color .25s, transform .25s, box-shadow .25s;
}
.rc-ct-cta:hover {
	background: #00ffb3; transform: translateY(-2px);
	box-shadow: 0 8px 28px rgba(0,229,160,.3); text-decoration: none;
}
.rc-ct-mail {
	margin-top: 1.75rem;
	font-family: var(--rc-mono); font-size: 12px; color: var(--rc-muted);
}
.rc-ct-mail a { color: var(--rc-accent); text-decoration: none; }
.rc-ct-mail a:hover { text-decoration: underline; }

.rc-ct-meta {
	display: flex; justify-content: center; gap: 1.5rem; flex-wrap: wrap;
	margin-top: 2.5rem;
	font-family: var(--rc-mono); font-size: 12px; color: var(--rc-muted);
	letter-spacing: .04em;
}
.rc-ct-meta-item { display: flex; align-items: center; gap: 6px; }
.rc-ct-meta-dot {
	width: 8px; height: 8px; border-radius: 50%;
	background: var(--rc-accent); animation: rcPulseCt 2s infinite;
}
@keyframes rcPulseCt { 50% { opacity: .3; } }
</style>

<section class="rc-ct-hero">
	<div class="rc-ct-hero-inner">
	<div class="rc-ct-label">// CONTACTO</div>
	<h1 class="rc-ct-title">Cuéntanos qué <span class="accent">no funciona</span>.</h1>
	<p class="rc-ct-sub">Soporte técnico remoto para Windows, Linux y Android. Crea tu cuenta y abre un ticket: diagnóstico, parches de seguridad e informe técnico al cerrar.</p>

	<a class="rc-ct-cta" href="<?php echo esc_url( home_url( '/registro/' ) ); ?>">CREAR CUENTA Y ABRIR TICKET →</a>

	<p class="rc-ct-mail">¿Dudas? Escríbenos a <a href="mailto:tecnicos@resolvecore.website">tecnicos@resolvecore.website</a></p>

	<div class="rc-ct-meta">
		<div class="rc-ct-meta-item">
		<span class="rc-ct-meta-dot"></span> Respuesta &lt; 2 h en horario laboral
		</div>
		<div class="rc-ct-meta-item">⬡ AnyDesk cifrado</div>
		<div class="rc-ct-meta-item">◈ Si no se resuelve, no se factura</div>
	</div>
	</div>
</section>

<?php get_footer(); ?>
