# Reiniciar fase 2: progreso y saldo de entrada

Reiniciar vuelve al relato inicial y a la llegada del tren, borra todos los datos de la Fase 2 y recupera las monedas y el inventario que había al terminar la Fase 1. La Fase 1 sigue completada y desbloqueada, con sus puzzles, dificultad y resumen conservados. Continuar y cancelar el reinicio mantienen el avance y saldo actuales.

## Estado restaurado

El guardado versión 19 incorpora `phase_two_entry`, una copia independiente del saldo y mochila tomada al completar la salida del tren, después de consumir el boleto. Con la economía actual son 87 monedas: 100 de la harina menos 3 de diligencia y 10 de tren. Se guarda el saldo real; no se fija a 87 en el código.

`restart_phase_two()` restaura esa copia y reemplaza `phase_two` por sus valores iniciales: sin descubrimientos, pasajes de Londres, trabajos completados, carbón, montaje del motor, combustible ni tiempo de presión acumulado. Las oportunidades vuelven a 15 en Fácil y 10 en Difícil. El checkpoint de Londres vuelve a la primera página del relato. El registro docente de la Fase 2 también se sustituye por estadísticas iniciales.

Para las partidas anteriores sin esa copia se recupera el saldo de entrada sumando al saldo actual los pasajes de Londres registrados en `city_transport.fares_paid`. Se excluyen de la mochila de entrada los costales, hulla y demás recompensas de la Fase 2, así como el boleto ya utilizado. Cargar esta migración conserva la partida en curso; la restauración ocurre únicamente al confirmar Reiniciar. El snapshot se guarda y se reutiliza, evitando duplicar reembolsos al reiniciar repetidamente.

## Pruebas

```powershell
godot --headless --path tmp/cart_validation_project res://tests/chapter_navigation_test.tscn
godot --headless --path tmp/cart_validation_project res://tests/chapter_navigation_test.tscn -- --read-navigation
godot --headless --path tmp/cart_validation_project res://tests/phase_one_smoke_test.tscn
```

Los dos primeros procesos van consecutivos, sin otras pruebas que escriban entre ambos; el lector restaura los archivos previos de validación. Resultado: **94 + 21 comprobaciones sin fallos**. Incluyen ambas dificultades, cancelar/continuar, regreso a Fase 1, reinicio con 37 monedas y cuatro costales, recuperación a 87, reinicios repetidos, migración de versiones 16 y 18 y saldos originales distintos de 87.

La prueba completa de la Fase 1 confirma la captura del saldo de 87 y la mochila sin boleto. La regresión de coches conserva **113 + 13 comprobaciones sin fallos**, incluido el cobro y migración anterior de la economía.
