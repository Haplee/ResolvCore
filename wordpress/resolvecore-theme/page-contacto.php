<?php
/* Template Name: Contacto */
get_header();
?>
<style>
.rc-contacto-wrap { max-width:700px; margin:3rem auto; padding:0 2rem; }
.rc-contacto-wrap h1 { font-family:var(--rc-mono); font-size:2rem; font-weight:700; margin-bottom:.5rem; }
.rc-contacto-wrap .sub { color:var(--rc-muted); margin-bottom:2.5rem; font-size:14px; }
.rc-form { display:flex; flex-direction:column; gap:1rem; }
.rc-form-row { display:grid; grid-template-columns:1fr 1fr; gap:1rem; }
.rc-form-group { display:flex; flex-direction:column; gap:6px; }
.rc-form-label { font-family:var(--rc-mono); font-size:10px; letter-spacing:.08em; color:var(--rc-muted); text-transform:uppercase; }
.rc-form-input,.rc-form-select,.rc-form-textarea {
  background:var(--rc-surface2,#1a1d24); border:1px solid var(--rc-border2,rgba(255,255,255,.13));
  color:var(--rc-text); font-family:var(--rc-sans); font-size:14px;
  padding:10px 14px; outline:none; width:100%; box-sizing:border-box;
}
.rc-form-input:focus,.rc-form-select:focus,.rc-form-textarea:focus { border-color:var(--rc-accent); }
.rc-form-textarea { resize:vertical; min-height:120px; }
.rc-form-submit {
  font-family:var(--rc-mono); font-size:12px; letter-spacing:.06em;
  color:#000; background:var(--rc-accent); border:none;
  padding:13px 28px; cursor:pointer; font-weight:700;
  transition:all .25s; align-self:flex-start;
}
.rc-form-submit:hover { background:#00ffb3; }
.rc-form-submit:disabled { opacity:.5; cursor:not-allowed; }
.rc-form-msg { font-family:var(--rc-mono); font-size:12px; padding:10px 14px; display:none; }
.rc-form-msg.success { background:rgba(40,200,64,.08); border:1px solid rgba(40,200,64,.2); color:#28c840; display:block; }
.rc-form-msg.error { background:rgba(255,107,53,.08); border:1px solid rgba(255,107,53,.2); color:var(--rc-warn); display:block; }
</style>

<div class="rc-contacto-wrap">
  <h1>Contacto</h1>
  <p class="sub">¿Tienes un problema? Abre un ticket y te respondemos en menos de 24 h.</p>

  <form id="rc-contact-form" class="rc-form">
    <input type="hidden" name="rc_website" value="">
    <div class="rc-form-row">
      <div class="rc-form-group">
        <label class="rc-form-label">Nombre</label>
        <input type="text" name="rc_name" class="rc-form-input" placeholder="Tu nombre" required>
      </div>
      <div class="rc-form-group">
        <label class="rc-form-label">Email</label>
        <input type="email" name="rc_email" class="rc-form-input" placeholder="tu@email.com" required>
      </div>
    </div>
    <div class="rc-form-group">
      <label class="rc-form-label">Tipo de consulta</label>
      <select name="rc_type" class="rc-form-select">
        <option value="soporte">Soporte técnico</option>
        <option value="bug">Reporte de bug</option>
        <option value="colaboracion">Colaboración</option>
        <option value="licencia">Licencia</option>
        <option value="otro">Otro</option>
      </select>
    </div>
    <div class="rc-form-group">
      <label class="rc-form-label">Mensaje</label>
      <textarea name="rc_message" class="rc-form-textarea" placeholder="Describe tu problema..." required maxlength="500"></textarea>
    </div>
    <div class="rc-form-msg" id="rc-msg"></div>
    <button type="submit" class="rc-form-submit">ENVIAR MENSAJE →</button>
  </form>
</div>

<script>
document.getElementById('rc-contact-form').addEventListener('submit', async function(e) {
  e.preventDefault();
  const btn = this.querySelector('.rc-form-submit');
  const msg = document.getElementById('rc-msg');
  btn.disabled = true; btn.textContent = 'ENVIANDO...';
  msg.style.display = 'none'; msg.className = 'rc-form-msg';

  const data = new FormData(this);
  data.append('action', 'resolvecore_contact');
  data.append('nonce', '<?php echo wp_create_nonce("resolvecore_contact"); ?>');

  try {
    const res = await fetch('<?php echo admin_url("admin-ajax.php"); ?>', { method:'POST', body:data });
    const json = await res.json();
    msg.textContent = json.data?.msg || (json.success ? 'Enviado' : 'Error');
    msg.className = 'rc-form-msg ' + (json.success ? 'success' : 'error');
    if (json.success) this.reset();
  } catch {
    msg.textContent = 'Error de red.';
    msg.className = 'rc-form-msg error';
  }
  btn.disabled = false; btn.textContent = 'ENVIAR MENSAJE →';
});
</script>

<?php get_footer(); ?>
