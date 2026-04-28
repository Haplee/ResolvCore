# ResolveCore — Investigación Técnica

> Última actualización: 25 abril 2026  
> Proyecto Integrado ASIR 2026 — Francisco Vidal Mateo

---

## 1. Fuentes de vulnerabilidades CVE

### 1.1 Panorama de fuentes disponibles

El mercado de bases de datos de vulnerabilidades tiene varias opciones con diferencias relevantes:

| Fuente | API pública | Auth requerida | Latencia | Cobertura | Notas |
|--------|-------------|----------------|----------|-----------|-------|
| **NVD/NIST** | ✅ REST v2.0 | API key opcional (50 req/30s sin key, 50 req/30s con key pero más estable) | Media | Completa, estándar | Fuente oficial. A veces tiene retrasos de enriquecimiento post-publicación |
| **MITRE CVE** | ✅ JSON feeds | No | — | IDs originales | Solo identificadores, sin CVSS. Útil como índice |
| **CIRCL CVE** | ✅ REST | No | Baja | NVD + EPSS | Gratuita, sin auth, devuelve EPSS score. Ideal para enriquecer |
| **VulnCheck NVD++** | ✅ REST | Token (plan free generoso) | Baja | NVD + extras | Más rápido que NVD, menos downtime. Buen fallback |
| **CISA KEV** | ✅ JSON estático | No | — | ~1000 CVEs activos | Lista de exploits confirmados en producción real. Crítico para priorización |
| **EPSS (FIRST)** | ✅ CSV/API | No | — | Todos los CVEs activos | Probabilidad de explotación en 30 días (0.0–1.0). Complementa CVSS |
| **CVE Details** | UI solo | — | — | Amplia | Sin API cómoda. Descartada para integración |
| **OpenVAS/Greenbone** | ✅ REST | Sí | Alta | Amplia | Escáner activo, paradigma distinto al del proyecto. Descartado |

### 1.2 Arquitectura CVE elegida

Se implementa motor en tres capas con lógica de priorización combinada:

```
NVD/NIST → fuente primaria (nombre de software → lista CVEs con CVSS)
  ↓
CIRCL CVE → enriquece con EPSS score (probabilidad de explotación 0.0–1.0)
  ↓
CISA KEV  → verifica si el CVE está en la lista de explotación confirmada
```

**Justificación de la arquitectura por capas:**

- Solo NVD no es suficiente: CVSS alto (≥9.0) no implica explotación activa. Un CVE 9.8 sin exploit conocido es menos urgente que un CVE 7.5 que ya se explota en producción.
- EPSS cubre la brecha: la probabilidad de explotación en 30 días es el mejor predictor de urgencia real según investigación de FIRST.
- CISA KEV es la señal más fuerte: el gobierno estadounidense publica esta lista con plazos de parcheo para agencias federales. Si está en KEV, hay explotación activa confirmada.

### 1.3 Lógica de priorización resultante

```
CVSS ≥ 9.0  AND  KEV = true              →  CRÍTICO   (parchear < 24h)
CVSS ≥ 7.0  AND  EPSS ≥ 0.5             →  ALTO      (parchear esta semana)
CVSS ≥ 7.0  AND  EPSS < 0.5             →  MEDIO     (monitorizar)
CVSS < 7.0  AND  KEV = false            →  BAJO      (informativo)
```

### 1.4 Rate limiting y caché

**Problema:** NVD limita a 50 peticiones cada 30 segundos por IP. Un diagnóstico con 50 paquetes de software genera 50 búsquedas → posible bloqueo.

**Solución implementada en `nvdApi.ts`:**
- Búsquedas por nombre de aplicación, no por CVE-ID individual
- Límite de resultados por query (`maxResults`)
- Pendiente: caché en Supabase Storage con TTL de 6 horas para resultados recurrentes

**CISA KEV como JSON cacheado:**
- La lista KEV se descarga una vez y se cachea en Supabase Storage
- Actualización programada (Edge Function con cron)
- Comprobación local sin llamada a red para cada CVE

### 1.5 VulnCheck como fallback

VulnCheck NVD++ ofrece la misma estructura de datos que NVD pero con mayor disponibilidad y menos downtime. Plan gratuito incluye ~1000 búsquedas/mes. Se activa automáticamente si NVD responde con error 503 o timeout > 5s.

---

## 2. Datos S.M.A.R.T. y diagnóstico de disco

### 2.1 Qué es S.M.A.R.T.

Self-Monitoring, Analysis and Reporting Technology — sistema de monitorización integrado en discos HDD y SSD. Cada disco expone atributos con valores numéricos. Los críticos para detectar fallos inminentes son:

| Atributo ID | Nombre | Descripción | Umbral crítico |
|------------|--------|-------------|----------------|
| 05 | Reallocated_Sector_Ct | Sectores con errores físicos reasignados a reserva | > 0 = alerta, > 10 = crítico |
| 0C | Power_Cycle_Count | Arranques totales del disco | Comparar con Power_On_Hours |
| C5 | Current_Pending_Sector | Sectores candidatos a reasignación | > 0 = alerta |
| C6 | Offline_Uncorrectable | Errores no corregibles durante test offline | > 0 = crítico |
| C7 | UDMA_CRC_Error_Count | Errores de cable/interfaz SATA | > 100 = revisar cable |
| C2 | Temperature_Celsius | Temperatura actual del disco | HDD > 50°C, SSD > 70°C |
| 09 | Power_On_Hours | Horas totales de uso acumulado | HDD > 25.000h, SSD > 40.000h |
| F1/F2 | Total LBAs Written | TBW (Total Bytes Written) en SSD | Comparar con spec del fabricante |

### 2.2 Lectura en Linux

```bash
# Requiere: smartmontools (apt install smartmontools)
# Necesita privilegios root o grupo 'disk'
smartctl -A /dev/sda
```

Parsing de atributos clave con awk:
```bash
reallocated=$(smartctl -A /dev/$dev 2>/dev/null | awk '/Reallocated_Sector_Ct/ {print $10}')
pending=$(smartctl -A /dev/$dev 2>/dev/null | awk '/Current_Pending_Sector/ {print $10}')
uncorrectable=$(smartctl -A /dev/$dev 2>/dev/null | awk '/Offline_Uncorrectable/ {print $10}')
hours=$(smartctl -A /dev/$dev 2>/dev/null | awk '/Power_On_Hours/ {print $10}')
temp=$(smartctl -A /dev/$dev 2>/dev/null | awk '/Temperature_Celsius/ {print $10}')
```

Para NVMe (no tiene atributos S.M.A.R.T. estándar, usa `nvme-cli`):
```bash
nvme smart-log /dev/nvme0 | grep -E "temperature|unsafe_shutdowns|media_errors|power_on_hours"
```

### 2.3 Lectura en Windows

Windows no expone S.M.A.R.T. completo vía WMI estándar. Opciones:

**Opción A — `Get-PhysicalDisk` (Hyper-V Storage Management):**
```powershell
Get-PhysicalDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus, MediaType
```
Solo da estado general (Healthy/Warning/Unhealthy), no atributos individuales.

**Opción B — `Get-StorageReliabilityCounter` (requiere Windows 10/11 + drivers):**
```powershell
Get-PhysicalDisk | Get-StorageReliabilityCounter | Select-Object `
  Temperature, ReadErrorsTotal, WriteErrorsTotal, PowerOnHours, Wear
```
`Wear` es porcentaje de desgaste SSD (0–100). No siempre disponible en drivers genéricos.

**Opción C — `wmic` (heredado pero universal):**
```powershell
$smart = Get-CimInstance -Namespace root/wmi -ClassName MSStorageDriver_ATAPISmartData
```
Devuelve bytes raw del S.M.A.R.T. — requiere parsing manual de offsets.

**Decisión:** Script usa opción B como primaria, fallback a opción A. Registra en JSON como `smart_detallado: null` si el driver no lo soporta, para que el frontend lo muestre como "no disponible" y no como error.

### 2.4 JSON de salida extendido (propuesta semana 5)

```json
{
  "disco_principal": {
    "modelo": "Samsung SSD 870 EVO 500GB",
    "tipo": "SSD",
    "capacidad_gb": 500,
    "smart_status": "OK",
    "smart_detallado": {
      "reallocated_sectors": 0,
      "pending_sectors": 0,
      "uncorrectable_errors": 0,
      "temperatura_c": 32,
      "horas_encendido": 8741,
      "ciclos_arranque": 1203,
      "desgaste_pct": 12
    }
  },
  "bateria": {
    "presente": true,
    "carga_pct": 87,
    "estado": "Discharging",
    "capacidad_diseno_mwh": 45000,
    "capacidad_actual_mwh": 38250,
    "desgaste_pct": 15,
    "ciclos": 287
  }
}
```

---

## 3. Motor de proyección de vida útil

### 3.1 Enfoque elegido: regresión lineal simple

El motor en `proyeccionVidaUtil.ts` usa regresión lineal sobre el histórico de `puntuacion_salud` (0–100) por dispositivo.

**Por qué regresión lineal:**
- Interpretable: pendiente = puntos que pierde el equipo por mes
- Computacionalmente trivial en cliente
- R² (coeficiente de determinación) permite medir la confianza del modelo
- Suficiente para un TFG: modelos más complejos (LSTM, Weibull) requieren más datos y son menos explicables ante un tribunal

**Limitaciones conocidas:**
- Asume degradación lineal. La realidad es más compleja (curva de bañera: fallo temprano → vida útil → desgaste final)
- Necesita mínimo 3 puntos de datos. Con 2 o menos, muestra "datos insuficientes"
- Sensible a outliers (diagnóstico anormalmente bajo por problema temporal)

**Mejora potencial v2:** ponderar los puntos más recientes con mayor peso (weighted least squares), reduciendo el impacto de diagnósticos antiguos.

### 3.2 Cálculo del EOL

```
EOL = punto donde puntuacion_salud = 35

Si la recta de regresión es: score(t) = slope * t + intercept
Entonces: t_EOL = (35 - intercept) / slope
Meses restantes = t_EOL - t_ahora
```

`EOL_THRESHOLD = 35` elegido porque:
- Por debajo de 35, el equipo falla en al menos 2 categorías simultáneamente
- Coincide con zona "roja" del gauge visual del dashboard
- Reemplazable en `proyeccionVidaUtil.ts` sin cambios en el resto del código

### 3.3 Estados del motor

| Estado | Criterio | Acción recomendada |
|--------|----------|--------------------|
| `insuficiente` | < 3 diagnósticos | Añadir más diagnósticos |
| `mejorando` | slope ≥ 0 | Sin acción necesaria |
| `estable` | −0.5 < slope < 0 | Revisión rutinaria |
| `declive_leve` | slope ≤ −0.5 | Seguimiento mensual |
| `declive_critico` | slope < −2 | Valorar sustitución de componentes |

### 3.4 Integración con S.M.A.R.T. (semana 5)

El motor actual usa solo `puntuacion_salud` global. Con datos S.M.A.R.T. se puede añadir:

- **Proyección de disco** basada en tendencia de sectores reubicados (crece → fallo inminente)
- **Proyección de batería** basada en `desgaste_pct` acumulado
- Cada componente tiene su propia proyección independiente en la UI

---

## 4. Sistema de alertas

### 4.1 Diseño del trigger en Supabase

Función PL/pgSQL llamada por trigger `AFTER INSERT ON diagnosticos`:

```sql
CREATE OR REPLACE FUNCTION crear_alertas_diagnostico()
RETURNS TRIGGER AS $$
DECLARE
  v_dispositivo_id UUID;
  v_cliente_id UUID;
BEGIN
  -- Obtener cliente del dispositivo
  SELECT cliente_id INTO v_cliente_id
  FROM dispositivos WHERE id = NEW.dispositivo_id;

  -- Salud crítica
  IF NEW.puntuacion_salud < 40 THEN
    INSERT INTO alertas (dispositivo_id, cliente_id, tipo, nivel, mensaje)
    VALUES (
      NEW.dispositivo_id, v_cliente_id,
      'salud_critica', 'critical',
      format('Puntuación de salud crítica: %s/100. El equipo necesita revisión inmediata.', NEW.puntuacion_salud)
    )
    ON CONFLICT DO NOTHING;
  END IF;

  -- Hardware degradado
  IF NEW.puntuacion_hardware < 35 THEN
    INSERT INTO alertas (dispositivo_id, cliente_id, tipo, nivel, mensaje)
    VALUES (
      NEW.dispositivo_id, v_cliente_id,
      'hardware_degradado', 'critical',
      format('Hardware degradado: puntuación %s/100. Posible fallo inminente de componente.', NEW.puntuacion_hardware)
    )
    ON CONFLICT DO NOTHING;
  END IF;

  -- Seguridad baja
  IF NEW.puntuacion_seguridad < 50 THEN
    INSERT INTO alertas (dispositivo_id, cliente_id, tipo, nivel, mensaje)
    VALUES (
      NEW.dispositivo_id, v_cliente_id,
      'seguridad_baja', 'warning',
      format('Seguridad por debajo del umbral: %s/100. Revisar antivirus, firewall y actualizaciones.', NEW.puntuacion_seguridad)
    )
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_alertas_diagnostico
  AFTER INSERT ON diagnosticos
  FOR EACH ROW EXECUTE FUNCTION crear_alertas_diagnostico();
```

### 4.2 Alertas S.M.A.R.T. (semana 5)

Cuando el JSON de diagnóstico incluya datos S.M.A.R.T. detallados, la función extrae y evalúa:

```sql
-- Dentro de la función, tras recibir NEW.json_raw
DECLARE smart_data JSONB;
BEGIN
  smart_data := NEW.json_raw -> 'disco_principal' -> 'smart_detallado';

  IF (smart_data ->> 'reallocated_sectors')::int > 0 THEN
    INSERT INTO alertas (..., tipo, nivel, mensaje)
    VALUES (..., 'smart_sectores', 'critical',
      format('Disco con %s sectores reubicados. Riesgo de pérdida de datos. Hacer backup urgente.',
        smart_data ->> 'reallocated_sectors'));
  END IF;

  IF (smart_data ->> 'uncorrectable_errors')::int > 0 THEN
    -- alerta crítica
  END IF;

  IF (smart_data ->> 'desgaste_pct')::int > 80 THEN
    -- alerta batería
  END IF;
END;
```

### 4.3 Componente AlertasPanel

Propuesta de estructura para `src/components/client/AlertasPanel.tsx`:

```tsx
interface Alerta {
  id: string
  tipo: string
  nivel: 'critical' | 'warning' | 'info'
  mensaje: string
  visto: boolean
  created_at: string
  dispositivos: { marca: string | null; modelo: string | null }
}
```

- Subscription Realtime a `alertas` filtrada por `cliente_id = auth.uid()`
- Badge numérico en header del Dashboard del cliente (alertas `visto = false`)
- Colores: rojo (`critical`), amarillo (`warning`), azul (`info`)
- Acción "Marcar como vista" → `UPDATE alertas SET visto = true WHERE id = ?`

---

## 5. Emails transaccionales

### 5.1 Proveedor elegido: Resend

**Comparativa rápida:**

| Proveedor | Plan free | Dominio propio | Edge Function support | SDK |
|-----------|-----------|----------------|----------------------|-----|
| **Resend** | 3.000/mes | Sí | ✅ Nativo | `resend` npm |
| SendGrid | 100/día | Sí | Posible | `@sendgrid/mail` |
| Postmark | 100/mes | Sí | Posible | `postmark` |
| Brevo | 300/día | Sí | Posible | REST |

Resend elegido por integración nativa con Supabase Edge Functions, SDK moderno y React Email support.

### 5.2 Eventos que disparan email

| Evento | Destinatario | Contenido |
|--------|-------------|-----------|
| Cita confirmada | Cliente | Fecha, técnico, servicio, botón de cancelación |
| Recordatorio 24h | Cliente | Recordatorio con detalles de la cita |
| Intervención cerrada | Cliente | Enlace firmado al PDF (válido 7 días) |
| Alerta crítica | Cliente | Descripción del problema + acción recomendada |

### 5.3 Edge Function: `send-email`

```typescript
// supabase/functions/send-email/index.ts
import { Resend } from 'resend'

const resend = new Resend(Deno.env.get('RESEND_API_KEY'))

Deno.serve(async (req) => {
  const { type, to, data } = await req.json()
  // type: 'cita_confirmada' | 'recordatorio' | 'intervencion_cerrada' | 'alerta_critica'
  // Selecciona template y envía
})
```

Invocada desde triggers de base de datos vía `pg_net` o desde Vercel Functions tras acciones del usuario.

---

## 6. Roles y seguridad

### 6.1 Problema actual del sistema de roles

El rol se determina comprobando si existe fila en `tecnicos` para el `user_id`:

```typescript
// authStore.ts
const { data: tecnico } = await supabase
  .from('tecnicos').select('id').eq('user_id', user.id).single()
setRole(tecnico ? 'tecnico' : 'cliente')
```

**Problema:** si alguien inserta una fila en `tecnicos` (por seed erróneo, migración incorrecta o escalada de privilegios), obtiene acceso al panel técnico.

### 6.2 Solución: rol en `app_metadata`

`app_metadata` en Supabase Auth solo puede ser escrito por el servidor con `service_role`. El cliente con `anon key` no puede modificarlo.

```sql
-- Al registrar un nuevo técnico (solo desde panel admin o Edge Function con service_role):
UPDATE auth.users
SET raw_app_meta_data = raw_app_meta_data || '{"role": "tecnico"}'::jsonb
WHERE id = '<user_id>';
```

Lectura en cliente:
```typescript
const role = user.app_metadata?.role ?? 'cliente'
```

Validación en RLS:
```sql
-- Política que usa app_metadata en lugar de JOIN a tabla tecnicos
CREATE POLICY "tecnicos_only" ON notas_internas
  FOR ALL USING (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'tecnico'
  );
```

---

## 7. Testing

### 7.1 Estrategia para proyecto ASIR

Con las semanas disponibles, la prioridad es cobertura de lógica de negocio crítica, no cobertura total.

**Tests obligatorios antes de la defensa:**

| Suite | Framework | Qué testea |
|-------|-----------|-----------|
| Motor CVE | Vitest | `severityColor()`, clasificación CVSS, parsing respuesta NVD |
| Proyección vida útil | Vitest | `calcularProyeccion()` con datasets conocidos, EOL matemático |
| Validación JSON script | Vitest | Schema del JSON de diagnóstico, campos obligatorios |
| Generación PDF | Vitest | Que `generateIntervencionPDF()` retorna Blob sin errores |

**Tests de integración (si hay tiempo):**

| Suite | Framework | Qué testea |
|-------|-----------|-----------|
| Flujo cita completo | Playwright | Cliente reserva → técnico confirma → cierra → PDF generado |
| Auth + roles | Playwright | Cliente no accede a rutas de técnico y viceversa |

### 7.2 Configuración Vitest

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import path from 'path'

export default defineConfig({
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
    coverage: {
      reporter: ['text', 'lcov'],
      include: ['src/lib/**', 'src/components/technician/CVESearchPanel.tsx'],
    },
  },
  resolve: {
    alias: { '@': path.resolve(__dirname, 'src') },
  },
})
```

---

## 8. Stack tecnológico: justificación de decisiones

### 8.1 React 19 + TypeScript

- React 19: Server Components, improved Suspense, useOptimistic para actualizaciones optimistas (checklist)
- TypeScript: tipos generados desde el schema de Supabase — si la BD cambia y los tipos no se regeneran, el compilador lo detecta antes del deploy

### 8.2 Supabase vs alternativas

| Criterio | Supabase | Firebase | PlanetScale | Neon |
|----------|----------|----------|-------------|------|
| PostgreSQL nativo | ✅ | ❌ (NoSQL) | ✅ | ✅ |
| RLS integrado | ✅ | Parcial | ❌ | ❌ |
| Auth incluido | ✅ | ✅ | ❌ | ❌ |
| Realtime | ✅ WebSockets | ✅ | ❌ | ❌ |
| Storage | ✅ | ✅ | ❌ | ❌ |
| Edge Functions | ✅ Deno | ✅ Cloud Functions | ❌ | ❌ |
| Plan free | Generoso | Generoso | Limitado | Generoso |

Supabase elegido por PostgreSQL (triggers, funciones PL/pgSQL, vistas analíticas) + RLS nativo + Realtime en el mismo producto. Para un TFG que demuestra conocimientos de BD relacionales, PostgreSQL con triggers y RLS tiene más valor académico que un modelo NoSQL.

### 8.3 Vercel + GitHub Actions

- Vercel: deploy automático en cada push a `main`, preview por PR, funciones serverless sin configuración
- GitHub Actions: pipeline lint → build → auditoría secretos (Gitleaks) → migraciones → deploy
- La auditoría de secretos bloquea el merge si hay una API key en el código fuente — relevante para el módulo de seguridad

### 8.4 jsPDF para generación de PDF

- Generación en cliente, no en servidor: reduce costes de compute, el PDF nunca sale del navegador del técnico hasta que elige guardarlo o subirlo
- Alternativas descartadas: Puppeteer (requiere servidor Node, overhead), WeasyPrint (Python, stack diferente), react-pdf (bueno pero más verboso)
- Limitación: fuentes personalizadas requieren base64 inlining — se usa fuente Helvetica estándar

### 8.5 Zustand vs Redux vs Context

- Zustand: minimal boilerplate, no requiere Provider wrapping, acceso al store fuera de componentes (útil en callbacks de Supabase Auth)
- Redux Toolkit: más potente pero excesivo para el tamaño del proyecto
- Context API: re-renders no controlados al actualizar el estado global

### 8.6 Tailwind CSS v4

- v4 elimina `tailwind.config.js` — configuración en `vite.config.ts` con plugin
- Purge automático más eficiente, CSS variables nativas
- `@apply` sigue funcionando en `index.css` para clases reutilizables
- Nota: algunas clases de v3 cambiaron de nombre en v4 — revisar al actualizar dependencias

---

## 9. Docker y CI/CD

### 9.1 Dockerfile multi-stage

```dockerfile
# Stage 1: build
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: serve
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

Multi-stage reduce la imagen final de ~900MB (con Node) a ~25MB (solo nginx + assets estáticos).

### 9.2 nginx.conf para SPA

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    # Fallback a index.html para React Router
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Headers de seguridad
    add_header X-Frame-Options "DENY";
    add_header X-Content-Type-Options "nosniff";
    add_header Content-Security-Policy "default-src 'self'; connect-src 'self' https://*.supabase.co wss://*.supabase.co; img-src 'self' data:;";
}
```

### 9.3 GitHub Actions pipeline

```yaml
# .github/workflows/ci.yml
jobs:
  ci:
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22' }
      - run: npm ci
      - run: npm run lint
      - run: npm run build
      - name: Audit secrets
        uses: gitleaks/gitleaks-action@v2
      - name: Run tests
        run: npm run test -- --run
      - name: Deploy to Vercel
        if: github.ref == 'refs/heads/main'
        run: vercel --prod --token ${{ secrets.VERCEL_TOKEN }}
```

---

## 10. Riesgos técnicos identificados

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|-------------|---------|-----------|
| NVD downtime o rate limit | Media | Alto | VulnCheck como fallback, caché 6h en Supabase |
| S.M.A.R.T. no disponible en VM/CI | Alta | Medio | Mock data para demo, campo `smart_detallado: null` en JSON |
| Driver Windows no expone wear SSD | Alta | Bajo | Graceful fallback en script, mostrar "No disponible" en UI |
| PDF generación falla con datos vacíos | Baja | Alto | Validación de campos antes de llamar `generateIntervencionPDF` |
| Trigger alertas genera duplicados | Media | Medio | `ON CONFLICT DO NOTHING` + campo `tipo` + `dispositivo_id` como unique |
| Semana sin tiempo (exámenes) | Media | Medio | Semana 6 tiene margen. Prioridad: alertas > S.M.A.R.T. > testing |

---

## 11. Estado de implementación

### 11.1 Completado ✅

| Componente | Ubicación | Estado |
|------------|-----------|--------|
| Motor NVD API | `src/lib/nvdApi.ts` | ✅ Implementado con caché |
| Fallback VulnCheck | `src/lib/nvdApi.ts` | ✅ Implementado |
| Enriquecimiento EPSS/CISA KEV | `supabase/functions/enrich-cve/` | ✅ Implementado |
| Proyección vida útil | `src/lib/proyeccionVidaUtil.ts` | ✅ Implementado con regresión lineal |
| Tests proyección vida útil | `src/lib/__tests__/proyeccionVidaUtil.test.ts` | ✅ 9 tests pasando |
| Tests calculateAutoScores | `src/lib/__tests__/diagnosticoUtil.test.ts` | ✅ 16 tests pasando |
| Diagnóstico Windows | `scripts/windows/diagnostico.ps1` | ✅ v3.0 con S.M.A.R.T. |
| Diagnóstico Linux | `scripts/linux/diagnostico.sh` | ✅ v3.0 con smartmontools |
| Diagnóstico macOS | `scripts/macos/diagnostico.sh` | ✅ v3.0 |
| Diagnóstico Android | `scripts/android/diagnostico.sh` | ✅ v3.0 vía ADB |
| Optimización Windows | `scripts/windows/optimizacion.ps1` | ✅ Mejorado v3.0 |
| Optimización macOS | `scripts/macos/optimizacion.sh` | ✅ Mejorado v3.0 |
| Optimización Linux | `scripts/linux/optimizacion.sh` | ✅ Mejorado v3.0 |
| Optimización Android | `scripts/android/optimizacion.sh` | ✅ Mejorado v3.0 |
| Trigger alertas PostgreSQL | `supabase/migrations/20260425000000_trigger_alertas_diagnostico.sql` | ✅ Implementado |
| Edge Function send-email | `supabase/functions/send-email/index.ts` | ✅ Implementado |

### 11.2 Pendiente ⚙️

| Componente | Notas |
|------------|-------|
| Tests adicionales | Necesitan dependencias vitest @testing-library/jest-dom |
| API Keys configuración | RESEND_API_KEY, VULNCHECK_API_KEY en variables de entorno |
| Despliegue Edge Functions | Requiere `supabase functions deploy` |

### 11.3 Uso de las Edge Functions

```bash
# Desplegar todas las funciones
supabase functions deploy send-email
supabase functions deploy enrich-cve

# Invocar locally
supabase functions serve send-email --port 54321
```

### 11.4 Variables de entorno requeridas

```
# .env.local
VITE_VULNCHECK_API_KEY=tu_api_key_vulncheck
RESEND_API_KEY=re_xxxxxxxx
```

---

## 11. Seguridad Avanzada

### 11.1 Rate Limiting

**Objetivo:** Protección contra abuso de APIs y ataques de fuerza bruta.

**Implementación actual:**

| Componente | Límite | Implementación |
|------------|--------|----------------|
| **NVD API** | 5 req/30s (sin key) | Debounce 500ms + caché 6h |
| **VulnCheck** | ~30 req/min (plan free) | Fallback automático con timeout 5s |
| **Edge Function (send-email)** | 10 req/min por IP | headers `X-RateLimit-*` + respuesta 429 |
| **Edge Function (enrich-cve)** | 20 req/min por IP | Rate limit middleware |

**Cabeceras de respuesta:**
```
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 8
X-RateLimit-Reset: 1714234800
```

**Estrategias de mitigación:**
- Caché en cliente (Supabase + localStorage)
- Batch de requests cuando sea posible
- Exponential backoff en reintentos
- Lista de allowlist para IPs confianza (webhooks internos)

**Referencias:**
- OWASP API Security: https://owasp.org/API-Security/
- NVD API Rate Limits: https://nvd.nist.gov/developers/vulnerabilities

---

### 11.2 Variables Guardadas y Gestión de Secrets

**Principio:** Nunca exponer credenciales en el código fuente.

**Variables de entorno utilizadas:**

| Variable | Ubicación | Acceso | Descripción |
|----------|------------|--------|-------------|
| `VITE_SUPABASE_URL` | Frontend (Vite) | Público | URL del proyecto Supabase |
| `VITE_SUPABASE_ANON_KEY` | Frontend (Vite) | Público | Anon key con RLS |
| `SUPABASE_SERVICE_ROLE_KEY` | Edge Functions | Privado | Solo server-side |
| `NVD_API_KEY` | Vercel/Vercel Functions | Privado | Mayor rate limit (50 req/30s) |
| `RESEND_API_KEY` | Edge Functions | Privado | Emails transaccionales |
| `VERCEL_TOKEN` | GitHub Actions | Privado | Deploy automático |

**Almacenamiento seguro:**

1. **Desarrollo local:**
   - `.env.local` (añadido a `.gitignore`)
   - No versionar nunca

2. **Producción (Vercel):**
   - Environment Variables en dashboard
   - Se injectan en build time (no accesibles en cliente)

3. **Base de datos (Supabase):**
   - Secrets en Settings → API → Reveal keys
   - Row Level Security protege datos sensibles

**Políticas de rotación:**
- NVD API Key: revisar cada 90 días
- Resend API Key: regenerar si hay sospecha de compromiso
- Supabase keys: regenerar antes de entregar proyecto

**Errores comunes a evitar:**
- ❌ Guardar API keys en código
- ❌ Compartir keys en screenshots o documentación
- ❌ Usar la misma key en desarrollo y producción
- ❌ Dejar keys en comentarios o logs

---

### 11.3 Inyecciones de Scripts y SQL

**Análisis de vectores de ataque en ResolveCore:**

#### 11.3.1 Cross-Site Scripting (XSS)

**Riesgo:** Inputs de usuario en resúmenes técnicos, recomendaciones, comentarios.

**Mitigaciones implementadas:**

| Protección | Ubicación | Estado |
|------------|-----------|--------|
| React auto-escaping | Componentes JSX | ✅ Por defecto |
| Content Security Policy | `vercel.json` | ✅ Configurado |
| `dangerouslySetInnerHTML` evitado | PDFs, resúmenes | ✅ Sin uso |
| Sanitización de entrada | Formularios técnicos | ⚠️ Mejorable |

**Mejoras pendientes:**
- Implementar DOMPurify para contenido HTML legítima
- Validar longitud máxima de campos (280 caracteres para comentarios)
- Añadir `rel="noopener noreferrer"` a enlaces externos

**Test de validación:**
```javascript
// Input malicioso típico
const maliciousInput = '<img src=x onerror=alert(1)>';
// React lo escapa automáticamente → &lt;img...
```

#### 11.3.2 Inyección SQL (PostgreSQL)

**Riesgo:** Consultas dinámicas a Supabase/PostgreSQL.

**Mitigaciones implementadas:**

| Protección | Ubicación | Estado |
|------------|-----------|--------|
| Parameterized queries | Supabase JS client | ✅ Por defecto |
| Row Level Security | Tablas PostgreSQL | ✅ 75+ políticas |
| Prepared statements | Edge Functions | ✅ Con Deno SQL client |
| Escapado automático | Supabase builders | ✅ Implementado |

**Ejemplo de consulta segura:**
```typescript
// ✅ Seguro - parameterized query
const { data } = await supabase
  .from('citas')
  .select('*')
  .eq('cliente_id', clienteId) // Parameterizado automáticamente

// ❌ Peligro - SQL dinámico con concatenación
const query = `SELECT * FROM citas WHERE cliente_id = '${clienteId}'`
```

**Verificación de RLS:**
```sql
-- Ver políticas activas en una tabla
SELECT tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'citas';
```

#### 11.3.3 Inyección en Scripts de Diagnóstico

**Riesgo:** Scripts de PowerShell/Bash que procesan output de sistema.

**Mitigaciones implementadas:**

| Protección | Ubicación | Estado |
|------------|-----------|--------|
| Validación de tipos | Scripts | ✅ Con `Get-Member` |
| Escape de caracteres | GeneratePDF.ts | ✅ jsPDF sanitiza |
| JSON parsing | diagnostico.sh/ps1 | ✅ jq / ConvertFrom-Json |
| Strict mode | PowerShell | ✅ `Set-StrictMode -Version Latest` |

#### 11.3.4 Resumen de hardening aplicado

```
✅ CSP configurado en vercel.json
✅ RLS activo en todas las tablas públicas
✅ No hay consultas SQL dinámicas concatenadas
✅ Inputs sanitizados automáticamente por React
✅ Supabase client usa parameterized queries
✅ Edge Functions con validación de schema
✅ Rate limiting en APIs sensibles
```

---

> Documento actualizado: 27 abril 2026 — Secciones 11.1, 11.2, 11.3 añadidas