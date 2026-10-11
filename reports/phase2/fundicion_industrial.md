# Fundición industrial: exterior e interior jugables

Implementación del 9 de octubre de 2026, a partir de la propuesta industrial aprobada. La planta ficticia conserva su fachada, hornos, grúa, martillo de vapor, rodillos y transmisiones. Incluye exploración y el [taller de Cort de seis fases](taller_de_cort.md).

## Recorrido

- Desde la parada de Londres, William ofrece **La forja y fundición** como tercer destino habilitado. El pasaje conserva el precio de 10 monedas, el regreso incluido y la secuencia de 40 segundos. El viaje muestra el exterior de la fundición al llegar y lo utiliza como origen al regresar.
- Desde el patio de Ensamble del motor se camina hacia el extremo izquierdo para llegar al patio de la fundición. Desde la mina se accede al patio industrial por su camino habitual y se continúa hacia la izquierda. Estos desplazamientos a pie son gratuitos. El extremo derecho del patio de la fundición devuelve al distrito.
- E frente a la puerta, o clic/toque sobre ella, conduce al interior. El pasillo queda transitable; los hornos y materiales quedan detrás de la zona de paso. E en la puerta interior o caminar por el extremo izquierdo devuelve al patio.
- El interior contiene al protagonista y Cort. Ambos tienen la misma altura visible, adaptada a la escala del taller. Cort utiliza el aviso **E Hablar con Cort, maestro de fundición** y el panel de diálogo compartido de la Fase 1. Las imágenes de fondo no contienen personajes pintados.
- Solo aparecen la barra habitual de monedas/inventario y los avisos de proximidad. No hay carteles de navegación ni objetivos superpuestos al mundo.

La conversación ofrece comenzar el taller o volver a explorar. La planta aporta el hierro, el combustible y su fuerza motriz; el carbón del jugador se reserva para la caldera de Murdoch. Visitarla no consume recursos. Solo superar las seis fases entrega la biela y completa la forja.

Continuar restaura patio o interior, posición, diálogo y destino/instante del coche. Reiniciar Fase 2 limpia sus descubrimientos junto al resto de la fase y recupera las monedas originales de entrada; no altera la Fase 1 completada. No cambia la versión global de la partida: los nuevos identificadores amplían las zonas admitidas y los guardados anteriores conservan su destino industrial predeterminado.

## Recursos

Generados con **image_gen integrado**; los fondos se editaron a partir de la propuesta aprobada para retirar las figuras. Se conserva el arte anterior como referencia, sin reemplazarlo.

- [Exterior de producción](../../assets/phase2/forge_yard_pixel_v1.png).
- [Interior de producción](../../assets/phase2/forge_hall_pixel_v1.png).
- [Cort con transparencia](../../assets/phase2/cort_foundry_pixel_v1.png).
- [Prompts exactos, referencias y modo](../../assets/phase2/forge_industrial_prompts_v1.json).
- [Propuesta industrial original](propuesta_forja/propuesta_industrial_v2.md).

`scripts/world/foundry_art.gd` comparte los fondos y posiciones entre la exploración y el coche. Las zonas `forge_yard` y `forge_hall` se integran en `london_arrival.gd`; `london_journey.gd` añade destinos y objetivos del cuaderno. En una partida nueva, Murdoch solicita la biela antes del montaje de engranajes. Los montajes antiguos que ya tienen engranajes o tuberías conservan su avance.

## Validación

Usar exclusivamente el proyecto aislado; ejecutar cada escritor seguido de su lector, sin intercalar procesos que modifiquen sus partidas.

```powershell
$godotExe = 'F:/Descargas/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
./tests/prepare_validation.ps1 -GodotExecutable $godotExe
& $godotExe --path tmp/cart_validation_project res://tests/foundry_scene_test.tscn -- --capture-ui
& $godotExe --headless --path tmp/cart_validation_project res://tests/foundry_scene_test.tscn -- --read-foundry
& $godotExe --headless --path tmp/cart_validation_project res://tests/london_coach_test.tscn
& $godotExe --headless --path tmp/cart_validation_project res://tests/london_coach_test.tscn -- --read-coach
```

Pasaron **34 comprobaciones de exploración y 9 de continuación entre procesos**, incluyendo la entrada al nuevo taller. Cubren selección/cancelación, cobro único, fondo correcto, desembarque libre, navegación real por teclado y clic, escala/transparencia de Cort, diálogo, conservación de costales y engranajes, continuación de diálogo y viaje, retorno incluido, desplazamientos gratuitos y reinicio. La prueba específica respalda/restaura los archivos del usuario aislado; `-- --restore-foundry` recupera el respaldo si se interrumpe antes del lector. La validación del puzzle y del recorrido completo se documenta en [taller de Cort](taller_de_cort.md).

Capturas nativas revisadas: [exterior](../../output/ui/foundry/01_exterior.png), [interior](../../output/ui/foundry/02_interior.png), [proximidad](../../output/ui/foundry/03_proximidad_cort.png) y [diálogo](../../output/ui/foundry/04_dialogo_cort.png).
