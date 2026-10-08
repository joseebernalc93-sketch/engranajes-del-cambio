extends Node
## Snapshot on the main thread; atomic file I/O on a single worker task.
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const PATH := "user://registro_fase_2.json"
var task_id: int = -1
var elapsed: float = 0.0
var last_write_error: Error = OK

func _process(delta: float) -> void:
	if GameState.phase_two.is_empty() or not bool(GameState.phase_two.get("active", false)): return
	elapsed += delta
	if elapsed >= 5.0:
		elapsed = 0.0
		request_write()

func report() -> Dictionary:
	Campaign.ensure()
	var metrics: Dictionary = GameState.phase_two.metrics
	var samples := int(metrics.pressure_samples)
	var duration := maxf(0.0001, float(metrics.get("pressure_duration", samples)))
	var accuracy: Variant = snappedf(100.0 * (1.0 - minf(1.0, float(metrics.pressure_error) / duration)), 0.01) if samples > 0 else null
	return {
		"version": 1,
		"fase": "El corazón de hierro",
		"dificultad": GameState.difficulty,
		"completada": GameState.phase_two.completed.size() == 4,
		"talleres_completados": GameState.phase_two.completed.duplicate(),
		"oportunidades": Campaign.remaining(),
		"oportunidades_totales": Campaign.total(),
		"rondas": int(GameState.phase_two.round),
		"tiempos": {
			"activo_segundos": snappedf(float(metrics.active_seconds), 0.01),
			"por_taller": metrics.workshop_seconds.duplicate(true),
		},
		"precision_presion_porcentaje": accuracy,
		"muestras_presion": samples,
		"paradas_emergencia": int(metrics.emergency_stops),
		"balance_productivo": {"fardos": int(metrics.bales), "meta": 10, "carbon_paleadas": int(metrics.coal_used)},
		"errores": metrics.errors.duplicate(true),
		"eventos": metrics.events.duplicate(true),
		"glosario": GameState.phase_two.glossary.duplicate(true),
	}

func request_write() -> void:
	if task_id >= 0:
		if not WorkerThreadPool.is_task_completed(task_id): return
		WorkerThreadPool.wait_for_task_completion(task_id)
	var payload := JSON.stringify(report(), "  ")
	task_id = WorkerThreadPool.add_task(_write.bind(payload), false, "Phase 2 teacher report")

func flush() -> void:
	if task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(task_id)
		task_id = -1
	request_write()
	WorkerThreadPool.wait_for_task_completion(task_id)
	task_id = -1

func _write(payload: String) -> void:
	var file := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		last_write_error = FileAccess.get_open_error()
		return
	file.store_string(payload)
	file.flush()
	file.close()
	last_write_error = DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH + ".tmp"), ProjectSettings.globalize_path(PATH))

func _exit_tree() -> void:
	# The last report includes work performed since the periodic snapshot.
	# Test harnesses disable processing before restoring their backed-up files.
	if is_processing() and not GameState.phase_two.is_empty() and bool(GameState.phase_two.get("active", false)):
		flush()
	if task_id >= 0: WorkerThreadPool.wait_for_task_completion(task_id)
