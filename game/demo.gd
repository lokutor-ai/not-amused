extends Node
## Plays the game by itself: the lines of the script are the jester's, spoken by a LokutorVoice, and the king hears them
## through the same microphone path as a player's. Used to record videos and to test the whole game without hands.

var game: Node
var script_path := ""
var voice: LokutorVoice
var _turns: Array = []
var _turn := 0
var _busy := false
var _level := 0.0
var _data := {}


func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(script_path if FileAccess.file_exists(script_path) else "res://" + script_path))
	_turns = _data.turns
	voice = game._voice(_data.get("jester", "F2"), game.stage.jester)
	voice.player.voice_played.connect(_hear)
	var lines := PackedStringArray()
	for t in _turns:
		lines.append(t.heard)
	await voice.preload_lines(lines)
	await get_tree().create_timer(float(_data.get("title_seconds", 2.6))).timeout
	game.begin()


## A line with "cut" is said over the king, after so many seconds of him.
func _my_turn() -> bool:
	if _turns[_turn].has("cut"):
		return game.agent.state == LokutorAgent.State.SPEAKING and game.agent.heard_seconds() >= float(_turns[_turn].cut)
	return game.agent.state == LokutorAgent.State.READY


func talking() -> bool:
	return voice.speaking


func level() -> float:
	return _level if voice.speaking else 0.0


## What the jester says goes into the king's ear.
func _hear(samples: PackedFloat32Array, rate: int) -> void:
	_level = LokutorAudio.calculate_rms(samples)
	game.agent.feed_microphone(samples, rate)


func _process(delta: float) -> void:
	if voice != null and not voice.speaking and game.agent.client != null:
		var hush := PackedFloat32Array()
		hush.resize(int(Lokutor.INPUT_RATE * delta))
		game.agent.feed_microphone(hush, Lokutor.INPUT_RATE)
	if _busy or game.phase != 2 or _turn >= _turns.size() or not _my_turn() or game._guard_talking != "":
		if game.phase == 5 and not _busy:
			_busy = true
			await get_tree().create_timer(float(_data.get("end_seconds", 4.0))).timeout
			if game.recorder:
				await game.recorder.stop()
			get_tree().quit()
		return
	_busy = true
	var t: Dictionary = _turns[_turn]
	if not t.has("cut"):
		await get_tree().create_timer(float(t.get("pause", 0.7))).timeout
	if t.has("hint"):
		await game.guard_hint(t.hint.side, t.hint.text)
		await get_tree().create_timer(0.35).timeout
	if t.get("shot", "") != "":
		game.stage.rig.go(t.shot, 0.0)
	game.stage.jester.mood(t.get("mood", "happy"))
	game.hud.bubble("jester", t.heard, game._beside(game.stage.jester), 1.0, true)
	await voice.say(t.heard)
	_turn += 1
	# Wait for the king to take his turn.
	var waited := 0.0
	while game.agent.state in [LokutorAgent.State.READY, LokutorAgent.State.PLAYER_TALKING] and waited < 8.0 and game.phase == 2:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_busy = false
