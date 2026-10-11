# El pozo minero y el ensamble del motor

Implementación del 8 de octubre de 2026. Una misión de seis etapas une la exploración de la mina, la gestión del carbón y el arranque de la fábrica. El enclave minero es ficticio, inspirado en las cuencas británicas; no representa una explotación histórica del centro de Londres.

## Recorrido jugable

William ofrece **Ensamble del motor**, **El pozo minero** y **La forja y fundición** en su selector de cuatro destinos. El destino independiente de Nave Textil sigue reservado. La [fundición industrial](fundicion_industrial.md) permite explorar su patio y taller y fabricar una biela con Cort en un [puzzle de seis fases](taller_de_cort.md). El coche cuesta 10 monedas y conserva el regreso incluido, la animación de 40 segundos y la continuación del viaje pagado. El checkpoint guarda también su destino; las partidas anteriores toman Ensamble del motor por defecto.

En el patio, acercarse a Caleb permite conversar con el panel compartido de la Fase 1. E en la puerta permite entrar a la casa del pozo; su ascensor inicia un descenso visible de 9,4 segundos dentro de un pozo independiente. Al subir se regresa a la casa y su puerta permite salir al patio. Véase [casa del pozo](casa_del_pozo.md). El túnel usa el modelo 3 de madera, hierro y carbón, con techo proporcionado al protagonista y movimiento exclusivo hacia izquierda/derecha. Tres tramos de piedras pequeñas obligan a observar los avisos de polvo y crujidos, esperar y cruzar al quedar libres. El elevador está al comienzo izquierdo y E permite subir. Los impactos pausan la acción con una explicación y conservan los tramos superados. Véanse [arte, animación y pruebas del túnel](tunel_mina_modelo3.md).

Después de extraer carbón, salir del pozo y caminar hacia la izquierda del patio lleva al patio industrial sin otro pago. Caminar hacia arriba frente a la entrada central del edificio conduce a la sala del motor. Antes del montaje de engranajes, Murdoch solicita la biela: se fabrica en la fundición, a la izquierda del patio industrial. Cort usa combustible propio y reserva los costales para la caldera. Entregar la biela la instala y abre las herramientas del motor. Tras el ensayo, caminar a la derecha permite observar los telares animados; este acceso final no abre el antiguo puzzle textil reservado.

## Seis etapas

| Etapa | Interacción y validación |
| --- | --- |
| 1. Encontrar el camino | Movimiento horizontal real, tres tramos de avance y espera ante desprendimientos anunciados. |
| 2. Recolectar combustible | Galería a la derecha del túnel. Taller de seis pasos: reconocer hulla, asegurar con puntales, extraer con piqueta, clasificar, equilibrar costales y completar vías y desvíos. La vagoneta entrega cuatro costales al llegar al elevador. Véase [taller del minero](veta_interactiva.md). |
| 3. Ensamblar engranajes | Fabricar y entregar la biela de Cort. Después, tres diámetros se colocan en sus ejes. Se pueden retirar y recolocar. Una prueba animada de manivela verifica la transmisión. |
| 4. Conectar tuberías | Seis segmentos giratorios cierran dos circuitos independientes: alimentación de la caldera y refrigeración del condensador. Las conexiones se validan mediante puertos N/E/S/O. |
| 5. Encender la máquina | Agua preparada, carbón real en el hogar y reserva suficiente antes de encender. |
| 6. Mantener la presión | Modelo de fuego, combustible y descarga de vapor. Cuenta 120 segundos de presión segura, con aguja analógica y palanca pixel art. |

Cada costal tiene seis paladas. Abrirlo retira un costal completo y guarda las porciones restantes en el estado de la misión. Cada palada modifica el fuego y las métricas. No se restaura carbón gastado al reintentar. Caleb permite extraer otro lote hasta disponer de cuatro costales completos, conservando engranajes, tuberías y tiempo estable; el camino gratuito entre mina y motor evita depender de otro pasaje.

Cerrar la descarga conserva vapor, pero no genera calor: un hogar sin combustible pierde presión aunque la válvula esté cerrada. El panel avisa cuando no quedan paladas y orienta al jugador para reabastecerse.

Fácil y Difícil usan las **15/10 oportunidades compartidas de la Fase 2**. Cambian aviso de desprendimiento, separación mínima de golpes, margen de presión y tiempo permitido fuera de la zona segura. Un fallo abre «Revisemos el trabajo», detiene herramientas y conserva etapas superadas. A cero oportunidades, una nueva ronda recupera el presupuesto sin borrar el montaje ni las porciones restantes.

## Controles y persistencia

- Exploración: Flechas/WASD, clic o toque para caminar; E/Espacio para interactuar cerca.
- Taller minero: señalar y arrastrar vetas, puntales, materiales y vías; comparar los costales en una balanza y cambiar dos desvíos. Flechas/A/D seleccionan, 1–4 elige pieza o costal, Espacio coloca o golpea y Enter comprueba. En el motor se arrastran engranajes, se tocan tubos para girarlos y se arrastra la palanca para descargar vapor.
- Teclado: Tab/Mayús+Tab recorre botones; Enter activa el botón. Flechas/A/D seleccionan piezas o ajustan la descarga, W/S cambia la rueda seleccionada, Espacio golpea, coloca, gira o alimenta según la etapa. Todos los comandos tienen botones accesibles.
- Esc abre el cuaderno de seis etapas. Inventario, cuaderno y pérdida de foco pausan la simulación. Salir al escenario también detiene el ensayo mientras el panel está cerrado.

El estado JSON vive en `GameState.phase_two.iron_mission`: galería recorrida, extracción, piezas, tuberías, agua, fuego, porciones, presión, oportunidades mediante el capítulo, revisión y segundos estables. El checkpoint de Londres conserva mapa, posición, panel abierto, cuaderno, destino del coche e instante del elevador. Los identificadores enteros se normalizan después de leer JSON. Se liberan los arrastres al pausar o continuar. No se modifica la versión global del guardado: los campos nuevos tienen valores predeterminados y las partidas de la Fase 1 conservan sus datos.

`registro_fase_2.json` incluye la misión, combustible consumido, muestras de presión, errores, oportunidades y resultado del ensayo. Completar entrega la transmisión de vapor una sola vez y pone en marcha la nave textil.

## Recursos y código

Arte creado con **image_gen integrado**:

- [Patio del pozo, versión actual](../../assets/phase2/mine_yard_pixel_v3.png). Las versiones iniciales se retiraron en la limpieza del 11 de octubre de 2026.
- [Caleb, minero](../../assets/phase2/caleb_miner_pixel_v1.png), ajustado a la altura visible del protagonista.
- [Piezas finales](../../assets/phase2/iron_mission_parts_pixel_v2.png): engranajes, tubos, costal y válvula. La segunda versión corrige el codo para que tenga dos aberturas.
- [Prompts originales](../../assets/phase2/iron_mission_prompts_v1.json) y [prompt de edición del atlas](../../assets/phase2/iron_mission_parts_v2_prompt.json).

Se reutilizan los fondos `mine_pixel_v1.png`, `engine_pixel_v1.png` y `textile_pixel_v1.png`, la palanca ilustrada de Silas y las herramientas de la Fase 2. El shader `shaders/coal_fire.gdshader` anima fuego pixelado con un reloj suministrado por el juego, que se detiene al pausar.

La lógica está en `scripts/core/iron_mission.gd`; herramientas en `scripts/puzzles/iron_mission_popup.gd` e `iron_mission_board.gd`; escena en `scenes/iron_mission_puzzle.tscn`. `london_arrival.gd` conecta los mapas y los modales. `mine_hazards.gd` y `textile_production.gd` dibujan desprendimientos y mecanismos animados.

## Verificación

Usar el proyecto aislado; los tests rechazan la aplicación normal para proteger la partida del jugador:

```powershell
$godotExe = 'F:/Descargas/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
./tests/prepare_validation.ps1 -GodotExecutable $godotExe
& $godotExe --headless --path tmp/cart_validation_project res://tests/iron_mission_test.tscn
& $godotExe --headless --path tmp/cart_validation_project res://tests/iron_mission_test.tscn -- --read-iron
```

Ejecutar en orden y solo lanzar el lector si el escritor termina correctamente. El escritor recorre las seis etapas en ambas dificultades, incluyendo errores, recuperación, presupuesto agotado, reabastecimiento, consumo real y el ensayo completo de 120 segundos. El lector abre otro proceso y verifica mapa, montaje, combustible, cuaderno y tiempo exacto. Los archivos previos se respaldan y restauran al finalizar el lector. Tras una interrupción del test, `-- --restore-iron` restaura su respaldo pendiente.

La revisión del taller minero pasa **104 comprobaciones de misión y 7 de lectura**, sin fallos, con ambas dificultades, reposición y ensayo completo. Sus pruebas específicas añaden **34 comprobaciones nativas y 26 de lectura**, incluida la corrección del carbón duplicado en la mochila. Véanse [recursos, capturas y validación del taller](veta_interactiva.md). La importación de recursos termina sin errores.

Para capturas e interacción con ratón/toque, ejecutar el escritor sin `--headless` y añadir `-- --capture-ui`, seguido del lector normal. Las imágenes quedan en `output/ui/iron_mission/` y los registros en `output/iron_*.log`.
