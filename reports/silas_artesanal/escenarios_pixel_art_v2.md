# Escenarios y palancas de Silas · 7 de octubre de 2026

Se integraron seis recursos de pixel art: mesa de peinado, pórtico de poleas, piezas de palanca, aro de remate, hilo encerado y manojo de cáñamo. Se revisaron capturas de mesa, máquina, remate con tres vueltas, ensayo de carga y ventana de 640×360. Recursos y prompts: `assets/gba/ui/silas_stage_scenery_v2_notes.md`.

**436 comprobaciones aprobadas en Fácil y Difícil**, tanto con `--headless` como con el renderizador OpenGL Compatibility de Godot 4.7.2, sin errores ni advertencias. Se añadieron veinte verificaciones de arrastre táctil de ambas palancas a cinco posiciones, conexión de cuerda con polea/costal y ausencia de penalización al mover controles sin carga. Se mantienen los recorridos completos por teclado y tacto, los seis casos de recuperación tras sobrecarga, persistencia, agotamiento y recompensa/instalación únicas.

Logs locales: `output/silas_pixel_v2_headless.log` y `output/silas_pixel_v2_native.log`. Capturas: `output/ui/silas_artesanal/`. Las pruebas usan exclusivamente `tmp/cart_validation_project`, con datos de usuario separados de la partida real.

```powershell
godot --headless --path tmp/cart_validation_project res://tests/rope_puzzle_test.tscn
```

Salida esperada: `ROPE ARTISAN SIX PHASES OK: 436 checks`.
