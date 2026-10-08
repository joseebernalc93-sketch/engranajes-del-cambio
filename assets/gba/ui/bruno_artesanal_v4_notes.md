# Bruno: banco artesanal interactivo

Esta versión reutiliza el taller, las tres superficies de madera, la garlopa del atlas de herramientas y el saco del inventario. Los demás instrumentos se dibujan en Godot con madera, acero y latón. No requiere imágenes nuevas ni extensiones nativas.

## Seis operaciones

1. **Veta:** distribución de nudos, poros y fisuras por semilla, con un tramo limpio garantizado. La plantilla se mueve directamente; confirmar una zona defectuosa consume una oportunidad. La lupa magnifica la escena mediante una copia del fondo y una lente cálida.
2. **Trazado:** regla de latón con tope a 160 cm, escuadra a 90° y dos incisiones. La primera referencia se conserva si falla la segunda. Tolerancia angular de 3,5° en Fácil y 1,5° en Difícil, con un pequeño margen para el ruido del dispositivo.
3. **Fijación:** tres cuñas arrastrables; encajarlas precede a tres golpes por cuña. La mordaza se ajusta girando su manivela. La prueba de rigidez valida todas las fijaciones y la presión. El golpe produce una vibración de 0,1 segundos.
4. **Serrado:** cinco recorridos alternos completos. El tirón, la inversión brusca o salir de la guía encallan la hoja; una pasada demasiado lenta no avanza y puede repetirse sin penalización. El shader profundiza la incisión. El sobrante se desprende como `RigidBody2D`, rebota sobre un banco con colisión y reproduce un impacto al aterrizar.
5. **Cepillado:** rueda de profundidad, cuatro franjas y pasadas a favor de veta. Una cuchilla retraída resbala sin penalización; una excesiva se clava y abre la revisión. El acabado se transforma por franja mediante shader y se emiten virutas curvadas.
6. **Flexión:** tres cargas progresivas, palanca manual y comparador cuadriculado. La respuesta elástica amortiguada mueve tanto la madera subdividida como la aguja. Se exige mantener la zona verde durante 1,2 segundos por saco.

La flexión y la fricción son modelos educativos controlados, no cálculos para dimensionar una estructura real. No se fuerza la física libre sobre herramientas de precisión. La gravedad, el rebote y la rotación del sobrante sí usan cuerpos 2D.

## Dificultad y revisión

Fácil conserva 15 oportunidades compartidas, guías más amplias, herramientas de teclado más lentas y 4 segundos para corregir la carga. Difícil conserva 10 oportunidades, mayor exigencia de cadencia y 1,2 segundos para corregir la carga. El aviso de Bruno suspende simulación, agarres, audio, partículas y cuerpos físicos. Continuar conserva lo validado; llegar a cero cierra el taller y ofrece otra ronda. Perder el foco o soltar una herramienta cancela únicamente el gesto sin terminar y no consume oportunidades.

## Datos e integración

- `scripts/ui/lumber_work_state.gd`: simulación determinista, validación y checkpoint versión 2.
- `scripts/ui/lumber_workbench_display.gd`: coordenadas unificadas de 800 × 420, mouse, contacto táctil único, teclado, shaders, partículas y física.
- `scripts/ui/lumber_puzzle_popup.gd`: reglas de oportunidades, explicación, audio, interfaz, inventario y guardado.
- `scenes/ui/lumber_puzzle_popup.tscn`: banco, malla subdividida, línea de incisión, cuerpos de madera, partículas GPU y lente.
- `scripts/core/session_memory.gd`: restaura Bruno desde su checkpoint explícito, sin recuperar objetos gráficos o agarres antiguos.

El checkpoint guarda semilla, defectos, plantilla, lupa, regla, escuadra, incisiones, cuñas, presión, cortes, franjas, profundidad, cargas y respuesta elástica. Los ajustes continuos se guardan periódicamente y al soltar o cerrar; las operaciones validadas se guardan inmediatamente. Se migran los checkpoints antiguos, sin borrar las fases superadas. La entrega sigue usando `GameState.complete_lumber_puzzle()` e `install_mill_part("tabla")`, que impiden duplicar la recompensa.

Los shaders 2D utilizan las interfaces de [CanvasItem](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html). La madera usa una [Polygon2D subdividida](https://docs.godotengine.org/en/stable/classes/class_polygon2d.html) y el serrín y las virutas usan [GPUParticles2D](https://docs.godotengine.org/en/stable/classes/class_gpuparticles2d.html).

## Ejecutar las pruebas

En Windows, prepara una vez el proyecto aislado desde la raíz del repositorio; `godot` debe estar disponible en PATH. También puedes pasar su ruta con `-GodotExecutable`:

```powershell
powershell -ExecutionPolicy Bypass -File tests/prepare_validation.ps1 -GodotExecutable godot
godot --headless --path tmp/cart_validation_project res://tests/lumber_puzzle_test.tscn
```

La suite verifica ambas dificultades, tablones resolubles, herramientas con mouse/touch/teclado, errores y recuperación, agotamiento temprano y tardío, migración, checkpoint, cadencia a 30/60/120 pasos, entrega única e instalación. Debe terminar con `LUMBER SIX PHASES OK` y sin errores. Usa un directorio de usuario distinto y restaura los archivos de validación al terminar.

Para capturas reales de las seis fases, omite `--headless`:

```powershell
godot --path tmp/cart_validation_project res://tests/lumber_puzzle_test.tscn -- --capture-lumber
```

Las imágenes se guardan en `output/ui/bruno_artesanal`. Para comprobar un checkpoint en dos procesos independientes, ejecuta primero `-- --write-bruno` y luego `-- --read-bruno`, siempre en el proyecto aislado.
