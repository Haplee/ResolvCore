# Correo saliente: SPF, DKIM y DMARC

> ⚠️ **ESTADO REAL (2026-05-31).** En producción el correo NO va por este flujo
> (Postfix + OpenDKIM). Va por **msmtp + relay autenticado a IONOS**, configurado
> con `scripts/server/ops/setup-mail-ionos.sh`, sobre el dominio
> **`resolvecore.website`** (no `.es`). DKIM lo firma IONOS (selectores
> `s1-ionos`/`s2-ionos`); SPF incluye `include:_spf-eu.ionos.com`; DMARC en
> `p=quarantine`. Verificado: el correo de activación llega a **inbox**.
> Este documento describe la alternativa OpenDKIM, cuyo script
> `scripts/server/setup-mail-dkim.sh` **se borró en `12890ac` y no está en el
> repo** (recuperable de histórico). Mantener como referencia, no como guía viva.
> Ver auditoría A11/D6.

> Garantiza que los correos de confirmación de ticket (`wp_mail` desde el tema
> ResolveCore) lleguen a la bandeja de entrada del cliente y no a spam.
>
> Script (alternativa, no presente): `scripts/server/setup-mail-dkim.sh` (idempotente).
> Tiempo total: ~10 min + propagación DNS.

---

## 0. Por qué hace falta

WordPress envía correo con `wp_mail()` → función `mail()` de PHP → Postfix local.
Sin autenticación de dominio, Gmail/Outlook marcan el correo como spam o lo
rechazan. Las tres capas que lo arreglan:

| Registro | Qué demuestra | Sin él |
|----------|---------------|--------|
| **SPF**  | Qué IP puede enviar correo del dominio | El correo parece falsificado |
| **DKIM** | El correo no se alteró en tránsito (firma criptográfica) | Sin firma de confianza |
| **DMARC**| Qué hacer si SPF/DKIM fallan + reporting | Sin política, cada proveedor decide |

El correo de confirmación al cliente es **no bloqueante** (si `wp_mail` falla, el
ticket se crea igual y se registra en el log), pero un correo en spam = cliente
que no ve su número de incidencia. Por eso esta configuración es necesaria en
producción.

---

## 1. Ejecutar el script en el VPS

```bash
# Conéctate al VPS por SSH
ssh tecnico@<ip-vps>

# Instala y configura Postfix + OpenDKIM
sudo bash scripts/server/setup-mail-dkim.sh --domain resolvecore.es

# Con relay saliente (necesario en VPS Ionos — ver sección 1b)
sudo bash scripts/server/setup-mail-dkim.sh --domain resolvecore.es \
     --relayhost smtp.ionos.es:587

# Selector personalizado (por defecto: rc)
sudo bash scripts/server/setup-mail-dkim.sh --domain resolvecore.es --selector rc

# Verificar una instalación ya hecha
sudo bash scripts/server/setup-mail-dkim.sh --domain resolvecore.es --check
```

El script:

1. Instala `postfix`, `opendkim`, `opendkim-tools`.
2. Genera una clave DKIM de 2048 bits en `/etc/opendkim/keys/<dominio>/`.
3. Escribe `opendkim.conf`, `KeyTable`, `SigningTable`, `TrustedHosts`.
4. Conecta Postfix al milter OpenDKIM (`smtpd_milters` puerto 8891).
5. Con `--relayhost`: configura el relay saliente (pide usuario/contraseña).
6. Reinicia los servicios.
7. **Imprime los 3 registros DNS** que hay que crear en Ionos.

> El script es idempotente: si la clave DKIM ya existe, la conserva (no
> regenerar, o invalidarías el registro DNS publicado).

---

## 1b. Relay saliente — obligatorio en VPS Ionos

**Los VPS de Ionos bloquean el puerto 25 saliente** (política antispam estándar
de la mayoría de proveedores). Sin tratar esto, el correo se queda en cola:

```
postfix/smtp: connect to ...:25: Connection timed out
status=deferred
```

El VPS no puede entregar correo directamente a otros servidores. La solución es
enviar **autenticado a través de un smarthost SMTP** del proveedor, por el
puerto 587. El flag `--relayhost` lo automatiza:

```bash
sudo bash scripts/server/setup-mail-dkim.sh --domain resolvecore.es \
     --relayhost smtp.ionos.es:587
```

El script pedirá de forma interactiva el **usuario** (un buzón completo del
dominio, p. ej. `tecnicos@resolvecore.es`) y su **contraseña** — la contraseña
nunca se pasa por la línea de comandos. Con eso:

- Escribe `/etc/postfix/sasl_passwd` (permisos `600`) y lo compila con `postmap`.
- Configura `relayhost`, `smtp_sasl_*` y `smtp_tls_security_level = encrypt`.
- Ajusta `mydestination` para que el correo a buzones del dominio salga por el
  relay y **no** se intente entregar localmente (causa del rebote
  `unknown user`).

Detalles importantes:

- **El buzón del smarthost debe existir** en el proveedor (créalo antes en el
  panel de correo de Ionos).
- La firma DKIM se aplica en el VPS *antes* del relay, así que el correo llega
  firmado al destinatario aunque salga por Ionos.
- El SPF debe incluir el `include:` del proveedor además de la IP del VPS
  (ver 2.1) — el relay envía desde las IP de Ionos.
- `myhostname` se fija a `mail.<dominio>` (no al dominio raíz) para que Postfix
  no trate el dominio como local.

Verificar el relay:

```bash
echo "test" | sendmail tu-correo@gmail.com
tail -n 5 /var/log/mail.log
```

Esperado: `status=sent` con `relay=smtp.ionos.es`. Si aparece
`SASL authentication failed`, la contraseña del buzón es incorrecta — corrige
`/etc/postfix/sasl_passwd`, vuelve a `postmap` y `systemctl reload postfix`.

---

## 2. Crear los registros DNS en Ionos

Panel Ionos → `Dominios y SSL` → dominio → `DNS`.

Sustituye `resolvecore.es` por tu dominio y `<IP_VPS>` por la IP pública del
VPS (el script la detecta y la imprime).

### 2.1 SPF

| Campo | Valor |
|-------|-------|
| Tipo  | `TXT` |
| Host  | `@` (raíz del dominio) |
| Valor | `v=spf1 a mx ip4:<IP_VPS> include:_spf-eu.ionos.com ~all` |

Solo **un** registro SPF por dominio. Si ya existe uno (p. ej. de Ionos Mail),
**fusiona** las directivas en una sola línea — no crees un segundo registro.

Como el correo sale por el relay de Ionos (sección 1b), el SPF debe autorizar
**tanto** la IP del VPS (`ip4:`) **como** los servidores de Ionos
(`include:_spf-eu.ionos.com`). Si omites el `include`, el correo relayado
falla SPF. Al guardar el registro, Ionos avisará de que desactiva su SPF
gestionado: es correcto siempre que el valor nuevo ya contenga el `include`.

### 2.2 DKIM

| Campo | Valor |
|-------|-------|
| Tipo  | `TXT` |
| Host  | `rc._domainkey` (usa el selector elegido) |
| Valor | Contenido entre comillas de `/etc/opendkim/keys/resolvecore.es/rc.txt` |

El fichero `.txt` trae el valor partido en varias líneas entre paréntesis;
concatena lo que está entre comillas en una sola cadena `v=DKIM1; k=rsa; p=…`.

### 2.3 DMARC

| Campo | Valor |
|-------|-------|
| Tipo  | `TXT` |
| Host  | `_dmarc` |
| Valor | `v=DMARC1; p=quarantine; rua=mailto:postmaster@resolvecore.es; fo=1` |

Empieza con `p=quarantine`. Cuando lleves semanas sin reportes de fallo, súbelo
a `p=reject`.

---

## 3. Verificación

```bash
# DNS propagado (puede tardar hasta 24-48 h, normalmente minutos en Ionos)
dig +short TXT rc._domainkey.resolvecore.es
dig +short TXT resolvecore.es
dig +short TXT _dmarc.resolvecore.es

# Estado de los servicios en el VPS
sudo bash scripts/server/setup-mail-dkim.sh --domain resolvecore.es --check
```

Prueba de entrega real:

1. Abre <https://www.mail-tester.com> y copia la dirección de test.
2. Desde WordPress, crea un ticket de prueba poniendo esa dirección como email
   del cliente (o usa el formulario de contacto).
3. Vuelve a mail-tester → puntuación. Objetivo: **10/10** (SPF pass, DKIM pass,
   DMARC alineado, sin blacklist).

---

## 4. Problemas frecuentes

| Síntoma | Causa probable | Arreglo |
|---------|----------------|---------|
| `Connection timed out` a puerto 25, `status=deferred` | Proveedor bloquea el puerto 25 saliente | Configurar relay con `--relayhost` (sección 1b) |
| `status=bounced (unknown user)` a un buzón del dominio | Postfix entrega local porque el dominio está en `mydestination` | Relay configurado pone `mydestination = localhost...`; o quitar el dominio a mano |
| `SASL authentication failed` | Usuario/contraseña del smarthost incorrectos | Corregir `/etc/postfix/sasl_passwd`, `postmap`, `reload postfix` |
| Correo no llega | Postfix no escucha o sin milter | `--check`, revisar `systemctl status postfix` |
| DKIM `fail` en mail-tester | DNS no propagó / valor mal pegado | `dig` el TXT, comparar con `rc.txt` |
| SPF `softfail` | IP del VPS o `include:` del relay no autorizados | Añadir `ip4:<IP_VPS>` e `include:_spf-eu.ionos.com` al SPF |
| `opendkim` no arranca | Permisos de la clave | `chown -R opendkim:opendkim /etc/opendkim` |
| Doble SPF | Dos registros TXT SPF | Fusionar en uno solo |

---

## 5. Referencias

- Script: `scripts/server/setup-mail-dkim.sh`
- Despliegue VPS: `docs/tecnica/despliegue-ionos.md`
- Función emisora: `resolvecore_send_client_confirmation()` en
  `wordpress/resolvecore-theme/functions.php`
