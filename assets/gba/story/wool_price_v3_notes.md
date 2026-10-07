# Relato de la fase 1: El precio de la lana

Fecha: 2026-10-05. Opción 2 aprobada por el usuario.

Se sustituyeron las cuatro imágenes y los cuatro textos de la introducción. Se retiraron los archivos de la versión `enclosure_v2_*` que consumía el relato anterior.

## Recursos

1. `wool_price_01_wealth.png`: La nueva riqueza.
2. `wool_price_02_gate.png`: Una puerta, dos realidades.
3. `wool_price_03_elena.png`: Lo que la lana no cuenta.
4. `wool_price_04_departure.png`: El coste del cambio.

Las imágenes proceden de `output/imagegen/phase1_stories/02_el_precio_de_la_lana`. Se generaron con la herramienta integrada image_gen. Los prompts exactos y los textos originales están en `output/imagegen/phase1_stories/prompts.md` y `historias.md`.

## Interfaz

El encabezado identifica la fase y el cercamiento, con el título del relato. El recuadro inferior muestra el título de cada escena, su narración y el contador. El rediseño aprobado el 2026-10-05 sigue el botón «Comenzar» de la portada: madera de nogal oscura, doble marco de latón con relieve, esquinas ornamentadas, remaches y pequeños engranajes. Los títulos y los botones utilizan tipografía serif; la narración conserva su tipografía de lectura.

Los tres recursos SVG de `assets/gba/ui/story_walnut_brass_panel.svg`, `story_walnut_brass_button.svg` y `story_brass_emblem.svg` se dibujaron para esta interfaz. Los marcos se escalan mediante StyleBoxTexture con márgenes fijos y los adornos tienen dimensiones independientes, para conservar sus proporciones al cambiar el ancho del recuadro. Las decoraciones ignoran el mouse. Los botones cuentan con estados normal, hover, pulsado y un contorno de foco para el teclado.

El botón final dice exactamente `Empesar primera fase`, como solicitó el usuario. Conserva el acceso a `sheep_farm.tscn` desde el camino público. Al consultar el relato dentro de una partida, la última acción sigue siendo `Volver al juego`.

El ajuste compacto del 2026-10-05 elimina el ancho fijo del encabezado y la altura mínima fija del recuadro inferior. Ambos se dimensionan según el contenido: el encabezado mide sus dos etiquetas y el diálogo calcula la altura del título, la narración envuelta y las acciones. Los márgenes y la separación entre filas se redujeron; los botones ajustan su ancho al texto y tienen 46 píxeles de altura. La narración conserva sus 18 píxeles de tamaño de fuente en el formato habitual.

Tras la aclaración sobre la franja vacía inferior, las acciones se trasladaron a la misma fila que el título de la escena y el contador. La narración aparece debajo a todo el ancho: ya no existe una fila reservada para botones bajo el texto. El encabezado interno se apila en ventanas estrechas para conservar la legibilidad y el acceso a los controles.

Los marcos, remaches y adornos se redujeron proporcionalmente para acompañar los recuadros compactos. En ventanas estrechas las acciones se apilan. Las transiciones de imagen cancelan el fundido anterior si se cambia de página rápidamente.

## Validación

- Importación de Godot sin errores de scripts ni de recursos.
- Capturas a 1152 × 648 de las cuatro páginas, con todos los textos visibles.
- Navegación real con Enter y clicks: 1 → 2 → 3 → 4 → Atrás → 3 → Siguiente → 4 → Empesar primera fase → criadero.
- El registro confirma la carga de `sheep_farm.tscn`; la captura final muestra al protagonista fuera del portón.
- Video: `output/imagegen/phase1_stories/opcion_2_recorrido.mp4`.
- El test general `phase_one_smoke_test` pasa las comprobaciones del relato, pero se detiene después en su comprobación de colisiones del patio de Mateo (línea 180), tanto en modo headless como con GPU. No se modificaron esa escena ni las colisiones para este cambio.

### Validación del rediseño de los recuadros

- Importación de los SVG y la escena sin errores de scripts ni recursos.
- Capturas de las cuatro páginas a 1152 × 648: títulos, narraciones, contador y botones completos.
- Recorrido real con Enter y clicks: las cuatro páginas, Atrás, Siguiente y entrada al criadero mediante «Empesar primera fase».
- Capturas y video en `output/ui/phase1_story_industrial`.
- El rediseño no altera las ilustraciones ni el texto del relato. No se volvió a ejecutar el test general de colisiones para este cambio de presentación.

### Validación del ajuste compacto

- Importación sin errores de recursos ni scripts.
- Revisión visual de las cuatro páginas a 1152 × 648: encabezado ajustado a sus etiquetas, narración completa y botones con ancho según su texto.
- Navegación con Enter, Atrás y Siguiente; entrada al criadero desde el botón final.
- Capturas y video en `output/ui/phase1_story_compact`.

### Eliminación de la fila vacía inferior

- Importación sin errores de scripts ni recursos.
- Revisión de las cuatro páginas con título, contador y acciones en la fila superior; narración completa debajo y margen inferior reducido.
- Recorrido con Enter y clicks hasta cargar el criadero.
- Actualizada la ruta de NextButton en la comprobación existente del relato.
- Capturas y video en `output/ui/phase1_story_inline`.
