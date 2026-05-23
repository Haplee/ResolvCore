<?php
if ( ! defined( 'ABSPATH' ) ) exit;

/**
 * REST endpoints internos: /wp-json/rc-tech/v1/*
 *
 * Auth: cookie + nonce wp_rest + cap rc_tech.
 */
class RC_Tech_Rest {

    private const NS = 'rc-tech/v1';

    public function register_routes(): void {
        register_rest_route( self::NS, '/queue', [
            'methods'             => 'GET',
            'callback'            => [ $this, 'queue' ],
            'permission_callback' => [ $this, 'auth' ],
        ] );
        register_rest_route( self::NS, '/timeline/(?P<id>\d+)', [
            'methods'             => 'GET',
            'callback'            => [ $this, 'timeline' ],
            'permission_callback' => [ $this, 'auth' ],
            'args' => [ 'id' => [ 'validate_callback' => fn( $v ) => is_numeric( $v ) ] ],
        ] );
        register_rest_route( self::NS, '/alerts', [
            'methods'             => 'GET',
            'callback'            => [ $this, 'alerts' ],
            'permission_callback' => [ $this, 'auth' ],
        ] );
        register_rest_route( self::NS, '/export.csv', [
            'methods'             => 'GET',
            'callback'            => [ $this, 'export_csv' ],
            'permission_callback' => [ $this, 'auth' ],
        ] );
        register_rest_route( self::NS, '/action/(?P<name>[a-z_]+)', [
            'methods'             => 'POST',
            'callback'            => [ $this, 'action' ],
            'permission_callback' => [ $this, 'auth' ],
        ] );
    }

    public function auth( WP_REST_Request $r ): bool {
        return current_user_can( RC_TECH_CAP );
    }

    public function queue( WP_REST_Request $r ): WP_REST_Response {
        $f = [
            'user_id'         => get_current_user_id(),
            'os'              => sanitize_text_field( (string) $r->get_param( 'os' ) ),
            'category'        => sanitize_text_field( (string) $r->get_param( 'category' ) ),
            'only_mine'       => (bool) $r->get_param( 'only_mine' ),
            'only_unassigned' => (bool) $r->get_param( 'only_unassigned' ),
            'q'               => sanitize_text_field( (string) $r->get_param( 'q' ) ),
        ];
        return rest_ensure_response( RC_Tech_Queue::build( $f ) );
    }

    public function timeline( WP_REST_Request $r ): WP_REST_Response {
        $id    = (int) $r['id'];
        $email = sanitize_email( (string) $r->get_param( 'email' ) );
        return rest_ensure_response( [
            'issue_id' => $id,
            'events'   => RC_Tech_Timeline::build( $id, $email ),
        ] );
    }

    public function alerts( WP_REST_Request $r ): WP_REST_Response {
        global $wpdb;
        $table = $wpdb->prefix . 'rc_tech_alerts';
        $rows  = $wpdb->get_results(
            "SELECT issue_id, alert_type, fired_at, channel
             FROM {$table}
             ORDER BY fired_at DESC LIMIT 50", ARRAY_A
        );
        return rest_ensure_response( [ 'alerts' => $rows ?: [] ] );
    }

    public function action( WP_REST_Request $r ): WP_REST_Response|WP_Error {
        $name     = $r['name'];
        $issue_id = (int) $r->get_param( 'issue_id' );
        if ( $issue_id < 1 ) {
            return new WP_Error( 'rc_tech_bad_id', 'issue_id requerido', [ 'status' => 400 ] );
        }
        if ( ! self::rate_limit_ok( get_current_user_id() ) ) {
            return new WP_Error( 'rc_tech_rate_limit', 'rate-limit (1 acción/2s)', [ 'status' => 429 ] );
        }

        $api = rc_tech_api();
        if ( ! $api ) {
            return new WP_Error( 'rc_tech_no_api', 'rc-mantisbt no configurado', [ 'status' => 500 ] );
        }

        switch ( $name ) {
            case 'assign_me':
                $user = wp_get_current_user()->user_login;
                $res  = $api->set_handler( $issue_id, $user );
                if ( is_wp_error( $res ) ) return $res;
                RC_Tech_Queue::invalidate( get_current_user_id() );
                return rest_ensure_response( [ 'ok' => true, 'handler' => $user ] );

            case 'resolve':
                $summary = sanitize_textarea_field( (string) $r->get_param( 'summary' ) );
                if ( $summary !== '' ) {
                    $api->inner()->add_note( $issue_id, $summary, 'public' );
                }
                $res = $api->set_status( $issue_id, 'resolved' );
                if ( is_wp_error( $res ) ) return $res;
                RC_Tech_Queue::invalidate( get_current_user_id() );
                return rest_ensure_response( [ 'ok' => true, 'status' => 'resolved' ] );

            case 'diag_note':
                $note = sanitize_textarea_field( (string) $r->get_param( 'note' ) );
                if ( $note === '' ) $note = 'Inicio diagnóstico vía panel técnico';
                $res = $api->inner()->add_note( $issue_id, $note, 'private' );
                if ( is_wp_error( $res ) ) return $res;
                return rest_ensure_response( [ 'ok' => true ] );

            case 'pdf':
                $email = sanitize_email( (string) $r->get_param( 'email' ) );
                if ( ! $email ) {
                    return new WP_Error( 'rc_tech_bad_email', 'email requerido', [ 'status' => 400 ] );
                }
                $res = RC_Tech_Report::generate( $issue_id, $email );
                if ( is_wp_error( $res ) ) return $res;
                return rest_ensure_response( [ 'ok' => true, 'detail' => $res ] );

            default:
                return new WP_Error( 'rc_tech_unknown_action', "acción desconocida: {$name}", [ 'status' => 400 ] );
        }
    }

    public function export_csv( WP_REST_Request $r ) {
        $data = RC_Tech_Queue::build( [ 'user_id' => get_current_user_id() ] );
        $rows = $data['rows'] ?? [];

        nocache_headers();
        header( 'Content-Type: text/csv; charset=utf-8' );
        header( 'Content-Disposition: attachment; filename="rc-tech-queue-' . date( 'Ymd-His' ) . '.csv"' );
        $out = fopen( 'php://output', 'w' );
        fputs( $out, "\xEF\xBB\xBF" ); // BOM utf-8 para Excel
        fputcsv( $out, [ 'id','priority','status','os','summary','reporter_email','handler','due_date','seconds_left','anydesk','host_score' ] );
        foreach ( $rows as $row ) {
            fputcsv( $out, [
                $row['id'], $row['priority'], $row['status'], $row['os'],
                $row['summary'], $row['reporter_email'], $row['handler'],
                $row['due_date'], $row['seconds_left'] ?? '',
                $row['anydesk'], $row['host_score'] ?? '',
            ] );
        }
        fclose( $out );
        exit;
    }

    private static function rate_limit_ok( int $user_id ): bool {
        $key  = "rc_tech_rl_{$user_id}";
        $last = (int) get_transient( $key );
        if ( $last && ( time() - $last ) < 2 ) return false;
        set_transient( $key, time(), 5 );
        return true;
    }
}
