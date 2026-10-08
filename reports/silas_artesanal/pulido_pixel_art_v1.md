# Pulido visual y recuperación de carga · 7 de octubre de 2026

- Tres sprites transparentes generados: rastrillo de hierro y roble, rollo de soga y tramo trenzado. Detalles y prompts en `assets/gba/ui/silas_pixel_art_v1_notes.md`.
- Fichas de los cabos con madera, herrajes, escala grabada y testigo de montaje; contacto de rueda y riel en y=237; anclaje de soga unido al carro. El sello y el rollo dejan libre el título.
- Se corrige la sobrecarga residual del resorte al reintentar: se conserva el número de sacos aprobados, se descarga el fallido y se prepara el freno. Los guardados con un aviso pendiente también se recuperan. El texto técnico queda en el aviso, sin desbordar sobre los controles laterales.

## Verificación

**412 comprobaciones aprobadas en Fácil y Difícil**, en `--headless` y en OpenGL Compatibility, sin errores ni advertencias. Se fuerzan sobrecargas con 0, 1 y 2 sacos aprobados en ambas dificultades; se cierra y reabre el aviso, se espera sin gastar oportunidades y se vuelve a izar desde el botón real hasta aprobar esa carga. Se conserva el trabajo anterior y se comprueba la reparación de un checkpoint antiguo con impulso residual.

Además, pasan reparación del molino y memoria de sesión en dos procesos separados. Resultados: `pixel_art_v1_validation.json`. Logs locales: `output/silas_pixel_rope_puzzle_test.log`, `output/silas_pixel_native.log`, `output/silas_pixel_mill_repair_test.log`, `output/silas_pixel_session_flow_test.log` y `output/silas_pixel_session_flow_test_read.log`.

Se revisaron capturas de las seis fases, los tres reintentos y el panel pequeño en `output/ui/silas_artesanal/`. Todas las pruebas usan el proyecto aislado `tmp/cart_validation_project`, con datos de usuario separados de la partida real.

```powershell
godot --headless --path tmp/cart_validation_project res://tests/rope_puzzle_test.tscn
```

Salida esperada: `ROPE ARTISAN SIX PHASES OK: 412 checks`.
