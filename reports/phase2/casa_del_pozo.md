# Casa del pozo y viaje independiente del ascensor

La propuesta visual aprobada se integra como un interior explorable separado, `mine_house`. El patio tiene una puerta cerrada de madera y hierro. Cerca aparece **E Entrar a la mina**; dentro, la puerta izquierda ofrece **E Salir al patio**. El ascensor queda a la derecha y ofrece **E Bajar al pozo**. Caleb sigue presentando la misión en el patio antes de permitir el descenso.

La habitación contiene banco de trabajo, herramientas, ladrillo, madera y lámparas en pixel art. El fondo no incorpora personajes ni una cabina inmóvil; el protagonista y la jaula se dibujan por separado. El personaje usa la misma escala 1,8 que en el túnel. Flechas/WASD y clic/toque permiten desplazarse; solo aparece el aviso de interacción al acercarse.

El viaje dura 9,4 segundos: entrada (0–1,3), cierre (1,3–2), recorrido (2–7,6), apertura (7,6–8,2), salida (8,2–9,4). El tramo central cambia a una vista cercana de un **pozo subterráneo exclusivo**, con paredes y lámparas desplazándose junto a las guías. Un fundido breve conecta los encuadres. La animación no dibuja el patio ni una franja sobre los adoquines.

Al bajar se llega al ascensor izquierdo del túnel existente. Al subir se regresa **al interior**, junto a la jaula, y se usa la puerta para volver al patio. Los desprendimientos y las seis etapas de carbón y motor conservan su funcionamiento.

## Guardado

`arrival_version: 5` conserva área, posición, tiempo, sentido del viaje y posición de entrada. Cuaderno, inventario y pérdida de foco pausan imagen y sonido. Continuar recupera el instante del viaje o la exploración dentro de la casa. Los viajes de versión 4 que partían del patio se trasladan a la casa sin alterar el tiempo guardado; los viajes antiguos de siete segundos se convierten proporcionalmente. No hay cobro de monedas ni reinicio de misión.

## Arte y código

Recursos creados con **image_gen integrado**, sin reemplazar los originales:

- [Casa sin personaje ni cabina](../../assets/phase2/mine_winding_house_v1.png).
- [Patio con puerta](../../assets/phase2/mine_yard_pixel_v3.png).
- [Pozo vertical](../../assets/phase2/mine_vertical_shaft_v1.png).
- [Prompts y referencias](../../assets/phase2/mine_winding_house_prompts_v1.json).

`london_arrival.gd` integra el área, las puertas y los checkpoints; `mine_lift_sequence.gd` reconstruye los tres encuadres desde el tiempo guardado; `mine_art.gd` comparte recursos y puntos de llegada. El atlas existente aporta la cabina y la compuerta.

## Verificación

Ejecutar los tres procesos en orden, dentro del proyecto aislado:

```powershell
./tests/prepare_validation.ps1 -GodotExecutable godot
godot --headless --path tmp/cart_validation_project res://tests/mine_tunnel_test.tscn
godot --headless --path tmp/cart_validation_project res://tests/mine_tunnel_test.tscn -- --read-descent
godot --headless --path tmp/cart_validation_project res://tests/mine_tunnel_test.tscn -- --read-ascent
```

La suite comprueba ambas dificultades, entrada/salida de la casa, desplazamientos del ascensor, pausas, continuación entre procesos, compatibilidad con versiones anteriores, presupuesto y avance del túnel. Sin `--headless`, añadir `-- --capture-ui` al primer proceso genera capturas en `output/ui/mine_tunnel/`. Después ejecutar los dos lectores para restaurar los archivos de validación previos.

La regresión de las seis etapas se ejecuta con `iron_mission_test.tscn` y luego con `-- --read-iron`. No intercalar otras pruebas que escriban partidas entre un escritor y sus lectores.

Resultado verificado: **92 + 6 + 13 comprobaciones** del túnel, casa y ascensor, sin fallos, tanto en ejecución headless como en captura nativa. La misión de seis etapas conserva **102 + 7 comprobaciones** sin fallos. Las partidas de validación usan una aplicación separada de la partida del jugador.

Capturas revisadas: [casa explorable](../../output/ui/mine_tunnel/facil_00_casa.png), [viaje subterráneo](../../output/ui/mine_tunnel/facil_02_descenso.png) y [regreso al interior](../../output/ui/mine_tunnel/facil_06_superficie.png).
