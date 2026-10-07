extends RefCounted
static var mechanism_stream: AudioStreamWAV


static func mechanism(parent: Node) -> void:
	if mechanism_stream == null:
		mechanism_stream = AudioStreamWAV.new()
		mechanism_stream.format = AudioStreamWAV.FORMAT_16_BITS
		mechanism_stream.mix_rate = 22050
		var bytes := PackedByteArray()
		bytes.resize(2646 * 2)
		for index in range(2646):
			var time := float(index) / 22050
			var first := (sin(TAU * 165 * time) + sin(TAU * 730 * time) * 0.4 + sin(TAU * 3107 * time) * 0.2) * exp(-time * 72)
			var second := sin(TAU * 270 * time) * exp(-maxf(0, time - 0.05) * 90) * 0.45 if time >= 0.05 else 0.0
			bytes.encode_s16(index * 2, int(clampf((first + second) * 5500, -32760, 32760)))
		mechanism_stream.data = bytes
	var player := AudioStreamPlayer.new()
	player.stream = mechanism_stream
	player.volume_db = -7
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func tone(parent: Node, bell := true) -> void:
	var player := AudioStreamPlayer.new()
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var duration := 1.15 if bell else 1.35
	var bytes := PackedByteArray()
	bytes.resize(int(22050 * duration) * 2)
	for index in range(bytes.size() / 2):
		var time := float(index) / 22050.0
		var envelope := exp(-time * 4.6) if bell else sin(PI * time / duration) * minf(time * 14.0, 1.0)
		var value := (sin(TAU * 740 * time) + sin(TAU * 1175 * time) * 0.32 + sin(TAU * 1960 * time) * 0.12) if bell else (sin(TAU * 392 * time) + sin(TAU * 466 * time) * 0.4 + sin(TAU * 587 * time) * 0.3)
		bytes.encode_s16(index * 2, int(clampf(value * envelope * 6000, -32760, 32760)))
	sound.data = bytes
	player.stream = sound
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
