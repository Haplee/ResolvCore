#!/usr/bin/env bash
# ============================================================
# ResolveCore — MantisBT Plugin Installer
# Uso: bash mantisbt/plugins/install.sh /var/www/mantis
# ============================================================
set -euo pipefail

MANTIS_DIR="${1:-/var/www/mantis}"
PLUGINS_DIR="${MANTIS_DIR}/plugins"

if [ ! -d "$MANTIS_DIR" ]; then
    echo "AVISO: MantisBT no encontrado en $MANTIS_DIR"
    echo "       Creando directorio para descarga previa de plugins..."
    mkdir -p "$PLUGINS_DIR"
fi

echo "==> Instalando plugins ResolveCore en $PLUGINS_DIR"
mkdir -p "$PLUGINS_DIR"

# ── source-integration ───────────────────────────────────────
echo "  [1/6] source-integration (GitHub/GitLab VCS)"
if [ ! -d "$PLUGINS_DIR/Source" ]; then
    git clone --depth 1 \
        https://github.com/mantisbt-plugins/source-integration.git \
        "$PLUGINS_DIR/_source-integration-tmp"
    mv "$PLUGINS_DIR/_source-integration-tmp/Source"      "$PLUGINS_DIR/Source"
    mv "$PLUGINS_DIR/_source-integration-tmp/SourceGithub" "$PLUGINS_DIR/SourceGithub" 2>/dev/null || true
    mv "$PLUGINS_DIR/_source-integration-tmp/SourceGitlab" "$PLUGINS_DIR/SourceGitlab" 2>/dev/null || true
    rm -rf "$PLUGINS_DIR/_source-integration-tmp"
    echo "     OK — activar: Gestionar → Plugins → Source Integration + SourceGithub"
else
    echo "     SKIP (ya instalado)"
fi

# ── MantisKanban ─────────────────────────────────────────────
echo "  [2/6] MantisKanban (tablero Kanban)"
if [ ! -d "$PLUGINS_DIR/MantisKanban" ]; then
    git clone --depth 1 \
        https://github.com/mantisbt-plugins/MantisKanban.git \
        "$PLUGINS_DIR/MantisKanban"
    echo "     OK — activar: Gestionar → Plugins → MantisKanban"
else
    echo "     SKIP (ya instalado)"
fi

# ── SetDuedate ───────────────────────────────────────────────
echo "  [3/6] SetDuedate (SLA automático)"
if [ ! -d "$PLUGINS_DIR/SetDuedate" ]; then
    git clone --depth 1 \
        https://github.com/mantisbt-plugins/SetDuedate.git \
        "$PLUGINS_DIR/SetDuedate"
    echo "     OK — activar: Gestionar → Plugins → SetDuedate"
else
    echo "     SKIP (ya instalado)"
fi

# ── Reminder ─────────────────────────────────────────────────
echo "  [4/6] Reminder (avisos de tickets sin atender)"
if [ ! -d "$PLUGINS_DIR/Reminder" ]; then
    git clone --depth 1 \
        https://github.com/mantisbt-plugins/Reminder.git \
        "$PLUGINS_DIR/Reminder"
    echo "     OK — activar: Gestionar → Plugins → Reminder"
else
    echo "     SKIP (ya instalado)"
fi

# ── mailtemplate ─────────────────────────────────────────────
echo "  [5/6] mailtemplate (emails HTML con branding)"
if [ ! -d "$PLUGINS_DIR/mailtemplate" ]; then
    git clone --depth 1 \
        https://github.com/mantisbt-plugins/mailtemplate.git \
        "$PLUGINS_DIR/mailtemplate"
    echo "     OK — activar: Gestionar → Plugins → Mail Template"
else
    echo "     SKIP (ya instalado)"
fi

# ── EventLog ─────────────────────────────────────────────────
echo "  [6/6] EventLog (auditoría de eventos)"
if [ ! -d "$PLUGINS_DIR/EventLog" ]; then
    git clone --depth 1 \
        https://github.com/mantisbt-plugins/EventLog.git \
        "$PLUGINS_DIR/EventLog"
    echo "     OK — activar: Gestionar → Plugins → EventLog"
else
    echo "     SKIP (ya instalado)"
fi

# ── Copiar configs personalizadas ─────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "==> Aplicando configuraciones ResolveCore..."

for plugin_conf_dir in "$SCRIPT_DIR"/*/; do
    plugin_name=$(basename "$plugin_conf_dir")
    target="$PLUGINS_DIR/$plugin_name"
    if [ -d "$target" ] && [ -f "$plugin_conf_dir/config.php" ]; then
        cp "$plugin_conf_dir/config.php" "$target/config.php"
        echo "     config.php → $target"
    fi
done

echo ""
echo "==> Hecho. Próximos pasos:"
echo "    1. Ir a MantisBT → Gestionar → Plugins"
echo "    2. Activar: Source, SourceGithub, MantisKanban, SetDuedate, Reminder, mailtemplate, EventLog"
echo "    3. Configurar source-integration: Gestionar → Repositorios → Añadir GitHub"
echo "    4. Añadir webhook en GitHub repo → Settings → Webhooks"
echo "       URL: https://tudominio.com/mantis/plugin.php?page=Source/checkin"
