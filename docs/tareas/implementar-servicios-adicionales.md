# Tarea: Implementar los scripts de servicios adicionales

> **Prompt de tarea diferida.** Redactado el 2026-05-22 — ejecutar otro día.
> Para lanzarlo: abre tu agente de IA en la raíz del repo y di:
> *"Implementa la tarea descrita en `docs/tareas/implementar-servicios-adicionales.md`."*

---

## 1. Contexto

ResolveCore amplía su catálogo de servicios con tres servicios nuevos. La
justificación técnica (herramientas, comparativas, procedimientos, precios) ya
está escrita en [`servicios-adicionales.md`](../tecnica/servicios-adicionales.md).
Lo que falta es la **capa de scripts** que ejecuta cada servicio.

El scaffolding ya existe: `scripts/servicios/` contiene 5 stubs no implementados,
cada uno con su contrato documentado en la cabecera (`.SYNOPSIS` / banner,
parámetros, exit codes) y un bloque `TODO(otro-dia)` con los pasos.

Esta tarea consiste en **implementar la lógica de esos 5 stubs**.

Servicios:

1. **Congelación de sistemas** — estado de referencia restaurable tras reinicio.
2. **Clonación de sistemas** — registro y verificación de integridad de imágenes.
3. **Kit de implantación en cliente** — paquete de acceso remoto para suscriptores.

**Alcance: solo scripts.** No tocar WordPress ni MantisBT en esta tarea
(decisión del 2026-05-22).

## 2. Ficheros a implementar

| Fichero | Servicio | Plataforma |
|---------|----------|------------|
| `scripts/servicios/congelacion/congelacion-windows.ps1` | Congelación | Windows |
| `scripts/servicios/congelacion/congelacion-linux.sh`    | Congelación | Linux |
| `scripts/servicios/clonacion/registrar-imagen.sh`       | Clonación   | Multiplataforma |
| `scripts/servicios/clonacion/verificar-imagen.sh`       | Clonación   | Multiplataforma |
| `scripts/servicios/kit/construir-kit.ps1`               | Kit         | Windows |

Cada stub ya tiene el contrato en cabecera. **Respétalo** — si necesitas
cambiarlo, actualiza también la cabecera.

## 3. Especificación por servicio

### 3.1 Congelación de sistemas

Referencia: `servicios-adicionales.md` §1.

**`congelacion-windows.ps1`** — herramientas: Reboot Restore Rx (default, gratis,
perfil PYME) y Deep Freeze (comercial, aulas/quioscos). Acciones:

- `Status` — detectar herramienta instalada y si el equipo está congelado.
- `Configure` — verificar/instalar herramienta; definir la partición de datos
  excluida de la congelación; fijar el estado de referencia.
- `Freeze` / `Thaw` — activar/desactivar la congelación. **Requieren `-Confirm`.**
- Salida: `[PSCustomObject]` estructurado.

**`congelacion-linux.sh`** — mecanismo: BTRFS + snapper sobre Ubuntu 22.04 LTS.
Acciones:

- `status` — configs de snapper, último snapshot, subvolumen.
- `configure` — crear config snapper, fijar retención, verificar la entrada de
  rollback en GRUB.
- `snapshot` — crear snapshot etiquetado del estado de referencia.
- `rollback` — `snapper rollback`. **Requiere `--confirm`** (descarta el estado
  actual).
- Salida: JSON por stdout, esquema propio del servicio.

### 3.2 Clonación de sistemas

Referencia: `servicios-adicionales.md` §2. ResolveCore **no** automatiza
Clonezilla (es un Live USB); aporta trazabilidad sobre las imágenes generadas.

**`registrar-imagen.sh`** — da de alta una imagen en un manifiesto JSON
(`imagenes-manifest.json`): `id`, `equipo`, `so`, `estado`, `ruta`, `hash`
SHA256, `fecha_registro`.

**`verificar-imagen.sh`** — recalcula el hash de una imagen y lo compara con el
del manifiesto. `exit 0` íntegra · `exit 1` corrupta · `exit 2` no encontrada.

### 3.3 Kit de implantación en cliente

Referencia: `servicios-adicionales.md` §3.

**`construir-kit.ps1`** — empaqueta `resolvecore-kit/` y `resolvecore-kit.zip`:

```
resolvecore-kit/
├── anydesk-portable.exe
├── README-cliente.pdf
└── scripts/
    ├── diagnostico-windows.ps1
    └── diagnostico-linux.sh
```

Copia AnyDesk portable, copia los scripts de diagnóstico existentes
(`scripts/windows/diagnostico.ps1`, `scripts/linux/diagnostico.sh`), genera un
`README-cliente.pdf` de una página y comprime con `Compress-Archive`.

## 4. Convenciones obligatorias (de `.claude/CLAUDE.md`)

- **PowerShell**: `#Requires -Version 5.1` (sin espacio entre `#` y `Requires`).
  `try/catch` para errores. Salida como `[PSCustomObject]`.
- **Bash**: `#!/usr/bin/env bash`. `set -uo pipefail` (NO añadir `-e`: rompe la
  captura granular comando a comando — ver `auditoria-mejoras.md` S3). Variables
  `UPPER_CASE`, funciones `snake_case`. `command -v <tool> || exit N` al inicio.
- **JSON en Bash**: ensamblar con `jq -n --argjson`, nunca por concatenación de
  strings (regresión 2026-05-09).
- **Acciones destructivas** (`Freeze`/`Thaw`, `rollback`): exigir el flag de
  confirmación explícito. Sin el flag → exit code de "falta confirmación".
- **No** deshabilitar el servicio de cola de impresión (Spooler) en ninguna
  operación: es crítico para el usuario final.
- No usar IPs, MACs ni emails reales en ejemplos: usar fixtures ficticios.

## 5. Definición de "hecho"

- [ ] Los 5 scripts implementados, sustituyendo el bloque `TODO(otro-dia)`.
- [ ] Cada script probado en su plataforma (o documentado por qué no se pudo).
- [ ] `-Help` / `--help` funcionan en cada script.
- [ ] `scripts/servicios/README.md` actualizado: estado `Scaffolding` →
      `Implementado`.
- [ ] Si algún script consolida un esquema JSON propio, documentarlo. NO es el
      esquema de diagnóstico — no tocar `docs/scripting/schema-diagnostico.md`.
- [ ] `docs/defensa/defensa-tfg.md` actualizado + su changelog: los tres
      servicios pasan de "documentados" a "operativos con script".
- [ ] Trabajo en una rama `feat/servicios-adicionales` — nunca commit directo a
      `main`.

## 6. Lo que NO se debe hacer

- No tocar WordPress ni MantisBT (fuera de alcance — decidido el 2026-05-22).
- No commit directo a `main`.
- No instalar dependencias globales sin avisar.
- No ejecutar operaciones destructivas reales (`rollback`, `Thaw`) durante las
  pruebas salvo en un entorno aislado.

---

*Redactado el 2026-05-22. Scaffolding asociado: `scripts/servicios/`.*
