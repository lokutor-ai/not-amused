extends "res://game/game.gd"
## The game on a phone: a tap instead of the space bar, and buttons instead of keys.

## AudioDeviceInfo: wired headset and headphones, Bluetooth (call and music), USB headset, hearing aid, Bluetooth LE headset.
const ON_THE_EARS := [3, 4, 7, 8, 22, 23, 26]
const KEY_FILE := "user://lokutor_key.txt"          # put there over USB, for tests on one's own phone
const TAP := {
	"en": ["Tap to play", "Tap to try again", "There is no key on this phone"],
	"es": ["Toca para jugar", "Toca para repetir", "No hay clave en este móvil"],
	"ca": ["Toca per jugar", "Toca per tornar-hi", "No hi ha clau en aquest mòbil"],
	"gl": ["Toca para xogar", "Toca para repetir", "Non hai clave neste móbil"],
	"eu": ["Ukitu jokatzeko", "Ukitu berriro saiatzeko", "Ez dago gakorik mugikor honetan"],
	"pt": ["Toca para jogar", "Toca para repetir", "Não há chave neste telemóvel"],
	"fr": ["Touche pour jouer", "Touche pour rejouer", "Pas de clé sur ce téléphone"],
	"it": ["Tocca per giocare", "Tocca per riprovare", "Nessuna chiave su questo telefono"],
	"de": ["Zum Spielen tippen", "Tippen: noch einmal", "Kein Schlüssel auf diesem Telefon"],
}

var _buttons: HBoxContainer


func _ready() -> void:
	var key := _saved(KEY_FILE).strip_edges()
	if key != "":
		OS.set_environment("LOKUTOR_API_KEY", key)
	get_tree().quit_on_go_back = false
	print("audio outputs %s, on the ears: %s" % [outputs(), headphones_on()])
	super()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if phase == Phase.TITLE:
			get_tree().quit()
		else:
			get_tree().reload_current_scene()
	elif what == NOTIFICATION_APPLICATION_PAUSED and phase != Phase.TITLE:      # nobody is talking to him any more
		agent.stop_conversation()
		get_tree().reload_current_scene()


## With the phone's loudspeaker he hears himself, and interrupts himself.
func _can_interrupt() -> bool:
	return super() and (_headphones() == "yes" or headphones_on())


static func headphones_on() -> bool:
	return outputs().any(func(o): return o in ON_THE_EARS)


## What the phone can play through, as AudioDeviceInfo types.
static func outputs() -> Array:
	if not Engine.has_singleton("AndroidRuntime"):
		return []
	var audio = Engine.get_singleton("AndroidRuntime").getApplicationContext().getSystemService("audio")
	var all = audio.getDevices(2) if audio != null else null
	return all.map(func(o): return int(o.getType())) if all is Array else []


func _speak_language() -> void:
	super()
	if _buttons == null:
		_make_buttons()
	_buttons.get_child(0).text = Words.NAMES[lang]
	_buttons.get_child(1).text = _king()
	_buttons.get_child(2).text = "%s: %s" % [text("headphones"), text(_headphones())]


func _process(delta: float) -> void:
	super(delta)
	if _buttons != null:
		_buttons.visible = phase == Phase.TITLE


func text(key: String):
	var at := ["space", "again", "no_key"].find(key)
	return super(key) if at < 0 else TAP[lang][at]


## The buttons say it.
func _corner() -> String:
	return ""


## There is one microphone; what matters is whether it hears.
func _mic_label(level: float, delta: float) -> String:
	return text("silence") if super(level, delta).contains(text("silence")) else ""


func _make_buttons() -> void:
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 26)
	_buttons.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_buttons.offset_right = -70.0
	_buttons.offset_top = 44.0
	hud.add_child(_buttons)
	for key in [KEY_L, KEY_V, KEY_H]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 116)
		b.add_theme_font_override("font", Hud.ink_font())
		b.add_theme_font_size_override("font_size", 38)
		for colour in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(colour, Hud.INK)
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, _pill(Hud.GOLD if state == "pressed" else Hud.CREAM))
		b.pressed.connect(_press.bind(key))
		_buttons.add_child(b)


func _pill(colour: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = colour
	s.border_color = Hud.INK
	s.set_border_width_all(6)
	s.set_corner_radius_all(40)
	s.corner_detail = 12
	s.content_margin_left = 38.0
	s.content_margin_right = 38.0
	s.shadow_color = Color(Hud.INK, 0.35)
	s.shadow_size = 1
	s.shadow_offset = Vector2(0, 8)
	return s


## What the key does on a computer.
func _press(key: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = key
	e.pressed = true
	_unhandled_input(e)
