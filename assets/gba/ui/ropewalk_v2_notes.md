# Recursos animados de la cordelería

Generados con la herramienta integrada `image_gen` (habilidad `imagegen`), tomando `ropewalk_workshop_v1.png` como referencia. El original se conserva. Los PNG de rueda y carro conservan su transparencia; el fondo es opaco. El movimiento, la manivela, los cabos y la ligadura se dibujan y animan en Godot desde `scripts/ui/rope_machine_display.gd`.

## Fondo — `ropewalk_backdrop_v2.png`

Prompt final:

Use case: precise-object-edit. Edit target is the provided pixel art ropewalk workshop. Create a clean animation background plate, same very wide landscape composition, perspective, lighting, rich detailed pixel art, amber wood palette. Keep the workshop walls, windows, hemp bales, wood floor and coils of rope in the two bottom corners identical. Keep the two long horizontal wooden ground rails and their feet, and the vertical wooden hook stand just to the right of the big wheel. Keep the conical wooden rope guide in the middle exactly at its original place. REMOVE the entire big wheel on the left INCLUDING spokes, rim, axle support and crank (reconstruct the wall/floor behind it). REMOVE all three taut ropes between hooks and guide and ALL horizontal rope from guide to right edge; keep the hooks themselves. REMOVE the complete wheeled movable carriage on the right INCLUDING its wheels, screw, handle, and vertical posts, reconstruct the empty wooden floor and rails behind it. No moving wheel anywhere, no taut ropes anywhere, no carriage. This is for a game that will draw and animate those removed objects as separate layers. Exact same 2.4:1 aspect ratio and landmarks composition. No text, no border, no interface.

## Rueda — `ropewalk_wheel_v2.png`

Prompt final (fondo transparente):

Use case: background-extraction / game animation component. Reference is a wooden ropewalk workshop pixel art. Create ONLY the large eight-spoked wooden wheel from the left side, isolated, viewed perfectly straight on (a true circular front view, NO perspective ellipse). TRANSPARENT background and transparent empty gaps between the 8 spokes. No stand, no crank, no supporting wooden legs, no ropes, no background whatsoever, no shadow outside the wheel. Thick honey brown oak outer rim with visible wood grain, dark iron bolts around rim, eight broad carved oak spokes converging to a small dark iron central hub. Detailed crisp hand painted pixel art, very fine pixel texture, dark outlines and warm amber highlights, exactly match supplied workshop style and historical materials. Wheel centered on square canvas with 5% transparent padding and hub EXACTLY at center. It will rotate in a Godot game. No text. Output a single wheel sprite with genuine alpha transparency.

## Carro — `ropewalk_carriage_v2.png`

Prompt final (fondo transparente):

Use case: background-extraction. Isolate ONLY the small wooden wheeled tension carriage from the RIGHT side of the supplied ropewalk workshop, as a single transparent game sprite. Preserve same front/three quarter view, dark honey oak timber, black iron brackets and small wheels, vertical clamp screw with wooden horizontal handle, fine crisp pixel art detail. Complete carriage including both wheels, handle and vertical posts, centered with transparent padding. Remove all background, long rails and especially REMOVE ALL HORIZONTAL HEMP ROPE running through carriage; the game will add rope separately. No floor shadow, no letters, no border, no additional objects. Transparent background, genuine alpha. Match the original carriage closely; roughly 1.4:1 width to height.
