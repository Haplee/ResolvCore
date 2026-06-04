# Viernes 05/06/2026 

## FASE 1: Memoria del Proyecto

### Correo Juan Carlos 04/06/2026

**Cosas por realizar:**

Actúa como un revisor y editor experto en documentación técnica académica. Necesito que apliques las siguientes correcciones y mejoras a la memoria de mi proyecto final para asegurar que cumple con los estándares exigidos para su presentación.

Por favor, realiza las siguientes tareas de forma detallada:

#### 1. Actualización del Índice
- Revisa la estructura del documento.
- Asegúrate de que el índice refleja todos los apartados y subapartados de forma jerárquica.
- **Importante:** Añade la referencia de página exacta a cada uno de los puntos listados en el índice.

#### 2. Inclusión de Imágenes y Esquemas
- Analiza el texto e identifica al menos **5-10 puntos estratégicos** donde se deba insertar una imagen, diagrama de red, esquema lógico o captura de pantalla.
- **Objetivo:** Hacer la lectura más amena y aumentar el volumen total de páginas del documento.
- **Acción requerida:** Indícame exactamente dónde insertar cada imagen y sugiere qué debería mostrar y qué pie de foto llevar.

#### 3. Revisión de Formato y Estilo (Justificación)
- Revisa minuciosamente el formato de todo el documento.
- Presta especial atención a la alineación del texto.
- Asegúrate de que **todos los párrafos** (especialmente el reportado en el apartado 3.2.3) estén **justificados** (alineados a los márgenes izquierdo y derecho).
- Homogeneiza los márgenes, fuentes y espaciados.

#### 4. Corrección de la Numeración
- Revisa la estructura de encabezados.
- Identifica el error de numeración marcado como **"3b"** y reestructura esa sección para que siga una numeración jerárquica coherente y estándar (ej. 3.1, 3.2, 3.3, etc.).

#### 5. Redacción del Anexo de Scripts
Crea una nueva sección al final del documento llamada **"ANEXOS"**. Dentro de ella, genera un apartado específico para la **"Documentación de Scripts"**. 

Para cada script del proyecto, debes incluir:
- Nombre del script y lenguaje (Bash, Python, etc.).
- Descripción breve de su función en la infraestructura.
- Requisitos o dependencias previas.
- Modo de ejecución y ejemplos de uso.
- El código fuente limpio y correctamente formateado.

> **Nota:** Entrégame el texto corregido o las instrucciones exactas paso a paso para que yo lo aplique en mi procesador de textos.

---

**Nota final:** ¡Mucha fuerza con la recta final! Como técnico ASIR, asegúrate de que en la presentación (el 17/6) lleves un entorno de laboratorio robusto y automatizado (quizás un entorno montado rápido con un par de scripts que puedas mostrar). ¡A por todas!

---

### Correo original de mi profesor - 04/06/2026

´´

    Buenos días, Fran:

    Lo primero: Tienes que asegurarte que lo que entreges esté subido el 11/6/2026 (versión final y presentación).

    A mejorar/añadir:
    - El índice tiene que tener referencia a las páginas (esto es, debe de tener la referencia de página de cada uno de los puntos).
    - Introduce imágenes en el documento, con el fin de facilitar su lectura, y de forma indirecta, que suba el número de páginas del mismo.
    - Asegúrate de la corrección del documento (por ejemplo, el apartado 3.2.3 no está justificado (el margen derecho no está alineado, ...)
    - ¿Qué numeración es 3b?
    - Creación de parte final de ANEXO, con la documentación de scripts.

    Prepárate bien la presentación y el laboratorio final. Has hecho todo lo que has podido y debes de poner "toda la carne en el asador",,,ánimo!! La presentación prosiblemente sea el 17/6/2026, pero no te lo puedo asegurar.

    Cualquier cosa o duda, por favor, llámame. Si no puedo cogerlo, te responderé cuando pueda.

´´

---

## FASE 2: Corrección de Scripts

### [CONTEXTO Y ROL]
Eres un ingeniero de sistemas sénior (ASIR) experto en scripting multiplataforma (Bash, PowerShell y Python). Actúas como un asistente de desarrollo para un técnico de sistemas que necesita depurar y finalizar un conjunto de herramientas de diagnóstico y gestión de tickets. El proyecto consta de scripts específicos por sistema (`.sh` para Ubuntu y `.ps1` para Windows) junto con scripts comunes desarrollados en Python.

### [TAREA CONCRETA]
Necesito que revises y corrijas el código de mis scripts de administración para resolver estos cuatro problemas:
1. Finalizar la implementación de las funciones incompletas en los scripts específicos de Ubuntu (`.sh`).
2. Corregir la validación de inputs en todos los scripts: actualmente, si el usuario pulsa ENTER sin introducir ninguna opción, el script se cierra. Debe atrapar este error y volver a pedir la entrada en bucle hasta recibir un valor válido.
3. Arreglar la ruta de exportación de tickets: al generar un ticket ejecutando el script nativamente en el terminal de Windows, el archivo se está guardando incorrectamente en una ruta de Windows por defecto. Debe asegurarse de que se guarda en el directorio destino relativo o absoluto correcto del proyecto.
4. Homogeneizar diagnósticos: actualizar el script de diagnóstico de Windows (`.ps1` o Python) para que extraiga y muestre exactamente la misma información técnica que ya proporciona la versión de Linux.

### [ESPECIFICACIONES]
- Genera código completo, robusto y listo para ejecutar. Nada de fragmentos sueltos ni comentarios tipo `# TODO`.
- Usa herramientas estándar nativas de cada sistema operativo (evita dependencias de terceros si no son estrictamente necesarias).
- No me expliques conceptos básicos de sistemas, redes o scripting; asume un nivel técnico avanzado.
- Asegura que las funciones escritas en Python mantengan compatibilidad pura multiplataforma gestionando las rutas con `os.path` o `pathlib`.

### [CRITERIOS DE CALIDAD]
- El script no debe romperse ni salir abruptamente ante un input vacío o inválido (aplica a bash, ps1 y python).
- La información de diagnóstico en Windows debe tener paridad total en datos con la de Linux (red, procesos, hardware, logs, etc.).
- La solución debe ser la más simple, ligera y directa posible.

### [FORMATO DE RESPUESTA]
1. Identificación directa del fallo detectado.
2. Código completo de los scripts corregidos (o las funciones completas a reemplazar, indicando claramente en qué archivo van).
3. Breves instrucciones de ejecución si hay cambios en el modo de uso.

### [VERIFICACIÓN FINAL]
Antes de responder, comprueba que has abordado los 4 puntos solicitados y que el código para Windows no usa sintaxis exclusiva de bash y que las rutas en Python están correctamente unificadas.
