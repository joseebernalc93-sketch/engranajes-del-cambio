# Dificultad de la fragua de Mateo

Actualizado el 2026-10-05. Mantiene las seis etapas y las animaciones del taller.

## Selección al comenzar

La portada incorpora «Dificultad». El emergente permite elegir Fácil o Difícil, presenta una descripción narrativa de cada perfil y se cierra con «Listo» o Esc. Utiliza los marcos de nogal y latón de la historia. La elección se guarda inmediatamente, y el botón Comenzar conserva su acceso al relato introductorio.

El modo inicial de las partidas antiguas es Difícil, para mantener el comportamiento anterior.

## Perfiles

| Ajuste | Fácil | Difícil |
| --- | --- | --- |
| Oportunidades por ronda | 15 | 10 |
| Indicador de remaches | Velocidad × 0.25 | Original |
| Movimiento del objetivo de enfriamiento | Velocidad × 0.25 | Original |
| Calor por acción del fuelle | 7.5 | 15 |
| Cambio de temperatura y ajuste de eje con teclado | Velocidad × 0.5 | Original |
| Aceleración y frenado de la barra de carga | Velocidad × 0.25 | Original |
| Tiempo para corregir calor o enfriamiento | 4 segundos | 2 segundos |
| Tiempo para corregir un exceso de velocidad | 5.2 segundos | 1.3 segundos |

Las zonas válidas, los tres golpes por remache, los dos segundos de calor estable y las tres cargas comprobadas conservan sus objetivos. No se modifican otros puzzles.

## Golpes sin penalizaciones de posición

En remaches, tocar otro refuerzo o intentar un golpe sin alinear la rueda o sin calor adecuado ofrece una orientación. No se pierde una oportunidad ni se acredita un remache. Un golpe bien dirigido pero fuera de la franja verde consume una oportunidad. Si el hierro pierde su temperatura durante el movimiento del martillo, se cancela ese impacto y se libera el control sin penalizar la precisión.

Los peligros continuos del calor, enfriamiento y carga mantienen sus reglas de advertencia y recuperación, con los tiempos del perfil elegido.

## Guardado y continuidad

La versión 11 guarda `difficulty` y `forge_attempts_spent`. Cambiar de modo conserva la fase y el trabajo correcto. El nuevo saldo se calcula a partir de los errores gastados: tras un fallo, pasar de Difícil a Fácil deja 14 oportunidades; volver a Difícil deja 9. Cambiar repetidamente no repone oportunidades consumidas. Reiniciar la fase conserva la dificultad elegida y crea un saldo nuevo.

Al agotar el saldo, el taller se cierra y Mateo anima al jugador. Una nueva ronda autorizada desde su diálogo comienza con 15 o 10 oportunidades según la selección. La rueda se entrega una sola vez y se instala en el molino existente.

## Validación

- Importación y compilación de Godot sin errores.
- `tests/wheelwright_forge_test.tscn`: recorridos completos de las seis etapas en Fácil y Difícil; recuperación por fase y avance parcial; 15/10 oportunidades; ventana de precisión más lenta; toques sin penalización; fallo de precisión; guardado, agotamiento y nueva ronda; entrega única.
- Migración de guardados de las versiones 8, 9 y 10, incluyendo oportunidades agotadas y avance conservado; cargar dos veces no concede oportunidades adicionales.
- Revisión nativa a 1152 × 648 del botón de portada, los dos perfiles del selector, el contador 15/15 y la orientación tras tocar otro refuerzo.
- Capturas: `output/ui/difficulty`.
