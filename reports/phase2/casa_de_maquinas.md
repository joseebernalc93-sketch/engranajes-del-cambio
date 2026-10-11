# Ensamble del motor · Casa de máquinas

Implementación de la propuesta aprobada el 10 de octubre de 2026. Tres espacios explorables separados, con el estilo industrial de Londres y personajes independientes del fondo.

## Recorrido

**Parada de William → patio exterior → nave de ensamble con Murdoch → sala de montaje del motor.**

- William conserva el destino **Ensamble del motor**, el viaje de 10 monedas y el regreso incluido. El coche desembarca en el patio nuevo; no se dibuja otro coche dentro del fondo.
- La puerta central del patio abre la nave. Sus caminos laterales conectan gratis con la fundición y el pozo minero.
- Murdoch está en la nave, con transparencia y la misma altura visible que el protagonista. Al acercarse aparece **E Hablar con Murdoch, ingeniero**. El diálogo compartido explica cómo llegar al motor y para qué sirven la biela y los costales.
- El arco iluminado del fondo abre la sala de montaje. Acercarse al banco muestra **E Trabajar en el motor**. Entrar o hablar con Murdoch no instala piezas automáticamente.
- El banco conserva la confirmación de instalación de la biela y el puzzle existente de engranajes, agua, combustible y presión. Su lógica y sus avances se mantienen. La puerta derecha conserva la conexión con la nave textil tras completar el ensayo.
- Las puertas permiten volver. Admiten clic/toque y E al acercarse; también se puede cruzar caminando en las zonas de salida. Las mesas, cajas y rejas delimitan la circulación.

## Persistencia

Se conserva el identificador `industrial` para el patio y `engine_room` para la sala del motor; se añade `engine_hall` para la nave. Esto mantiene los destinos de William y los caminos existentes. Las posiciones antiguas que caen dentro de las nuevas mesas o rejas se trasladan a suelo libre. Se conservan monedas, mochila, conversación, inventario abierto, engranajes parciales y biela instalada. Reiniciar la fase recupera el inventario y saldo de entrada desde la Fase 1, normalmente 87 monedas.

## Arte generado

Modo: **imagegen integrado (`image_gen`)**. Referencia: [propuesta aprobada](casa_de_maquinas/propuesta_aprobada_v1.png). Los cuatro prompts exactos están en [engine_house_prompts_v1.json](../../assets/phase2/engine_house_prompts_v1.json).

| Recurso guardado | Uso |
| --- | --- |
| [engine_house_yard_v1.png](../../assets/phase2/engine_house_yard_v1.png) | Patio exterior sin personas ni coche incorporados |
| [engine_house_hall_v1.png](../../assets/phase2/engine_house_hall_v1.png) | Nave de bienvenida, bancos y arco a la sala |
| [engine_house_assembly_v1.png](../../assets/phase2/engine_house_assembly_v1.png) | Sala de montaje, motor estacionario, caldera y banco |
| [murdoch_engineer_pixel_v1.png](../../assets/phase2/murdoch_engineer_pixel_v1.png) | Ingeniero independiente con fondo transparente |

Los originales se conservaron sin recortar ni alterar. El juego adapta el fondo a 1152 × 648 y calcula la escala del personaje a partir de sus píxeles opacos.

## Capturas del juego

- [Patio exterior](../../output/ui/engine_house/01_patio.png)
- [Nave interior](../../output/ui/engine_house/02_nave.png)
- [Murdoch y aviso de proximidad](../../output/ui/engine_house/03_murdoch.png)
- [Conversación](../../output/ui/engine_house/04_dialogo.png)
- [Sala de montaje](../../output/ui/engine_house/05_sala_montaje.png)
- [Interacción con el motor](../../output/ui/engine_house/06_proximidad_motor.png)

## Validación

Godot 4.7.2, proyecto aislado `tmp/cart_validation_project`, sin utilizar los archivos de guardado del jugador. Capturas nativas con OpenGL Compatibility, revisadas visualmente. Cada proceso escritor terminó antes de ejecutar su lector.

| Suite | Escritor | Lector | Fallos |
| --- | ---: | ---: | ---: |
| Casa de máquinas | 37 | 11 | 0 |
| Coches de Londres, ambas dificultades | 115 | 13 | 0 |
| Taller de Cort, ambas dificultades | 108 | 17 | 0 |
| Recorrido carbón–biela–motor–telares, ambas dificultades | 110 | 7 | 0 |
| Exploración de fundición y caminos | 34 | 9 | 0 |
| **Total** | **404** | **57** | **0** |

**461 comprobaciones**, sin errores de script ni salida de error. Se probaron el desembarque, las puertas recorridas realmente, la altura y transparencia de Murdoch, el aviso E, el diálogo, Continue en la nave, persistencia entre procesos, cancelación e instalación de biela, mochila, posición antigua, retorno textil, carreteras, regreso incluido y reinicio de fase. El recorrido completo también verifica la extracción, las seis tareas de Cort y los 120 segundos de presión.

Para repetir la suite específica:

```powershell
./tests/prepare_validation.ps1 -GodotExecutable godot
godot --path tmp/cart_validation_project --rendering-method gl_compatibility res://tests/engine_house_test.tscn -- --capture-ui
# Esperar a que el escritor termine antes del lector:
godot --headless --path tmp/cart_validation_project res://tests/engine_house_test.tscn -- --read-engine-house
```

El lector restaura los archivos de validación respaldados. Los registros de esta ejecución están en `tmp/engine_house_*`, `tmp/engine_coach_*`, `tmp/engine_foundry_*` y `tmp/engine_chain_*`.
