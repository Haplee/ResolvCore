<?php
if ( ! defined( 'WP_UNINSTALL_PLUGIN' ) ) exit;

global $wpdb;
$table = $wpdb->prefix . 'rc_tech_alerts';
$wpdb->query( "DROP TABLE IF EXISTS {$table}" );

$role = get_role( 'administrator' );
if ( $role ) {
    $role->remove_cap( 'rc_tech' );
}

delete_transient( 'rc_tech_sla_count' );

wp_clear_scheduled_hook( 'rc_tech_sla_check' );
wp_clear_scheduled_hook( 'rc_tech_gc_alerts' );
