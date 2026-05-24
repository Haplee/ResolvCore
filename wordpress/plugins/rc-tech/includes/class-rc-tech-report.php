<?php
if ( ! defined( 'ABSPATH' ) ) exit;

/**
 * Wrapper de reports/generate-report.php — busca último JSON del host por email,
 * invoca el generador y deja que él autoadjunte el PDF en Mantis.
 */
class RC_Tech_Report {

    public static function generate( int $issue_id, string $client_email ): array|WP_Error {
        if ( ! function_exists( 'shell_exec' ) ) {
            return new WP_Error( 'rc_tech_no_shell', 'shell_exec deshabilitado en este servidor' );
        }
        $host = rc_tech_lookup_host( $client_email );
        if ( ! $host || empty( $host['last_json'] ) ) {
            return new WP_Error( 'rc_tech_no_diag',
                'Sin diagnóstico previo para ' . $client_email );
        }

        $upload  = wp_upload_dir();
        $tmpdir  = trailingslashit( $upload['basedir'] ) . 'rc-tech/tmp';
        wp_mkdir_p( $tmpdir );

        $json_path = $tmpdir . "/issue-{$issue_id}-" . wp_generate_password( 8, false ) . '.json';
        $written   = file_put_contents( $json_path, $host['last_json'] );
        if ( $written === false ) {
            return new WP_Error( 'rc_tech_write_fail', "no se pudo escribir {$json_path}" );
        }

        $script = realpath( ABSPATH . '../reports/generate-report.php' );
        if ( ! $script ) {
            $script = realpath( __DIR__ . '/../../../../../reports/generate-report.php' );
        }
        if ( ! $script || ! is_readable( $script ) ) {
            @unlink( $json_path );
            return new WP_Error( 'rc_tech_no_generator',
                'reports/generate-report.php no encontrado' );
        }

        $mantis_url   = rc_mantis_get_url();
        $mantis_token = rc_mantis_get_token();

        $cmd = sprintf(
            'php %s --json %s --ticket %d --mantis-url %s --mantis-token %s 2>&1',
            escapeshellarg( $script ),
            escapeshellarg( $json_path ),
            $issue_id,
            escapeshellarg( $mantis_url ),
            escapeshellarg( $mantis_token )
        );

        $output = shell_exec( $cmd );
        @unlink( $json_path );

        if ( $output === null ) {
            return new WP_Error( 'rc_tech_shell_fail', 'shell_exec devolvió null' );
        }

        return [
            'output'   => trim( (string) $output ),
            'issue_id' => $issue_id,
        ];
    }
}
