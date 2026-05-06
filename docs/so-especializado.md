# ResolveCore — SO Especializado para Técnicos

Sistema operativo preconfigurado para técnicos que necesitan el stack completo de ResolveCore listo para trabajar sin configuración manual.

---

## Concepto

El técnico instala el SO base (Ubuntu o Windows) y ejecuta **un único script** que instala y configura automáticamente:

| Componente | Versión | Función |
|------------|---------|---------|
| Nginx | Última LTS | Servidor web |
| PHP | 8.2 | Motor backend |
| MariaDB | 10.11 | Base de datos |
| WordPress | Última | Frontend del soporte |
| MantisBT | 2.27.0 | Gestión de tickets |
| wkhtmltopdf | 0.12.6 | Generación de PDF |
| AnyDesk | Última | Acceso remoto al cliente |
| PowerShell | 7+ | Scripts multiplataforma |
| Scripts ResolveCore | main | Diagnóstico y optimización |

Al terminar el script, el técnico solo necesita:
1. Abrir `http://resolvecore.local/mantis/` → completar wizard MantisBT
2. Abrir `http://resolvecore.local/wp-admin/` → instalar tema + plugin
3. Configurar el API token de MantisBT en el plugin de WordPress

---

## Opción A: Linux (recomendada para producción)

**Base:** Ubuntu Desktop 24.04 LTS

### Instalación rápida

```bash
# Tras instalar Ubuntu desde la ISO oficial, ejecutar como root:
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/Haplee/ResolveCore/main/scripts/iso/linux/post-install.sh)"
```

### Instalación desatendida (autoinstall)

Para instalar Ubuntu + stack completo sin intervención manual:

1. Descarga la ISO de Ubuntu Server 24.04 LTS
2. Arranca el instalador con el parámetro:
   ```
   autoinstall ds=nocloud-net;s=http://TU_SERVIDOR/
   ```
3. Sirve el fichero `scripts/iso/linux/autoinstall.yaml` en `TU_SERVIDOR`
4. El sistema instala Ubuntu y lanza `post-install.sh` automáticamente al primer arranque

### Qué hace `post-install.sh`

```
[✓] Actualiza el sistema
[✓] Instala Nginx
[✓] Instala PHP 8.2 + extensiones
[✓] Instala MariaDB → crea BBs resolvecore_wp + resolvecore_mantis
[✓] Instala WordPress via WP-CLI
[✓] Instala MantisBT 2.27.0
[✓] Configura Nginx (WordPress en / , MantisBT en /mantis/)
[✓] Instala wkhtmltopdf
[✓] Instala PowerShell 7
[✓] Instala AnyDesk
[✓] Clona los scripts de ResolveCore en /opt/resolvecore/
[✓] Configura UFW (firewall)
[✓] Guarda credenciales en /root/resolvecore-credentials.txt
```

**Tiempo estimado:** 10–20 minutos (según velocidad de red)

---

## Opción B: Windows 10/11 (máquina física del técnico)

**Nota:** Microsoft no permite redistribuir ISOs de Windows modificadas con software preinstalado de terceros. La solución es un script que transforma una instalación limpia de Windows en el stack completo.

### Instalación rápida

```powershell
# Ejecutar en PowerShell 7 como Administrador:
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-Expression (Invoke-WebRequest "https://raw.githubusercontent.com/Haplee/ResolveCore/main/scripts/iso/windows/setup.ps1" -UseBasicParsing).Content
```

O ejecutar localmente:

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\iso\windows\setup.ps1
```

### Qué hace `setup.ps1`

```
[✓] Instala Chocolatey (gestor de paquetes)
[✓] Instala PHP 8.2 + extensiones
[✓] Instala Nginx → registrado como servicio Windows (NSSM)
[✓] Instala MariaDB → crea BBs resolvecore_wp + resolvecore_mantis
[✓] Instala WordPress via WP-CLI
[✓] Instala MantisBT 2.27.0
[✓] Instala wkhtmltopdf
[✓] Instala AnyDesk
[✓] Clona los scripts de ResolveCore en C:\ResolveCore\scripts\
[✓] Configura hosts local: resolvecore.local
[✓] Guarda credenciales en C:\ResolveCore\credenciales.txt
```

**Tiempo estimado:** 15–30 minutos

---

## Estructura generada post-instalación

### Linux
```
/opt/resolvecore/
├── linux/
│   ├── diagnostico.sh
│   └── optimizacion.sh
├── windows/
│   ├── diagnostico.ps1
│   └── optimizacion.ps1
├── macos/
└── android/
/var/www/
├── wordpress/       ← WordPress
└── mantis/          ← MantisBT
/root/resolvecore-credentials.txt   ← Credenciales (solo root)
```

### Windows
```
C:\ResolveCore\
├── www\
│   ├── wordpress\
│   └── mantis\
├── scripts\
│   ├── linux\
│   ├── windows\
│   ├── macos\
│   └── android\
├── credenciales.txt
└── install.log
```

---

## Credenciales generadas automáticamente

Ambos scripts generan contraseñas aleatorias y seguras para:
- Root de MariaDB
- Usuario de BD de WordPress
- Usuario de BD de MantisBT
- Admin de WordPress

Las credenciales se guardan en:
- **Linux:** `/root/resolvecore-credentials.txt` (permisos 600, solo root)
- **Windows:** `C:\ResolveCore\credenciales.txt`

---

## Requisitos del sistema

| | Linux | Windows |
|---|---|---|
| OS | Ubuntu 22.04 / 24.04 LTS | Windows 10/11 Pro |
| RAM | 2 GB mínimo (4 GB recomendado) | 4 GB mínimo (8 GB recomendado) |
| Disco | 20 GB libres | 30 GB libres |
| Red | Acceso a Internet durante instalación | Acceso a Internet durante instalación |
| Privilegios | root / sudo | Administrador |

---

## Ficheros

| Fichero | Descripción |
|---------|-------------|
| `scripts/iso/linux/post-install.sh` | Script de instalación completa para Ubuntu/Debian |
| `scripts/iso/linux/autoinstall.yaml` | Preseed para instalación desatendida Ubuntu 24.04 |
| `scripts/iso/windows/setup.ps1` | Script de instalación completa para Windows 10/11 |
