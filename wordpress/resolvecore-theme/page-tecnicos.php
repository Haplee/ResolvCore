<?php
/* Template Name: Área de Técnicos */

// Redirige a login si no está autenticado
if ( ! is_user_logged_in() ) {
	wp_redirect( wp_login_url( get_permalink() ) );
	exit;
}

// Solo roles técnico / administrador
if ( ! current_user_can( 'editor' ) && ! current_user_can( 'administrator' ) ) {
	wp_die(
		'<p>Acceso restringido al área de técnicos. Contacta con el administrador.</p>',
		'Sin acceso',
		array( 'response' => 403 )
	);
}

$version     = '1.0.0';
$build_date  = '2026-05-25';
$dl_base     = home_url( '/tecnicos/' );

$downloads = array(
	'windows' => array(
		'label'   => 'Windows — install-servicios.ps1',
		'size'    => '~12 KB',
		'desc'    => 'Instala: Chocolatey · WSL · jq · AnyDesk portable',
		'oneliner'=> 'iwr -useb https://resolvecore.website/downloads/install-servicios.ps1 | iex',
		'note'    => 'Requiere PowerShell como Administrador',
	),
	'linux' => array(
		'label'   => 'Linux — install-servicios.sh',
		'size'    => '~6 KB',
		'desc'    => 'Instala: jq · curl · btrfs-progs · snapper. Compatible: Ubuntu 22.04+, Debian 11+, Fedora 37+, Arch.',
		'oneliner'=> 'curl -sSL https://resolvecore.website/downloads/install-servicios.sh | bash',
		'note'    => 'Puede requerir sudo. El script lo pide cuando es necesario.',
	),
	'kit' => array(
		'label'   => 'Kit cliente — resolvecore-kit.zip',
		'size'    => '~5 MB',
		'desc'    => 'AnyDesk portable + scripts diagnóstico + README-cliente.txt + MANIFEST.txt',
		'oneliner'=> '',
		'note'    => 'Enviar al cliente por email o pendrive.',
	),
);

get_header();
?>

<a class="rc-skip-link" href="#main-content">Saltar al contenido</a>

<main id="main-content">

<section class="rc-tecnicos-hero">
	<div class="rc-tecnicos-hero-inner">
		<div class="rc-badge">Área restringida</div>
		<h1 class="rc-tecnicos-title">Área de Técnicos</h1>
		<p class="rc-tecnicos-sub">
			Hola, <strong><?php echo esc_html( wp_get_current_user()->display_name ); ?></strong>.
			Descarga los instaladores y kits para tus intervenciones de soporte.
		</p>
		<div class="rc-tecnicos-meta">
			<span>Versión <?php echo esc_html( $version ); ?></span>
			<span>·</span>
			<span>Build <?php echo esc_html( $build_date ); ?></span>
			<span>·</span>
			<a href="<?php echo esc_url( home_url( '/changelog/' ) ); ?>">Changelog</a>
		</div>
	</div>
</section>

<section class="rc-tecnicos-section">
<div class="rc-tecnicos-container">

	<!-- ── Tabs ────────────────────────────────────────────────────── -->
	<div class="rc-tabs" role="tablist" aria-label="Plataformas">
		<button class="rc-tab rc-tab--active" role="tab" aria-selected="true"
			aria-controls="tab-windows" id="btn-windows" data-tab="windows">
			Windows
		</button>
		<button class="rc-tab" role="tab" aria-selected="false"
			aria-controls="tab-linux" id="btn-linux" data-tab="linux">
			Linux
		</button>
		<button class="rc-tab" role="tab" aria-selected="false"
			aria-controls="tab-kit" id="btn-kit" data-tab="kit">
			Kit cliente
		</button>
	</div>

	<!-- ── Panel Windows ────────────────────────────────────────────── -->
	<div id="tab-windows" class="rc-tab-panel rc-tab-panel--active" role="tabpanel" aria-labelledby="btn-windows">

		<div class="rc-dl-card">
			<div class="rc-dl-card-header">
				<div class="rc-dl-platform-icon rc-dl-platform-icon--win" aria-hidden="true">
					<svg viewBox="0 0 24 24" fill="currentColor" width="28" height="28">
						<path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.4H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-12.9-1.801"/>
					</svg>
				</div>
				<div>
					<h2 class="rc-dl-card-title">Windows 10 / 11</h2>
					<p class="rc-dl-card-sub">PowerShell 5.1+ · Requiere Administrador</p>
				</div>
				<span class="rc-dl-badge rc-dl-badge--green">Listo</span>
			</div>

			<p class="rc-dl-desc"><?php echo esc_html( $downloads['windows']['desc'] ); ?></p>

			<div class="rc-dl-oneliner-box">
				<span class="rc-dl-oneliner-label">Opción 1 — Ejecutar directamente (sin descargar)</span>
				<div class="rc-dl-oneliner-row">
					<code class="rc-dl-oneliner"><?php echo esc_html( $downloads['windows']['oneliner'] ); ?></code>
					<button class="rc-copy-btn" data-copy="<?php echo esc_attr( $downloads['windows']['oneliner'] ); ?>"
						aria-label="Copiar comando">Copiar</button>
				</div>
				<small class="rc-dl-note"><?php echo esc_html( $downloads['windows']['note'] ); ?></small>
			</div>

			<div class="rc-dl-or">
				<span>o</span>
			</div>

			<div class="rc-dl-btn-wrap">
				<a href="<?php echo esc_url( add_query_arg( 'rc_download', 'windows', $dl_base ) ); ?>"
				   class="rc-dl-btn" download>
					<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20" aria-hidden="true">
						<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>
					</svg>
					Descargar install-servicios.ps1
					<span class="rc-dl-size"><?php echo esc_html( $downloads['windows']['size'] ); ?></span>
				</a>
			</div>

			<div class="rc-dl-steps">
				<h3 class="rc-dl-steps-title">Pasos tras la descarga</h3>
				<ol class="rc-dl-steps-list">
					<li>Clic derecho en <code>install-servicios.ps1</code> → <em>Ejecutar con PowerShell</em></li>
					<li>Si Windows pide confirmación UAC, haz clic en <strong>Sí</strong></li>
					<li>El script instala todo automáticamente (~3-5 min)</li>
					<li>Si pide reinicio, reinicia y ejecuta <code>.\ResolveCore.ps1</code></li>
				</ol>
			</div>
		</div>

		<div class="rc-dl-includes">
			<h3>Qué instala el script</h3>
			<table class="rc-dl-table">
				<thead><tr><th>Herramienta</th><th>Uso</th><th>Licencia</th></tr></thead>
				<tbody>
					<tr><td>Chocolatey</td><td>Gestor de paquetes Windows</td><td>Apache 2.0</td></tr>
					<tr><td>WSL</td><td>Ejecutar scripts Bash (clonación)</td><td>Microsoft</td></tr>
					<tr><td>jq (WSL)</td><td>Parseo JSON en scripts Bash</td><td>MIT</td></tr>
					<tr><td>AnyDesk portable</td><td>Acceso remoto al cliente</td><td>Freeware</td></tr>
				</tbody>
			</table>
		</div>
	</div><!-- /tab-windows -->

	<!-- ── Panel Linux ──────────────────────────────────────────────── -->
	<div id="tab-linux" class="rc-tab-panel" role="tabpanel" aria-labelledby="btn-linux" hidden>

		<div class="rc-dl-card">
			<div class="rc-dl-card-header">
				<div class="rc-dl-platform-icon rc-dl-platform-icon--linux" aria-hidden="true">
					<svg viewBox="0 0 24 24" fill="currentColor" width="28" height="28">
						<path d="M12.504 0c-.155 0-.315.008-.480.021-4.226.333-3.105 4.807-3.17 6.298-.076 1.092-.3 1.953-1.05 3.02-.885 1.051-2.127 2.75-2.716 4.521-.278.832-.41 1.684-.287 2.489.121.799.457 1.494.945 2.048C5.006 19.09 6.26 19.9 7.593 20.8a5.75 5.75 0 0 0 .7.441l-.001.007c.158.08.316.153.474.215.044.018.088.035.132.05.157.055.315.1.473.135.04.01.08.018.12.025.194.04.389.064.583.077.043.003.087.005.13.006.3.004.597-.014.888-.072.112-.022.222-.05.332-.083l.01-.003a5.567 5.567 0 0 0 .428-.163 6.5 6.5 0 0 0 .47-.22l.008-.004c.16-.087.316-.18.467-.28l.009-.005c.152-.102.299-.212.44-.33l.01-.009a5.476 5.476 0 0 0 .395-.38l.007-.008c.12-.13.233-.268.337-.414.069-.097.133-.197.192-.3.117-.204.214-.42.286-.643.072-.223.115-.455.126-.693.01-.238-.011-.477-.067-.716-.056-.238-.143-.476-.261-.712a3.52 3.52 0 0 0-.218-.367c-.08-.12-.166-.234-.26-.344-.094-.11-.195-.214-.303-.314-.054-.05-.11-.1-.167-.148-.085-.073-.172-.144-.262-.211-.09-.067-.182-.131-.277-.192-.095-.061-.191-.118-.289-.172-.048-.027-.097-.053-.146-.078-.1-.052-.203-.1-.306-.145-.069-.03-.138-.058-.208-.085a5.67 5.67 0 0 0-.434-.142c-.04-.011-.08-.02-.12-.03-.134-.031-.269-.057-.405-.077-.068-.01-.136-.018-.205-.024-.069-.006-.139-.01-.209-.012l-.06-.002H12c-.004 0-.007.001-.01.001z"/>
					</svg>
				</div>
				<div>
					<h2 class="rc-dl-card-title">Linux</h2>
					<p class="rc-dl-card-sub">Ubuntu 22.04+ · Debian 11+ · Fedora 37+ · Arch</p>
				</div>
				<span class="rc-dl-badge rc-dl-badge--green">Listo</span>
			</div>

			<p class="rc-dl-desc"><?php echo esc_html( $downloads['linux']['desc'] ); ?></p>

			<div class="rc-dl-oneliner-box">
				<span class="rc-dl-oneliner-label">Opción 1 — Ejecutar directamente (sin descargar)</span>
				<div class="rc-dl-oneliner-row">
					<code class="rc-dl-oneliner"><?php echo esc_html( $downloads['linux']['oneliner'] ); ?></code>
					<button class="rc-copy-btn" data-copy="<?php echo esc_attr( $downloads['linux']['oneliner'] ); ?>"
						aria-label="Copiar comando">Copiar</button>
				</div>
				<small class="rc-dl-note"><?php echo esc_html( $downloads['linux']['note'] ); ?></small>
			</div>

			<div class="rc-dl-or"><span>o</span></div>

			<div class="rc-dl-btn-wrap">
				<a href="<?php echo esc_url( add_query_arg( 'rc_download', 'linux', $dl_base ) ); ?>"
				   class="rc-dl-btn" download>
					<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20" aria-hidden="true">
						<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>
					</svg>
					Descargar install-servicios.sh
					<span class="rc-dl-size"><?php echo esc_html( $downloads['linux']['size'] ); ?></span>
				</a>
			</div>

			<div class="rc-dl-steps">
				<h3 class="rc-dl-steps-title">Pasos tras la descarga</h3>
				<ol class="rc-dl-steps-list">
					<li>Abre terminal en la carpeta de descarga</li>
					<li>Ejecuta: <code>chmod +x install-servicios.sh && bash install-servicios.sh</code></li>
					<li>El script instala todo automáticamente e informa si falta algo</li>
					<li>Lanza el menú principal: <code>bash scripts/linux/ResolveCore.sh</code></li>
				</ol>
			</div>
		</div>

		<div class="rc-dl-includes">
			<h3>Qué instala el script</h3>
			<table class="rc-dl-table">
				<thead><tr><th>Paquete</th><th>Uso</th><th>Licencia</th></tr></thead>
				<tbody>
					<tr><td>jq</td><td>Parseo JSON (clonación, congelación)</td><td>MIT</td></tr>
					<tr><td>curl</td><td>Integración MantisBT REST API</td><td>MIT/curl</td></tr>
					<tr><td>btrfs-progs</td><td>Herramientas BTRFS (congelación)</td><td>GPL-2.0</td></tr>
					<tr><td>snapper</td><td>Gestión de snapshots BTRFS</td><td>GPL-2.0</td></tr>
				</tbody>
			</table>
			<p class="rc-dl-note-block">
				<strong>Nota:</strong> La congelación requiere que el sistema de archivos raíz sea BTRFS.
				El script detecta automáticamente y avisa si no es compatible.
			</p>
		</div>
	</div><!-- /tab-linux -->

	<!-- ── Panel Kit cliente ────────────────────────────────────────── -->
	<div id="tab-kit" class="rc-tab-panel" role="tabpanel" aria-labelledby="btn-kit" hidden>

		<div class="rc-dl-card">
			<div class="rc-dl-card-header">
				<div class="rc-dl-platform-icon rc-dl-platform-icon--kit" aria-hidden="true">
					<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="28" height="28" aria-hidden="true">
						<path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/>
					</svg>
				</div>
				<div>
					<h2 class="rc-dl-card-title">Kit de implantación en cliente</h2>
					<p class="rc-dl-card-sub">ZIP listo para enviar — AnyDesk + scripts + instrucciones</p>
				</div>
				<span class="rc-dl-badge rc-dl-badge--blue">Entrega</span>
			</div>

			<p class="rc-dl-desc"><?php echo esc_html( $downloads['kit']['desc'] ); ?></p>

			<div class="rc-dl-btn-wrap" style="margin-top:1.5rem">
				<a href="<?php echo esc_url( add_query_arg( 'rc_download', 'kit', $dl_base ) ); ?>"
				   class="rc-dl-btn" download>
					<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20" aria-hidden="true">
						<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>
					</svg>
					Descargar resolvecore-kit.zip
					<span class="rc-dl-size"><?php echo esc_html( $downloads['kit']['size'] ); ?></span>
				</a>
			</div>

			<div class="rc-dl-steps">
				<h3 class="rc-dl-steps-title">Cómo entregarlo al cliente</h3>
				<ol class="rc-dl-steps-list">
					<li>Descarga el ZIP desde este portal</li>
					<li>Envíalo al cliente por email adjunto, o cópialo en un pendrive</li>
					<li>El cliente descomprime y hace doble clic en <code>anydesk-portable.exe</code></li>
					<li>El cliente te da su ID AnyDesk (9-10 dígitos) → tú te conectas</li>
				</ol>
			</div>

			<div class="rc-dl-includes">
				<h3>Contenido del ZIP</h3>
				<table class="rc-dl-table">
					<thead><tr><th>Fichero</th><th>Descripción</th></tr></thead>
					<tbody>
						<tr><td><code>anydesk-portable.exe</code></td><td>Acceso remoto sin instalación</td></tr>
						<tr><td><code>README-cliente.txt</code></td><td>Instrucciones en lenguaje no técnico + RGPD</td></tr>
						<tr><td><code>MANIFEST.txt</code></td><td>Checksums SHA256 de todos los ficheros</td></tr>
						<tr><td><code>scripts/diagnostico-windows.ps1</code></td><td>Diagnóstico Windows (opcional)</td></tr>
						<tr><td><code>scripts/diagnostico-linux.sh</code></td><td>Diagnóstico Linux (opcional)</td></tr>
					</tbody>
				</table>
			</div>
		</div>
	</div><!-- /tab-kit -->

</div><!-- .rc-tecnicos-container -->
</section>

<!-- ── Info quick-links ──────────────────────────────────────────────────── -->
<section class="rc-tecnicos-links">
<div class="rc-tecnicos-container">
	<h2 class="rc-tecnicos-links-title">Accesos rápidos</h2>
	<div class="rc-tecnicos-links-grid">
		<a href="<?php echo esc_url( home_url( '/docs/' ) ); ?>" class="rc-tlink">
			<span class="rc-tlink-icon">📄</span>
			<span class="rc-tlink-label">Documentación</span>
		</a>
		<a href="<?php echo esc_url( home_url( '/changelog/' ) ); ?>" class="rc-tlink">
			<span class="rc-tlink-icon">📋</span>
			<span class="rc-tlink-label">Changelog</span>
		</a>
		<a href="<?php echo esc_url( home_url( '/fleet-status/' ) ); ?>" class="rc-tlink">
			<span class="rc-tlink-icon">📡</span>
			<span class="rc-tlink-label">Estado de la flota</span>
		</a>
		<a href="https://mantis.resolvecore.website" target="_blank" rel="noopener" class="rc-tlink">
			<span class="rc-tlink-icon">🎫</span>
			<span class="rc-tlink-label">MantisBT</span>
		</a>
	</div>
</div>
</section>

</main>

<style>
/* ── Área técnicos ─────────────────────────────────────────────────────── */
.rc-tecnicos-hero {
	background: linear-gradient(135deg,#0a0c10 0%,#111418 100%);
	border-bottom: 1px solid #1a1d24;
	padding: 3.5rem 1.5rem 2.5rem;
	text-align: center;
}
.rc-tecnicos-hero-inner { max-width: 680px; margin: 0 auto; }
.rc-badge {
	display: inline-block;
	font-size: .7rem;
	font-weight: 700;
	letter-spacing: .1em;
	text-transform: uppercase;
	color: #00e5a0;
	border: 1px solid #00e5a030;
	background: #00e5a010;
	padding: .25rem .75rem;
	border-radius: 2rem;
	margin-bottom: 1rem;
}
.rc-tecnicos-title {
	font-size: clamp(1.8rem,4vw,2.6rem);
	font-weight: 800;
	color: #e8eaf0;
	margin: 0 0 .75rem;
}
.rc-tecnicos-sub { color: #a0a4b0; margin: 0 0 1rem; font-size: 1.05rem; }
.rc-tecnicos-meta {
	display: flex; gap: .6rem; justify-content: center;
	font-size: .8rem; color: #555c6e;
}
.rc-tecnicos-meta a { color: #00e5a0; text-decoration: none; }

/* ── Section + container ───────────────────────────────────────────────── */
.rc-tecnicos-section { padding: 3rem 1.5rem 4rem; background: #0d0f14; }
.rc-tecnicos-container { max-width: 860px; margin: 0 auto; }

/* ── Tabs ──────────────────────────────────────────────────────────────── */
.rc-tabs {
	display: flex; gap: .25rem;
	border-bottom: 2px solid #1a1d24;
	margin-bottom: 2rem;
}
.rc-tab {
	background: none; border: none; cursor: pointer;
	color: #7a7f8e; font-size: .9rem; font-weight: 600;
	padding: .7rem 1.4rem;
	border-bottom: 2px solid transparent;
	margin-bottom: -2px;
	transition: color .15s, border-color .15s;
}
.rc-tab:hover  { color: #c8cad8; }
.rc-tab--active { color: #00e5a0; border-bottom-color: #00e5a0; }

/* ── Card ──────────────────────────────────────────────────────────────── */
.rc-dl-card {
	background: #13151c;
	border: 1px solid #1e2130;
	border-radius: 12px;
	padding: 2rem;
	margin-bottom: 1.5rem;
}
.rc-dl-card-header {
	display: flex; align-items: center; gap: 1rem;
	margin-bottom: 1.25rem;
}
.rc-dl-platform-icon {
	width: 52px; height: 52px;
	border-radius: 10px;
	display: grid; place-items: center; flex-shrink: 0;
}
.rc-dl-platform-icon--win   { background: #1e3a5f; color: #4fc3f7; }
.rc-dl-platform-icon--linux { background: #2a1f00; color: #ffd54f; }
.rc-dl-platform-icon--kit   { background: #1a2d1a; color: #00e5a0; }
.rc-dl-card-title { font-size: 1.2rem; font-weight: 700; color: #e8eaf0; margin: 0 0 .2rem; }
.rc-dl-card-sub   { font-size: .8rem; color: #7a7f8e; margin: 0; }
.rc-dl-badge {
	margin-left: auto; font-size: .7rem; font-weight: 700;
	padding: .25rem .6rem; border-radius: 2rem; text-transform: uppercase;
}
.rc-dl-badge--green { background: #00e5a015; color: #00e5a0; border: 1px solid #00e5a030; }
.rc-dl-badge--blue  { background: #1565c015; color: #64b5f6; border: 1px solid #1565c030; }
.rc-dl-desc { color: #9da2b0; font-size: .9rem; margin-bottom: 1.5rem; }

/* ── One-liner ─────────────────────────────────────────────────────────── */
.rc-dl-oneliner-box {
	background: #0a0c10;
	border: 1px solid #1e2130;
	border-radius: 8px;
	padding: 1rem 1.25rem;
	margin-bottom: 1rem;
}
.rc-dl-oneliner-label { display: block; font-size: .72rem; color: #555c6e; margin-bottom: .6rem; font-weight: 600; letter-spacing: .05em; }
.rc-dl-oneliner-row   { display: flex; gap: .75rem; align-items: center; flex-wrap: wrap; }
.rc-dl-oneliner {
	font-family: 'JetBrains Mono',monospace;
	font-size: .82rem;
	color: #00e5a0;
	background: none;
	flex: 1;
	word-break: break-all;
}
.rc-copy-btn {
	background: #1e2130; border: 1px solid #2a2d3e; color: #c8cad8;
	font-size: .75rem; padding: .35rem .9rem; border-radius: 6px;
	cursor: pointer; flex-shrink: 0; transition: background .15s;
}
.rc-copy-btn:hover       { background: #252838; }
.rc-copy-btn.rc-copied   { background: #00e5a020; color: #00e5a0; border-color: #00e5a030; }
.rc-dl-note { display: block; font-size: .75rem; color: #555c6e; margin-top: .5rem; }

/* ── OR divider ────────────────────────────────────────────────────────── */
.rc-dl-or {
	display: flex; align-items: center; gap: 1rem;
	color: #3a3d4e; font-size: .8rem; margin: 1rem 0;
}
.rc-dl-or::before, .rc-dl-or::after {
	content: ''; flex: 1; height: 1px; background: #1e2130;
}

/* ── Download button ───────────────────────────────────────────────────── */
.rc-dl-btn-wrap { text-align: center; }
.rc-dl-btn {
	display: inline-flex; align-items: center; gap: .6rem;
	background: linear-gradient(135deg,#00c988,#00e5a0);
	color: #0a0c10; font-weight: 700; font-size: .95rem;
	padding: .85rem 2rem; border-radius: 8px; text-decoration: none;
	transition: opacity .15s, transform .1s;
	box-shadow: 0 4px 20px #00e5a030;
}
.rc-dl-btn:hover { opacity: .9; transform: translateY(-1px); color: #0a0c10; }
.rc-dl-size {
	font-size: .75rem; font-weight: 400;
	background: #00000025; padding: .15rem .5rem; border-radius: 4px;
}

/* ── Steps ─────────────────────────────────────────────────────────────── */
.rc-dl-steps { margin-top: 1.75rem; }
.rc-dl-steps-title { font-size: .85rem; font-weight: 700; color: #7a7f8e; letter-spacing: .06em; text-transform: uppercase; margin-bottom: .75rem; }
.rc-dl-steps-list  { margin: 0; padding-left: 1.5rem; color: #9da2b0; font-size: .9rem; line-height: 1.8; }
.rc-dl-steps-list code { background: #0a0c10; color: #00e5a0; padding: .1rem .4rem; border-radius: 4px; font-size: .82rem; }

/* ── Includes table ────────────────────────────────────────────────────── */
.rc-dl-includes { margin-top: 1.5rem; }
.rc-dl-includes h3 { font-size: .85rem; font-weight: 700; color: #7a7f8e; letter-spacing: .06em; text-transform: uppercase; margin-bottom: .75rem; }
.rc-dl-table { width: 100%; border-collapse: collapse; font-size: .85rem; color: #9da2b0; }
.rc-dl-table th { text-align: left; color: #555c6e; font-weight: 600; font-size: .75rem; text-transform: uppercase; letter-spacing: .05em; padding: .5rem .75rem; border-bottom: 1px solid #1e2130; }
.rc-dl-table td { padding: .6rem .75rem; border-bottom: 1px solid #13151c; }
.rc-dl-table td:first-child { color: #c8cad8; }
.rc-dl-table td code { background: #0a0c10; color: #64b5f6; padding: .1rem .4rem; border-radius: 4px; font-size: .8rem; }
.rc-dl-note-block { margin-top: 1rem; font-size: .82rem; color: #7a7f8e; background: #0a0c10; border-left: 3px solid #ffd54f40; padding: .75rem 1rem; border-radius: 0 6px 6px 0; }

/* ── Quick links ───────────────────────────────────────────────────────── */
.rc-tecnicos-links { background: #0a0c10; border-top: 1px solid #1a1d24; padding: 2.5rem 1.5rem 3rem; }
.rc-tecnicos-links-title { text-align: center; font-size: .85rem; font-weight: 700; color: #555c6e; letter-spacing: .08em; text-transform: uppercase; margin-bottom: 1.5rem; }
.rc-tecnicos-links-grid  { display: flex; gap: 1rem; justify-content: center; flex-wrap: wrap; max-width: 600px; margin: 0 auto; }
.rc-tlink {
	display: flex; flex-direction: column; align-items: center; gap: .4rem;
	background: #13151c; border: 1px solid #1e2130; border-radius: 10px;
	padding: 1rem 1.5rem; text-decoration: none; color: #9da2b0;
	font-size: .82rem; transition: border-color .15s, color .15s;
	min-width: 110px;
}
.rc-tlink:hover { border-color: #00e5a040; color: #e8eaf0; }
.rc-tlink-icon { font-size: 1.4rem; }

@media (max-width: 600px) {
	.rc-dl-card { padding: 1.25rem; }
	.rc-dl-card-header { flex-wrap: wrap; }
	.rc-dl-badge { margin-left: 0; }
	.rc-dl-btn { width: 100%; justify-content: center; }
	.rc-tabs { overflow-x: auto; }
}
</style>

<script>
(function () {
	// ── Tabs ──────────────────────────────────────────────────────────────
	document.querySelectorAll('.rc-tab').forEach(function (btn) {
		btn.addEventListener('click', function () {
			var tab = btn.dataset.tab;
			document.querySelectorAll('.rc-tab').forEach(function (b) {
				b.classList.remove('rc-tab--active');
				b.setAttribute('aria-selected', 'false');
			});
			document.querySelectorAll('.rc-tab-panel').forEach(function (p) {
				p.classList.remove('rc-tab-panel--active');
				p.hidden = true;
			});
			btn.classList.add('rc-tab--active');
			btn.setAttribute('aria-selected', 'true');
			var panel = document.getElementById('tab-' + tab);
			if (panel) { panel.classList.add('rc-tab-panel--active'); panel.hidden = false; }
		});
	});

	// ── Copy buttons ──────────────────────────────────────────────────────
	document.querySelectorAll('.rc-copy-btn').forEach(function (btn) {
		btn.addEventListener('click', function () {
			var text = btn.dataset.copy;
			if (!text) return;
			navigator.clipboard.writeText(text).then(function () {
				btn.textContent = '¡Copiado!';
				btn.classList.add('rc-copied');
				setTimeout(function () {
					btn.textContent = 'Copiar';
					btn.classList.remove('rc-copied');
				}, 2000);
			}).catch(function () {
				// Fallback para HTTP (sin HTTPS)
				var ta = document.createElement('textarea');
				ta.value = text;
				ta.style.position = 'fixed'; ta.style.opacity = '0';
				document.body.appendChild(ta);
				ta.select();
				try { document.execCommand('copy'); btn.textContent = '¡Copiado!'; btn.classList.add('rc-copied');
					setTimeout(function(){btn.textContent='Copiar';btn.classList.remove('rc-copied');},2000); } catch(e){}
				document.body.removeChild(ta);
			});
		});
	});
})();
</script>

<?php get_footer(); ?>
