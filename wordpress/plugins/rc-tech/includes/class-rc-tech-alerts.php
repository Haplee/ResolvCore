<?php
if ( ! defined( 'ABSPATH' ) ) exit;

/**
 * Alertas SLA — disparo idempotente por (issue_id, alert_type, payload_hash).
 */
class RC_Tech_Alerts {

    public static function scan_and_fire(): void {
        $matches = RC_Tech_Sla::scan();
        $count   = 0;
        foreach ( $matches as $m ) {
            if ( self::fire( $m['issue'], $m['state'] ) ) {
                $count++;
            }
        }
        set_transient( 'rc_tech_sla_count', count( $matches ), RC_TECH_SLA_CACHE_TTL );
    }

    private static function fire( array $issue, string $alert_type ): bool {
        global $wpdb;
        $table = $wpdb->prefix . 'rc_tech_alerts';

        $issue_id = (int) ( $issue['id'] ?? 0 );
        $due      = $issue['due_date'] ?? null;
        $hash     = rc_tech_payload_hash( $issue_id, $alert_type, $due );

        $exists = (int) $wpdb->get_var( $wpdb->prepare(
            "SELECT 1 FROM {$table} WHERE issue_id=%d AND alert_type=%s AND payload_hash=%s LIMIT 1",
            $issue_id, $alert_type, $hash
        ) );
        if ( $exists ) return false;

        // Email canal default
        $subject_state = $alert_type === 'sla_overdue' ? 'SLA VENCIDO' : 'SLA <30min';
        $subject = sprintf( '[ResolveCore #%d] %s — %s',
            $issue_id, $subject_state, $issue['summary'] ?? '' );

        $body  = "Ticket #{$issue_id}\n";
        $body .= 'Resumen: ' . ( $issue['summary'] ?? '' ) . "\n";
        $body .= 'Estado: '  . ( $issue['status']['name'] ?? '' ) . "\n";
        $body .= 'Handler: ' . ( $issue['handler']['name'] ?? '(sin asignar)' ) . "\n";
        $body .= 'Due date: ' . ( $due ?? '—' ) . "\n";
        $body .= "\nAbrir panel: " . admin_url( 'admin.php?page=rc-tech' ) . "\n";

        $sent = wp_mail( get_option( 'admin_email' ), $subject, $body );

        $wpdb->insert( $table, [
            'issue_id'     => $issue_id,
            'alert_type'   => $alert_type,
            'fired_at'     => current_time( 'mysql' ),
            'channel'      => 'email',
            'payload_hash' => $hash,
        ], [ '%d', '%s', '%s', '%s', '%s' ] );

        do_action( 'rc_tech_alert_fired', [
            'issue_id'   => $issue_id,
            'issue'      => $issue,
            'alert_type' => $alert_type,
            'sent'       => $sent,
        ] );
        return true;
    }

    public static function gc(): void {
        global $wpdb;
        $table = $wpdb->prefix . 'rc_tech_alerts';
        $wpdb->query(
            $wpdb->prepare( "DELETE FROM %i WHERE fired_at < DATE_SUB(NOW(), INTERVAL 90 DAY)", $table )
        );
    }
}
