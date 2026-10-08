# Fase 2 · El corazón de hierro

**Estado actual:** estos cuatro talleres se conservan para integrarlos posteriormente en la aventura. La entrada de la Fase 2 ahora recorre la [llegada a Londres](llegada_londres.md): historia, tren, andenes, boletería y ciudad. El complejo junto al canal no tiene acceso desde este recorrido. Las partidas del complejo se redirigen a Londres sin perder sus checkpoints de talleres.

## Recorrido jugable

| Taller | Etapas | Entrega / desbloqueo |
|---|---|---|
| Caleb · Mina | Malla de la lámpara y ventilación; tres vetas; seis golpes rítmicos; criba de seis fragmentos; tres compuertas; cabrestante con freno | Carbón de hulla seleccionado |
| Cort · Pudelado | Carga de arrabio y hogar separado; tres vueltas de rabot; tres escorias; traslado con tenazas; ocho golpes en cuatro caras; enfriamiento y compás | Biela de hierro forjado |
| Murdoch · Motor | Émbolo, empaque y pernos cruzados; tres bridas selladas; excéntrica; tres articulaciones; dos esferas y mariposa; purga y régimen de 15 PSI | Transmisión de vapor habilitada |
| Nave textil | Cuatro correas; cuatro tensores; cuatro embragues; turno de 120 segundos con caldera, hilo, frenado, anudado y relanzamiento | Diez fardos y puesto de fogonero |

Los talleres se habilitan en ese orden. Cada entrega es única y añade una ficha al inventario/glosario. El final ofrece el balance en la página nueva del cuaderno; la página anterior conserva el resumen de la Fase 1.

## Controles

- Caminar: WASD; entrar: E / Espacio. También se puede tocar el letrero de cada taller.
- Herramientas: clic o arrastre táctil sobre lámpara, vetas, piqueta, fragmentos, compuertas, torno, rabot, tenazas, compás, articulaciones y correas.
- Teclado dentro del taller: flechas / WASD ajustan o eligen piezas; Tab / Mayús+Tab recorren las herramientas; Espacio o Enter activan el botón seleccionado. Mantener Espacio recorre el rabot o gira el torno; mantener izquierda/derecha ajusta gradualmente.
- Las agujas y sus franjas verdes muestran el ajuste; las palancas reutilizan el sprite de madera y latón de Silas y Bruno.
- Esc guarda y vuelve al complejo. Durante una revisión se utiliza **Continuar esta fase**. En el complejo, Esc abre el cuaderno; izquierda/derecha cambian de capítulo. Inventario/glosario y menú principal son accesibles desde allí.

## Dificultad, revisiones y memoria

Hay **un presupuesto para toda la Fase 2**, no uno por taller: 15 oportunidades en Fácil y 10 en Difícil. La velocidad de oscilación y del desgaste térmico es 0,25× / 1×; la tolerancia normalizada es ±18% / ±2% del instrumento; el margen crítico es 4 / 1 segundos. El tiro de ventilación utiliza el intervalo específico 50–75 CFM.

Un fallo cobra una oportunidad y pausa la simulación, las herramientas y las partículas. La revisión explica la causa técnica. Continuar conserva etapa, piezas aceptadas, golpes, carga, fardos y montaje. Al agotar el presupuesto, el tutor permite abrir una nueva ronda con el cupo completo sin borrar talleres ni etapas superados. Un intento de golpe no válido no sigue consumiendo oportunidades mientras la revisión esté abierta.

Los checkpoints son diccionarios de valores JSON. Se conservan incluso la revisión pendiente, el telar con hilo roto, las bobinas, el tiempo del turno y la producción. Las pulsaciones sostenidas y los arrastres se liberan al salir o perder foco. La oscilación transitoria de una vagoneta se neutraliza al restaurar para evitar un impacto no provocado por el jugador.

La jornada usa 120 segundos de simulación activa en ambas dificultades. Revisiones, pérdida de foco, salida del taller y parada de emergencia suspenden ese reloj. Si suena el silbato sin diez fardos, una revisión permite un nuevo turno conservando la producción.

## Reporte docente

`user://registro_fase_2.json` se escribe periódicamente en un hilo de trabajo mediante archivo temporal y reemplazo atómico. Incluye dificultad, talleres terminados, oportunidades y rondas, tiempo activo por taller, precisión de presión, paradas de emergencia, fardos, paleadas de carbón, errores y fichas. La precisión refleja la distancia de las muestras respecto al régimen central del instrumento; los tiempos excluyen revisiones y ausencia de foco.

En Windows, `user://` del juego corresponde normalmente a `%APPDATA%/Godot/app_userdata/EngranajesDelCambio/`. La validación utiliza otra aplicación y respalda/restaura sus archivos.

## Verificación

Preparar/importar una vez desde la raíz del proyecto:

```powershell
./tests/prepare_validation.ps1 -GodotExecutable godot
godot --headless --path tmp/cart_validation_project res://tests/phase2_factory_test.tscn
```

La suite recorre los cuatro talleres en ambas dificultades a través de sus controladores reales. Verifica checkpoints en cada etapa, presupuesto compartido, errores y recuperación, agotamiento, teclado/táctil, presión, ventilación, jornada completa, recompensas únicas, reporte de fondo, cuaderno y ventana pequeña.

Resultado final: **296 comprobaciones correctas** en modo headless y con renderizado real. Los demás recorridos y el comando con la ruta de Godot de esta máquina están en [validacion.md](validacion.md).

Guardado entre procesos independientes:

```powershell
godot --headless --path tmp/cart_validation_project res://tests/phase2_session_test.tscn
godot --headless --path tmp/cart_validation_project res://tests/phase2_session_test.tscn -- --read-phase2
```

Flujo real desde el tren, introducción y cuaderno entre capítulos:

```powershell
godot --headless --path tmp/cart_validation_project res://tests/chapter_journal_flow_test.tscn
godot --headless --path tmp/cart_validation_project res://tests/chapter_journal_flow_test.tscn -- --read-chapter
```

Capturas con renderizado real OpenGL:

```powershell
godot --path tmp/cart_validation_project res://tests/phase2_factory_test.tscn -- --capture-phase2
```

Las imágenes de comprobación se guardan en `output/ui/phase2/`. La simulación es determinista; se acelera la ejecución de pruebas, no el reloj productivo exigido al jugador.

## Recursos y estructura

Los archivos solicitados están en `scenes/story/`, `scenes/`, `scripts/story/`, `scripts/puzzles/`, `scripts/core/`, `shaders/` y `tests/`. `factory_work_state.gd` contiene la simulación; `factory_stage_catalog.gd`, las consignas; `factory_workbench.gd`, la interacción y el dibujo; `factory_puzzle_popup.gd`, el presupuesto, revisión y controles. Las cuatro escenas usan controladores específicos y construyen su jerarquía al entrar al árbol.

Se generaron doce PNG nuevos mediante la herramienta integrada **image_gen**: cuatro viñetas, complejo, cuatro fondos de taller, una variante sin correas para el montaje textil y dos atlas transparentes. Están en `assets/phase2/`; los prompts exactos están en [generation_prompts_v1.json](../../assets/phase2/generation_prompts_v1.json). Se revisaron visualmente e integraron como texturas y regiones de atlas, sin modificar los originales de la Fase 1. Los tres shaders usan tiempo de simulación explícito para poder pausarlos.

## Criterio histórico

La fase reúne tecnologías de los siglos XVIII y XIX como reconstrucción didáctica; los tutores presentan los oficios y avances, no una reunión biográfica de inventores en una fecha concreta. Las cantidades, CFM, tolerancias y 15 PSI son parámetros del juego.

- El combustible se coloca en el hogar separado del horno de reverbero, no mezclado con la solera: [Historic England](https://historicengland.org.uk/research/results/reports/4598/ANINVESTIGATIONINTOTHETECHNOLOGICALPROCESSUSEDTOPRODUCEDAVIDHARTLEYSFIRE-PLATING).
- Darby y el empleo del coque desde 1709: [Ironbridge Gorge Museum Trust](https://www.ironbridge.org.uk/our-story/the-iron-bridge/).
- La lámpara de Davy y el papel de su malla se contrastaron con [Science Museum Group](https://collection.sciencemuseumgroup.org.uk/objects/co509748/davy-lamps) y [Royal Institution](https://www.rigb.org/explore-science/explore/collection/humphry-davys-miners-safety-lamp).
- El condensador separado de Watt: [National Museums Scotland](https://blog.nms.ac.uk/2019/08/25/james-watt-2019-a-double-anniversary/).
- El martinete de vapor pertenece a un desarrollo posterior, asociado a Nasmyth desde 1839: [Science Museum Group](https://collection.sciencemuseumgroup.org.uk/objects/co46229/nasmyths-steam-hammer-steam-hammer).

El objetivo curricular y las páginas 54–56 proceden del encargo. No se ha recibido el libro para contrastar su redacción literal.
