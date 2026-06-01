# Tareas pendientes — ResolveCore

> Lista de acciones manuales por hacer. Marca con [x] al completar.
> Última actualización: 2026-05-31.

---

## 1. Deploy de los últimos cambios (front-page, dashboard, login, mail script)

Commits los haces tú. Desde la raíz del repo en local:

```bash
git add -A
git commit -m "fix(cliente): filtro seguridad tickets + dashboard UI + login brand + mail script"
git push origin main
```

Luego en el VPS:

```bash
ssh franvi@***REMOVED***
sudo bash -c 'cd /opt/resolvecore-repo && git fetch origin && git reset --hard origin/main && bash scripts/server/ops/sync-wp.sh main'
exit
```

Verificación en Chrome (**Ctrl+Shift+R** para saltar caché):
- [ ] Home: acento **verde**, hero a 2 columnas, **demo interactiva** anima, tarjetas servicios refinadas.
- [ ] Nav «Recursos ▾» alineado (caret en la misma línea).
- [ ] `/registro/`: se ve el **formulario** (no solo la cabecera).
- [ ] Dashboard de un cliente: solo aparecen **sus** tickets (no los de otros).
- [ ] wp-login con logo ResolveCore + tema oscuro verde.

---

## 2. Configurar el correo saliente (IONOS SMTP vía msmtp) — ✅ COMPLETADO 2026-05-31

Sin esto NO llegan los emails de activación de cuenta ni «He olvidado mi contraseña».

1. [x] **Crear el buzón** en el panel IONOS → Email: `tecnicos@resolvecore.website`. Contraseña guardada aparte (gestor de contraseñas, **nunca en el repo**).
2. [x] En el VPS, lanzar el script con el buzón + password reales (pega la password en la terminal, no la versiones):
   ```bash
   sudo bash /opt/resolvecore-repo/scripts/server/ops/setup-mail-ionos.sh tecnicos@resolvecore.website 'PASSWORD_DEL_BUZON'
   ```
3. [x] Alinear el remitente de WordPress al buzón (el filtro `wp_mail_from` usa `admin_email`):
   ```bash
   sudo -u www-data wp option update admin_email tecnicos@resolvecore.website --path=/var/www/wp
   ```
4. [x] Probar el envío directo:
   ```bash
   echo -e "Subject: prueba resolvecore\n\nhola" | msmtp -a default TU_CORREO_PERSONAL@gmail.com
   ```
5. [x] Probar el flujo real: alta en `/registro/` con un email tuyo → debe llegar el correo de activación con el botón «Fijar mi contraseña».

Notas:
- Host/puerto por defecto del script: `smtp.ionos.es:587` (STARTTLS). Cambiar como args 3 y 4 si IONOS te da otros.
- La password queda solo en `/etc/msmtprc` (`0640 root:www-data`), nunca en el repo.
- Logs de envío en `/var/log/msmtp.log` si algo falla.

### 2b. Autenticación DNS (SPF / DKIM / DMARC) — ✅ hecho 2026-05-31

Registros TXT/CNAME en DNS de `resolvecore.website` (panel IONOS):
- **SPF** TXT `@`: `v=spf1 a mx ip4:***REMOVED*** include:_spf-eu.ionos.com ~all`.
- **DKIM**: CNAME `s1-ionos._domainkey` y `s2-ionos._domainkey` (firma IONOS, activado en panel Email). Borrado `rc._domainkey` huérfano (sobra del intento OpenDKIM, no firmaba nada con relay IONOS).
- **DMARC** TXT `_dmarc`: `v=DMARC1; p=quarantine; rua=mailto:postmaster@resolvecore.website; fo=1`.

Verificado: correo de activación («ResolveCore — Activa tu cuenta») llega a **inbox**, no a spam.

> Gotcha que costó depurar: en `/registro/` no llegaba nada porque el email de prueba (`fvidalmateo@gmail.com`) ya era la cuenta **admin** (ID 1) → `email_exists` corta el alta y no manda activación. Para probar el flujo real usar un email nuevo (alias Gmail `+test`). El transporte y la plantilla HTML funcionaban desde el principio.

---

## 3. Seguridad — rotar la contraseña root del VPS

La password root se compartió en texto plano durante el desarrollo. Rotar:

- [ ] En el VPS:
  ```bash
  sudo passwd root
  ```
- [ ] (Opcional recomendado) Deshabilitar login SSH por password y dejar solo clave:
  en `/etc/ssh/sshd_config` → `PasswordAuthentication no`, luego `sudo systemctl reload ssh`.
  (Antes asegúrate de tener tu clave pública en `~/.ssh/authorized_keys`.)

---

## 4. Token Mantis filtrado en git (auditoría A2 — decisión pendiente)

- [ ] Decisión del autor: el token de la API Mantis sigue en el histórico de git (riesgo asumido). Si se decide rotar, regenerarlo en MantisBT y actualizar `RC_MANTIS_TOKEN` en `wp-config.php` del VPS (no versionar).

---

## Ideas / mejoras futuras (no urgente)

- [ ] Dashboard: acciones in-situ (responder nota + adjuntar archivo desde el dashboard sin abrir MantisBT).
- [ ] Cachear `rc_mantis_listar_tickets()` con `set_transient` 60s para no castigar la API en cada visita.
- [ ] Mover los zips de descargas a GitHub Releases (auditoría E2).
