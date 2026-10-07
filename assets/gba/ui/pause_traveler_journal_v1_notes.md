# Cuaderno del viajero — pausa

Libro abierto inspirado en la propuesta elegida por el usuario. Se reutilizan cuatro estados de progreso; Elena conserva su papel narrativo y su caballo en la aldea, sin ficha de puzzle. La venta de harina permanece en 13 monedas.

## Capas

- `pause_traveler_journal_v1.png`: pergamino, cubierta de cuero, herrajes, dibujos del pueblo y herramientas en la izquierda y estudio de engranajes en la derecha. Sin textos, botones ni estados dibujados.
- `pause_journal_illustrations_v1.png`: atlas transparente de 3 × 2 celdas iguales. Fila superior: yunque, cuerda, sierra y troncos. Fila inferior: molino, cambiavías, celda vacía. Las regiones se leen como AtlasTexture en Godot.
- `scripts/ui/pause_journey_board.gd`: tipografía editorial, distribución de páginas, cuatro fichas, estados, contador y tres botones nativos con remaches de latón.

## Generación

Libro: se editó la propuesta Cuaderno del viajero para aislar el libro sobre transparencia y retirar todo texto, ficha, estado y botón. Se conservaron pergamino envejecido, cuero, encuadernación con anillas, cantoneras, aldeas y molino dibujados arriba a la izquierda, herramientas y farol abajo, y engranaje técnico arriba a la derecha. Se reservaron superficies limpias para los controles.

Ilustraciones: se pidió un atlas regular 3 × 2 con cinco grabados aislados de tinta sepia —yunque y martillo; cuerda de cáñamo; sierra y troncos; molino hidráulico; vías y cambiavías— sin textos, marcos ni fondo, con la última celda vacía.

Los PNG fueron generados con la herramienta integrada y copiados al proyecto. Los archivos originales se conservan en la carpeta de imágenes generadas; el juego utiliza únicamente los recursos dentro de `assets/`.

## Validación

`tests/five_puzzles_pause_test.tscn` comprueba que objetivo y guía estén en la página izquierda, las cuatro fichas en la derecha, contador y dificultad correctos, acciones de continuar y revisar historia, escalado de ventana, caballo persistente, economía y migración. Añadir `-- --capture-ui` con renderizado genera las capturas de Fácil y Difícil en `output/ui/pause_traveler_journal/`.

## Retirada del puzzle ferroviario

El cuaderno utiliza cuatro fichas en una cuadrícula de 2 × 2. La región del atlas que representa las vías ya no se dibuja; se conservan las otras cuatro ilustraciones y el libro original. El boleto permite subir directamente al tren, sin comprobar la antigua misión de vías.
