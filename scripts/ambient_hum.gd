class_name AmbientHum
extends AudioStreamPlayer
## Looping fluorescent-bed hum generated at runtime (no audio files).

func _ready() -> void:
	stream = _make_loop()
	volume_db = -14.0
	autoplay = true
	bus = "Master"
	play()


func _make_loop() -> AudioStreamWAV:
	var sample_rate := 22050
	var seconds := 4.0
	var n := int(sample_rate * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	var last := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xB00
	for i in n:
		var t := float(i) / float(sample_rate)
		var white := rng.randf_range(-1.0, 1.0)
		last = (last + 0.02 * white) / 1.02
		var drone := sin(TAU * 55.0 * t) * 0.22 + sin(TAU * 55.4 * t) * 0.18
		var buzz := sin(TAU * 120.0 * t) * 0.07 + sin(TAU * 240.0 * t) * 0.03
		var hiss := white * 0.015
		var s := last * 1.6 + drone + buzz + hiss
		var v := clampi(int(s * 7000.0), -32767, 32767)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	wav.data = data
	return wav
