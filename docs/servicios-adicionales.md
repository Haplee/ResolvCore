# ResolveCore — Servicios Adicionales

> Justificación técnica de los servicios complementarios ofrecidos por ResolveCore.  
> Autor: Francisco Vidal Mateo · TFG ASIR 2024/25  
> Última actualización: mayo 2026

---

## Índice

1. [Congelación de sistemas](#1-congelación-de-sistemas)
2. [Clonación de sistemas](#2-clonación-de-sistemas)
3. [Acceso remoto y físico](#3-acceso-remoto-y-físico)
4. [Cifrado de disco](#4-cifrado-de-disco)
5. [Gestores de contraseñas](#5-gestores-de-contraseñas)
6. [Despliegue de SO por imágenes](#6-despliegue-de-so-por-imágenes)
7. [Posición en el catálogo de servicios ResolveCore](#7-posición-en-el-catálogo-de-servicios-resolvecore)

---

## 1. Congelación de sistemas

### Concepto

La congelación de sistemas protege una imagen de referencia del sistema operativo. Tras cada reinicio, el equipo vuelve al estado congelado, descartando todos los cambios realizados durante la sesión. Se usa en entornos donde varios usuarios comparten el mismo equipo y donde la persistencia de cambios es indeseable.

### Herramientas

#### Windows

| Herramienta | Fabricante | Licencia | Mecanismo | Caso de uso principal |
|-------------|-----------|----------|-----------|----------------------|
| **Deep Freeze** | Faronics | Comercial (~50 €/equipo) | Driver de bloqueo de escritura a nivel de sector | Aulas, quioscos, salas de examen |
| **Reboot Restore Rx** | Horizons | Gratuita (básica) / Pro | Snapshot de disco + restauración automática en reinicio | Uso doméstico, PYMES |
| **Returnil** | Returnil Software | Freemium | Disco virtual temporal para sesión | Protección ligera, usuario avanzado |
| **SteadyState** | Microsoft | Descontinuado (Win XP/Vista) | Perfil de usuario bloqueado | Referencia histórica, no usar en producción |

**Elección para ResolveCore:** Deep Freeze para clientes con aulas o salas de acceso público. Reboot Restore Rx para PYMES con presupuesto limitado.

#### Linux

| Herramienta | Mecanismo | Caso de uso |
|-------------|-----------|-------------|
| **fsprotect** | Overlay sobre sistema de ficheros (tmpfs) | Equipos de aula con Debian/Ubuntu |
| **BTRFS + snapper** | Snapshots del sistema + rollback automático en GRUB | Servidores y estaciones de trabajo |
| **OverlayFS manual** | Capas de lectura/escritura efímeras sobre rootfs | Contenedores, kioscos embedded |
| **aufs (deprecated)** | Unión de sistema de ficheros | Referencia histórica, no usar en kernels modernos |

**Elección para ResolveCore:** BTRFS + snapper en Ubuntu 22.04 LTS. Permite restauración selectiva por fecha, no solo reinicio. Compatible con el entorno de despliegue del proyecto.

### Procedimiento de implantación (cliente tipo)

```
1. Instalar herramienta de congelación en estado limpio del equipo
2. Configurar partición de trabajo (datos de usuario) excluida de la congelación
3. Definir estado de referencia (snapshot o imagen de congelación)
4. Validar: realizar cambios → reiniciar → verificar restauración
5. Documentar en MantisBT como servicio aplicado (ticket cerrado)
```

### Cuándo ofrece ResolveCore este servicio

- Aulas de informática (colegios, academias, centros de formación)
- Quioscos de atención al público
- Equipos compartidos en oficinas (recepción, salas de reuniones)
- Equipos de demostración en tiendas o ferias

---

## 2. Clonación de sistemas

### Concepto

La clonación crea una imagen exacta (sector a sector o a nivel de ficheros) de un disco o partición. La imagen se puede restaurar sobre hardware idéntico o similar, eliminando la necesidad de reinstalar y reconfigurar el SO desde cero.

### Herramientas

| Herramienta | Tipo | Licencia | Red/Local | SO soportados | Compresión | Restauración bare-metal |
|-------------|------|---------|-----------|--------------|-----------|------------------------|
| **Clonezilla Live** | Live CD/USB | GPL | Local (USB/NFS/SFTP) | Windows, Linux, macOS | gzip/lzo/zstd | ✅ |
| **FOG Project** | Servidor PXE | GPL | Red (PXE boot) | Windows, Linux | gzip | ✅ |
| **Acronis Cyber Backup** | Agente + consola | Comercial | Local + Cloud | Windows, Linux | Propietario | ✅ |
| **Veeam Agent Free** | Agente | Freemium | Local + NFS/SMB | Windows, Linux | zlib | ✅ |
| **Macrium Reflect Free** | GUI Windows | Freemium | Local | Solo Windows | Propietario | ✅ |

**Elección para ResolveCore:**
- **Clonezilla** para intervenciones puntuales (un equipo, USB en mano).
- **FOG Project** para clientes con flotas de equipos (>5 equipos idénticos).
- **Veeam Agent Free** para backups programados en producción (integración con MantisBT vía script).

### Procedimiento estándar (Clonezilla)

```
1. Arrancar equipo desde Clonezilla Live (USB o PXE)
2. Seleccionar "device-image" → "local_dev" o "samba_server"
3. Elegir partición/disco origen
4. Comprimir imagen: zstd (velocidad) o gzip (compatibilidad)
5. Almacenar en NAS, carpeta de red o disco externo
6. Verificar integridad: Clonezilla genera hash MD5/SHA256 automáticamente
7. Documentar imagen: equipo, fecha, SO, estado (limpio/post-instalación/producción)
```

### Procedimiento de restauración

```
1. Arrancar desde Clonezilla Live
2. Seleccionar "restore-disk" o "restore-parts"
3. Apuntar a la imagen almacenada
4. Confirmar disco destino (⚠️ operación destructiva — requiere flag --confirm en ResolveCore)
5. Restaurar y verificar arranque
```

### Casos de uso empresariales

| Escenario | Herramienta | Beneficio |
|-----------|------------|-----------|
| Incorporación de nuevo empleado | FOG Project | Despliegue de imagen corporativa en <20 min |
| Restauración post-ransomware | Clonezilla/Veeam | Vuelta a imagen limpia sin pagar rescate |
| Migración HDD → SSD | Clonezilla | Clonado sector a sector, sin reinstalación |
| Actualización de SO en flota | FOG Project | Imagen actualizada → despliegue masivo en red |
| Backup previo a intervención técnica | Veeam/Clonezilla | Punto de restauración antes de cambios mayores |

---

## 3. Acceso remoto y físico

### Herramientas de acceso remoto

| Herramienta | Licencia | Protocolo | Windows | Linux | Android | ID único | Grabación sesión | GDPR |
|-------------|---------|-----------|---------|-------|---------|----------|-----------------|------|
| **AnyDesk** | Comercial (free personal) | DeskRT (propietario) | ✅ | ✅ | ✅ | ✅ | Pro | Parcial |
| **RustDesk** | AGPL (OSS) | RustDesk (basado en VP9) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (self-hosted) |
| **TeamViewer** | Comercial (free personal, bloqueado long-session) | TV patentado | ✅ | ✅ | ✅ | ✅ | Pro | ✅ |
| **VNC (TigerVNC/RealVNC)** | GPL/Comercial | RFB | ✅ | ✅ | ❌ | ❌ (IP) | RealVNC Pro | Variable |
| **SSH** | N/A (protocolo) | SSH-2 | ✅ (OpenSSH) | ✅ | ❌ GUI | ❌ | Manual | ✅ |
| **Microsoft RDP** | Propietario (incluido Win) | RDP | ✅ | ❌ nativo | ❌ | ❌ (IP) | Win Server | ✅ |

### Decisión para ResolveCore

**Principal:** AnyDesk (free tier para uso personal/educativo). El ID único del dispositivo se almacena como campo personalizado en MantisBT, lo que permite al técnico iniciar la sesión directamente desde el ticket sin necesidad de preguntar al cliente.

**Alternativa GDPR-compliant:** RustDesk con servidor relay propio. Para clientes que requieran que los datos de la sesión no pasen por servidores de terceros. Instalación del servidor relay en el mismo VPS de ResolveCore.

**SSH:** Obligatorio para acceso a servidores Linux sin GUI. Se configura con clave pública (sin contraseña). Tunneling SSH (`-L`) para acceder a servicios internos del cliente durante el diagnóstico.

### Procedimiento de primera conexión AnyDesk

```
1. Cliente descarga AnyDesk portable (sin instalación) desde resolvecore.com/tools
2. Cliente envía su AnyDesk ID al técnico (vía ticket MantisBT o email)
3. Técnico registra AnyDesk ID en campo personalizado del ticket
4. Técnico inicia sesión → cliente aprueba la conexión en pantalla
5. Técnico ejecuta script de diagnóstico en el equipo del cliente
6. Al finalizar: AnyDesk ID queda en el ticket para sesiones de seguimiento
```

### Kit de implantación en cliente

Para clientes recurrentes que contratan suscripción mensual:

```
resolvecore-kit/
├── anydesk-portable.exe         # Sin instalación, cliente lo ejecuta cuando necesite
├── README-cliente.pdf           # Instrucciones de uso (una página)
└── scripts/
    ├── diagnostico-windows.ps1  # Opcional: cliente lo ejecuta antes de llamar
    └── diagnostico-linux.sh     # Idem Linux
```

### SSH — tunneling para diagnóstico

```bash
# Acceder a servicio interno del cliente (ej. panel web en localhost:8080)
ssh -L 8080:localhost:8080 usuario@ip-cliente

# Reenvío dinámico (proxy SOCKS) para navegar por la red interna del cliente
ssh -D 1080 usuario@ip-cliente

# Ejecutar script de diagnóstico remoto sin acceso interactivo
ssh usuario@ip-cliente 'bash -s' < scripts/linux/diagnostico.sh
```

---

## 4. Cifrado de disco

### Windows

| Herramienta | Licencia | TPM requerido | Algoritmo | Recuperación | Caso de uso |
|-------------|---------|--------------|-----------|--------------|-------------|
| **BitLocker** | Incluido Win Pro/Ent | Opcional (recomendado) | AES-128/256-XTS | Clave de recuperación 48 dígitos | Portátiles corporativos |
| **VeraCrypt** | Apache 2.0 (OSS) | No | AES/Twofish/Serpent | Disco de rescate | Multiplataforma, contenedores cifrados |
| **DiskCryptor** | GPL | No | AES/Twofish/Serpent | Clave de rescate | Windows only, sin soporte activo |

**Elección para ResolveCore:**
- **BitLocker** para clientes con Windows Pro/Enterprise y TPM 2.0. Integración nativa, sin software adicional.
- **VeraCrypt** para clientes con Windows Home o cuando se requiere cifrar una partición/contenedor concreto sin cifrar el disco completo.

### Linux

| Herramienta | Integración | Algoritmo | Gestor |
|-------------|-------------|-----------|--------|
| **LUKS (dm-crypt)** | Nativo (kernel) | AES-256-XTS | `cryptsetup` |
| **VeraCrypt** | Multiplataforma | AES/Twofish/Serpent | GUI/CLI |
| **ecryptfs** | Nivel de directorio | AES-256 | `ecryptfs-utils` |

**Elección para ResolveCore:** LUKS para cifrado completo de disco en instalaciones Linux. ecryptfs para cifrar solo el directorio home sin reiniciar.

### Criterios de elección para cliente tipo

```
Empresa con Win Pro/Ent + TPM 2.0 → BitLocker (sin coste adicional)
Usuario doméstico con Win Home    → VeraCrypt (gratuito, open source)
Servidor Linux                    → LUKS (durante instalación del SO)
Portátil Linux sin reinstalar     → VeraCrypt contenedor o ecryptfs home
```

---

## 5. Gestores de contraseñas

### Comparativa

| Gestor | Licencia | Almacenamiento | Sync | 2FA | Compartir | Auditoría | Precio |
|--------|---------|---------------|------|-----|-----------|-----------|--------|
| **Bitwarden** | AGPL (OSS) | Cloud o self-hosted | ✅ | ✅ | ✅ Teams | ✅ | Gratis / 10€/año Premium |
| **KeePass** | GPL | Local (`.kdbx`) | Manual (Dropbox, NAS) | Plugin (KeeOTP) | ❌ nativo | ❌ nativo | Gratis |
| **1Password** | Propietario | Cloud | ✅ | ✅ | ✅ | ✅ | ~3 €/mes |
| **Dashlane** | Propietario | Cloud | ✅ | ✅ | ✅ | ✅ | ~4 €/mes |
| **Keepass XC** | GPL | Local | Manual | ✅ | ❌ | ❌ | Gratis |

### Decisión para clientes ResolveCore

**Usuario doméstico / autónomo:** Bitwarden free. Sync automático, app móvil, extensión navegador. Sin coste.

**Empresa (2-10 personas):** Bitwarden Teams. Compartir contraseñas departamentales de forma segura. Auditoría de accesos.

**Máxima seguridad / sin cloud:** KeePass + base de datos en NAS propio o cifrada con VeraCrypt. Sin dependencia de terceros. Requiere gestión manual del sync.

### Por qué Bitwarden sobre 1Password / Dashlane

1. **Open source:** código auditado públicamente. Historial de auditorías de seguridad independientes (2018, 2020, 2022).
2. **Self-hosted:** opción de instalar Bitwarden/Vaultwarden en VPS propio (opción para clientes con requisitos GDPR estrictos).
3. **Sin coste prohibitivo:** el plan gratuito cubre el 95% de casos domésticos.
4. **Importación desde otros gestores:** migración desde LastPass, 1Password, CSV.

---

## 6. Despliegue de SO por imágenes

### Herramientas

| Herramienta | Tipo | Red/Local | SO soportados | Curva aprendizaje | Coste |
|-------------|------|-----------|--------------|-------------------|-------|
| **FOG Project** | Servidor PXE | Red (LAN) | Windows, Linux | Media | Gratis |
| **Clonezilla Server Edition** | Servidor PXE | Red (LAN) | Windows, Linux, macOS | Alta | Gratis |
| **WDS (Windows Deployment Services)** | Servidor Windows | Red (PXE/TFTP) | Solo Windows | Alta | Incluido Win Server |
| **MDT (Microsoft Deployment Toolkit)** | Herramienta + WDS | Red | Solo Windows | Alta | Gratis |
| **Clonezilla Live** | Live USB | Local | Todos | Baja-Media | Gratis |

### Criterios de elección

```
Flota Windows corporativa grande (>20 equipos) → WDS + MDT (integración AD, GPO)
Flota mixta Windows/Linux (5-50 equipos)       → FOG Project
Un equipo o pocos equipos                       → Clonezilla Live (USB)
Sin servidor dedicado                           → Clonezilla Live
```

### FOG Project — descripción técnica

FOG es un servidor de imágenes de disco que arranca los equipos cliente por PXE, les envía una imagen comprimida por la red y gestiona el inventario de hardware. Componentes:

- **Servidor FOG:** Ubuntu/Debian + Apache + MySQL + TFTP + NFS/FTP
- **Cliente FOG:** agente ligero instalado en cada equipo (inventario, despertado, snapins)
- **Interfaz web:** gestión de hosts, imágenes, grupos, programación

**Flujo de despliegue con FOG:**
```
1. Crear imagen de referencia (equipo maestro)
2. Subir imagen al servidor FOG
3. Asignar imagen a grupo de equipos
4. Programar despliegue (inmediato o programado)
5. Equipos arrancan por PXE → reciben imagen automáticamente
6. Verificar arranque → equipo listo en ~15 min
```

### WDS — descripción técnica

WDS es el servicio de despliegue de Microsoft para entornos con Active Directory. Distribuye imágenes WIM (Windows Image) de forma centralizada:

- **Requisitos:** Windows Server + AD DS + DHCP configurado para PXE
- **Integración:** MDT añade automatización (drivers, aplicaciones, configuración post-instalación)
- **Formato imagen:** `.wim` (Windows Imaging Format) — diferencial, un solo fichero para múltiples variantes

---

## 7. Posición en el catálogo de servicios ResolveCore

| Servicio | Cuándo se ofrece | Precio orientativo | Módulo técnico |
|----------|-----------------|-------------------|----------------|
| Diagnóstico remoto | Siempre (fase 4 del flujo) | Incluido en tarifa base | `diagnostico.ps1` / `diagnostico.sh` |
| Optimización | Tras diagnóstico con problemas de rendimiento | +15 €/intervención | `optimizacion.ps1` / `optimizacion.sh` |
| Clonación de disco | Migración HDD→SSD, backup pre-intervención | 30-60 €/equipo | Clonezilla + procedimiento |
| Congelación de sistema | Entornos multiusuario, aulas, quioscos | 40-80 €/equipo (instalación) | Deep Freeze / BTRFS snapper |
| Despliegue de imagen | Flotas >3 equipos idénticos | 15-30 €/equipo | FOG Project / Clonezilla |
| Acceso remoto AnyDesk | Todas las intervenciones remotas | Incluido | AnyDesk (campo en MantisBT) |
| Cifrado de disco | Portátiles, datos sensibles | 25-40 €/equipo | BitLocker / LUKS / VeraCrypt |
| Gestor de contraseñas | Clientes sin gestión de credenciales | 0-10 €/usuario/año | Bitwarden |
| Auditoría de exposición Shodan | Empresas con IP pública | 30 €/IP/informe | `shodan_lookup.py` |

---

*Documento de referencia para justificación técnica de servicios TFG ASIR 2024/25 — ResolveCore.*
