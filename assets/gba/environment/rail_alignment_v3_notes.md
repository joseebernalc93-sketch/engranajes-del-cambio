# Ampliación ferroviaria: seis curvas y dos cambiavías

Esta revisión conserva el tren, el andén original y la vista cercana de rieles sobre piedras aprobados. Se reutiliza la textura de balasto existente; no se generan ni modifican imágenes. Las nuevas piezas, palancas, topes, agujas y controles se dibujan con Godot y responden de forma independiente.

## Recorrido

Ocho controles: cambiavías A → curva de entrada → enlace central → curva de carga → retorno inferior → cambiavías B → enlace de salida → curva final → salida norte. Cada cambiavías une una entrada con tres ramales: recta, norte y sur. Sus apartaderos cerrados permanecen visibles para obligar a comprobar la dirección. La inspección recorre el trazado entre cada control. Las curvas giran en cuartos de vuelta; las palancas y agujas se mueven suavemente, y las barreras terminan de abrirse antes de avanzar. Los mecanismos tienen un breve sonido metálico sintetizado localmente.

El paso se bloquea ante una curva incorrecta, un cambiavías hacia un apartadero, agujas todavía en movimiento o controles fuera de orden. Las piezas verificadas y las piezas mientras pasa la inspección quedan bloqueadas. No se pierde progreso ni se cobran monedas por corregir.

## Controles

- 1–8: seleccionar control; flechas izquierda/derecha o Q/R: girar curva o cambiar vía.
- Ratón/tacto: tocar o arrastrar curvas; tocar palancas para recorrer sus tres posiciones o arrastrarlas a sus enclavamientos.
- Panel: ocho filas con selección, dos controles de giro/cambio y Paso. La ficha seleccionada muestra su orientación y ofrece Recta/Norte/Sur para los cambiavías.
- Espacio: iniciar/continuar inspección y abrir la señal final; Tab/Enter: navegar/confirmar botones; Esc: cerrar.
- Repetir maniobra: al completar, reinicia solo una práctica local. Conserva los datos guardados y no repite métricas ni recompensas.

## Código y compatibilidad

- `scripts/core/rail_route.gd`: topología, ocho posiciones, tipos, objetivos e inicio compartidos.
- `scripts/ui/rail_alignment_board.gd`: curvas, ramales, rieles fijos, recorrido continuo y entrada de ratón/tacto.
- `scripts/ui/rail_alignment_drawing.gd`: traviesas, rieles, agujas móviles, palancas, barreras, señal y vehículo inspector.
- `scripts/ui/rail_dispatch_popup.gd`: selección, controles, animaciones, seguridad, guardado y práctica.
- `scripts/core/game_state.gd`: guardado versión 8, diálogo, objetivo, requisito de ocho controles e informe de cambiavías.

Las partidas finalizadas mantienen su autorización y pueden repetir como práctica. Las partidas v7 parciales conservan sus cuatro curvas adaptadas al nuevo trazado; el prefijo comprobado se traslada hasta el primer tramo nuevo pendiente y se prepara el cambiavías de entrada. Las partidas del antiguo puzzle de vagoneta siguen migrando. Inventario, boleto, monedas y puzzles anteriores se conservan.

## Recursos reutilizados

`assets/gba/environment/rail_ballast_closeup_v1.png`, `assets/gba/environment/station_industrial_single_rail_v3.png`, `assets/gba/train_industrial_v2.png` y `shaders/train_wheels.gdshader`. El prompt de la textura generada anteriormente está en [rail_alignment_v2_notes.md](rail_alignment_v2_notes.md).

## Validación y demostración

`tests/rail_dispatch_test.tscn` comprueba el recorrido completo, las tres posiciones de las palancas, desvíos cerrados, agujas asentadas, barreras, ratón, tacto, teclado, cierre/reapertura, guardado, ventanas pequeñas, práctica sin alterar guardado/métricas, migraciones v6/v7, boleto y salida del tren original. Se valida también transporte, economía y expansión de la fase. Los archivos de los otros puzzles conservan sus hashes.

Vídeo: `tmp/cart_validation_project/tmp/rail_alignment/cambiavias_y_ocho_pasos.mp4`. Capturas: `rail_alignment_unconnected.png`, `second_turnout_blocked.png`, `all_rails_connected.png`, `inspection_completed.png`, `small_window.png` y `practice_replay.png`, en esa misma carpeta.
