# Engranajes del Cambio

Prototipo educativo en Godot 4.7 sobre la Revolución Industrial para estudiantes de 10mo de EGB.

## Ejecutar el juego

1. Clona o descarga este repositorio.
2. Abre Godot 4.7.2 y selecciona **Importar** para abrir `project.godot`.
3. Espera a que Godot importe los recursos y pulsa **F5** para iniciar el juego.

La fase 1 está disponible. La fase 2 muestra una pantalla de construcción. El juego permite elegir dificultad y guarda el progreso localmente en la carpeta de datos de usuario de Godot. Las partidas, la caché, las capturas temporales y los instaladores generados no se incluyen en el repositorio.

## Prototipo actual

La introducción de la fase 1 presenta **El precio de la lana**, con cuatro ilustraciones: la producción del criadero, el portón que divide el acceso a la tierra, la conversación con Elena y la preparación de la partida. Sus recuadros y botones combinan madera oscura, doble marco de latón, remaches y adornos de engranajes, siguiendo el botón «Comenzar» de la portada. Incluyen títulos por escena y navegación adelante/atrás. La última acción dice **Empesar primera fase**, según el texto solicitado, y abre el criadero desde el camino público. Los recursos y la validación están documentados en `assets/gba/story/wool_price_v3_notes.md`.

La primera fase permite experimentar el éxodo rural mediante acciones de juego:

1. Explorar los campos cercados y recolectar el trigo del sembrío junto al molino.
2. Conversar con una campesina desplazada.
3. Reutilizar las herramientas agrícolas para forjar una rueda y conseguir las piezas del molino.
4. Reparar y operar el molino hidráulico, regulando el agua para transformar el trigo en harina.
5. Vender el costal de harina por 13 monedas para pagar ambos pasajes.
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

La salida derecha de la aldea conduce a una nueva estación de carretas con posada, establos, cobertizo de carga y dos diligencias con caballos. Ramón cobra **3 monedas** por el trayecto hasta la estación del tren; el pasaje incluye el regreso. Cancelar no descuenta monedas y el cobro se guarda una sola vez. El panadero paga 13 monedas por la harina: 3 para la diligencia y 10 para el tren. Elena conserva su diálogo histórico y su caballo en la aldea, sin puzzle propio. Las partidas anteriores mantienen sus puzzles completados y reciben el ajuste de transporte si lo necesitan.

La travesía de 15,6 segundos muestra al personaje subiendo, la salida del patio, el camino entre los campos, la llegada a la estación y el descenso a pie. La cámara sigue la diligencia; el caballo camina, las ruedas giran según la distancia y la carrocería tiene suspensión y polvo. **E**, **Espacio**, **Esc** o **Continuar** adelantan el viaje. La llegada deja al jugador en la escena real con los controles restaurados.

`scenes/station.tscn` contiene la fachada exterior y la entrada principal, con explanada, bancos y equipaje. La puerta lleva a la taquilla; con el boleto comprado se accede al andén de `scenes/station_platform.tscn`. Los viajes en diligencia y las monedas de pasaje aparecen en el registro docente. Los cinco recursos de la diligencia y sus prompts se documentan en `assets/gba/environment/passenger_coach_route_v1_notes.md`.

`tests/passenger_coach_test.tscn` comprueba el acceso caminando, las colisiones, saldo insuficiente, cancelación, cobro único, venta de harina por 13 monedas, los cinco momentos de ida y regreso, las ruedas y las cuatro poses del caballo, llegada, taquilla, boleto, andén, partida real del tren, guardado y migración. Ejecuta con `--headless --path tmp/cart_validation_project res://tests/passenger_coach_test.tscn`. Para capturas, omite `--headless` y añade `-- --capture-ui`. `tests/_capture_coach_voyage.tscn` permite grabar con `--write-movie` y `--fixed-fps 30`; añade `-- --return` para el regreso. Los puzzles existentes conservan sus archivos.

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

El puzzle «La cuerda bajo tensión» tiene seis etapas: seleccionar fibras, peinar tres manojos, igualar y montar los cabos, controlar la torsión, ajustar tres vueltas de ligadura y probar tres cargas progresivas con un freno. Conserva la rueda, la manivela, el carro y sus ruedas animadas. Fácil comparte 15 oportunidades entre las seis etapas, mueve los indicadores de precisión a un cuarto del ritmo de Difícil y deja cuatro segundos para corregir sobrecargas. Difícil comparte 10 oportunidades y usa el ritmo exigente de la fragua, con un segundo para corregir la tensión.

- Peinado: selecciona el manojo con **1–3** o sus botones. Haz dos pasadas por manojo con **Espacio** en verde, o arrastra el rastrillo y suéltalo en la zona indicada.
- Montaje: regula el grosor de referencia con el deslizador y pulsa los ganchos iluminados o sus botones. La franja verde admite más margen en Fácil. También puedes navegar con Tab y confirmar con Enter.
- Torsión: mantén **Espacio** (o pulsa y mantén la rueda o el botón de manivela). Ajusta el carro con **← → / A D**, arrastrándolo o con el deslizador.
- Mantén la tensión entre **45 y 70** en el indicador verde. La carga aumenta ligeramente mientras se tuerce la cuerda; una sobrecarga sostenida activa el freno de Silas sin borrar el progreso.
- Ligadura: elige el remate correcto y ajusta tres vueltas con **Espacio**, el botón o arrastrando el hilo. Cada vuelta correcta permanece asegurada si fallas otra.
- Carga: mantén **Espacio** o el botón de prueba para levantar el saco. Regula el freno con **← → / A D** o su deslizador mientras aumenta el peso. Las comprobaciones superadas se conservan si sueltas o fallas. La rueda principal permanece bloqueada durante esta prueba.
- Cada error consume una oportunidad sin volver a la primera etapa. Silas muestra «Revisemos el trabajo» con la explicación, el saldo y el botón **Continuar esta fase**. El aviso pausa las herramientas y los indicadores; se continúa con clic, Enter o Espacio. Cerrar y volver conserva el avance y los errores. Al agotarlas, Silas ofrece empezar una nueva ronda; cambiar de dificultad conserva las oportunidades ya gastadas.
- Esc cierra el puzzle. Soltar el control o cambiar de ventana detiene la manivela. El panel se adapta al tamaño de la ventana.

Los recursos por capas están en `assets/gba/ui/ropewalk_*_v2.png`; el rastrillo y los controles de ligadura se dibujan en Godot. La escena `tests/rope_puzzle_test.tscn` verifica los seis pasos en ambas dificultades, controles directos, margen de precisión, recuperación parcial, guardado, agotamiento y nueva ronda, entrega única e instalación en el molino. Se ejecuta con `--path tmp/cart_validation_project res://tests/rope_puzzle_test.tscn`; añadir `-- --capture-rope` sin `--headless` genera capturas en `output/ui/rope_six_phases`.

## Carpintería de Bruno

El puzzle «La tabla que sostiene el molino» tiene seis fases: elegir la veta, medir y marcar, fijar, serrar, cepillar y probar tres cargas. El taller permanece fijo mientras las cuñas entran, la escuadra gira, la sierra profundiza el corte y el sobrante cae. Cada pasada del cepillo deja una franja lisa con virutas; los sacos hacen flexionar la tabla entre sus apoyos.

Fácil ofrece **15 oportunidades** para todo el puzzle, el indicador de marcado avanza a un cuarto del ritmo de Difícil, las herramientas con teclado a la mitad y las zonas seguras son más amplias. Difícil ofrece **10 oportunidades**, el ritmo normal y ajustes más precisos. Cada fallo descuenta una oportunidad y permite continuar en la fase actual. Las marcas, fijaciones, cortes, franjas y cargas aprobadas se guardan al cerrar y cargar la partida. Al agotar el total, el taller se cierra y Bruno anima al jugador; «Intentar de nuevo» prepara otra pieza con el total correspondiente a la dificultad elegida. Sus oportunidades son independientes de las de Mateo y Silas.

Ante un fallo, Bruno muestra **Revisemos el trabajo**, con la causa, las oportunidades restantes y **Continuar esta fase**. El recuadro de madera y latón se ajusta al texto, bloquea los controles del taller y detiene herramientas e indicadores hasta continuar con el botón, Enter o Espacio. Esc permite cerrar y conservar el trabajo. El aviso no añade errores mientras está abierto; el último fallo sigue cerrando el puzzle para mostrar el diálogo de ánimo.

- Inspección: pulsa las marcas sobre la madera o usa los botones. La selección de un defecto consume una oportunidad; pasar el cursor para examinarlo no consume ninguna.
- Medición: ajusta la regla a 160 cm y la escuadra a 90°. Marca los tres puntos en orden con el ratón, **Espacio** o el botón cuando el indicador esté en verde. Los ajustes y las marcas terminadas se conservan.
- Fijación: coloca tres fijaciones, regula la presión de la abrazadera en verde y confirma la estabilidad. Tab, flechas y Enter permiten manejar los controles.
- Sierra: arrastra el mango iluminado alternando los dos sentidos, o mantén **← → / A D** en el sentido indicado. Hay cinco recorridos; soltar antes de terminar permite repetir el recorrido.
- Cepillo: ajusta la profundidad de la cuchilla en verde; arrastra de izquierda a derecha con presión uniforme, mantén **Espacio** o el botón **Cepillar**. Suelta y vuelve a pulsar para cada una de las cuatro franjas.
- Carga: arrastra el saco desde su botón al lugar marcado, pulsa la marca o usa **Colocar**. Ajusta el apoyo para sostener la aguja en verde durante 1,2 segundos por carga. Cada saco cambia la referencia; tienes más tiempo para corregir en Fácil. Si falla, se retira solo el saco que estaba a prueba. La tabla se entrega una única vez, tras las tres comprobaciones.
- Esc cierra el taller. Soltar fuera de la herramienta o cambiar de ventana libera el agarre. Las transiciones pendientes se cancelan al cerrar y el panel se adapta a ventanas pequeñas.

Los recursos están en `assets/gba/ui/bruno_workshop_backdrop_v2.png` y `bruno_workpieces_v2.png`; las instrucciones de generación se documentan en `bruno_workbench_v2_notes.md`, y los cambios de interacción en `bruno_six_phases_v3_notes.md`. `tests/lumber_puzzle_test.tscn` verifica los seis pasos en ambas dificultades, controles de ratón, táctiles y teclado, avisos de error y pausa sin penalizaciones adicionales, persistencia, agotamiento y reinicio, carga progresiva, recompensa única e instalación en el molino. Ejecuta las pruebas con un nombre de proyecto separado para proteger los datos del jugador; la carpeta local `tmp/cart_validation_project` sirve para ese fin. Añade `-- --capture-lumber` con renderizado para guardar las fases y los avisos en `output/ui/lumber_six_phases`.

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

El puzzle del carro se ha retirado. Elena conserva sus diálogos sobre el cercamiento; el caballo, la carreta y sus colisiones permanecen en el mismo lugar incluso al cargar partidas antiguas. Ya no se requiere ayudar con el carro para comprar el boleto o subir al tren. La harina se vende por 13 monedas y paga ambos pasajes. Los recursos antiguos de la carreta quedan como material de archivo, sin acceso desde el juego.

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

El guardado versión 14 conserva dificultad, posición, avances y el resumen final del capítulo. Si una partida anterior recibió solo 10 monedas por la harina y no cobró la antigua ayuda de Elena, recibe 3 monedas una sola vez. Los guardados dentro del puzzle retirado vuelven al mismo lugar de la aldea con movimiento disponible.

`tests/five_puzzles_pause_test.tscn` verifica el caballo persistente, la ausencia del puzzle, el pago único de 13 monedas, el viaje y el boleto sin Elena, cuatro tarjetas dinámicas, ambas dificultades, tamaño del menú, los botones y la migración sin duplicar monedas. Ejecuta con `--headless --path tmp/cart_validation_project res://tests/five_puzzles_pause_test.tscn`. Omite `--headless` y añade `-- --capture-ui` para generar vistas en `output/ui/pause_traveler_journal/`.

## Cierre de la fase 1 y cuaderno de capítulos

La salida del tren abre la última página del **Cuaderno del viajero**, con cuatro fichas de oficios, logros de la cosecha y del molino, cuentas del viaje, tiempo, dificultad y reflexión histórica. Los datos del informe se fijan al terminar la fase.

**Seguir explorando** abre la pantalla **Fase 2 en construcción**. **Esc** abre y cierra el cuaderno, comenzando por la nueva página de la fase 2. **Fase anterior / Fase siguiente**, o las flechas izquierda/derecha, permiten revisar el resumen de la fase 1 y volver a la fase 2. El guardado recuerda esta pantalla, la página elegida y si el libro estaba abierto. **Volver al inicio** conserva la partida; **Reiniciar fase** comienza de nuevo la historia de la fase 1 con la dificultad elegida.

`tests/chapter_journal_flow_test.tscn` prueba el flujo con la salida real del tren y una segunda ejecución del motor. Ejecuta primero la escena en el proyecto aislado y después repite con `-- --read-chapter`; para generar capturas, ejecuta la primera con renderizado y `-- --capture-ui`. Los recursos y prompts de generación se documentan en `assets/gba/ui/chapter_journal_v1_notes.md`; las capturas están en `output/ui/chapter_journal/`.
