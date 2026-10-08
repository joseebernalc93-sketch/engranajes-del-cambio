# Silas: herramientas y sogas en pixel art

Generados con la herramienta integrada `image_gen` (habilidad imagegen), con fondo transparente. Los originales se conservaron y se copiaron al proyecto sin modificar su alfa. El renderer recorta el margen transparente mediante regiones de textura y usa filtrado nearest.

| Recurso | Intención del prompt |
| --- | --- |
| `silas_hatchel_pixel_v1.png` | Rastrillo de cáñamo del siglo XVIII: mango torneado de roble, remaches de hierro, doce dientes de acero hacia abajo; sprite frontal de pixel art con paleta cálida, sin texto ni interfaz. |
| `silas_rope_coil_pixel_v1.png` | Soga de cáñamo enrollada en varias vueltas trenzadas, hueco central y extremo suelto; pixel art de inventario con sombras ocres y luces doradas, sin círculos vectoriales ni sello. |
| `silas_rope_braid_pixel_v1.png` | Segmento horizontal de soga de tres cabos entrelazados, fibras y surcos visibles; pixel art de contorno oscuro y paleta de cáñamo, sin fondo ni otros objetos. |

Integración: rastrillos en las tres líneas de peinado; trenzado en cabos, máquina, remate y carga; rollo separado del título del sello. Las fichas del calibre llevan madera, cantoneras de latón, escala grabada y testigo de montaje.

El contacto de las ruedas del carro se fija en y=237 del taller de 800×420. El anclaje de la soga comparte el desplazamiento del sprite.

La recuperación del ensayo descarga solo el saco fallido, elimina el impulso residual del resorte y prepara el freno para la siguiente carga. Conserva las cargas aprobadas y las fases anteriores; también repara guardados anteriores con una sobrecarga pendiente.
