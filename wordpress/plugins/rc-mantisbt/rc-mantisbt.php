<?php
/**
 * Plugin Name: ResolveCore — MantisBT Integration
 * Plugin URI:  https://github.com/Haplee/ResolveCore
 * Description: Integra el formulario de contacto de ResolveCore con MantisBT vía REST API. Crea un ticket automáticamente con cada solicitud de soporte.
 * Version:     1.0.0
 * Author:      Francisco Vidal Mateo
 * Author URI:  https://github.com/Haplee
 * License:     GPL-2.0+
 * Text Domain: rc-mantisbt
 */

if ( ! defined( 'ABSPATH' ) ) exit;

define( 'RC_MANTIS_VERSION', '1.0.0' );
define( 'RC_MANTIS_DIR', plugin_dir_path( __FILE__ ) );

require_once RC_MANTIS_DIR . 'includes/class-mantis-api.php';

// ── Admin settings ────────────────────────────────────────────────────────────

add_action( 'admin_menu', 'rc_mantis_admin_menu' );
function rc_mantis_admin_menu(): void {
    add_options_page(
        'MantisBT · ResolveCore',
        'MantisBT',
        'manage_options',
        'rc-mantisbt',
        'rc_mantis_settings_page'
    );
}

add_action( 'admin_init', 'rc_mantis_register_settings' );
function rc_mantis_register_settings(): void {
    register_setting( 'rc_mantis_group', 'rc_mantis_url',        [ 'sanitize_callback' => 'esc_url_raw' ] );
    register_setting( 'rc_mantis_group', 'rc_mantis_token',      [ 'sanitize_callback' => 'sanitize_text_field' ] );
    register_setting( 'rc_mantis_group', 'rc_mantis_project_id', [ 'sanitize_callback' => 'absint' ] );
    register_setting( 'rc_mantis_group', 'rc_mantis_enabled',    [ 'sanitize_callback' => 'absint' ] );
}

function rc_mantis_settings_page(): void {
    if ( ! current_user_can( 'manage_options' ) ) return;

    $url        = get_option( 'rc_mantis_url', '' );
    $token      = get_option( 'rc_mantis_token', '' );
    $project_id = get_option( 'rc_mantis_project_id', 1 );
    $enabled    = get_option( 'rc_mantis_enabled', 0 );
    ?>
    <div class="wrap">
        <h1>MantisBT · ResolveCore</h1>
        <form method="post" action="options.php">
            <?php settings_fields( 'rc_mantis_group' ); ?>
            <table class="form-table">
                <tr>
                    <th><label for="rc_mantis_enabled">Activar integración</label></th>
                    <td>
                        <input type="checkbox" id="rc_mantis_enabled" name="rc_mantis_enabled" value="1" <?php checked( $enabled, 1 ); ?>>
                        <p class="description">Si está activo, cada mensaje del formulario de contacto crea un ticket en MantisBT.</p>
                    </td>
                </tr>
                <tr>
                    <th><label for="rc_mantis_url">URL de MantisBT</label></th>
                    <td>
                        <input type="url" id="rc_mantis_url" name="rc_mantis_url" value="<?php echo esc_attr( $url ); ?>" class="regular-text" placeholder="https://tudominio.com/mantis">
                    </td>
                </tr>
                <tr>
                    <th><label for="rc_mantis_token">API Token</label></th>
                    <td>
                        <input type="password" id="rc_mantis_token" name="rc_mantis_token" value="<?php echo esc_attr( $token ); ?>" class="regular-text" placeholder="Token generado en MantisBT → Mi cuenta → API Tokens">
                        <p class="description">MantisBT: <strong>Mi cuenta → API Tokens → Crear token</strong></p>
                    </td>
                </tr>
                <tr>
                    <th><label for="rc_mantis_project_id">ID del Proyecto</label></th>
                    <td>
                        <input type="number" id="rc_mantis_project_id" name="rc_mantis_project_id" value="<?php echo esc_attr( $project_id ); ?>" class="small-text" min="1">
                        <p class="description">ID numérico del proyecto en MantisBT (ver URL al editar el proyecto).</p>
                    </td>
                </tr>
            </table>

            <?php submit_button( 'Guardar cambios' ); ?>

            <?php if ( $url && $token ): ?>
            <hr>
            <h2>Probar conexión</h2>
            <p>
                <a href="<?php echo esc_url( add_query_arg( [ 'page' => 'rc-mantisbt', 'rc_mantis_test' => '1' ], admin_url( 'options-general.php' ) ) ); ?>" class="button">
                    Verificar conexión con MantisBT
                </a>
            </p>
            <?php
                if ( isset( $_GET['rc_mantis_test'] ) && current_user_can( 'manage_options' ) ) {
                    $api    = rc_mantis_get_api();
                    $result = $api ? $api->get_projects() : null;
                    if ( is_wp_error( $result ) ) {
                        echo '<div class="notice notice-error"><p><strong>Error:</strong> ' . esc_html( $result->get_error_message() ) . '</p></div>';
                    } elseif ( $result !== null ) {
                        $count = count( $result['projects'] ?? [] );
                        echo '<div class="notice notice-success"><p>Conexión OK. Proyectos disponibles: <strong>' . esc_html( $count ) . '</strong></p></div>';
                    }
                }
            ?>
            <?php endif; ?>
        </form>
    </div>
    <?php
}

// ── Public API helper ──────────────────────────────────────────────────────────

function rc_mantis_get_api(): ?RC_Mantis_API {
    $url   = get_option( 'rc_mantis_url', '' );
    $token = get_option( 'rc_mantis_token', '' );
    if ( ! $url || ! $token ) return null;
    return new RC_Mantis_API( $url, $token );
}

/**
 * Create a MantisBT ticket from a contact form submission.
 *
 * @param array $data {
 *   string $name
 *   string $email
 *   string $type    soporte|bug|colaboracion|licencia|otro
 *   string $message
 * }
 * @return int|WP_Error  Ticket ID on success.
 */
function rc_mantis_create_ticket( array $data ): int|WP_Error {
    if ( ! get_option( 'rc_mantis_enabled', 0 ) ) {
        return new WP_Error( 'rc_mantis_disabled', 'MantisBT integration is disabled.' );
    }

    $api = rc_mantis_get_api();
    if ( ! $api ) {
        return new WP_Error( 'rc_mantis_no_config', 'MantisBT not configured.' );
    }

    $priority_map = [
        'soporte'      => 'high',
        'bug'          => 'normal',
        'colaboracion' => 'low',
        'licencia'     => 'normal',
        'otro'         => 'low',
    ];

    $category_map = [
        'soporte'      => 'Soporte técnico',
        'bug'          => 'Bug',
        'colaboracion' => 'Colaboración',
        'licencia'     => 'Licencia',
        'otro'         => 'General',
    ];

    $type     = sanitize_text_field( $data['type'] ?? 'otro' );
    $priority = $priority_map[ $type ] ?? 'normal';
    $category = $category_map[ $type ] ?? 'General';

    $summary = sprintf(
        '[ResolveCore] %s — %s',
        ucfirst( $type ),
        sanitize_text_field( $data['name'] )
    );

    $description = sprintf(
        "**Remitente:** %s  \n**Email:** %s  \n**Tipo:** %s  \n\n---\n\n%s",
        sanitize_text_field( $data['name'] ),
        sanitize_email( $data['email'] ),
        $type,
        sanitize_textarea_field( $data['message'] )
    );

    $result = $api->create_issue( [
        'summary'    => $summary,
        'description'=> $description,
        'project_id' => (int) get_option( 'rc_mantis_project_id', 1 ),
        'category'   => $category,
        'priority'   => $priority,
    ] );

    if ( is_wp_error( $result ) ) {
        error_log( '[rc-mantisbt] create_issue failed: ' . $result->get_error_message() );
        return $result;
    }

    return (int) ( $result['issue']['id'] ?? 0 );
}

/**
 * Sube un JSON de diagnóstico a un ticket existente y crea una nota con el resumen.
 *
 * Valida que el JSON cumpla el esquema mínimo (`_meta.plataforma` + `_meta.version`),
 * lo adjunta como fichero y añade una nota con los datos clave para que el técnico
 * los vea sin descargar el adjunto.
 *
 * @param int    $issue_id     ID del ticket en MantisBT.
 * @param string $json_path    Ruta absoluta al JSON generado por scripts/<os>/diagnostico.*.
 * @param bool   $add_summary  Si true (default), añade nota con resumen.
 * @return true|WP_Error
 */
function rc_mantis_attach_diagnostic( int $issue_id, string $json_path, bool $add_summary = true ): true|WP_Error {
    if ( $issue_id < 1 ) {
        return new WP_Error( 'rc_mantis_invalid_issue', 'issue_id invalido' );
    }
    if ( ! is_readable( $json_path ) ) {
        return new WP_Error( 'rc_mantis_file_unreadable', "JSON ilegible: $json_path" );
    }

    $raw = file_get_contents( $json_path );
    if ( $raw === false || $raw === '' ) {
        return new WP_Error( 'rc_mantis_file_empty', 'JSON vacio o ilegible' );
    }

    $data = json_decode( $raw, true );
    if ( ! is_array( $data ) ) {
        return new WP_Error( 'rc_mantis_json_invalid',
            'JSON malformado: ' . json_last_error_msg() );
    }

    if ( empty( $data['_meta']['plataforma'] ) || empty( $data['_meta']['version'] ) ) {
        return new WP_Error( 'rc_mantis_schema_invalid',
            'JSON sin _meta.plataforma o _meta.version (esquema incompatible)' );
    }

    $api = rc_mantis_get_api();
    if ( ! $api ) {
        return new WP_Error( 'rc_mantis_no_config', 'MantisBT no configurado.' );
    }

    // 1. Adjuntar fichero
    $upload = $api->attach_file( $issue_id, $json_path );
    if ( is_wp_error( $upload ) ) {
        error_log( '[rc-mantisbt] attach_file failed: ' . $upload->get_error_message() );
        return $upload;
    }

    // 2. Nota con resumen — extrae datos clave por plataforma
    if ( $add_summary ) {
        $resumen = rc_mantis_format_diagnostic_summary( $data );
        $note    = $api->add_note( $issue_id, $resumen, 'private' );
        if ( is_wp_error( $note ) ) {
            // No abortar — el adjunto ya está. Solo loguear.
            error_log( '[rc-mantisbt] add_note failed: ' . $note->get_error_message() );
        }
    }

    return true;
}

/**
 * Genera resumen Markdown del JSON de diagnóstico para incluir en una nota.
 * Tolerante a campos faltantes (cada plataforma expone lo suyo).
 */
function rc_mantis_format_diagnostic_summary( array $d ): string {
    $meta       = $d['_meta'] ?? [];
    $plataforma = $meta['plataforma'] ?? 'desconocida';
    $hostname   = $meta['hostname']   ?? '—';
    $generado   = $meta['generado_en'] ?? '—';

    $lines   = [];
    $lines[] = "**Diagnóstico ResolveCore** ({$plataforma})";
    $lines[] = "- Host: `" . sanitize_text_field( (string) $hostname ) . "`";
    $lines[] = "- Generado: {$generado}";
    $lines[] = "- Versión script: " . ( $meta['version'] ?? '—' );
    $lines[] = "";

    // Sistema operativo
    $os = $d['sistema'] ?? $d['sistema_operativo'] ?? null;
    if ( is_array( $os ) ) {
        $nombre = $os['nombre'] ?? '—';
        $build  = $os['build']  ?? '';
        $uptime = $os['uptime_horas'] ?? null;
        $lines[] = "**SO:** {$nombre} {$build}" . ( $uptime !== null ? " — uptime {$uptime}h" : '' );
    }

    // Hardware (linux/android lo agrupan; Windows lo expone en raíz)
    $hw = $d['hardware'] ?? null;
    if ( is_array( $hw ) ) {
        $cores = $hw['cpu_cores'] ?? '—';
        $ram   = $hw['ram_gb']    ?? '—';
        $disk  = $hw['disk_gb']   ?? '—';
        $lines[] = "**Hardware:** {$cores} cores · {$ram}GB RAM · disco {$disk}GB";
    } else {
        // Windows
        if ( ! empty( $d['cpu']['nucleos_total'] ) ) {
            $lines[] = "**CPU:** {$d['cpu']['nucleos_total']} cores / "
                . ( $d['cpu']['hilos_total'] ?? '—' ) . ' hilos';
        }
        if ( ! empty( $d['memoria']['total_gb'] ) ) {
            $lines[] = "**RAM:** {$d['memoria']['total_gb']}GB total · "
                . ( $d['memoria']['disponible_gb'] ?? '—' ) . 'GB disponibles';
        }
    }

    // Red
    if ( ! empty( $d['red']['latencia_ms'] ) ) {
        $lines[] = "**Red:** latencia {$d['red']['latencia_ms']}ms · pérdida "
            . ( $d['red']['perdida_paquetes_pct'] ?? '—' ) . '%';
    }

    // Seguridad
    if ( is_array( $d['seguridad'] ?? null ) ) {
        $sec = $d['seguridad'];
        $av  = $sec['antivirus'] ?? ( $sec['windows_defender']['activo'] ?? null ? 'Defender' : null );
        $fw  = ! empty( $sec['firewall'] ) ? 'activo' : 'inactivo';
        $lines[] = "**Seguridad:** firewall {$fw}" . ( $av ? " · AV: {$av}" : '' );
    }

    return implode( "\n", $lines );
}
