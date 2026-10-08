# Verificación del banco artesanal de Bruno

Fecha: 7 de octubre de 2026. Motor: Godot 4.7.2 estable.

- Las 14 suites registradas en [pruebas.json](pruebas.json) finalizaron correctamente, sin errores de scripts ni aserciones.
- La suite de carpintería aprobó 276 comprobaciones en Fácil y Difícil: seis fases, mouse, touch y teclado, oportunidades, recuperación parcial, agotamiento, migración, entrega única e instalación.
- Se verificó además la recuperación de una carga activa mediante dos procesos independientes (`--write-bruno` / `--read-bruno`).
- Se ejecutó la suite con renderizado OpenGL Compatibility: shaders compilados y capturas revisadas de las fases, la lente y una ventana de 640 × 360.
- Se validó el preparador `tests/prepare_validation.ps1`. Las pruebas usaron el proyecto aislado y no modificaron las partidas originales del jugador.
- `git diff --check` no encontró errores de formato.

Las capturas locales están en `output/ui/bruno_artesanal`. Los logs completos permanecen en esta carpeta y en `output/`, excluidos del repositorio por `.gitignore`. La suite de sesión mantiene su advertencia previa de tres objetos pendientes al cerrar; las pruebas de guardado y recuperación finalizaron correctamente.

La guía de mecánicas, arquitectura y ejecución está en [bruno_artesanal_v4_notes.md](../../assets/gba/ui/bruno_artesanal_v4_notes.md).
