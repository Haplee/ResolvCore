<?php
if ( ! defined( 'ABSPATH' ) ) exit;

/**
 * Cálculo y escaneo de SLAs basados en due_date del plugin SetDueDate de Mantis.
 */
class RC_Tech_Sla {

    /**
     * Devuelve issues con SLA en estado warning/overdue para el proyecto activo.
     *
     * @return array<int,array{issue:array,seconds_left:int,state:string}>
     */
    public static function scan(): array {
        $api = rc_tech_api();
        if ( ! $api ) return [];

        $issues = $api->list_issues( [
            'project_id' => rc_tech_project_id(),
            'page_size'  => 100,
            'status_in'  => [ 10, 20, 30, 40, 50 ],
        ] );
        if ( is_wp_error( $issues ) ) {
            error_log( '[rc-tech] SLA scan failed: ' . $issues->get_error_message() );
            return [];
        }

        $out = [];
        foreach ( $issues as $issue ) {
            $due  = $issue['due_date'] ?? null;
            $secs = rc_tech_seconds_left( $due );
            if ( $secs === null ) continue;

            if ( $secs <= 0 ) {
                $out[] = [ 'issue' => $issue, 'seconds_left' => $secs, 'state' => 'sla_overdue' ];
            } elseif ( $secs < 1800 ) {
                $out[] = [ 'issue' => $issue, 'seconds_left' => $secs, 'state' => 'sla_warn_30m' ];
            }
        }
        return $out;
    }
}
