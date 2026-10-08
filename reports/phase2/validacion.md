# Verificación de la Fase 2

Fecha: 2026-10-07. Motor utilizado: Godot 4.7.2 estable. Renderizado real: OpenGL Compatibility, NVIDIA GeForce RTX 5070. Los procesos de prueba usan `EngranajesDelCambio_CleanupValidation`; las partidas del juego principal no se modifican.

| Verificación | Resultado |
|---|---|
| `phase2_factory_test.tscn`, headless | **296 comprobaciones correctas** en Fácil y Difícil |
| Misma suite con ventana y capturas | **296 comprobaciones correctas**, sin errores de scripts ni shaders |
| `phase2_session_test.tscn` + `--read-phase2` | Cierre y reapertura en otro proceso: etapa, revisión, turno, fardos, bobinas, rotura y presupuesto recuperados |
| `chapter_journal_flow_test.tscn` + `--read-chapter` | Salida real del tren, cuatro viñetas, complejo, cuaderno, páginas, menú, guardado y reinicio correctos; también probado con renderizado real |
| `session_flow_test.tscn` + `--read-session` | Flujo y memoria de los cinco paneles de los cuatro puzzles de la Fase 1 correctos |
| `lumber_puzzle_test.tscn` | **276 comprobaciones correctas** |
| `rope_puzzle_test.tscn` | **436 comprobaciones correctas** |

La suite industrial verifica controles sin deslizadores, toque/arrastre, Tab/Mayús+Tab, flechas correctamente mapeadas, pausa por pérdida de foco, revisión sin consumo repetido, tolerancias y margen crítico, recuperación de todos los tipos de error, oportunidades compartidas, etapas conservadas, agotamiento, recompensas únicas, jornada de 120 segundos, reparación de telares por toque, reporte atómico en otro hilo, persistencia y ventana pequeña.

Se inspeccionaron las doce imágenes generadas, las cuatro viñetas dentro del marco real, el complejo, las revisiones, el cabrestante, la sala de vapor, el montaje textil sin correas/con dos correas, el turno y la página industrial del cuaderno. Capturas locales: `output/ui/phase2/` y `output/ui/chapter_journal/`. Los logs `output/phase2_*.log` quedan fuera del repositorio.

En esta máquina, Godot no está en `PATH`. Para reproducir la prueba directamente:

```powershell
$factoryGodot = 'F:/Descargas/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
./tests/prepare_validation.ps1 -GodotExecutable $factoryGodot
& $factoryGodot --headless --path tmp/cart_validation_project res://tests/phase2_factory_test.tscn
```

Si `godot` está en `PATH`, el comando del encargo funciona sin cambios:

```powershell
godot --headless --path tmp/cart_validation_project res://tests/phase2_factory_test.tscn
```

El arte se generó con la herramienta integrada `image_gen`, se guardó en `assets/phase2/` y se integró en escenas y atlas. Los prompts exactos están en [generation_prompts_v1.json](../../assets/phase2/generation_prompts_v1.json). Los controles, reglas y fuentes históricas se detallan en [implementacion.md](implementacion.md).
