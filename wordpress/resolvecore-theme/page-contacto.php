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
  --rc-muted:   #7a7f8e;
  --rc-mono:    'Space Mono', monospace;
  --rc-sans:    'DM Sans', sans-serif;
}
body { background: var(--rc-bg); color: var(--rc-text); font-family: var(--rc-sans); }

.rc-ct-hero {
  position: relative; overflow: hidden;
  padding: 5rem 2rem 3rem;
  border-bottom: 1px solid var(--rc-border);
  background:
    radial-gradient(ellipse at 20% 0%, rgba(0,229,160,.08) 0%, transparent 55%),
    radial-gradient(ellipse at 80% 100%, rgba(0,153,255,.05) 0%, transparent 60%),
    var(--rc-bg);
}
.rc-ct-hero-inner { max-width: 1100px; margin: 0 auto; }
.rc-ct-label {
  font-family: var(--rc-mono); font-size: 11px; letter-spacing: .12em;
  color: var(--rc-accent); margin-bottom: .75rem;
}
.rc-ct-title {
  font-family: var(--rc-mono); font-size: clamp(2rem, 4vw, 3rem);
  font-weight: 700; line-height: 1.1; margin-bottom: 1rem;
}
.rc-ct-title .accent { color: var(--rc-accent); }
.rc-ct-sub {
  color: var(--rc-muted); font-size: 1.05rem; max-width: 640px;
  line-height: 1.7; margin-bottom: 1.5rem;
}
.rc-ct-meta {
  display: flex; gap: 1.5rem; flex-wrap: wrap;
  font-family: var(--rc-mono); font-size: 12px; color: var(--rc-muted);
  letter-spacing: .04em;
}
.rc-ct-meta-item { display: flex; align-items: center; gap: 6px; }
.rc-ct-meta-dot {
  width: 8px; height: 8px; border-radius: 50%;
  background: var(--rc-accent); animation: rcPulseCt 2s infinite;
}
@keyframes rcPulseCt { 50% { opacity: .3; } }

.rc-ct-wrap { max-width: 1100px; margin: 3rem auto; padding: 0 2rem; }

.rc-ct-grid {
  display: grid; grid-template-columns: 1fr 1.5fr; gap: 2.5rem;
  align-items: start;
}
@media (max-width: 860px) {
  .rc-ct-grid { grid-template-columns: 1fr; }
}

.rc-ct-side {
  display: flex; flex-direction: column; gap: 1rem;
}
.rc-ct-channel {
  display: flex; align-items: center; gap: 1rem;
  background: var(--rc-surface); border: 1px solid var(--rc-border);
  padding: 1.1rem 1.25rem; text-decoration: none;
  transition: border-color .2s, transform .2s, background .2s;
}
.rc-ct-channel:hover {
  border-color: rgba(0,229,160,.35);
  background: var(--rc-surface2);
  transform: translateY(-2px);
  text-decoration: none;
}
.rc-ct-channel-icon {
  width: 40px; height: 40px; flex-shrink: 0;
  border: 1px solid var(--rc-border2);
  display: flex; align-items: center; justify-content: center;
  color: var(--rc-accent); font-size: 16px;
}
.rc-ct-channel-label {
  font-family: var(--rc-mono); font-size: 10px; letter-spacing: .08em;
  color: var(--rc-muted); margin-bottom: 3px;
}
.rc-ct-channel-val { font-size: 13px; color: var(--rc-text); font-weight: 500; }

.rc-ct-trust {
  background: var(--rc-surface); border: 1px solid var(--rc-border);
  padding: 1.25rem; margin-top: .5rem;
}
.rc-ct-trust h3 {
  font-family: var(--rc-mono); font-size: 11px; letter-spacing: .08em;
  color: var(--rc-muted); margin-bottom: .75rem;
}
.rc-ct-trust ul { list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 8px; }
.rc-ct-trust li {
  font-size: 13px; color: var(--rc-text); display: flex; align-items: flex-start; gap: 8px;
  line-height: 1.5;
}
.rc-ct-trust li::before {
  content: '✓'; color: var(--rc-accent); font-weight: 700; flex-shrink: 0;
}

.rc-ct-form-box {
  background: var(--rc-surface); border: 1px solid var(--rc-border);
  padding: 2rem;
}
.rc-ct-form-title {
  font-family: var(--rc-mono); font-size: 1.1rem; font-weight: 700;
  margin-bottom: .5rem;
}
.rc-ct-form-sub {
  color: var(--rc-muted); font-size: 13px; margin-bottom: 1.5rem;
}

.rc-form { display: flex; flex-direction: column; gap: 1rem; }
.rc-form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.rc-form-group { display: flex; flex-direction: column; gap: 6px; }
.rc-form-label {
  font-family: var(--rc-mono); font-size: 10px; letter-spacing: .08em;
  color: var(--rc-muted); text-transform: uppercase;
}
.rc-form-input,.rc-form-select,.rc-form-textarea {
  background: var(--rc-surface2); border: 1px solid var(--rc-border2);
  color: var(--rc-text); font-family: var(--rc-sans); font-size: 14px;
  padding: 11px 14px; outline: none; width: 100%; box-sizing: border-box;
  transition: border-color .2s;
}
.rc-form-input:focus,.rc-form-select:focus,.rc-form-textarea:focus {
  border-color: var(--rc-accent);
}
.rc-form-select { appearance: none; cursor: pointer; }
.rc-form-textarea { resize: vertical; min-height: 130px; font-family: var(--rc-sans); }
.rc-form-count {
  font-family: var(--rc-mono); font-size: 11px; color: var(--rc-muted);
  text-align: right; margin-top: -2px;
}
.rc-form-submit {
  font-family: var(--rc-mono); font-size: 12px; letter-spacing: .06em;
  color: #000; background: var(--rc-accent); border: none;
  padding: 14px 28px; cursor: pointer; font-weight: 700;
  transition: all .25s; align-self: flex-start;
}
.rc-form-submit:hover { background: #00ffb3; transform: translateY(-1px); box-shadow: 0 6px 20px rgba(0,229,160,.25); }
.rc-form-submit:disabled { opacity: .5; cursor: not-allowed; transform: none; }
.rc-form-msg {
  font-family: var(--rc-mono); font-size: 12px;
  padding: 10px 14px; display: none;
}
.rc-form-msg.success {
  background: rgba(40,200,64,.08); border: 1px solid rgba(40,200,64,.2);
  color: #28c840; display: block;
}
.rc-form-msg.error {
  background: rgba(255,107,53,.08); border: 1px solid rgba(255,107,53,.2);
  color: var(--rc-warn); display: block;
}

@media (max-width: 640px) {
  .rc-form-row { grid-template-columns: 1fr; }
  .rc-ct-form-box { padding: 1.25rem; }
}
</style>

<section class="rc-ct-hero">
  <div class="rc-ct-hero-inner">
    <div class="rc-ct-label">// CONTACTO</div>
    <h1 class="rc-ct-title">Cuéntanos qué <span class="accent">no funciona</span>.</h1>
    <p class="rc-ct-sub">Soporte técnico remoto para Windows, Linux y Android. Diagnóstico, parches de seguridad e informe PDF al cerrar el ticket.</p>
    <div class="rc-ct-meta">
      <div class="rc-ct-meta-item">
        <span class="rc-ct-meta-dot"></span> Respuesta &lt; 2 h en horario laboral
      </div>
      <div class="rc-ct-meta-item">⬡ AnyDesk cifrado</div>
      <div class="rc-ct-meta-item">◈ Sin compromiso</div>
    </div>
  </div>
</section>

<div class="rc-ct-wrap">
  <div class="rc-ct-grid">

    <aside class="rc-ct-side">
      <a class="rc-ct-channel" href="mailto:fvidalmateo@gmail.com">
        <div class="rc-ct-channel-icon">✉</div>
        <div>
          <div class="rc-ct-channel-label">EMAIL DIRECTO</div>
          <div class="rc-ct-channel-val">fvidalmateo@gmail.com</div>
        </div>
      </a>
      <a class="rc-ct-channel" href="https://github.com/Haplee/ResolveCore/issues/new" target="_blank" rel="noopener noreferrer">
        <div class="rc-ct-channel-icon">◈</div>
        <div>
          <div class="rc-ct-channel-label">REPORTE TÉCNICO</div>
          <div class="rc-ct-channel-val">GitHub Issues →</div>
        </div>
      </a>
      <a class="rc-ct-channel" href="<?php echo esc_url( home_url( '/docs/' ) ); ?>">
        <div class="rc-ct-channel-icon">⬡</div>
        <div>
          <div class="rc-ct-channel-label">AUTOSERVICIO</div>
          <div class="rc-ct-channel-val">Docs &amp; guías →</div>
        </div>
      </a>
      <a class="rc-ct-channel" href="https://x.com/FranVidalMateo" target="_blank" rel="noopener noreferrer">
        <div class="rc-ct-channel-icon">◇</div>
        <div>
          <div class="rc-ct-channel-label">TWITTER / X</div>
          <div class="rc-ct-channel-val">@FranVidalMateo</div>
        </div>
      </a>

      <div class="rc-ct-trust">
        <h3>// QUÉ ESPERAR</h3>
        <ul>
          <li>Confirmación del ticket en menos de 2 h</li>
          <li>Conexión remota acordada contigo (AnyDesk)</li>
          <li>Diagnóstico + resolución + informe PDF</li>
          <li>Si no se resuelve, no se factura</li>
        </ul>
      </div>
    </aside>

    <div class="rc-ct-form-box">
      <div class="rc-ct-form-title">Abrir ticket</div>
      <p class="rc-ct-form-sub">Cuanto más detalle, más rápido el diagnóstico. Adjunta capturas a fvidalmateo@gmail.com si las tienes.</p>

      <form id="rc-contact-form" class="rc-form">
        <input type="hidden" name="rc_website" value="">
        <div class="rc-form-row">
          <div class="rc-form-group">
            <label class="rc-form-label" for="rc_name">Nombre</label>
            <input type="text" id="rc_name" name="rc_name" class="rc-form-input" placeholder="Tu nombre" required>
          </div>
          <div class="rc-form-group">
            <label class="rc-form-label" for="rc_email">Email</label>
            <input type="email" id="rc_email" name="rc_email" class="rc-form-input" placeholder="tu@email.com" required>
          </div>
        </div>
        <div class="rc-form-group">
          <label class="rc-form-label" for="rc_type">Tipo de consulta</label>
          <select id="rc_type" name="rc_type" class="rc-form-select">
            <option value="soporte">Soporte técnico</option>
            <option value="bug">Reporte de bug</option>
            <option value="colaboracion">Colaboración</option>
            <option value="licencia">Licencia Pro / Enterprise</option>
            <option value="otro">Otro</option>
          </select>
        </div>
        <div class="rc-form-group">
          <label class="rc-form-label" for="rc_message">Mensaje</label>
          <textarea id="rc_message" name="rc_message" class="rc-form-textarea" placeholder="Describe el problema, SO, equipo, cuándo empezó..." required maxlength="500"></textarea>
          <div class="rc-form-count"><span id="rc-char">0</span> / 500</div>
        </div>
        <div class="rc-form-msg" id="rc-msg"></div>
        <button type="submit" class="rc-form-submit">ENVIAR MENSAJE →</button>
      </form>
    </div>

  </div>
</div>

<script>
(function() {
  var form = document.getElementById('rc-contact-form');
  var msg  = document.getElementById('rc-msg');
  var ta   = document.getElementById('rc_message');
  var ch   = document.getElementById('rc-char');

  ta.addEventListener('input', function() { ch.textContent = ta.value.length; });

  form.addEventListener('submit', async function(e) {
    e.preventDefault();
    var btn = form.querySelector('.rc-form-submit');
    btn.disabled = true; btn.textContent = 'ENVIANDO...';
    msg.style.display = 'none'; msg.className = 'rc-form-msg';

    var data = new FormData(form);
    data.append('action', 'resolvecore_contact');
    data.append('nonce', '<?php echo wp_create_nonce("resolvecore_contact"); ?>');

    try {
      var res = await fetch('<?php echo admin_url("admin-ajax.php"); ?>', { method:'POST', body:data });
      var json = await res.json();
      msg.textContent = (json.data && json.data.msg) || (json.success ? 'Enviado' : 'Error');
      msg.className = 'rc-form-msg ' + (json.success ? 'success' : 'error');
      if (json.success) { form.reset(); ch.textContent = '0'; }
    } catch (err) {
      msg.textContent = 'Error de red. Inténtalo de nuevo.';
      msg.className = 'rc-form-msg error';
    }
    btn.disabled = false; btn.textContent = 'ENVIAR MENSAJE →';
  });
})();
</script>

<?php get_footer(); ?>
