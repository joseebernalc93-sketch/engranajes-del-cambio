# Cordelería de Silas: seis fases

Actualizado el 2026-10-05. Conserva los recursos originales del taller y sus animaciones de rueda, manivela, carro, cabos, ligadura y saco.

1. Seleccionar tres manojos útiles entre seis materiales.
2. Peinar cada manojo dos veces con un rastrillo: Espacio en verde, botón o arrastre directo de la herramienta.
3. Igualar el grosor de los tres cabos con un deslizador y montarlos en los ganchos.
4. Mantener la tensión entre 45 y 70 mientras gira la rueda y se corrige la posición del carro.
5. Elegir el remate apropiado y ajustar tres vueltas de ligadura con precisión.
6. Levantar el saco y regular un freno mientras se verifican tres cargas progresivas.

## Dificultad compartida con el menú

| Ajuste | Fácil | Difícil |
| --- | --- | --- |
| Oportunidades compartidas entre fases | 15 | 10 |
| Ritmo de rastrillo y ligadura | × 0.25 | × 1.0, el indicador de la fragua |
| Franja de precisión | 30–75% | 38–62% |
| Grosor aceptable alrededor de 60 | ±10 | ±4 |
| Cambios de tensión y freno con teclado | × 0.5 | × 1.0 |
| Oscilación de carga y rueda | × 0.25 | × 1.0 |
| Tiempo para corregir tensión o carga | 4 segundos | 1 segundo |

Los errores se descuentan de un saldo único de la cordelería. Se conservan las pasadas, cabos, torsión, vueltas y cargas correctas; el fallo de carga solo vuelve a apoyar el saco y descarta el progreso de la comprobación actual. Cerrar o recargar la partida conserva la fase. Cambiar de perfil usa el mismo número de errores gastados y no repone intentos. Al agotar el saldo, el puzzle cierra, devuelve los controles al jugador y Silas anima a intentar una nueva ronda. Una ronda nueva empieza desde la preparación con el saldo del perfil elegido.

Cada fallo con saldo disponible abre «Silas: revisemos el trabajo», usando el recuadro compartido `scripts/ui/workshop_retry_notice.gd`. Muestra la causa, el saldo y **Continuar esta fase**. Bloquea el taller, suelta los controles mantenidos y pausa indicadores, rueda y carro hasta confirmar con clic, Enter o Espacio. No descuenta otra oportunidad mientras se lee; tampoco se inicia una acción al pulsar Espacio para continuar. Esc conserva la fase al cerrar. La última oportunidad mantiene el cierre y diálogo de ánimo.

## Implementación

- `scripts/ui/rope_craft_display.gd`: herramientas y franja interactiva dibujadas en Godot, reutilizando el taller existente.
- `scripts/ui/rope_puzzle_popup.gd`: las seis fases, acciones, teclado, oportunidades, avance persistente y transiciones de cada sesión.
- `scripts/core/game_state.gd`: saldo independiente, guardado, diálogo de Silas y nueva ronda.
- No se generan ni sustituyen imágenes; los demás puzzles conservan sus mecánicas.

## Validación

`tests/rope_puzzle_test.tscn` completa las seis fases con errores en ambas dificultades. Comprueba arrastre y teclado, mayor ventana para acertar en Fácil, fases conservadas al cerrar y cargar, errores sin borrar trabajos correctos, agotamiento 15/10 y nueva ronda, transiciones canceladas, entrega única y uso de la cuerda en el molino. Las pruebas usan el proyecto de validación y restauran sus archivos de guardado y reporte.

Capturas nativas: `output/ui/rope_six_phases`, con las fases de Fácil y Difícil a 1152 × 648.

Importación y recorridos nativos sin errores. También pasan `tests/economy_flow_test.tscn` y el recorrido completo de `tests/wheelwright_forge_test.tscn`, incluyendo ambos perfiles y migración de guardados. El cambio mantiene las reglas de la fragua y la venta de harina.
