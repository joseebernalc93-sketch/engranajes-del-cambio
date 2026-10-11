# Taller del minero: seis etapas

Implementación del 9 de octubre de 2026, basada en la [propuesta aprobada](propuesta_minero_seis_etapas/seis_etapas_v1.png). La extracción funciona como los talleres manuales de la Fase 1: seis tareas distintas, piezas manipulables y comprobaciones antes de avanzar.

## Entrada y recorrido

Tras cruzar los desprendimientos, caminar al extremo derecho del túnel abre la galería de extracción. **E junto a la veta** abre el taller. «Volver al escenario» permite salir conservando el trabajo; caminar a la izquierda devuelve al túnel del elevador. La exploración mantiene su escala y su barra compartida de monedas e inventario.

| Etapa | Tarea y comprobación |
| --- | --- |
| 1. Reconocer la veta | Mover la lámpara y señalar las tres zonas negras y brillantes; distinguirlas de la pizarra gris. |
| 2. Asegurar el tramo | Encajar un puntal vertical y dos inclinados en sus tres aberturas. Se pueden retirar y recolocar; comprobar valida los apoyos. |
| 3. Extraer el carbón | Tres golpes separados en cada una de las tres vetas. El protagonista mueve la piqueta, las grietas se abren y el material cae en la vagoneta. No hay medidor de fuerza. |
| 4. Separar el material | Arrastrar seis piezas: hulla a la vagoneta y pizarra al cajón. Las piezas aceptadas permanecen separadas tras una corrección. |
| 5. Equilibrar costales | Repartir ocho piezas entre cuatro costales y comparar su peso con una balanza animada. Fácil usa pesos 1/2 y referencia 3; Difícil, pesos 1/2/3/4 y referencia 5. |
| 6. Sacar la carga | Colocar una vía recta y dos curvas, ajustar los dos desvíos y probar el recorrido. La vagoneta lleva los cuatro costales al elevador en 5,5 segundos. |

La etapa 6 usa una carga de cuatro costales apilados en dos filas y sujetos con cuerda, con sombra de contacto, ruedas visibles y balanceo suave del cuerpo al rodar. Las vías completas, las piezas sueltas y los desvíos comparten el mismo ancho y las mismas texturas de traviesas, hierro, placas y tornillos; las curvas enlazan con sus extremos. El vagón ajusta su inclinación al apoyo de ambas ruedas y el protagonista acompaña el asidero. El movimiento visible sigue las curvas y todos sus efectos se detienen al pausar. Este acabado conserva la lógica, las soluciones y el guardado del taller.

El carbón permanece como trabajo en curso hasta terminar el transporte. **Solo la llegada entrega cuatro costales al inventario real** y abre Ensamble del motor. Una nueva pulsación o avance del reloj no duplica la recompensa. La reposición permite volver a realizar el taller hasta disponer de cuatro costales, conservando montaje, tuberías y segundos estables del motor.

La entrega registra la hulla en el glosario, sin añadir carbón suelto a la mochila. Al cargar partidas que ya recibieron los costales se retira la antigua recompensa `hulla`, conservando monedas, costales y progreso. Si el combustible ya se gastó, la corrección tampoco lo repone. Los talleres antiguos reservados conservan su recompensa original.

Los errores de identificación, clasificación o comprobación usan las **15/10 oportunidades compartidas**. «Caleb: revisemos el trabajo» explica cómo corregir y conserva lo aprobado. Soltar una pieza fuera de una abertura y pulsar golpes demasiado seguidos no penaliza. Agotar las oportunidades ofrece una nueva ronda sin borrar las etapas terminadas.

## Controles

Ratón y toque permiten señalar, arrastrar piezas, seleccionar costales y mover las palancas. Los botones inferiores seleccionan herramientas y comprueban el trabajo.

| Acción | Teclado |
| --- | --- |
| Elegir veta, abertura o pieza | Izquierda/derecha o A/D |
| Señalar, golpear o colocar | Espacio o E |
| Elegir puntal o vía | 1–3 |
| Clasificar la pieza seleccionada | C: hulla; X: piedra |
| Elegir costal | 1–4; Espacio coloca la pieza seleccionada |
| Vaciar costal / retirar pieza seleccionada | Retroceso |
| Cambiar desvíos | Q / W |
| Comprobar y continuar | Enter; también hay botón |
| Recorrer botones y activar el seleccionado | Tab / Mayús+Tab; Enter o Espacio |
| Cuaderno / inventario | Esc / I |

Un segundo dedo no sustituye el arrastre activo. Abrir un modal o perder el foco libera la captura. Los botones enfocados conservan su activación de teclado; al cambiar de etapa el foco vuelve al taller.

## Persistencia y compatibilidad

`GameState.phase_two.iron_mission.extraction`, **versión 3**, guarda etapa, vetas reconocidas, puntales, grietas, caída de material, clasificación, asignaciones de peso, vías, desvíos y transporte. Los lotes de reposición usan `refill_extraction`. La selección de herramientas y de costal se guarda en el checkpoint de la vista.

Cuaderno, inventario, revisiones y pérdida de foco detienen todos los relojes. Continuar recupera el transporte desde el instante exacto, incluso con el cuaderno abierto, y nunca restaura un arrastre activo. Los sonidos breves se descartan al pausar.

Las versiones 1 y 2 convierten el carbón aceptado y los golpes anteriores en trabajo equivalente. Una antigua carga completa se conserva como cuatro costales preparados para el último puzzle de entrega; migrar no concede una segunda recompensa. Reiniciar Fase 2 elimina sus etapas y recupera las monedas y objetos de entrada desde Fase 1: **87 monedas en el recorrido normal**.

## Arte y archivos

Los recursos nuevos se generaron con **image_gen integrado**, se copiaron al proyecto y se revisaron dentro de Godot. Los prompts exactos y las referencias quedan junto a los archivos. Se mantienen los sprites originales del protagonista, carbón, pizarra, piqueta y costales.

- [Puntales y piezas de balanza](../../assets/phase2/mining_workshop_tools_v1.png).
- [Vías, palancas y puerta del elevador](../../assets/phase2/mining_rail_parts_v1.png).
- [Banco de clasificación y pesaje](../../assets/phase2/mining_sorting_bench_v1.png).
- [Prompts exactos de esos tres recursos](../../assets/phase2/mining_workshop_prompts_v1.json).
- [Zona de carga con suelo transitable](../../assets/phase2/mining_loading_bay_v1.png) y [prompt exacto](../../assets/phase2/mining_loading_bay_prompt_v1.json).
- [Vagoneta reutilizada](../../assets/phase2/mining_cart_parts_v1.png) y [prompt original](../../assets/phase2/mining_cart_prompt_v1.json).
- [Carga de cuatro costales, versión 2](../../assets/phase2/mining_sack_bundle_v2.png) y [prompt exacto, referencia y modo integrado](../../assets/phase2/mining_sack_bundle_prompt_v2.json).

`scripts/core/coal_extraction.gd` valida las seis etapas. `scripts/puzzles/mining_workshop_board.gd` dibuja piezas y animaciones y recibe ratón, toque y teclado. `coal_extraction_view.gd` organiza el panel, las herramientas, el guardado y las pausas. `scripts/world/mining_workshop_art.gd` recorta los atlas según sus márgenes reales. La escena sigue siendo `scenes/coal_extraction_workface.tscn`.

`scripts/world/mining_transport_art.gd` compone la carga por capas y dibuja los raíles con mallas texturizadas. Reutiliza la textura pixel art de vía existente; mantiene su escala en todos los tramos y calcula las uniones curvas sin deformar el ancho de la vía. La geometría está en una caché limitada, incluida la vista previa al arrastrar.

## Verificación

Usar exclusivamente el proyecto aislado. Ejecutar cada escritor y su lector consecutivamente, sin intercalar otra prueba que escriba partidas; solo continuar si el anterior termina sin errores.

```powershell
$godotExe = 'F:/Descargas/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
./tests/prepare_validation.ps1 -GodotExecutable $godotExe
& $godotExe --path tmp/cart_validation_project res://tests/coal_extraction_test.tscn -- --capture-ui
& $godotExe --headless --path tmp/cart_validation_project res://tests/coal_extraction_test.tscn -- --read-coal
& $godotExe --headless --path tmp/cart_validation_project res://tests/iron_mission_test.tscn
& $godotExe --headless --path tmp/cart_validation_project res://tests/iron_mission_test.tscn -- --read-iron
```

Pasaron **34 comprobaciones del taller y 26 de continuación**, sin fallos. Cubren las seis tareas, teclado y toque, geometría incorrecta, cambios de piezas, clasificación, redistribución, botones enfocados, múltiples dedos, pausas, transporte guardado, recompensa única, migración y reinicio con 87 monedas. Incluyen la entrega sin carbón duplicado, la reparación persistida de partidas anteriores con combustible disponible o consumido y la compatibilidad con los talleres antiguos. La misión completa pasa **104 comprobaciones y 7 de continuación**, incluidas ambas dificultades, reposición y los 120 segundos de presión estable.

Capturas nativas revisadas: [reconocer](../../output/ui/mining_workshop/01_reconocer.png), [puntales](../../output/ui/mining_workshop/02_puntales.png), [extracción](../../output/ui/mining_workshop/03_extraer.png), [separación](../../output/ui/mining_workshop/04_separar.png), [balanza](../../output/ui/mining_workshop/05_equilibrar.png) y [transporte](../../output/ui/mining_workshop/06_transporte.png).

Los tests respaldan y restauran sus archivos de usuario aislados; no usan la partida habitual. Si se interrumpen antes de restaurar, sus opciones `-- --restore-coal` y `-- --restore-iron` recuperan los respaldos pendientes.
