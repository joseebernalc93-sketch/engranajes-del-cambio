# Rediseño del túnel y el elevador

El usuario eligió el **modelo 3**. Su implementación se documenta en [Túnel de la mina: modelo 3 integrado](../tunel_mina_modelo3.md). Estas imágenes conservan la propuesta original; el juego usa fondos y piezas separados para animarlos.

Propuestas visuales del 8 de octubre de 2026. Todavía no sustituyen el escenario ni modifican la lógica jugable. Imágenes generadas con `image_gen` integrado, copiadas al proyecto y revisadas visualmente. Los prompts completos están en [prompts.json](prompts.json).

## Opciones

1. [Madera y ámbar](01_madera_ambar.png): vigas de madera, lámparas cálidas, riel discreto y jaula compacta. Recomendada por su continuidad visual con el juego y la claridad de la ruta.
2. [Ladrillo y pizarra](02_ladrillo_pizarra.png): entrada reforzada en ladrillo y carbón gris azulado; ambiente más sobrio.
3. [Hierro y carbón](03_hierro_profundo.png): madera reforzada, guías de hierro y tubería de drenaje; ambiente más industrial.

Las tres muestran un solo camino horizontal, techo bajo, elevador al comienzo izquierdo y veta de carbón al extremo derecho. El personaje incluido sirve para valorar proporciones; la implementación conservará el sprite jugable actual. Las piedras de caída van de tamaño de mano a cabeza, sin bloques mayores que el personaje.

## Funcionamiento propuesto

- Cámara lateral próxima, con desplazamiento horizontal si se extiende el túnel. Suelo a una altura fija: Flechas izquierda/derecha o A/D; clic/toque se proyecta a esa misma línea. Sin rutas para rodear por arriba o abajo los desprendimientos.
- Tres zonas de caída separadas por espacios seguros. Secuencia: crujido y polvo, caída de piedras pequeñas, rebotes breves y apertura del paso. El jugador observa y espera antes de avanzar. Las zonas no cierran simultáneamente todo el recorrido.
- Tras superar los tres tramos se llega al carbón y se conserva la extracción/clasificación actual. El regreso conduce por el mismo túnel al elevador izquierdo. Se conservan las etapas y el inventario de la misión ya implementada.
- Un impacto descuenta una oportunidad, abre la explicación y devuelve al último espacio seguro; la revisión pausa el mundo y evita descuentos repetidos. Se mantienen las 15/10 oportunidades compartidas.
- En superficie, E junto al elevador inicia una secuencia de aproximadamente 8–10 segundos: el personaje entra, cierra la compuerta, gira el torno y la cámara acompaña la jaula al bajar por el pozo. Al llegar se abre la compuerta y el personaje sale hacia la derecha. Sin sustituir ese movimiento por un simple fundido.
- En el inicio izquierdo del túnel, E inicia la secuencia inversa de subida. Durante el viaje no se camina ni se vuelve a activar el elevador. Cuaderno, inventario y pérdida de foco lo pausan. El guardado conserva dirección e instante del trayecto.

## Preparación para integrar el modelo elegido

El fondo definitivo se preparará sin personaje ni piedras suspendidas: personaje, escombros, polvo, cuerdas y jaula serán capas o nodos independientes para que la animación sea real. La escala de la jaula y de los soportes se ajustará a la altura visible del sprite existente; el techo tendrá aproximadamente 2–2,5 veces esa altura. La cabina de superficie y la subterránea usarán el mismo diseño. Las pruebas verificarán la restricción horizontal, las ventanas seguras, la recuperación de impactos y la continuación de ambas direcciones del elevador.
