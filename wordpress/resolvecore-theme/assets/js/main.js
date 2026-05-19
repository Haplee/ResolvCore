document.addEventListener('DOMContentLoaded', () => {
  const form   = document.getElementById('rc-contact-form');
  if (!form) return;

  const msgOk  = document.getElementById('rc-msg-ok');
  const msgErr = document.getElementById('rc-msg-err');
  const btn    = form.querySelector('button[type="submit"]');

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    btn.disabled = true;
    btn.textContent = 'Enviando...';
    msgOk.style.display = msgErr.style.display = 'none';

    const data = new FormData(form);
    data.append('action', 'rc_contact_submit');
    data.append('_rc_nonce', rcAjax.nonce);

    try {
      const res  = await fetch(rcAjax.url, { method: 'POST', body: data });
      const json = await res.json();

      if (json.success) {
        msgOk.textContent = json.data.msg;
        msgOk.style.display = 'block';
        form.reset();
      } else {
        msgErr.textContent = json.data?.msg ?? 'Error al enviar.';
        msgErr.style.display = 'block';
      }
    } catch {
      msgErr.textContent = 'Error de red. Inténtalo de nuevo.';
      msgErr.style.display = 'block';
    } finally {
      btn.disabled = false;
      btn.textContent = 'Enviar mensaje';
    }
  });
});
