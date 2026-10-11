# La pieza que dará movimiento

Taller jugable de seis fases, rediseñado el 10 de octubre de 2026 a partir de la [propuesta interactiva aprobada](propuesta_cort_interactivo_v2/propuesta.md). Entra en la fundición y habla con Cort; «Trabajar con Cort» abre el taller. Puedes salir y volver sin perder el trabajo. La mesa ocupa el panel; las herramientas se manipulan directamente y la ayuda larga se consulta con H.

| Fase | Trabajo del jugador |
| --- | --- |
| 1. Medir y sujetar | Arrastrar una barra, colocar la regla junto a su borde, cerrar el calibre y girar o mantener las dos mordazas. El pedido indica largo 120 y grosor 30. |
| 2. Repartir el calor | Mover la barra sujeta entre las mordazas de las tenazas y girar el volante circular del aire. Tres instrumentos muestran aguja, franja ideal y estado de cada tercio. Con las tres zonas en punto se aprueba y se detiene el horno; se mantienen los indicadores aprobados y se habilita Continuar. El metal sigue sólido. |
| 3. Forjar con matrices | Arrastrar matrices al yunque y deslizar el hierro hasta sus topes. Cada tirón de palanca produce un golpe y modifica la zona trabajada. Debe soltarse para repetir. Vapor y escamas acompañan el impacto. |
| 4. Taladrar con control | Fijar la biela, girar el tornillo de avance, montar la broca fina o gruesa y mantener/soltar la palanca. El husillo se extiende y mantiene el mandril y la broca en el mismo eje. Los centros reales del sprite coinciden con ese eje en cada tope. Polea, reflejos y hélices giran; virutas curvas nacen en el contacto con el hierro. Dos instrumentos conservan la profundidad; avanzar demasiado tiempo produce vibración y reduce el corte. La broca debe retirarse antes de mover la mesa. |
| 5. Limar y comprobar | Dar pasadas hacia delante sobre rebabas visibles; volver atrás prepara otra pasada. La plantilla identifica el punto que roza sin gastar oportunidades. Fácil requiere tres pasadas por zona y Difícil cuatro. |
| 6. Probar con manivela | Montar la biela y pasadores, corregibles también con ratón. El volante conserva su forma circular; ambos ojos permanecen unidos al pistón y al punto excéntrico en todo el giro. Bandejas muestran las piezas; dos instrumentos de aguja registran recorrido y carga. Un freno con escala y franja suave permite comprobar al menos una vuelta con carga y tres vueltas de recorrido. El freno excesivo atasca y se puede aflojar. Esperar o confirmar no completa la prueba. |

Cada fase tiene ratón/toque y alternativas de teclado. H abre la ayuda y pausa la simulación; Tab recorre Volver, Ayuda y Comprobar. Los arrastres y teclas sostenidas se liberan al pausar o perder foco. La vista mantiene el marco, inventario, monedas y diálogo compartidos.

| Fase | Teclado |
| --- | --- |
| Medición | 1–3: barra; Espacio: colocar; R: regla; C: calibre; mantener Q/E: cada mordaza. |
| Horno | Espacio: introducir; mantener izquierda/derecha: tenazas; arriba/abajo: aire. Al tener las tres zonas en punto se detiene el calor. Botón Continuar o Enter: pasar a forjar. T antes de tiempo solo orienta, sin gastar oportunidades. |
| Martillo | Izquierda/derecha: zona y tope; 1–3: matriz; pulsar y soltar Espacio: golpe. |
| Taladro | C: fijar; izquierda/derecha: avance; 1/2: broca; mantener/soltar Espacio: cortar/retirar. |
| Acabado | Izquierda/derecha: zona; Espacio: pasada; T: comprobar plantilla. |
| Transmisión | E: montar; 1/2: pasadores; arriba/abajo: freno; mantener/soltar Espacio: girar/parar. |

## Conexión con el motor

La fundición aporta hierro y combustible. **No consume monedas ni costales**. Tras aprobar la prueba se añade una sola `biela` a la mochila, con su sprite perforado y descripción. Murdoch ofrece entregarla e instalarla antes de abrir los engranajes. Cancelar conserva la pieza. Confirmar la retira de la mochila y marca `biela_installed`; los cuatro costales siguen disponibles para el encendido y la prueba de presión de **120 segundos**.

Ejecutar una operación inválida gasta una oportunidad compartida (15 en Fácil, 10 en Difícil), abre una revisión de Cort y conserva el trabajo. Preparar herramientas, alinear, probar el encaje, intentar retirar antes de calentar o aflojar el freno permite corregir sin penalización. El horno aprueba en cuanto las tres zonas están listas, antes de añadir más calor; retira la barra, congela sus temperaturas y espera a Continuar. Esperar, volver a accionar las herramientas o continuar una partida no sobrecalienta una barra aprobada. Agotar el presupuesto permite otra ronda sin repetir fases. No avanza la simulación con ayuda, cuaderno, inventario o revisión abiertos, fuera del taller o sin foco.

El estado versión 2 vive en `GameState.phase_two.foundry`: medidas, mordazas, calor de tres zonas, aprobación del horno (`heat_approved`), matrices, golpes, profundidades independientes, acabado, montaje y vueltas con/sin carga. Continuar conserva el panel, modales y trabajo, sin restaurar gestos sostenidos. Los estados versión 1 migran conservando fases, agujeros y recorrido de la prueba anterior; requieren un gesto nuevo para mover máquinas. Reiniciar Fase 2 limpia el taller y recupera el saldo de entrada. Las forjas completadas se reconocen sin otra recompensa.

## Arte y código

Recursos generados con **image_gen integrado**, conservando los originales. Los recortes y transformaciones de sprites se hacen al dibujar dentro de Godot.

- [Banco de trabajo](../../assets/phase2/foundry_workbench_v1.png), [horno](../../assets/phase2/foundry_reheating_hearth_v1.png), [martillo](../../assets/phase2/foundry_steam_hammer_bay_v1.png) y [taladro](../../assets/phase2/foundry_belt_drill_bay_v1.png).
- [Materiales y herramientas](../../assets/phase2/foundry_materials_atlas_v1.png), [componentes mecánicos](../../assets/phase2/foundry_machine_parts_atlas_v1.png).
- [Prompts exactos y referencias](../../assets/phase2/foundry_workshop_prompts_v1.json).
- Nuevas [herramientas de hierro, latón y madera](../../assets/phase2/foundry_interactive_tools_v2.png): mordaza, calibre por piezas, regla, manivela, palanca, freno y plano. [Prompt exacto y original](../../assets/phase2/foundry_interactive_tools_prompts_v2.json).
- Modelo: `scripts/core/foundry_workshop.gd`; vista y tablero: `scripts/puzzles/foundry_workshop_*.gd`; recortes: `scripts/world/foundry_workshop_art.gd`; escena: `scenes/foundry_workshop.tscn`.
- El informe docente incorpora `taller_de_cort`, tiempo de trabajo, errores, recompensa e instalación.

## Validación

Usar el proyecto aislado, con cada escritor seguido inmediatamente de su lector:

```powershell
$godotExe = 'F:/Descargas/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
./tests/prepare_validation.ps1 -GodotExecutable $godotExe
& $godotExe --path tmp/cart_validation_project res://tests/foundry_workshop_test.tscn -- --capture-ui
& $godotExe --headless --path tmp/cart_validation_project res://tests/foundry_workshop_test.tscn -- --read-workshop
& $godotExe --headless --path tmp/cart_validation_project res://tests/iron_mission_test.tscn
& $godotExe --headless --path tmp/cart_validation_project res://tests/iron_mission_test.tscn -- --read-iron
```

Validación del rediseño: **108 + 17** comprobaciones del taller y **108 + 7** del recorrido completo mina–fundición–motor: **240 comprobaciones sin fallos**. Cubren ambas dificultades, medición por arrastre, mordazas sostenidas, matrices y topes, avance circular del taladro, corte parcial, pasadas de lima, corrección de pasadores solo con ratón, giro manual, freno, pausa y continuación entre procesos. El horno comprueba retirada anticipada sin penalización, aprobación que detiene el calor y espera al botón Continuar, protección de una barra lista ante un fotograma largo, liberación de las tenazas al aprobar y el área circular de interacción del volante. Verifican además el centrado visible de ambos ojos del taladro, el contacto de la broca y el giro del husillo, la conservación del radio circular y longitud de la biela durante cuatro ángulos de giro, y el guardado de la aprobación térmica. También verifican recompensa única, entrega/cancelación, combustible, migración y reinicio. Los lectores restauran los archivos del usuario aislado. Si se interrumpe una prueba, `--restore-workshop` o `--restore-iron` recuperan su respaldo.

Capturas nativas revisadas del rediseño: [hierro](../../output/ui/foundry_workshop_v2/facil_01_hierro.png), [horno](../../output/ui/foundry_workshop_v2/facil_02_horno.png), [martillo](../../output/ui/foundry_workshop_v2/facil_03_martillo.png), [taladro](../../output/ui/foundry_workshop_v2/facil_04_taladro.png), [ajuste](../../output/ui/foundry_workshop_v2/facil_05_ajuste.png) y [transmisión](../../output/ui/foundry_workshop_v2/facil_06_transmision.png).

Detalle de la corrección del horno: [pinza sujetando hierro e instrumentos térmicos](../../output/ui/foundry_workshop_v2/facil_02_pinza_1.png) y [desplazamiento con giro del volante](../../output/ui/foundry_workshop_v2/facil_02_pinza_2.png). La pinza se dibuja en dos capas, con la mordaza superior detrás del hierro y la inferior delante. El volante y los instrumentos compensan la escala del tablero para conservar su proporción.

Corrección de alineación y presentación: [broca fina perforando](../../output/ui/foundry_workshop_v2/facil_04_perforando.png), [broca gruesa perforando](../../output/ui/foundry_workshop_v2/facil_04_perforando_gruesa.png), [transmisión articulada](../../output/ui/foundry_workshop_v2/facil_06_articulacion.png) y [horno aprobado a la espera de Continuar](../../output/ui/foundry_workshop_v2/facil_02_aprobado.png). La geometría de corte procede de los centros del sprite ajustado a su rectángulo real. La transmisión se resuelve en coordenadas de pantalla con escala uniforme para evitar deformaciones y separaciones entre los anclajes. Los marcadores de las seis fases y los controles conservan tipografía proporcionada.
