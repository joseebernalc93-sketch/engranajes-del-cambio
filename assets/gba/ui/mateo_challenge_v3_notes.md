# Fragua de Mateo: reto de seis etapas

Implementado el 5 de octubre de 2026. Se reutilizan las imágenes existentes; los nuevos refuerzos, muescas, abrazaderas, indicadores, tornillos, manivela y controles se dibujan con Godot. No se generan ni editan imágenes.

## Reglas

1. Montar cuatro refuerzos según número y muesca. Las piezas se giran y arrastran; una entrega fuera del área de montaje vuelve a la bandeja sin penalizar. Encajar una pieza incorrecta o confirmar un montaje sin todas las piezas y ambas abrazaderas consume una oportunidad.
2. Calentar el hierro y mantenerlo dos segundos entre 82 y 96 unidades del indicador. El exceso mantenido durante dos segundos falla; V y Ventilar permiten corregirlo antes.
3. Remachar en orden 1–3–2–4. Cada refuerzo requiere tres impactos. La rueda debe estar alineada, el calor entre 70 y 96 y el indicador de golpe entre 38% y 62%. El golpe se decide al pulsar y la pieza se modifica al impactar el martillo. Un golpe confirmado incorrecto consume una oportunidad.
4. Enfriar regulando la ventilación. El caudal del deslizador controla la velocidad de enfriamiento; la franja de trabajo varía lentamente. Una desviación sostenida de dos segundos falla. Al alcanzar la temperatura fría se habilita el centrado.
5. Centrar tres tornillos independientes. Cada uno tiene su propia marca de trabajo; la tolerancia es 0,065. El comparador y la oscilación muestran la desviación. Confirmar un eje fuera de tolerancia falla.
6. Accionar una manivela bajo tres niveles de carga. Los objetivos de velocidad son 1,0, 1,25 y 1,5, con tolerancia de 0,28. Solo el giro estable cuenta; cada nivel requiere un tercio de vuelta. El exceso sostenido durante 1,3 segundos falla tras una advertencia. Soltar permite frenar y corregir.

## Tres oportunidades

Cada fallo válido y confirmado registra una sola oportunidad consumida y su causa. Las herramientas se liberan, las animaciones y sus callbacks se cancelan y se muestra la explicación. Reintentar vuelve al montaje con piezas, abrazaderas, calor, remaches, eje y carga reiniciados. Al llegar a cero, el taller se cierra y Mateo muestra su mensaje de ánimo, con opciones para iniciar otra ronda o volver después.

El hierro ya entregado no vuelve a cobrarse ni se pierde. Cerrar, reabrir, guardar o cargar conserva las oportunidades. Abrir el taller con cero oportunidades lleva al diálogo; solo la acción explícita de nueva ronda repone las tres. Perder el foco pausa los temporizadores de fallo y libera controles. La rueda se entrega únicamente tras verificar las seis etapas y la entrega no se repite si ya fue instalada.

El guardado versión 9 añade `forge_attempts_left`; los guardados anteriores reciben tres oportunidades sin alterar sus piezas, boleto ni puzzles completados. El informe añade intentos fallidos, oportunidades restantes y rondas.

## Recursos y código

Imágenes reutilizadas: `mateo_workshop_backdrop_v2.png`, `mateo_forge_bellows_sheet_v1.png`, `mill_gear_piece_v1.png`, `mateo_pinion_v2.png` y `environment/forge_fire_sheet.png`. Sus prompts anteriores siguen en `mateo_workshop_v2_notes.md`.

- `scripts/ui/wheelwright_forge_popup.gd`: seis etapas, controles, oportunidades, advertencias, precisión y transiciones.
- `scripts/ui/forge_challenge_tools.gd`: piezas arrastrables, abrazaderas, indicadores, tornillos y manivela.
- `scripts/ui/forge_workbench_display.gd`: conserva el taller y sus animaciones, con visibilidad adaptada al montaje y al eje.
- `scripts/core/game_state.gd`: persistencia, fallo, mensaje de Mateo, nueva ronda e informe.
- `scripts/game.gd`: conserva el bloqueo de movimiento al iniciar la nueva ronda desde el diálogo.

## Validación

`tests/wheelwright_forge_test.tscn` cubre el recorrido entero, fallos de montaje y precisión, tres oportunidades, persistencia y agotamiento, diálogo, nueva ronda, ratón/tacto/teclado, abrazaderas, tiempos térmicos, impactos reales, caudal, tornillos, manivela, entrega única, instalación, cancelaciones y guardados previos. Se comprueban además el puzzle del tren, la economía y la expansión de la fase.

Las capturas se guardan en `tmp/cart_validation_project/tmp/forge_challenge/`: `assembly.png`, `retry_explanation.png`, `heat.png`, `precision_rivets.png`, `cooling.png`, `centering.png`, `loaded_crank.png`, `mateo_encouragement.png`, `complete.png` y `small_window.png`.

Vídeo del recorrido, incluido un agotamiento y la nueva ronda: `tmp/cart_validation_project/tmp/forge_challenge/seis_etapas_y_oportunidades.mp4`. Grabador: `tests/_capture_forge_motion.tscn`; usar un proyecto con nombre distinto para proteger la partida del jugador.
