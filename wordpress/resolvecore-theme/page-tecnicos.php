<?php
/* Template Name: Área de Técnicos */

// Redirige a login si no está autenticado
if ( ! is_user_logged_in() ) {
	wp_safe_redirect( wp_login_url( get_permalink() ) );
	exit;
}

// Solo roles técnico / administrador.
// En vez de la pantalla gris nativa de wp_die(), renderizamos un 403 elegante
// que hereda el header/footer del tema (auditoría 01-06-2026).
if ( ! current_user_can( 'editor' ) && ! current_user_can( 'administrator' ) ) {
	status_header( 403 );
	get_header();
	?>
	<main id="main-content" class="rc-403">
		<div class="rc-403-box">
			<div class="rc-403-code" aria-hidden="true">403</div>
			<h1 class="rc-403-title">Acceso restringido</h1>
			<p class="rc-403-text">
				Esta zona es exclusiva del equipo técnico de ResolveCore.
				Tu cuenta no tiene permisos para acceder a ella.
			</p>
			<div class="rc-403-actions">
				<a class="rc-btn rc-btn--accent" href="<?php echo esc_url( home_url( '/' ) ); ?>">Volver al inicio</a>
				<a class="rc-btn" href="<?php echo esc_url( home_url( '/dashboard/' ) ); ?>">Ir a mi panel</a>
			</div>
			<p class="rc-403-foot">
				¿Crees que es un error? Escribe a
				<a href="mailto:tecnicos@resolvecore.website">tecnicos@resolvecore.website</a>.
			</p>
		</div>
	</main>
	<style>
		.rc-403 { display: flex; align-items: center; justify-content: center;
		          min-height: 60vh; padding: 4rem 1.5rem; }
		.rc-403-box { max-width: 480px; text-align: center;
		              background: var(--rc-grad-surface, #13151c); border: 1px solid var(--rc-border2, #1e2130);
		              border-radius: 16px; padding: 3rem 2.5rem;
		              box-shadow: 0 24px 60px rgba(0,0,0,.45); }
		.rc-403-code { font-family: var(--rc-mono, monospace); font-size: 4rem; font-weight: 700;
		               line-height: 1; color: var(--rc-accent, #00e5a0); margin-bottom: .5rem;
		               letter-spacing: .05em; }
		.rc-403-title { font-family: var(--rc-mono, monospace); font-size: 1.5rem; font-weight: 700;
		                margin: 0 0 .75rem; color: var(--rc-text, #e8eaf0); }
		.rc-403-text { color: var(--rc-muted, #9da2b0); line-height: 1.6; margin: 0 0 1.75rem; }
		.rc-403-actions { display: flex; gap: .75rem; justify-content: center; flex-wrap: wrap;
		                  margin-bottom: 1.5rem; }
		.rc-403-foot { font-size: .85rem; color: var(--rc-muted, #9da2b0); margin: 0; }
		.rc-403-foot a { color: var(--rc-accent, #00e5a0); }
		@media (max-width: 460px) { .rc-403-box { padding: 2rem 1.5rem; } }
	</style>
	<?php
	get_footer();
	exit;
}

$dl_base    = home_url( '/tecnicos/' );
$nonce_ajax = wp_create_nonce( 'rc_tech_nonce' );
$nonce_kit  = wp_create_nonce( 'rc_tech_readme' );

$meta_win = function_exists( 'rc_get_download_meta' ) ? rc_get_download_meta( 'windows' ) : array();
$meta_lin = function_exists( 'rc_get_download_meta' ) ? rc_get_download_meta( 'linux' ) : array();
$meta_kit = function_exists( 'rc_get_download_meta' ) ? rc_get_download_meta( 'kit' ) : array();

$downloads = array(
	'windows' => array(
		'label'    => 'Windows — install-servicios.ps1',
		'desc'     => 'Instala: Chocolatey · WSL · jq · AnyDesk portable',
		'oneliner' => 'irm https://resolvecore.website/install.ps1 | iex',
		'note'     => 'Requiere PowerShell como Administrador',
		'meta'     => $meta_win,
		'prompt'   => 'PS C:\>',
	),
	'linux'   => array(
		'label'    => 'Linux — install-servicios.sh',
		'desc'     => 'Instala: jq · curl · btrfs-progs · snapper. Ubuntu 22.04+, Debian 11+, Fedora 37+, Arch.',
		'oneliner' => 'curl -fsSL https://resolvecore.website/install.sh | sudo bash',
		'note'     => 'Requiere sudo (instala paquetes del sistema).',
		'meta'     => $meta_lin,
		'prompt'   => '$',
	),
	'kit'     => array(
		'label'    => 'Kit cliente — resolvecore-kit.zip',
		'desc'     => 'AnyDesk portable + scripts diagnóstico + README-cliente.txt + MANIFEST.txt',
		'oneliner' => '',
		'note'     => 'Enviar al cliente por email o pendrive.',
		'meta'     => $meta_kit,
		'prompt'   => '',
	),
);

get_header();
?>

<a class="rc-skip-link" href="#main-content">Saltar al contenido</a>

<main id="main-content" class="rc-tec">

<!-- ── Barra de trabajo ───────────────────────────────────────────────── -->
<header class="rc-tec-bar">
	<div class="rc-tec-bar-inner">
		<span class="rc-tec-bar-brand">ResolveCore <span>Operaciones</span></span>
		<nav class="rc-tec-bar-nav" aria-label="Accesos directos">
			<a href="https://mantis.resolvecore.website" target="_blank" rel="noopener" class="rc-tec-bar-link rc-tec-bar-link--primary">
				<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/><line x1="7" y1="7" x2="7.01" y2="7"/></svg>
				MantisBT
			</a>
			<a href="<?php echo esc_url( home_url( '/fleet-status/' ) ); ?>" class="rc-tec-bar-link">Estado flota</a>
			<a href="<?php echo esc_url( home_url( '/docs/' ) ); ?>" class="rc-tec-bar-link">Docs</a>
			<button type="button" class="rc-tec-bar-link rc-tec-bar-pal" id="rc-bar-palette">
				<kbd>Ctrl</kbd>+<kbd>K</kbd>
			</button>
		</nav>
	</div>
</header>

<!-- ── Estado infraestructura ─────────────────────────────────────────── -->
<section class="rc-tec-status" aria-label="Estado de infraestructura">
	<div class="rc-tec-wrap">
		<div class="rc-tec-status-head">
			<span class="rc-tec-status-label">Infraestructura en vivo</span>
			<button class="rc-tec-status-refresh" type="button" aria-label="Refrescar estado">
				<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><path d="M23 4v6h-6"/><path d="M1 20v-6h6"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>
				<span>Actualizar</span>
			</button>
		</div>
		<div class="rc-tec-status-grid" id="rc-infra">
			<div class="rc-tec-status-card" data-svc="mantis">
				<span class="rc-tec-status-dot rc-tec-status-dot--load"></span>
				<div>
					<strong>MantisBT</strong>
					<small>mantis.resolvecore.website</small>
				</div>
				<span class="rc-tec-status-ms">—</span>
			</div>
			<div class="rc-tec-status-card" data-svc="web">
				<span class="rc-tec-status-dot rc-tec-status-dot--load"></span>
				<div>
					<strong>Web / API</strong>
					<small>resolvecore.website</small>
				</div>
				<span class="rc-tec-status-ms">—</span>
			</div>
			<div class="rc-tec-status-card" data-svc="fleet">
				<span class="rc-tec-status-dot rc-tec-status-dot--load"></span>
				<div>
					<strong>Fleet panel</strong>
					<small>/fleet-status/</small>
				</div>
				<span class="rc-tec-status-ms">—</span>
			</div>
		</div>
	</div>
</section>

<!-- ── Mis tickets MantisBT (accionable: arriba) ──────────────────────── -->
<section class="rc-tec-tickets">
	<div class="rc-tec-wrap">
		<div class="rc-tec-tickets-head">
			<h2>Mis tickets abiertos</h2>
			<a href="https://mantis.resolvecore.website" target="_blank" rel="noopener" class="rc-mini-btn">
				Abrir MantisBT
				<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>
			</a>
		</div>
		<div id="rc-tickets" class="rc-tickets-list">
			<div class="rc-tickets-loading">Cargando tickets…</div>
		</div>
	</div>
</section>

<section class="rc-tec-section">
<div class="rc-tec-wrap">

	<!-- ── Tabs ────────────────────────────────────────────────────── -->
	<div class="rc-tabs" role="tablist" aria-label="Plataformas">
		<button class="rc-tab rc-tab--active" role="tab" aria-selected="true"
			aria-controls="tab-windows" id="btn-windows" data-tab="windows">
			<kbd>1</kbd> Windows
		</button>
		<button class="rc-tab" role="tab" aria-selected="false"
			aria-controls="tab-linux" id="btn-linux" data-tab="linux">
			<kbd>2</kbd> Linux
		</button>
		<button class="rc-tab" role="tab" aria-selected="false"
			aria-controls="tab-kit" id="btn-kit" data-tab="kit">
			<kbd>3</kbd> Kit cliente
		</button>
	</div>

	<?php
	$platforms = array(
		'windows' => array(
			'icon_class' => 'rc-dl-icon--win',
			'title'      => 'Windows 10 / 11',
			'sub'        => 'PowerShell 5.1+ · Requiere Administrador',
			'badge'      => array( 'green', 'Listo' ),
		),
		'linux'   => array(
			'icon_class' => 'rc-dl-icon--linux',
			'title'      => 'Linux',
			'sub'        => 'Ubuntu 22.04+ · Debian 11+ · Fedora 37+ · Arch',
			'badge'      => array( 'green', 'Listo' ),
		),
		'kit'     => array(
			'icon_class' => 'rc-dl-icon--kit',
			'title'      => 'Kit de implantación',
			'sub'        => 'AnyDesk + scripts + README + MANIFEST',
			'badge'      => array( 'blue', 'Entrega' ),
		),
	);
	foreach ( $platforms as $key => $plat ) :
		$dl     = $downloads[ $key ];
		$active = $key === 'windows' ? ' rc-tab-panel--active' : '';
		$hidden = $key === 'windows' ? '' : ' hidden';
		$meta   = $dl['meta'];
		$exists = ! empty( $meta['exists'] );
		$size   = $exists ? rc_format_bytes( (int) $meta['size'] ) : '—';
		$sha    = $exists ? $meta['sha256'] : '';
		$mtime  = $exists ? wp_date( 'Y-m-d H:i', (int) $meta['mtime'] ) : '—';
		?>
		<div id="tab-<?php echo esc_attr( $key ); ?>" class="rc-tab-panel<?php echo esc_attr( $active ); ?>" role="tabpanel" aria-labelledby="btn-<?php echo esc_attr( $key ); ?>" <?php echo $hidden ? 'hidden' : ''; ?>>

		<div class="rc-dl-card rc-dl-card--<?php echo esc_attr( $key ); ?>">
			<div class="rc-dl-card-bar" aria-hidden="true"></div>

			<div class="rc-dl-card-header">
				<div class="rc-dl-platform-icon <?php echo esc_attr( $plat['icon_class'] ); ?>" aria-hidden="true">
					<?php if ( $key === 'windows' ) : ?>
						<svg viewBox="0 0 24 24" fill="currentColor" width="28" height="28"><path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.4H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-12.9-1.801"/></svg>
					<?php elseif ( $key === 'linux' ) : ?>
						<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="28" height="28"><circle cx="12" cy="9" r="4"/><path d="M5 21c0-3 3-5 7-5s7 2 7 5"/><path d="M9 8h.01M15 8h.01"/></svg>
					<?php else : ?>
						<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="28" height="28"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/></svg>
					<?php endif; ?>
				</div>
				<div>
					<h2 class="rc-dl-card-title"><?php echo esc_html( $plat['title'] ); ?></h2>
					<p class="rc-dl-card-sub"><?php echo esc_html( $plat['sub'] ); ?></p>
				</div>
				<span class="rc-dl-badge rc-dl-badge--<?php echo esc_attr( $plat['badge'][0] ); ?>"><?php echo esc_html( $plat['badge'][1] ); ?></span>
			</div>

			<p class="rc-dl-desc"><?php echo esc_html( $dl['desc'] ); ?></p>

			<?php if ( $dl['oneliner'] ) : ?>
			<div class="rc-terminal" data-oneliner="<?php echo esc_attr( $dl['oneliner'] ); ?>">
				<div class="rc-terminal-chrome" aria-hidden="true">
					<span class="rc-terminal-dot rc-terminal-dot--r"></span>
					<span class="rc-terminal-dot rc-terminal-dot--y"></span>
					<span class="rc-terminal-dot rc-terminal-dot--g"></span>
					<span class="rc-terminal-title"><?php echo $key === 'windows' ? 'PowerShell (Administrador)' : 'bash'; ?></span>
				</div>
				<div class="rc-terminal-body">
					<span class="rc-terminal-prompt"><?php echo esc_html( $dl['prompt'] ); ?></span>
					<code class="rc-terminal-cmd"><?php echo esc_html( $dl['oneliner'] ); ?></code>
				</div>
				<div class="rc-terminal-actions">
					<small class="rc-terminal-note"><?php echo esc_html( $dl['note'] ); ?></small>
					<div class="rc-terminal-btns">
						<button class="rc-mini-btn rc-copy-btn" type="button" data-copy="<?php echo esc_attr( $dl['oneliner'] ); ?>" aria-label="Copiar comando">
							<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
							Copiar
						</button>
					</div>
				</div>
			</div>

			<div class="rc-dl-or"><span>o descarga directa</span></div>
			<?php endif; ?>

			<div class="rc-dl-btn-wrap">
				<a href="<?php echo esc_url( wp_nonce_url( add_query_arg( 'rc_download', $key, $dl_base ), 'rc_download' ) ); ?>"
				   class="rc-dl-btn" download>
					<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20" aria-hidden="true"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
					Descargar <?php echo esc_html( basename( $dl['label'] ) ); ?>
					<span class="rc-dl-size"><?php echo esc_html( $size ); ?></span>
				</a>
			</div>

			<!-- Metadata real -->
			<dl class="rc-dl-meta">
				<div>
					<dt>Tamaño</dt>
					<dd><?php echo esc_html( $size ); ?></dd>
				</div>
				<div>
					<dt>Actualizado</dt>
					<dd><?php echo esc_html( $mtime ); ?></dd>
				</div>
				<div class="rc-dl-meta-sha">
					<dt>SHA-256</dt>
					<dd>
						<?php if ( $sha ) : ?>
						<code class="rc-sha"><?php echo esc_html( $sha ); ?></code>
						<button class="rc-mini-btn rc-copy-btn" type="button" data-copy="<?php echo esc_attr( $sha ); ?>" aria-label="Copiar hash">
							<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
						</button>
						<?php else : ?>
						<span class="rc-muted">— (fichero no disponible)</span>
						<?php endif; ?>
					</dd>
				</div>
			</dl>

			<?php if ( $key === 'windows' ) : ?>
			<details class="rc-dl-trouble">
				<summary>Problemas comunes Windows ▾</summary>
				<ul>
					<li><strong>ExecutionPolicy bloquea:</strong> abrir PS como Admin y ejecutar <code>Set-ExecutionPolicy RemoteSigned -Scope CurrentUser</code></li>
					<li><strong>UAC bloquea:</strong> clic derecho PowerShell → Ejecutar como Administrador</li>
					<li><strong>"Falta llave de cierre" parseando:</strong> el .ps1 perdió el BOM UTF-8. Re-descarga.</li>
					<li><strong>WSL pide reinicio:</strong> normal en primera instalación, exit code 2.</li>
				</ul>
			</details>
			<?php elseif ( $key === 'linux' ) : ?>
			<details class="rc-dl-trouble">
				<summary>Problemas comunes Linux ▾</summary>
				<ul>
					<li><strong>sudo: command not found:</strong> instalar primero <code>apt install sudo</code> como root.</li>
					<li><strong>btrfs no detectado:</strong> congelación solo en raíz BTRFS. Resto módulos OK.</li>
					<li><strong>apt lock:</strong> esperar a que termine <code>unattended-upgrades</code>.</li>
				</ul>
			</details>
			<?php endif; ?>

			<?php if ( $key === 'windows' ) : ?>
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
			<?php elseif ( $key === 'linux' ) : ?>
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
			</div>
			<?php else : ?>
			<div class="rc-dl-includes">
				<h3>Contenido del ZIP</h3>
				<table class="rc-dl-table">
					<thead><tr><th>Fichero</th><th>Descripción</th></tr></thead>
					<tbody>
						<tr><td><code>anydesk-portable.exe</code></td><td>Acceso remoto sin instalación</td></tr>
						<tr><td><code>README-cliente.txt</code></td><td>Instrucciones + RGPD</td></tr>
						<tr><td><code>MANIFEST.txt</code></td><td>Checksums SHA256</td></tr>
						<tr><td><code>scripts/diagnostico-windows.ps1</code></td><td>Diagnóstico Windows</td></tr>
						<tr><td><code>scripts/diagnostico-linux.sh</code></td><td>Diagnóstico Linux</td></tr>
					</tbody>
				</table>
			</div>

			<!-- Generador README personalizado -->
			<div class="rc-kit-gen">
				<h3>Generador de README personalizado</h3>
				<p class="rc-muted">Genera un <code>README-cliente.txt</code> ya rellenado con nombre del cliente, ticket y técnico asignado.</p>
				<form method="POST" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" class="rc-kit-form">
					<input type="hidden" name="action" value="rc_tech_build_readme">
					<?php wp_nonce_field( 'rc_tech_readme' ); ?>
					<label>
						<span>Cliente</span>
						<input type="text" name="cliente" required maxlength="80" placeholder="Ej: Juan Pérez">
					</label>
					<label>
						<span>Ticket #</span>
						<input type="number" name="ticket" min="0" placeholder="123">
					</label>
					<button type="submit" class="rc-mini-btn rc-mini-btn--primary">
						<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
						Descargar README
					</button>
				</form>
			</div>
			<?php endif; ?>

			<div class="rc-dl-steps">
				<h3 class="rc-dl-steps-title">Pasos tras la descarga</h3>
				<ol class="rc-checklist" data-checklist="<?php echo esc_attr( $key ); ?>">
				<?php
				$steps = array(
					'windows' => array(
						'Clic derecho en install-servicios.ps1 → Ejecutar con PowerShell',
						'Confirmar UAC con "Sí"',
						'Esperar 3-5 min mientras instala',
						'Si pide reinicio: reiniciar y lanzar .\ResolveCore.ps1',
					),
					'linux'   => array(
						'Abrir terminal en carpeta de descarga',
						'chmod +x install-servicios.sh && bash install-servicios.sh',
						'Esperar a que termine (instala paquetes con sudo)',
						'Lanzar: bash scripts/linux/ResolveCore.sh',
					),
					'kit'     => array(
						'Descargar ZIP desde este portal',
						'Enviar por email o pendrive al cliente',
						'Cliente: doble clic en anydesk-portable.exe',
						'Cliente te da ID AnyDesk → conectas',
					),
				);
				foreach ( $steps[ $key ] as $i => $step ) :
					?>
					<li>
						<label>
							<input type="checkbox" data-step="<?php echo (int) $i; ?>">
							<span><?php echo esc_html( $step ); ?></span>
						</label>
					</li>
				<?php endforeach; ?>
				</ol>
			</div>
		</div>
	</div>
	<?php endforeach; ?>

</div>
</section>

<!-- ── Dashboard ticket activo (pinned) ────────────────────────────────── -->
<section class="rc-tec-dash" id="rc-dash" hidden>
	<div class="rc-tec-wrap">
		<div class="rc-dash-header">
			<div class="rc-dash-pin">
				<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="17" x2="12" y2="22"/><path d="M5 17h14l-1.5-9.5a2 2 0 0 0-2-1.5h-7a2 2 0 0 0-2 1.5z"/></svg>
				<span>Ticket activo</span>
				<strong id="rc-dash-id">#—</strong>
				<span id="rc-dash-sum" class="rc-muted"></span>
			</div>
			<div class="rc-dash-timer">
				<span id="rc-dash-elapsed">00:00:00</span>
				<button type="button" class="rc-mini-btn" id="rc-dash-toggle">Pausar</button>
				<button type="button" class="rc-mini-btn" id="rc-dash-reset">Reset</button>
				<button type="button" class="rc-mini-btn" id="rc-dash-unpin">Soltar</button>
			</div>
		</div>

		<div class="rc-dash-grid">
			<div class="rc-dash-block">
				<h4>Añadir nota al ticket</h4>
				<textarea id="rc-note-text" rows="3" placeholder="Diagnóstico breve, paso aplicado…"></textarea>
				<div class="rc-dash-row">
					<small id="rc-note-feedback" class="rc-muted"></small>
					<button type="button" class="rc-mini-btn rc-mini-btn--primary" id="rc-note-send">Enviar nota</button>
				</div>
			</div>

			<div class="rc-dash-block">
				<h4>Subir informe (PDF/HTML)</h4>
				<input type="file" id="rc-informe-file" accept=".pdf,.html" hidden>
				<button type="button" class="rc-mini-btn" id="rc-informe-pick">Elegir fichero…</button>
				<small id="rc-informe-name" class="rc-muted">Ningún fichero</small>
				<div class="rc-dash-row">
					<small id="rc-informe-feedback" class="rc-muted"></small>
					<button type="button" class="rc-mini-btn rc-mini-btn--primary" id="rc-informe-send" disabled>Adjuntar al ticket</button>
				</div>
			</div>

			<div class="rc-dash-block">
				<h4>Generar factura</h4>
				<div class="rc-fact-form">
					<label>Cliente <input type="text" id="rc-fact-cliente" placeholder="Juan Pérez"></label>
					<label>Horas <input type="number" id="rc-fact-horas" step="0.25" min="0.25" value="1"></label>
					<label>€/h <input type="number" id="rc-fact-tarifa" step="1" min="0" value="35"></label>
				</div>
				<button type="button" class="rc-mini-btn rc-mini-btn--primary" id="rc-fact-go">Abrir factura</button>
			</div>

			<div class="rc-dash-block">
				<h4>Sesión AnyDesk</h4>
				<div class="rc-dash-row">
					<input type="text" id="rc-anydesk-id" placeholder="ID AnyDesk (9-10 dígitos)" pattern="[0-9]+" inputmode="numeric">
					<button type="button" class="rc-mini-btn rc-mini-btn--primary" id="rc-anydesk-go">Conectar</button>
				</div>
				<ul id="rc-anydesk-recent" class="rc-anydesk-recent"></ul>
			</div>
		</div>
	</div>
</section>

<!-- ── Command palette ─────────────────────────────────────────────────── -->
<div id="rc-palette" class="rc-palette" hidden role="dialog" aria-modal="true" aria-label="Paleta de comandos">
	<div class="rc-palette-bg" data-close></div>
	<div class="rc-palette-box">
		<div class="rc-palette-input-row">
			<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
			<input type="text" id="rc-palette-q" placeholder="Buscar acción, ticket, plataforma… (Esc cierra)" autocomplete="off" spellcheck="false">
			<kbd>Esc</kbd>
		</div>
		<ul id="rc-palette-list" class="rc-palette-list" role="listbox"></ul>
		<div class="rc-palette-footer">
			<span><kbd>↑↓</kbd> navegar</span>
			<span><kbd>Enter</kbd> seleccionar</span>
			<span><kbd>Ctrl</kbd>+<kbd>K</kbd> abrir/cerrar</span>
		</div>
	</div>
</div>

<!-- ── Accesos rápidos ─────────────────────────────────────────────────── -->
<section class="rc-tec-links">
	<div class="rc-tec-wrap">
		<h2 class="rc-tec-links-title">Accesos rápidos</h2>
		<div class="rc-tec-links-grid">
			<a href="<?php echo esc_url( home_url( '/docs/' ) ); ?>" class="rc-tlink">
				<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
				<span>Documentación</span>
			</a>
			<a href="<?php echo esc_url( home_url( '/changelog/' ) ); ?>" class="rc-tlink">
				<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="20" x2="12" y2="10"/><line x1="18" y1="20" x2="18" y2="4"/><line x1="6" y1="20" x2="6" y2="16"/></svg>
				<span>Changelog</span>
			</a>
			<a href="<?php echo esc_url( home_url( '/fleet-status/' ) ); ?>" class="rc-tlink">
				<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2"><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7z"/><circle cx="12" cy="12" r="3"/></svg>
				<span>Estado flota</span>
			</a>
			<a href="https://mantis.resolvecore.website" target="_blank" rel="noopener" class="rc-tlink">
				<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/><line x1="7" y1="7" x2="7.01" y2="7"/></svg>
				<span>MantisBT</span>
			</a>
		</div>
	</div>
</section>

<!-- ── Atajos teclado hint ─────────────────────────────────────────────── -->
<div class="rc-tec-hotkeys" aria-hidden="true">
	<kbd>Ctrl</kbd>+<kbd>K</kbd> palette · <kbd>1</kbd><kbd>2</kbd><kbd>3</kbd> tabs · <kbd>C</kbd> copiar · <kbd>Esc</kbd> cerrar
</div>

</main>

<style>
/* ── Reset / base ─────────────────────────────────────────────────────── */
.rc-tec { background: #06080c; color: #e8eaf0; }
.rc-tec * { box-sizing: border-box; }
.rc-tec-wrap { max-width: 920px; margin: 0 auto; padding: 0 1.5rem; }

/* ── Barra de trabajo ─────────────────────────────────────────────────── */
.rc-tec-bar {
	position: sticky; top: 0; z-index: 30;
	background: rgba(10,12,16,.92); backdrop-filter: blur(10px);
	border-bottom: 1px solid #1a1d24;
}
.rc-tec-bar-inner {
	max-width: 920px; margin: 0 auto; padding: .6rem 1.5rem;
	display: flex; align-items: center; justify-content: space-between; gap: 1rem;
}
.rc-tec-bar-brand {
	font-size: .9rem; font-weight: 800; color: #e8eaf0; letter-spacing: .02em;
}
.rc-tec-bar-brand span { color: #00e5a0; font-weight: 700; }
.rc-tec-bar-nav { display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }
.rc-tec-bar-link {
	display: inline-flex; align-items: center; gap: .35rem;
	background: none; border: 1px solid #1e2130; color: #9da2b0;
	font-size: .78rem; font-family: inherit;
	padding: .35rem .7rem; border-radius: 6px; cursor: pointer; text-decoration: none;
	transition: color .15s, border-color .15s, background .15s;
}
.rc-tec-bar-link:hover { color: #00e5a0; border-color: #00e5a040; }
.rc-tec-bar-link--primary { color: #00e5a0; border-color: #00e5a040; background: rgba(0,229,160,.06); }
.rc-tec-bar-pal kbd {
	background: #1e2130; border: 1px solid #2a2d3e; border-bottom-width: 2px;
	padding: 1px 5px; border-radius: 3px; font-size: .62rem; color: #c8cad8;
	font-family: inherit; margin: 0 1px;
}

/* ── Estado infra ─────────────────────────────────────────────────────── */
.rc-tec-status { padding: 1.5rem 1.5rem 0; background: #06080c; }
.rc-tec-status-head {
	display: flex; justify-content: space-between; align-items: center;
	margin-bottom: .75rem;
}
.rc-tec-status-label {
	font-size: .72rem; font-weight: 700; letter-spacing: .1em;
	text-transform: uppercase; color: #555c6e;
}
.rc-tec-status-refresh {
	display: inline-flex; align-items: center; gap: .4rem;
	background: none; border: 1px solid #1e2130; color: #7a7f8e;
	padding: .35rem .7rem; border-radius: 6px; cursor: pointer;
	font-size: .75rem;
}
.rc-tec-status-refresh:hover { color: #00e5a0; border-color: #00e5a040; }
.rc-tec-status-grid {
	display: grid; grid-template-columns: repeat(3, 1fr); gap: .75rem;
}
.rc-tec-status-card {
	display: flex; align-items: center; gap: .75rem;
	background: rgba(19,21,28,.6);
	border: 1px solid #1e2130;
	backdrop-filter: blur(8px);
	border-radius: 10px; padding: .8rem 1rem;
	font-size: .82rem;
}
.rc-tec-status-card > div { flex: 1; }
.rc-tec-status-card strong { display: block; color: #e8eaf0; font-size: .85rem; }
.rc-tec-status-card small  { color: #555c6e; font-size: .7rem; }
.rc-tec-status-dot {
	width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0;
	transition: background .3s, box-shadow .3s;
}
.rc-tec-status-dot--load { background: #555c6e; animation: rc-pulse-grey 1.2s infinite; }
.rc-tec-status-dot--ok   { background: #00e5a0; box-shadow: 0 0 8px #00e5a0a0; }
.rc-tec-status-dot--err  { background: #ff5252; box-shadow: 0 0 8px #ff5252a0; }
@keyframes rc-pulse-grey {
	0%,100% { opacity: .4; } 50% { opacity: 1; }
}
.rc-tec-status-ms { color: #555c6e; font-family: 'JetBrains Mono',monospace; font-size: .75rem; }

/* ── Section ──────────────────────────────────────────────────────────── */
.rc-tec-section { padding: 2.5rem 1.5rem 3rem; }

/* ── Tabs ─────────────────────────────────────────────────────────────── */
.rc-tabs {
	display: flex; gap: .25rem;
	border-bottom: 2px solid #1a1d24;
	margin-bottom: 2rem;
	position: sticky; top: 0; z-index: 10;
	background: rgba(6,8,12,.85);
	backdrop-filter: blur(10px);
	padding-top: .5rem;
}
.rc-tab {
	background: none; border: none; cursor: pointer;
	color: #7a7f8e; font-size: .9rem; font-weight: 600;
	padding: .7rem 1.4rem;
	border-bottom: 2px solid transparent;
	margin-bottom: -2px;
	transition: color .15s, border-color .15s;
	display: inline-flex; align-items: center; gap: .5rem;
}
.rc-tab kbd {
	font-family: inherit; font-size: .65rem;
	background: #13151c; border: 1px solid #2a2d3e; border-bottom-width: 2px;
	padding: 1px 5px; border-radius: 3px; color: #555c6e;
}
.rc-tab:hover  { color: #c8cad8; }
.rc-tab--active { color: #00e5a0; border-bottom-color: #00e5a0; }
.rc-tab--active kbd { color: #00e5a0; border-color: #00e5a040; }

/* ── Glass card ───────────────────────────────────────────────────────── */
.rc-dl-card {
	position: relative;
	background: linear-gradient(180deg, rgba(19,21,28,.85), rgba(13,15,20,.85));
	border: 1px solid #1e2130;
	backdrop-filter: blur(12px);
	border-radius: 14px;
	padding: 2rem;
	margin-bottom: 1.5rem;
	overflow: hidden;
}
.rc-dl-card-bar {
	position: absolute; top: 0; left: 0; right: 0; height: 3px;
}
.rc-dl-card--windows .rc-dl-card-bar { background: linear-gradient(90deg,#4fc3f7,#1565c0); }
.rc-dl-card--linux   .rc-dl-card-bar { background: linear-gradient(90deg,#ffd54f,#ff9800); }
.rc-dl-card--kit     .rc-dl-card-bar { background: linear-gradient(90deg,#00e5a0,#00c988); }

.rc-dl-card-header { display: flex; align-items: center; gap: 1rem; margin-bottom: 1.25rem; }
.rc-dl-platform-icon {
	width: 52px; height: 52px; border-radius: 12px;
	display: grid; place-items: center; flex-shrink: 0;
}
.rc-dl-icon--win   { background: rgba(30,58,95,.5); color: #4fc3f7; border: 1px solid #1565c040; }
.rc-dl-icon--linux { background: rgba(42,31,0,.5);  color: #ffd54f; border: 1px solid #ffd54f30; }
.rc-dl-icon--kit   { background: rgba(26,45,26,.5); color: #00e5a0; border: 1px solid #00e5a040; }
.rc-dl-card-title { font-size: 1.2rem; font-weight: 700; color: #e8eaf0; margin: 0 0 .2rem; }
.rc-dl-card-sub   { font-size: .8rem; color: #7a7f8e; margin: 0; }
.rc-dl-badge {
	margin-left: auto; font-size: .7rem; font-weight: 700;
	padding: .25rem .6rem; border-radius: 2rem; text-transform: uppercase;
}
.rc-dl-badge--green { background: rgba(0,229,160,.1); color: #00e5a0; border: 1px solid #00e5a040; }
.rc-dl-badge--blue  { background: rgba(21,101,192,.15); color: #64b5f6; border: 1px solid #1565c050; }
.rc-dl-desc { color: #9da2b0; font-size: .92rem; margin-bottom: 1.5rem; }

/* ── Terminal mock ────────────────────────────────────────────────────── */
.rc-terminal {
	background: #04060a;
	border: 1px solid #1e2130;
	border-radius: 10px;
	overflow: hidden;
	margin-bottom: 1rem;
	box-shadow: 0 8px 24px rgba(0,0,0,.4);
}
.rc-terminal-chrome {
	display: flex; align-items: center; gap: .4rem;
	background: #0d0f14;
	padding: .55rem .9rem;
	border-bottom: 1px solid #1a1d24;
}
.rc-terminal-dot { width: 11px; height: 11px; border-radius: 50%; }
.rc-terminal-dot--r { background: #ff5f56; }
.rc-terminal-dot--y { background: #ffbd2e; }
.rc-terminal-dot--g { background: #27c93f; }
.rc-terminal-title {
	flex: 1; text-align: center;
	font-size: .72rem; color: #555c6e; font-family: 'JetBrains Mono',monospace;
}
.rc-terminal-body {
	padding: 1rem 1.1rem;
	display: flex; align-items: flex-start; gap: .6rem;
	font-family: 'JetBrains Mono',ui-monospace,monospace;
	font-size: .85rem; line-height: 1.5;
	word-break: break-all;
}
.rc-terminal-prompt { color: #00e5a0; flex-shrink: 0; user-select: none; }
.rc-terminal-cmd    { color: #e8eaf0; background: none; }
.rc-terminal-cmd::after {
	content: '▍'; color: #00e5a0;
	animation: rc-blink 1s steps(2) infinite;
}
@keyframes rc-blink { 50% { opacity: 0; } }
.rc-terminal-actions {
	display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap;
	gap: .5rem;
	padding: .6rem .9rem;
	border-top: 1px solid #1a1d24;
	background: rgba(13,15,20,.5);
}
.rc-terminal-note { color: #555c6e; font-size: .72rem; }
.rc-terminal-btns { display: flex; gap: .4rem; }

/* ── Mini button ──────────────────────────────────────────────────────── */
.rc-mini-btn {
	display: inline-flex; align-items: center; gap: .35rem;
	background: #1e2130; border: 1px solid #2a2d3e; color: #c8cad8;
	font-size: .72rem; padding: .35rem .7rem; border-radius: 6px;
	cursor: pointer; text-decoration: none;
	transition: background .15s, color .15s, border-color .15s;
}
.rc-mini-btn:hover { background: #252838; color: #e8eaf0; }
.rc-mini-btn.rc-copied {
	background: rgba(0,229,160,.15); color: #00e5a0; border-color: #00e5a050;
}
.rc-mini-btn--primary {
	background: #00c988; color: #04060a; border-color: #00c988;
}
.rc-mini-btn--primary:hover { background: #00e5a0; color: #04060a; }

/* ── OR divider ───────────────────────────────────────────────────────── */
.rc-dl-or {
	display: flex; align-items: center; gap: 1rem;
	color: #3a3d4e; font-size: .75rem; margin: 1rem 0;
	text-transform: uppercase; letter-spacing: .1em;
}
.rc-dl-or::before, .rc-dl-or::after {
	content: ''; flex: 1; height: 1px; background: #1e2130;
}

/* ── Download button ──────────────────────────────────────────────────── */
.rc-dl-btn-wrap { text-align: center; margin-bottom: 1.5rem; }
.rc-dl-btn {
	display: inline-flex; align-items: center; gap: .6rem;
	background: linear-gradient(135deg,#00c988,#00e5a0);
	color: #0a0c10; font-weight: 700; font-size: .95rem;
	padding: .9rem 2rem; border-radius: 10px; text-decoration: none;
	transition: transform .15s, box-shadow .15s;
	box-shadow: 0 4px 20px rgba(0,229,160,.25);
}
.rc-dl-btn:hover { transform: translateY(-2px); box-shadow: 0 8px 28px rgba(0,229,160,.4); color: #0a0c10; }
.rc-dl-size {
	font-size: .75rem; font-weight: 600;
	background: rgba(0,0,0,.2); padding: .2rem .55rem; border-radius: 5px;
}

/* ── Metadata ─────────────────────────────────────────────────────────── */
.rc-dl-meta {
	display: grid; grid-template-columns: auto auto 1fr; gap: .5rem 1.5rem;
	background: #04060a;
	border: 1px solid #1a1d24; border-radius: 8px;
	padding: .85rem 1rem;
	margin-bottom: 1.5rem;
	font-size: .78rem;
}
.rc-dl-meta > div { display: flex; align-items: center; gap: .5rem; min-width: 0; }
.rc-dl-meta-sha { grid-column: 1 / -1; }
.rc-dl-meta dt { color: #555c6e; text-transform: uppercase; letter-spacing: .08em; font-size: .68rem; }
.rc-dl-meta dd { margin: 0; color: #c8cad8; }
.rc-sha {
	color: #00e5a0; font-family: 'JetBrains Mono',monospace; font-size: .7rem;
	background: none;
	word-break: break-all; flex: 1;
}
.rc-muted { color: #555c6e; }

/* ── Troubleshooting ──────────────────────────────────────────────────── */
.rc-dl-trouble {
	background: rgba(255,213,79,.05);
	border: 1px solid rgba(255,213,79,.2);
	border-radius: 8px;
	padding: .75rem 1rem;
	margin-bottom: 1.5rem;
	font-size: .82rem;
}
.rc-dl-trouble summary {
	cursor: pointer; color: #ffd54f; font-weight: 600;
	list-style: none;
}
.rc-dl-trouble summary::-webkit-details-marker { display: none; }
.rc-dl-trouble ul { margin: .75rem 0 0; padding-left: 1.25rem; color: #9da2b0; }
.rc-dl-trouble li { margin-bottom: .4rem; }
.rc-dl-trouble code { background: #04060a; color: #ffd54f; padding: .1rem .4rem; border-radius: 4px; font-size: .78rem; }

/* ── Checklist ────────────────────────────────────────────────────────── */
.rc-dl-steps { margin-top: 1.75rem; }
.rc-dl-steps-title {
	font-size: .85rem; font-weight: 700; color: #7a7f8e;
	letter-spacing: .06em; text-transform: uppercase; margin-bottom: .75rem;
}
.rc-checklist { list-style: none; margin: 0; padding: 0; }
.rc-checklist li {
	padding: .5rem .75rem;
	border-left: 2px solid #1e2130;
	transition: border-color .2s, background .2s;
}
.rc-checklist label {
	display: flex; align-items: flex-start; gap: .6rem;
	cursor: pointer; color: #9da2b0; font-size: .9rem;
}
.rc-checklist input[type=checkbox] {
	accent-color: #00e5a0; margin-top: .2rem; flex-shrink: 0;
}
.rc-checklist input:checked ~ span { color: #555c6e; text-decoration: line-through; }
.rc-checklist li:has(input:checked) {
	border-left-color: #00e5a0;
	background: rgba(0,229,160,.04);
}

/* ── Includes table ───────────────────────────────────────────────────── */
.rc-dl-includes { margin-top: 1.5rem; }
.rc-dl-includes h3 {
	font-size: .85rem; font-weight: 700; color: #7a7f8e;
	letter-spacing: .06em; text-transform: uppercase; margin-bottom: .75rem;
}
.rc-dl-table { width: 100%; border-collapse: collapse; font-size: .85rem; color: #9da2b0; }
.rc-dl-table th { text-align: left; color: #555c6e; font-weight: 600; font-size: .72rem; text-transform: uppercase; letter-spacing: .05em; padding: .5rem .75rem; border-bottom: 1px solid #1e2130; }
.rc-dl-table td { padding: .55rem .75rem; border-bottom: 1px solid #13151c; }
.rc-dl-table td:first-child { color: #c8cad8; }
.rc-dl-table td code { background: #04060a; color: #64b5f6; padding: .1rem .4rem; border-radius: 4px; font-size: .78rem; }

/* ── Kit generator ────────────────────────────────────────────────────── */
.rc-kit-gen {
	margin-top: 1.5rem; padding: 1rem 1.25rem;
	background: rgba(0,229,160,.04);
	border: 1px solid rgba(0,229,160,.15);
	border-radius: 10px;
}
.rc-kit-gen h3 { font-size: .9rem; color: #00e5a0; margin: 0 0 .25rem; }
.rc-kit-form {
	display: flex; gap: .75rem; align-items: flex-end; flex-wrap: wrap;
	margin-top: .75rem;
}
.rc-kit-form label { display: flex; flex-direction: column; gap: .25rem; flex: 1; min-width: 140px; }
.rc-kit-form span  { font-size: .7rem; color: #7a7f8e; text-transform: uppercase; letter-spacing: .05em; }
.rc-kit-form input {
	background: #04060a; border: 1px solid #1e2130; border-radius: 6px;
	padding: .5rem .7rem; color: #e8eaf0; font-size: .85rem;
}
.rc-kit-form input:focus { outline: none; border-color: #00e5a060; }

/* ── Mis tickets ──────────────────────────────────────────────────────── */
.rc-tec-tickets { padding: 2rem 1.5rem; background: #0a0c10; border-top: 1px solid #1a1d24; }
.rc-tec-tickets-head {
	display: flex; justify-content: space-between; align-items: center;
	margin-bottom: 1rem;
}
.rc-tec-tickets-head h2 {
	font-size: .85rem; font-weight: 700; color: #7a7f8e;
	letter-spacing: .08em; text-transform: uppercase; margin: 0;
}
.rc-tickets-list { display: flex; flex-direction: column; gap: .5rem; }
.rc-tickets-loading, .rc-tickets-empty { color: #555c6e; font-size: .85rem; padding: 1rem; text-align: center; }
.rc-ticket {
	display: flex; align-items: center; gap: .75rem;
	background: rgba(19,21,28,.6); border: 1px solid #1e2130;
	border-radius: 8px; padding: .75rem 1rem;
	text-decoration: none; color: #c8cad8;
	transition: border-color .15s, background .15s;
}
.rc-ticket:hover { border-color: #00e5a040; background: rgba(19,21,28,.9); color: #e8eaf0; }
.rc-ticket-id { font-family: 'JetBrains Mono',monospace; color: #00e5a0; font-weight: 700; font-size: .85rem; min-width: 50px; }
.rc-ticket-sum { flex: 1; font-size: .88rem; }
.rc-ticket-status {
	font-size: .68rem; text-transform: uppercase; letter-spacing: .05em;
	padding: .2rem .55rem; border-radius: 4px;
	background: #1e2130; color: #9da2b0;
}
.rc-ticket-prio { font-size: .68rem; color: #ff8a65; }

/* ── Quick links ──────────────────────────────────────────────────────── */
.rc-tec-links { background: #06080c; border-top: 1px solid #1a1d24; padding: 2rem 1.5rem 3rem; }
.rc-tec-links-title { text-align: center; font-size: .8rem; font-weight: 700; color: #555c6e; letter-spacing: .08em; text-transform: uppercase; margin-bottom: 1.5rem; }
.rc-tec-links-grid  { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: .75rem; max-width: 640px; margin: 0 auto; }
.rc-tlink {
	display: flex; flex-direction: column; align-items: center; gap: .5rem;
	background: rgba(19,21,28,.6); border: 1px solid #1e2130; border-radius: 10px;
	padding: 1.1rem 1rem; text-decoration: none; color: #9da2b0;
	font-size: .82rem; transition: all .15s;
}
.rc-tlink:hover { border-color: #00e5a040; color: #00e5a0; transform: translateY(-2px); }
.rc-tlink svg { stroke: currentColor; }

/* ── Hotkeys hint ─────────────────────────────────────────────────────── */
.rc-tec-hotkeys {
	position: fixed; bottom: 1rem; right: 1rem;
	background: rgba(13,15,20,.85); backdrop-filter: blur(8px);
	border: 1px solid #1e2130; border-radius: 8px;
	padding: .4rem .7rem; font-size: .7rem; color: #555c6e;
	z-index: 50;
}
.rc-tec-hotkeys kbd {
	background: #1e2130; border: 1px solid #2a2d3e; border-bottom-width: 2px;
	padding: 1px 5px; border-radius: 3px; margin: 0 2px;
	font-family: inherit; font-size: .65rem; color: #c8cad8;
}

/* ── Dashboard ticket activo ──────────────────────────────────────────── */
.rc-tec-dash {
	position: sticky; top: 50px; z-index: 20;
	background: rgba(10,12,16,.92); backdrop-filter: blur(12px);
	border-top: 1px solid #00e5a040;
	border-bottom: 1px solid #00e5a040;
	padding: 1rem 1.5rem;
	box-shadow: 0 8px 30px rgba(0,0,0,.4);
}
.rc-dash-header {
	display: flex; justify-content: space-between; align-items: center;
	flex-wrap: wrap; gap: 1rem; margin-bottom: 1rem;
}
.rc-dash-pin {
	display: flex; align-items: center; gap: .5rem;
	color: #00e5a0; font-weight: 600; font-size: .9rem;
}
.rc-dash-pin strong { color: #e8eaf0; font-family: 'JetBrains Mono',monospace; }
.rc-dash-pin #rc-dash-sum { font-size: .8rem; font-weight: 400; }
.rc-dash-timer {
	display: flex; align-items: center; gap: .5rem;
}
.rc-dash-timer #rc-dash-elapsed {
	font-family: 'JetBrains Mono',monospace; font-size: 1.1rem; font-weight: 700;
	color: #00e5a0;
	background: rgba(0,229,160,.08); border: 1px solid #00e5a030;
	padding: .35rem .75rem; border-radius: 6px;
	min-width: 90px; text-align: center;
}
.rc-dash-grid {
	display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: .75rem;
}
.rc-dash-block {
	background: rgba(19,21,28,.6); border: 1px solid #1e2130;
	border-radius: 10px; padding: .85rem;
}
.rc-dash-block h4 {
	font-size: .7rem; font-weight: 700; color: #7a7f8e;
	letter-spacing: .08em; text-transform: uppercase; margin: 0 0 .6rem;
}
.rc-dash-block textarea, .rc-dash-block input {
	width: 100%;
	background: #04060a; border: 1px solid #1e2130; color: #e8eaf0;
	border-radius: 6px; padding: .45rem .6rem;
	font-size: .82rem; font-family: inherit;
	resize: vertical;
}
.rc-dash-block textarea:focus, .rc-dash-block input:focus {
	outline: none; border-color: #00e5a060;
}
.rc-dash-row {
	display: flex; justify-content: space-between; align-items: center; gap: .5rem;
	margin-top: .5rem;
}
.rc-fact-form { display: grid; grid-template-columns: 1.5fr 1fr 1fr; gap: .4rem; margin-bottom: .5rem; }
.rc-fact-form label { display: flex; flex-direction: column; font-size: .65rem; color: #7a7f8e; text-transform: uppercase; gap: .2rem; }
.rc-anydesk-recent {
	list-style: none; margin: .6rem 0 0; padding: 0;
	max-height: 80px; overflow-y: auto;
}
.rc-anydesk-recent li {
	display: flex; justify-content: space-between; align-items: center;
	padding: .25rem .4rem; font-size: .76rem; color: #9da2b0;
	border-bottom: 1px solid #13151c;
}
.rc-anydesk-recent button {
	background: none; border: none; color: #00e5a0; cursor: pointer; font-size: .7rem;
}

/* ── Command palette ─────────────────────────────────────────────────── */
.rc-palette {
	position: fixed; inset: 0; z-index: 1100;
	display: grid; place-items: flex-start center;
	padding-top: 12vh;
}
.rc-palette[hidden] { display: none; }
.rc-palette-bg { position: absolute; inset: 0; background: rgba(0,0,0,.65); backdrop-filter: blur(6px); }
.rc-palette-box {
	position: relative;
	width: min(640px, 92vw);
	background: #13151c; border: 1px solid #2a2d3e;
	border-radius: 12px; overflow: hidden;
	box-shadow: 0 30px 80px rgba(0,0,0,.6);
}
.rc-palette-input-row {
	display: flex; align-items: center; gap: .6rem;
	padding: .85rem 1rem;
	border-bottom: 1px solid #1e2130;
	color: #555c6e;
}
.rc-palette-input-row input {
	flex: 1;
	background: none; border: none; color: #e8eaf0;
	font-size: .95rem; outline: none;
}
.rc-palette-input-row kbd {
	background: #1e2130; border: 1px solid #2a2d3e; border-bottom-width: 2px;
	padding: 1px 6px; border-radius: 3px; font-size: .65rem; color: #7a7f8e;
}
.rc-palette-list {
	list-style: none; margin: 0; padding: .4rem 0;
	max-height: 50vh; overflow-y: auto;
}
.rc-palette-list li {
	display: flex; align-items: center; gap: .6rem;
	padding: .55rem 1rem; cursor: pointer;
	color: #c8cad8; font-size: .88rem;
}
.rc-palette-list li.rc-pal-active {
	background: rgba(0,229,160,.1); color: #00e5a0;
}
.rc-palette-list .rc-pal-cat {
	font-size: .65rem; text-transform: uppercase; letter-spacing: .06em;
	color: #555c6e; background: #1e2130;
	padding: .15rem .45rem; border-radius: 3px;
	margin-left: auto;
}
.rc-palette-list .rc-pal-empty {
	padding: 1.5rem; text-align: center; color: #555c6e; font-style: italic;
}
.rc-palette-footer {
	display: flex; gap: 1rem; justify-content: center;
	padding: .55rem 1rem; border-top: 1px solid #1e2130;
	background: #0d0f14;
	font-size: .7rem; color: #555c6e;
}
.rc-palette-footer kbd {
	background: #1e2130; border: 1px solid #2a2d3e; border-bottom-width: 2px;
	padding: 1px 5px; border-radius: 3px; font-size: .65rem; color: #c8cad8;
	margin: 0 1px;
}

/* ── Responsive ───────────────────────────────────────────────────────── */
@media (max-width: 720px) {
	.rc-tec-status-grid { grid-template-columns: 1fr; }
	.rc-dl-card { padding: 1.25rem; }
	.rc-dl-card-header { flex-wrap: wrap; }
	.rc-dl-badge { margin-left: 0; }
	.rc-dl-btn { width: 100%; justify-content: center; }
	.rc-dl-meta { grid-template-columns: 1fr; }
	.rc-tabs { overflow-x: auto; }
	.rc-tec-hotkeys { display: none; }
}
</style>

<script>
(function () {
	'use strict';

	var ajaxUrl = '<?php echo esc_js( admin_url( 'admin-ajax.php' ) ); ?>';
	var nonce   = '<?php echo esc_js( $nonce_ajax ); ?>';

	// ── Tabs ─────────────────────────────────────────────────────────────
	function activateTab(name) {
		document.querySelectorAll('.rc-tab').forEach(function (b) {
			var on = b.dataset.tab === name;
			b.classList.toggle('rc-tab--active', on);
			b.setAttribute('aria-selected', on ? 'true' : 'false');
		});
		document.querySelectorAll('.rc-tab-panel').forEach(function (p) {
			var on = p.id === 'tab-' + name;
			p.classList.toggle('rc-tab-panel--active', on);
			p.hidden = !on;
		});
		try { localStorage.setItem('rc-tec-tab', name); } catch(e){}
	}
	document.querySelectorAll('.rc-tab').forEach(function (btn) {
		btn.addEventListener('click', function () { activateTab(btn.dataset.tab); });
	});

	// Auto-detect SO
	function detectOS() {
		try {
			var saved = localStorage.getItem('rc-tec-tab');
			if (saved && ['windows','linux','kit'].indexOf(saved) >= 0) return saved;
		} catch(e){}
		var ua = (navigator.userAgent || '').toLowerCase();
		if (ua.indexOf('linux') >= 0 && ua.indexOf('android') < 0) return 'linux';
		if (ua.indexOf('mac') >= 0) return 'linux';
		return 'windows';
	}
	activateTab(detectOS());

	// ── Copy buttons ─────────────────────────────────────────────────────
	function flashCopied(btn) {
		var prev = btn.innerHTML;
		btn.innerHTML = '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="3"><polyline points="20 6 9 17 4 12"/></svg> ¡Copiado!';
		btn.classList.add('rc-copied');
		setTimeout(function () {
			btn.innerHTML = prev;
			btn.classList.remove('rc-copied');
		}, 1600);
	}
	function copyText(text, btn) {
		if (!text) return;
		if (navigator.clipboard && window.isSecureContext) {
			navigator.clipboard.writeText(text).then(function () { flashCopied(btn); }).catch(function(){ legacyCopy(text, btn); });
		} else {
			legacyCopy(text, btn);
		}
	}
	function legacyCopy(text, btn) {
		var ta = document.createElement('textarea');
		ta.value = text;
		ta.style.position = 'fixed'; ta.style.opacity = '0';
		document.body.appendChild(ta); ta.select();
		try { document.execCommand('copy'); flashCopied(btn); } catch(e){}
		document.body.removeChild(ta);
	}
	document.querySelectorAll('.rc-copy-btn').forEach(function (btn) {
		btn.addEventListener('click', function () { copyText(btn.dataset.copy, btn); });
	});

	// ── Infraestructura ──────────────────────────────────────────────────
	function paintInfra(data) {
		['mantis','web','fleet'].forEach(function (svc) {
			var card = document.querySelector('[data-svc="' + svc + '"]');
			if (!card || !data[svc]) return;
			var dot = card.querySelector('.rc-tec-status-dot');
			var ms  = card.querySelector('.rc-tec-status-ms');
			dot.className = 'rc-tec-status-dot ' + (data[svc].ok ? 'rc-tec-status-dot--ok' : 'rc-tec-status-dot--err');
			ms.textContent = (data[svc].code || 'ERR') + ' · ' + (data[svc].ms || 0) + ' ms';
		});
	}
	function fetchInfra() {
		var fd = new FormData();
		fd.append('action', 'rc_tech_infra_status');
		fd.append('nonce', nonce);
		fetch(ajaxUrl, { method: 'POST', credentials: 'same-origin', body: fd })
			.then(function (r) { return r.json(); })
			.then(function (j) { if (j && j.success) paintInfra(j.data); })
			.catch(function () {});
	}
	fetchInfra();
	setInterval(fetchInfra, 60000);
	document.querySelector('.rc-tec-status-refresh').addEventListener('click', fetchInfra);

	// ── Mis tickets ──────────────────────────────────────────────────────
	function paintTickets(list) {
		var box = document.getElementById('rc-tickets');
		if (!list || !list.length) {
			box.innerHTML = '<div class="rc-tickets-empty">No hay tickets abiertos a tu nombre.</div>';
			return;
		}
		var html = list.map(function (t) {
			return '<a class="rc-ticket" href="https://mantis.resolvecore.website/view.php?id=' + t.id + '" target="_blank" rel="noopener">'
				+ '<span class="rc-ticket-id">#' + t.id + '</span>'
				+ '<span class="rc-ticket-sum">' + escapeHtml(t.summary) + '</span>'
				+ '<span class="rc-ticket-prio">' + escapeHtml(t.priority) + '</span>'
				+ '<span class="rc-ticket-status">' + escapeHtml(t.status) + '</span>'
				+ '</a>';
		}).join('');
		box.innerHTML = html;
	}
	function escapeHtml(s) { return String(s||'').replace(/[&<>"']/g, function(c){return ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[c];}); }
	function fetchTickets() {
		var fd = new FormData();
		fd.append('action', 'rc_tech_my_tickets');
		fd.append('nonce', nonce);
		fetch(ajaxUrl, { method: 'POST', credentials: 'same-origin', body: fd })
			.then(function (r) { return r.json(); })
			.then(function (j) {
				if (j && j.success) paintTickets(j.data.tickets || []);
				else document.getElementById('rc-tickets').innerHTML = '<div class="rc-tickets-empty">' + escapeHtml((j && j.data && j.data.msg) || 'Sin datos') + '</div>';
			})
			.catch(function () {
				document.getElementById('rc-tickets').innerHTML = '<div class="rc-tickets-empty">Error de red.</div>';
			});
	}
	fetchTickets();

	// ── Checklist persistido ─────────────────────────────────────────────
	document.querySelectorAll('.rc-checklist').forEach(function (list) {
		var key = 'rc-checklist-' + list.dataset.checklist;
		var saved = {};
		try { saved = JSON.parse(localStorage.getItem(key) || '{}'); } catch(e){}
		list.querySelectorAll('input[type=checkbox]').forEach(function (cb) {
			if (saved[cb.dataset.step]) cb.checked = true;
			cb.addEventListener('change', function () {
				try {
					var current = JSON.parse(localStorage.getItem(key) || '{}');
					current[cb.dataset.step] = cb.checked;
					localStorage.setItem(key, JSON.stringify(current));
				} catch(e){}
			});
		});
	});

	// ── Dashboard ticket activo ──────────────────────────────────────────
	var dash    = document.getElementById('rc-dash');
	var dashId  = document.getElementById('rc-dash-id');
	var dashSum = document.getElementById('rc-dash-sum');
	var dashElapsed = document.getElementById('rc-dash-elapsed');
	var dashToggleBtn = document.getElementById('rc-dash-toggle');
	var dashResetBtn  = document.getElementById('rc-dash-reset');
	var dashUnpinBtn  = document.getElementById('rc-dash-unpin');

	var pinned = null;   // { id, summary }
	var timer  = { start: 0, accumulated: 0, running: false, intervalId: null };

	function loadPinned() {
		try {
			pinned = JSON.parse(localStorage.getItem('rc-pinned-ticket') || 'null');
			var t  = JSON.parse(localStorage.getItem('rc-timer') || 'null');
			if (t) timer = Object.assign(timer, t);
		} catch(e){}
	}
	function savePinned() {
		try {
			localStorage.setItem('rc-pinned-ticket', JSON.stringify(pinned));
			localStorage.setItem('rc-timer', JSON.stringify({ start: timer.start, accumulated: timer.accumulated, running: timer.running }));
		} catch(e){}
	}
	function fmtElapsed(ms) {
		var s = Math.floor(ms / 1000);
		var h = Math.floor(s / 3600); s -= h * 3600;
		var m = Math.floor(s / 60); s -= m * 60;
		var p = function (n) { return n < 10 ? '0' + n : '' + n; };
		return p(h) + ':' + p(m) + ':' + p(s);
	}
	function tickTimer() {
		var ms = timer.accumulated + (timer.running ? Date.now() - timer.start : 0);
		dashElapsed.textContent = fmtElapsed(ms);
	}
	function startTimer() {
		if (timer.running) return;
		timer.start = Date.now(); timer.running = true;
		dashToggleBtn.textContent = 'Pausar';
		if (!timer.intervalId) timer.intervalId = setInterval(tickTimer, 500);
		savePinned();
	}
	function pauseTimer() {
		if (!timer.running) return;
		timer.accumulated += Date.now() - timer.start;
		timer.running = false;
		dashToggleBtn.textContent = 'Reanudar';
		savePinned();
	}
	function resetTimer() {
		timer.start = 0; timer.accumulated = 0; timer.running = false;
		dashToggleBtn.textContent = 'Iniciar';
		tickTimer();
		savePinned();
	}
	function renderDash() {
		if (!pinned) { dash.hidden = true; return; }
		dash.hidden = false;
		dashId.textContent = '#' + pinned.id;
		dashSum.textContent = pinned.summary || '';
		dashToggleBtn.textContent = timer.running ? 'Pausar' : (timer.accumulated ? 'Reanudar' : 'Iniciar');
		if (!timer.intervalId) timer.intervalId = setInterval(tickTimer, 500);
		tickTimer();
	}
	function pinTicket(id, summary) {
		pinned = { id: parseInt(id, 10), summary: summary || '' };
		timer = { start: 0, accumulated: 0, running: false, intervalId: timer.intervalId };
		savePinned();
		renderDash();
		startTimer();
		window.scrollTo({ top: 0, behavior: 'smooth' });
	}
	function unpinTicket() {
		pinned = null; resetTimer();
		try { localStorage.removeItem('rc-pinned-ticket'); localStorage.removeItem('rc-timer'); } catch(e){}
		renderDash();
	}
	dashToggleBtn.addEventListener('click', function () { timer.running ? pauseTimer() : startTimer(); });
	dashResetBtn .addEventListener('click', resetTimer);
	dashUnpinBtn .addEventListener('click', unpinTicket);

	loadPinned();
	renderDash();
	if (timer.running) startTimer();

	// Pin ticket desde widget: añadimos botón a cada ticket renderizado
	var paintTicketsOrig = paintTickets;
	paintTickets = function (list) {
		paintTicketsOrig(list);
		document.querySelectorAll('.rc-ticket').forEach(function (a, i) {
			if (!list[i]) return;
			var t = list[i];
			var pinBtn = document.createElement('button');
			pinBtn.type = 'button';
			pinBtn.className = 'rc-mini-btn';
			pinBtn.textContent = (pinned && pinned.id === t.id) ? 'Pinned' : 'Pin';
			pinBtn.addEventListener('click', function (ev) {
				ev.preventDefault(); ev.stopPropagation();
				pinTicket(t.id, t.summary);
				pinBtn.textContent = 'Pinned';
			});
			a.appendChild(pinBtn);
		});
	};

	// Add note al ticket pinned
	var noteText = document.getElementById('rc-note-text');
	var noteSend = document.getElementById('rc-note-send');
	var noteFb   = document.getElementById('rc-note-feedback');
	noteSend.addEventListener('click', function () {
		if (!pinned) { noteFb.textContent = 'Pin un ticket primero.'; return; }
		var txt = (noteText.value || '').trim();
		if (!txt) { noteFb.textContent = 'Texto vacío.'; return; }
		noteSend.disabled = true; noteFb.textContent = 'Enviando…';
		var fd = new FormData();
		fd.append('action', 'rc_tech_add_note');
		fd.append('nonce', nonce);
		fd.append('ticket_id', pinned.id);
		fd.append('text', txt);
		fetch(ajaxUrl, { method: 'POST', credentials: 'same-origin', body: fd })
			.then(function (r) { return r.json(); })
			.then(function (j) {
				noteSend.disabled = false;
				if (j && j.success) { noteFb.textContent = j.data.msg; noteText.value = ''; }
				else noteFb.textContent = (j && j.data && j.data.msg) || 'Error';
			})
			.catch(function () { noteSend.disabled = false; noteFb.textContent = 'Error red.'; });
	});

	// Upload informe
	var informeFile = document.getElementById('rc-informe-file');
	var informePick = document.getElementById('rc-informe-pick');
	var informeName = document.getElementById('rc-informe-name');
	var informeSend = document.getElementById('rc-informe-send');
	var informeFb   = document.getElementById('rc-informe-feedback');
	informePick.addEventListener('click', function () { informeFile.click(); });
	informeFile.addEventListener('change', function () {
		if (informeFile.files.length) {
			informeName.textContent = informeFile.files[0].name;
			informeSend.disabled = false;
		} else {
			informeName.textContent = 'Ningún fichero';
			informeSend.disabled = true;
		}
	});
	informeSend.addEventListener('click', function () {
		if (!pinned) { informeFb.textContent = 'Pin un ticket primero.'; return; }
		if (!informeFile.files.length) return;
		informeSend.disabled = true; informeFb.textContent = 'Subiendo…';
		var fd = new FormData();
		fd.append('action', 'rc_tech_upload_informe');
		fd.append('nonce', nonce);
		fd.append('ticket_id', pinned.id);
		fd.append('informe', informeFile.files[0]);
		fetch(ajaxUrl, { method: 'POST', credentials: 'same-origin', body: fd })
			.then(function (r) { return r.json(); })
			.then(function (j) {
				informeSend.disabled = false;
				if (j && j.success) {
					informeFb.textContent = j.data.msg;
					informeFile.value = ''; informeName.textContent = 'Ningún fichero';
					informeSend.disabled = true;
				} else informeFb.textContent = (j && j.data && j.data.msg) || 'Error';
			})
			.catch(function () { informeSend.disabled = false; informeFb.textContent = 'Error red.'; });
	});

	// Factura
	document.getElementById('rc-fact-go').addEventListener('click', function () {
		if (!pinned) { alert('Pin un ticket primero.'); return; }
		var cliente = (document.getElementById('rc-fact-cliente').value || '').trim() || 'Cliente';
		var horas   = parseFloat(document.getElementById('rc-fact-horas').value) || 1;
		var tarifa  = parseFloat(document.getElementById('rc-fact-tarifa').value) || 35;
		var url = '<?php echo esc_js( home_url( '/tecnicos/' ) ); ?>?rc_factura=' + pinned.id
			+ '&cliente=' + encodeURIComponent(cliente)
			+ '&horas=' + horas + '&tarifa=' + tarifa
			+ '&_wpnonce=<?php echo esc_js( wp_create_nonce( 'rc_factura' ) ); ?>';
		window.open(url, '_blank');
	});

	// AnyDesk launcher
	var anydeskInput  = document.getElementById('rc-anydesk-id');
	var anydeskGo     = document.getElementById('rc-anydesk-go');
	var anydeskRecent = document.getElementById('rc-anydesk-recent');
	function loadAnydeskHist() {
		try { return JSON.parse(localStorage.getItem('rc-anydesk-hist') || '[]'); } catch(e){ return []; }
	}
	function saveAnydeskHist(h) { try { localStorage.setItem('rc-anydesk-hist', JSON.stringify(h.slice(0,5))); } catch(e){} }
	function paintAnydeskHist() {
		var h = loadAnydeskHist();
		anydeskRecent.innerHTML = h.map(function (item) {
			return '<li><span>' + escapeHtml(item.id) + (item.ticket ? ' · #' + item.ticket : '') + '</span>'
				+ '<button data-anydesk="' + escapeHtml(item.id) + '">Conectar</button></li>';
		}).join('');
		anydeskRecent.querySelectorAll('button').forEach(function (b) {
			b.addEventListener('click', function () { launchAnydesk(b.dataset.anydesk); });
		});
	}
	function launchAnydesk(id) {
		if (!/^[0-9]{6,12}$/.test(id)) { alert('ID AnyDesk inválido.'); return; }
		var h = loadAnydeskHist();
		h = [{ id: id, ticket: pinned ? pinned.id : 0, at: Date.now() }]
			.concat(h.filter(function (x) { return x.id !== id; }));
		saveAnydeskHist(h);
		paintAnydeskHist();
		window.location.href = 'anydesk:' + id;
	}
	anydeskGo.addEventListener('click', function () { launchAnydesk(anydeskInput.value.trim()); });
	anydeskInput.addEventListener('keydown', function (e) { if (e.key === 'Enter') launchAnydesk(anydeskInput.value.trim()); });
	paintAnydeskHist();

	// ── Command palette ──────────────────────────────────────────────────
	var palette  = document.getElementById('rc-palette');
	var palQ     = document.getElementById('rc-palette-q');
	var palList  = document.getElementById('rc-palette-list');
	var palItems = [];
	var palIdx   = 0;
	var palTickets = [];

	function buildPalItems() {
		var base = [
			{ cat: 'Tab', label: 'Ir a Windows',         action: function(){ activateTab('windows'); } },
			{ cat: 'Tab', label: 'Ir a Linux',           action: function(){ activateTab('linux'); } },
			{ cat: 'Tab', label: 'Ir a Kit cliente',     action: function(){ activateTab('kit'); } },
			{ cat: 'Acción', label: 'Copiar oneliner Windows', action: function(){ copyText('irm https://resolvecore.website/install.ps1 | iex', document.querySelector('.rc-copy-btn')); } },
			{ cat: 'Acción', label: 'Copiar oneliner Linux',   action: function(){ copyText('curl -fsSL https://resolvecore.website/install.sh | sudo bash', document.querySelector('.rc-copy-btn')); } },
			{ cat: 'Acción', label: 'Refrescar estado infra',  action: fetchInfra },
			{ cat: 'Acción', label: 'Refrescar mis tickets',   action: fetchTickets },
			{ cat: 'Link', label: 'Abrir MantisBT',  action: function(){ window.open('https://mantis.resolvecore.website','_blank'); } },
			{ cat: 'Link', label: 'Abrir Fleet panel', action: function(){ window.open('<?php echo esc_js( home_url( '/fleet-status/' ) ); ?>','_blank'); } },
			{ cat: 'Link', label: 'Abrir Changelog',  action: function(){ window.open('<?php echo esc_js( home_url( '/changelog/' ) ); ?>','_blank'); } },
			{ cat: 'Link', label: 'Abrir Documentación', action: function(){ window.open('<?php echo esc_js( home_url( '/docs/' ) ); ?>','_blank'); } },
		];
		palTickets.forEach(function (t) {
			base.push({
				cat: 'Ticket #' + t.id,
				label: t.summary,
				action: function () { pinTicket(t.id, t.summary); }
			});
		});
		return base;
	}
	function renderPalList(filter) {
		var q = (filter || '').toLowerCase().trim();
		palItems = buildPalItems().filter(function (it) {
			if (!q) return true;
			return (it.label + ' ' + it.cat).toLowerCase().indexOf(q) >= 0;
		});
		if (!palItems.length) {
			palList.innerHTML = '<li class="rc-pal-empty">Sin resultados</li>';
			return;
		}
		palList.innerHTML = palItems.map(function (it, i) {
			return '<li role="option" data-i="' + i + '" class="' + (i === 0 ? 'rc-pal-active' : '') + '">'
				+ '<span>' + escapeHtml(it.label) + '</span>'
				+ '<span class="rc-pal-cat">' + escapeHtml(it.cat) + '</span>'
				+ '</li>';
		}).join('');
		palIdx = 0;
		palList.querySelectorAll('li').forEach(function (li) {
			li.addEventListener('click', function () { runPal(parseInt(li.dataset.i, 10)); });
			li.addEventListener('mouseenter', function () { highlightPal(parseInt(li.dataset.i, 10)); });
		});
	}
	function highlightPal(i) {
		palIdx = i;
		palList.querySelectorAll('li').forEach(function (li, j) {
			li.classList.toggle('rc-pal-active', j === i);
		});
	}
	function runPal(i) {
		if (palItems[i]) { palItems[i].action(); closePalette(); }
	}
	function openPalette() {
		// Refresca tickets de cache (último fetchTickets los guardó si lo modificamos; usar globales).
		palTickets = window.__rcLastTickets || [];
		renderPalList('');
		palette.hidden = false;
		setTimeout(function () { palQ.value = ''; palQ.focus(); }, 0);
	}
	function closePalette() { palette.hidden = true; palQ.blur(); }
	palQ.addEventListener('input', function () { renderPalList(palQ.value); });
	palQ.addEventListener('keydown', function (e) {
		if (e.key === 'ArrowDown')      { e.preventDefault(); highlightPal(Math.min(palIdx + 1, palItems.length - 1)); }
		else if (e.key === 'ArrowUp')   { e.preventDefault(); highlightPal(Math.max(palIdx - 1, 0)); }
		else if (e.key === 'Enter')     { e.preventDefault(); runPal(palIdx); }
	});
	palette.querySelectorAll('[data-close]').forEach(function (el) { el.addEventListener('click', closePalette); });
	var barPalBtn = document.getElementById('rc-bar-palette');
	if (barPalBtn) barPalBtn.addEventListener('click', function () { palette.hidden ? openPalette() : closePalette(); });

	// Hook para guardar últimos tickets en global
	var paintTicketsForPalette = paintTickets;
	paintTickets = function (list) {
		window.__rcLastTickets = list || [];
		paintTicketsForPalette(list);
	};

	// ── Atajos teclado ───────────────────────────────────────────────────
	document.addEventListener('keydown', function (e) {
		// Ctrl/Cmd + K abre palette (siempre)
		if ((e.ctrlKey || e.metaKey) && (e.key === 'k' || e.key === 'K')) {
			e.preventDefault();
			palette.hidden ? openPalette() : closePalette();
			return;
		}
		if (e.key === 'Escape') {
			if (!palette.hidden) { closePalette(); return; }
		}
		if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) return;
		if (e.key === '1') activateTab('windows');
		else if (e.key === '2') activateTab('linux');
		else if (e.key === '3') activateTab('kit');
		else if (e.key === 'c' || e.key === 'C') {
			var activePanel = document.querySelector('.rc-tab-panel--active');
			if (!activePanel) return;
			var term = activePanel.querySelector('.rc-terminal');
			if (term) {
				var btn = term.querySelector('.rc-copy-btn');
				if (btn) copyText(term.dataset.oneliner, btn);
			}
		}
	});

})();
</script>

<?php get_footer(); ?>
