# Fase 2: llegada explorable a Londres

Implementación del 7 de octubre de 2026; personajes e interacción actualizados el 8 de octubre de 2026. Godot 4.7.2, renderizado Compatibility.

## Recorrido jugable

La salida del tren en la Fase 1 conserva su resumen. Seguir explorando abre las cuatro páginas narradas del viaje. Ya no se presenta una visita anticipada a los talleres: la narración prepara la llegada y la orientación por la estación.

La escena `scenes/london_arrival.tscn` reproduce 9,5 segundos de llegada: entrada y frenado del tren, ruedas vinculadas al desplazamiento, vapor, señal sonora, apertura de puerta y descenso del protagonista. Después devuelve el control en los andenes. El cuaderno y la pérdida de foco pausan la animación, las partículas y el sonido.

Tres mapas conectados:

1. **Andenes:** únicamente el protagonista y Henry, encargado del tren. Henry explica la salida. Caminar al extremo derecho conduce al vestíbulo sin exigir una conversación previa. Las colisiones separan el área caminable de las vías.
2. **Boleterías:** únicamente el protagonista y Arthur, el empleado de uniforme. Arthur aclara que salir no requiere otro pasaje. Se puede observar el reloj. La puerta izquierda vuelve a los andenes y la derecha sale a la ciudad.
3. **Londres:** Edward atiende su puesto de periódicos en el rincón izquierdo y Rose espera junto al carruaje de época en el derecho. Los personajes igualan la altura visible del protagonista, descontando los márgenes transparentes de sus sprites. El puesto tiene colisión y se puede tocar para acercarse al vendedor. La entrada de la estación permite regresar. Los talleres no tienen entradas ni botones en este recorrido.

## Controles y memoria

- Flechas/WASD: caminar. Clic o toque: dirigirse a un punto; tocar un personaje aproxima al protagonista y abre la conversación.
- E/Espacio: interacción cercana. Al acercarse aparece el mismo aviso «E Hablar con…» de la Fase 1; al alejarse desaparece. El panel de diálogo, nombre, texto y botón Continuar también reutilizan el HUD de la Fase 1. No hay nombres flotantes sobre los personajes.
- Caminar hasta un extremo del pasillo cambia de mapa: derecha de los andenes, izquierda/derecha de las boleterías. En la calle se vuelve a entrar caminando hacia la puerta de la estación. Las salidas no tienen rótulos ni requieren pulsar E.
- Escape: cuaderno o cierre del inventario/diálogo. Izquierda/derecha: páginas de capítulos. Tab/Shift+Tab recorre los controles del panel abierto. Enter/Espacio activa el botón enfocado.
- I o botón Inventario: el mismo inventario ilustrado, glosario y barra de monedas de la Fase 1. Se conserva la pestaña y el objeto seleccionados al continuar; abrirlo pausa la exploración y la llegada del tren.
- Reiniciar fase 2 requiere confirmación y vuelve al relato inicial y la llegada del tren; preserva Fase 1, dificultad y checkpoints de talleres.
- Volver a fase 1 regresa al criadero con los cuatro puzzles completados. Desde la pausa del campo o Fases desbloqueadas en el título se puede continuar Londres en su propio punto de guardado. Continuar en el título restaura la última fase visitada exactamente donde quedó.

`scripts/world/london_journey.gd` mantiene descubrimientos y conversaciones en `GameState.phase_two.arrival`. `london_arrival.gd` guarda el mapa, coordenadas, orientación, instante de la llegada, diálogo pendiente y página/visibilidad del cuaderno. Los puntos de navegación y las pulsaciones son transitorios. El guardado versión 17 incorpora `chapter_checkpoints` con un punto por fase y mantiene `checkpoint` como la sesión más reciente para Continuar. Los guardados anteriores crean el índice desde su sesión existente; las sesiones del antiguo complejo migran a la llegada sin borrar piezas, oportunidades o avances de sus puzzles.

El cuaderno muestra cuatro descubrimientos de viaje y el objetivo actual, mantiene la dificultad y permite volver al resumen congelado de Fase 1. La exploración no resta oportunidades: el presupuesto de Fácil (15) o Difícil (10) queda disponible para los futuros talleres.

Durante la exploración aparece la barra de monedas e inventario y, únicamente cerca de alguien, el aviso para hablar. El título, la dificultad y el objetivo se consultan en el cuaderno; no se muestran instrucciones permanentes, nombres de mapas, carteles de salidas ni mensajes automáticos al llegar a la calle. El HUD compartido utiliza `inventory_only` y su señal `local_dialogue_action` para que Londres conserve su propio cuaderno y los resultados de sus conversaciones. Los diálogos pendientes se guardan sin duplicarlos en el estado del inventario; al cargar partidas anteriores se descartan las conversaciones de los personajes retirados.

## Arte y alcance histórico

Recursos creados con **image_gen integrado**, copiados al proyecto:

- `assets/phase2/london_platform_pixel_v1.png`
- `assets/phase2/london_ticket_hall_pixel_v1.png`
- `assets/phase2/london_street_pixel_v1.png`
- `assets/phase2/london_people_pixel_v1.png` (atlas transparente 2×2: mozo, vendedor, vecina y viajero).
- `assets/phase2/london_news_stall_pixel_v1.png` (puesto transparente de madera, toldo y periódicos; generado con la herramienta integrada imagegen el 8 de octubre).
- `assets/phase2/london_staff_pixel_v2.png` (dos empleados distintos: Henry con bigote y uniforme burdeos; Arthur con gafas y uniforme verde oscuro).

El prompt íntegro de los uniformes se guarda en `assets/phase2/london_staff_generation_v2.json`. El atlas usa dos celdas horizontales, con la silueta y proporciones del protagonista como referencia. Los cuatro NPC igualan la altura opaca del protagonista: `sprite_body_bounds.gd` mide píxeles con alfa ≥ 0,5 y descarta los residuos casi transparentes que hacían pequeños a Edward y Rose. Se conservan las proporciones de cada figura y se cachean texturas y medidas al cambiar de mapa.

El prompt íntegro del nuevo puesto se guarda en `assets/phase2/london_news_stall_generation_v1.json`. El carruaje de la esquina derecha se reutiliza del escenario de Londres existente. Las dos figuras retiradas del interior permanecen en el atlas de archivo, sin instanciarse en los mapas. Desde el extremo inferior de la plaza se accede ahora a la [parada de coches y al distrito industrial](coches_londres.md), con un trayecto animado de 40 segundos y tarifa de 10 monedas.

Los prompts de los escenarios están en `assets/phase2/london_generation_prompts_v1.json`. Se reutilizan protagonista, tren, vapor y marcos del juego. La ambientación se inspira en Londres hacia 1850 y en estaciones tempranas como Euston, inaugurada en 1837; es una composición didáctica, no una reconstrucción exacta del edificio. Referencia: [Network Rail, historia de Euston](https://www.networkrail.co.uk/who-we-are/our-history/iconic-infrastructure/the-history-of-london-euston-station/).

`scenes/phase2_hub.tscn` y sus cuatro talleres quedan reservados para desarrollo; no se borran. Las fábricas y sus desafíos se integrarán posteriormente en la ciudad.

## Verificación

Preparar el proyecto aislado y ejecutar los dos procesos, en este orden:

```powershell
$godotExe = 'F:/Descargas/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
./tests/prepare_validation.ps1 -GodotExecutable $godotExe
& $godotExe --headless --path tmp/cart_validation_project res://tests/london_arrival_test.tscn
& $godotExe --headless --path tmp/cart_validation_project res://tests/london_arrival_test.tscn -- --read-london
```

La primera ejecución realiza **142 comprobaciones** en ambas dificultades: relato, tren, pausa/foco, colisiones, eventos reales de cursor y toque, reparto de personajes, altura opaca medida independientemente, regresión de bordes casi transparentes, uniformes distintos, puesto interactivo, aviso de proximidad, diálogo compartido, Continuar real, conversación pendiente, salidas caminando por los extremos, ausencia de etiquetas, monedas, inventario, cuaderno, adaptación de tamaño y guardado. La segunda realiza **15 comprobaciones** de Continuar desde otro proceso, ubicación/orientación exactas, descubrimientos, dificultad, cuaderno e inventario abiertos, pestaña/objeto seleccionados, vuelta al título y migración del complejo anterior. Los tests solo se permiten en el proyecto aislado y respaldan/restauran sus datos de usuario.

También pasaron el flujo real de salida de Fase 1 y continuación entre procesos, la migración de un turno textil guardado (47,6 segundos, revisión pendiente y producción conservada), los 296 controles de los talleres reservados y las regresiones de Bruno (276) y Silas (436).

Para revisar imágenes, omitir `--headless` en la primera ejecución y añadir `-- --capture-ui`. Capturas en `output/ui/london_arrival/`. Los logs de pruebas se guardan en `output/london_*.log`.
