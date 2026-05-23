<?php
if ( ! defined( 'ABSPATH' ) ) exit;

$data = RC_Tech_Queue::build( [
    'user_id'         => get_current_user_id(),
    'only_mine'       => false,
    'only_unassigned' => false,
] );
$kpis = $data['kpis'];
$rows = $data['rows'];
$err  = $data['error'] ?? '';
?>
<div class="wrap rc-tech-wrap">
    <h1 class="wp-heading-inline">Panel Técnico ResolveCore</h1>
    <p class="description">Cola priorizada · refresco cada <?php echo (int) ( RC_TECH_POLL_INTERVAL_MS / 1000 ); ?>s</p>

    <?php if ( $err ): ?>
        <div class="notice notice-error"><p><strong>Error:</strong> <?php echo esc_html( $err ); ?></p></div>
    <?php endif; ?>

    <div class="rc-tech-kpis">
        <div class="kpi"><span class="num"><?php echo (int) $kpis['open']; ?></span><span class="lbl">Abiertos</span></div>
        <div class="kpi"><span class="num"><?php echo (int) $kpis['mine']; ?></span><span class="lbl">Míos</span></div>
        <div class="kpi <?php echo $kpis['overdue'] > 0 ? 'red' : ''; ?>">
            <span class="num"><?php echo (int) $kpis['overdue']; ?></span><span class="lbl">SLA vencidos</span>
        </div>
        <div class="kpi"><span class="num"><?php echo $kpis['fleet_score'] !== null ? (int) $kpis['fleet_score'] : '—'; ?></span><span class="lbl">Score flota</span></div>
    </div>

    <div class="rc-tech-toolbar">
        <select id="rc-tech-os">
            <option value="">SO (todos)</option>
            <option value="windows">Windows</option>
            <option value="linux">Linux</option>
            <option value="macos">macOS</option>
            <option value="android">Android</option>
        </select>
        <label><input type="checkbox" id="rc-tech-only-mine"> Solo míos</label>
        <label><input type="checkbox" id="rc-tech-only-unassigned"> Sin asignar</label>
        <input type="search" id="rc-tech-q" placeholder="Buscar resumen…">
        <button type="button" class="button" id="rc-tech-refresh">↻ Refrescar</button>
        <button type="button" class="button" id="rc-tech-toggle-view" data-view="table">Vista Kanban</button>
        <a class="button" href="<?php echo esc_url( rest_url( 'rc-tech/v1/export.csv?_wpnonce=' . wp_create_nonce( 'wp_rest' ) ) ); ?>">⇩ CSV</a>
        <span class="rc-tech-updated" id="rc-tech-updated"></span>
    </div>

    <div id="rc-tech-kanban" class="rc-tech-kanban" hidden></div>

    <table class="wp-list-table widefat fixed striped rc-tech-table">
        <thead>
            <tr>
                <th style="width:50px">#</th>
                <th style="width:90px">Prio</th>
                <th>Resumen</th>
                <th style="width:200px">Cliente</th>
                <th style="width:80px">SO</th>
                <th style="width:100px">AnyDesk</th>
                <th style="width:140px">SLA</th>
                <th style="width:70px">Host</th>
                <th style="width:240px">Acciones</th>
            </tr>
        </thead>
        <tbody id="rc-tech-rows">
            <?php foreach ( $rows as $row ): ?>
                <?php include RC_TECH_DIR . 'admin/partials/row.php'; ?>
            <?php endforeach; ?>
            <?php if ( ! $rows ): ?>
                <tr><td colspan="9"><em>Sin tickets en cola.</em></td></tr>
            <?php endif; ?>
        </tbody>
    </table>

    <aside id="rc-tech-sidebar" class="rc-tech-sidebar" hidden>
        <button type="button" class="rc-tech-sidebar-close" aria-label="Cerrar">×</button>
        <h2 id="rc-tech-sidebar-title">Ticket</h2>
        <nav class="rc-tech-tabs">
            <button data-tab="timeline" class="active">Timeline</button>
            <button data-tab="host">Host</button>
            <button data-tab="notes">Notas</button>
        </nav>
        <div class="rc-tech-tab-content" id="rc-tech-tab-timeline"><em>Cargando…</em></div>
        <div class="rc-tech-tab-content" id="rc-tech-tab-host" hidden></div>
        <div class="rc-tech-tab-content" id="rc-tech-tab-notes" hidden></div>
    </aside>
</div>
