<?php
if ( ! defined( 'ABSPATH' ) ) exit;

/**
 * RC_Mantis_API — Cliente REST para MantisBT 2.x.
 *
 * Endpoints utilizados:
 *   POST /api/rest/issues
 *   GET  /api/rest/issues/{id}
 *   POST /api/rest/issues/{id}/notes
 *   POST /api/rest/issues/{id}/files
 *   GET  /api/rest/projects
 *
 * Errores:
 *   - Devuelve WP_Error con código `mantis_api_error` y data['status']=HTTP code.
 *   - Loggea cuerpo completo a error_log() cuando HTTP no es 2xx (debug producción).
 */
class RC_Mantis_API {

    const PRIORITIES = [ 'none', 'low', 'normal', 'high', 'urgent', 'immediate' ];
    const SEVERITIES = [ 'feature', 'trivial', 'text', 'tweak', 'minor', 'major', 'crash', 'block' ];
    const MAX_DESCRIPTION = 65000;
    const MAX_SUMMARY     = 250;
    const MAX_FILE_BYTES  = 5242880; // 5 MB — default Mantis upload cap.

    private string $base_url;
    private string $token;

    public function __construct( string $base_url, string $token ) {
        $this->base_url = rtrim( $base_url, '/' );
        $this->token    = $token;
    }

    // ─── Issue lifecycle ─────────────────────────────────────────────────────

    /**
     * Crea un ticket. Valida y sanitiza payload antes de enviar.
     *
     * @param array $data {
     *   string $summary       Obligatorio. Trimmed a 250 caracteres.
     *   string $description   Obligatorio. Trimmed a 65000 caracteres, UTF-8 forzado.
     *   int    $project_id    Obligatorio.
     *   string $category      Default 'General'.
     *   string $priority      Default 'normal'. Whitelist PRIORITIES.
     *   string $severity      Default 'minor'. Whitelist SEVERITIES.
     *   array  $custom_fields  Opcional.
     * }
     * @return array|WP_Error
     */
    public function create_issue( array $data ): array|WP_Error {
        $summary    = $this->sanitize_summary( $data['summary'] ?? '' );
        $descripcion = $this->sanitize_description( $data['description'] ?? '' );

        if ( $summary === '' ) {
            return new WP_Error( 'mantis_invalid_payload', 'summary vacio' );
        }
        if ( $descripcion === '' ) {
            return new WP_Error( 'mantis_invalid_payload', 'description vacia' );
        }
        if ( empty( $data['project_id'] ) || (int) $data['project_id'] < 1 ) {
            return new WP_Error( 'mantis_invalid_payload', 'project_id invalido' );
        }

        $priority = $this->validate_enum( $data['priority'] ?? 'normal', self::PRIORITIES, 'normal' );
        $severity = $this->validate_enum( $data['severity'] ?? 'minor',  self::SEVERITIES, 'minor' );
        $category = $data['category'] ?? 'General';
        $category = is_string( $category ) && trim( $category ) !== '' ? trim( $category ) : 'General';

        $body = [
            'summary'     => $summary,
            'description' => $descripcion,
            'project'     => [ 'id' => (int) $data['project_id'] ],
            'category'    => [ 'name' => $category ],
            'priority'    => [ 'name' => $priority ],
            'severity'    => [ 'name' => $severity ],
        ];

        if ( ! empty( $data['custom_fields'] ) && is_array( $data['custom_fields'] ) ) {
            $body['custom_fields'] = $data['custom_fields'];
        }

        return $this->request( 'POST', '/api/rest/issues', $body );
    }

    public function get_issue( int $id ): array|WP_Error {
        if ( $id < 1 ) {
            return new WP_Error( 'mantis_invalid_payload', 'id invalido' );
        }
        return $this->request( 'GET', "/api/rest/issues/{$id}" );
    }

    public function get_projects(): array|WP_Error {
        return $this->request( 'GET', '/api/rest/projects' );
    }

    /**
     * Añade una nota (comentario) al ticket.
     *
     * @param int    $issue_id
     * @param string $text       Markdown/texto plano.
     * @param string $view_state 'public' (default) | 'private'.
     */
    public function add_note( int $issue_id, string $text, string $view_state = 'public' ): array|WP_Error {
        if ( $issue_id < 1 ) {
            return new WP_Error( 'mantis_invalid_payload', 'issue_id invalido' );
        }
        $text = $this->sanitize_description( $text );
        if ( $text === '' ) {
            return new WP_Error( 'mantis_invalid_payload', 'note text vacio' );
        }
        $view_state = ( $view_state === 'private' ) ? 'private' : 'public';

        return $this->request( 'POST', "/api/rest/issues/{$issue_id}/notes", [
            'text'       => $text,
            'view_state' => [ 'name' => $view_state ],
        ] );
    }

    /**
     * Adjunta un fichero al ticket.
     * Endpoint Mantis acepta multipart/form-data con campo "files[]".
     *
     * @param int    $issue_id
     * @param string $file_path  Ruta absoluta al fichero.
     * @param string $reporter_filename  Nombre visible (default: basename).
     */
    public function attach_file( int $issue_id, string $file_path, string $reporter_filename = '' ): array|WP_Error {
        if ( $issue_id < 1 ) {
            return new WP_Error( 'mantis_invalid_payload', 'issue_id invalido' );
        }
        if ( ! is_readable( $file_path ) ) {
            return new WP_Error( 'mantis_file_unreadable', "fichero ilegible: $file_path" );
        }
        $size = filesize( $file_path );
        if ( $size === false || $size <= 0 ) {
            return new WP_Error( 'mantis_file_empty', "fichero vacio: $file_path" );
        }
        if ( $size > self::MAX_FILE_BYTES ) {
            return new WP_Error( 'mantis_file_too_large',
                sprintf( 'fichero %d bytes > limite %d', $size, self::MAX_FILE_BYTES ) );
        }

        $filename = $reporter_filename !== '' ? $reporter_filename : basename( $file_path );

        $boundary = wp_generate_password( 24, false );
        $contents = file_get_contents( $file_path );
        if ( $contents === false ) {
            return new WP_Error( 'mantis_file_unreadable', "no se pudo leer: $file_path" );
        }

        // Construir multipart manualmente — wp_remote_request no soporta uploads directos.
        $eol  = "\r\n";
        $body = '--' . $boundary . $eol;
        $body .= 'Content-Disposition: form-data; name="files[]"; filename="' . $filename . '"' . $eol;
        $body .= 'Content-Type: ' . $this->guess_mime( $file_path ) . $eol . $eol;
        $body .= $contents . $eol;
        $body .= '--' . $boundary . '--' . $eol;

        $response = wp_remote_post( $this->base_url . "/api/rest/issues/{$issue_id}/files", [
            'timeout' => 30,
            'headers' => [
                'Authorization' => $this->token,
                'Content-Type'  => 'multipart/form-data; boundary=' . $boundary,
            ],
            'body' => $body,
        ] );

        return $this->parse_response( $response, "POST /api/rest/issues/{$issue_id}/files" );
    }

    // ─── Internals ───────────────────────────────────────────────────────────

    private function sanitize_summary( string $s ): string {
        $s = wp_check_invalid_utf8( trim( $s ) );
        if ( strlen( $s ) > self::MAX_SUMMARY ) {
            $s = mb_substr( $s, 0, self::MAX_SUMMARY );
        }
        return $s;
    }

    private function sanitize_description( string $s ): string {
        $s = wp_check_invalid_utf8( $s );
        $s = trim( $s );
        if ( strlen( $s ) > self::MAX_DESCRIPTION ) {
            $s = mb_substr( $s, 0, self::MAX_DESCRIPTION ) . "\n\n[truncado]";
        }
        return $s;
    }

    private function validate_enum( string $value, array $whitelist, string $default ): string {
        $value = strtolower( trim( $value ) );
        return in_array( $value, $whitelist, true ) ? $value : $default;
    }

    private function guess_mime( string $path ): string {
        $ext = strtolower( pathinfo( $path, PATHINFO_EXTENSION ) );
        return match ( $ext ) {
            'json' => 'application/json',
            'pdf'  => 'application/pdf',
            'html', 'htm' => 'text/html',
            'txt', 'log'  => 'text/plain',
            default       => 'application/octet-stream',
        };
    }

    private function request( string $method, string $endpoint, ?array $body = null ): array|WP_Error {
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
            $encoded = wp_json_encode( $body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES );
            if ( $encoded === false ) {
                return new WP_Error( 'mantis_json_encode_failed', 'wp_json_encode devolvio false' );
            }
            $args['body'] = $encoded;
        }

        $response = wp_remote_request( $this->base_url . $endpoint, $args );
        return $this->parse_response( $response, "{$method} {$endpoint}" );
    }

    private function parse_response( $response, string $context ): array|WP_Error {
        if ( is_wp_error( $response ) ) {
            error_log( "[rc-mantisbt] {$context} transport error: " . $response->get_error_message() );
            return $response;
        }

        $code     = wp_remote_retrieve_response_code( $response );
        $raw_body = wp_remote_retrieve_body( $response );
        $json     = json_decode( $raw_body, true );

        if ( $code < 200 || $code >= 300 ) {
            $message = is_array( $json ) && ! empty( $json['message'] )
                ? (string) $json['message']
                : "HTTP {$code}";
            error_log( "[rc-mantisbt] {$context} HTTP {$code}: " . substr( (string) $raw_body, 0, 1000 ) );
            return new WP_Error( 'mantis_api_error', $message, [
                'status'  => $code,
                'context' => $context,
                'body'    => is_array( $json ) ? $json : null,
            ] );
        }

        if ( ! is_array( $json ) ) {
            // 2xx con cuerpo no-JSON (raro, pero posible). Devolvemos vacío sin error.
            return [];
        }
        return $json;
    }
}
