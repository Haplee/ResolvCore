<?php
/**
 * Plugin Name:       ResolveCore — Tech Panel
 * Plugin URI:        https://github.com/Haplee/ResolveCore
 * Description:       Panel técnico unificado: cola priorizada de tickets Mantis con quick-actions (Asignarme, Diag, PDF, Resolver), alertas SLA proactivas y timeline ticket+host.
 * Version:           0.2.0
 * Requires at least: 6.0
 * Tested up to:      6.5
 * Requires PHP:      8.0
 * Author:            Francisco Vidal Mateo
 * Author URI:        https://github.com/Haplee
 * License:           GPL-3.0-or-later
 * License URI:       https://www.gnu.org/licenses/gpl-3.0.html
 * Text Domain:       rc-tech
 */

if ( ! defined( 'ABSPATH' ) ) exit;

define( 'RC_TECH_VERSION',          '0.2.0' );
define( 'RC_TECH_DIR',              plugin_dir_path( __FILE__ ) );
define( 'RC_TECH_URL',              plugin_dir_url( __FILE__ ) );
define( 'RC_TECH_QUEUE_CACHE_TTL',  30 );
define( 'RC_TECH_SLA_CACHE_TTL',    60 );
define( 'RC_TECH_POLL_INTERVAL_MS', 60000 );
define( 'RC_TECH_CAP',              'rc_tech' );

require_once RC_TECH_DIR . 'includes/helpers.php';
require_once RC_TECH_DIR . 'includes/class-rc-tech-api-ext.php';
require_once RC_TECH_DIR . 'includes/class-rc-tech-queue.php';
require_once RC_TECH_DIR . 'includes/class-rc-tech-sla.php';
require_once RC_TECH_DIR . 'includes/class-rc-tech-alerts.php';
require_once RC_TECH_DIR . 'includes/class-rc-tech-timeline.php';
require_once RC_TECH_DIR . 'includes/class-rc-tech-report.php';
require_once RC_TECH_DIR . 'rest/class-rc-tech-rest.php';

// ── Activation / deactivation ────────────────────────────────────────────────

register_activation_hook( __FILE__, 'rc_tech_activate' );
register_deactivation_hook( __FILE__, 'rc_tech_deactivate' );

function rc_tech_activate(): void {
    global $wpdb;
    $table   = $wpdb->prefix . 'rc_tech_alerts';
    $charset = $wpdb->get_charset_collate();

    $sql = "CREATE TABLE {$table} (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        issue_id INT UNSIGNED NOT NULL,
        alert_type VARCHAR(32) NOT NULL,
        fired_at DATETIME NOT NULL,
        channel VARCHAR(16) NOT NULL,
        payload_hash CHAR(40) NOT NULL,
        PRIMARY KEY (id),
        UNIQUE KEY uniq_alert (issue_id, alert_type, payload_hash),
        KEY idx_fired (fired_at)
    ) {$charset};";
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    dbDelta( $sql );

    // Cap a admin (DEVELOPER+ humano se asume tiene rol con manage_options).
    $role = get_role( 'administrator' );
    if ( $role && ! $role->has_cap( RC_TECH_CAP ) ) {
        $role->add_cap( RC_TECH_CAP );
    }

    if ( ! wp_next_scheduled( 'rc_tech_sla_check' ) ) {
        wp_schedule_event( time() + 60, 'rc_tech_5min', 'rc_tech_sla_check' );
    }
    if ( ! wp_next_scheduled( 'rc_tech_gc_alerts' ) ) {
        wp_schedule_event( time() + 3600, 'daily', 'rc_tech_gc_alerts' );
    }
}

function rc_tech_deactivate(): void {
    wp_clear_scheduled_hook( 'rc_tech_sla_check' );
    wp_clear_scheduled_hook( 'rc_tech_gc_alerts' );
}

// Cron custom interval
add_filter( 'cron_schedules', function ( $s ) {
    $s['rc_tech_5min'] = [ 'interval' => 300, 'display' => 'rc-tech 5min' ];
    return $s;
} );

// ── Admin menu ────────────────────────────────────────────────────────────────

add_action( 'admin_menu', 'rc_tech_admin_menu' );
function rc_tech_admin_menu(): void {
    $sla_count = (int) get_transient( 'rc_tech_sla_count' );
    $title     = 'Panel Técnico';
    if ( $sla_count > 0 ) {
        $title .= ' <span class="awaiting-mod">' . esc_html( $sla_count ) . '</span>';
    }
    add_menu_page(
        'Panel Técnico ResolveCore',
        $title,
        RC_TECH_CAP,
        'rc-tech',
        'rc_tech_render_admin_page',
        'dashicons-shield-alt',
        26
    );
}

add_action( 'admin_enqueue_scripts', function ( $hook ) {
    if ( $hook !== 'toplevel_page_rc-tech' ) return;
    wp_enqueue_style(
        'rc-tech-panel',
        RC_TECH_URL . 'assets/tech-panel.css',
        [],
        RC_TECH_VERSION
    );
    wp_enqueue_script(
        'rc-tech-panel',
        RC_TECH_URL . 'assets/tech-panel.js',
        [],
        RC_TECH_VERSION,
        true
    );
    wp_localize_script( 'rc-tech-panel', 'rcTech', [
        'restUrl'      => esc_url_raw( rest_url( 'rc-tech/v1/' ) ),
        'nonce'        => wp_create_nonce( 'wp_rest' ),
        'pollInterval' => RC_TECH_POLL_INTERVAL_MS,
        'currentUser'  => wp_get_current_user()->user_login,
        'i18n'         => [
            'assigned'    => __( 'Asignado a ti', 'rc-tech' ),
            'resolved'    => __( 'Resuelto', 'rc-tech' ),
            'error'       => __( 'Error', 'rc-tech' ),
            'copyScript'  => __( 'Script copiado al portapapeles', 'rc-tech' ),
            'pdfAttached' => __( 'PDF adjuntado al ticket', 'rc-tech' ),
        ],
    ] );
} );

function rc_tech_render_admin_page(): void {
    if ( ! current_user_can( RC_TECH_CAP ) ) {
        wp_die( esc_html__( 'Sin permiso', 'rc-tech' ) );
    }
    require RC_TECH_DIR . 'admin/page-tech.php';
}

// ── REST init ────────────────────────────────────────────────────────────────

add_action( 'rest_api_init', function () {
    ( new RC_Tech_Rest() )->register_routes();
} );

// ── Cron hooks ───────────────────────────────────────────────────────────────

add_action( 'rc_tech_sla_check', [ 'RC_Tech_Alerts', 'scan_and_fire' ] );
add_action( 'rc_tech_gc_alerts', [ 'RC_Tech_Alerts', 'gc' ] );
