<?php
/**
 * Ejemplo de add-on opcional para canal Telegram.
 *
 * Cómo activar:
 *   1) Define TELEGRAM_BOT_TOKEN y TELEGRAM_CHAT_ID en wp-config.php.
 *   2) Mueve este fichero a wp-content/mu-plugins/rc-tech-telegram.php
 *      o requírelo desde un plugin propio.
 *
 * No modifica rc-tech core — engancha al hook `rc_tech_alert_fired`.
 */
if ( ! defined( 'ABSPATH' ) ) exit;

add_action( 'rc_tech_alert_fired', function ( $alert ): void {
    if ( ! defined( 'TELEGRAM_BOT_TOKEN' ) || ! defined( 'TELEGRAM_CHAT_ID' ) ) return;

    $msg = sprintf(
        "*ResolveCore #%d* — %s\n%s\nHandler: %s",
        $alert['issue_id'],
        strtoupper( str_replace( '_', ' ', $alert['alert_type'] ) ),
        $alert['issue']['summary'] ?? '',
        $alert['issue']['handler']['name'] ?? '(sin asignar)'
    );

    wp_remote_post( 'https://api.telegram.org/bot' . TELEGRAM_BOT_TOKEN . '/sendMessage', [
        'timeout' => 5,
        'body'    => [
            'chat_id'    => TELEGRAM_CHAT_ID,
            'text'       => $msg,
            'parse_mode' => 'Markdown',
        ],
    ] );
} );
