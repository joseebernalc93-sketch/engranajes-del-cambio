extends RefCounted
## Player-facing tasks. Every mouse tool has an equivalent focused button/key action.
static func titles(id: String) -> Array:
	return {"mine": ["Calibrar la lámpara Davy", "Reconocer las vetas", "Picar con cadencia", "Cribar y separar", "Ventilar la galería", "Elevar la vagoneta"], "forge": ["Dosificar el horno", "Batir el arrabio", "Retirar la escoria", "Trasladar la lupa", "Forjar las cuatro caras", "Enfriar y calibrar"], "engine": ["Ajustar pistón y culata", "Sellar el condensador", "Sincronizar las válvulas", "Montar el movimiento paralelo", "Armar el regulador", "Purgar y probar a 15 PSI"], "textile": ["Tender cuatro correas", "Regular las poleas", "Acoplar los embragues", "Turno de producción · 2 minutos"]}.get(id, [])

static func instructions(id: String, stage: int) -> String:
	return str({"mine": ["Centra el cierre de la malla y acciona tres veces el fuelle. Confirma cuando la llama vuelva a ser cálida.", "Explora la roca con la lámpara. Marca las tres vetas negras brillantes; descarta la pizarra mate.", "Golpea seis veces cuando la aguja pase por la zona verde. Mantén un compás regular.", "Arrastra cada fragmento: piedra clara al cajón izquierdo y hulla negra al derecho.", "Arrastra las tres compuertas. Mantén el tiro entre 50 y 75 CFM durante 1,2 segundos.", "Gira el cabrestante en sentido horario. Ajusta el freno para que la vagoneta no golpee los maderos."], "forge": ["Tres paladas de arrabio a la solera y dos de coque al hogar separado. Confirma la carga.", "Describe tres vueltas continuas con el rabot. Reaviva el hogar si el hierro pierde temperatura.", "Retira las tres manchas de escoria de la superficie antes de que la lupa se enfríe.", "Toma la lupa con las tenazas y arrástrala al yunque de la derecha mientras siga amarilla.", "Da dos golpes por cara, en orden 1 → 2 → 3 → 4. Pisa el pedal cuando la aguja esté en verde.", "Sumerge poco a poco la biela. Cuando esté fría, centra el compás con el patrón y verifica."], "engine": ["Inserta el émbolo, coloca el empaque y aprieta la culata en cruz: 1 → 3 → 2 → 4.", "Selecciona cada brida, coloca su arandela y conecta el tubo. Completa tres uniones estancas.", "Mueve la excéntrica hasta centrar la alternancia de las dos carreras. Comprueba el ciclo.", "Alinea cada uno de los tres brazos con la guía vertical y fíjalo. Selecciona el siguiente brazo.", "Monta las dos esferas y enlaza la varilla de ajuste con la válvula mariposa.", "Abre la admisión gradualmente y purga el condensado. Mantén 15 PSI en verde durante 1,2 segundos."], "textile": ["Arrastra una correa del árbol superior hasta cada telar. Conecta las cuatro transmisiones.", "Selecciona cada telar y centra su polea tensora. Verifica las cuatro correas antes de continuar.", "Acopla los cuatro embragues de fricción con el árbol motor detenido.", "Inicia el turno. Alimenta la caldera y repón hilo. Si se rompe una urdimbre: frena ese telar, anuda y relanza. Meta: diez fardos al silbato."]}[id][stage])

static func buttons(id: String, stage: int) -> Array:
	return {"mine": [["vent|Accionar fuelle", "confirm|Comprobar lámpara"], ["inspect|Marcar veta"], ["hit|Golpear piqueta"], ["sort_stone|Separar piedra", "sort_coal|Guardar hulla"], [], ["crank|Girar cabrestante"]], "forge": [["ore|Palada de arrabio", "fuel|Coque al hogar", "confirm|Comprobar carga"], ["stir|Recorrer con rabot", "heat|Reavivar hogar"], ["skim|Retirar escoria", "heat|Reavivar hogar"], ["transfer|Tenazas al yunque", "heat|Reavivar hogar"], ["hit|Pisar pedal"], ["cool|Sumergir despacio", "confirm|Verificar compás"]], "engine": [["piston|Insertar émbolo", "packing|Colocar empaque", "bolt|Apretar perno"], ["washer|Colocar arandela", "pipe|Unir tubería"], ["confirm|Comprobar distribución"], ["arm|Fijar articulación"], ["ball|Montar esfera", "link|Enlazar mariposa"], ["purge|Purgar condensado"]], "textile": [["belt|Tender correa"], ["confirm|Verificar tensión"], ["clutch|Acoplar embrague"], ["start|Iniciar / reanudar", "feed|Palear carbón", "vent|Descargar vapor", "refill|Reponer hilo", "stop|Frenar telar", "knot|Anudar fibra", "restart|Relanzar", "emergency|Parada de emergencia"]]}[id][stage]

static func selectors(id: String, stage: int) -> int:
	if id == "mine": return [0, 6, 0, 6, 3, 0][stage]
	if id == "forge": return [0, 0, 3, 0, 4, 0][stage]
	if id == "engine": return [4, 3, 0, 3, 2, 0][stage]
	return 4

static func adjustable(id: String, stage: int) -> bool:
	return (id == "mine" and stage in [0, 4, 5]) or (id == "forge" and stage == 5) or (id == "engine" and stage in [2, 3, 5]) or (id == "textile" and stage == 1)

static func selection_name(id: String, stage: int) -> String:
	if id == "textile": return "Telar"
	if id == "mine": return "Compuerta" if stage == 4 else ("Veta" if stage == 1 else "Fragmento")
	if id == "forge": return "Cara" if stage == 4 else "Escoria"
	return {0: "Perno", 1: "Brida", 3: "Brazo", 4: "Esfera"}.get(stage, "Pieza")
