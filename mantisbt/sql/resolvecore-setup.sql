-- ============================================================
-- MantisBT — ResolveCore initial setup
-- Ejecutar DESPUÉS de la instalación web de MantisBT.
-- Ajusta el prefijo de tablas si lo cambiaste en la instalación.
-- ============================================================

-- Proyecto principal ResolveCore
-- Nota: MantisBT gestiona proyectos vía UI o API.
-- Este script configura categorías y campos personalizados vía SQL directo.
-- En producción, preferir la UI de MantisBT para el proyecto.

-- ── Categorías del proyecto ──────────────────────────────────
-- Insertar en el proyecto con id = 1 (ajustar si es distinto)
INSERT IGNORE INTO mantis_category_table (project_id, user_id, name, status)
VALUES
  (1, 1, 'Soporte técnico', 10),
  (1, 1, 'Bug',             10),
  (1, 1, 'Colaboración',    10),
  (1, 1, 'Licencia',        10),
  (1, 1, 'General',         10);

-- ── Versión inicial ──────────────────────────────────────────
INSERT IGNORE INTO mantis_project_version_table (project_id, version, date_order, description, released, obsolete)
VALUES (1, 'v1.0.0', NOW(), 'Lanzamiento inicial ResolveCore', 1, 0);

-- ── Campo personalizado: Plataforma ─────────────────────────
INSERT IGNORE INTO mantis_custom_field_table
  (name, type, possible_values, default_value, valid_regexp,
   access_level_r, access_level_rw, length_min, length_max,
   filter_by, display_report, display_update, display_resolved,
   display_closed, require_report, require_update, require_resolved, require_closed)
VALUES
  ('Plataforma', 6 /* lista */, 'Windows|Linux|macOS|Android|Otro', 'Windows', '',
   10, 55, 0, 0,
   1, 1, 1, 1,
   1, 0, 0, 0, 0);

-- Asignar campo personalizado al proyecto 1
SET @field_id = (SELECT id FROM mantis_custom_field_table WHERE name = 'Plataforma' LIMIT 1);
INSERT IGNORE INTO mantis_custom_field_project_table (field_id, project_id, sequence)
VALUES (@field_id, 1, 10);

-- ── Campo personalizado: AnyDesk ID ─────────────────────────
INSERT IGNORE INTO mantis_custom_field_table
  (name, type, possible_values, default_value, valid_regexp,
   access_level_r, access_level_rw, length_min, length_max,
   filter_by, display_report, display_update, display_resolved,
   display_closed, require_report, require_update, require_resolved, require_closed)
VALUES
  ('AnyDesk ID', 0 /* texto */, '', '', '^[0-9 ]{0,15}$',
   10, 55, 0, 15,
   0, 0, 1, 0,
   0, 0, 0, 0, 0);

SET @anydesk_field_id = (SELECT id FROM mantis_custom_field_table WHERE name = 'AnyDesk ID' LIMIT 1);
INSERT IGNORE INTO mantis_custom_field_project_table (field_id, project_id, sequence)
VALUES (@anydesk_field_id, 1, 20);
