<?php
/**
 * MantisBT Plugin — ResolveCore Branding
 *
 * Aplica la identidad visual de ResolveCore a la instalación de Mantis:
 *   - Logo y cabecera corporativa.
 *   - Footer con autoría y eslogan.
 *   - CSS oscuro coherente con resolvecore.website (mismas vars).
 *
 * Instalación:
 *   1. Copiar carpeta a /var/www/mantis/plugins/ResolveCoreBranding/
 *   2. Login como admin en MantisBT > Gestionar > Gestionar plugins
 *   3. Instalar y activar.
 *
 * Autor:   Francisco Vidal Mateo (GitHub: Haplee)
 * Versión: 1.2
 */

class ResolveCoreBranding extends MantisPlugin {

	function register() {
		$this->name        = 'ResolveCore Branding';
		$this->description = 'Logo, título y CSS corporativo de ResolveCore.';
		$this->version     = '1.2';
		$this->author      = 'Francisco Vidal Mateo';
		$this->url         = 'https://resolvecore.website';
	}

	function hooks() {
		// Solo enganchamos lo imprescindible: cabecera, pie y CSS.
		return array(
			'EVENT_LAYOUT_PAGE_HEADER' => 'page_header',
			'EVENT_LAYOUT_PAGE_FOOTER' => 'page_footer',
			'EVENT_LAYOUT_RESOURCES'   => 'resources',
		);
	}


	/**
	 * Estilos corporativos — fondo oscuro, verde de marca, tipografía mono
	 * para títulos. Mantenemos las clases de Mantis para no romper layout
	 * pero las repintamos.
	 */
	function resources( $p_event ) {
		return $this->favicon_link()
		     . $this->css_block()
		     . $this->enhance_script();
	}

	/**
	 * Favicon dedicado a tamanos pequenos. El logo completo (resolvcore-icon)
	 * tiene trazos finos y contorno que se empastan al reducirse a 16/32px en la
	 * pestana; aqui se usa la variante simplificada (resolvcore-favicon), nitida
	 * a tamano pequeno. SVG primario en navegadores modernos; .ico + PNG 16/32
	 * de respaldo, y apple-touch 180 para marcadores en movil.
	 */
	private function favicon_link() {
		$base = 'https://resolvecore.website/wp-content/themes/resolvecore-theme/assets/logo';
		return '<link rel="icon" type="image/svg+xml" href="' . htmlspecialchars( $base . '/favicon.svg' ) . '">' . "\n"
		     . '<link rel="icon" type="image/png" sizes="96x96" href="' . htmlspecialchars( $base . '/favicon-96x96.png' ) . '">' . "\n"
		     . '<link rel="icon" type="image/x-icon" href="' . htmlspecialchars( $base . '/favicon.ico' ) . '">' . "\n"
		     . '<link rel="apple-touch-icon" sizes="180x180" href="' . htmlspecialchars( $base . '/apple-touch-icon.png' ) . '">' . "\n";
	}

	/**
	 * Script de mejora cargado como MÓDULO ES (type="module").
	 *
	 * Corrige dos avisos de consola de MantisBT:
	 *   - «Cannot use import statement outside a module»: cualquier JS con
	 *     sintaxis ESM debe servirse con type="module"; este bloque lo es, así
	 *     que es el sitio correcto para importar/añadir lógica moderna.
	 *   - «A form field element has neither an id nor a name attribute»: el core
	 *     imprime algunos input/select/textarea sin id ni name, lo que rompe el
	 *     autocompletado del navegador. Aquí se les asigna un name/id único y
	 *     estable derivado de su posición en el formulario.
	 */
	private function enhance_script() {
		return <<<'JS'
<script type="module">
const fixAnonymousFields = () => {
	document.querySelectorAll('form').forEach((form, fi) => {
		form.querySelectorAll('input, select, textarea').forEach((el, i) => {
			if (el.type === 'submit' || el.type === 'button') return;
			if (!el.name && !el.id) {
				const key = `rc-field-${fi}-${i}`;
				el.name = key;
				el.id = key;
			} else if (!el.id && el.name) {
				el.id = el.name;
			}
		});
	});
};

// Menu hamburguesa: en movil no se abria. El core de Mantis pinta un toggle con
// el icono FontAwesome 'fa-bars'; el override !important del CSS de marca podia
// estar tapando el comportamiento nativo. Alternamos una clase propia
// (rc-menu-open) que el CSS responsive de abajo hace visible.
// Usamos DELEGACION en document: el listener no depende de que el nodo exista
// al cargar, asi funciona aunque Mantis repinte la cabecera tras DOMContentLoaded.
// Si la version de Mantis usa otro selector, ampliar las listas de candidatos.
const RC_TOGGLE_SEL = '.fa-bars, .fa-navicon, i.menu-toggle, #menu-toggle, .menu-collapse, a.bars';
const RC_MENU_SEL = '#sidebar, .responsive-menu, #navbar, nav.menu, ul.menu, #nav-container';
const initMenuToggle = () => {
	document.addEventListener('click', (e) => {
		const hit = e.target.closest(RC_TOGGLE_SEL);
		if (!hit) return;
		const menu = document.querySelector(RC_MENU_SEL);
		if (!menu) return;
		e.preventDefault();
		menu.classList.toggle('rc-menu-open');
	});
};

// Arregla el enlace de la marca del navbar.
// A veces Mantis prepend el path completo y otras el short_path, resultando en:
// "/https://resolvecore.website" o "https://mantis.resolvecore.website/https://resolvecore.website"
const fixBrandLink = () => {
	document.querySelectorAll('a').forEach((a) => {
		const href = a.getAttribute('href') || '';
		if (href.includes('https://resolvecore.website') && href !== 'https://resolvecore.website') {
			a.setAttribute('href', 'https://resolvecore.website');
		}
	});
};

// Borra el pie del core de Mantis: "Powered by", "Copyright (c) ... MantisBT
// Team" y "Contacta con el administrador por ayuda". No queremos marca de
// Mantis: el unico pie es .rc-mantis-footer (lo deja page_footer).
const cleanFooter = () => {
	const scopes = document.querySelectorAll('#footer, footer, .bottom-padding');
	const matchTxt = (t) => {
		t = (t || '').toLowerCase();
		return t.includes('powered by')
			|| t.includes('mantisbt team')
			|| t.includes('copyright')
			|| t.includes('administrador por ayuda')
			|| t.includes('administrator for assistance');
	};
	scopes.forEach((foot) => {
		// Enlaces/imagenes a mantisbt.org (Powered by).
		foot.querySelectorAll('a[href*="mantisbt.org"], img[src*="mantis"]').forEach((e) => {
			const w = e.closest('address, p, span, li') || e;
			w.remove();
		});
		// Lineas de copyright / contacto admin (sin tocar .rc-mantis-footer).
		foot.querySelectorAll('address, p, span, div, li').forEach((e) => {
			if (e.closest('.rc-mantis-footer')) return;
			if (matchTxt(e.textContent) && e.children.length === 0) {
				e.remove();
			}
		});
		foot.querySelectorAll('address').forEach((e) => {
			if (!e.closest('.rc-mantis-footer') && matchTxt(e.textContent)) {
				e.remove();
			}
		});
	});
};

const rcInit = () => { fixAnonymousFields(); initMenuToggle(); fixBrandLink(); cleanFooter(); };
if (document.readyState !== 'loading') rcInit();
else document.addEventListener('DOMContentLoaded', rcInit);
</script>
JS;
	}

	private function css_block() {
		return <<<CSS
<style>
/* Tokens de marca ResolveCore (espejo de :root del tema). */
:root {
	--rc-bg: #0a0c10;
	--rc-surface: #111318;
	--rc-surface2: #16191f;
	--rc-accent: #00e5a0;
	--rc-accent2: #0099ff;
	--rc-text: #e8eaf0;
	--rc-muted: #7a7f8e;
	--rc-border: #1e2229;
	--rc-border2: #2a2f3a;
	/* Fondo de marca: gradientes radiales sutiles sobre el oscuro base. */
	--rc-grad-hero:
		radial-gradient(1200px 600px at 70% -10%, rgba(0,229,160,.10), transparent 60%),
		radial-gradient(900px 500px at 0% 10%, rgba(0,153,255,.08), transparent 55%);
}

/* Fondo de marca en toda la app + pantalla de login. */
body {
	background-color: var(--rc-bg) !important;
	background-image: var(--rc-grad-hero) !important;
	background-attachment: fixed !important;
	color: var(--rc-text) !important;
}
body.login_page, .login-container, #login-div {
	background-color: var(--rc-bg) !important;
	background-image: var(--rc-grad-hero) !important;
}

/* Cabecera / navegación. */
#header, .header, #navigation, .nav, .menu, .responsive-menu {
	background: var(--rc-surface) !important;
	border-bottom: 1px solid var(--rc-border) !important;
}

/* Enlaces. */
a, .bar-link {
	color: var(--rc-accent) !important;
}
a:hover {
	color: #00ffb3 !important;
}

/* Contenedores y tablas de bugs. */
.form-container, .widget-container, .table-container,
.login-container, .important-msg, .space-10 {
	background: var(--rc-surface) !important;
	border-color: var(--rc-border) !important;
}
table.width100, table.width100 td, .table-container table,
.table-container th, .table-container td {
	border-color: var(--rc-border) !important;
	color: var(--rc-text) !important;
}
table.width100 tr:nth-child(even) td,
.table-container tr:nth-child(even) td {
	background: rgba(255,255,255,.02) !important;
}
th, .row-category, .form-title, .widget-title {
	background: var(--rc-surface2) !important;
	color: var(--rc-text) !important;
}

/* Formularios. */
input, select, textarea {
	background: var(--rc-surface2) !important;
	color: var(--rc-text) !important;
	border: 1px solid var(--rc-border2) !important;
	border-radius: 5px !important;
}
input:focus, select:focus, textarea:focus {
	outline: none !important;
	border-color: var(--rc-accent) !important;
	box-shadow: 0 0 0 3px rgba(0,229,160,.12) !important;
}
input[type=submit], input[type=button], button, .btn {
	background: var(--rc-accent) !important;
	color: #000 !important;
	border: none !important;
	border-radius: 5px !important;
	font-weight: 700 !important;
	cursor: pointer;
}
input[type=submit]:hover, input[type=button]:hover, button:hover, .btn:hover {
	background: #00ffb3 !important;
}

/* Topbar de marca. */
.rc-mantis-topbar {
	display: flex;
	align-items: center;
	justify-content: center;
	padding: 10px;
	background: var(--rc-surface);
	border-bottom: 1px solid var(--rc-border);
}
.rc-mantis-topbar img {
	height: 28px;
	vertical-align: middle;
}
.rc-mantis-topbar span {
	color: var(--rc-muted);
	font-size: 12px;
	margin-left: 10px;
}
.rc-mantis-footer {
	text-align: center;
	padding: 14px 12px;
	color: var(--rc-muted);
	font-size: 11px;
	border-top: 1px solid var(--rc-border);
}

/* Respaldo CSS por si el JS no llega: oculta "Powered by Mantis" del pie core. */
#footer a[href*="mantisbt.org"],
footer a[href*="mantisbt.org"],
#footer img[src*="mantis"] {
	display: none !important;
}

/* ── Tema Ace / Bootstrap 3.4 (Mantis 2.x) ────────────────────────────────
   El core moderno pinta con clases de Ace (ace-mantis.css) y Bootstrap, no
   con las clases legacy de arriba. Sin estos overrides quedan paneles, navbar,
   sidebar, modales y tablas en BLANCO sobre el fondo oscuro. Repintamos todo
   con los mismos tokens de marca. */

/* Contenedores raiz Ace. */
.main-container, .main-content, .page-content, #main-container,
.ace-settings-container, .body, .container-fluid {
	background: transparent !important;
	color: var(--rc-text) !important;
}

/* Navbar superior Ace (.navbar / .navbar-default / .ace-nav). */
.navbar, .navbar-default, .navbar-inner, .ace-nav, .navbar .navbar-container {
	background: var(--rc-surface) !important;
	background-image: none !important;
	border-color: var(--rc-border) !important;
	box-shadow: none !important;
}
.navbar .nav > li > a, .ace-nav > li > a, .navbar-text {
	color: var(--rc-text) !important;
}
.navbar .nav > li > a:hover, .ace-nav > li > a:hover {
	background: var(--rc-surface2) !important;
}

/* Sidebar y menu lateral (.sidebar / .nav-list). */
.sidebar, .nav-list, .sidebar .nav-list {
	background: var(--rc-surface) !important;
	border-color: var(--rc-border) !important;
}
.nav-list > li > a, .nav-list li a {
	color: var(--rc-text) !important;
	border-color: var(--rc-border) !important;
}
.nav-list > li:hover > a, .nav-list > li.active > a,
.nav-list > li.open > a {
	background: var(--rc-surface2) !important;
	color: var(--rc-accent) !important;
}
.nav-list > li.active > a::before {
	background: var(--rc-accent) !important;
}

/* Widgets Ace (la caja blanca de cada panel/seccion). */
.widget-box, .widget-main, .widget-body, .widget-body .table {
	background: var(--rc-surface) !important;
	border-color: var(--rc-border) !important;
	color: var(--rc-text) !important;
	box-shadow: none !important;
}
.widget-header {
	background: var(--rc-surface2) !important;
	color: var(--rc-text) !important;
	border-color: var(--rc-border) !important;
}
.widget-header > .widget-title, .widget-header h1,
.widget-header h2, .widget-header h3, .widget-header h4, .widget-header h5 {
	color: var(--rc-text) !important;
}
.widget-toolbar { border-color: var(--rc-border) !important; }

/* Paneles / wells / cajas Bootstrap. */
.panel, .panel-default, .well, .thumbnail, .jumbotron, .popover {
	background: var(--rc-surface) !important;
	border-color: var(--rc-border) !important;
	color: var(--rc-text) !important;
	box-shadow: none !important;
}
.panel-heading, .panel-footer {
	background: var(--rc-surface2) !important;
	border-color: var(--rc-border) !important;
	color: var(--rc-text) !important;
}

/* Tablas Bootstrap (.table) — la lista de incidencias. */
.table, .table > thead > tr > th, .table > tbody > tr > td,
.table > tbody > tr > th, .table-bordered, .table-bordered > tbody > tr > td,
.table-bordered > thead > tr > th {
	background-color: transparent !important;
	border-color: var(--rc-border) !important;
	color: var(--rc-text) !important;
}
.table > thead > tr > th, .table thead th {
	background: var(--rc-surface2) !important;
}
.table-striped > tbody > tr:nth-child(odd) > td,
.table-striped > tbody > tr:nth-child(odd) > th {
	background: rgba(255,255,255,.02) !important;
}
.table-hover > tbody > tr:hover > td,
.table-hover > tbody > tr:hover > th {
	background: rgba(0,229,160,.06) !important;
}

/* Breadcrumbs. */
.breadcrumb, .breadcrumbs, .ace-nav .breadcrumb {
	background: var(--rc-surface2) !important;
	border-color: var(--rc-border) !important;
	color: var(--rc-muted) !important;
}
.breadcrumb > li > a, .breadcrumbs a { color: var(--rc-accent) !important; }

/* Dropdowns. */
.dropdown-menu {
	background: var(--rc-surface2) !important;
	border-color: var(--rc-border2) !important;
	box-shadow: 0 6px 20px rgba(0,0,0,.5) !important;
}
.dropdown-menu > li > a, .dropdown-menu li a { color: var(--rc-text) !important; }
.dropdown-menu > li > a:hover, .dropdown-menu > li > a:focus {
	background: var(--rc-accent) !important;
	color: #000 !important;
}

/* Pestanas (.nav-tabs). */
.nav-tabs { border-color: var(--rc-border) !important; }
.nav-tabs > li > a { color: var(--rc-muted) !important; border-color: transparent !important; }
.nav-tabs > li.active > a, .nav-tabs > li.active > a:hover,
.nav-tabs > li.active > a:focus {
	background: var(--rc-surface) !important;
	border-color: var(--rc-border) var(--rc-border) transparent !important;
	color: var(--rc-accent) !important;
}

/* Modales. */
.modal-content {
	background: var(--rc-surface) !important;
	border-color: var(--rc-border2) !important;
	color: var(--rc-text) !important;
}
.modal-header, .modal-footer { border-color: var(--rc-border) !important; }

/* Inputs Bootstrap (.form-control) ademas de los legacy de arriba. */
.form-control {
	background: var(--rc-surface2) !important;
	color: var(--rc-text) !important;
	border-color: var(--rc-border2) !important;
}
.form-control:focus {
	border-color: var(--rc-accent) !important;
	box-shadow: 0 0 0 3px rgba(0,229,160,.12) !important;
}

/* Alertas / mensajes. */
.alert {
	background: var(--rc-surface2) !important;
	border-color: var(--rc-border2) !important;
	color: var(--rc-text) !important;
}

/* Texto auxiliar Ace (gris claro sobre blanco -> ilegible en oscuro). */
.lighter, .grey, .text-muted, .muted, label, .control-label,
.bigger-110, .smaller-80, dt, dd, p, span, li, td, th, h1, h2, h3, h4, h5, h6 {
	color: var(--rc-text);
}
.text-muted, .muted, .grey, .lighter { color: var(--rc-muted) !important; }

/* Separadores. */
hr, .hr { border-color: var(--rc-border) !important; background: var(--rc-border) !important; }

/* Pie Ace del core (lo borra el JS, esto es respaldo visual). */
.footer, .footer-inner, .footer-content {
	background: var(--rc-surface) !important;
	color: var(--rc-muted) !important;
	border-color: var(--rc-border) !important;
}

/* ── Responsive movil ─────────────────────────────────────────────────────
   Mantis no adapta bien las tablas de bugs ni el menu en pantallas pequenas. */
@media (max-width: 768px) {
	/* Tablas anchas: scroll horizontal en vez de desbordar la pagina. */
	.table-container,
	.width100,
	table.width100 {
		display: block;
		max-width: 100%;
		overflow-x: auto;
		-webkit-overflow-scrolling: touch;
	}
	/* Formularios e inputs no deben salirse del viewport. */
	input, select, textarea { max-width: 100%; box-sizing: border-box; }
	.form-container, .widget-container { padding: 8px !important; }

	/* Menu desplegable al pulsar el hamburguesa (clase puesta por initMenuToggle).
	   Cubrimos los selectores de menu mas comunes del core. */
	#sidebar.rc-menu-open,
	.responsive-menu.rc-menu-open,
	#navbar.rc-menu-open,
	nav.menu.rc-menu-open,
	ul.menu.rc-menu-open,
	#nav-container.rc-menu-open {
		display: block !important;
		max-height: none !important;
		visibility: visible !important;
	}
	.rc-mantis-topbar img { height: 22px; }
}
</style>
CSS;
	}


	/**
	 * Barra superior con el logo. La URL del logo apunta al servidor
	 * principal de ResolveCore para no duplicar assets.
	 */
	function page_header( $p_event ) {
		$logo = 'https://resolvecore.website/wp-content/themes/resolvecore-theme/assets/logo/resolvcore-logo-light.svg';

		return '<div class="rc-mantis-topbar">'
		     . '<img src="' . htmlspecialchars( $logo ) . '" alt="ResolveCore">'
		     . '<span>Gestión de incidencias</span>'
		     . '</div>';
	}


	function page_footer( $p_event ) {
		return '<div class="rc-mantis-footer">'
		     . 'ResolveCore — Solución a tus problemas informáticos'
		     . '</div>';
	}
}
