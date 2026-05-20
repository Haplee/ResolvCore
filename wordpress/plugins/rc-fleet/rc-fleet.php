<?php
/**
 * Plugin Name: ResolveCore — Fleet Panel
 * Plugin URI:  https://github.com/Haplee/ResolveCore
 * Description: Panel multiplataforma de flota: agentes Win/Linux/Android publican su JSON de diagnóstico vía REST y se centralizan en wp-admin.
 * Version:     0.1.0
 * Author:      Francisco Vidal Mateo
 * License:     GPL-2.0+
 * Text Domain: rc-fleet
 */

if ( ! defined( 'ABSPATH' ) ) exit;

define( 'RC_FLEET_VERSION', '0.1.0' );
define( 'RC_FLEET_DB_VER', '1' );
define( 'RC_FLEET_TABLE',  'rc_fleet_hosts' );

// ── Activation / schema ────────────────────────────────────────────────────────

register_activation_hook( __FILE__, 'rc_fleet_install' );

function rc_fleet_install(): void {
    global $wpdb;
    $table   = $wpdb->prefix . RC_FLEET_TABLE;
    $charset = $wpdb->get_charset_collate();

    $sql = "CREATE TABLE {$table} (
        id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
        host_id VARCHAR(64) NOT NULL,
        client_email VARCHAR(190) NOT NULL,
        hostname VARCHAR(120) NOT NULL,
        os VARCHAR(20) NOT NULL DEFAULT 'unknown',
        os_version VARCHAR(80) NOT NULL DEFAULT '',
        last_seen DATETIME NOT NULL,
        last_score TINYINT DEFAULT NULL,
        last_json LONGTEXT DEFAULT NULL,
        ticket_id INT(11) DEFAULT NULL,
        optim_at DATETIME DEFAULT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY  (id),
        UNIQUE KEY uniq_host (client_email, host_id),
        KEY idx_seen (last_seen),
        KEY idx_os (os)
    ) {$charset};";

    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    dbDelta( $sql );
    update_option( 'rc_fleet_db_ver', RC_FLEET_DB_VER );
}

add_action( 'plugins_loaded', function () {
    if ( (string) get_option( 'rc_fleet_db_ver', '0' ) !== RC_FLEET_DB_VER ) {
        rc_fleet_install();
    }
} );

// ── Helpers ────────────────────────────────────────────────────────────────────

function rc_fleet_get_token(): string {
    if ( defined( 'RC_FLEET_TOKEN' ) && RC_FLEET_TOKEN ) {
        return (string) RC_FLEET_TOKEN;
    }
    return (string) get_option( 'rc_fleet_token', '' );
}

function rc_fleet_check_auth( WP_REST_Request $req ): bool {
    $expected = rc_fleet_get_token();
    if ( $expected === '' ) return false;
    $auth = $req->get_header( 'authorization' );
    if ( ! $auth || stripos( $auth, 'Bearer ' ) !== 0 ) return false;
    $token = trim( substr( $auth, 7 ) );
    return hash_equals( $expected, $token );
}

function rc_fleet_normalize_os( string $raw ): string {
    $r = strtolower( trim( $raw ) );
    if ( str_contains( $r, 'win' ) )       return 'windows';
    if ( str_contains( $r, 'android' ) )   return 'android';
    if ( str_contains( $r, 'mac' ) || str_contains( $r, 'darwin' ) ) return 'macos';
    if ( str_contains( $r, 'linux' ) || str_contains( $r, 'ubuntu' ) || str_contains( $r, 'debian' ) ) return 'linux';
    return 'unknown';
}

/**
 * Calcula un score 0-100 de salud a partir del JSON de diagnóstico.
 * Heurística simple: penaliza disco lleno, RAM saturada, CVEs críticos, AV inactivo.
 */
function rc_fleet_score( array $d ): int {
    $score = 100;

    // Disco
    $disk_used = null;
    if ( isset( $d['discos'][0]['uso_pct'] ) )       $disk_used = (float) $d['discos'][0]['uso_pct'];
    elseif ( isset( $d['hardware']['disk_used_pct'] ) ) $disk_used = (float) $d['hardware']['disk_used_pct'];
    if ( $disk_used !== null ) {
        if ( $disk_used >= 95 ) $score -= 25;
        elseif ( $disk_used >= 85 ) $score -= 12;
        elseif ( $disk_used >= 75 ) $score -= 5;
    }

    // RAM
    $ram_used = null;
    if ( isset( $d['memoria']['uso_pct'] ) )      $ram_used = (float) $d['memoria']['uso_pct'];
    elseif ( isset( $d['hardware']['ram_used_pct'] ) ) $ram_used = (float) $d['hardware']['ram_used_pct'];
    if ( $ram_used !== null && $ram_used >= 85 ) $score -= 10;

    // Seguridad
    if ( isset( $d['seguridad']['firewall'] ) && ! $d['seguridad']['firewall'] ) $score -= 10;
    if ( isset( $d['seguridad']['antivirus_activo'] ) && ! $d['seguridad']['antivirus_activo'] ) $score -= 15;

    // CVEs
    if ( isset( $d['vulnerabilidades']['criticas'] ) ) {
        $score -= min( 30, 5 * (int) $d['vulnerabilidades']['criticas'] );
    }

    return (int) max( 0, min( 100, $score ) );
}

// ── REST API ───────────────────────────────────────────────────────────────────

add_action( 'rest_api_init', function () {
    register_rest_route( 'rc/v1', '/fleet', [
        'methods'             => 'POST',
        'callback'            => 'rc_fleet_rest_post',
        'permission_callback' => 'rc_fleet_check_auth',
    ] );
    register_rest_route( 'rc/v1', '/fleet', [
        'methods'             => 'GET',
        'callback'            => 'rc_fleet_rest_list',
        'permission_callback' => 'rc_fleet_check_auth',
    ] );
} );

function rc_fleet_rest_post( WP_REST_Request $req ) {
    $body = $req->get_json_params();
    if ( ! is_array( $body ) ) {
        return new WP_Error( 'rc_fleet_invalid', 'JSON inválido', [ 'status' => 400 ] );
    }

    $client_email = sanitize_email( $body['client_email'] ?? '' );
    if ( ! is_email( $client_email ) ) {
        return new WP_Error( 'rc_fleet_invalid_email', 'client_email requerido', [ 'status' => 400 ] );
    }

    $diag = $body['diagnostico'] ?? [];
    if ( ! is_array( $diag ) || empty( $diag['_meta'] ) ) {
        return new WP_Error( 'rc_fleet_invalid_diag', 'falta diagnostico._meta', [ 'status' => 400 ] );
    }

    $meta     = $diag['_meta'];
    $hostname = sanitize_text_field( (string) ( $meta['hostname'] ?? 'desconocido' ) );
    $os       = rc_fleet_normalize_os( (string) ( $meta['plataforma'] ?? '' ) );
    $os_ver   = sanitize_text_field( (string) ( $diag['sistema']['build'] ?? $diag['sistema']['nombre'] ?? '' ) );
    $host_id  = substr( hash( 'sha256', $client_email . '|' . $hostname ), 0, 64 );

    $score    = rc_fleet_score( $diag );
    $now      = current_time( 'mysql' );
    $ticket   = isset( $body['ticket_id'] ) ? (int) $body['ticket_id'] : null;
    $optim_at = ! empty( $body['optim_at'] ) ? sanitize_text_field( $body['optim_at'] ) : null;

    global $wpdb;
    $table = $wpdb->prefix . RC_FLEET_TABLE;

    $data = [
        'host_id'      => $host_id,
        'client_email' => $client_email,
        'hostname'     => $hostname,
        'os'           => $os,
        'os_version'   => $os_ver,
        'last_seen'    => $now,
        'last_score'   => $score,
        'last_json'    => wp_json_encode( $diag, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES ),
        'ticket_id'    => $ticket,
        'optim_at'     => $optim_at,
    ];

    $existing = $wpdb->get_var( $wpdb->prepare(
        "SELECT id FROM {$table} WHERE client_email=%s AND host_id=%s",
        $client_email, $host_id
    ) );

    if ( $existing ) {
        $wpdb->update( $table, $data, [ 'id' => (int) $existing ] );
        $id = (int) $existing;
        $action = 'updated';
    } else {
        $wpdb->insert( $table, $data );
        $id = (int) $wpdb->insert_id;
        $action = 'created';
    }

    return rest_ensure_response( [
        'ok'      => true,
        'action'  => $action,
        'id'      => $id,
        'host_id' => $host_id,
        'score'   => $score,
    ] );
}

function rc_fleet_rest_list( WP_REST_Request $req ) {
    global $wpdb;
    $table = $wpdb->prefix . RC_FLEET_TABLE;
    $os    = sanitize_text_field( $req->get_param( 'os' ) ?? '' );
    $limit = min( 200, max( 1, (int) ( $req->get_param( 'limit' ) ?? 50 ) ) );

    if ( $os ) {
        $rows = $wpdb->get_results( $wpdb->prepare(
            "SELECT id, host_id, client_email, hostname, os, os_version, last_seen, last_score, ticket_id, optim_at
             FROM {$table} WHERE os=%s ORDER BY last_seen DESC LIMIT %d",
            $os, $limit
        ) );
    } else {
        $rows = $wpdb->get_results( $wpdb->prepare(
            "SELECT id, host_id, client_email, hostname, os, os_version, last_seen, last_score, ticket_id, optim_at
             FROM {$table} ORDER BY last_seen DESC LIMIT %d",
            $limit
        ) );
    }
    return rest_ensure_response( [ 'ok' => true, 'count' => count( $rows ), 'hosts' => $rows ] );
}

// ── Admin page ────────────────────────────────────────────────────────────────

add_action( 'admin_menu', function () {
    add_menu_page(
        'Fleet · ResolveCore',
        'Fleet',
        'manage_options',
        'rc-fleet',
        'rc_fleet_admin_page',
        'dashicons-networking',
        25
    );
} );

function rc_fleet_admin_page(): void {
    if ( ! current_user_can( 'manage_options' ) ) return;
    global $wpdb;
    $table = $wpdb->prefix . RC_FLEET_TABLE;

    $os_filter = isset( $_GET['os'] ) ? sanitize_text_field( wp_unslash( $_GET['os'] ) ) : '';
    $search    = isset( $_GET['q'] )  ? sanitize_text_field( wp_unslash( $_GET['q'] ) )  : '';

    $where  = 'WHERE 1=1';
    $params = [];
    if ( $os_filter ) { $where .= ' AND os=%s';                $params[] = $os_filter; }
    if ( $search )    { $where .= ' AND (hostname LIKE %s OR client_email LIKE %s)';
                        $params[] = '%' . $wpdb->esc_like( $search ) . '%';
                        $params[] = '%' . $wpdb->esc_like( $search ) . '%'; }

    $sql  = "SELECT id,host_id,client_email,hostname,os,os_version,last_seen,last_score,ticket_id,optim_at FROM {$table} {$where} ORDER BY last_seen DESC LIMIT 200";
    $rows = $params
        ? $wpdb->get_results( $wpdb->prepare( $sql, ...$params ) )
        : $wpdb->get_results( $sql );

    $total = (int) $wpdb->get_var( "SELECT COUNT(*) FROM {$table}" );
    $by_os = $wpdb->get_results( "SELECT os, COUNT(*) AS n FROM {$table} GROUP BY os", OBJECT_K );

    $token  = rc_fleet_get_token();
    $masked = $token ? substr( $token, 0, 4 ) . '…' . substr( $token, -4 ) : '— no configurado —';
    ?>
    <div class="wrap">
      <h1>Fleet · Panel multiplataforma</h1>
      <p style="margin:.5rem 0 1rem;color:#555">
        <strong>Total hosts:</strong> <?php echo (int) $total; ?> ·
        <?php foreach ( [ 'windows','linux','macos','android','unknown' ] as $o ): $n = isset( $by_os[ $o ] ) ? (int) $by_os[ $o ]->n : 0; ?>
          <span style="margin-right:8px;"><strong><?php echo esc_html( $o ); ?>:</strong> <?php echo $n; ?></span>
        <?php endforeach; ?>
      </p>

      <form method="get" style="margin:1rem 0;">
        <input type="hidden" name="page" value="rc-fleet">
        <input type="search" name="q" value="<?php echo esc_attr( $search ); ?>" placeholder="Buscar host o email…" style="min-width:280px;">
        <select name="os">
          <option value="">— Todos los SO —</option>
          <?php foreach ( [ 'windows'=>'Windows','linux'=>'Linux','macos'=>'macOS','android'=>'Android','unknown'=>'Desconocido' ] as $v=>$l ): ?>
            <option value="<?php echo esc_attr( $v ); ?>" <?php selected( $os_filter, $v ); ?>><?php echo esc_html( $l ); ?></option>
          <?php endforeach; ?>
        </select>
        <button class="button button-primary">Filtrar</button>
        <a href="<?php echo esc_url( admin_url( 'admin.php?page=rc-fleet' ) ); ?>" class="button">Limpiar</a>
      </form>

      <table class="widefat fixed striped">
        <thead>
          <tr>
            <th style="width:60px">ID</th>
            <th>Host</th>
            <th>Cliente</th>
            <th>SO</th>
            <th>Versión</th>
            <th style="width:80px">Score</th>
            <th>Última conexión</th>
            <th>Ticket</th>
          </tr>
        </thead>
        <tbody>
          <?php if ( ! $rows ): ?>
            <tr><td colspan="8" style="padding:2rem;text-align:center;color:#888">No hay hosts registrados. Los agentes publican vía <code>POST /wp-json/rc/v1/fleet</code> con <code>Authorization: Bearer …</code>.</td></tr>
          <?php else: foreach ( $rows as $r ):
              $score = (int) $r->last_score;
              $color = $score >= 80 ? '#28c840' : ( $score >= 60 ? '#febc2e' : '#ff6b35' );
          ?>
            <tr>
              <td><?php echo (int) $r->id; ?></td>
              <td><strong><?php echo esc_html( $r->hostname ); ?></strong></td>
              <td><?php echo esc_html( $r->client_email ); ?></td>
              <td><code><?php echo esc_html( $r->os ); ?></code></td>
              <td><?php echo esc_html( $r->os_version ); ?></td>
              <td><span style="display:inline-block;min-width:36px;text-align:center;padding:2px 8px;border-radius:3px;background:<?php echo $color; ?>;color:#000;font-weight:700"><?php echo $score; ?></span></td>
              <td><?php echo esc_html( $r->last_seen ); ?></td>
              <td><?php if ( $r->ticket_id ): ?><a href="https://mantis.resolvecore.website/view.php?id=<?php echo (int) $r->ticket_id; ?>" target="_blank">#<?php echo (int) $r->ticket_id; ?></a><?php else: ?>—<?php endif; ?></td>
            </tr>
          <?php endforeach; endif; ?>
        </tbody>
      </table>

      <h2 style="margin-top:2.5rem">Integración del agente</h2>
      <p>Token actual: <code><?php echo esc_html( $masked ); ?></code> — defínelo como constante <code>RC_FLEET_TOKEN</code> en <code>wp-config.php</code> (recomendado) o en la opción <code>rc_fleet_token</code>.</p>
      <pre style="background:#1a1d24;color:#e8eaf0;padding:1rem;overflow:auto;font-size:12px;line-height:1.5;border-radius:4px">
curl -X POST https://resolvecore.website/wp-json/rc/v1/fleet \
  -H "Authorization: Bearer &lt;RC_FLEET_TOKEN&gt;" \
  -H "Content-Type: application/json" \
  -d '{
    "client_email": "cliente@example.com",
    "diagnostico": {
      "_meta": {"plataforma":"windows","hostname":"PC-OFI-01","version":"4.0.0"},
      "sistema": {"nombre":"Windows 11 Pro","build":"22631"},
      "memoria": {"uso_pct": 62},
      "discos":  [{"uso_pct": 78}],
      "seguridad": {"firewall": true, "antivirus_activo": true},
      "vulnerabilidades": {"criticas": 0}
    },
    "ticket_id": 42
  }'</pre>
      <p style="color:#666">Respuesta: <code>{ok:true, action:"created|updated", id, score}</code>. Listado: <code>GET /wp-json/rc/v1/fleet?os=linux&amp;limit=50</code>.</p>
    </div>
    <?php
}
