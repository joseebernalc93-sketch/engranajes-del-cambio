# Verificación de Silas · 7 de octubre de 2026

Se sustituyó el puzzle anterior por seis operaciones de cordelería con herramientas directas, revisión pedagógica y persistencia versionada. El inventario conserva el ID `cuerda` y su instalación en el molino.

## Resultado

- **308 comprobaciones aprobadas** en `tests/rope_puzzle_test.tscn`, en Fácil y Difícil, tanto con `--headless` como con renderizador OpenGL Compatibility de Godot 4.7.2. Incluyen la revisión posterior de anclajes, guía cónica y seguimiento del carro.
- Ejecución final del puzzle **sin errores, advertencias ni instancias huérfanas al salir**. El recorrido acelerado espera que el servidor de audio libere sus voces antes de cerrar el motor.
- **14 pruebas de integración aprobadas**, código de salida 0 y archivos de error vacíos: recorrido general, fragua, cordelería, carpintería, reparación y operación del molino, bote, diligencia, cuaderno de pausa, inventario, diario de capítulos y memoria de sesión en dos procesos.
- **Persistencia entre dos procesos independientes**: escritura de un ensayo con el segundo saco activo; lectura de la fase, la primera carga aprobada y el ajuste exacto del freno. Los archivos anteriores del directorio aislado se restauraron después.
- Capturas revisadas de las seis fases, remate cerrado, carga activa, revisión y ventana de **640×360**, en `output/ui/silas_artesanal/`.

Los controles se prueban por sus rutas públicas: rastrillo arrastrado con tacto, agarre desde su mango, calibres, arrastre de porciones al gancho sin modificar la masa, dos dedos simultáneos en rueda y carro, círculos de ligadura, tirón final y saco/freno. Un segundo recorrido completa las seis fases mediante teclado en ambas dificultades sin gastar oportunidades.

Se comprueban fallos por inclinación y velocidad del rastrillo, grosor desigual, sobretensión, destorsión, exceso de tensión durante compactación, vuelta incompleta o invertida y ensayo de carga. La revisión congela la simulación, evita descuentos duplicados y se recupera tras cerrar y cargar. Se verifican agotamiento, diálogo de Silas, nueva ronda, tolerancias, reloj cuatro veces más lento, migración de ganchos antiguos, entrega única e instalación única. El resorte se comprueba a 30, 60 y 120 Hz.

## Reproducción

```powershell
powershell -ExecutionPolicy Bypass -File tests/prepare_validation.ps1 -GodotExecutable godot
godot --headless --path tmp/cart_validation_project res://tests/rope_puzzle_test.tscn
```

Salida esperada: `ROPE ARTISAN SIX PHASES OK: 308 checks`.

Evidencia: `pruebas.json`, `final_headless.err`, `final_render.err`, `write-silas.err` y `read-silas.err`. Los logs completos y capturas permanecen en el espacio de trabajo; los `.log` y `output/` se excluyen de Git.

Todos los ensayos utilizaron `EngranajesDelCambio_CleanupValidation`, con datos de usuario separados. No se ejecutaron pruebas contra la partida real ni se publicó una nueva revisión en GitHub.
