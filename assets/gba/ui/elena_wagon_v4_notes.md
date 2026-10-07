# Carreta de Elena v4

Modo: imagegen integrado (generación y edición; sin CLI). Assets conservados como nuevas versiones. Se reutilizan los seis objetos detallados de `elena_cargo_v3_notes.md` y las ruedas independientes de `elena_cart_parts_v2.png`.

## wagon

Ruta: `assets/gba/ui/elena_wagon_body_v4.png`.

Prompt exacto:

```text
Use case: historical-scene. Asset type: single isolated stationary WAGON CHASSIS sprite for layered pixel-art game animation. Detailed hand-painted golden oak and dark forged iron, matching nineteenth century rural English village RPG. STRICT side profile facing RIGHT, very slightly elevated camera so the EMPTY INNER BOX FLOOR is visible. A NEW sturdy horse-drawn farm wagon body with tall back and end walls, rectangular deep interior, a LOW front side rail at the bottom letting independently drawn cargo appear inside. Tall rear wall runs horizontally across entire box, with upper rim at about 20% image height. Main interior is a wide clean unobstructed rectangular recess about x12%..72%, y30%..70%. Front side board occupies y70%..84% and is one narrow horizontal plank with iron corner brackets. Two short horizontal shafts extend RIGHT from the lower body, to attach a horse later. ABSOLUTELY NO WHEELS attached, NO CARGO, NO HORSE, no person, no canvas cover, no lettering. Box body is wide and rectangular, not a cart with oversized handle at left. Designed to install independent spinning wheels under bottom rail. Fully transparent background. Entire body visible, about 82 percent of wide horizontal image. Fine oak grain, iron fittings, realistic period construction, warm sunlit pixels, crisp outlines, no scene, no ground, no cast shadow.
```

## horse

Ruta: `assets/gba/ui/elena_draft_horse_walk_v4.png`.

Prompt exacto:

```text
Use case: historical-scene. Asset type: FOUR-FRAME walking sprite sheet of ONE chestnut DRAFT HORSE wearing simple leather pulling HARNESS for a nineteenth century village wagon. FOUR separate equally sized strict SIDE PROFILE horses facing RIGHT arranged in ONE horizontal row on fully TRANSPARENT background, each full horse isolated in its own cell with plenty of gap. Each horse same chestnut coat, darker mane and tail, small pale forehead blaze, sturdy proportions, leather neck collar and belly strap, NO saddle, NO rider, NO reins trailing outside. Frames 1,2,3,4 depict consecutive gentle WALK cycle leg positions, four legs correctly attached and alternating steps, not galloping. Body dimensions and hoof baseline consistent across all frames. Each horse fits entire cell with margin, no cutoff mane/tail/hooves. Detailed polished hand-painted pixel art, golden afternoon light, matching rural historical oak wagon game. No cart, no cargo, no people, no labels, no text, no ground, no shadow, no painted background.
```

## village_vehicle

Ruta: `assets/gba/environment/elena_horse_wagon_world_v4.png`.

Prompt exacto:

```text
Use case: historical-scene. Asset type: ONE isolated HORSE-DRAWN WAGON with neatly stowed belongings, transparent game environment prop. Elevated THREE-QUARTER TOP-DOWN view matching a 2D historical RPG village, wagon on LEFT, chestnut draft horse on RIGHT, facing lower-right east. Sturdy new rectangular GOLDEN OAK wagon with iron braces and four spoke wheels. Tall side and end boards define a REAL INTERIOR BOX. Inside the box, below the upper rims, neatly separated travel parcels: compact folded blankets, a small linen provisions bundle and an oak tools box. Every parcel fits inside, none sitting on top of boards, none protruding outside, nothing covering the horse. Horse has dark mane and simple leather collar and belly harness. Two wooden shafts at lower sides connect the wagon to horse, period correct, short coherent coupling. Proper perspective and size: horse is sturdy and about the height of wagon plus wheels. Entire composed vehicle visible and isolated, warm highly detailed hand-painted PIXEL ART matching nineteenth century rural English game scenery. No people, no road, no grass, no buildings, no text, no labels, no background, no cast shadow outside vehicle. Fully transparent alpha.
```

## clearing

Ruta: `assets/gba/environment/village_bakery_courtyard_v4.png`.

Prompt exacto:

```text
Edit target: attached village background image. Keep the same image dimensions, same top-down pixel-art style, wheat field and fences on the left, cottage and bakery buildings in their exact positions, main vertical cobblestone road and horizontal road at bottom, bakery oven, bakery bread counter and racks, and lower river unchanged. Change only the overgrown ground in the middle clearing south of the small cottage and immediately west of the vertical main road. This is the area approximately x44%..65% of the image width and y45%..64% of image height. Replace intrusive bushes, large scattered rocks and patchy grass there with one broad integrated pale earth-and-cobblestone wagon waiting courtyard that connects naturally to the cottage path and main road. Make sufficient smooth empty open space for a wagon and horse, around 300 pixels wide in the final game, no hard rectangular patch outline. Move ground clutter to the edges. Keep a clear walking passage between cottage doorstep and courtyard. Do NOT add carts, horses, people or new structures. Preserve all other scenery, exact building locations, street geometry, colors and lighting. No text, no UI.
```

## Limpieza del recorte del vehículo del pueblo

Asset final: `assets/gba/environment/elena_horse_wagon_world_v4.png`.

Prompt exacto de edición:

```text
Edit this exact sprite. Preserve the detailed oak wagon, neatly contained cargo, chestnut draft horse, attached shafts and leather harness and their exact arrangement and perspective. Remove ALL the brown/golden ambient glow and haze, ALL background and cast shadows around and between the objects. Deliver an absolutely clean transparent-background game sprite cutout with fully opaque wagon, cargo and horse materials, alpha zero everywhere outside their silhouettes including gaps between spokes and between legs. No ground plane, no vignette, no smoky halo, no additional objects. Keep the silhouette complete with no cropping.
```

## Integración

Caja y pared cercana se dibujan por capas; cada pertenencia ocupa una posición independiente dentro del suelo. El equilibrio desplaza el conjunto con límites que mantienen la carga dentro de la caja. Las ruedas giran con la distancia y el caballo usa cuatro cuadros de caminata. Elena camina al lado izquierdo. El patio está incorporado al fondo del pueblo; el vehículo y sus dos obstáculos físicos se eliminan al completar la misión y no se crean al cargar una partida completada.

Validación: `tests/migration_cart_test.tscn` verifica todas las combinaciones permitidas, separación y contención en los extremos del equilibrio, animación del caballo, controles, tres prioridades, eliminación inmediata, limpieza de colisiones y ausencia al cargar la partida. `tests/_capture_elena_wagon_v4.tscn` recorre y captura el viaje completo y el pueblo antes/después.

