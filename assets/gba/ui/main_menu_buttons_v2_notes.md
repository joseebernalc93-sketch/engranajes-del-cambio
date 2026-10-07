# Botones e informativos de la portada

Actualizado el 2026-10-05.

Los botones «Dificultad» y «Comenzar» comparten la misma textura, tipografía, estilos de interacción y dimensiones. Se centran en una columna: Dificultad arriba, Comenzar abajo, con 10 píxeles de separación a 1152 × 648. La selección de dificultad y los puzzles conservan sus reglas.

## Textos aprobados

- Fácil: «Disfruta la historia y resuelve los desafíos con mayor tranquilidad. Ideal para comenzar tu aventura».
- Difícil: «Pon a prueba tu precisión y habilidad para superar los desafíos. Ideal si buscas un reto mayor».

## Recursos

- Fondo sin el botón incrustado: `assets/gba/main_menu_campo_ciudad_clean_v3.png`.
- Marco transparente reutilizado en ambos botones: `assets/gba/ui/main_menu_button_walnut_brass_v1.png`.
- Original conservado: `assets/gba/main_menu_campo_ciudad_v2.png`.
- Capturas nativas de portada, Fácil y Difícil: `output/ui/difficulty_menu_v2`.

## Generación

Modo: herramienta integrada image_gen, dos ediciones sobre el original, con transparencia real para el marco. Las etiquetas se dibujan en Godot para mantener la misma tipografía.

## Validación

Importación de Godot sin errores. Revisión visual nativa de portada y ambos perfiles a 1152 × 648. Ambos botones miden 271.872 × 104.976 píxeles y comparten los estilos y el tamaño de fuente. Comprobados selección de Fácil/Difícil, textos completos, cierre con Listo, devolución del foco y entrada al relato introductorio. La comprobación se ejecutó en el proyecto de validación y restauró sus archivos de guardado.

### menu_clean

Use case: precise-object-edit. Input image 1: edit target, existing game menu artwork. Remove ONLY the single ornate wooden Comenzar button at the bottom center (approximately x640–1030, y740–900 in the 1672x941 image), including its lettering and gold frame. Inpaint that small area with a seamless continuation of the rural stone footpath, grass and flowers behind it. Preserve the entire rest of the image EXACTLY: the title ENG RANAJES DEL CAMBIO actually reads ENGRANAJES DEL CAMBIO and must retain its exact original lettering and gears, original subtitle UNA HISTORIA DE LA REVOLUCIÓN INDUSTRIAL, boy, factories, river, sky, buildings, lighting, composition and detailed pixel illustration. Same 16:9 landscape frame. No buttons, no new objects, no additional text. This is a localized removal, not a redesign.

### menu_button

Use case: background-extraction. Input image 1: extraction target. Extract ONLY the single walnut wood and brass Comenzar button at bottom center as a standalone reusable game UI asset. Preserve precisely its original shape and design: horizontally elongated rounded dark walnut plaque, original double beveled warm gold brass frame, symmetrical corner scrollwork, small centered cog above and below, two round side screws. Remove ONLY the Comenzar lettering, reconstructing clean uninterrupted walnut wood inside. No lettering at all. Actual transparent background with clean alpha, no scene, no fake checkerboard. Front-on flat UI, identical style, colors, proportions and finely pixelated illustration of the original button. Include the complete top and bottom cogs, tightly frame the whole button with minimal transparent padding; landscape canvas about 2.6:1. One single blank button, no text, no extra buttons, no new decoration.


