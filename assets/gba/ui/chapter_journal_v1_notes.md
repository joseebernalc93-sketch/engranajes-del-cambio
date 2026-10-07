# Cuaderno final y página de la fase 2

La opción 1 elegida se implementa con ilustración estática y controles nativos. Al terminar la salida animada del tren, el cuaderno muestra los cuatro puzzles, trigo, harina, reparación del molino, economía del viaje, tiempo y dificultad. El informe queda congelado al terminar: revisarlo o cerrar y abrir el juego no aumenta el tiempo de esa fase.

**Seguir explorando** abre `scenes/ui/phase_two_construction.tscn`. No vuelve al andén. La pantalla de construcción permite abrir el cuaderno con Esc; comienza en la fase 2 y las flechas de fase anterior/siguiente permiten revisar el resumen de la fase 1. Las teclas izquierda/derecha también cambian de página. Esc o Cerrar cuaderno vuelve a la pantalla de construcción. Volver al inicio conserva la partida. Reiniciar fase vuelve a la historia inicial y conserva la dificultad seleccionada.

El guardado versión 14 conserva el informe, la nueva escena, la página seleccionada y si el cuaderno estaba abierto. Las partidas anteriores siguen siendo compatibles; el cierre antiguo de la fase 1 utiliza la nueva presentación al continuar. Los guardados antiguos que ya estaban explorando el pueblo conservan su ubicación.

## Recursos

- `assets/gba/ui/chapter_completion_journal_v1.png`: libro aislado con transparencia, cuero, latón, pergamino y el viajero frente a la ciudad; sin texto ni controles incrustados.
- `assets/gba/environment/phase_two_construction_v1.png`: distrito industrial con andamios, vías, planos y maquinaria de época.
- Se reutilizan el libro de pausa, el atlas de cuatro oficios y los iconos de trigo, harina y rueda dentada del proyecto.
- `scripts/ui/chapter_journal.gd`: páginas, fichas, datos reales, botones, estados y transición de página.
- `scripts/ui/phase_two_construction.gd`: pantalla futura, Esc y restauración de la sesión.

Los dos PNG se generaron con la herramienta integrada imagegen y se copiaron al proyecto. Los originales permanecen en la carpeta de imágenes generadas de Codex. El juego solo carga recursos de `assets/`.

## Prompts finales

**Libro (referencia: la opción 1 elegida):**

Use case: precise-object-edit. Production bitmap asset for a Godot game. Reference is the chosen end-of-chapter traveler journal. Extract a beautiful isolated open leather-bound journal in exactly this style, transparent background, landscape aspect 1000:606. Straight-on orthographic view, complete book with safe margins, rich warm aged ivory pages, dark brown leather binding, bronze corners and rings, restrained hand-inked marginal decoration. KEEP the traveler in straw hat facing an industrial city illustration ONLY on the left page within the rectangle from 8% to 47% of whole-image width, and 25% to 52% of whole-image height. Illustration blends into parchment edges. Both pages have plain parchment elsewhere for native Godot text and controls. Entire top 22% of left page blank for headings; entire lower 45% of left page blank for three achievement rows and reflection. Entire right page blank except subtle tiny corner vines and thin decorative borders outside the content area. No top blueprints on right page. REMOVE ALL lettering, ALL numbers, ALL stamps, ALL achievement rows, ALL puzzle cards, ALL buttons, ALL symbols suggesting fake controls. No text whatsoever. No station background. Genuine transparent outside the silhouette. Preserve lavish craftsmanship and believable book materials from the reference. Exact illustration placement crucial; native content will be overlaid.

**Fondo (referencia: la estación del juego):**

Use case: historical-scene. Production full-screen background illustration for an educational pixel-art game set in the Industrial Revolution, matching the reference station's rich painterly pixel-art textures and warm bronze/brick palette. Landscape 16:9, no text and no UI. A new industrial city district still under construction: Victorian brick factory and stone viaduct with timber scaffolding at right, an unfinished large iron gear mechanism and wooden workbench with rolled blueprints in lower right foreground, work lanterns, stacks of bricks, hand tools and beams. Distant city smokestacks, subtle steam, dusk sky. Left and central portions are atmospheric and visually calm with darker space for an overlaid "Fase 2 en construcción" heading. A railway leads away toward the city to link the completed countryside chapter with the future city chapter. Detailed craftsmanship, atmospheric cinematic lighting, tasteful warm gas lamps against deep teal dusk. Period construction only, no modern cranes, machinery, caution tape or signage. No characters needed, no lettering, no watermarks, no interface. Scene fills frame, avoid borders.

## Verificación

`tests/chapter_journal_flow_test.tscn` verifica la salida real del tren, informe congelado, cuatro fichas y economía, ambas dificultades, dimensiones de arte y texto, nueva pantalla, Esc, flechas y teclado, ventana pequeña, guardado y restauración en otro proceso, regreso al inicio y reinicio.

Ejecutar primero `--headless --path tmp/cart_validation_project res://tests/chapter_journal_flow_test.tscn` y luego la misma escena con `-- --read-chapter`. Omitir `--headless` y añadir `-- --capture-ui` a la primera ejecución produce capturas en `output/ui/chapter_journal/`. El segundo proceso restaura los archivos de validación originales. Las pruebas usan el proyecto aislado para preservar la partida del usuario.
