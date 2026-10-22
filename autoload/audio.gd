extends Node
## Music, ambience and sound effects by asset id. If an id has no audio file
## yet, music stays silent and sound effects use a small synthesised stand-in
## so the game is still readable by ear.

const VOICES := 12
const MIX_RATE := 22050

var sfx_volume_db := -3.0
var music_volume_db := -7.0
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _music_id: StringName
var _last_played := {}
var _synth_cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_ambience = AudioStreamPlayer.new()
	add_child(_ambience)


func play_sfx(id: StringName, _world_pos := Vector2.ZERO) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(id, -1000)) < 40:
		return
	_last_played[id] = now
	var stream := Assets.get_stream(id)
	if stream == null:
		stream = _synth(id)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.volume_db = sfx_volume_db + float(Assets.get_entry(id).get("volume_db", 0.0))
	p.pitch_scale = randf_range(0.97, 1.03)
	p.play()


func play_music(id: StringName) -> void:
	if id == _music_id:
		return
	_music_id = id
	_music.stop()
	var stream := Assets.get_stream(id)
	if stream:
		_music.stream = _looped(stream, id)
		_music.volume_db = music_volume_db + float(Assets.get_entry(id).get("volume_db", 0.0))
		_music.play()


func play_ambience(id: StringName) -> void:
	_ambience.stop()
	var stream := Assets.get_stream(id)
	if stream:
		_ambience.stream = _looped(stream, id)
		_ambience.volume_db = music_volume_db + float(Assets.get_entry(id).get("volume_db", 0.0))
		_ambience.play()


## Applies the manifest's loop settings. "loop_start"/"loop_end" are seconds,
## so an intro plays once and the main section repeats seamlessly.
func _looped(stream: AudioStream, id: StringName) -> AudioStream:
	var e := Assets.get_entry(id)
	var wav := stream as AudioStreamWAV
	if wav == null or not e.get("loop", false):
		if wav:
			wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
		return stream
	var rate := float(wav.mix_rate)
	var end_s: float = e.get("loop_end", 0.0)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = int(float(e.get("loop_start", 0.0)) * rate)
	wav.loop_end = int(end_s * rate) if end_s > 0.0 else int(wav.get_length() * rate)
	return wav


func stop_all() -> void:
	_music_id = &""
	_music.stop()
	_ambience.stop()


# --- Placeholder sound synthesis -------------------------------------------

func _synth(id: StringName) -> AudioStream:
	if _synth_cache.has(id):
		return _synth_cache[id]
	var key := String(id)
	var s: AudioStreamWAV = null
	if "explosion" in key:
		s = _tone(0.45, 90.0, 40.0, 1.0, 0.6)
	elif "laser" in key:
		s = _tone(0.16, 1400.0, 300.0, 0.0, 0.25)
	elif "enemy_shot" in key:
		s = _tone(0.09, 500.0, 220.0, 0.5, 0.2)
	elif "shot" in key:
		s = _tone(0.07, 900.0, 300.0, 0.6, 0.22)
	elif "hurt" in key:
		s = _tone(0.25, 300.0, 80.0, 0.3, 0.4)
	elif "hit" in key:
		s = _tone(0.05, 200.0, 120.0, 0.8, 0.2)
	elif "ping" in key:
		s = _tone(0.08, 2200.0, 1800.0, 0.0, 0.15)
	elif "pickup" in key or "checkpoint" in key:
		s = _tone(0.22, 600.0, 1400.0, 0.0, 0.25)
	elif "jump" in key:
		s = _tone(0.1, 250.0, 500.0, 0.0, 0.15)
	elif "warning" in key:
		s = _tone(0.6, 440.0, 440.0, 0.0, 0.3, 6.0)
	_synth_cache[id] = s
	return s


func _tone(duration: float, f0: float, f1: float, noise: float, vol: float, tremolo := 0.0) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += lerpf(f0, f1, t) / MIX_RATE
		var sq := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		var v := lerpf(sq, randf_range(-1.0, 1.0), noise) * (1.0 - t) * vol
		if tremolo > 0.0:
			v *= 0.5 + 0.5 * signf(sin(t * duration * TAU * tremolo))
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav
