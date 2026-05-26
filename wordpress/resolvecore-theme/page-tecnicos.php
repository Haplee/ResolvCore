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

$dl_base    = home_url( '/tecnicos/' );
$build_date = '2026-05-26';
$nonce_ajax = wp_create_nonce( 'rc_tech_nonce' );
$nonce_kit  = wp_create_nonce( 'rc_tech_readme' );

$meta_win   = function_exists( 'rc_get_download_meta' ) ? rc_get_download_meta( 'windows' ) : array();
$meta_lin   = function_exists( 'rc_get_download_meta' ) ? rc_get_download_meta( 'linux' )   : array();
$meta_kit   = function_exists( 'rc_get_download_meta' ) ? rc_get_download_meta( 'kit' )     : array();
$stats      = function_exists( 'rc_tech_my_stats' )    ? rc_tech_my_stats()                 : array( 'total' => 0, 'last_at' => '' );

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

<!-- ── Hero ───────────────────────────────────────────────────────────── -->
<section class="rc-tec-hero">
	<div class="rc-tec-hero-mesh" aria-hidden="true"></div>
	<div class="rc-tec-hero-inner">
		<div class="rc-tec-badge">
			<span class="rc-tec-badge-dot"></span> Área restringida
		</div>
		<h1 class="rc-tec-title">Centro de Operaciones</h1>
		<p class="rc-tec-sub">
			Hola, <strong><?php echo esc_html( wp_get_current_user()->display_name ); ?></strong>.
			Herramientas, kits e infraestructura del soporte ResolveCore.
		</p>
		<div class="rc-tec-meta">
			<span>Build <?php echo esc_html( $build_date ); ?></span>
			<span>·</span>
			<a href="<?php echo esc_url( home_url( '/changelog/' ) ); ?>">Changelog</a>
			<span>·</span>
			<span class="rc-tec-stat">Tus descargas (30d): <strong><?php echo (int) $stats['total']; ?></strong></span>
		</div>
	</div>
</section>

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
		'windows' => array( 'icon_class' => 'rc-dl-icon--win',   'title' => 'Windows 10 / 11', 'sub' => 'PowerShell 5.1+ · Requiere Administrador', 'badge' => array( 'green', 'Listo' ) ),
		'linux'   => array( 'icon_class' => 'rc-dl-icon--linux', 'title' => 'Linux',           'sub' => 'Ubuntu 22.04+ · Debian 11+ · Fedora 37+ · Arch', 'badge' => array( 'green', 'Listo' ) ),
		'kit'     => array( 'icon_class' => 'rc-dl-icon--kit',   'title' => 'Kit de implantación', 'sub' => 'AnyDesk + scripts + README + MANIFEST', 'badge' => array( 'blue',  'Entrega' ) ),
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
	<div id="tab-<?php echo esc_attr( $key ); ?>" class="rc-tab-panel<?php echo $active; ?>"
	     role="tabpanel" aria-labelledby="btn-<?php echo esc_attr( $key ); ?>" <?php echo $hidden; ?>>

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
						<button class="rc-mini-btn rc-copy-btn" type="button"
						        data-copy="<?php echo esc_attr( $dl['oneliner'] ); ?>" aria-label="Copiar comando">
							<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
							Copiar
						</button>
						<button class="rc-mini-btn rc-qr-btn" type="button"
						        data-text="<?php echo esc_attr( $dl['oneliner'] ); ?>" aria-label="Mostrar QR">
							<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><path d="M14 14h3v3h-3zM20 14h1v3M14 20h3v1M20 20h1v1"/></svg>
							QR
						</button>
					</div>
				</div>
			</div>

			<div class="rc-dl-or"><span>o descarga directa</span></div>
			<?php endif; ?>

			<div class="rc-dl-btn-wrap">
				<a href="<?php echo esc_url( add_query_arg( 'rc_download', $key, $dl_base ) ); ?>"
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
						<button class="rc-mini-btn rc-copy-btn" type="button"
						        data-copy="<?php echo esc_attr( $sha ); ?>" aria-label="Copiar hash">
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
							<input type="checkbox" data-step="<?php echo $i; ?>">
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

<!-- ── Mis tickets MantisBT ───────────────────────────────────────────── -->
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

<!-- ── Modal QR ────────────────────────────────────────────────────────── -->
<div id="rc-qr-modal" class="rc-modal" hidden aria-hidden="true" role="dialog" aria-modal="true" aria-labelledby="rc-qr-title">
	<div class="rc-modal-bg" data-close></div>
	<div class="rc-modal-box">
		<button class="rc-modal-x" type="button" data-close aria-label="Cerrar">×</button>
		<h3 id="rc-qr-title">Escanea con el móvil</h3>
		<div id="rc-qr-canvas"></div>
		<p class="rc-muted" id="rc-qr-text"></p>
	</div>
</div>

<!-- ── Atajos teclado hint ─────────────────────────────────────────────── -->
<div class="rc-tec-hotkeys" aria-hidden="true">
	<kbd>1</kbd><kbd>2</kbd><kbd>3</kbd> tabs · <kbd>C</kbd> copiar · <kbd>?</kbd> ayuda
</div>

</main>

<style>
/* ── Reset / base ─────────────────────────────────────────────────────── */
.rc-tec { background: #06080c; color: #e8eaf0; }
.rc-tec * { box-sizing: border-box; }
.rc-tec-wrap { max-width: 920px; margin: 0 auto; padding: 0 1.5rem; }

/* ── Hero gradient mesh ───────────────────────────────────────────────── */
.rc-tec-hero {
	position: relative; overflow: hidden;
	padding: 4rem 1.5rem 3rem;
	text-align: center;
	background: #0a0c10;
	border-bottom: 1px solid #1a1d24;
}
.rc-tec-hero-mesh {
	position: absolute; inset: -20%;
	background:
		radial-gradient(circle at 20% 30%, #00e5a020 0%, transparent 40%),
		radial-gradient(circle at 80% 70%, #1565c020 0%, transparent 45%),
		radial-gradient(circle at 60% 20%, #7c4dff15 0%, transparent 50%);
	filter: blur(40px);
	animation: rc-mesh 18s ease-in-out infinite alternate;
	pointer-events: none;
}
@keyframes rc-mesh {
	0%   { transform: translate(0,0) scale(1); }
	100% { transform: translate(-3%,2%) scale(1.08); }
}
.rc-tec-hero-inner { position: relative; max-width: 680px; margin: 0 auto; }
.rc-tec-badge {
	display: inline-flex; align-items: center; gap: .4rem;
	font-size: .7rem; font-weight: 700; letter-spacing: .1em; text-transform: uppercase;
	color: #00e5a0;
	border: 1px solid #00e5a040;
	background: rgba(0,229,160,.08);
	backdrop-filter: blur(6px);
	padding: .3rem .8rem; border-radius: 2rem;
	margin-bottom: 1.25rem;
}
.rc-tec-badge-dot {
	width: 6px; height: 6px; border-radius: 50%;
	background: #00e5a0;
	box-shadow: 0 0 0 0 #00e5a080;
	animation: rc-pulse 2s infinite;
}
@keyframes rc-pulse {
	0%,100% { box-shadow: 0 0 0 0 #00e5a080; }
	50%     { box-shadow: 0 0 0 6px #00e5a000; }
}
.rc-tec-title {
	font-size: clamp(2rem,4.5vw,2.8rem); font-weight: 800; margin: 0 0 .75rem;
	background: linear-gradient(135deg,#e8eaf0 0%,#00e5a0 100%);
	-webkit-background-clip: text; background-clip: text; color: transparent;
}
.rc-tec-sub { color: #a0a4b0; margin: 0 0 1rem; font-size: 1.05rem; }
.rc-tec-meta { display: flex; gap: .6rem; justify-content: center; flex-wrap: wrap; font-size: .8rem; color: #555c6e; }
.rc-tec-meta a { color: #00e5a0; text-decoration: none; }
.rc-tec-stat strong { color: #c8cad8; }

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

/* ── Modal QR ─────────────────────────────────────────────────────────── */
.rc-modal {
	position: fixed; inset: 0; z-index: 1000;
	display: grid; place-items: center;
}
.rc-modal[hidden] { display: none; }
.rc-modal-bg { position: absolute; inset: 0; background: rgba(0,0,0,.7); backdrop-filter: blur(4px); }
.rc-modal-box {
	position: relative;
	background: #13151c; border: 1px solid #1e2130;
	border-radius: 14px; padding: 1.5rem;
	min-width: 280px; max-width: 90vw;
	text-align: center;
	box-shadow: 0 20px 60px rgba(0,0,0,.5);
}
.rc-modal-box h3 { margin: 0 0 1rem; color: #e8eaf0; font-size: 1rem; }
.rc-modal-x {
	position: absolute; top: .5rem; right: .75rem;
	background: none; border: none; color: #7a7f8e; cursor: pointer;
	font-size: 1.5rem; line-height: 1; padding: .25rem .5rem;
}
.rc-modal-x:hover { color: #e8eaf0; }
#rc-qr-canvas { display: grid; place-items: center; padding: 1rem; background: #fff; border-radius: 8px; }
#rc-qr-canvas svg { display: block; }
#rc-qr-text { font-family: 'JetBrains Mono',monospace; font-size: .72rem; margin: .75rem 0 0; word-break: break-all; }

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

	// ── QR (canvas simple, sin librerías externas — usa API qrserver.com como fallback img) ──
	// Implementación matricial QR sería demasiado código; usamos generador remoto via img.
	var qrModal = document.getElementById('rc-qr-modal');
	function openQR(text) {
		document.getElementById('rc-qr-text').textContent = text;
		var canvas = document.getElementById('rc-qr-canvas');
		canvas.innerHTML = '<img alt="QR" width="220" height="220" src="https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=' + encodeURIComponent(text) + '">';
		qrModal.hidden = false;
		qrModal.setAttribute('aria-hidden', 'false');
	}
	function closeQR() {
		qrModal.hidden = true;
		qrModal.setAttribute('aria-hidden', 'true');
	}
	document.querySelectorAll('.rc-qr-btn').forEach(function (btn) {
		btn.addEventListener('click', function () { openQR(btn.dataset.text); });
	});
	qrModal.querySelectorAll('[data-close]').forEach(function (el) {
		el.addEventListener('click', closeQR);
	});

	// ── Atajos teclado ───────────────────────────────────────────────────
	document.addEventListener('keydown', function (e) {
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
		} else if (e.key === 'Escape' && !qrModal.hidden) closeQR();
	});

})();
</script>

<?php get_footer(); ?>
