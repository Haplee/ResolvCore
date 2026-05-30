<?php
if ( ! defined( 'ABSPATH' ) ) exit;
/** @var array $row */

$prio_color = match ( $row['priority'] ) {
    'immediate', 'urgent' => 'red',
    'high'                => 'orange',
    'normal'              => 'blue',
    default               => 'gray',
};
$sla_class = '';
if ( $row['seconds_left'] !== null ) {
    if ( $row['seconds_left'] <= 0 )   $sla_class = 'sla-overdue';
    elseif ( $row['seconds_left'] < 1800 ) $sla_class = 'sla-warn';
}
$score_color = rc_tech_score_color( isset( $row['host_score'] ) ? (int) $row['host_score'] : null );
?>
<tr data-issue-id="<?php echo (int) $row['id']; ?>"
    data-email="<?php echo esc_attr( $row['reporter_email'] ); ?>"
    data-anydesk="<?php echo esc_attr( $row['anydesk'] ); ?>"
    data-os="<?php echo esc_attr( $row['os'] ); ?>">
    <td><a href="#" class="rc-tech-row-open">#<?php echo (int) $row['id']; ?></a></td>
    <td><span class="rc-tech-prio rc-tech-prio-<?php echo esc_attr( $prio_color ); ?>"><?php echo esc_html( $row['priority'] ); ?></span></td>
    <td><strong><?php echo esc_html( $row['summary'] ); ?></strong><br><small><?php echo esc_html( $row['category'] ); ?></small></td>
    <td><?php echo esc_html( $row['reporter'] ); ?><br><small><?php echo esc_html( $row['reporter_email'] ); ?></small></td>
    <td><span class="rc-tech-os rc-tech-os-<?php echo esc_attr( $row['os'] ); ?>"><?php echo esc_html( $row['os'] ?: '—' ); ?></span></td>
    <td class="col-anydesk"><?php if ( $row['anydesk'] ): ?><code><?php echo esc_html( $row['anydesk'] ); ?></code><?php else: echo '—'; endif; ?></td>
    <td class="<?php echo esc_attr( $sla_class ); ?>"><?php echo esc_html( rc_tech_format_countdown( $row['seconds_left'] ) ); ?></td>
    <td class="col-score"><?php if ( $row['host_score'] !== null ): ?>
        <span class="rc-tech-score rc-tech-score-<?php echo esc_attr( $score_color ); ?>"><?php echo (int) $row['host_score']; ?></span>
    <?php else: echo '—'; endif; ?></td>
    <td class="rc-tech-actions">
        <button class="button button-small rc-tech-act" data-act="assign_me">Asignarme</button>
        <button class="button button-small rc-tech-act" data-act="diag">Diag</button>
        <button class="button button-small rc-tech-act" data-act="pdf">PDF</button>
        <button class="button button-small button-primary rc-tech-act" data-act="resolve">Resolver</button>
    </td>
</tr>
