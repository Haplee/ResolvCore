<?php
/* Template Name: ResolveCore Docs */
get_header();
?>

<!-- Barra de progreso de lectura -->
<div class="rc-docs-progress" id="rc-docs-progress" aria-hidden="true"></div>

<div class="rc-docs-layout">
	<aside class="rc-docs-sidebar">
	<div class="rc-docs-logo">
		<img src="<?php echo esc_url( get_template_directory_uri() ); ?>/assets/logo/resolvcore-logo-dark.png"
			alt="ResolveCore" class="rc-docs-logo-img" width="160" height="40">
	</div>
	<ul class="rc-docs-nav">
		<li><a href="#intro" class="active">Introducción</a></li>
		<li><a href="#instalacion">Instalación</a></li>
		<li><a href="#uso">Uso</a></li>
		<li><a href="#modulos">Módulos</a></li>
		<li><a href="#json">Salida JSON</a></li>
		<li><a href="#faq">FAQ</a></li>
	</ul>
	</aside>

	<main class="rc-docs-main" id="main-content">
	<header class="rc-docs-header">
		<h1 class="rc-docs-title">Documentación</h1>
		<p class="rc-docs-subtitle">ResolveCore v1.2.0-beta — Guía de uso de la suite de diagnóstico</p>
	</header>

	<section id="intro" class="rc-docs-section">
		<h2 class="rc-docs-h2">Introducción</h2>
		<p class="rc-docs-p">
		ResolveCore es una plataforma de soporte técnico remoto para <strong>Windows, Linux y Android</strong>.
		Estructura el servicio en 7 fases: solicitud &rarr; ticket (MantisBT) &rarr; conexión remota (AnyDesk)
		&rarr; diagnóstico (PowerShell / Bash / Python) &rarr; resolución &rarr; informe <code>.txt</code> &rarr; facturación.
		</p>
		<p class="rc-docs-p">
		<strong>Requisitos:</strong> Windows 10/11 (PowerShell 5.1, ya incluido), Ubuntu 20.04+ / Debian 11+ (Bash 4+),
		o Android 10+ con depuración ADB. El escáner de vulnerabilidades necesita Python 3.8+ (solo stdlib, sin <code>pip</code>).
		</p>
		<div class="rc-callout rc-callout--info">
		<span class="rc-callout-i">i</span>
		<div>Todo el código es software libre bajo <strong>GNU GPL-3.0</strong>. Las APIs de vulnerabilidades
		(NVD, CISA KEV, OSV) son públicas y auditables.</div>
		</div>
	</section>

	<section id="instalacion" class="rc-docs-section">
		<h2 class="rc-docs-h2">Instalación</h2>
		<p class="rc-docs-p">No requiere instalación: se clona el repositorio y se lanza el menú interactivo de tu plataforma.</p>

		<div class="rc-os-tabs" role="tablist" aria-label="Plataforma">
		<button class="rc-os-tab active" role="tab" aria-selected="true"  data-os="win">⊞ Windows</button>
		<button class="rc-os-tab"        role="tab" aria-selected="false" data-os="lin">☰ Linux</button>
		<button class="rc-os-tab"        role="tab" aria-selected="false" data-os="and">◈ Android</button>
		</div>

		<div class="rc-os-panel active" data-os="win">
		<div class="rc-code-header">
			<span>PowerShell — como Administrador</span>
			<button class="rc-copy-btn" onclick="copyCode(this)">Copy</button>
		</div>
		<div class="rc-code-block"><code>git clone https://github.com/Haplee/ResolveCore.git
cd ResolveCore

# Menu interactivo (diagnostico, optimizacion, vulnerabilidades, informe, servicios)
.\scripts\windows\ResolveCore.ps1</code></div>
		</div>

		<div class="rc-os-panel" data-os="lin">
		<div class="rc-code-header">
			<span>Terminal — Ubuntu / Debian</span>
			<button class="rc-copy-btn" onclick="copyCode(this)">Copy</button>
		</div>
		<div class="rc-code-block"><code># Dependencias opcionales (S.M.A.R.T. + JSON)
sudo apt install -y smartmontools jq

git clone https://github.com/Haplee/ResolveCore.git
cd ResolveCore

# Menu interactivo
bash scripts/linux/ResolveCore.sh</code></div>
		</div>

		<div class="rc-os-panel" data-os="and">
		<div class="rc-code-header">
			<span>Bash — requiere ADB habilitado en el dispositivo</span>
			<button class="rc-copy-btn" onclick="copyCode(this)">Copy</button>
		</div>
		<div class="rc-code-block"><code># Verificar dispositivo conectado por ADB
adb devices

git clone https://github.com/Haplee/ResolveCore.git
cd ResolveCore

# Menu interactivo (sobre el dispositivo conectado)
bash scripts/android/ResolveCore.sh</code></div>
		</div>
	</section>

	<section id="uso" class="rc-docs-section">
		<h2 class="rc-docs-h2">Uso</h2>
		<p class="rc-docs-p">
		El launcher abre un menú; también puedes invocar cada script directamente. Con <code>--ticket &lt;N&gt;</code>
		las salidas se organizan en <code>reparaciones/&lt;NNNNN&gt;/</code> por número de incidencia de MantisBT.
		</p>

		<h3 class="rc-docs-h3">Diagnóstico</h3>
		<div class="rc-code-block"><code># Windows — genera JSON + imprime un resumen legible
.\scripts\windows\diagnostico.ps1 -Ticket 42

# Linux
bash scripts/linux/diagnostico.sh --ticket 42</code></div>

		<h3 class="rc-docs-h3">Vulnerabilidades</h3>
		<div class="rc-code-block"><code># Escaneo CVE multi-feed (NVD + CISA KEV + OSV). Exporta JSON limpio.
python scripts/common/buscar_vulnerabilidades.py --plataforma windows --salida-json vuln.json
# Tras el escaneo, el launcher ofrece un menu de desinstalacion del software vulnerable.</code></div>

		<h3 class="rc-docs-h3">Optimización</h3>
		<div class="rc-code-block"><code>bash scripts/linux/optimizacion.sh --dry-run   # previsualiza, no aplica nada
bash scripts/linux/optimizacion.sh             # aplica y guarda el estado previo
bash scripts/linux/optimizacion.sh --undo      # revierte al estado guardado</code></div>

		<h3 class="rc-docs-h3">Informe técnico</h3>
		<div class="rc-code-block"><code># Genera la plantilla .txt pre-rellenada desde el diagnostico
python scripts/common/generar_informe.py --json diagnostico.json --ticket 42</code></div>

		<div class="rc-callout rc-callout--warn">
		<span class="rc-callout-i">!</span>
		<div>Las acciones destructivas (desinstalar, limpiar) exigen selección y confirmación explícita.
		El <strong>Spooler de impresión</strong> (Windows) y <strong>cups</strong> (Linux) se reportan pero
		<strong>nunca se tocan</strong>.</div>
		</div>
	</section>

	<section id="modulos" class="rc-docs-section">
		<h2 class="rc-docs-h2">Módulos</h2>

		<div class="rc-module-grid">
		<div class="rc-module-card">
			<div class="rc-module-icon">⬡</div>
			<div class="rc-module-name">01 — Diagnóstico</div>
			<div class="rc-module-desc">CPU, RAM, discos, servicios críticos, red, S.M.A.R.T., uptime y seguridad. JSON estructurado + resumen en terminal.</div>
		</div>
		<div class="rc-module-card">
			<div class="rc-module-icon">◈</div>
			<div class="rc-module-name">02 — Vulnerabilidades</div>
			<div class="rc-module-desc">CVE multi-feed (NVD · CISA KEV · OSV). Filtra avisos KEV/CVSS≥7.0 y ofrece menú de desinstalación seguro.</div>
		</div>
		<div class="rc-module-card">
			<div class="rc-module-icon">◇</div>
			<div class="rc-module-name">03 — Optimización</div>
			<div class="rc-module-desc">Limpieza de temporales y servicios con <code>--dry-run</code> y <code>--undo</code>. Spooler/cups siempre excluidos.</div>
		</div>
		<div class="rc-module-card">
			<div class="rc-module-icon">⬡</div>
			<div class="rc-module-name">04 — Informe .txt</div>
			<div class="rc-module-desc">Plantilla de texto plano pre-rellenada desde el diagnóstico; el técnico la completa a mano y la sube al ticket.</div>
		</div>
		<div class="rc-module-card">
			<div class="rc-module-icon">◈</div>
			<div class="rc-module-name">05 — Servicios</div>
			<div class="rc-module-desc">Congelación (Reboot Restore Rx / BTRFS+snapper), clonación con verificación SHA-256 y kit de implantación.</div>
		</div>
		<div class="rc-module-card">
			<div class="rc-module-icon">◇</div>
			<div class="rc-module-name">06 — Multiplataforma</div>
			<div class="rc-module-desc">Windows, Linux y Android (vía ADB) con paridad funcional. macOS está en el roadmap.</div>
		</div>
		</div>
	</section>

	<section id="json" class="rc-docs-section">
		<h2 class="rc-docs-h2">Salida JSON</h2>
		<p class="rc-docs-p">
		Cada diagnóstico guarda un JSON con estructura plana. El esquema completo vive en
		<code>docs/scripting/schema-diagnostico.md</code>. Ejemplo (Windows, recortado):
		</p>

		<div class="rc-code-block"><code>{
  "_meta":    { "plataforma": "windows", "hostname": "PC-CLIENTE", "version": "2.1" },
  "timestamp": "2026-06-04T12:00:00",
  "sistema":  { "nombre": "Windows 11 Pro", "build": "26100", "uptime_horas": 52.3 },
  "cpu":      { "name": "Intel Core i7-12700H", "cores": 12, "load": 8 },
  "ram":      { "total_gb": 16, "free_gb": 9.3 },
  "discos":   [ { "drive": "C:", "total_gb": 512, "free_gb": 67 } ],
  "servicios_criticos": [ { "nombre": "Spooler", "estado": "Running" } ],
  "seguridad": { "defender_activo": true, "firewall": true, "uac": true },
  "red":      { "ip": "192.0.2.15", "gateway": "192.0.2.1", "puertos_escucha": [135, 445] },
  "actualizaciones": { "pendientes": 7 }
}</code></div>

		<h3 class="rc-docs-h3">Leer el último diagnóstico (Bash)</h3>
		<div class="rc-code-header">
		<span>Bash</span>
		<button class="rc-copy-btn" onclick="copyCode(this)">Copy</button>
		</div>
		<div class="rc-code-block"><code>REPORT=$(ls -t reparaciones/*/diagnostico.json | head -1)
jq '.servicios_criticos[] | select(.estado != "Running")' "$REPORT"</code></div>
	</section>

	<section id="faq" class="rc-docs-section">
		<h2 class="rc-docs-h2">FAQ</h2>

		<h3 class="rc-docs-h3">¿ResolveCore es de pago?</h3>
		<p class="rc-docs-p">El software es libre y gratuito (GPL-3.0). Lo que se factura es la intervención del técnico, gestionada desde MantisBT.</p>

		<h3 class="rc-docs-h3">¿Bajo qué licencia está?</h3>
		<p class="rc-docs-p">GNU General Public License v3.0. El código de diagnóstico y el escáner CVE son auditables.</p>

		<h3 class="rc-docs-h3">¿En qué formato entrega el informe?</h3>
		<p class="rc-docs-p">Una plantilla de texto plano (<code>.txt</code>) que el técnico rellena a mano y sube a tu ticket. No se genera PDF.</p>

		<h3 class="rc-docs-h3">¿Dónde reporto un fallo?</h3>
		<p class="rc-docs-p">Abre un issue en <a href="https://github.com/Haplee/ResolveCore">GitHub</a>.</p>
	</section>
	</main>
</div>

<style>
	/* ---- Barra de progreso de lectura ---- */
	.rc-docs-progress {
		position: fixed; top: 0; left: 0; height: 3px; width: 0;
		background: var(--rc-accent); z-index: 1000;
		box-shadow: 0 0 8px rgba(0,229,160,.5); transition: width .1s linear;
	}
	/* ---- Nav lateral: punto activo (scroll-spy) ---- */
	.rc-docs-nav a { position: relative; transition: color .2s, background-color .2s; }
	.rc-docs-nav a.active::before {
		content: ''; position: absolute; left: -10px; top: 50%; transform: translateY(-50%);
		width: 3px; height: 16px; border-radius: 2px; background: var(--rc-accent);
	}
	/* ---- Tabs de SO en Instalacion ---- */
	.rc-os-tabs { display: flex; gap: .5rem; margin: 0 0 1rem; flex-wrap: wrap; }
	.rc-os-tab {
		font-family: var(--rc-mono); font-size: 12px; cursor: pointer;
		color: var(--rc-muted); background: transparent;
		border: 1px solid var(--rc-border2); border-radius: 6px; padding: 8px 16px;
		transition: color .2s, border-color .2s, background-color .2s;
	}
	.rc-os-tab:hover { color: var(--rc-text); border-color: var(--rc-accent); }
	.rc-os-tab.active { color: #000; background: var(--rc-accent); border-color: var(--rc-accent); font-weight: 700; }
	.rc-os-panel { display: none; animation: rcDocFade .25s ease both; }
	.rc-os-panel.active { display: block; }
	@keyframes rcDocFade { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }
	/* ---- Callouts ---- */
	.rc-callout {
		display: flex; gap: .9rem; align-items: flex-start;
		border: 1px solid var(--rc-border2); border-left-width: 3px;
		border-radius: 8px; padding: 1rem 1.1rem; margin: 1.25rem 0;
		font-size: 13.5px; line-height: 1.6; color: var(--rc-muted);
		background: var(--rc-surface2);
	}
	.rc-callout div strong { color: var(--rc-text); }
	.rc-callout-i {
		flex: none; width: 20px; height: 20px; border-radius: 50%;
		display: flex; align-items: center; justify-content: center;
		font-family: var(--rc-mono); font-size: 12px; font-weight: 700; margin-top: 1px;
	}
	.rc-callout--info { border-left-color: var(--rc-accent); }
	.rc-callout--info .rc-callout-i { background: rgba(0,229,160,.15); color: var(--rc-accent); }
	.rc-callout--warn { border-left-color: #febc2e; }
	.rc-callout--warn .rc-callout-i { background: rgba(254,188,46,.15); color: #febc2e; }
	/* ---- Rejilla de modulos ---- */
	.rc-module-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 1rem; }
	.rc-module-card { transition: transform .25s ease, border-color .25s ease; }
	.rc-module-card:hover { transform: translateY(-3px); border-color: var(--rc-accent); }
	.rc-module-card code { font-family: var(--rc-mono); color: var(--rc-accent); font-size: 12px; }
	/* ---- Copy con check ---- */
	.rc-copy-btn.done { color: var(--rc-accent); border-color: var(--rc-accent); }
	@media (max-width: 760px) {
		.rc-module-grid { grid-template-columns: 1fr; }
	}
</style>

<script>
(function () {
	/* Copiar bloque de codigo + feedback visual */
	window.copyCode = function (btn) {
		var block = btn.closest('.rc-code-header').nextElementSibling;
		if (!block) { return; }
		navigator.clipboard.writeText(block.textContent.trim());
		btn.textContent = '✓ Copied';
		btn.classList.add('done');
		setTimeout(function () { btn.textContent = 'Copy'; btn.classList.remove('done'); }, 1800);
	};

	/* Tabs de SO: alterna paneles por data-os */
	document.querySelectorAll('.rc-os-tab').forEach(function (tab) {
		tab.addEventListener('click', function () {
			var os = tab.getAttribute('data-os');
			document.querySelectorAll('.rc-os-tab').forEach(function (t) {
				var on = t === tab;
				t.classList.toggle('active', on);
				t.setAttribute('aria-selected', on ? 'true' : 'false');
			});
			document.querySelectorAll('.rc-os-panel').forEach(function (p) {
				p.classList.toggle('active', p.getAttribute('data-os') === os);
			});
		});
	});

	/* Scroll suave del nav lateral */
	var navLinks = document.querySelectorAll('.rc-docs-nav a');
	navLinks.forEach(function (link) {
		link.addEventListener('click', function (e) {
			e.preventDefault();
			var el = document.getElementById(link.getAttribute('href').slice(1));
			if (el) { el.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
		});
	});

	/* Scroll-spy: resalta la seccion visible en el nav (IntersectionObserver) */
	var sections = document.querySelectorAll('.rc-docs-section');
	var spy = new IntersectionObserver(function (entries) {
		entries.forEach(function (entry) {
			if (!entry.isIntersecting) { return; }
			var id = entry.target.id;
			navLinks.forEach(function (a) {
				a.classList.toggle('active', a.getAttribute('href') === '#' + id);
			});
		});
	}, { rootMargin: '-30% 0px -60% 0px' });
	sections.forEach(function (s) { spy.observe(s); });

	/* Barra de progreso de lectura */
	var bar = document.getElementById('rc-docs-progress');
	function updateProgress() {
		var h = document.documentElement;
		var max = h.scrollHeight - h.clientHeight;
		var pct = max > 0 ? (h.scrollTop / max) * 100 : 0;
		bar.style.width = pct + '%';
	}
	window.addEventListener('scroll', updateProgress, { passive: true });
	updateProgress();
})();
</script>

<?php get_footer(); ?>
