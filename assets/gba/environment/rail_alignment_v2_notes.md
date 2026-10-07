# Rieles sobre balasto: revisión del puzzle ferroviario

Generado con la herramienta integrada `image_gen` el 4 de octubre de 2026. Se creó una textura de piedras; los rieles, traviesas, controles y animaciones son geometría nativa de Godot. El original generado se conserva. Esta revisión sustituye la propuesta de patio de maniobras documentada en `railway_dispatch_v1_notes.md`.

## Recursos activos

- Textura nueva: `assets/gba/environment/rail_ballast_closeup_v1.png` (1672 × 941).
- Andén original recuperado: `assets/gba/environment/station_industrial_single_rail_v3.png`.
- Tren original recuperado: `assets/gba/train_industrial_v2.png`, escala 0,44.
- Animación de ruedas original: `shaders/train_wheels.gdshader`, aplicada por `scripts/world/steam_train.gd`. El ángulo depende de la distancia recorrida dividida por el radio de 28 píxeles. El tren permanece quieto hasta embarcar y autorizar la salida; acelera con vapor y silbato.

El andén conserva su vía única y sus objetos originales. Se retiraron las vías secundarias dibujadas y la vagoneta de la propuesta anterior. La fachada exterior, la diligencia y la taquilla conservan su recorrido.

## Puzzle y controles

`scenes/ui/rail_dispatch_popup.tscn` abre «El empalme de los rieles»: vista cenital de cuatro curvas sobre balasto, sin estación ni patio. Cada tramo gira en cuartos de vuelta y debe conectar sus dos extremos. Una inspección animada sigue el recorrido y se detiene ante cada barrera. El jugador comprueba y abre los cuatro controles de paso en orden; una unión cortada bloquea el avance y puede corregirse. Cada barrera termina de abrirse antes de continuar. Después se abre la señal de salida y se habilita el embarque.

- Ratón o pantalla táctil: tocar una pieza la gira; arrastrar permite elegir el sentido. Los botones de giro y Paso ofrecen controles equivalentes.
- Teclado: 1–4 seleccionan; ← / → o Q / R giran; Espacio inicia o continúa la inspección y abre la señal. Tab y Enter permiten recorrer los botones.
- Esc cierra y conserva orientaciones y pasos comprobados. Los tramos verificados quedan bloqueados. Al reabrir, la inspección retoma el siguiente control.

El guardado versión 7 conserva los puzzles previos, inventario, monedas y boleto. Las partidas que ya terminaron la preparación ferroviaria mantienen la salida autorizada. Una preparación parcial del puzzle descartado empieza el nuevo recorrido con cero controles verificados. El informe registra cuatro comprobaciones y una autorización de salida; la recompensa no se repite.

## Validación y vista previa

`tests/rail_dispatch_test.tscn` comprueba el acceso con colisiones, el tren y la vía originales, ratón, teclado y tacto, bloqueo de un empalme incorrecto, orden de controles, barreras animadas, continuidad de la inspección, cierre y reapertura, guardado, ventana pequeña, migración, señal y partida real con ruedas ligadas al movimiento.

`tests/_capture_rail_dispatch.tscn` graba el nuevo recorrido completo. Vídeo: `tmp/cart_validation_project/tmp/rail_alignment/empalme_y_tren_original.mp4`. Capturas de control en la misma carpeta: `restored_train_and_track.png`, `rail_alignment_unconnected.png`, `all_rails_connected.png`, `inspection_completed.png`, `small_window.png` y `original_train_departing.png`.

## Prompt exacto: textura de balasto

```text
Use case: historical-scene. Asset type: high quality 16:9 1672x941 pixel art railway BALLAST ground texture for a close-up interactive railway track puzzle. Reference is ONLY the colorful detailed pixel art style and stone material at the bottom of the reference. Create a completely filled, uniform top-down bird's-eye field of small compacted railway ballast stones: irregular angular grey and warm brown pebbles, a few subtle charcoal fragments and occasional muted dry grass near the far edges. Fine detailed pixel texture, professionally lit warmly from upper left with modest small shadows between pebbles, no perspective horizon, no large rocks, no scenery. Keep contrast restrained and medium dark so separately rendered steel rails and dark wooden sleepers stand out clearly. THE ENTIRE IMAGE IS ONLY GRAVEL. Absolutely NO station, buildings, patio, sky, tracks, railings, railway sleepers, rails, trains, vehicles, people, letters, diagrams, borders or interface. Seamless feeling and visually calm, no conspicuous repeating shapes or patterned grid.
```
