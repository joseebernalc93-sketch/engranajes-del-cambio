# Silas: escenarios y herramientas por etapa

Recursos creados con la herramienta integrada `image_gen` de la habilidad imagegen. Los dos fondos se editaron a partir de `ropewalk_backdrop_v2.png` para conservar el taller, su paleta y la iluminación. Los sprites se generaron con transparencia. Los originales permanecen en el directorio de generación; las copias utilizadas están en esta carpeta.

| Archivo | Notas del prompt |
| --- | --- |
| `silas_carding_room_pixel_v2.png` | Sustituir completamente máquina, ganchos, cono y rieles por una mesa de roble vista desde arriba, con herrajes, tres espacios de trabajo, útiles laterales y luz cálida. Se refinó la composición para que los tres manojos queden sobre el tablero y las patas ocupen solo la franja inferior. |
| `silas_proof_room_pixel_v2.png` | Sustituir la máquina por un pórtico de roble con refuerzos de hierro, dos poleas de latón y espacio libre para la cuerda y el costal dinámicos. Reservar el lateral derecho para dinamómetro y freno. |
| `silas_brake_parts_pixel_v2.png` | Dos piezas separadas: pedestal de freno de hierro con tornillos y eje de latón; brazo vertical de hierro con mango torneado de roble y orificio de articulación inferior. Sin interfaz ni letras. |
| `silas_binding_jig_pixel_v2.png` | Aro físico de latón visto de frente, centro transparente, divisiones grabadas, flechas horarias y pestañas remachadas. Pixel art de contornos definidos. |
| `silas_binding_thread_pixel_v2.png` | Una vuelta ovalada de hilo encerado con textura de fibras y centro transparente; repetida sobre la soga para representar las tres vueltas aseguradas. Se refinó el borde del sprite. |
| `silas_hemp_bundle_pixel_v2.png` | Manojo horizontal de cáñamo suelto, filamentos naturales ondulados y puntas deshiladas; sin trenzado ni patrones geométricos repetidos. |

## Integración

- Etapa 1: mesa y tres manojos naturales; etiquetas separadas de los recorridos de los rastrillos.
- Etapas 2–5: taller con la máquina de cordelería. El remate usa el aro ilustrado, hilo trenzado y un pequeño ovillo móvil; mantiene el recorrido circular y el tirón de cierre.
- Etapa 6 y entrega: pórtico de poleas, cuerda dinámica y costal suspendido. La cuerda nace en la tangente de la polea y llega a la boca del costal, que permanece sobre el suelo.
- Ambas palancas giran sobre una articulación fija. El arrastre calcula el ángulo desde ese eje; las flechas conservan el control alternativo. Las regiones de atlas excluyen los márgenes transparentes y usan filtrado nearest.
- El shader de peinado ilumina progresivamente las fibras ilustradas, conservando su alfa.

Se conservan dificultad, oportunidades compartidas, pausas de revisión, reintento de carga, checkpoints, entrega única e instalación en el molino.
