<?php
if ( ! defined( 'ABSPATH' ) ) exit;

/**
 * Wrapper sobre RC_Mantis_API añadiendo list_issues / update_issue / get_issue_with_history.
 * Composición — no modifica el cliente original.
 */
class RC_Tech_Api_Ext {

    private RC_Mantis_API $api;
    private string $base_url;
    private string $token;

    public function __construct( RC_Mantis_API $api, string $base_url, string $token ) {
        $this->api      = $api;
        $this->base_url = rtrim( $base_url, '/' );
        $this->token    = $token;
    }

    public function inner(): RC_Mantis_API {
        return $this->api;
    }

    /**
     * Lista issues con filtros.
     *
     * @param array{project_id?:int,page_size?:int,filter_id?:int,handler_id?:int,status_in?:array} $f
     */
    public function list_issues( array $f ): array|WP_Error {
        $params = [
            'project_id' => $f['project_id'] ?? rc_tech_project_id(),
            'page_size'  => $f['page_size']  ?? 50,
        ];
        if ( ! empty( $f['filter_id'] ) )  $params['filter_id']  = (int) $f['filter_id'];
        if ( ! empty( $f['handler_id'] ) ) $params['handler_id'] = (int) $f['handler_id'];

        $endpoint = '/api/rest/issues?' . http_build_query( $params );
        $res = $this->raw_request( 'GET', $endpoint );
        if ( is_wp_error( $res ) ) return $res;

        $issues = $res['issues'] ?? [];

        // Filtro local status_in (Mantis REST no soporta filtro multi-status directo sin filter_id).
        if ( ! empty( $f['status_in'] ) && is_array( $f['status_in'] ) ) {
            $allowed = array_map( 'intval', $f['status_in'] );
            $issues  = array_filter( $issues, function ( $i ) use ( $allowed ) {
                return in_array( (int) ( $i['status']['id'] ?? 0 ), $allowed, true );
            } );
            $issues = array_values( $issues );
        }
        return $issues;
    }

    public function get_issue_with_history( int $id ): array|WP_Error {
        return $this->raw_request( 'GET', "/api/rest/issues/{$id}?include=history,notes" );
    }

    public function set_handler( int $id, string $username ): array|WP_Error {
        return $this->patch_issue( $id, [ 'handler' => [ 'name' => $username ] ] );
    }

    public function set_status( int $id, string $status_name ): array|WP_Error {
        return $this->patch_issue( $id, [ 'status' => [ 'name' => $status_name ] ] );
    }

    public function patch_issue( int $id, array $patch ): array|WP_Error {
        return $this->raw_request( 'PATCH', "/api/rest/issues/{$id}", $patch );
    }

    /**
     * Backoff exponencial 3 reintentos (1s, 2s, 4s) para 429/5xx.
     */
    private function raw_request( string $method, string $endpoint, ?array $body = null ): array|WP_Error {
        $url     = $this->base_url . $endpoint;
        $delays  = [ 0, 1, 2, 4 ];
        $last    = null;

        foreach ( $delays as $i => $delay ) {
            if ( $delay > 0 ) sleep( $delay );

            $args = [
                'method'  => $method,
                'timeout' => 15,
                'headers' => [
                    'Authorization' => $this->token,
                    'Content-Type'  => 'application/json; charset=utf-8',
                    'Accept'        => 'application/json',
                ],
            ];
            if ( $body !== null ) {
                $args['body'] = wp_json_encode( $body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES );
            }
            $resp = wp_remote_request( $url, $args );

            // 405 PATCH → fallback POST + override
            if ( ! is_wp_error( $resp )
                 && (int) wp_remote_retrieve_response_code( $resp ) === 405
                 && $method === 'PATCH' ) {
                $args['method']                            = 'POST';
                $args['headers']['X-HTTP-Method-Override'] = 'PATCH';
                $resp = wp_remote_request( $url, $args );
            }

            if ( is_wp_error( $resp ) ) {
                $last = $resp;
                continue;
            }
            $code = (int) wp_remote_retrieve_response_code( $resp );
            $raw  = wp_remote_retrieve_body( $resp );
            $json = json_decode( $raw, true );

            if ( $code >= 200 && $code < 300 ) {
                return is_array( $json ) ? $json : [];
            }
            // 429 o 5xx → reintentar
            if ( $code === 429 || $code >= 500 ) {
                $last = new WP_Error( 'rc_tech_api_retry',
                    "HTTP {$code} en {$method} {$endpoint}",
                    [ 'status' => $code, 'attempt' => $i + 1 ] );
                continue;
            }
            // 4xx no reintentable
            $msg = is_array( $json ) && ! empty( $json['message'] ) ? (string) $json['message'] : "HTTP {$code}";
            error_log( "[rc-tech] {$method} {$endpoint} HTTP {$code}: " . substr( $raw, 0, 500 ) );
            return new WP_Error( 'rc_tech_api_error', $msg, [
                'status'  => $code,
                'context' => "{$method} {$endpoint}",
                'body'    => is_array( $json ) ? $json : null,
            ] );
        }
        return $last ?: new WP_Error( 'rc_tech_api_error', 'agotados reintentos' );
    }
}
