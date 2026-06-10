<?php
if ( ! defined( 'ABSPATH' ) ) exit;

/**
 * Generador del informe técnico (Fase 6).
 *
 * ⚠️ LEGACY / INACTIVO (2026-06-02). Esta clase NO forma parte del flujo actual.
 * El informe que recibe el cliente es la plantilla `.txt` que el técnico rellena
 * a mano y sube a MantisBT él mismo (sin PDF, decisión del autor). Se conserva por
 * referencia; mantener este código no implica reactivar el PDF. Ver README del plugin.
 *
 * Antes esto era un wrapper que llamaba por shell a un `reports/generate-report.php`
 * que NUNCA existió en el repo (3 generadores fantasma documentados, incompatibles
 * entre sí). Unificado en UN solo camino, autocontenido en PHP:
 *
 *   1. Recupera el último diagnóstico (JSON) del host por email de cliente.
 *   2. Renderiza un informe HTML con las secciones fijas del servicio.
 *   3. Lo convierte a PDF con wkhtmltopdf SI está disponible; si no, adjunta el
 *      HTML (degradación elegante, no se rompe la fase).
 *   4. Adjunta el fichero al ticket en MantisBT vía RC_Mantis_API::attach_file().
 *
 * No depende de ningún binario obligatorio: wkhtmltopdf es opcional.
 */
class RC_Tech_Report {

    public static function generate( int $issue_id, string $client_email ): array|WP_Error {
        $host = rc_tech_lookup_host( $client_email );
        if ( ! $host || empty( $host['last_json'] ) ) {
            return new WP_Error( 'rc_tech_no_diag',
                'Sin diagnóstico previo para ' . $client_email );
        }

        $diag = json_decode( $host['last_json'], true );
        if ( ! is_array( $diag ) ) {
            return new WP_Error( 'rc_tech_bad_json',
                'El diagnóstico almacenado no es JSON válido' );
        }

        // ── 1) Render HTML ──────────────────────────────────────────────────
        $html = self::render_html( $issue_id, $client_email, $host, $diag );

        $upload = wp_upload_dir();
        $dir    = trailingslashit( $upload['basedir'] ) . 'rc-tech/reports';
        wp_mkdir_p( $dir );

        $stamp     = gmdate( 'Ymd-His' );
        $base      = "informe-ticket-{$issue_id}-{$stamp}";
        $html_path = "{$dir}/{$base}.html";

        if ( file_put_contents( $html_path, $html ) === false ) {
            return new WP_Error( 'rc_tech_write_fail', "no se pudo escribir {$html_path}" );
        }

        // ── 2) HTML → PDF (wkhtmltopdf opcional) ────────────────────────────
        $pdf_path = "{$dir}/{$base}.pdf";
        $format   = 'html';
        $attach   = $html_path;

        $wkhtml = self::find_wkhtmltopdf();
        if ( $wkhtml && function_exists( 'shell_exec' ) ) {
            // --disable-local-file-access: el HTML se genera a partir de datos
            // del ticket (resumen, notas…), que pueden contener entrada de
            // usuario. Con acceso a ficheros locales un <img src="file:///etc/passwd">
            // inyectado se embebería en el PDF (LFI). Lo bloqueamos explícitamente.
            $cmd = sprintf(
                '%s --quiet --disable-local-file-access %s %s 2>&1',
                escapeshellarg( $wkhtml ),
                escapeshellarg( $html_path ),
                escapeshellarg( $pdf_path )
            );
            shell_exec( $cmd );
            if ( is_readable( $pdf_path ) && filesize( $pdf_path ) > 0 ) {
                $format = 'pdf';
                $attach = $pdf_path;
            }
        }

        // ── 3) Adjuntar a Mantis ────────────────────────────────────────────
        if ( ! function_exists( 'rc_mantis_get_api' ) ) {
            return new WP_Error( 'rc_tech_no_mantis', 'rc-mantisbt no está activo' );
        }
        $api = rc_mantis_get_api();
        if ( ! $api ) {
            return new WP_Error( 'rc_tech_no_mantis', 'API de MantisBT no configurada' );
        }

        $res = $api->attach_file( $issue_id, $attach, basename( $attach ) );
        if ( is_wp_error( $res ) ) {
            return $res;
        }

        return [
            'issue_id'  => $issue_id,
            'format'    => $format,
            'file'      => $attach,
            'attached'  => true,
        ];
    }

    /**
     * Localiza el binario wkhtmltopdf. Devuelve null si no está instalado.
     */
    private static function find_wkhtmltopdf(): ?string {
        if ( defined( 'RC_WKHTMLTOPDF_BIN' ) && is_executable( RC_WKHTMLTOPDF_BIN ) ) {
            return RC_WKHTMLTOPDF_BIN;
        }
        if ( ! function_exists( 'shell_exec' ) ) {
            return null;
        }
        $found = trim( (string) @shell_exec( 'command -v wkhtmltopdf 2>/dev/null' ) );
        return $found !== '' ? $found : null;
    }

    /**
     * Renderiza el informe HTML con las secciones fijas del servicio
     * (resumen ejecutivo, incidencias, estado actual, recomendaciones).
     */
    private static function render_html( int $issue_id, string $email, array $host, array $diag ): string {
        $score    = isset( $host['last_score'] ) ? (int) $host['last_score'] : null;
        $hostname = esc_html( (string) ( $host['hostname'] ?? 'desconocido' ) );
        $os       = esc_html( (string) ( $host['os'] ?? 'desconocido' ) );
        $seen     = esc_html( (string) ( $host['last_seen'] ?? '' ) );
        $fecha    = esc_html( gmdate( 'Y-m-d H:i' ) . ' UTC' );
        $email_e  = esc_html( $email );

        $score_color = $score === null ? '#7a7f8e'
            : ( $score >= 80 ? '#00a86b' : ( $score >= 60 ? '#c79a00' : '#d6336c' ) );
        $score_txt = $score === null ? '—' : $score . '/100';

        // Volcado legible del JSON de diagnóstico.
        $diag_pretty = esc_html(
            wp_json_encode( $diag, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES )
        );

        ob_start();
        ?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>Informe técnico · Ticket #<?php echo (int) $issue_id; ?></title>
<style>
  body { font-family: "DejaVu Sans", Arial, sans-serif; color: #1a1d24; margin: 32px; font-size: 13px; line-height: 1.5; }
  h1 { font-size: 22px; margin: 0 0 4px; }
  h2 { font-size: 15px; margin: 28px 0 8px; border-bottom: 2px solid #00a86b; padding-bottom: 4px; }
  .meta { color: #555; font-size: 12px; margin-bottom: 18px; }
  .score { display: inline-block; padding: 6px 14px; border-radius: 6px; color: #fff; font-weight: 700; background: <?php echo esc_attr( $score_color ); ?>; }
  table { border-collapse: collapse; width: 100%; margin-top: 6px; }
  td, th { border: 1px solid #ddd; padding: 6px 8px; text-align: left; }
  th { background: #f3f4f6; }
  pre { background: #0d0f13; color: #d6e2dd; padding: 12px; border-radius: 6px; overflow: auto; font-size: 11px; white-space: pre-wrap; word-break: break-word; }
  footer { margin-top: 36px; color: #888; font-size: 11px; border-top: 1px solid #ddd; padding-top: 8px; }
</style>
</head>
<body>
  <h1>Informe técnico — ResolveCore</h1>
  <div class="meta">
    Ticket <strong>#<?php echo (int) $issue_id; ?></strong> ·
    Cliente: <strong><?php echo $email_e; ?></strong> ·
    Generado: <?php echo $fecha; ?>
  </div>

  <h2>1. Resumen ejecutivo</h2>
  <p>Salud del sistema: <span class="score"><?php echo esc_html( $score_txt ); ?></span></p>
  <table>
    <tr><th>Equipo</th><td><?php echo $hostname; ?></td></tr>
    <tr><th>Sistema operativo</th><td><?php echo $os; ?></td></tr>
    <tr><th>Último diagnóstico</th><td><?php echo $seen; ?></td></tr>
  </table>

  <h2>2. Incidencias detectadas</h2>
  <?php echo self::render_incidencias( $diag, $score ); ?>

  <h2>3. Estado actual del sistema (diagnóstico)</h2>
  <pre><?php echo $diag_pretty; ?></pre>

  <h2>4. Recomendaciones</h2>
  <?php echo self::render_recomendaciones( $score ); ?>

  <footer>
    ResolveCore — Solución a tus problemas informáticos · Francisco Vidal Mateo.<br>
    Documento generado automáticamente a partir del último diagnóstico del equipo.
  </footer>
</body>
</html>
        <?php
        return (string) ob_get_clean();
    }

    private static function render_incidencias( array $diag, ?int $score ): string {
        $items = [];

        $disk = $diag['discos'][0]['uso_pct'] ?? ( $diag['disco']['porcentaje_uso'] ?? null );
        if ( $disk !== null && (float) $disk >= 85 ) {
            $items[] = sprintf( 'Disco con uso elevado (%s%%): liberar espacio o ampliar almacenamiento.', esc_html( (string) $disk ) );
        }
        $ram = $diag['memoria']['uso_pct'] ?? null;
        if ( $ram !== null && (float) $ram >= 85 ) {
            $items[] = sprintf( 'Memoria saturada (%s%%): revisar procesos o ampliar RAM.', esc_html( (string) $ram ) );
        }
        if ( isset( $diag['seguridad']['firewall'] ) && ! $diag['seguridad']['firewall'] ) {
            $items[] = 'Cortafuegos desactivado: activarlo.';
        }
        if ( isset( $diag['seguridad']['antivirus_activo'] ) && ! $diag['seguridad']['antivirus_activo'] ) {
            $items[] = 'Antivirus inactivo: habilitar protección en tiempo real.';
        }
        $crit = $diag['vulnerabilidades']['criticas'] ?? null;
        if ( $crit !== null && (int) $crit > 0 ) {
            $items[] = sprintf( '%d vulnerabilidad(es) crítica(s): aplicar parches pendientes.', (int) $crit );
        }
        $upd = $diag['actualizaciones']['pendientes'] ?? null;
        if ( $upd !== null && (int) $upd > 0 ) {
            $items[] = sprintf( '%d actualización(es) del sistema pendiente(s).', (int) $upd );
        }

        if ( ! $items ) {
            return '<p>No se han detectado incidencias relevantes en el último diagnóstico.</p>';
        }
        $out = '<ul>';
        foreach ( $items as $i ) {
            $out .= '<li>' . esc_html( $i ) . '</li>';
        }
        return $out . '</ul>';
    }

    private static function render_recomendaciones( ?int $score ): string {
        if ( $score === null ) {
            return '<p>Sin score disponible. Repetir diagnóstico para una valoración.</p>';
        }
        if ( $score >= 80 ) {
            return '<p>El equipo está en buen estado. Mantener actualizaciones y revisiones periódicas.</p>';
        }
        if ( $score >= 60 ) {
            return '<p>Estado mejorable. Resolver las incidencias listadas y programar una revisión de seguimiento.</p>';
        }
        return '<p>Estado crítico. Se recomienda intervención prioritaria sobre las incidencias detectadas.</p>';
    }
}
