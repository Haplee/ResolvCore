<?php
if ( ! defined( 'ABSPATH' ) ) exit;

class RC_Mantis_API {

    private string $base_url;
    private string $token;

    public function __construct( string $base_url, string $token ) {
        $this->base_url = rtrim( $base_url, '/' );
        $this->token    = $token;
    }

    /**
     * Create an issue in MantisBT.
     *
     * @param array $data {
     *   string $summary
     *   string $description
     *   int    $project_id
     *   string $category   Default 'General'
     *   string $priority   Default 'normal'
     *   array  $custom_fields  Optional: [['field'=>['id'=>X],'value'=>'Y']]
     * }
     * @return array|WP_Error  Issue data on success, WP_Error on failure.
     */
    public function create_issue( array $data ): array|WP_Error {
        $body = [
            'summary'     => $data['summary'],
            'description' => $data['description'],
            'project'     => [ 'id' => (int) $data['project_id'] ],
            'category'    => [ 'name' => $data['category'] ?? 'General' ],
            'priority'    => [ 'name' => $data['priority'] ?? 'normal' ],
        ];

        if ( ! empty( $data['custom_fields'] ) ) {
            $body['custom_fields'] = $data['custom_fields'];
        }

        return $this->request( 'POST', '/api/rest/issues', $body );
    }

    /**
     * Get a single issue by ID.
     *
     * @return array|WP_Error
     */
    public function get_issue( int $id ): array|WP_Error {
        return $this->request( 'GET', "/api/rest/issues/{$id}" );
    }

    /**
     * List available projects.
     *
     * @return array|WP_Error
     */
    public function get_projects(): array|WP_Error {
        return $this->request( 'GET', '/api/rest/projects' );
    }

    // ----------------------------------------------------------------

    private function request( string $method, string $endpoint, ?array $body = null ): array|WP_Error {
        $args = [
            'method'  => $method,
            'timeout' => 10,
            'headers' => [
                'Authorization' => 'Token ' . $this->token,
                'Content-Type'  => 'application/json',
            ],
        ];

        if ( $body !== null ) {
            $args['body'] = wp_json_encode( $body );
        }

        $response = wp_remote_request( $this->base_url . $endpoint, $args );

        if ( is_wp_error( $response ) ) {
            return $response;
        }

        $code = wp_remote_retrieve_response_code( $response );
        $json = json_decode( wp_remote_retrieve_body( $response ), true );

        if ( $code < 200 || $code >= 300 ) {
            $message = $json['message'] ?? "HTTP {$code}";
            return new WP_Error( 'mantis_api_error', $message, [ 'status' => $code ] );
        }

        return $json ?? [];
    }
}
