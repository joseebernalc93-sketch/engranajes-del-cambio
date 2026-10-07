# Limpieza del proyecto completada

Fecha: 7 de octubre de 2026. Ejecutada despu?s de que el usuario confirm? su respaldo.

## Resultado

- Carpeta completa antes: aproximadamente **4,70 GB**.
- Carpeta completa despu?s: aproximadamente **291 MB**, incluida la cach? regenerada de Godot.
- C?digo, recursos y pruebas: aproximadamente **167 MB**; la cach? ocupa aproximadamente **124 MB**.
- Espacio liberado: aproximadamente **4,41 GB (94 %)**. Tama?os decimales, sin contar dos veces los enlaces de directorio.

Se retiraron **114 archivos antiguos sin referencias desde el juego ni las pruebas**, junto con sus metadatos y archivos hu?rfanos: **230 archivos individuales**. Se limpiaron `tmp/`, `scratch/`, `output/`, `build/` y `.godot/`. Esto incluye capturas, respaldos de trabajo y el APK anterior. Godot regener? su cach? y se recre? un proyecto m?nimo de validaci?n aislado; no se siguieron los enlaces de directorio durante la eliminaci?n.

Se conservaron el caballo del escenario, el tren, los cuatro puzzles actuales, la historia, el cuaderno, el resumen final y la pantalla de construcci?n de la fase 2. Tambi?n se conservaron 15 recursos usados exclusivamente por pruebas o herramientas de captura antiguas, y el c?digo de compatibilidad con partidas anteriores.

## Validaci?n

**13 comprobaciones aprobadas**: recorrido de la fase 1; herrero; hilandero; le?ador; reparaci?n del molino; controles de molienda; viaje en bote; diligencia; men? de pausa; final de cap?tulo; recuperaci?n del cap?tulo en otro proceso; flujo de sesi?n; recuperaci?n de sesi?n en otro proceso.

La importaci?n limpia de Godot termin? sin errores de recursos ni de scripts. Se elimin? una marca UTF-8 BOM de dos escenas de prueba que imped?a importarlas desde cero, sin modificar su contenido funcional. La auditor?a final no encontr? referencias de entrada inexistentes en el juego activo ni en las pruebas; las rutas de salida de capturas se consideran archivos generados.

Las pruebas utilizaron `EngranajesDelCambio_CleanupValidation`, un directorio de datos separado. **No se modificaron las partidas guardadas del juego original.** El cierre de una prueba de sesi?n registra una advertencia sobre tres objetos pendientes de liberar; no impidi? guardar ni recuperar la sesi?n.

## Prevenci?n

`.gitignore` excluye cach?, temporales, capturas y exportaciones. El preset Android excluye temporales, pruebas e informes. No se gener? un APK nuevo durante esta limpieza.

## Evidencia

- [Manifiesto de archivos retirados](reports/limpieza/manifest.json).
- [Auditor?a previa](reports/limpieza/auditoria_previa.json).
- [Referencias y tama?os finales](reports/limpieza/verificacion_recursos.json).
- [Resultados de las 13 comprobaciones](reports/limpieza/pruebas.json).
- [Importaci?n final de Godot](reports/limpieza/importacion_final.log).
