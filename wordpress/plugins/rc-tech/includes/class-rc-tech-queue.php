<?php
if ( ! defined( 'ABSPATH' ) ) exit;

/**
 * Construye cola priorizada con caché transient 30s.
 *
 * Prioridad efectiva:
 *   1. SLA vencido (< 0)
 *   2. SLA dentro de 30min
 *   3. Prioridad Mantis (immediate > urgent > high > normal > low > none)
 *   4. Antigüedad (más viejo primero)
 */
class RC_Tech_Queue {

    private const PRIO_WEIGHT = [
        'immediate' => 50, 'urgent' => 40, 'high' => 30,
        'normal' => 20, 'low' => 10, 'none' => 0,
    ];

    /**
     * @param array{user_id:int,os?:string,category?:string,only_mine?:bool,only_unassigned?:bool,q?:string} $f
     */
    public static function build( array $f ): array {
        $hash = md5( wp_json_encode( $f ) );
        $key  = "rc_tech_queue_{$f['user_id']}_{$hash}";

        $cached = get_transient( $key );
        if ( is_array( $cached ) ) return $cached;

        $api = rc_tech_api();
        if ( ! $api ) {
            return [ 'error' => 'rc-mantisbt no configurado', 'rows' => [], 'kpis' => self::empty_kpis() ];
        }

        $issues = $api->list_issues( [
            'project_id' => rc_tech_project_id(),
            'page_size'  => 50,
            'status_in'  => [ 10, 20, 30, 40, 50 ], // new, feedback, acknowledged, confirmed, assigned
        ] );
        if ( is_wp_error( $issues ) ) {
            return [ 'error' => $issues->get_error_message(), 'rows' => [], 'kpis' => self::empty_kpis() ];
        }

        $current_user = wp_get_current_user()->user_login;
        $rows         = [];
        foreach ( $issues as $issue ) {
            $row = self::normalize_row( $issue );

            // Filtros locales
            if ( ! empty( $f['os'] ) && $row['os'] !== $f['os'] ) continue;
            if ( ! empty( $f['category'] ) && stripos( $row['category'], $f['category'] ) === false ) continue;
            if ( ! empty( $f['only_mine'] ) && $row['handler'] !== $current_user ) continue;
            if ( ! empty( $f['only_unassigned'] ) && $row['handler'] !== '' ) continue;
            if ( ! empty( $f['q'] ) && stripos( $row['summary'], $f['q'] ) === false ) continue;

            $rows[] = $row;
        }

        usort( $rows, [ self::class, 'sort_priority' ] );

        $kpis = self::compute_kpis( $issues, $current_user );

        $out = [ 'rows' => $rows, 'kpis' => $kpis, 'generated_at' => current_time( 'mysql' ) ];
        set_transient( $key, $out, RC_TECH_QUEUE_CACHE_TTL );
        return $out;
    }

    public static function invalidate( int $user_id ): void {
        // Borrar todas las variantes de filtros para este user — wp transients no soportan wildcards.
        // Estrategia: incrementar versión global.
        delete_transient( "rc_tech_queue_v_{$user_id}" );
    }

    private static function normalize_row( array $issue ): array {
        $handler   = $issue['handler']['name'] ?? '';
        $secs_left = rc_tech_seconds_left( $issue['due_date'] ?? null );
        $plataforma = rc_tech_custom_field( $issue, 'Plataforma' );
        $anydesk    = rc_tech_custom_field( $issue, 'AnyDesk ID' );

        $os = strtolower( $plataforma );
        if ( str_contains( $os, 'win' ) )     $os = 'windows';
        elseif ( str_contains( $os, 'linux' ) ) $os = 'linux';
        elseif ( str_contains( $os, 'mac' ) )   $os = 'macos';
        elseif ( str_contains( $os, 'android' ) ) $os = 'android';

        $email = $issue['reporter']['email'] ?? '';
        $host  = $email ? rc_tech_lookup_host( $email ) : null;

        return [
            'id'           => (int) ( $issue['id'] ?? 0 ),
            'summary'      => (string) ( $issue['summary'] ?? '' ),
            'category'     => (string) ( $issue['category']['name'] ?? '' ),
            'priority'     => (string) ( $issue['priority']['name'] ?? 'normal' ),
            'status'       => (string) ( $issue['status']['name'] ?? '' ),
            'status_id'    => (int) ( $issue['status']['id'] ?? 0 ),
            'reporter'     => (string) ( $issue['reporter']['name'] ?? '' ),
            'reporter_email' => $email,
            'handler'      => $handler,
            'created_at'   => (string) ( $issue['created_at'] ?? '' ),
            'due_date'     => (string) ( $issue['due_date'] ?? '' ),
            'seconds_left' => $secs_left,
            'os'           => $os,
            'anydesk'      => $anydesk,
            'host_score'   => $host['last_score'] ?? null,
            'host_id'      => $host['host_id'] ?? '',
        ];
    }

    private static function sort_priority( array $a, array $b ): int {
        // SLA vencido prioridad máxima
        $a_overdue = ( $a['seconds_left'] !== null && $a['seconds_left'] <= 0 ) ? 1 : 0;
        $b_overdue = ( $b['seconds_left'] !== null && $b['seconds_left'] <= 0 ) ? 1 : 0;
        if ( $a_overdue !== $b_overdue ) return $b_overdue - $a_overdue;

        // SLA <30min
        $a_warn = ( $a['seconds_left'] !== null && $a['seconds_left'] > 0 && $a['seconds_left'] < 1800 ) ? 1 : 0;
        $b_warn = ( $b['seconds_left'] !== null && $b['seconds_left'] > 0 && $b['seconds_left'] < 1800 ) ? 1 : 0;
        if ( $a_warn !== $b_warn ) return $b_warn - $a_warn;

        // Prioridad Mantis
        $a_p = self::PRIO_WEIGHT[ $a['priority'] ] ?? 20;
        $b_p = self::PRIO_WEIGHT[ $b['priority'] ] ?? 20;
        if ( $a_p !== $b_p ) return $b_p - $a_p;

        // Antigüedad: más viejo primero
        return strcmp( $a['created_at'], $b['created_at'] );
    }

    private static function compute_kpis( array $issues, string $current_user ): array {
        $open       = count( $issues );
        $mine       = 0;
        $overdue    = 0;
        foreach ( $issues as $issue ) {
            if ( ( $issue['handler']['name'] ?? '' ) === $current_user ) $mine++;
            $secs = rc_tech_seconds_left( $issue['due_date'] ?? null );
            if ( $secs !== null && $secs <= 0 ) $overdue++;
        }

        $fleet_score = null;
        if ( function_exists( 'rc_fleet_get_public_stats' ) ) {
            $s = rc_fleet_get_public_stats();
            $fleet_score = $s['avg_score'] ?? null;
        }

        return [
            'open'        => $open,
            'mine'        => $mine,
            'overdue'     => $overdue,
            'fleet_score' => $fleet_score,
        ];
    }

    private static function empty_kpis(): array {
        return [ 'open' => 0, 'mine' => 0, 'overdue' => 0, 'fleet_score' => null ];
    }
}
