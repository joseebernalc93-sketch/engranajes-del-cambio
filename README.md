# Engranajes del Cambio

Prototipo educativo en Godot 4.7 sobre la Revolución Industrial para estudiantes de 10mo de EGB.

## Ejecutar el juego

1. Clona o descarga este repositorio.
2. Abre Godot 4.7.2 y selecciona **Importar** para abrir `project.godot`.
3. Espera a que Godot importe los recursos y pulsa **F5** para iniciar el juego.

Están disponibles la Fase 1 (el éxodo rural) y la Fase 2 (tecnología y mecanización). El juego permite elegir dificultad y guarda el progreso localmente en la carpeta de datos de usuario de Godot. Las partidas, la caché, las capturas temporales y los instaladores generados no se incluyen en el repositorio.

## Prototipo actual

La introducción de la fase 1 presenta **El precio de la lana**, con cuatro ilustraciones: la producción del criadero, el portón que divide el acceso a la tierra, la conversación con Elena y la preparación de la partida. Sus recuadros y botones combinan madera oscura, doble marco de latón, remaches y adornos de engranajes, siguiendo el botón «Comenzar» de la portada. Incluyen títulos por escena y navegación adelante/atrás. La última acción dice **Empesar primera fase**, según el texto solicitado, y abre el criadero desde el camino público. Los recursos y la validación están documentados en `assets/gba/story/wool_price_v3_notes.md`.

La primera fase permite experimentar el éxodo rural mediante acciones de juego:

1. Explorar los campos cercados y recolectar el trigo del sembrío junto al molino.
2. Conversar con una campesina desplazada.
3. Reutilizar las herramientas agrícolas para forjar una rueda y conseguir las piezas del molino.
4. Reparar y operar el molino hidráulico, regulando el agua para transformar el trigo en harina.
5. Vender el costal de harina por 100 monedas para pagar ambos pasajes.
6. Viajar en la diligencia de Ramón hasta la estación del tren.
7. Comprar un boleto y abordar el tren hacia la ciudad industrial.

No hay cuestionarios ni penalizaciones por desconocimiento. Los objetos funcionan también como glosario histórico y las acciones relevantes quedan registradas.

El protagonista utiliza un ciclo de caminata de tres cuadros en cuatro direcciones. Los personajes, edificios, objetos y tren emplean los atlas de pixel art guardados en `assets/gba/`.

La finca inicial utiliza `sheep_estate_v5.png`: mansión georgiana con jardines, corral cerrado y taller textil de ladrillo. Sus ocho ovejas pastan y se desplazan entre puntos cercanos sin salir del corral. La cardadora tiene cuerpo fijo, volante y polea independientes, correa y biela en movimiento, lana en la alimentación y vapor animado. La verja y el portón con cadena y candado bloquean el acceso privado. Las pistas del portón y del taller se pueden observar desde el camino público; la salida sigue conduciendo a la aldea. Los componentes y prompts exactos se documentan en `assets/gba/environment/sheep_estate_v5_notes.md`. `tests/sheep_estate_test.tscn` verifica las animaciones, el corral, el portón, las interacciones y la salida. Ejecuta con `--headless --path tmp/cart_validation_project res://tests/sheep_estate_test.tscn`; para capturas, omite `--headless` y añade `-- --capture-ui`.

El antiguo sembrío de la aldea es ahora una estación de carretas abierta, con un pequeño cobertizo, abrevadero y acceso amplio desde el camino. El caballo y la carreta de Elena tienen una escala acorde con los personajes. Las casas, el panadero, el horno, el agua y los botes conservan sus capas y animaciones. El campo junto al molino contiene los tres puntos de cosecha, tanto antes como después de repararlo. Se conservan los identificadores de cosecha de las partidas guardadas y los puzzles existentes.

`tests/field_layout_test.tscn` comprueba el traslado, la salida de la carreta, el acceso al sembrío con la colisión real del jugador, las tres cosechas y su persistencia al cargar la partida, y la animación del molino reparado. Ejecuta Godot con `--headless --path tmp/cart_validation_project res://tests/field_layout_test.tscn`. Para obtener capturas, omite `--headless` y añade `-- --capture-ui`; se guardan en `tmp/cart_validation_project/tmp/field_layout/`.

El camino del taller de Silas continúa hacia la izquierda y conduce al nuevo embarcadero del lago. El escenario incluye almacén, cobertizo de carga, grúa manual, carretilla, sacos, barriles y un muelle de madera en T. Dos botes de pesca y el bote de pasajeros oscilan sobre el agua animada. El acceso y las colisiones permiten recorrer la zona de carga y el muelle; el agua impide salir a pie al lago. El molino conserva su cosecha y ya no tiene muelle ni acceso a la isla.

El viaje en bote parte del nuevo embarcadero, cruza el lago y atraca en la isla de Bruno. La cámara sigue una ruta continua; los remos, las ondas y la estela responden al movimiento y se detienen al amarrar. La vuelta termina en el mismo embarcadero, junto al camino de Silas. **Espacio**, **E**, **Esc** o **Continuar** permiten adelantar la travesía. Al llegar, el jugador recupera el control junto al muelle; los puzzles no cambian. Los fondos y sus prompts exactos se documentan en `assets/gba/environment/lake_dock_v2_notes.md`.

`tests/lake_dock_test.tscn` comprueba el recorrido real desde Silas, las salidas automáticas, el acceso al muelle, sus colisiones, los botes animados, los viajes de ida y regreso y la eliminación del muelle del molino conservando el trigo. `tests/boat_travel_test.tscn` verifica ambos sentidos, la continuidad del bote y la cámara, los cuatro cuadros de remada, la estela, la llegada real a las escenas y los puntos de aparición. Ejecuta Godot con `--headless --path tmp/cart_validation_project res://tests/lake_dock_test.tscn` o `res://tests/boat_travel_test.tscn`. Omite `--headless` y añade `-- --capture-ui` para obtener capturas en `tmp/cart_validation_project/tmp/lake_dock/` y `tmp/cart_validation_project/tmp/boat_voyage/`. La escena `tests/_capture_boat_voyage.tscn` permite grabar el recorrido con `--write-movie` y `--fixed-fps 30`; añade `-- --return` para grabar el regreso.

## Diligencia de pasajeros y estación del tren

La salida derecha de la aldea conduce a una nueva estación de carretas con posada, establos, cobertizo de carga y dos diligencias con caballos. Ramón cobra **3 monedas** por el trayecto hasta la estación del tren; el pasaje incluye el regreso. Cancelar no descuenta monedas y el cobro se guarda una sola vez. El panadero paga 100 monedas por la harina: 3 para la diligencia y 10 para el tren. Elena conserva su diálogo histórico y su caballo en la aldea, sin puzzle propio. Las partidas anteriores mantienen sus puzzles completados y reciben el ajuste de transporte si lo necesitan.

La travesía de 15,6 segundos muestra al personaje subiendo, la salida del patio, el camino entre los campos, la llegada a la estación y el descenso a pie. La cámara sigue la diligencia; el caballo camina, las ruedas giran según la distancia y la carrocería tiene suspensión y polvo. **E**, **Espacio**, **Esc** o **Continuar** adelantan el viaje. La llegada deja al jugador en la escena real con los controles restaurados.

`scenes/station.tscn` contiene la fachada exterior y la entrada principal, con explanada, bancos y equipaje. La puerta lleva a la taquilla; con el boleto comprado se accede al andén de `scenes/station_platform.tscn`. Los viajes en diligencia y las monedas de pasaje aparecen en el registro docente. Los cinco recursos de la diligencia y sus prompts se documentan en `assets/gba/environment/passenger_coach_route_v1_notes.md`.

`tests/passenger_coach_test.tscn` comprueba el acceso caminando, las colisiones, saldo insuficiente, cancelación, cobro único, venta de harina por 100 monedas, los cinco momentos de ida y regreso, las ruedas y las cuatro poses del caballo, llegada, taquilla, boleto, andén, partida real del tren, guardado y migración. Ejecuta con `--headless --path tmp/cart_validation_project res://tests/passenger_coach_test.tscn`. Para capturas, omite `--headless` y añade `-- --capture-ui`. `tests/_capture_coach_voyage.tscn` permite grabar con `--write-movie` y `--fixed-fps 30`; añade `-- --return` para el regreso. Los puzzles existentes conservan sus archivos.

## Tren sin puzzle de vías

El puzzle ferroviario y su control interactivo se han retirado. El tren, sus rieles, el escenario del andén, el vapor, el movimiento y las ruedas animadas se conservan. Después de comprar el boleto se puede subir y partir directamente, sin alinear tramos ni cambiar agujas.

El guardado versión 13 elimina el panel y los diálogos del puzzle de las vías de los checkpoints antiguos. Mantiene la posición en el andén, la dificultad, el inventario, el saldo y los puzzles completados. Los recursos ferroviarios antiguos quedan archivados sin acceso desde el juego.

`tests/rail_puzzle_removal_test.tscn` prueba una partida de versión 12 cerrada dentro del puzzle: carga sin panel, conserva la posición y el boleto, permite subir directamente, mantiene las ruedas en movimiento y completa el capítulo. Se ejecuta con `--headless --path tmp/cart_validation_project res://tests/rail_puzzle_removal_test.tscn`.

## Controles

- Movimiento: `WASD` o flechas.
- Interacción: `E` o barra espaciadora.
- Inventario y glosario: `I` o tabulador.
- Pausa o cerrar panel: `Esc`.

## Inventario y glosario

La barra de monedas y el inventario comparten un acabado de hierro oscuro, cobre y remaches. El panel muestra doce casillas ordenadas, cantidades, selección persistente y una ficha del objeto sobre un plano técnico. La pestaña **Mochila** contiene los objetos disponibles; **Glosario** permite consultar las siete fichas históricas incluso después de utilizar los objetos. La mochila vacía ofrece una guía para continuar la exploración.

Abre el panel con **I**, **Tab** o el botón de la barra. Dentro del panel, **Tab** recorre los controles y **Enter** confirma; **I** o **Esc** cierran. El panel se ajusta al espacio disponible y los textos extensos admiten desplazamiento. Los adornos y nuevos iconos son vectoriales y se mantienen nítidos al cambiar de tamaño.

`tests/inventory_ui_test.tscn` comprueba selección, actualización de cantidades, mochila vacía, consulta de objetos utilizados, adaptación del panel y restauración del movimiento. No reinicia ni guarda la partida. Para validarlo con datos separados, ejecuta Godot con `--headless --path tmp/inventory_validation_project res://tests/inventory_ui_test.tscn`. Añade `-- --capture-ui` y omite `--headless` para generar capturas en la carpeta `tmp/inventory_ui` del proyecto de validación.

## Cordelería de Silas

El puzzle «La cuerda bajo tensión» es una pista de cordelería con herramientas manipulables, agujas de latón, fibras con shaders y partículas vegetales. Fácil comparte 15 oportunidades, ralentiza cuatro veces las oscilaciones y deja cuatro segundos para corregir tensión y carga; Difícil comparte 10, con un segundo para corregir. Se han sustituido los deslizadores y barras genéricas.

- **Peinado:** arrastra el rastrillo de izquierda a derecha o mantén **Espacio**, con dos pasadas por manojo. Los tirones y las inclinaciones excesivas traban las púas; cada pasada limpia se guarda.
- **Cabos:** mueve la mordaza del calibre o usa **← → / A D** para repartir la fibra entre porciones sin crear ni perder material. Engancha con arrastre, clic en el gancho o **Espacio**. Tolerancia de grosor: ±12% en Fácil y ±4% en Difícil.
- **Torsión:** gira la rueda en sentido horario y acompaña el acortamiento arrastrando el carro. Con teclado, **Espacio** mueve la rueda y **← → / A D** el carro. La inercia permite cambiar de herramienta con un puntero; dos dedos pueden manejar rueda y carro a la vez.
- **Compactación:** mantén **Espacio** y regula el freno con **← → / A D**, o alterna rueda y manivela de freno con el puntero. La aguja debe permanecer entre **45 y 70** durante **3 segundos continuos**.
- **Ligadura:** traza tres círculos horarios o mantén **Espacio** para cada vuelta; suelta entre vueltas. Un error elimina solo la vuelta incompleta. Después, tira del hilo hacia abajo o pulsa **Espacio** para trabar el lazo.
- **Carga:** arrastra cada saco al cabrestante, pulsa **Izar saco** o **Espacio**. El control pasa automáticamente al freno: **← → / A D** o arrastre de su empuñadura. Tres ensayos de **1,2 segundos en verde** validan la soga; se conservan las cargas aprobadas.
- Cada error consume una oportunidad sin volver a la primera etapa. Silas muestra «Revisemos el trabajo» con la explicación, el saldo y el botón **Continuar esta fase**. El aviso pausa las herramientas y los indicadores; se continúa con clic, Enter o Espacio. Cerrar y volver conserva el avance y los errores. Al agotarlas, Silas ofrece empezar una nueva ronda; cambiar de dificultad conserva las oportunidades ya gastadas.
- **Tab / Enter** navegan y activan herramientas y botones; **Esc** cierra. Perder el foco pausa también el resorte y los temporizadores. El panel se adapta a ventanas pequeñas.

El guardado del taller usa `rope_progress.version = 3`, con migración de los seis pasos anteriores y sus ganchos, vueltas y cargas. La recompensa única conserva el ID `cuerda` y se llama **Soga de transmisión resistente**; sigue instalándose en el molino. La simulación guiada usa tensión geométrica, curvas de caída y un resorte amortiguado, con parámetros pedagógicos. Los recursos reutilizados son `assets/gba/ui/ropewalk_*_v2.png`.

Los rastrillos, cabos y sogas utilizan sprites de pixel art con transparencia y filtrado nearest. El carro apoya sus ruedas sobre el riel del fondo y el rollo terminado deja libre el encabezado. Si falla un ensayo, se descarga solo ese saco y se elimina el impulso residual del resorte; **Izar saco** permite repetir sin perder las cargas aprobadas. También se reparan guardados anteriores detenidos en una sobrecarga. Recursos y prompts: [silas_pixel_art_v1_notes.md](assets/gba/ui/silas_pixel_art_v1_notes.md).

La primera etapa muestra una mesa de peinado con manojos de cáñamo; de la segunda a la quinta se utiliza el taller de la máquina. El ensayo final muestra un pórtico de poleas y el costal suspendido. Ambas palancas tienen pedestal, eje y mango de pixel art; se arrastran alrededor de su articulación. El remate utiliza una guía de latón grabada y vueltas de hilo ilustradas. Recursos y prompts: [silas_stage_scenery_v2_notes.md](assets/gba/ui/silas_stage_scenery_v2_notes.md).

```powershell
powershell -ExecutionPolicy Bypass -File tests/prepare_validation.ps1 -GodotExecutable godot
godot --headless --path tmp/cart_validation_project res://tests/rope_puzzle_test.tscn
```

La prueba verifica las seis fases en ambas dificultades, controles táctiles simultáneos y teclado, errores, guardado, agotamiento, migración, recompensa e instalación única. Sin `--headless`, añade `-- --capture-rope` para obtener las imágenes en `output/ui/silas_artesanal`. La guía técnica está en [ropewalk_artesanal_v4_notes.md](assets/gba/ui/ropewalk_artesanal_v4_notes.md).

## Carpintería de Bruno

El taller ahora usa herramientas diegéticas manipulables, sin deslizadores ni medidores genéricos. Conserva las seis fases, las oportunidades, el guardado y la entrega única de la tabla.

### Seis operaciones

1. **Veta:** distribución de nudos, poros y fisuras por semilla, con un tramo limpio garantizado. La plantilla se mueve directamente; confirmar una zona defectuosa consume una oportunidad. La lupa magnifica la escena mediante una copia del fondo y una lente cálida.
2. **Trazado:** regla de latón con tope a 160 cm, escuadra a 90° y dos incisiones. La primera referencia se conserva si falla la segunda. Tolerancia angular de 3,5° en Fácil y 1,5° en Difícil, con un pequeño margen para el ruido del dispositivo.
3. **Fijación:** tres cuñas arrastrables; encajarlas precede a tres golpes por cuña. La mordaza se ajusta girando su manivela. La prueba de rigidez valida todas las fijaciones y la presión. El golpe produce una vibración de 0,1 segundos.
4. **Serrado:** cinco recorridos alternos completos. El tirón, la inversión brusca o salir de la guía encallan la hoja; una pasada demasiado lenta no avanza y puede repetirse sin penalización. El shader profundiza la incisión. El sobrante se desprende como `RigidBody2D`, rebota sobre un banco con colisión y reproduce un impacto al aterrizar.
5. **Cepillado:** rueda de profundidad, cuatro franjas y pasadas a favor de veta. Una cuchilla retraída resbala sin penalización; una excesiva se clava y abre la revisión. El acabado se transforma por franja mediante shader y se emiten virutas curvadas.
6. **Flexión:** tres cargas progresivas, palanca manual y comparador cuadriculado. La respuesta elástica amortiguada mueve tanto la madera subdividida como la aguja. Se exige mantener la zona verde durante 1,2 segundos por saco.

La flexión y la fricción son modelos educativos controlados, no cálculos para dimensionar una estructura real. No se fuerza la física libre sobre herramientas de precisión. La gravedad, el rebote y la rotación del sobrante sí usan cuerpos 2D.

### Dificultad y revisión

Fácil conserva 15 oportunidades compartidas, guías más amplias, herramientas de teclado más lentas y 4 segundos para corregir la carga. Difícil conserva 10 oportunidades, mayor exigencia de cadencia y 1,2 segundos para corregir la carga. El aviso de Bruno suspende simulación, agarres, audio, partículas y cuerpos físicos. Continuar conserva lo validado; llegar a cero cierra el taller y ofrece otra ronda. Perder el foco o soltar una herramienta cancela únicamente el gesto sin terminar y no consume oportunidades.


La [guía del banco artesanal](assets/gba/ui/bruno_artesanal_v4_notes.md) documenta los controles, la arquitectura, los shaders y las pruebas. Para preparar el proyecto aislado y verificar ambas dificultades:

```powershell
powershell -ExecutionPolicy Bypass -File tests/prepare_validation.ps1 -GodotExecutable godot
godot --headless --path tmp/cart_validation_project res://tests/lumber_puzzle_test.tscn
```

Con renderizado, añade `-- --capture-lumber` para guardar capturas en `output/ui/bruno_artesanal`.

## Fragua de Mateo: seis etapas y dificultad seleccionable

La portada muestra **Comenzar** y, cuando existe una partida, **Continuar** encima. **Comenzar** abre el paso **Elegir dificultad**, con un selector de **Fácil** y **Difícil** de madera y latón. **Listo** inicia la historia; si existe otra partida, primero pide confirmar su reemplazo. La elección pendiente no altera la partida anterior. Fácil ofrece **15 oportunidades compartidas** y un indicador de precisión cuatro veces más lento; también suaviza el calor, el enfriamiento, el ajuste del eje y la velocidad bajo carga. Difícil conserva **10 oportunidades compartidas** y el ritmo original. Cambiar de modo conserva el trabajo y los errores gastados.

El taller conserva su fondo, fuelle, hogar, rueda, martillo y piñón animados. Tiene seis etapas: montar cuatro refuerzos y apretar dos abrazaderas; sostener el calor en la zona de trabajo; remachar en lados opuestos con precisión; regular el enfriamiento; centrar el eje con tres tornillos; y probar la rueda con tres niveles de carga.

- **Montaje:** selecciona con **1–4**, toca las piezas o arrástralas. **Q / R** y los botones giran cada pieza. Encaja el número y la muesca en su lugar; mantén las abrazaderas o su botón para sujetar ambos lados y pulsa **Comprobar montaje**.
- **Calor:** **Espacio / F**, el fuelle o su botón avivan el carbón. Mantén dos segundos en la franja de trabajo. **V** o **Ventilar** bajan el exceso; la advertencia deja dos segundos para corregir en Difícil y cuatro en Fácil.
- **Remaches:** gira con **← → / A D**, arrastra la rueda o usa **Alinear refuerzo**. Trabaja en orden **1 → 3 → 2 → 4**, con tres golpes por refuerzo. Pulsa **Espacio**, el remache o **Golpear** cuando el indicador esté en verde y el calor sea correcto. Tocar otro remache, golpear sin alinear o intentar un golpe con el hierro frío muestra una orientación y no consume oportunidades. Un golpe válido fuera de la zona verde sí consume una. Las cabezas se aplanan solo al impactar el martillo.
- **Enfriamiento:** ajusta el deslizador o **← →** para seguir una franja que cambia lentamente. Un ritmo incorrecto durante dos segundos en Difícil o cuatro en Fácil consume una oportunidad.
- **Eje:** **1–3** o los botones seleccionan tornillo; **← →**, mantener **Aflojar / Apretar** o arrastrar el tornillo lo ajustan. Las tres marcas deben estar verdes antes de pulsar **Comprobar eje**. La oscilación disminuye al centrarlo.
- **Carga:** pulsa y suelta **Espacio / →**, la manivela de la rueda o su botón para mantener la velocidad en verde. La carga cambia en tres niveles; un exceso sostenido de velocidad provoca un fallo tras una advertencia.

Cada error confirmado consume una oportunidad. Se explica la causa y **Continuar esta fase** conserva las etapas anteriores y el trabajo correcto de la fase actual: piezas y abrazaderas, impactos de remache, enfriamiento, ajustes del eje y cargas comprobadas. Un fallo en carga permite seguir en carga con una oportunidad menos. Pasar de fase no recarga el contador. Se liberan los controles y se recuperan el calor o la ventilación para corregir sin repetir inmediatamente el mismo fallo.

Solo al agotar las oportunidades del modo elegido, el panel se cierra y Mateo anima al jugador: «Sigue intentándolo, no te rindas. ¡Ánimo!». Su diálogo permite comenzar desde el montaje una nueva ronda de 10 o 15 oportunidades, según la dificultad, o volver después. Cerrar, reabrir, guardar o cargar conserva la fase, su avance y las oportunidades restantes; abrir directamente con cero oportunidades lleva al diálogo de Mateo. Las acciones y temporizadores se detienen al perder el foco, y las animaciones pendientes se cancelan al cerrar. Si una transición validada estaba pendiente, se retoma al abrir.

La rueda se entrega una sola vez tras completar todas las comprobaciones y sigue sirviendo para reparar el molino. Las partidas anteriores mantienen los puzzles completados y el inventario. El guardado versión 11 conserva la dificultad y las oportunidades gastadas: las partidas antiguas se cargan con el modo Difícil y el avance intacto. Se mantiene la migración anterior que añadía siete oportunidades a las partidas de la versión 9. El informe registra la dificultad, fallos, oportunidades y rondas de la fragua.

`tests/wheelwright_forge_test.tscn` comprueba las seis etapas en ambos modos, controles de ratón/tacto/teclado, selección y guardado de dificultad, 10/15 oportunidades, indicadores lentos, toques sin penalización y fallos de precisión. También verifica recuperación con avance parcial, guardar y reabrir, agotamiento, diálogo y nueva ronda, transiciones interrumpidas, ventana pequeña, entrega única, instalación en el molino y migración de partidas sin recargar oportunidades. Ejecuta con `--headless --path tmp/cart_validation_project res://tests/wheelwright_forge_test.tscn`; omite `--headless` y añade `-- --capture-ui` para capturas. El comportamiento actual se documenta en `assets/gba/ui/mateo_difficulty_v5_notes.md`.

## Reparar el mecanismo del molino

La reparación utiliza un taller fijo con engranajes, poleas, soga, tabla y herramientas animados por separado. Las tres piezas pueden instalarse en cualquier orden: arrástralas desde la mesa hasta su marca o pulsa su botón. **1 / 2 / 3** también seleccionan e inician la instalación. Las piezas que faltan indican qué artesano las prepara.

- Rueda dentada: arrastra el borde o usa **Girar / ← → / A D** para alinear la ranura cuadrada. Mantén el centro, el botón o **Espacio** para asentarla en el eje.
- Soga: ajusta el tensor con su asa, deslizador, botones o **← → / A D**. La franja verde indica una tensión útil entre **64 y 78%**. Mantén la soga, el botón o **Espacio** para asegurar el amarre.
- Tabla: mantén cada fijación iluminada, el botón o **Espacio** para apretarla. La herramienta y las cabezas giran; hay que soltar entre las dos fijaciones.
- Prueba: mantén el eje, el botón o **Espacio** para completar una vuelta. El piñón gira en sentido opuesto; la soga y su amarre recorren las poleas y las ranuras de la piedra giran. Tres comprobaciones verifican el engranaje, la transmisión y la bancada.

Cada pieza se consume y guarda solamente al terminar su montaje. Cerrar conserva las piezas instaladas; un montaje incompleto vuelve a empezar sin perder el objeto. Si las tres piezas ya están guardadas, la siguiente visita comienza en la prueba. Soltar o cambiar de ventana detiene la herramienta y conserva el avance de la acción actual; Esc cierra el panel. Tab y Enter permiten usar los botones. El molino habilita **Preparar costal de harina** al superar la comprobación final. Las partidas que ya tenían el molino reparado siguen funcionando.

`tests/mill_repair_test.tscn` verifica piezas ausentes, destinos incorrectos, alineación, tensión, fijaciones independientes, ratón y pantalla táctil, teclado, guardado, prueba de giro, cierre y aviso de cercanía. La carpeta `tmp/repair_validation_project` protege los datos del jugador durante la validación. El taller y la estructura reutilizan las capas de la preparación de harina y las piezas artesanales existentes; no hay una imagen única que gire con toda la máquina.

## Preparar la harina en el molino

La rueda, los engranajes y las ranuras de las piedras giran por separado según las revoluciones. El caudal mueve el agua del canal; el grano baja de la tolva solo durante una molienda estable y el costal crece a medida que recibe la harina. Los sonidos del agua y la transmisión responden al caudal y al giro. La estructura del molino permanece fija.

La compuerta puede regularse arrastrando su asa en la máquina, con el deslizador, con **− Cerrar / + Abrir** o con **← → / A D**. Una pulsación cambia un 2%; mantener el botón o la tecla regula el caudal gradualmente. Arrastra el trigo al interior de la tolva, pulsa la tolva o usa **Cargar / Espacio** cuando la rueda esté estable. Después de las tres tandas, pulsa **Detener el caudal**, espera a que el eje se detenga y mantén el costal, **Atar** o **Espacio**. La harina se entrega tras completar la ligadura. El avance se conserva al soltar.

Al soltar fuera de la herramienta, cambiar de ventana o cerrar el panel se libera el control. Tab y Enter permiten utilizar los botones. El panel se adapta al tamaño de la ventana. Cerrar antes de terminar conserva el trigo y reinicia la preparación al volver a abrir. La misión completada puede consultarse sin repetir su recompensa. Al acercarse al molino reparado, el aviso muestra **Preparar costal de harina**; antes de la reparación continúa indicando el mecanismo averiado. También se actualiza si la reparación termina mientras el personaje sigue cerca.

`tests/mill_operation_controls_test.tscn` verifica el aviso de cercanía antes y después de reparar, los botones, las teclas, el arrastre táctil a la tolva, la rotación, las tres tandas, la recuperación de atascos, el frenado, la ligadura y una sola entrega del costal. La carpeta local `tmp/mill_validation_project` usa un nombre distinto para proteger los datos del jugador. Los recursos nuevos y sus prompts se documentan en `assets/gba/ui/mill_workshop_v2_notes.md`.

## Elena en la aldea

El puzzle del carro se ha retirado. Elena conserva sus diálogos sobre el cercamiento; el caballo, la carreta y sus colisiones permanecen en el mismo lugar incluso al cargar partidas antiguas. Ya no se requiere ayudar con el carro para comprar el boleto o subir al tren. La harina se vende por 100 monedas y paga ambos pasajes. Los recursos antiguos de la carreta quedan como material de archivo, sin acceso desde el juego.

## Registro docente

Al completar la fase se genera `user://registro_fase_1.json`. Contiene tiempo, cantidad de interacciones, pistas históricas, desempeño al operar el molino, decisiones del carro del éxodo y una cronología de las acciones del jugador. El archivo se guarda en la carpeta de datos de usuario administrada por Godot.

## Estructura

- `scenes/`: juego, jugador, interfaz y componentes reutilizables.
- `scripts/core/`: estado, contenido, guardado y eventos globales.
- `scripts/world/`: escenario e interacciones.
- `assets/`: recursos visuales editables del prototipo.
- `tests/`: recorrido automático de la primera fase.






## Inicio, pausa y memoria de la partida

El inicio sigue el flujo **Comenzar → Elegir dificultad → Fácil / Difícil → Listo → historia**. Una partida existente habilita **Continuar** encima de **Comenzar**. Al preparar otra, la dificultad y el progreso guardados permanecen intactos hasta pulsar **Comenzar de nuevo** en el aviso. **Cancelar** vuelve al selector; Esc vuelve al paso anterior.

La pausa conserva sus tres opciones y muestra siempre **Dificultad: Fácil / Difícil**. El objetivo y la guía se actualizan con los talleres completados, las piezas que faltan, la reparación y molienda, la venta, la diligencia, el boleto y la subida al tren.

La partida se guarda cada segundo, después de las acciones que modifican el progreso, al perder el foco y al cerrar la ventana. El archivo se escribe completo en un temporal antes de reemplazar el anterior. **Continuar** recupera escenario, posición y orientación, dificultad, dinero, inventario y avances. También restaura la página del relato, pausa, diálogo, glosario, taller abierto, ajustes, oportunidades gastadas y aviso de error, junto con el punto del trayecto en bote, diligencia o salida del tren. Las teclas mantenidas y los arrastres se liberan al continuar para que una herramienta no quede accionada. Los guardados anteriores a esta función conservan sus logros; al no tener coordenadas, se retoman frente al criadero.

`tests/session_flow_test.tscn` comprueba la memoria en **dos procesos independientes de Godot**: el primero cierra con un puzzle abierto y el segundo carga esa partida, verifica los cinco paneles de los cuatro puzzles, diálogos, inventario, relato, viajes, salida del tren, cancelación y confirmación de nueva partida, y ambas dificultades. Usa únicamente el proyecto de validación aislado:

```powershell
Godot --headless --path tmp/cart_validation_project res://tests/session_flow_test.tscn
Godot --headless --path tmp/cart_validation_project res://tests/session_flow_test.tscn -- --read-session
```

El segundo proceso restaura los datos originales del proyecto de validación. Para capturar las pantallas, omite `--headless` y añade `--capture-session` en ambos comandos después de `--`. Las imágenes se guardan en `output/ui/session_flow`.


`tests/completed_chapter_return_test.tscn` termina el cap?tulo con la salida real del tren y verifica el regreso desde la entrada de la estaci?n, en diligencia, hasta el pueblo. Tambi?n fuerza la retirada del HUD entre las dos esperas de su ajuste de pausa: comprueba que una escena reemplazada no acceda a un `SceneTree` nulo, que la pausa siga centrada y que se conserven cap?tulo completado, informe, dificultad y guardado en el pueblo. Ejecuta con `--headless --path tmp/cart_validation_project res://tests/completed_chapter_return_test.tscn`; la salida debe mostrar `COMPLETED CHAPTER RETURN OK` sin errores de Godot.


## Pausa: los cuatro puzzles

El menú es el **Cuaderno del viajero**: un libro abierto de cuero, pergamino y herrajes de latón. La página izquierda muestra la fase, la dificultad, el objetivo actual y la guía. La página derecha reúne cuatro fichas ilustradas en tinta: Herrero, Hilandero, Leñador y Molino, seguidas de los tres botones. El texto y los estados son controles nativos y se actualizan con la partida. El contador se actualiza de 0/4 a 4/4. El molino cuenta como completado al terminar la molienda, después de repararlo; Elena no figura como puzzle. La leyenda sigue el progreso y los tres botones mantienen continuar, revisar la historia y reiniciar la fase.

El guardado versión 17 conserva dificultad, posición, avances, resumen de la Fase 1 y un punto independiente para cada fase desbloqueada. Si una partida anterior recibió solo 10 monedas por la harina y no cobró la antigua ayuda de Elena, recibe 3 monedas una sola vez. Los guardados dentro del puzzle retirado vuelven al mismo lugar de la aldea con movimiento disponible.

Al completar la Fase 1, **Volver a fase 1** regresa al criadero conservando los cuatro puzzles, inventario, dinero, dificultad y resumen. La pausa del campo permite **Continuar fase 2 · Londres** y regresar al menú principal. **Continuar** en el título recupera siempre la última sesión visitada; cambiar de fase conserva por separado la ubicación y los descubrimientos de Londres. **Fases desbloqueadas** en el título permite volver al campo, continuar Londres o **Reiniciar fase 2**. Este último requiere confirmación, borra todo el progreso de la Fase 2 y vuelve a su relato y llegada del tren. Recupera las monedas y la mochila originales del final de la Fase 1 (normalmente 87 monedas, sin el boleto utilizado), conservando esa fase completada. Véanse [reinicio, migración y pruebas](reports/phase2/reiniciar_fase_2.md). Solo **Comenzar de nuevo** borra la partida completa; reiniciar una Fase 1 todavía incompleta conserva su funcionamiento anterior.

`tests/chapter_navigation_test.tscn` verifica este flujo en Fácil y Difícil, con controles reales del cuaderno y del menú, y otro proceso verifica la persistencia y la migración de partidas versión 16:

```powershell
Godot --headless --path tmp/cart_validation_project res://tests/chapter_navigation_test.tscn
Godot --headless --path tmp/cart_validation_project res://tests/chapter_navigation_test.tscn -- --read-navigation
```

El segundo comando se ejecuta después de que termine correctamente el primero y restaura los archivos de validación respaldados. Para generar capturas añade `-- --capture-ui` al primero y omite `--headless`.

`tests/five_puzzles_pause_test.tscn` verifica el caballo persistente, la ausencia del puzzle, el pago único de 100 monedas, el viaje y el boleto sin Elena, cuatro tarjetas dinámicas, ambas dificultades, tamaño del menú, los botones y la migración sin duplicar monedas. Ejecuta con `--headless --path tmp/cart_validation_project res://tests/five_puzzles_pause_test.tscn`. Omite `--headless` y añade `-- --capture-ui` para generar vistas en `output/ui/pause_traveler_journal/`.

## Cierre de la fase 1 y cuaderno de capítulos

La salida del tren abre la última página del **Cuaderno del viajero**, con cuatro fichas de oficios, logros de la cosecha y del molino, cuentas del viaje, tiempo, dificultad y reflexión histórica. Los datos del informe se fijan al terminar la fase.

**Seguir explorando** abre cuatro viñetas de viaje y después la llegada animada del tren a Londres. El personaje baja al andén, pregunta al guía Henry por la salida, atraviesa el vestíbulo de boleterías y sale a una calle explorable. Las partidas antiguas del complejo industrial se redirigen a esta aventura y conservan todos los trabajos de los talleres. **Esc** abre y cierra el cuaderno. **Fase anterior / Fase siguiente**, o izquierda/derecha, permiten consultar el resumen de la Fase 1 y los descubrimientos de la llegada. El guardado recuerda mapa, posición, conversación, instante de la animación y página abierta. **Menú principal** conserva la partida; **Reiniciar fase 2** requiere confirmar y vuelve al relato y a la llegada del tren, conservando el capítulo anterior y los trabajos reservados.

`tests/chapter_journal_flow_test.tscn` prueba el flujo con la salida real del tren y una segunda ejecución del motor. Ejecuta primero la escena en el proyecto aislado y después repite con `-- --read-chapter`; para generar capturas, ejecuta la primera con renderizado y `-- --capture-ui`. Los recursos y prompts de generación se documentan en `assets/gba/ui/chapter_journal_v1_notes.md`; las capturas están en `output/ui/chapter_journal/`.

## Fase 2: el corazón de hierro

La entrada jugable es una aventura de exploración por **andenes → boletería → calle de Londres**, con tres fondos nuevos en pixel art y personajes propios de la ciudad. Se camina con Flechas/WASD o clic/toque; E/Espacio permite conversar. Las puertas conectan las zonas en ambos sentidos y el guía orienta al jugador antes de abandonar los andenes. La dificultad se consulta en el cuaderno y explorar no consume oportunidades.

La aventura conecta **hulla → biela de hierro → motor de vapor → producción textil**, con exploración entre el pozo, la fundición y la casa de máquinas. Conserva sus avances, inventario, presupuesto de 15/10 oportunidades y pruebas.

```powershell
./tests/prepare_validation.ps1 -GodotExecutable godot
godot --headless --path tmp/cart_validation_project res://tests/phase2_factory_test.tscn
godot --headless --path tmp/cart_validation_project res://tests/london_arrival_test.tscn
godot --headless --path tmp/cart_validation_project res://tests/london_arrival_test.tscn -- --read-london
```

La [llegada a Londres](reports/phase2/llegada_londres.md) documenta el recorrido actual, sus controles, recursos y pruebas. La [documentación de los talleres reservados](reports/phase2/implementacion.md) conserva sus reglas y arquitectura.

La exploración de Londres muestra la misma barra de monedas e inventario de la Fase 1 y el aviso «E Hablar con…» únicamente al acercarse a alguien. Las conversaciones reutilizan el panel de la Fase 1. En los andenes solo están el protagonista y Henry; en la boletería, el protagonista y Arthur. Afuera, Edward tiene un puesto de periódicos en una esquina y Rose está junto al carruaje de la otra; ambos igualan la altura visible del protagonista. El cuaderno se abre con Esc y contiene los objetivos y la dificultad. No hay títulos, carteles de destinos ni nombres flotantes. Se cambia de zona caminando hasta los extremos; para volver a la estación desde la calle basta acercarse a su puerta. Las conversaciones se inician con E/Espacio o tocando al personaje; también se puede tocar el puesto para acercarse al vendedor. El inventario compartido se abre con I y conserva el glosario y la selección al continuar.

Henry tiene bigote y uniforme burdeos; Arthur lleva gafas y uniforme verde oscuro. Sus sprites nuevos están en `assets/phase2/london_staff_pixel_v2.png`, con el prompt guardado en `london_staff_generation_v2.json`. La escala de los cuatro NPC se calcula desde los píxeles opacos del cuerpo y descarta los bordes casi transparentes del atlas; las proporciones individuales se conservan. Las pruebas de Londres comprueban la altura visible y los uniformes además del recorrido y la persistencia (142 controles de escritura y 15 de lectura).

Al caminar hacia abajo desde la plaza de Londres se llega a la parada de coches. William ofrece un viaje animado de **40 segundos** al distrito industrial por **10 monedas**, con regreso incluido. El cuaderno y el inventario pausan el trayecto, que continúa desde el instante guardado sin cobrar de nuevo. Tomás paga ahora **100 monedas** por la harina: después de gastar 3 en el pueblo y 10 en el tren quedan **87**, y después del coche, **77**. El boleto se consume al viajar; los guardados anteriores reciben una sola vez la diferencia de la venta. Véanse [implementación, recursos y pruebas del coche](reports/phase2/coches_londres.md).

William tiene un sprite pixel art propio, de la misma altura visible que el protagonista, tanto en la parada como conduciendo. Al hablar pregunta «¿A dónde deseas ir?» y muestra **Ensamble del motor**, **El pozo minero**, **La forja y fundición** y **Nave Textil**. Los tres primeros destinos están disponibles y solicitan confirmar el pasaje antes de cobrar; Nave Textil queda reservado.

La misión **Carbón, hierro y vapor** conecta seis etapas: recorrer la galería evitando desprendimientos, extraer y clasificar carbón para el inventario, ensamblar engranajes, conectar dos circuitos de agua, encender la caldera y sostener la presión durante 120 segundos seguros. Mina y motor se conectan también a pie, sin otro pago. Se conserva el progreso al reintentar y se puede reponer carbón sin reiniciar el montaje. Al terminar se abre la nave textil con mecanismos animados. El cuaderno muestra las seis etapas, combustible y tiempo; menú principal y Continuar recuperan el trabajo exacto. Véanse [recorrido, controles, arte y pruebas del pozo y motor](reports/phase2/pozo_y_motor.md).

La mina usa el **túnel lateral del modelo 3**, con un solo suelo, piedras pequeñas y tres tramos de espera. El elevador del extremo izquierdo permite bajar y subir con E mediante un viaje visible de 9,4 segundos; cuaderno e inventario lo pausan y el guardado recupera su instante exacto. Se conserva el personaje actual y se adapta la escala al túnel. El acceso pasa por una puerta y la casa del pozo; el viaje muestra un pozo subterráneo independiente y la subida vuelve al interior. Véanse [casa del pozo y compatibilidad de guardados](reports/phase2/casa_del_pozo.md). Véanse [recursos y pruebas del túnel y elevador](reports/phase2/tunel_mina_modelo3.md).

Caminar al extremo derecho del túnel abre una **galería de extracción nueva**. E junto a la veta inicia un taller manual de seis etapas: reconocer la hulla con una lámpara, colocar puntales, golpear tres vetas, separar carbón y piedra, equilibrar cuatro costales y completar vías y desvíos para transportarlos al elevador. Incluye piezas pixel art, balanza animada y vagoneta sobre raíles. Solo la entrega final añade los cuatro costales al inventario. Ratón, toque y teclado permiten completar las tareas; Continuar conserva las piezas colocadas y el instante del transporte. Los reintentos mantienen lo aprobado. Caminar hacia la izquierda devuelve al túnel del elevador. Véanse [controles, recursos generados, prompts y pruebas del taller minero](reports/phase2/veta_interactiva.md).

**La forja y fundición** ofrece patio e interior explorables con hornos, grúa, martillo de vapor y transmisiones. William habilita el tercer destino con la tarifa habitual; también se llega gratis caminando hacia la izquierda desde Ensamble del motor. La puerta permite entrar y conversar con Cort usando el diálogo y aviso compartidos. Continuar conserva mapa, posición, conversación y viaje. El [taller de Cort de seis fases](reports/phase2/taller_de_cort.md) incorpora regla y calibre móviles, mordazas, calor por zonas, matrices arrastrables, taladrado con avance sostenido, limado y comprobación de rebabas, y una transmisión que se gira manualmente bajo carga. La ayuda H explica los controles y pausa el trabajo. Los guardados anteriores conservan su avance. Murdoch recibe una sola biela antes de los engranajes; el carbón se reserva para la caldera. Véanse [recursos, prompts, capturas y pruebas](reports/phase2/fundicion_industrial.md).

**Ensamble del motor · Casa de máquinas** reúne tres mapas: patio exterior con William, nave interior con Murdoch y sala de montaje con el motor. Las puertas conectan ambos sentidos y los caminos del patio enlazan la mina y la fundición. Murdoch tiene la misma altura visible que el protagonista y orienta mediante el diálogo compartido. El aviso **E Trabajar en el motor** abre el montaje existente desde su sala; se conservan el puzzle, la biela instalada y los avances. Véanse [arte, prompts, capturas y 461 comprobaciones](reports/phase2/casa_de_maquinas.md).

La [limpieza del 11 de octubre de 2026](reports/limpieza/limpieza_2026-10-11.md) retiró temporales, capturas antiguas y recursos reemplazados, y recuperó aproximadamente 237 MB. Conservó código, escenas, pruebas y arte actual. Las diez ejecuciones de validación aprobaron desde una caché nueva e independiente. El proyecto temporal de validación se retiró al terminar; se recrea con `tests/prepare_validation.ps1`.
