## [2026-05-06] â€” DiseÃ±o del logotipo principal

- DiseÃ±ado el logotipo principal para el proyecto `ResolvCore` basÃ¡ndome en los colores corporativos del tema de WordPress (fondo oscuro y acento `#00e5a0`).
- Por peticiÃ³n, se ha cambiado el checkmark central por una **'R'** estilizada dentro del hexÃ¡gono core para representar directamente el nombre y aportar un toque mÃ¡s tÃ©cnico.
- Se ha cambiado la tipografÃ­a a `Helvetica Neue/Arial` con pesos contrastados para dotar al logotipo de una presencia formal y profesional.
- Generadas tres versiones tanto en formato **SVG** (vectorial) como en **PNG** (rasterizado): 
  - `resolvcore-icon` (solo el sÃ­mbolo para favicon o avatares)
  - `resolvcore-logo-dark` (para fondos oscuros)
  - `resolvcore-logo-light` (para fondos claros)
- Estado: Recursos de marca creados en `assets/logo/`, listos para ser implementados en la web y otras plataformas del TFG.
- Añadida una silueta oscura exterior al trazado del icono para aportar mayor delimitación y contraste, mejorando la legibilidad sobre fondos complejos.
- Reestructuradas las capas del diseño vectorial para que cada trazo mantenga su propio contorno oscuro, logrando el efecto de superposición (ribbon) que separa claramente cada golpe visual.
- Actualizado el README principal: Integración del logotipo en la cabecera con soporte para modo oscuro/claro, actualización de la estructura de archivos (assets) e inclusión de redes sociales requeridas.
- Integrado el logotipo en el tema de WordPress: copiado a 'assets/logo/', eliminado el filtro de inversión CSS y actualizadas las referencias HTML. Generado el archivo comprimido 'resolvecore-theme.zip' listo para producción.
- Añadida sección 'Branding e Identidad' al README.md para exponer de forma visible los nuevos iconos (resolvcore-icon) y variantes del logotipo principal.
- Afinado el logotipo: eliminado el fondo negro en las vistas previas del README y reducido drásticamente el grosor del borde en los SVGs (pasando a una línea delimitadora casi imperceptible). PNGs y el ZIP del tema de WordPress regenerados.
- Añadida una 'C' entrelazada en el símbolo del logotipo para representar 'Core'. Se ha utilizado el color secundario representativo de la marca (azul #0099ff) para crear contraste y dinamismo con la 'R' verde principal.
- Modificado el color de la 'C' entrelazada en los logotipos: se ha cambiado el azul secundario por el naranja vibrante (#ff4b1f a #ff6b35) que corresponde a la variable '--rc-warn' del tema, dándole un contraste más enérgico y manteniendo la coherencia con la paleta de la web.
- Color de la 'C' del logo cambiado nuevamente: se ha asignado el color del texto principal de la interfaz web (gradiente blanco/plata para fondos oscuros y gris oscuro para fondos claros). Esto relaciona directamente la 'C' con la palabra 'Resolv' y la 'R' verde con 'Core'.

## [2026-05-07] — Actualización de README y Marca

- Renovado el README.md con los nuevos logotipos (light/dark) y una estructura más profesional.
- Añadido diagrama de flujo con Mermaid para explicar el ciclo operativo de ResolvCore.
- Actualizadas las redes sociales y el stack tecnológico para reflejar el estado actual del proyecto.
- Estado: Documentación principal finalizada y profesionalizada.
