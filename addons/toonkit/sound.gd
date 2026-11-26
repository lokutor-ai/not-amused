class_name Sound
extends Node
## Every WAV in res://assets/audio, played by name. "music" loops, and gets out of the way when somebody talks.

var music: AudioStreamPlayer
## 0..1: somebody is talking, music down.
var duck := 0.0
var music_volume := -13.0
var _players := {}
var _duck := 0.0


func _ready() -> void:
	for f in DirAccess.get_files_at("res://assets/audio"):
		var clip := f.trim_suffix(".import").trim_suffix(".remap")
		if clip.ends_with(".wav") and not _players.has(clip.get_basename()):
			var p := AudioStreamPlayer.new()
			p.stream = load("res://assets/audio/" + clip)
			p.max_polyphony = 4
			add_child(p)
			_players[clip.get_basename()] = p
	music = _players.get("music")
	if music == null:
		set_process(false)
		return
	var s := music.stream as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = int(s.get_length() * s.mix_rate)
	music.volume_db = music_volume


func play(clip: String, db := 0.0, pitch := 1.0) -> void:
	if not _players.has(clip):
		push_warning("no sound called " + clip)
		return
	var p: AudioStreamPlayer = _players[clip]
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


func stop(clip: String) -> void:
	_players[clip].stop()


func _process(delta: float) -> void:
	_duck = move_toward(_duck, duck, delta * (6.0 if duck > _duck else 1.6))
	music.volume_db = music_volume - 11.0 * _duck
