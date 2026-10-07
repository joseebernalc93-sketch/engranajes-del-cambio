# Bruno: seis fases y dificultad seleccionable

Se mantienen el taller, las herramientas, las piezas de madera y la animación del corte, virutas, cuñas y carga. La regla, escuadra, marcas numeradas, indicadores y controles se dibujan con Godot; no se generaron imágenes nuevas.

1. **Veta:** seleccionar madera recta y seca; inspeccionar al pasar el cursor no gasta oportunidades.
2. **Medir:** regla de 160 cm, escuadra de 90° y tres marcas en orden, sincronizadas con el indicador verde. Clic en marcas, botón o Espacio.
3. **Fijar:** colocar tres fijaciones, regular la presión y confirmar la estabilidad.
4. **Serrar:** cinco recorridos alternos con ratón, tacto o flechas / A D. El corte profundiza y se desprende el sobrante.
5. **Cepillar:** ajustar la cuchilla y completar cuatro franjas a favor de veta. Ratón, tacto, Espacio o botón mantenido; las franjas aprobadas permanecen visibles.
6. **Carga:** tres sacos sucesivos. Regular el apoyo para conservar el indicador en verde 1,2 segundos; cada carga cambia la referencia. Un fallo retira únicamente el saco sin aprobar.

Fácil: 15 oportunidades, indicador a 0,25 del ritmo, herramientas con teclado a 0,5, corrección de carga durante 4 segundos, tolerancias mayores. Difícil: 10 oportunidades, ritmo original de las herramientas, indicador como el de Mateo en Difícil, corrección de carga durante 1 segundo y tolerancias más estrechas.

`lumber_attempts_spent` guarda los errores de la ronda; cambiar dificultad recalcula el saldo sin borrar los errores. `lumber_progress` guarda los pasos aprobados y ajustes. Los campos faltantes en partidas antiguas se leen con valores iniciales. Las oportunidades son independientes de los otros talleres. Las métricas nuevas registran marcas y errores de carpintería.

Cerrar conserva el progreso; los temporizadores llevan el identificador de sesión para evitar transiciones y recompensas de una sesión cerrada. Perder el foco cancela el gesto actual sin gastar una oportunidad. Una carga en observación se retira al reabrir; las aprobadas se restauran. Al agotarse las oportunidades, se cierra el taller y Bruno ofrece ánimo y una nueva ronda. Se respeta el bloqueo de movimiento del jugador y la entrega única de la tabla.

Los fallos con saldo disponible abren «Bruno: revisemos el trabajo», con causa, saldo y **Continuar esta fase**. El componente `scripts/ui/workshop_retry_notice.gd` usa madera oscura y latón y se ajusta al texto. Pausa herramientas e indicadores y bloquea controles hasta continuar con clic, Enter o Espacio; no hay nuevos cargos mientras se lee ni un golpe o pasada involuntaria al continuar con Espacio. Esc guarda el trabajo y cierra; agotarse el saldo sigue llevando directamente al diálogo de ánimo.

Validación: `tests/lumber_puzzle_test.tscn` recorre ambas dificultades, ratón, tacto y teclado, mide el ritmo real del indicador, verifica errores, persistencia tras cargar, conservación de la primera carga tras fallar la segunda, agotamiento inicial y en cepillado, reinicio, callbacks cancelados, independencia de presupuestos, entrega única e instalación en el molino. La captura opcional produce siete imágenes por dificultad en `output/ui/lumber_six_phases`.
