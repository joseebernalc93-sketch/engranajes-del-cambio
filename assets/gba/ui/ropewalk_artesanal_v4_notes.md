# Silas: pista de cordelería artesanal

Implementación de seis etapas con manipulación directa. El fondo, la rueda y el carro reutilizan los PNG `ropewalk_*_v2.png`; rastrillo, calibres, ligadura y dinamómetro son ilustraciones procedurales nativas de Godot. No hace falta generar nuevas imágenes para ejecutar el taller.

## Controles

| Etapa | Puntero / táctil | Teclado |
|---|---|---|
| Peinado | Tomar las púas a la izquierda y avanzar suavemente hacia la derecha | Elegir manojo con Tab/Enter; mantener Espacio y soltar entre pasadas |
| Reparto | Arrastrar mordaza del calibre; llevar la porción al gancho o tocarlo | ← → / A D repartir; Espacio o botón enganchar |
| Torsión | Giro horario de rueda y arrastre de carro; dos dedos admitidos | Espacio rueda y ← → / A D carro simultáneamente |
| Tensión | Rueda y manivela del freno | Espacio rueda; ← → / A D freno |
| Ligadura | Tres círculos horarios, soltar cada vuelta; tirón final hacia abajo | Mantener Espacio por vuelta, soltar; otra pulsación cierra el lazo |
| Carga | Arrastrar saco al cabrestante y ajustar freno | Espacio izar; ← → / A D frenar; repetir con cada saco |

Tab y Enter permiten navegar por todos los botones. Enter o Espacio continúan la revisión. Esc guarda y cierra el taller. Al perder foco se liberan los gestos y se congela la simulación hasta regresar; no se cobra una oportunidad por cambiar de ventana.

## Dificultad y reglas

| Parámetro | Fácil | Difícil |
|---|---:|---:|
| Oportunidades compartidas | 15 | 10 |
| Reloj de oscilación e indicadores | 0,25× | 1× |
| Diferencia de grosor respecto a la referencia | ±12% | ±4% |
| Inclinación del rastrillo | ±18° | ±8° |
| Velocidad máxima del rastrillo | 1100 px/s | 650 px/s |
| Corrección de sobrecarga / destorsión | 4 s | 1 s |
| Compactación continua entre 45–70 | 3 s | 3 s |
| Ventana del dinamómetro | ±9,5 lb | ±4,5 lb |
| Validación continua por saco | 1,2 s | 1,2 s |

Las unidades de tensión y las libras de prueba son una escala didáctica; no representan la capacidad certificada de una soga real. La caída de los cabos se aproxima con curvas suaves entre los apoyos. El acortamiento depende de las vueltas y el esfuerzo depende de la distancia del carro; el ensayo integra un resorte amortiguado en pasos de hasta 1/120 s. La inercia de rueda permite alternar controles con un único puntero. La velocidad excesiva y los movimientos oblicuos traban el rastrillo.

Un fallo congela herramientas, audio continuo, partículas y reloj. La revisión explica la causa y resta exactamente una oportunidad. Se conservan pasadas, porciones, ganchos, torsión, vueltas cerradas y sacos aprobados. Una vuelta incompleta se pierde si se suelta el hilo; salir con Esc o perder el foco cancela ese gesto sin cobrar un error. Al agotar las oportunidades se ofrece una nueva ronda desde el peinado con el cupo de la dificultad actual.

## Arquitectura y persistencia

- `scripts/ui/rope_work_state.gd`: estado tipado y simulación sin dependencias de la escena ni del gestor global.
- `scripts/ui/ropewalk_display.gd`: coordenadas normalizadas 800×420, herramientas, punteros simultáneos, teclado, partículas y shaders.
- `scripts/ui/rope_tool_illustration.gd`: capa de ilustraciones por encima de fibras y cabos.
- `scripts/ui/rope_puzzle_popup.gd`: reglas de oportunidades, revisión, audio, inventario y guardado.
- `scenes/ui/rope_puzzle_popup.tscn`: panel, controles accesibles y mundo 2D.
- `shaders/hemp_fiber_carding.gdshader`: alineación y brillo del cáñamo.
- `shaders/rope_spiral_twist.gdshader`: densificación helicoidal con vueltas.
- `shaders/rope_tension_vibrate.gdshader`: vibración ligada al esfuerzo y al reloj de simulación, sin `TIME` independiente.
- `shaders/ropewalk_cart_wheels.gdshader`: gira las caras de las ruedas originales sin superponer ruedas nuevas ni mover la estructura del carro.

Los tres cabos nacen en los ganchos del fondo y terminan en la boca de la guía cónica. La guía se repinta por encima de los cabos para respetar su oclusión; una línea unificada sale por su extremo y se sujeta a la argolla del carro. Las coordenadas de esta argolla siguen al carro en todas sus posiciones. Se conserva el riel ilustrado del taller. La prueba verifica estos anclajes durante la torsión y la compactación.

`GameState.flags.rope_progress.version = 3` guarda datos JSON explícitos. No serializa nodos, recursos, arrastres ni teclas mantenidas. Los ajustes continuos se guardan cada segundo y al soltar; el trabajo aprobado se guarda inmediatamente. La causa de una revisión se guarda junto al avance y se restaura sin un segundo descuento. `SessionMemory` conserva el taller abierto sin capturar internamente su renderizador.

Las partidas anteriores migran los ganchos concretos montados, las pasadas, vueltas cerradas y cargas comprobadas. El identificador de inventario continúa siendo `cuerda`. Su nombre visible es «Soga de transmisión resistente»; la entrega y la instalación en el molino mantienen las protecciones existentes contra duplicación.

## Verificación aislada

Preparar una vez el proyecto con nombre de aplicación distinto:

```powershell
powershell -ExecutionPolicy Bypass -File tests/prepare_validation.ps1 -GodotExecutable godot
godot --headless --path tmp/cart_validation_project res://tests/rope_puzzle_test.tscn
```

La prueba rechaza ejecutarse contra los datos del jugador. Guarda y restaura los archivos originales del directorio de validación; verifica ambos perfiles, todas las fases, errores geométricos y de cadencia, margen de corrección, recuperación, guardado, teclado, tacto, ventana pequeña, migración, agotamiento y recompensa única. Se comprueba la respuesta del resorte a 30, 60 y 120 Hz.

Capturas con renderizador gráfico:

```powershell
godot --path tmp/cart_validation_project res://tests/rope_puzzle_test.tscn -- --capture-rope
```

Salida: `output/ui/silas_artesanal/`.

Para verificar persistencia entre procesos independientes en el proyecto de validación:

```powershell
godot --headless --path tmp/cart_validation_project res://tests/rope_puzzle_test.tscn -- --write-silas
godot --headless --path tmp/cart_validation_project res://tests/rope_puzzle_test.tscn -- --read-silas
```

Estos dos modos dejan una partida de prueba con el segundo saco activo en el directorio aislado. La prueba normal sigue restaurando los archivos anteriores. Los scripts de captura antiguos redirigen al nuevo recorrido para conservar sus escenas de entrada.
