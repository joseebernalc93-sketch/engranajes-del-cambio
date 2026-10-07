> Propuesta sustituida: el tren y la vía originales se recuperaron; el puzzle activo se documenta en [rail_alignment_v2_notes.md](rail_alignment_v2_notes.md). Los recursos de esta propuesta se conservan como historial.

# Estación ferroviaria y puzzle «La última salida»

Generado con la herramienta integrada `image_gen` el 4 de octubre de 2026. Cuatro imágenes independientes, copiadas al proyecto; los originales generados se conservaron. Los atlas mantienen su alfa real. No se utilizó la CLI.

## Recursos finales

- Andén y nave de cristal: `assets/gba/environment/station_platform_dispatch_v4.png`.
- Locomotora, ténder, coche y rueda separados: `assets/gba/environment/steam_train_components_v3.png`.
- Vagoneta, señal, brazo, campana y rueda: `assets/gba/environment/railway_signal_components_v1.png`.
- Patio de maniobras del puzzle: `assets/gba/environment/railway_dispatch_yard_v1.png`.

## Integración

`scenes/station_platform.tscn` reemplaza el andén anterior por la nave de ladrillo, piedra, hierro y cristal, cabina de señales, equipaje, iluminación cálida y vías operables. Se conservan la fachada principal exterior, la llegada en diligencia, la taquilla y su boleto de 10 monedas. Los puzzles anteriores permanecen sin cambios.

La locomotora, el ténder y los dos coches se dibujan por separado de las ruedas. `scripts/world/steam_train.gd` utiliza desplazamiento real dividido por el radio para girar las ruedas grandes y pequeñas. Las bielas conectan los tres pernos de las ruedas motrices y el pistón acompaña el giro. Cuando el tren está quieto, las ruedas y las bielas se detienen. La salida acelera progresivamente y emite vapor y un silbato sintetizado localmente. La fase y el informe docente se completan tras la partida.

El atlas del tren usa regiones: locomotora `(28,100,1100,455)`, ténder `(26,635,580,312)`, coche `(615,601,905,348)`, rueda `(1150,200,340,340)`. El atlas de señales usa vagoneta `(45,305,990,251)`, rueda pequeña `(1165,715,275,275)`, poste `(1130,15,173,700)` y brazo `(108,727,489,167)`. El marco de la campana permanece fijo y la campana se dibuja y oscila por separado. Las vías, traviesas, agujas y palancas son geometría propia de Godot para responder al movimiento y conservar puntos de interacción precisos.

## Puzzle y controles

El personaje llega al andén con el boleto y se acerca a la cabina de señales. El tren también dirige al puzzle si falta preparar la vía. `rail_dispatch_popup.tscn` abre un panel de hierro y cobre con el patio de maniobras, tres palancas conectadas al escenario, instrucciones y comprobaciones.

1. Apartar la carga: bajar la palanca 1 hacia la vía secundaria, mover la vagoneta y frenar dentro del recuadro. D, derecha o Espacio avanzan; A o izquierda retroceden; S o abajo frenan. También se pueden mantener los botones o arrastrar la vagoneta. Hay aceleración, inercia, freno y ruedas que giran según el recorrido. Una aguja incorrecta bloquea el avance y el tope permite retroceder para corregir el estacionamiento.
2. Preparar las agujas: subir la palanca 1 y bajar la 2. Las agujas se mueven y la comprobación espera a que terminen de alinearse. Las palancas admiten arrastre con ratón o pantalla táctil; Tab y Enter o las flechas arriba/abajo permiten accionarlas con teclado. No se cambia una aguja mientras la vagoneta la está atravesando.
3. Dar la salida: bajar la palanca 3 para abrir el semáforo. Esperar a que el brazo termine de moverse y tocar la campana, su botón o B. La campana y el semáforo también se pueden pulsar directamente en el patio. La salida queda bloqueada si la carga, las agujas o la señal no están preparadas.

Esc o Cerrar regresan al andén. Apartar la carga y preparar el recorrido se guardan como etapas completas; una maniobra incompleta vuelve a empezar al reabrir. Soltar fuera del control, cambiar de foco o cerrar libera los mandos. Se conserva la visibilidad previa de los controles móviles. El panel se ajusta a ventanas pequeñas.

La versión de guardado pasa a 6. Las partidas activas mantienen los puzzles, monedas y boleto y reciben la nueva preparación ferroviaria; las fases antiguas ya completadas siguen completadas. El registro docente añade resultado de maniobra, acciones de agujas, bloqueos de seguridad y campanadas.

## Verificación y vista previa

`tests/rail_dispatch_test.tscn` verifica acceso a pie con colisiones, cabina y tren, bloqueo de embarque prematuro, señal y campana inseguras, freno, arrastres reales, teclado, pantalla táctil, etapas conservadas al cerrar/reabrir, pérdida de foco, ventana de 640×360, señal animada, campana única, guardado, migración de partidas de versión 5, tren con ruedas ligadas al desplazamiento, partida real y reporte. Las pruebas utilizan `tmp/cart_validation_project` con un nombre de aplicación separado y restauran los archivos anteriores.

```powershell
Godot --headless --path tmp/cart_validation_project res://tests/rail_dispatch_test.tscn
```

Para capturas, omitir `--headless` y añadir `-- --capture-ui`. `tests/_capture_rail_dispatch.tscn` graba una demostración completa con `--fixed-fps 30 --write-movie`; también restaura los datos de validación. Video final: `tmp/cart_validation_project/tmp/rail_dispatch/estacion_y_puzzle.mp4`.

## Prompts exactos

### Andén y nave de cristal

Destino: `assets/gba/environment/station_platform_dispatch_v4.png`

```text
Use case: historical-scene. Asset type: 1672x941 wide 16:9 pixel art Godot RPG railway PLATFORM background. Reference image is STYLE ONLY, create a NEW more sophisticated early industrial steam railway terminal in warm golden afternoon. Elevated top-down three-quarter RPG game view matching the reference, intricately textured colorful pixel art, not photorealism. Grand red-brick station upper middle with restrained stone arches, large clock, glazed iron canopy, vaulted glass roof, warm lit windows, huge inviting double door at game coordinate (640,310). Smaller beautiful signal cabin at upper left with brass fittings, mechanical lever frame visible through open window, baggage office on right, period lamps, benches, luggage carts, copper guttering, climbers and flower pots. Open generous walkable paved platform across entire screen at game y340..475, completely unobstructed middle walkway x400..790. Keep furniture grouped upper edges, no foreground vertical columns hiding player/train. Lower quarter y475..648 is EMPTY uniform textured gravel railway ballast reserved for separately drawn train, rails, switches and cargo wagon. Do NOT paint ANY rails, trains, vehicles, wheels, signals, people or readable text into the background. Upper background glimpse distant countryside and a stone viaduct with soft sky, keep coherent rural industrial style. Main station building fits y40..330, clear platform ledge near y470. Pixel art premium game production, readable small details, depth and atmosphere, no UI, no lettering, no modern things, no borders.
```

### Locomotora, ténder, coche y rueda separados

Destino: `assets/gba/environment/steam_train_components_v3.png`

```text
Use case: historical-scene. Asset type: transparent layered sprite atlas 1536x1024 for an animated premium pixel art steam train facing LEFT, perfectly side-on, matching supplied game reference style. Draw four strictly SEPARATE non-overlapping components with generous transparent gutters, on REAL TRANSPARENT background. Upper-left rectangle x40..1030,y35..470: beautiful black iron and deep burgundy early industrial steam locomotive BODY ONLY without any wheels and without connecting rods, brass domes, smokestack at left, riveted boiler, illuminated cab at right, cowcatcher at far left, chassis ending in clean horizontal lower edge. Lower-left x40..560,y520..825: matching dark green COAL TENDER BODY ONLY without wheels, coal visible above rim. Lower-middle/right x620..1490,y515..825: luxurious burgundy PASSENGER CARRIAGE BODY ONLY without wheels, cream curtains, warm lit windows, brass door handles, black curved roof and roof vents. Upper-right x1140..1460,y110..430: ONE large detached perfectly round burgundy spoked locomotive wheel with brass rim and central axle, perpendicular face-on with no perspective tilt, transparent between spokes. Important ALL vehicle bodies have NO wheels, no wheel fragments and no connecting rods; code will add spinning wheels and rods. Clean crisp rich detailed pixel art with consistent sunlight, no labels, no text, no rails, no smoke, no ground, no checkerboard.
```

### Vagoneta, señal, brazo, campana y rueda

Destino: `assets/gba/environment/railway_signal_components_v1.png`

```text
Use case: historical-scene. Asset type: 1536x1024 transparent game sprite atlas for railway signalling puzzle, rich detailed pixel art matching supplied reference, dark oak, iron, brass, warm gold light. Four strictly separated sprites with generous transparent gutters. TOP LEFT x50..800,y80..400: a small LOW railway flat cargo wagon BODY only with crates, rolled sack and rope tied to its wooden deck, perfectly side-on, NO wheels (animated wheels added separately). TOP RIGHT x1080..1400,y50..660: tall elegant period semaphore signal POST with brass and iron fittings, ladder and circular axle near upper tip; NO horizontal semaphore ARM. LOWER LEFT x80..700,y620..820: a detached long horizontal semaphore ARM pointing right, red with one white vertical stripe, round hinge at LEFT endpoint, same perspective as post. LOWER MIDDLE x740..1040,y650..950: beautiful period brass station BELL hanging in a dark oak small frame, no text. LOWER RIGHT x1190..1430,y760..990: a separate perfectly circular dark iron railway wagon wheel with eight brass-dark spokes, transparent gaps between spokes, face-on no perspective tilt. All sprites consistent detailed game pixel art, isolated on REAL transparency, no checkerboard, no lettering, no ground, no extra objects, no overlapping parts.
```

### Patio de maniobras del puzzle

Destino: `assets/gba/environment/railway_dispatch_yard_v1.png`

```text
Use case: historical-scene. Asset type: 1672x941 widescreen pixel art railway shunting yard background for interactive puzzle, matching supplied reference rich pixel art style. Elevated very clear three-quarter top-down game camera. Rural early industrial railway siding next to the new brick station, red brick signal cabin and glazed station canopy along TOP EDGE y0..190 only, trees, wall, coal shed, sacks and telegraph pole at upper edges. The central and lower large area game y200..575 is a WIDE OPEN smooth finely textured grey-brown gravel railbed with sparse weeds and small stones; keep it unobstructed and evenly lit. Reserve this area for separately drawn functional rails, moving cargo wagon, switches and mechanical signals, so do NOT draw ANY rails, rail tracks, vehicles, wheels, signals or people anywhere. Rich warm afternoon, beautiful crisp detailed game pixel art, modest edges, foreground dark oak and wrought iron fence confined extreme bottom y615..648. No text, no UI, no borders, no checkerboard, no modern objects. Landscape intended for a polished hands-on railway routing game.
```


