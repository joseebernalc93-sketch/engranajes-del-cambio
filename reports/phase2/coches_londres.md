# Del ferrocarril al distrito industrial

Implementación del 8 de octubre de 2026.

Desde la plaza exterior de la estación se camina hacia abajo para llegar a una nueva parada de coches. William ofrece el viaje al distrito industrial por **10 monedas**, con el regreso incluido. Cancelar o no disponer de dinero conserva el saldo. Cada nueva salida al distrito cuesta 10; continuar una salida ya pagada no vuelve a cobrar. Los talleres de la Fase 2 siguen reservados, sin abrir los cuatro desafíos antiguos.

## Economía y partidas existentes

| Acción | Importe | Saldo desde una partida nueva |
| --- | ---: | ---: |
| Venta de harina a Tomás | +100 | 100 |
| Diligencia del pueblo al tren | −3 | 97 |
| Boleto a Londres | −10 | 87 |
| Coche al distrito industrial | −10 | 77 |

La versión 18 del guardado añade la diferencia de **87 monedas** a quienes ya vendieron la harina con la economía anterior. Conserva gastos, coordenadas, objetos, trabajos y duración de la Fase 1; actualiza el importe de la venta en el resumen. La compensación no se repite al cargar. Quien aún no vendió no recibe dinero anticipado. El boleto desaparece del inventario al completar la partida del tren y se retira de las partidas anteriores que ya completaron la fase. La bandera de compra se mantiene como registro del viaje y para visitar la Fase 1 completada. El glosario conserva la ficha histórica del boleto.

## Recorrido y animación

`london_arrival.gd` conecta cinco mapas dentro de la misma escena: andenes, boletería, plaza, parada de coches y distrito industrial. Las salidas se activan al caminar hacia el exterior correspondiente; moverse paralelo a un borde no cambia de mapa. La parada regresa a la plaza caminando hacia el acceso superior. En el distrito, William permite volver en coche.

`london_coach_ride.gd` anima **40 segundos**: subida (2,8 s), salida (5,2 s), recorrido panorámico por tiendas, canal y fábricas (24 s), llegada (5,5 s) y bajada (2,5 s). Se reutilizan los componentes ilustrados de la diligencia y las cuatro poses del caballo; ruedas y suspensión se animan en Godot. Un botón permite omitir el trayecto después de subir. Escape abre el cuaderno; inventario y pérdida de foco pausan la secuencia. Menú principal y Continuar conservan tiempo exacto, dirección, fase de ruedas/caballo, saldo y pago, incluso entre procesos. Tras bajar se recupera el control del protagonista.

La contabilidad urbana persiste en `GameState.phase_two.city_transport`; la secuencia activa se serializa en `checkpoint.city_ride`. La compra prepara viaje y descuento antes de escribir un único checkpoint; el botón duplicado y los callbacks repetidos no duplican el cobro. Reiniciar la llegada a Londres conserva el saldo y los registros de transporte, como los demás avances de la fase.

## Arte

Fondos creados mediante **image_gen integrado**, con la plaza existente como referencia de estilo:

- `assets/phase2/london_coach_depot_v1.png`: parada de coches, taquilla, establos y cobertizo.
- `assets/phase2/london_coach_panorama_v1.png`: panorámica continua de Londres hacia el canal y las fábricas.
- `assets/phase2/london_industrial_depot_v1.png`: parada del distrito, fundición y naves industriales.

Prompts íntegros: `assets/phase2/london_coach_art_prompts_v1.json`. Se reutilizan `passenger_coach_components_v1.png`, `elena_draft_horse_walk_v4.png`, `ramon_coachman_v1.png` y el protagonista. La exploración mantiene el HUD, diálogos y aviso de proximidad de la Fase 1; objetivos y tarifa también se consultan en el cuaderno.

## Verificación

```powershell
$godotExe = 'F:/Descargas/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
./tests/prepare_validation.ps1 -GodotExecutable $godotExe
& $godotExe --headless --path tmp/cart_validation_project res://tests/london_coach_test.tscn
& $godotExe --headless --path tmp/cart_validation_project res://tests/london_coach_test.tscn -- --read-coach
```

Ejecutar los dos procesos en orden. Pasaron **79 comprobaciones de escritura** en ambas dificultades y **13 de lectura**, sin fallos. El primero comprueba economía completa, caminata entre mapas, oferta/cancelación/saldo insuficiente, pago único, etapas animadas, caballo/ruedas, pausas, guardado, continuación, desembarque automático y regreso. El segundo comprueba continuación entre procesos y migración desde la versión 17, incluida compensación única, otros saldos y harina sin vender. Las pruebas usan exclusivamente el proyecto aislado y respaldan/restauran sus archivos de usuario.

También pasaron el recorrido completo de la Fase 1, el menú con sus cuatro puzzles y migraciones anteriores, la diligencia rural y su partida real del tren, las pruebas de llegada a Londres (142 + 15), navegación entre capítulos (80 + 14) y resumen/cuaderno con continuación entre procesos. Las capturas nativas confirman los dos patios y el trayecto panorámico.

Para capturas nativas: omitir `--headless` y añadir `-- --capture-ui` a la primera ejecución. Imágenes en `output/ui/london_coach/`; registros en `output/london_coach_*.log`.
