-- =============================================================================
-- ResolvCore — Migración 0001: tabla rc_vulnerabilities
--
-- Fuentes alimentadoras (en alguna fase del proyecto):
--   - NVD (NIST)        → https://nvd.nist.gov/
--   - CISA KEV          → https://www.cisa.gov/known-exploited-vulnerabilities-catalog
--   - OSV (Google)      → https://osv.dev/
--   - EPSS-FIRST        → https://www.first.org/epss/
--
-- Idempotente: usa CREATE TABLE IF NOT EXISTS / CREATE INDEX IF NOT EXISTS.
-- Compatible con MariaDB 10.4+ y MySQL 8.0+.
-- =============================================================================

CREATE TABLE IF NOT EXISTS rc_vulnerabilities (
    id              BIGINT UNSIGNED      NOT NULL AUTO_INCREMENT,
    cve_id          VARCHAR(32)          NOT NULL COMMENT 'Identificador CVE-YYYY-NNNNN',
    fuente          VARCHAR(16)          NOT NULL DEFAULT 'NVD' COMMENT 'NVD | KEV | OSV | EPSS',
    gravedad        ENUM('none','low','medium','high','critical') NOT NULL DEFAULT 'medium',
    cvss_score      DECIMAL(3,1)         DEFAULT NULL COMMENT '0.0-10.0',
    epss_score      DECIMAL(5,4)         DEFAULT NULL COMMENT '0.0000-1.0000 prob. de explotación',
    kev_listed      TINYINT(1)           NOT NULL DEFAULT 0 COMMENT '1 si aparece en CISA KEV',
    so_afectado     VARCHAR(64)          NOT NULL COMMENT 'windows | linux | macos | android | cross | <vendor>',
    producto        VARCHAR(128)         DEFAULT NULL COMMENT 'p.ej. openssl, kernel, chrome',
    version_rango   VARCHAR(255)         DEFAULT NULL COMMENT 'CPE/expresión de versiones afectadas',
    titulo          VARCHAR(255)         NOT NULL,
    descripcion     TEXT                 NOT NULL,
    fix             TEXT                 DEFAULT NULL COMMENT 'Mitigación o versión que corrige',
    referencias     TEXT                 DEFAULT NULL COMMENT 'URLs separadas por salto de línea',
    publicado_en    DATETIME             DEFAULT NULL,
    actualizado_en  DATETIME             DEFAULT NULL,
    fecha_sync      DATETIME             NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Última sincronización con la fuente',
    creado_en       DATETIME             NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_cve_id (cve_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX IF NOT EXISTS idx_rc_vuln_so          ON rc_vulnerabilities (so_afectado);
CREATE INDEX IF NOT EXISTS idx_rc_vuln_gravedad    ON rc_vulnerabilities (gravedad);
CREATE INDEX IF NOT EXISTS idx_rc_vuln_kev         ON rc_vulnerabilities (kev_listed);
CREATE INDEX IF NOT EXISTS idx_rc_vuln_fecha_sync  ON rc_vulnerabilities (fecha_sync);
CREATE INDEX IF NOT EXISTS idx_rc_vuln_producto    ON rc_vulnerabilities (producto);

-- =============================================================================
-- Tabla auxiliar de runs de sincronización (audit trail).
-- =============================================================================

CREATE TABLE IF NOT EXISTS rc_vulnerabilities_sync (
    id              BIGINT UNSIGNED      NOT NULL AUTO_INCREMENT,
    fuente          VARCHAR(16)          NOT NULL,
    iniciado_en     DATETIME             NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finalizado_en   DATETIME             DEFAULT NULL,
    items_nuevos    INT UNSIGNED         NOT NULL DEFAULT 0,
    items_actualizados INT UNSIGNED      NOT NULL DEFAULT 0,
    estado          ENUM('ok','parcial','fallo') NOT NULL DEFAULT 'ok',
    detalle         TEXT                 DEFAULT NULL COMMENT 'Mensaje de error o resumen',
    PRIMARY KEY (id),
    KEY idx_rc_sync_fuente (fuente, iniciado_en)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
