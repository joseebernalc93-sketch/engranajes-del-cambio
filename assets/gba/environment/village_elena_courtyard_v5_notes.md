# Patio de Elena y traslado del trigo

Se utilizó la herramienta integrada `image_gen` en modo de edición sobre `village_bakery_courtyard_v4.png`. El resultado se guardó en `village_elena_courtyard_v5.png` (1672 × 941).

El escenario dibuja solo la región superior izquierda de la imagen nueva sobre el fondo original. Así conserva las casas, calles, panadería y sus posiciones. El caballo y la carreta siguen siendo un sprite independiente que desaparece al terminar la misión. El agua, los botes y el fuego conservan sus animaciones.

El escenario del molino dibuja únicamente el interior del sembrío del fondo original, con el trigo dorado, tanto antes como después de su reparación. La cerca, los árboles y el camino del molino permanecen en su fondo original. Los nodos de cosecha mantienen `wheat_1`, `wheat_2` y `wheat_3` para conservar la compatibilidad con partidas guardadas.

## Prompt utilizado

```text
Use case: precise-object-edit. Asset type: existing 16:9 game background for Godot, detailed colorful pixel art top-down 3/4 rural village. Input image is the EDIT TARGET, preserve its camera, dimensions, composition and alignment exactly. Change ONLY the golden wheat inside the fenced rectangular plot in the upper left (roughly x 4%-43%, y 13%-51%). Remove ALL wheat stalks and all agricultural furrow rows there, replace that interior with an EMPTY compacted warm earth courtyard with a few small cobblestones, subtle wagon wheel tracks and tiny grassy tufts near perimeter. Leave ample flat empty space for a separate horse and wagon game sprite. Keep the existing wooden fence and its centered opening at the bottom in precisely their original locations. Keep the short entrance path connecting that opening to the lower road unchanged. Keep ALL pixels outside the plot unchanged as closely as possible, including green trees bushes flowers, both houses, bakery facade counters oven bread racks barrels, vertical and horizontal stone roads, lower wooden bench, river shore and blue water. No horse, no wagon, no people, no UI, no lettering, no new buildings or objects. Only replacing wheat with a clean empty courtyard floor, sharp pixel art matching target.
```
