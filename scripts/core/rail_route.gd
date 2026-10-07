extends RefCounted
## Shared topology and save defaults for the railway puzzle.
const COUNT := 8
const SWITCHES := [0, 5]
const CENTERS := [Vector2(170, 105), Vector2(370, 105), Vector2(370, 255), Vector2(570, 255), Vector2(570, 395), Vector2(760, 395), Vector2(760, 245), Vector2(915, 245)]
const TARGETS := [0, 0, 2, 0, 2, 1, 3, 1]
const INITIAL := [1, 1, 0, 3, 0, 0, 1, 3]
const NAMES := ["Cambiavías A", "Curva de entrada", "Enlace central", "Curva de carga", "Retorno inferior", "Cambiavías B", "Enlace de salida", "Curva final"]
const BRANCH_NAMES := ["Recta", "Norte", "Sur"]
