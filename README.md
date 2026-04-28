<div align="center">

# ⚙️ ResolveCore

### Plataforma de mantenimiento, diagnóstico y optimización de equipos informáticos

*Solución a tus problemas informáticos.*

<br/>

![WordPress](https://img.shields.io/badge/WordPress-21759B?style=for-the-badge&logo=wordpress&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-777BB4?style=for-the-badge&logo=php&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![ASIR](https://img.shields.io/badge/ASIR-8.4%2F10-3B82F6?style=flat-square)

</div>

---

## ✨ Características

| | Descripción |
|---|-------------|
| � **Diagnóstico** | Análisis automatizado con puntuación 0-100 por categorías |
| 🔒 **Vulnerabilidades** | Cruza software contra base CVE/NVD del NIST |
| ⏳ **Vida útil** | Estima lifespan de componentes (S.M.A.R.T., temperatura, batería) |
| 🎮 **Demo interactiva** | Prueba el diagnóstico en tiempo real desde la web |
| 📄 **PDF** | Informes técnicos y resumen para el cliente |
| 🌐 **Multiplataforma** | Scripts para Windows, Linux, macOS y Android |

---

## 🖥️ Capturas

| Sección | Descripción |
|---------|-------------|
| Landing | Hero animado con grid, partículas y estadísticas |
| Demo | Terminal interactiva con 4 escenarios |
| Docs | Documentación con sidebar y código copiable |
| Changelog | Timeline de versiones |
| Contacto | Formulario AJAX con validación |

---

## 📦 Instalación

### Requisitos

- WordPress 6.0+
- PHP 8.x
- MySQL / MariaDB

### Pasos

```bash
# 1. Copiar tema a WordPress
cp -r wordpress/resolvecore-theme/ wp-content/themes/

# 2. Activar desde WordPress
# Apariencia > Temas > ResolveCore

# 3. Crear páginas
# Docs     → Plantilla: ResolveCore Docs
# Changelog → Plantilla: ResolveCore Changelog
```

---

## 📂 Estructura

```
ResolveCore/
├── wordpress/
│   ├── resolvecore-theme/     # Tema WordPress
│   │   ├── front-page.php    # Landing con demo
│   │   ├── page-docs.php    # Documentación
│   │   ├── page-changelog.php # Historial versiones
│   │   ├── functions.php    # Funcionalidad PHP
│   │   ├── style.css        # Estilos (dark, mono)
│   │   └── index.php
│   └── page-resolvecore.php
├── scripts/
│   ├── windows/    #diagnostico.ps1, optimizacion.ps1
│   ├── linux/      #diagnostico.sh, optimizacion.sh
│   ├── macos/     #diagnostico.sh, optimizacion.sh
│   └── android/   #diagnostico.sh, optimizacion.sh
└── notes/
    ├── PROPUESTA DE PROYECTO INTEGRADO.md
    ├── Plan de desarrollo.md
    └── analiza.md
```

---

## 🛠️ Scripts de Diagnóstico

### Windows
```powershell
.\scripts\windows\diagnostico.ps1
```

### Linux
```bash
bash scripts/linux/diagnostico.sh
```

### macOS
```bash
bash scripts/macos/diagnostico.sh
```

### Android
```bash
# Requiere ADB habilitado
bash scripts/android/diagnostico.sh
```

---

## 🎯 Valoración ASIR

| Criterio | Puntuación |
|----------|------------|
| Funcionalidad | 9/10 |
| Código (PHP) | 8.5/10 |
| Seguridad | 8.5/10 |
| Base de datos | 8.5/10 |
| Documentación | 8.5/10 |
| **TOTAL** | **8.4/10** |

---

## 📚 Módulos ASIR Cubiertos

| Módulo | Estado |
|--------|--------|
| Gestión de BD + Admin. SGBD | ✅ |
| Servicios en Red + Implantación Apps Web | ✅ |
| Lenguajes de Marca (HTML/CSS) | ✅ |
| FOL + Empresa | ✅ |
| Administración de SO | ✅ |
| Fundamentos Hardware | ✅ |
| Planificación Redes | ✅ |
| Seguridad | ✅ |

---

## 👤 Autor

<div align="center">

### Francisco Vidal Mateo

**Desarrollador Full Stack · Técnico Superior en ASIR**

Proyecto Integrado — IES Trafalgar, Barbate, Cádiz

---

| | |
|---|---|
| 🌍 | **Ubicación:** Barbate, Cádiz, España |
| 🎓 | **Especialidad:** Administración de Sistemas Informáticos en Red |
| 🛠️ | **Stack:** WordPress, PHP, MySQL |

---

**Contacto**

[![GitHub](https://img.shields.io/badge/GitHub-Haplee-181717?style=for-the-badge&logo=github)](https://github.com/Haplee)
[![X](https://img.shields.io/badge/X-@FranVidalMateo-000000?style=for-the-badge&logo=x)](https://x.com/FranVidalMateo)
[![Email](https://img.shields.io/badge/Email-franvidalmateo@gmail.com-D14836?style=for-the-badge&logo=gmail)](mailto:franvidalmateo@gmail.com)

---

*ResolveCore fue desarrollado como proyecto final del ciclo formativo ASIR.*

> *"Solución a tus problemas informáticos."*

</div>