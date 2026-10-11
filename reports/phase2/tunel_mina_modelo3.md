# Túnel de la mina: modelo 3 integrado

Implementación del 8 de octubre de 2026. El modelo elegido sustituye la gran sala de la galería por un túnel lateral de madera reforzada con hierro, lámparas cálidas y carbón oscuro. El protagonista conserva sus sprites; dentro de la mina se muestra a escala 1,8 para que el techo tenga unas dos alturas de personaje. El patio mantiene su escala habitual y la casa del pozo comparte la escala del túnel.

## Recorrido y escombros

En superficie, Caleb explica el trabajo. E en la puerta del castillete abre la casa del pozo; el ascensor interior inicia el descenso. Véase [casa del pozo](casa_del_pozo.md). En el túnel solo funcionan izquierda/derecha o A/D; clic y toque se proyectan a la misma línea de suelo. Arriba/abajo no permiten esquivar los desprendimientos por otra fila. La velocidad se ajusta a la vista cercana del túnel.

El elevador queda en el comienzo izquierdo. Hay tres zonas separadas: primero polvo y crujidos, después piedras grises pequeñas, un rebote breve y el despeje del tramo. Las piedras miden entre 8 y 18 píxeles frente a un personaje de unos 108; no son bloques gigantes. Los ciclos están desplazados y nunca caen las tres zonas a la vez. El aviso dura 2,5 segundos en Fácil y 1,6 en Difícil; la caída ocupa 2,3 segundos y el asentamiento 0,5. El último tramo da acceso a la veta y al minijuego de extracción/clasificación existente.

Un impacto gasta una oportunidad compartida y devuelve al espacio seguro anterior. La explicación pausa herramientas y escombros y evita descuentos repetidos. Continuar mantiene los tramos aprobados, carbón, montaje del motor y tiempo del ensayo. E cerca de la jaula izquierda permite subir. Desde el 9 de octubre, el extremo derecho lleva caminando a una [galería nueva con veta interactiva](veta_interactiva.md); caminar a la izquierda desde ella devuelve al túnel original.

## Elevador visible y guardado

El viaje dura **9,4 segundos**: entrar (0–1,3), cerrar compuerta (1,3–2), recorrer el pozo (2–7,6), abrir (7,6–8,2) y salir (8,2–9,4). La jaula y el protagonista se mueven juntos; el tramo central usa un fondo exclusivo del pozo vertical, con lámparas y guías desplazándose junto a la cabina. Un fundido breve conecta los encuadres de entrada, viaje y llegada. La subida invierte el desplazamiento. Los pasos de entrada/salida reutilizan los sprites de caminar del protagonista y la compuerta deja visible la cabeza.

Cuaderno, inventario y pérdida de foco pausan el viaje, incluido su sonido. El checkpoint conserva `lift_elapsed`, `lift_returning` y `lift_start` con `arrival_version: 5`; cualquier fotograma se reconstruye desde esos datos. Se evita activar el elevador dos veces durante el trayecto. Los checkpoints de la galería antigua se proyectan al nuevo suelo; los viajes antiguos de siete segundos se convierten proporcionalmente. No se modifica el presupuesto ni se cobran monedas por usar el elevador.

## Recursos

Arte creado con **image_gen integrado**, a partir del modelo seleccionado, y guardado en el proyecto:

- [Fondo del túnel](../../assets/phase2/mine_tunnel_iron_v1.png), sin personaje ni partículas incrustados.
- [Jaula, compuerta, polea y piedra](../../assets/phase2/mine_lift_parts_v1.png), atlas transparente; sus regiones respetan las proporciones reales generadas.
- [Patio de superficie](../../assets/phase2/mine_yard_pixel_v3.png), con puerta hacia la casa del pozo.
- [Prompts del túnel y las piezas](../../assets/phase2/mine_tunnel_model3_prompts_v1.json) y [edición de superficie](../../assets/phase2/mine_yard_lift_prompt_v2.json).

Los scripts nuevos son `scripts/world/mine_art.gd`, `mine_lift_rig.gd` y `mine_lift_sequence.gd`. `mine_hazards.gd` reconstruye los escombros desde el reloj de la misión, sin partículas imposibles de restaurar. `london_arrival.gd` integra entradas, movimiento, pausas y guardado. La llegada del coche y el panel de extracción también usan los nuevos fondos.

## Verificación

Ejecutar exclusivamente en el proyecto aislado para proteger la partida habitual:

```powershell
$godotExe = 'F:/Descargas/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
./tests/prepare_validation.ps1 -GodotExecutable $godotExe
& $godotExe --headless --path tmp/cart_validation_project res://tests/mine_tunnel_test.tscn
& $godotExe --headless --path tmp/cart_validation_project res://tests/mine_tunnel_test.tscn -- --read-descent
& $godotExe --headless --path tmp/cart_validation_project res://tests/mine_tunnel_test.tscn -- --read-ascent
```

Los tres procesos van en orden, sin ejecutar otras pruebas que escriban partidas entre ellos. El primero prueba ambas dificultades y deja un descenso a mitad con el cuaderno abierto; el segundo continúa ese descenso y deja una subida pausada en el inventario; el tercero continúa la subida y restaura los archivos previos. `-- --restore-tunnel` permite restaurar el respaldo tras una interrupción.

Para revisar la animación, ejecutar el primer proceso sin `--headless` y con `-- --capture-ui`; las capturas quedan en `output/ui/mine_tunnel/`. Los lectores se ejecutan después normalmente. Resultado: **92 comprobaciones del túnel y elevador**, **6 de continuación del descenso** y **13 de continuación de la subida**, sin fallos. La misión de seis etapas mantiene **102 + 7 comprobaciones**, incluido el ensayo completo de dos minutos en Fácil y Difícil.
