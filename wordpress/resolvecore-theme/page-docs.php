<?php
/* Template Name: ResolveCore Docs */
get_header();
?>


<div class="rc-docs-layout">
  <aside class="rc-docs-sidebar">
    <div class="rc-docs-logo">
      <img src="<?php echo get_template_directory_uri(); ?>/assets/logo/resolvcore-logo-dark.png"
           alt="ResolveCore" class="rc-docs-logo-img" width="160" height="40">
    </div>
    <ul class="rc-docs-nav">
      <li><a href="#intro" class="active">Introducción</a></li>
      <li><a href="#instalacion">Instalación</a></li>
      <li><a href="#uso">Uso</a></li>
      <li><a href="#modulos">Módulos</a></li>
      <li><a href="#api">API</a></li>
      <li><a href="#faq">FAQ</a></li>
    </ul>
  </aside>

  <main class="rc-docs-main">
    <header class="rc-docs-header">
      <h1 class="rc-docs-title">Documentación</h1>
      <p class="rc-docs-subtitle">ResolveCore v1.0.0 — Guía completa de usuario</p>
    </header>

    <section id="intro" class="rc-docs-section">
      <h2 class="rc-docs-h2">Introducción</h2>
      <p class="rc-docs-p">
        ResolveCore es una plataforma cross-platform de mantenimiento y optimización para Windows, Linux y Android.
        El proyecto incluye diagnóstico automatizado, análisis de vulnerabilidades y proyección de vida útil del hardware.
      </p>
      <p class="rc-docs-p">
        <strong>Requisitos del sistema:</strong> Windows 10/11, Ubuntu 20.04+ / Debian 11+, o Android 10+.
      </p>
    </section>

    <section id="instalacion" class="rc-docs-section">
      <h2 class="rc-docs-h2">Instalación</h2>
      <p class="rc-docs-p">Selecciona tu plataforma:</p>

      <h3 class="rc-docs-h3">Windows</h3>
      <div class="rc-code-header">
        <span>PowerShell — Ejecutar como Administrador</span>
        <button class="rc-copy-btn" onclick="copyCode(this)">Copy</button>
      </div>
      <div class="rc-code-block"><code># Clonar el repositorio
git clone https://github.com/Haplee/ResolveCore.git
cd ResolveCore

# Menú interactivo (diagnóstico + optimización)
.\scripts\windows\ResolveCore.ps1

# O ejecutar scripts individuales
.\scripts\windows\diagnostico.ps1
.\scripts\windows\optimizacion.ps1</code></div>

      <h3 class="rc-docs-h3">Linux (Ubuntu / Debian)</h3>
      <div class="rc-code-header">
        <span>Terminal</span>
        <button class="rc-copy-btn" onclick="copyCode(this)">Copy</button>
      </div>
      <div class="rc-code-block"><code># Instalar dependencias opcionales (S.M.A.R.T.)
sudo apt install -y smartmontools

# Clonar el repositorio
git clone https://github.com/Haplee/ResolveCore.git
cd ResolveCore

# Menú interactivo
bash scripts/linux/ResolveCore.sh

# O ejecutar scripts individuales
bash scripts/linux/diagnostico.sh
bash scripts/linux/optimizacion.sh</code></div>

      <h3 class="rc-docs-h3">Android (vía ADB)</h3>
      <div class="rc-code-header">
        <span>Bash — Requiere ADB habilitado en el dispositivo</span>
        <button class="rc-copy-btn" onclick="copyCode(this)">Copy</button>
      </div>
      <div class="rc-code-block"><code># Verificar dispositivo conectado
adb devices

# Ejecutar diagnóstico
bash scripts/android/diagnostico.sh

# Menú interactivo
bash scripts/android/ResolveCore.sh</code></div>
    </section>

    <section id="uso" class="rc-docs-section">
      <h2 class="rc-docs-h2">Uso</h2>
      <p class="rc-docs-p">
        ResolveCore puede ejecutarse desde línea de comandos o mediante la interfaz gráfica.
      </p>

      <h3 class="rc-docs-h3">Línea de comandos</h3>
      <div class="rc-code-block"><code># Diagnóstico completo
resolvecore --scan --full

# Escaneo de vulnerabilidades
resolvecore --vuln-scan

# Proyección de hardware
resolvecore --hardware-check

# Optimización
resolvecore --optimize --safe</code></div>

      <h3 class="rc-docs-h3">Interfaz gráfica</h3>
      <p class="rc-docs-p">
        Ejecuta <code>resolvecore-gui</code> (Linux) o haz doble clic en el acceso directo (Windows/Android).
        La interfaz permite gestionar todos los dispositivos desde un panel unificado.
      </p>
    </section>

    <section id="modulos" class="rc-docs-section">
      <h2 class="rc-docs-h2">Módulos</h2>

      <div class="rc-module-card">
        <div class="rc-module-icon">⬡</div>
        <div class="rc-module-name">01 — Diagnóstico automatizado</div>
        <div class="rc-module-desc">Análisis completo del sistema en segundos. Escanea CPU, RAM y almacenamiento.</div>
      </div>
      <div class="rc-module-card">
        <div class="rc-module-icon">◈</div>
        <div class="rc-module-name">02 — Proyección de vida útil</div>
        <div class="rc-module-desc">Algoritmos predictivos que estiman cuándo podrían fallar los componentes.</div>
      </div>
      <div class="rc-module-card">
        <div class="rc-module-icon">⬡</div>
        <div class="rc-module-name">03 — Análisis de vulnerabilidades</div>
        <div class="rc-module-desc">Escanea el SO contra una base de datos de CVEs actualizada.</div>
      </div>
      <div class="rc-module-card">
        <div class="rc-module-icon">◇</div>
        <div class="rc-module-name">04 — Optimización del sistema</div>
        <div class="rc-module-desc">Limpieza profunda, desfragmentación y gestión de servicios.</div>
      </div>
      <div class="rc-module-card">
        <div class="rc-module-icon">⬡</div>
        <div class="rc-module-name">05 — Panel multiplataforma</div>
        <div class="rc-module-desc">Gestiona Windows, Linux y Android desde una única interfaz.</div>
      </div>
      <div class="rc-module-card">
        <div class="rc-module-icon">◈</div>
        <div class="rc-module-name">06 — Actualizaciones automáticas</div>
        <div class="rc-module-desc">Mantén todos tus sistemas al día con actualizaciones silenciosas.</div>
      </div>
    </section>

    <section id="api" class="rc-docs-section">
      <h2 class="rc-docs-h2">Salida JSON</h2>
      <p class="rc-docs-p">
        Los scripts generan un archivo JSON estructurado en
        <code>scripts/diagnosticos/&lt;timestamp&gt;_&lt;plataforma&gt;.json</code>.
        Este archivo alimenta el generador de informes PDF.
      </p>

      <h3 class="rc-docs-h3">Estructura del JSON de diagnóstico</h3>
      <div class="rc-code-block"><code>{
  "timestamp": "2026-05-06T12:00:00",
  "platform":  "windows",
  "version":   "1.0.0",
  "system":  { "os": "Windows 11 Pro", "hostname": "PC-USUARIO", "uptime": "2d 4h" },
  "cpu":     { "model": "Intel Core i7-12700H", "cores": 12, "load_pct": 8 },
  "ram":     { "total_gb": 16, "used_gb": 6.7, "free_gb": 9.3 },
  "disk":    [ { "name": "C:", "total_gb": 512, "used_gb": 443, "health": "OK" } ],
  "smart":   { "reallocated_sectors": 0, "temp_celsius": 54, "health_pct": 94 },
  "network": { "interfaces": [], "open_ports": [] },
  "vulnerabilities": [
    { "cve": "CVE-2024-3049", "severity": "CRITICAL", "fixed": false }
  ],
  "optimization": { "temp_gb": 4.2, "startup_items": 23 }
}</code></div>

      <h3 class="rc-docs-h3">Leer el último diagnóstico (PowerShell)</h3>
      <div class="rc-code-header">
        <span>PowerShell</span>
        <button class="rc-copy-btn" onclick="copyCode(this)">Copy</button>
      </div>
      <div class="rc-code-block"><code>$report = Get-Content .\scripts\diagnosticos\*.json |
          Sort-Object LastWriteTime -Descending |
          Select-Object -First 1 |
          Get-Content | ConvertFrom-Json
$report.cpu.load_pct
$report.vulnerabilities | Where-Object { $_.severity -eq 'CRITICAL' }</code></div>

      <h3 class="rc-docs-h3">Leer el último diagnóstico (Bash)</h3>
      <div class="rc-code-header">
        <span>Bash</span>
        <button class="rc-copy-btn" onclick="copyCode(this)">Copy</button>
      </div>
      <div class="rc-code-block"><code>REPORT=$(ls -t scripts/diagnosticos/*.json | head -1)
cat "$REPORT" | python3 -m json.tool
# O con jq:
jq '.vulnerabilities[] | select(.severity=="CRITICAL")' "$REPORT"</code></div>
    </section>

    <section id="faq" class="rc-docs-section">
      <h2 class="rc-docs-h2">FAQ</h2>

      <h3 class="rc-docs-h3">¿ResolveCore es gratuito?</h3>
      <p class="rc-docs-p">Sí, la versión básica es gratuita. Los planes Pro y Enterprise incluyen funciones adicionales.</p>

      <h3 class="rc-docs-h3">¿Puedo usar ResolveCore en producción?</h3>
      <p class="rc-docs-p">Sí, el código está bajo licencia MIT. Se recomienda probar primero en entorno de pruebas.</p>

      <h3 class="rc-docs-h3">¿Dónde puedo reportar bugs?</h3>
      <p class="rc-docs-p">Abre un issue en <a href="https://github.com/Haplee/ResolveCore">GitHub</a>.</p>
    </section>
  </main>
</div>

<script>
function copyCode(btn) {
  const code = btn.closest('.rc-code-header').nextElementSibling.textContent;
  navigator.clipboard.writeText(code.trim());
  btn.textContent = 'Copied!';
  setTimeout(() => btn.textContent = 'Copy', 2000);
}

// Smooth scroll para el sidebar
document.querySelectorAll('.rc-docs-nav a').forEach(link => {
  link.addEventListener('click', e => {
    e.preventDefault();
    const id = link.getAttribute('href').slice(1);
    document.getElementById(id).scrollIntoView({ behavior: 'smooth' });
    document.querySelectorAll('.rc-docs-nav a').forEach(a => a.classList.remove('active'));
    link.classList.add('active');
  });
});
</script>

<?php get_footer(); ?>