extends Node3D
## NOT AMUSED. You are the jester. You have a minute and a microphone, and the king has heard them all.
##
## The king is a LokutorAgent: he hears you, answers, and calls `react` to say how funny that was, which moves the meter, his
## face and his body. Nobody interrupts him twice. The guards are LokutorVoices with written lines. All of them move their lips with Lokutor's visemes.
##
##   with a key:      LOKUTOR_API_KEY=... godot --path .
##   a microphone:    mic=tonor (part of its name); M changes it, and it is remembered
##   a language:      lang=es; L changes it on the title screen, and it is remembered
##   headphones:      headphones or speakers; H changes it, and it is remembered. If not, the game finds out: see Leak
##   full screen:     fullscreen; F or F11 changes it, and it is remembered
##   the king:        king=M1; V tries the next voice on the title screen, and it is remembered
##   with no key:     dev=<port>, a development server on this computer that answers from game/script.json
##   a demo:          demo=game/script.json, played by itself; record=<folder> keeps its frames and sound

enum Phase { TITLE, INTRO, PLAY, WON, LOST, END }

const ROUND_SECONDS := 60.0
## What the king calls his reactions, and what they are here. Not one plain word: he wrote "[bored]" as if it were a tag of the
## voice, and a bracket the voice does not know is read aloud.
const REACTIONS := {"stone_face": "bored", "raised_eyebrow": "confused", "trembling_lips": "snort", "escaped_giggle": "giggle",
	"open_laugh": "laugh", "deep_offence": "offended", "unfinished_joke": "waiting"}
## A jester heard over the king this soon after he began was not cutting him off: they had paused in the middle of a joke.
const STILL_TALKING := 1.5
const DEV := "ws://127.0.0.1:%d"             # the dev server; "dev" or "dev=8788" on the command line

var phase := Phase.TITLE
var amusement := 0.0
var left := ROUND_SECONDS
var best_line := ""
var best_score := -1
var stage: Stage
var hud: Hud
var sound: Sound
var agent: LokutorAgent
var king_voice: LokutorVoice              # the king's written lines, with the same mouth
var guard_voices := {}
var ear: LokutorMicrophone                # the microphone on the title screen, to see that it hears you
var demo: Node
var recorder: Recorder
var dev := false
var lang := "en"                          # see Words; the scripts of the demos are English

var _args := {}
var _heard_last := ""
var _reply_text: PackedStringArray = []
var _reply_seconds := 0.0
var _speaking_for := 0.0                  # how long the king has been saying this
var _waits := 0                           # times in a row he has waited for the rest of a joke
var _silence := 0.0
var _hints_given := 0
var _shot_hold := 0.0
var _won := false
var _tick := 0
var _greeted := false
var _guard_talking := ""
var _started_at := 0.0
var _leak := Leak.new()
var _echoed := false                      # the king's voice comes back through the microphone
var _cuts := 0                            # how many times the jester has cut the king off
var _answered := false
var _manners := ""                        # what he thinks of the last one, until he has said it


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		_args[p[0]] = p[1] if p.size() > 1 else "1"
	var page := Lokutor.page_args()                 # in a browser, from the address: lokutor.com/games passes the language
	for k in ["lang", "headphones", "king", "dev"]:
		if page.has(k):
			_args[k] = page[k]
	dev = _args.has("dev")
	_choose_mic(_saved(MIC_FILE) if not _args.has("mic") else str(_args.mic))
	if _args.has("fullscreen") or (not _args.has("demo") and _saved(WINDOW_FILE) == "full"):
		_full_screen(true)
	if _args.has("lang"):
		lang = str(_args.lang) if str(_args.lang) in Words.LANGUAGES else "en"
	elif _can_choose_language():
		lang = _saved(LANGUAGE_FILE) if _saved(LANGUAGE_FILE) in Words.LANGUAGES else Words.of_this_computer()
	stage = Stage.new()
	add_child(stage)
	hud = Hud.new()
	add_child(hud)
	sound = Sound.new()
	add_child(sound)
	_make_voices()
	await _warm_up()
	if _args.has("demo"):
		demo = load("res://game/demo.gd").new()
		demo.script_path = _args.demo
		demo.game = self
		add_child(demo)
	if _args.has("record"):
		recorder = Recorder.new()
		add_child(recorder)
		recorder.start(_args.record)
	_to_title()


## Draws everything once behind a curtain, so that nothing is compiled in the middle of a joke.
func _warm_up() -> void:
	var curtain := ColorRect.new()
	curtain.color = Color("#2b1633")
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(curtain)
	_confetti(true)
	for shot in ["jester", "trap", "party", "lever", "king_close"]:
		stage.rig.go(shot)
		for i in 3:
			await get_tree().process_frame
	create_tween().tween_property(curtain, "modulate:a", 0.0, 0.5).finished.connect(curtain.queue_free)


# ---- The voices ----------------------------------------------------------------------------------------------------------

func _make_voices() -> void:
	agent = LokutorAgent.new()
	agent.name = "King"
	agent.start_on_ready = false
	_king_bus()
	agent.voice_bus = KING_BUS
	agent.spatial_voice = false
	agent.lip_sync = stage.king.lips
	if _base_url() != "":
		agent.url = _base_url() + "/ws/agent"
	if dev:
		agent.api_key = "dev"
	if _args.has("demo"):
		agent.mic_mode = LokutorAgent.MicMode.OFF
	agent.state_changed.connect(_on_state)
	agent.echo_heard.connect(func(_t): _hears_himself())      # the SDK caught his own words coming back
	agent.player_said.connect(_on_player_said)
	agent.player_said_partial.connect(func(t): if phase == Phase.PLAY and not agent.is_speaking: hud.bubble("jester", t, _beside(stage.jester), 1.0, true))
	agent.character_said.connect(func(t): _reply_text.append(_spoken(t)))
	agent.visemes_received.connect(func(list): if not list.is_empty(): _reply_seconds = maxf(_reply_seconds, list[-1].t + list[-1].d))
	agent.error_occurred.connect(_on_error)
	add_child(agent)
	king_voice = _voice("M2", stage.king)
	king_voice.voice_bus = KING_BUS
	guard_voices = {"l": _voice("M4", stage.guard_l), "r": _voice("M3", stage.guard_r)}


func _voice(voice: String, actor: Actor) -> LokutorVoice:
	var v := LokutorVoice.new()
	v.voice = voice
	v.language = lang
	v.spatial_voice = false
	v.lip_sync = actor.lips
	if _base_url() != "":
		v.url = _base_url() + "/ws/tts"
	if dev:
		v.api_key = "dev"
	add_child(v)
	return v


## The dev server, the relay to the real one (devserver/relay.py), or "" for the real one.
func _base_url() -> String:
	if dev:
		return DEV % (int(_args.dev) if int(_args.dev) > 1 else 8787)
	return DEV % int(_args.relay) if _args.has("relay") else ""


func has_key() -> bool:
	return dev or OS.get_environment("LOKUTOR_API_KEY") != "" or agent.ticket_provider.is_valid() or Lokutor.keyless_allowed()


# ---- The evening ---------------------------------------------------------------------------------------------------------

func _to_title() -> void:
	phase = Phase.TITLE
	_won = false
	hud.card(false)
	hud.show_play(false)
	hud.hush()
	stage.jester.visible = false
	stage.jester.position = ThroneRoom.TRAP
	stage.jester.rotation_degrees.y = 180.0
	stage.room.close_trap()
	_calm()
	_listen()
	stage.rig.go("title", 1.6 if stage.rig.shot != "" else 0.0)
	if not sound.music.playing:
		sound.music.play()
	sound.music.pitch_scale = 1.0
	_speak_language()


func _calm() -> void:
	stage.look_around()
	stage.king.idle("bored")
	stage.king.mood("bored")
	for g in stage.guards():
		g.idle("stand")
		g.mood("neutral")
	stage.jester.idle("idle")
	stage.jester.mood("happy")


func begin() -> void:
	if phase != Phase.TITLE or not has_key():
		return
	phase = Phase.INTRO
	if ear != null:
		ear.stop()
		ear.queue_free()
		ear = null
	hud.title(false)
	amusement = 0.0
	left = ROUND_SECONDS
	best_score = -1
	best_line = ""
	_hints_given = 0
	_silence = 0.0
	_tick = 0
	_cuts = 0
	_forget()
	_leak = Leak.new()
	agent.mute_mic_while_speaking = true              # his greeting tells whether the microphone hears him
	hud.meter.value = 0.0
	hud.clock.left = left
	hud.clock.total = ROUND_SECONDS
	_greeted = false
	stage.rig.go("play", 1.5)
	await get_tree().create_timer(0.8).timeout
	# The jester jumps in from the wings.
	var j := stage.jester
	j.visible = true
	j.position = ThroneRoom.TRAP + Vector3(-3.4, 0, 1.2)
	agent.start_conversation()                        # he greets whoever comes in
	if agent.client != null:
		agent.client.transcript_truncated.connect(_on_cut_off)
	var t := create_tween()
	for i in 3:
		var to := ThroneRoom.TRAP + Vector3(-3.4, 0, 1.2) * (1.0 - (i + 1) / 3.0)
		var from := ThroneRoom.TRAP + Vector3(-3.4, 0, 1.2) * (1.0 - i / 3.0)
		t.tween_method(func(u: float): j.position = from.lerp(to, u) + Vector3(0, sin(u * PI) * 0.55, 0), 0.0, 1.0, 0.30)
		t.tween_callback(func():
			j.bump(-3.2)
			sound.play("boing", -14.0, 1.0 + 0.12 * i)
			sound.play("jingle", -12.0))
	await t.finished
	j.play("bow", 0.15)
	sound.play("jingle", -8.0)
	for g in stage.guards():
		g.look.target = j.position + Vector3(0, 1.1, 0)


func _start_round() -> void:
	phase = Phase.PLAY
	_started_at = left
	agent.add_action("react", Prompts.action(lang, "react"), _on_react, {
		"reaction": {"type": "string", "enum": REACTIONS.keys(), "description": Prompts.action(lang, "reaction")},
		"amusement": {"type": "integer", "minimum": 0, "maximum": 10, "description": Prompts.action(lang, "amusement")}})
	agent.add_action("pull_lever", Prompts.action(lang, "lever"), _on_lever)
	agent.set_persona(Prompts.persona(lang))
	_echoed = _leak.found()
	agent.mute_mic_while_speaking = not _can_interrupt()
	hud.show_play(true)
	stage.rig.go("play", 0.9)
	sound.play("drumroll", -16.0)


## The king says how funny that was.
func _on_react(args: Dictionary) -> String:
	if phase != Phase.PLAY:
		return Prompts.action(lang, "over")
	var called := str(args.get("reaction", ""))
	var reaction: String = REACTIONS.get(called, called if called in REACTIONS.values() else "bored")
	var funny := clampi(int(args.get("amusement", 0)), 0, 10)
	_waits = _waits + 1 if reaction == "waiting" else 0
	if reaction == "waiting" and _waits < 3 and _manners == "":
		_perform(reaction, 0)
		return Prompts.action(lang, "waiting")
	var points := int(round((funny - 2.5) * 6.8)) if funny >= 3 else (-4 if reaction == "offended" else 0)
	amusement = clampf(amusement + points, 0.0, 100.0)
	hud.meter.set_value(amusement)
	hud.score(points)
	if funny > best_score and _heard_last != "":
		best_score = funny
		best_line = _heard_last
	_perform(reaction, funny)
	_know("laughter", Prompts.fact(lang, "of").format({"n": int(amusement)}))
	if amusement >= 100.0:
		_won = true
		return Prompts.action(lang, "won")
	var how: String = _manners if _manners != "" else Prompts.action(lang, reaction if reaction != "waiting" else "bored")
	return Prompts.action(lang, "laughter").format({"n": int(amusement), "how": how})


func _on_lever(_args_: Dictionary) -> String:
	if phase == Phase.PLAY and not _won:
		_lose_after_reply("")
		return Prompts.action(lang, "dropped")
	return Prompts.action(lang, "stuck")


## A fact of the moment, for the king's mind.
func _know(key: String, value) -> void:
	agent.set_context(Prompts.fact(lang, key), value)


## A new audience: nothing of the last one, which may have been in another language.
func _forget() -> void:
	_manners = ""
	_waits = 0
	for l in Words.LANGUAGES:
		for key in ["laughter", "audience", "time", "joke", "manners"]:
			agent.set_context(Prompts.fact(l, key), null)


## The server stopped him because the jester was talking. `full`: all that he had to say. A jester who answers on his last
## word has not cut him off.
func _on_cut_off(heard: String, full: String) -> void:
	if phase != Phase.PLAY or _won or heard.length() > full.length() * 0.85:
		return
	if _leak.found():                     # it was himself
		_hears_himself()
		return
	if _speaking_for < STILL_TALKING:
		_know("joke", Prompts.fact(lang, "rest"))
		return
	_cuts += 1
	var said := _spoken(heard).trim_suffix("…").strip_edges()
	_manners = Prompts.fact(lang, "cut_%d" % mini(_cuts, 3)).format({"heard": said if said != "" else "…"})
	_know("manners", _manners)
	amusement = maxf(0.0, amusement - 6.0)
	hud.meter.set_value(amusement)
	hud.score(-6)
	_know("laughter", Prompts.fact(lang, "of").format({"n": int(amusement)}))
	hud.hush("king")
	hud.shout(text("dare!"), Hud.RED, 0.9, 150)
	stage.rig.go("king_close", 0.0)
	_fury()


func _hears_himself() -> void:
	_echoed = true
	agent.mute_mic_while_speaking = not _can_interrupt()


## What the microphone heard is what the king has just said.
func _his_words(text: String) -> bool:
	var his := _words(" ".join(_reply_text))
	var these := _words(text)
	if these.size() < 3:
		return false
	var same := 0
	for w in these:
		if w in his:
			same += 1
	return same >= these.size() * 0.75


func _words(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for m in RegEx.create_from_string("[\\p{L}\\p{N}]+").search_all(text.to_lower()):
		out.append(m.get_string())
	return out


func _fury() -> void:
	var k := stage.king
	k.play("angry", 0.08)
	k.mood("angry", 0.05)
	k.bump(2.2 + 0.6 * mini(_cuts, 3))
	stage.rig.shake(0.04 + 0.02 * mini(_cuts, 3))
	sound.play("gasp", -8.0)
	for g in stage.guards():
		g.play("shock", 0.1)
		g.mood("scared")


## What a reaction looks like: the king, the guards and the camera.
func _perform(reaction: String, funny: int) -> void:
	var k := stage.king
	if _manners != "" and reaction in ["bored", "confused", "offended"]:      # he has not got over it
		_fury()
		return
	match reaction:
		"snort":
			k.play("snort", 0.12)
			k.mood("hold", 0.1)
			k.bump(1.6)
		"giggle":
			k.play("giggle", 0.15)
			k.mood("giggle")
			k.bump(1.2)
		"laugh":
			k.play("giggle" if not _won else "belly_laugh", 0.15)
			k.mood("laugh")
			k.bump(2.0)
		"offended":
			k.play("offended", 0.12)
			k.mood("offended", 0.1)
			k.bump(1.4)
			stage.rig.shake(0.04)
		"confused":
			k.play("confused", 0.2)
			k.mood("confused")
		"waiting":
			k.mood("listen", 0.2)
		_:
			k.mood("bored", 0.3)
	for g in stage.guards():
		if reaction == "offended":
			g.play("shock", 0.1)
			g.mood("scared")
			sound.play("gasp", -10.0)
		elif amusement > 72.0 or funny >= 8:
			g.idle("laugh")
			g.mood("laugh")
		elif amusement > 25.0 or funny >= 5:
			g.idle("hold_it")
			g.mood("hold")
			g.bump(0.8)
		else:
			g.idle("stand")
			g.mood("neutral" if funny < 3 else "amused")


func _win() -> void:
	phase = Phase.WON
	_know("audience", Prompts.fact(lang, "you_laughed"))
	hud.show_play(false)
	var k := stage.king
	k.idle("belly_laugh", 0.15)
	k.mood("laugh")
	for g in stage.guards():
		g.idle("laugh")
		g.mood("laugh")
	stage.jester.idle("win")
	stage.jester.mood("laugh")
	create_tween().tween_property(stage.jester, "rotation_degrees:y", 360.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stage.rig.go("party", 0.0)
	stage.rig.shake(0.05)
	sound.play("fanfare", -5.0)
	_confetti()
	hud.shout(text("pardoned!"), Hud.GOLD, 2.6)
	_end_after(3.4, true)


func _lose_after_reply(line: String) -> void:
	phase = Phase.LOST
	hud.show_play(false)
	sound.music_volume = -60.0
	var k := stage.king
	k.mood("sly", 0.15)
	for g in stage.guards():
		g.look.target = stage.jester.position + Vector3(0, 1.0, 0)
		g.mood("scared")
	stage.jester.idle("nervous", 0.15)
	stage.jester.mood("scared")
	# Let him finish what he was saying.
	await _quiet(4.0)
	hud.hush()
	stage.rig.go("lever", 0.0)
	if line != "":
		hud.bubble("king", line, _beside(k), 1.0)
		king_voice.say(line)
		await get_tree().create_timer(0.35).timeout
	k.play("lever", 0.16)
	await get_tree().create_timer(0.62).timeout
	stage.room.pull_lever()
	sound.play("clunk")
	stage.rig.shake(0.05)
	await get_tree().create_timer(0.30).timeout
	hud.hush()
	stage.rig.go("trap", 0.0)
	stage.room.open_trap()
	sound.play("creak", -6.0)
	stage.jester.face.speed = 0.05
	stage.jester.mood("surprised")
	for q in stage.queue:
		q.mood("surprised")
	# He hangs in the air just long enough to understand.
	stage.jester.play("fall", 0.08)
	await get_tree().create_timer(0.42).timeout
	sound.play("fall", -8.0)
	var t := create_tween()
	t.tween_property(stage.jester, "position:y", -6.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(1.5).timeout
	sound.stop("fall")
	sound.play("thud")
	stage.rig.shake(0.10)
	stage.jester.visible = false
	for q in stage.queue:
		q.mood("scared")
		q.bump(-2.0)
	await get_tree().create_timer(0.55).timeout
	stage.rig.go("king", 0.0)
	k.mood("bored")
	stage.room.close_trap()
	sound.play("creak", -10.0, 1.3)
	hud.shout(text("next!"), Hud.RED, 2.2, 260)
	sound.play("fail", -6.0)
	_end_after(2.6, false)


func _end_after(seconds: float, won: bool) -> void:
	await get_tree().create_timer(seconds).timeout
	await _quiet(6.0)
	phase = Phase.END
	agent.stop_conversation()
	hud.hush()
	sound.music_volume = -13.0
	stage.rig.go("card", 1.1)
	if won:
		hud.card(true, true, text("pardoned"), text("laughed") % int(round(ROUND_SECONDS - left)), best_line, text("again"))
	else:
		hud.card(true, false, text("not_amused"), text("got_to") % int(amusement), best_line if best_score >= 4 else "", text("again"))


## Waits until nobody is talking.
func _quiet(at_most: float) -> void:
	var waited := 0.0
	var calm := 0.0
	while waited < at_most and calm < 0.25:
		await get_tree().process_frame
		var d := get_process_delta_time()
		waited += d
		calm = 0.0 if agent.is_speaking or king_voice.speaking or _guard_talking != "" else calm + d


# ---- Who is talking ------------------------------------------------------------------------------------------------------

func _on_state(state: LokutorAgent.State) -> void:
	match state:
		LokutorAgent.State.THINKING:
			_reply_text = []
			_reply_seconds = 0.0
			_answered = false
			_speaking_for = 0.0
			if phase == Phase.PLAY and _guard_talking == "":      # the silence after a joke belongs to his face
				stage.rig.go("king_close" if amusement > 55.0 else "king", 0.0)
		LokutorAgent.State.SPEAKING:
			_greeted = true
			_answered = true
			if phase == Phase.PLAY:
				_leak = Leak.new()
			if phase == Phase.PLAY or phase == Phase.INTRO:
				stage.rig.go("king_close" if amusement > 55.0 else "king", 0.0)
			if _manners != "":
				stage.king.mood("angry", 0.1)
			if stage.king.base == "bored" or stage.king.base == "listen":
				stage.king.idle("talk_a" if randf() < 0.5 else "talk_b")
		LokutorAgent.State.PLAYER_TALKING:
			stage.king.idle("listen")
			if stage.king.face.mood in ["bored", "confused"]:
				stage.king.mood("listen", 0.3)
		LokutorAgent.State.READY:
			if phase == Phase.INTRO:
				if _greeted:
					_start_round()
			elif phase == Phase.PLAY and _won:
				_win()
			elif phase == Phase.PLAY:
				if _answered:
					_know("joke", null)
				if _manners != "" and _answered:               # said: it is out of his chest
					_manners = ""
					_know("manners", null)
					for g in stage.guards():
						g.mood("neutral")
				stage.rig.go("play", 0.0)
				stage.king.idle("bored" if amusement < 40.0 else "listen", 0.6)
				if amusement < 40.0:
					stage.king.mood("bored", 0.6)
				else:
					stage.king.mood("amused", 0.5)
				hud.hush("king")


func _on_player_said(text: String) -> void:
	if not agent.mute_mic_while_speaking and agent.microphone != null and _his_words(text):
		_hears_himself()
		return
	_heard_last = text
	_silence = 0.0
	if phase == Phase.PLAY:
		hud.bubble("jester", text, _beside(stage.jester), 1.0, true)


func _on_error(code: String, message: String) -> void:
	push_warning("%s: %s" % [code, message])
	if phase == Phase.INTRO:
		phase = Phase.TITLE
		if code == "auth.time_limited":                # the lokutor.com demo's limits: the page around the game says why
			hud.title(true, text("space"), text("tagline"), _corner())
		else:
			hud.title(true, message)


func _spoken(text: String) -> String:
	return Lokutor.strip_tags(text)


func guard_hint(side: String, text: String) -> void:
	if _guard_talking != "":
		return
	_guard_talking = side
	var g: Actor = stage.guard_l if side == "l" else stage.guard_r
	var look := g.look.target
	g.look.target = Stage.SHOTS["guard_" + side][0] + Vector3(0, 0.9, 0)
	g.play("whisper", 0.2)
	g.mood("sly")
	stage.rig.go("guard_" + side, 0.0)
	await get_tree().create_timer(0.25).timeout
	var way := 1.0 if side == "l" else -1.0
	hud.bubble("guard", text, _beside(g, way), way)
	await guard_voices[side].say(text)
	hud.hush("guard")
	_guard_talking = ""
	g.look.target = look
	g.idle("stand")
	g.mood("neutral")
	if phase == Phase.PLAY:
		stage.rig.go("play", 0.0)


## Where a bubble points to: beside the head, `side` -1 or 1.
func _beside(actor: Actor, side := 1.0) -> Vector2:
	var wide: float = {"king": 0.66, "jester": 0.50}.get(actor.kind, 0.56)
	var up: float = {"king": 0.32, "jester": 0.28}.get(actor.kind, 0.34)
	var p := actor.head_position() + Vector3(0, up, 0) + stage.rig.camera.global_basis.x * wide * side
	if stage.rig.camera.is_position_behind(p):
		return Vector2(hud.size().x * 0.3, hud.size().y * 0.8)
	return stage.rig.camera.unproject_position(p)


func _process(delta: float) -> void:
	var king_talks := agent.is_speaking or king_voice.speaking
	stage.king.speaking = king_talks
	stage.guard_l.speaking = guard_voices.l.speaking
	stage.guard_r.speaking = guard_voices.r.speaking
	var level := 0.0
	if demo != null:
		level = demo.level()
		stage.jester.speaking = demo.talking()
	elif ear != null:
		level = ear.level
	elif agent.microphone != null:
		level = agent.microphone.level
		stage.jester.speaking = level > 0.03
		# The player's mouth has no visemes: it opens with the microphone.
		stage.jester.lips.advance(0.0, clampf(level * 3.0, 0.0, 1.0), stage.jester.speaking, delta, self)
	hud.mic.level = level
	hud.mic.visible = (phase == Phase.PLAY and not (king_talks and agent.mute_mic_while_speaking)) or (phase == Phase.TITLE and ear != null)
	if agent.is_speaking and agent.microphone != null and (phase == Phase.INTRO or not agent.mute_mic_while_speaking):
		_leak.hear(agent.microphone.level, agent.voice_level(), delta)
	hud.mic.device = _mic_label(level, delta) if demo == null and hud.mic.visible else ""
	hud.move_bubble("jester", _beside(stage.jester))
	hud.mic.open = not (agent.mute_mic_while_speaking and king_talks)
	sound.duck = 1.0 if king_talks or stage.jester.speaking or _guard_talking != "" else 0.0
	_king_caption()
	if agent.is_speaking:
		_speaking_for += delta
	if phase == Phase.PLAY:
		_play(delta, king_talks, level)


func _play(delta: float, king_talks: bool, level: float) -> void:
	var talking := stage.jester.speaking or agent.state == LokutorAgent.State.PLAYER_TALKING
	if talking:
		_silence = 0.0
		stage.jester.idle("perform", 0.2)
		stage.jester.anim.speed_scale = 0.8 + clampf(level * 5.0, 0.0, 0.8)
		if level > 0.12:
			stage.jester.bump(level * 14.0 * delta)
	else:
		stage.jester.idle("nervous" if left < 15.0 else "idle", 0.4)
		stage.jester.mood("scared" if left < 15.0 else "happy", 0.4)
	if king_talks:
		hud.hush("jester")
	# The clock does not run while the king talks: it is the jester's minute.
	if not king_talks and _guard_talking == "" and agent.state != LokutorAgent.State.THINKING and not _won:
		left = maxf(0.0, left - delta)
		_silence += delta
	hud.clock.left = left
	sound.music.pitch_scale = 1.0 if left > 15.0 else 1.12
	if left < 10.0 and int(left) != _tick:
		_tick = int(left)
		sound.play("tick", -8.0)
	if demo == null and _silence > 7.0 and _hints_given < 5 and not king_talks and agent.state == LokutorAgent.State.READY:
		_silence = 0.0
		var side := "r" if _hints_given % 2 == 0 else "l"
		guard_hint(side, text(side)[(_hints_given / 2) % text(side).size()])
		_hints_given += 1
	_know("time", Prompts.fact(lang, "hurry") if left <= 12.0 else null)
	if left <= 0.0 and not _won:
		_lose_after_reply(text("next"))


## The sentence being heard, over the king's head. Sentences arrive ahead of their sound: each one gets its share of the
## reply's length.
func _king_caption() -> void:
	if not agent.is_speaking or _reply_text.is_empty():
		if not king_voice.speaking and not agent.is_speaking and phase != Phase.LOST:
			hud.hush("king")
		return
	var total := 0
	for t in _reply_text:
		total += t.length()
	var at := agent.heard_seconds() / maxf(_reply_seconds, 0.1) * total
	var line := _reply_text[-1]
	var seen := 0
	for t in _reply_text:
		seen += t.length()
		if at <= seen:
			line = t
			break
	hud.bubble("king", line, _beside(stage.king), 1.0)


func _confetti(rehearsal := false) -> void:
	if not rehearsal:
		sound.play("confetti", -4.0)
	for side in [-1.0, 1.0]:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.explosiveness = 0.92
		p.amount = 150
		p.lifetime = 4.5
		p.position = Vector3(3.6 * side, 0.4, 4.4)
		p.direction = Vector3(-0.45 * side, 1.0, -0.15)
		p.spread = 26.0
		p.initial_velocity_min = 5.0
		p.initial_velocity_max = 9.5
		p.gravity = Vector3(0, -3.6, 0)
		p.damping_min = 0.8
		p.damping_max = 1.6
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.particle_flag_rotate_y = true
		p.angular_velocity_min = -400.0
		p.angular_velocity_max = 400.0
		var g := Gradient.new()
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		g.colors = PackedColorArray([Color("#ff5a5f"), Color("#ffc52e"), Color("#36c6b4"), Color("#7248bd"), Color("#58b9ff")])
		g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
		p.color_initial_ramp = g
		var q := QuadMesh.new()
		q.size = Vector2(0.10, 0.07)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		q.material = m
		p.mesh = q
		add_child(p)
		p.emitting = true
		get_tree().create_timer(0.3 if rehearsal else 7.0).timeout.connect(p.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode in [KEY_F, KEY_F11] or (event.keycode == KEY_ENTER and event.alt_pressed)):
		_full_screen(not _is_full_screen())
		_save(WINDOW_FILE, "full" if _is_full_screen() else "window")
	elif event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		if phase == Phase.TITLE:
			begin()
		elif phase == Phase.END:
			_to_title()
	elif event.is_action_pressed("ui_cancel") and not OS.has_feature("web"):   # a page cannot be quit
		get_tree().quit()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M and demo == null:
		var all := LokutorMicrophone.devices()
		_choose_mic(all[(all.find(_mic) + 1) % all.size()])
		_save(MIC_FILE, _mic)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H and phase in [Phase.TITLE, Phase.PLAY] and demo == null:
		var ways := ["auto", "yes", "no"]
		_save(HEADPHONES_FILE, ways[(ways.find(_headphones()) + 1) % 3])
		if phase == Phase.TITLE:
			_speak_language()
		else:
			agent.mute_mic_while_speaking = not _can_interrupt()
			hud.shout("%s: %s" % [text("headphones"), text(_headphones())], Hud.GOLD, 0.9, 90)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V and phase == Phase.TITLE and demo == null and not dev:
		_next_king()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L and phase == Phase.TITLE and _can_choose_language():
		lang = Words.LANGUAGES[(Words.LANGUAGES.find(lang) + 1) % Words.LANGUAGES.size()]
		_save(LANGUAGE_FILE, lang)
		_speak_language()


# ---- The king's voice ----------------------------------------------------------------------------------------------------
# The voice is one of Lokutor's, as it is in the language; what makes him enormous is the bus it is played through.

const KING_BUS := &"King"
const KING_FILE := "user://king.txt"
const KINGS := ["M1", "M2", "M3", "M4", "M5", "F1", "F2", "F3", "F4", "F5"]
## The one whose pitch moves most, of those measured (one line each): M5 in Spanish, M1 in English.
const BEST_KING := {"es": "M5"}


func _king() -> String:
	var chosen := str(_args.king) if _args.has("king") else ("" if _args.has("demo") else _saved(KING_FILE))
	return chosen if chosen in KINGS else BEST_KING.get(lang, "M1")


## Lower and bigger than a person, in a hall of stone.
func _king_bus() -> void:
	if AudioServer.get_bus_index(KING_BUS) >= 0:
		return
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, KING_BUS)
	var shift := AudioEffectPitchShift.new()
	shift.pitch_scale = 0.88
	shift.oversampling = 8
	AudioServer.add_bus_effect(bus, shift)
	var low := AudioEffectLowShelfFilter.new()
	low.cutoff_hz = 220.0
	low.gain = 1.6
	AudioServer.add_bus_effect(bus, low)
	var hall := AudioEffectReverb.new()
	hall.room_size = 0.55
	hall.damping = 0.6
	hall.wet = 0.14
	hall.dry = 0.95
	AudioServer.add_bus_effect(bus, hall)


## The next one, and how it sounds.
func _next_king() -> void:
	_save(KING_FILE, KINGS[(KINGS.find(_king()) + 1) % KINGS.size()])
	_speak_language()
	king_voice.say(text("next"))


# ---- The window ----------------------------------------------------------------------------------------------------------

const WINDOW_FILE := "user://window.txt"


func _is_full_screen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


func _full_screen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


# ---- The language --------------------------------------------------------------------------------------------------------

const LANGUAGE_FILE := "user://language.txt"


## What the development server and the demos say is written, in English.
func _can_choose_language() -> bool:
	return not dev and not _args.has("demo")


func _corner() -> String:
	if _args.has("demo"):
		return ""
	return ("%s [L]     " % Words.NAMES[lang] if _can_choose_language() else "") + "%s [V]     %s: %s [H]     %s [F]" % [_king(), text("headphones"), text(_headphones()), text("full")]


func text(key: String):
	return Words.TEXT[lang][key]


## Everybody speaks it and thinks in it, and the title screen is in it.
func _speak_language() -> void:
	agent.language = lang
	agent.voice = _king()
	king_voice.voice = agent.voice
	agent.persona = Prompts.arrival(lang)
	agent.context_heading = Prompts.fact(lang, "now")
	agent.speak_before_actions = false                 # `react` comes before any word
	agent.remove_action("react")
	agent.remove_action("pull_lever")
	for v in [king_voice, guard_voices.l, guard_voices.r]:
		v.language = lang
	hud.title(true, text("space") if has_key() else text("no_key"), text("tagline"), _corner())
	if has_key():                                     # written lines are made once and kept
		king_voice.preload_lines(PackedStringArray([text("next")]))
		for g in guard_voices:
			guard_voices[g].preload_lines(PackedStringArray(text(g)))


# ---- The microphone ----------------------------------------------------------------------------------------------------

const MIC_FILE := "user://microphone.txt"
const HEADPHONES_FILE := "user://headphones.txt"
var _mic := "Default"                     # AudioServer.input_device takes a moment to say it
var _heard_peak := 0.0
var _mic_seconds := 0.0


func _saved(file: String) -> String:
	return FileAccess.get_file_as_string(file) if FileAccess.file_exists(file) else ""


func _save(file: String, what: String) -> void:
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f != null:
		f.store_string(what)


## The first whose name contains it; otherwise the computer's own choice.
func _choose_mic(wanted: String) -> void:
	_heard_peak = 0.0
	_mic_seconds = 0.0
	_mic = "Default"
	if wanted != "":
		for d in LokutorMicrophone.devices():
			if d.to_lower().contains(wanted.to_lower()):
				_mic = d
				break
	AudioServer.input_device = _mic


## "auto", "yes" or "no".
func _headphones() -> String:
	if _args.has("headphones") or _args.has("speakers"):
		return "yes" if _args.has("headphones") else "no"
	var saved := "" if _args.has("demo") else _saved(HEADPHONES_FILE)
	return saved if saved in ["yes", "no"] else "auto"


## With speakers he would interrupt himself. Phones and browsers mostly play through their own speaker: there he
## only lets himself be interrupted when the player says they wear headphones.
func _can_interrupt() -> bool:
	if _headphones() != "auto":
		return _headphones() == "yes"
	return not _echoed and not (OS.has_feature("mobile") or OS.has_feature("web"))


## On the title screen, so that the player sees the bars move before there is anybody to talk to.
func _listen() -> void:
	if demo != null or _args.has("demo") or DisplayServer.get_name() == "headless" or ear != null:
		return
	ear = LokutorMicrophone.new()
	add_child(ear)
	if not ear.start():
		ear.queue_free()
		ear = null


func _mic_label(level: float, delta: float) -> String:
	_heard_peak = maxf(_heard_peak * (1.0 - 0.3 * delta), level)
	_mic_seconds += delta
	var name := _mic
	if name == "Default":
		name = text("default")
	elif name.contains("(") and name.ends_with(")"):
		name = name.get_slice("(", 1).trim_suffix(")")
	var silent := phase == Phase.TITLE and _mic_seconds > 3.0 and _heard_peak < 0.0002
	return "%s%s   [M] %s" % [name, ": " + text("silence") if silent else "", text("change")]
