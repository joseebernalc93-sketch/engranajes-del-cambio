# El carro de Elena · recursos v2

Generados con la herramienta integrada image_gen, mediante la habilidad imagegen. Los originales permanecen en `.codex/generated_images`; los recursos utilizados se copian al proyecto con nombres nuevos.

- `assets/gba/ui/elena_cart_parts_v2.png`: chasis vacío y rueda separada, RGBA. Regiones seleccionadas en código; cada rueda gira sobre su centro.
- `assets/gba/ui/elena_riverside_backdrop_v2.png`: panorama único, con desplazamiento sin repetir bordes.
- `assets/gba/ui/elena_enclosure_gate_v2.png`: portón encadenado independiente, RGBA.
- Las pertenencias utilizan los sprites independientes documentados en `elena_cargo_v3_notes.md`. Las cuerdas, indicador, rampa y controles se dibujan en Godot; Elena conserva su atlas original.

## Prompts finales

### Chasis y rueda

Create a polished pixel-art game sprite atlas on a fully transparent background, wide image about 1536x1024. Warm golden oak and iron, detailed hand-painted pixel art for a nineteenth-century rural cart, matching classic historical adventure game. TWO separate objects only, plenty of clear space between: LEFT TWO THIRDS of image an EMPTY wooden handcart chassis in strict SIDE PROFILE facing RIGHT, flat horizontal bed, low front side planks that allow cargo drawn behind to show, back wall behind cargo, two long pulling handles extending to right. Absolutely NO wheels attached to this chassis, no cargo, no ground, no backdrop, no people. The chassis occupies x~80 to 1020 and y~280 to 650. RIGHT THIRD of image, a SINGLE separate perfectly round wooden wagon wheel front-on, with 8 oak spokes and dark iron rim, centered at x~1300 y~480, about 330 pixels diameter, suitable to rotate as a game sprite. No text, no labels, no outlines of cells. Transparent background throughout, crisp edges, subtle pixel texture, not smooth vector art.

### Paisaje

A wide panoramic background for a polished historical pixel-art adventure game, 19th century English countryside during rural migration. Hand-painted detailed pixel-art style, warm olive greens, earthy amber dirt, muted blue sky, oak fences, distant stone village cottages left, a river winding along the right midground, distant small railway station near far right horizon. Camera strictly side-on with modest depth. Bottom 45 percent is EMPTY broad earthen road with grass verges and a few small stones and muddy ruts. Road runs straight horizontally. No carts, no people, no wheels, no text, no signs with lettering, no foreground gate blocking road, no interface. Rich beautiful landscape, soft morning light, composition suitable for placing large animated side profile wooden cart on road at center. Wide aspect ratio about 2.4:1.

### Portón

Single isolated sprite of a closed oak farm enclosure gate, nineteenth century English countryside, STRICT FRONT VIEW. Rich highly detailed pixel-art game asset matching golden weathered oak medieval historical RPG sprites, dark outlines, subtle pixel texture. Gate is about square, vertical planks and two thick horizontal braces, two heavy wooden side posts. A dark forged iron chain hangs across the closed double gate with a prominent iron padlock exactly in center. Wood golden brown, visible grain and iron bolt heads, morning light from upper left. Empty fully TRANSPARENT background, no grass, no ground, no fence extending beyond gate, no sky, no landscape, no cart, no people, no text or signage, no shadow below. Gate fills 80 percent of square image with 10 percent transparent margin on all sides. Clean alpha, sharp sprite edges.

