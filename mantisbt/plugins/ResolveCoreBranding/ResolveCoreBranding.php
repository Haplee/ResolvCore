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
 * Autor:   Francisco Vidal Mateo (FranVi)
 * Versión: 1.0
 */

class ResolveCoreBranding extends MantisPlugin {

	function register() {
		$this->name        = 'ResolveCore Branding';
		$this->description = 'Logo, título y CSS corporativo de ResolveCore.';
		$this->version     = '1.0';
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
		return $this->css_block();
	}

	private function css_block() {
		$accent  = '#00e5a0';
		$bg      = '#0a0c10';
		$surface = '#111318';
		$text    = '#e8eaf0';
		$muted   = '#7a7f8e';
		$border  = '#1e2229';

		return <<<CSS
<style>
body {
	background: {$bg} !important;
	color: {$text} !important;
}
#header, .header, #navigation, .nav {
	background: {$surface} !important;
	border-bottom: 1px solid {$border};
}
a, .bar-link {
	color: {$accent} !important;
}
a:hover {
	color: #00ffb3 !important;
}
.form-container, .widget-container, .table-container {
	background: {$surface} !important;
	border-color: {$border} !important;
}
input, select, textarea {
	background: #16191f !important;
	color: {$text} !important;
	border-color: #2a2f3a !important;
}
input[type=submit], input[type=button], .btn {
	background: {$accent} !important;
	color: #000 !important;
	border: none !important;
	font-weight: 700;
}
.rc-mantis-topbar {
	display: flex;
	align-items: center;
	justify-content: center;
	padding: 10px;
	background: {$surface};
	border-bottom: 1px solid {$border};
}
.rc-mantis-topbar img {
	height: 28px;
	vertical-align: middle;
}
.rc-mantis-topbar span {
	color: {$muted};
	font-size: 12px;
	margin-left: 10px;
}
.rc-mantis-footer {
	text-align: center;
	padding: 14px 12px;
	color: {$muted};
	font-size: 11px;
	border-top: 1px solid {$border};
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
