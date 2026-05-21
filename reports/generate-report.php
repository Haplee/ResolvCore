<?php
/**
 * ResolveCore — Generador de informe técnico PDF
 *
 * Uso:
 *   php generate-report.php --json <ruta.json> [--output <informe.pdf>]
 *                           [--ticket <id>] [--mantis-url <url>] [--mantis-token <token>]
 *
 * Requiere wkhtmltopdf instalado en el PATH del sistema.
 * El archivo informe.html debe estar en el mismo directorio que este script.
 */

if (php_sapi_name() !== 'cli') {
    http_response_code(403);
    exit('Solo uso CLI.');
}

// ─── Args ──────────────────────────────────────────────────────────────────────
$opts = getopt('', ['json:', 'output:', 'ticket:', 'mantis-url:', 'mantis-token:']);

$json_path   = $opts['json']          ?? null;
$pdf_output  = $opts['output']        ?? null;
$ticket_id   = isset($opts['ticket']) ? (int) $opts['ticket'] : null;
$mantis_url  = rtrim($opts['mantis-url']   ?? (getenv('RC_MANTIS_URL')   ?: ''), '/');
$mantis_tok  = $opts['mantis-token']       ?? (getenv('RC_MANTIS_TOKEN') ?: '');

if (! $json_path) {
    fwrite(STDERR, "ERROR: --json <ruta> es obligatorio.\n");
    fwrite(STDERR, "Uso: php generate-report.php --json <ruta.json> [--output <informe.pdf>]\n");
    exit(1);
}

if (! is_readable($json_path)) {
    fwrite(STDERR, "ERROR: no se puede leer '$json_path'.\n");
    exit(1);
}

// ─── Leer y validar JSON ───────────────────────────────────────────────────────
$json_raw = file_get_contents($json_path);
$data     = json_decode($json_raw, true);

if (json_last_error() !== JSON_ERROR_NONE) {
    fwrite(STDERR, "ERROR: JSON inválido — " . json_last_error_msg() . "\n");
    exit(1);
}

if (empty($data['_meta']['plataforma']) || empty($data['_meta']['version'])) {
    fwrite(STDERR, "ERROR: JSON no cumple schema mínimo (_meta.plataforma + _meta.version ausentes).\n");
    exit(1);
}

// ─── Nombre de salida por defecto ─────────────────────────────────────────────
if (! $pdf_output) {
    $suffix      = $ticket_id ? "TICKET{$ticket_id}" : date('Ymd_His');
    $pdf_output  = dirname(__FILE__) . "/informe_{$suffix}.pdf";
}

// ─── Cargar plantilla HTML ────────────────────────────────────────────────────
$template_path = __DIR__ . '/informe.html';
if (! is_readable($template_path)) {
    fwrite(STDERR, "ERROR: plantilla no encontrada en '$template_path'.\n");
    exit(1);
}

$html = file_get_contents($template_path);

// El JSON vive en <script type="application/json">; hay que escapar </script>
// para evitar que el parser HTML lo interprete como cierre del tag.
$json_escaped = str_replace('</', '<\/', $json_raw);
$html = str_replace('__JSON_DATA__', $json_escaped, $html);

if (str_contains($html, '__JSON_DATA__')) {
    fwrite(STDERR, "ERROR: el placeholder __JSON_DATA__ no se encontró en la plantilla.\n");
    exit(1);
}

// ─── Guardar HTML temporal ────────────────────────────────────────────────────
$tmp_html = sys_get_temp_dir() . '/rc_report_' . uniqid() . '.html';
file_put_contents($tmp_html, $html);

// ─── Generar PDF con wkhtmltopdf ──────────────────────────────────────────────
$wk = trim((string) shell_exec('which wkhtmltopdf 2>/dev/null || where wkhtmltopdf 2>NUL'));
if (! $wk) {
    @unlink($tmp_html);
    fwrite(STDERR, "ERROR: wkhtmltopdf no encontrado en PATH.\n");
    fwrite(STDERR, "  Ubuntu: apt install wkhtmltopdf\n");
    fwrite(STDERR, "  Windows: https://wkhtmltopdf.org/downloads.html\n");
    exit(1);
}

$cmd = sprintf(
    '%s --quiet --page-size A4 --encoding UTF-8 --margin-top 10mm --margin-bottom 10mm --margin-left 10mm --margin-right 10mm --print-media-type --background --enable-local-file-access %s %s',
    escapeshellarg($wk),
    escapeshellarg($tmp_html),
    escapeshellarg($pdf_output)
);

$ret = null;
passthru($cmd, $ret);
@unlink($tmp_html);

if ($ret !== 0 || ! file_exists($pdf_output)) {
    fwrite(STDERR, "ERROR: wkhtmltopdf falló (código $ret).\n");
    exit(1);
}

$size_kb = round(filesize($pdf_output) / 1024, 1);
echo "[OK] PDF generado: $pdf_output ({$size_kb} KB)\n";

// ─── Adjuntar al ticket MantisBT (opcional) ───────────────────────────────────
if ($ticket_id && $mantis_url && $mantis_tok) {
    echo "[..] Adjuntando a ticket #$ticket_id en MantisBT...\n";

    $pdf_b64   = base64_encode(file_get_contents($pdf_output));
    $pdf_name  = basename($pdf_output);
    $payload   = json_encode(['files' => [['name' => $pdf_name, 'content' => $pdf_b64]]]);

    $ch = curl_init("{$mantis_url}/api/rest/issues/{$ticket_id}/files");
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS     => $payload,
        CURLOPT_HTTPHEADER     => [
            'Authorization: ' . $mantis_tok,
            'Content-Type: application/json',
        ],
        CURLOPT_TIMEOUT        => 30,
        CURLOPT_SSL_VERIFYPEER => true,
    ]);

    $resp = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err  = curl_error($ch);
    curl_close($ch);

    if ($err) {
        fwrite(STDERR, "[!] cURL error: $err\n");
    } elseif ($code >= 200 && $code < 300) {
        echo "[OK] PDF adjuntado al ticket #$ticket_id.\n";
    } else {
        fwrite(STDERR, "[!] MantisBT respondió HTTP $code: " . substr($resp, 0, 300) . "\n");
    }
} elseif ($ticket_id) {
    echo "[!] --ticket especificado pero faltan --mantis-url y/o --mantis-token. PDF no adjuntado.\n";
    echo "    Adjuntar manualmente o usar variables de entorno RC_MANTIS_URL / RC_MANTIS_TOKEN.\n";
}
