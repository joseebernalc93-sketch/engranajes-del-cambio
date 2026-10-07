# Ruta en diligencia de pasajeros — v1

Generación: herramienta integrada `image_gen`, 4 de octubre de 2026. Se conservaron las imágenes originales y se copiaron las versiones elegidas al proyecto. Las cinco imágenes se generaron por separado; no se utilizó la CLI.

## Recursos finales

| Recurso | Ruta | Tamaño |
| --- | --- | --- |
| Estación de carretas | `assets/gba/environment/carriage_depot_v1.png` | 1672 × 941 |
| Entrada principal del tren | `assets/gba/environment/station_front_entrance_v4.png` | 1672 × 941 |
| Componentes de la diligencia | `assets/gba/environment/passenger_coach_components_v1.png` | 1536 × 1024, alfa |
| Camino de la travesía | `assets/gba/environment/coach_countryside_v1.png` | 1672 × 941 |
| Ramón, cochero | `assets/gba/ramon_coachman_v1.png` | 1024 × 1536, alfa |

## Integración y recorrido

El extremo derecho de la aldea conduce a `scenes/carriage_depot.tscn`. El patio incluye posada, cobertizo, establos, abrevadero, equipaje, bancos y dos diligencias con caballos a escala de los personajes. Ramón ofrece el viaje por 3 monedas y el regreso queda incluido. Cancelar o carecer de monedas no descuenta el saldo; una reserva pendiente impide los cobros repetidos.

La venta de harina conserva las 10 monedas necesarias para el boleto del tren. Al completar la misión existente de Elena, ella entrega 3 monedas adicionales por el trabajo, una sola vez. Se conserva el puzzle, sus controles y sus condiciones de éxito. Las partidas de versión 4 que terminaron ese trabajo reciben la compensación al cargar; las que ya compraron el boleto o completaron la fase conservan su acceso sin nuevos cobros.

`scenes/coach_travel.tscn` anima cinco etapas durante 15,6 segundos: subir, salir del patio, recorrer el campo con la cámara siguiendo el vehículo, llegar a la fachada y bajar a pie. Las ruedas giran según la distancia, el caballo utiliza cuatro cuadros de paso, los pasajeros permanecen sentados y hay suspensión y polvo discreto. La misma secuencia funciona en sentido contrario. E, Espacio, Esc o el botón Continuar adelantan el viaje y dejan al jugador en el punto correcto, con los controles restaurados.

`scenes/station.tscn` ahora muestra exclusivamente la fachada principal y la explanada. La puerta lleva a la taquilla existente (`station_interior.tscn`); después de comprar el boleto se puede pasar al andén (`station_platform.tscn`). El antiguo exterior ferroviario se conserva como ese andén, con el tren y su animación original de partida. Se registran los viajes y el importe del pasaje en el informe docente.

Los fondos se dibujan a 1152 × 648. El panorama de campo se repite alternando reflejos mediante transformaciones de Godot. La diligencia usa regiones del atlas sin modificar el PNG: cuerpo `(30,200,1060,610)`, rueda `(1119,124,391,391)`, cochero sentado `(1070,575,256,372)` y pasajero `(1330,582,203,369)`. El caballo reutiliza `assets/gba/ui/elena_draft_horse_walk_v4.png`. Los componentes se animan por separado en `scripts/world/passenger_coach.gd`.

## Verificación

`tests/passenger_coach_test.tscn` comprueba la ruta caminando con colisiones, saldo insuficiente, cancelación, una sola tarifa, recompensa de Elena, los cinco momentos de la animación en ambos sentidos, las cuatro poses del caballo, rotación de ruedas, llegada, taquilla accesible, boleto, acceso al andén, partida real del tren, regreso incluido, guardado y migración. Usa el proyecto de validación con nombre separado:

```powershell
Godot --headless --path tmp/cart_validation_project res://tests/passenger_coach_test.tscn
```

Para capturas, omitir `--headless` y añadir `-- --capture-ui`. `tests/_capture_coach_voyage.tscn` permite grabar el recorrido con `--write-movie` y `--fixed-fps 30`; añadir `-- --return` para el regreso. El video de vista previa se guarda en `tmp/cart_validation_project/tmp/passenger_coach/viaje_en_diligencia.mp4`.

## Prompts exactos

### Estación de carretas

Destino: `assets/gba/environment/carriage_depot_v1.png`

```text
Use case: historical-scene. Asset type: finished1672x941 16:9 Godot RPG background. The supplied village image is STYLE REFERENCE ONLY. Create a NEW professional rural PASSENGER COACH STATION from the early Industrial Revolution with the same top-down3/4 game camera, rich detailed colorful pixel art, warm sunlight, lush greens, terracotta, aged oak and warm stone. A beautiful small coaching inn / ticket office stands at upper left (game x140..450,y55..270), tiled roof, stone/wood facade, open service hatch, lantern, luggage shelves and waiting bench. At upper middle an open coach shelter with wooden posts and baggage crates. At upper right a beautiful stable with two open stalls, hay, tack hooks, water trough and hitching rails. Keep the central loading yard generous and open, with circular wheel tracks on dirt, cobblestone boarding curb, simple period timetable board without readable lettering, luggage trunks and travel sacks along edges. Reserve EMPTY parking spots in front of the shelter and stable for two separately animated horse-drawn passenger carriages; DO NOT draw any horses, vehicles or people in this background. A generous horizontal cobblestone road MUST connect BOTH screen edges at game y420..520 (image y610..755), same level as the reference village road. The west/LEFT road connects back to the village; the east/RIGHT road leads towards the railway station. Clear uninterrupted road, no gate blocking travel. Lower quarter has landscaped grassy roadside, stone drainage ditch, trees and flowers, some lakeshore blue water glimpses at bottom, no boats. Main boarding spot centered at game(630,410), room for a240x120 carriage and nearby50px-tall ticket collector. Believable beautiful coaching terminus rather than corral, coherent building scales matching the reference, no modern buses/cars, no train/tracks, no text, no UI, no border, no gigantic buildings.
```

### Entrada principal del tren

Destino: `assets/gba/environment/station_front_entrance_v4.png`

```text
Use case: historical-scene. Asset type: finished1672x941 16:9 replacement Godot RPG railway station EXTERIOR / MAIN FRONT ENTRANCE. The supplied village image is STYLE REFERENCE ONLY for colorful detailed pixel art and top-down3/4 camera. Create an exceptionally crafted modest Victorian/early Industrial Revolution rural railway station main street facade in red brick and carved warm stone, dark slate roofs, arched windows, symmetrical entrance, central clock over a grand double timber-and-glass doorway, two chimneys, period wall lamps, modest iron entrance canopy over a short broad stair, climbing ivy and flower planters. The principal station building occupies game x230..1000,y35..320, with the centered entrance/steps at game x610,y330..390 (image x885,y480..566). The playable foreground is ONLY an open cobblestone FORECOURT and carriage drop-off street with benches, luggage trolley, hand cart, small baggage piles, planted islands and warm wood/iron materials at edges. CRITICAL: no platforms, NO RAILS/TRACKS, no train, no rear railway view, no huge urban city. This is the front where passengers arrive by carriage and enter the main door. A continuous public cobblestone road spans BOTH image edges at game y430..530(image y625..770) to align with coach travel and arrival. Leave clear drop-off curb in front of the entrance centered game(480,465), with space for a240x120 animated passenger carriage and the player to disembark aroundgame(620,440). Keep the main approach to the door walkable; no props block it. Lush country trees and gardens frame the station, lower foreground roadside grass/stone boundary rather than railway. Architectural detail polished but the building is coherent with a50px-tall character at game1152x648 scale. No people, no horses, no coaches because those will be animated separate layers. No modern objects, no readable text, no UI, no border. Bright consistent daytime light matching the village.
```

### Componentes de la diligencia

Destino: `assets/gba/environment/passenger_coach_components_v1.png`

```text
Use case: game-asset modular-sprite-atlas. Generate a beautiful TRANSPARENT PNG1536x1024 for an early Industrial Revolution rural PASSENGER carriage, detailed colorful PIXEL ART matching a top-down3/4 RPG, facing RIGHT. Components isolated, alpha transparent, absolutely no scenery/ground/text/labels. Main component on LEFT x30..1120,y130..850: a varnished oak four-wheeled passenger coach BODY with fine dark iron fittings, deep green upholstered bench seats, modest leather trim, a small folded travel blanket and luggage strapped behind, right-facing raised front driver's seat and access step. Open top or low folded canvas hood so the seated passenger is visible. Keep warm lit highlights, rich material detail, crisp pixel art. No cargo cart, no wagon full of sacks. MUST NOT draw wheels attached to the body: leave bare centered axle hubs at rear-left and front-right under the chassis so separate rotating wheel sprites can be overlaid. No horse attached, no long shafts beyond the reserved body area, no driver/person baked into the body. UPPER RIGHT separate wooden spoked carriage wheel with iron tyre/brass hub, perfectly circular front-on view centered(1320,270),diameter300. LOWER RIGHT two seated figures, fully separate from coach and wheel, each entirely contained in own cell: a COACHMAN in brown frock coat, dark waistcoat, flat cap, riding boots, hands forward holding reins, facing right, cell x1170..1320,y600..970; next to him the FARMER PASSENGER wearing golden straw hat, cream shirt and brown trousers, facing right, sitting with bent knees/hands resting, cellx1340..1510,y600..970. Farmer resembles the supplied character reference image exactly in clothing/face style (golden straw hat white shirt brown waistcoat and trousers). Professional cohesive passenger transport vehicle, not oversized mansion-like stagecoach, correct perspective, no words, no checkerboard, no background shadows/glow outside object silhouettes.
```

### Camino de la travesía

Destino: `assets/gba/environment/coach_countryside_v1.png`

```text
Use case: historical-scene / scrolling-game-environment. Generate a1536x864 colorful premium PIXEL ART panorama for a sidewards moving horse carriage in a top-down3/4 Industrial Revolution rural RPG, the supplied village image is STYLE REFERENCE ONLY. Bright warm day, rich trees, golden fields, stone farm walls, wildflowers, distant small slate-roof farmhouse upper left, glimpses of blue lake along bottom, a milestone and modest roadside shrubs. CRITICAL: broad flat horizontal cobblestone/dirt country lane spans full width at65%-81% image height (equivalent gamey420..525), samewidth and y alignment at both edges. Surrounding hedges and treelines frame but do not block the lane. Horizontally seamless tileable game map: left and right edge vegetation and road edges must connect when repeated; no giant foreground trunks crossing the road. Lane is empty for animated horse/carriage overlay; no humans, no sheep, no horses, no vehicles, no train, no modern objects, no text, no UI. Camera and pixel density match the supplied village; natural countryside readable at1152x648 game resolution. No curves, hills, intersections, bridge or obstacles across the lane. Lots of believable environmental details off the road, polished map-like composition not perspective vanishing-point landscape.
```

### Ramón, cochero

Destino: `assets/gba/ramon_coachman_v1.png`

```text
Use case: isolated-game-character. Create a single fully TRANSPARENT PNG sprite of RAMON THE COACHMAN for a colorful high-detail pixel art Industrial Revolution rural RPG, top-down3/4 camera, front facing slightly towards viewer/right. A friendly middle-aged man with dark short hair and modest moustache, dark brown flat cap, cream shirt, burgundy/brown waistcoat, practical knee-length brown frock coat, dark trousers and riding boots, a small leather fare pouch at belt, one hand holding a small paper coach ticket and other resting near his belt. Period nineteenth-century coach driver, no modern uniform, no top hat, no weapon, no horse, no cart, no furniture, no scenery, no labels. Full body centered with10% transparent margin all around on768x1024 canvas. Warm daylight, professional coherent crisp pixel detail, compact proportions matching the supplied game's farmer50px-tall sprite when rendered in game. All shading within character silhouette, no backdrop/glow/checkerboard.
```

