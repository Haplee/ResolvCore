<?php
if ( ! defined( 'ABSPATH' ) ) exit;

/**
 * Devuelve instancia de RC_Tech_Api_Ext o null si rc-mantisbt no está configurado.
 */
function rc_tech_api(): ?RC_Tech_Api_Ext {
    if ( ! function_exists( 'rc_mantis_get_api' ) ) return null;
    $api = rc_mantis_get_api();
    if ( ! $api ) return null;
    return new RC_Tech_Api_Ext( $api, rc_mantis_get_url(), rc_mantis_get_token() );
}

/**
 * Project ID configurado en rc-mantisbt.
 */
function rc_tech_project_id(): int {
    return (int) get_option( 'rc_mantis_project_id', 1 );
}

/**
 * Score color (verde / amarillo / rojo) por puntuación 0-100.
 */
function rc_tech_score_color( ?int $score ): string {
    if ( $score === null ) return 'gray';
    if ( $score >= 80 ) return 'green';
    if ( $score >= 50 ) return 'yellow';
    return 'red';
}

/**
 * Segundos restantes hasta due_date. Negativo = vencido. Null si due_date vacío.
 */
function rc_tech_seconds_left( ?string $due_date_iso ): ?int {
    if ( ! $due_date_iso ) return null;
    $ts = strtotime( $due_date_iso );
    if ( $ts === false ) return null;
    return $ts - time();
}

/**
 * Formatea seconds_left en string legible (humano).
 */
function rc_tech_format_countdown( ?int $secs ): string {
    if ( $secs === null ) return '—';
    if ( $secs <= 0 ) {
        $abs = abs( $secs );
        return '⚠ Vencido hace ' . rc_tech_human_duration( $abs );
    }
    return 'En ' . rc_tech_human_duration( $secs );
}

function rc_tech_human_duration( int $secs ): string {
    if ( $secs < 60 )    return "{$secs}s";
    if ( $secs < 3600 )  return floor( $secs / 60 ) . 'm';
    if ( $secs < 86400 ) return floor( $secs / 3600 ) . 'h';
    return floor( $secs / 86400 ) . 'd';
}

/**
 * Lookup host fleet por email cliente.
 */
function rc_tech_lookup_host( string $email ): ?array {
    global $wpdb;
    $table = $wpdb->prefix . 'rc_fleet_hosts';
    $row   = $wpdb->get_row( $wpdb->prepare(
        "SELECT host_id, hostname, os, last_seen, last_score, last_json
         FROM {$table}
         WHERE client_email = %s
         ORDER BY last_seen DESC
         LIMIT 1",
        $email
    ), ARRAY_A );
    return $row ?: null;
}

/**
 * Custom field value from Mantis issue (helper para custom_fields[]).
 */
function rc_tech_custom_field( array $issue, string $name ): string {
    foreach ( $issue['custom_fields'] ?? [] as $cf ) {
        if ( ( $cf['field']['name'] ?? '' ) === $name ) {
            return (string) ( $cf['value'] ?? '' );
        }
    }
    return '';
}

/**
 * Hash sha1 idempotente para alertas.
 */
function rc_tech_payload_hash( int $issue_id, string $alert_type, ?string $due_date ): string {
    return sha1( $issue_id . '|' . $alert_type . '|' . ( $due_date ?? '' ) );
}
