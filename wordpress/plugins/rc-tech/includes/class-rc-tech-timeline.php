<?php
if ( ! defined( 'ABSPATH' ) ) exit;

/**
 * Merge Mantis history+notes con últimos diagnósticos rc-fleet por email cliente.
 */
class RC_Tech_Timeline {

    public static function build( int $issue_id, string $client_email = '' ): array {
        $events = [];
        $api    = rc_tech_api();
        if ( ! $api ) return $events;

        $res = $api->get_issue_with_history( $issue_id );
        if ( is_wp_error( $res ) ) return $events;

        $issue = $res['issues'][0] ?? null;
        if ( ! $issue ) return $events;

        if ( ! $client_email ) {
            $client_email = $issue['reporter']['email'] ?? '';
        }

        // History (status changes, handler changes, custom field updates)
        foreach ( $issue['history'] ?? [] as $h ) {
            $ts = $h['created_at'] ?? '';
            $events[] = [
                'ts'     => $ts,
                'source' => 'mantis',
                'type'   => 'history',
                'text'   => self::format_history_entry( $h ),
                'actor'  => $h['user']['name'] ?? '',
            ];
        }

        // Notes
        foreach ( $issue['notes'] ?? [] as $n ) {
            $events[] = [
                'ts'     => $n['created_at'] ?? '',
                'source' => 'mantis',
                'type'   => 'note',
                'text'   => mb_substr( (string) ( $n['text'] ?? '' ), 0, 300 ),
                'actor'  => $n['reporter']['name'] ?? '',
            ];
        }

        // Fleet diagnostics (últimos 5)
        if ( $client_email ) {
            global $wpdb;
            $table = $wpdb->prefix . 'rc_fleet_hosts';
            $diags = $wpdb->get_results( $wpdb->prepare(
                "SELECT host_id, hostname, os, last_seen, last_score, last_json
                 FROM {$table}
                 WHERE client_email = %s
                 ORDER BY last_seen DESC
                 LIMIT 5",
                $client_email
            ), ARRAY_A );

            foreach ( $diags ?: [] as $d ) {
                $summary = '';
                if ( function_exists( 'rc_mantis_format_diagnostic_summary' ) && $d['last_json'] ) {
                    $json = json_decode( $d['last_json'], true );
                    if ( is_array( $json ) ) {
                        $summary = rc_mantis_format_diagnostic_summary( $json );
                    }
                }
                $events[] = [
                    'ts'     => $d['last_seen'],
                    'source' => 'fleet',
                    'type'   => 'diagnostic',
                    'text'   => "Diagnóstico {$d['os']} · score " . ( $d['last_score'] ?? '—' ),
                    'host'   => $d['hostname'],
                    'detail' => mb_substr( $summary, 0, 500 ),
                ];
            }
        }

        // Sort desc por timestamp
        usort( $events, fn( $a, $b ) => strcmp( $b['ts'], $a['ts'] ) );
        return $events;
    }

    private static function format_history_entry( array $h ): string {
        $field = $h['field']['name'] ?? '';
        $old   = $h['old_value'] ?? '';
        $new   = $h['new_value'] ?? '';
        if ( $field ) {
            return "{$field}: «{$old}» → «{$new}»";
        }
        return (string) ( $h['message'] ?? 'Cambio' );
    }
}
