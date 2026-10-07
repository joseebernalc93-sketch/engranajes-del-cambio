# Fragua de Mateo: diez oportunidades y continuidad por fase

Actualizado el 5 de octubre de 2026. Mantiene las seis etapas, los controles y las animaciones de la versión 3. Sustituye la regla de tres oportunidades y reinicio completo documentada en `mateo_challenge_v3_notes.md`.

## Reglas de continuidad

- Una sola bolsa de diez oportunidades para todo el trabajo. Cambiar de fase no la repone.
- Cada fallo confirmado descuenta una oportunidad y pausa las herramientas. La explicación incluye la causa, el contador y el botón «Continuar esta fase».
- Montaje conserva refuerzos colocados, orientaciones y abrazaderas; calor conserva el montaje; remaches conserva impactos válidos y orden; enfriamiento conserva la temperatura alcanzada y todos los remaches; eje conserva los tornillos ajustados; carga conserva los niveles comprobados y el giro parcial.
- Tras un fallo térmico se recupera el calor de trabajo. Tras un fallo de ventilación se recupera un caudal seguro. Las herramientas quedan sueltas y los temporizadores de peligro se limpian para permitir corregir.
- El décimo error cierra el taller en cualquier fase. Mateo anima al jugador. Solo su opción de nueva ronda repone diez oportunidades y reinicia el montaje, conservando el hierro entregado.
- Cerrar y reabrir conserva la fase y su avance, incluso tras guardar/cargar. Una acción de martillo cancelada no suma impactos; una transición ya validada continúa al abrir. La rueda se entrega una única vez.

## Persistencia y validación

`GameState.FORGE_OPPORTUNITIES` define el total. El contador y `forge_progress` se guardan en las flags de la partida, versión 10. Se guarda al cambiar de fase, al fallar y al cerrar. La versión 9 recibe siete oportunidades adicionales: 3→10, 2→9, 1→8, 0→7. La migración se aplica una sola vez y conserva los puzzles completados y el inventario.

`tests/wheelwright_forge_test.tscn` recorre las seis etapas con siete errores repartidos y termina con tres oportunidades. Comprueba que cada error conserva el trabajo anterior y el avance parcial de la fase, incluyendo guardar y reabrir en carga. También verifica diez errores hasta agotamiento en carga, bloqueo de apertura directa, nueva ronda, controles, foco, transiciones canceladas, entrega e instalación únicas y migración de guardados.

No se modifican imágenes ni otros puzzles. Las capturas actuales se guardan en `tmp/cart_validation_project/tmp/forge_challenge/`, incluidas `load_retry.png` y `load_resumed.png`.
