# Correo saliente: SPF, DKIM y DMARC

> Garantiza que los correos de confirmación de ticket (`wp_mail` desde el tema
> ResolveCore) lleguen a la bandeja de entrada del cliente y no a spam.
>
> Script automatizado: `scripts/server/setup-mail-dkim.sh` (idempotente).
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
5. Reinicia los servicios.
6. **Imprime los 3 registros DNS** que hay que crear en Ionos.

> El script es idempotente: si la clave DKIM ya existe, la conserva (no
> regenerar, o invalidarías el registro DNS publicado).

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
| Valor | `v=spf1 a mx ip4:<IP_VPS> ~all` |

Solo **un** registro SPF por dominio. Si ya existe uno (p. ej. de Ionos Mail),
fusiona las directivas, no crees un segundo.

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
| Correo no llega | Postfix no escucha o sin milter | `--check`, revisar `systemctl status postfix` |
| DKIM `fail` en mail-tester | DNS no propagó / valor mal pegado | `dig` el TXT, comparar con `rc.txt` |
| SPF `softfail` | IP del VPS no incluida | Añadir `ip4:<IP_VPS>` al registro SPF |
| `opendkim` no arranca | Permisos de la clave | `chown -R opendkim:opendkim /etc/opendkim` |
| Doble SPF | Dos registros TXT SPF | Fusionar en uno solo |

---

## 5. Referencias

- Script: `scripts/server/setup-mail-dkim.sh`
- Despliegue VPS: `docs/tecnica/despliegue-ionos.md`
- Función emisora: `resolvecore_send_client_confirmation()` en
  `wordpress/resolvecore-theme/functions.php`
