class_name Hud
extends CanvasLayer
## Everything drawn over the stage, in the same ink as the characters: bubbles, the meter, the clock, big words.

const INK := Color("#2b1633")
const CREAM := Color("#fff6e4")
const RED := Color("#e8344c")
const GOLD := Color("#ffc52e")
const TEAL := Color("#22b8a5")

static var font: Font

var meter: Meter
var clock: Clock
var mic: MicBadge
var _root: Control
var _bubbles := {}
var _big: Control
var _title: Control
var _card: Control


static func ink_font() -> Font:
	if font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Arial Rounded MT Bold", "Segoe UI", "SF Pro Rounded", "Ubuntu", "Arial"])
		f.font_weight = 900
		f.multichannel_signed_distance_field = false
		font = f
	return font


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	meter = Meter.new()
	_root.add_child(meter)
	clock = Clock.new()
	_root.add_child(clock)
	mic = MicBadge.new()
	_root.add_child(mic)
	for n in ["king", "jester", "guard"]:
		var b := Bubble.new()
		_root.add_child(b)
		_bubbles[n] = b
	show_play(false)


func size() -> Vector2:
	return _root.get_viewport_rect().size


func show_play(on: bool) -> void:
	for c in [meter, clock, mic]:
		c.visible = on


## Says something over a character. `at`: where its head is on the screen. `side`: -1 the bubble goes left, 1 right.
func bubble(who: String, text: String, at: Vector2, side := 1.0, small := false) -> void:
	_bubbles[who].say(text, at, side, small)


func move_bubble(who: String, at: Vector2) -> void:
	_bubbles[who].anchor = at


func hush(who := "") -> void:
	for n in _bubbles:
		if who == "" or n == who:
			_bubbles[n].hush()


## A word that fills the screen, letter by letter.
func shout(text: String, colour := GOLD, seconds := 2.0, size_px := 210) -> void:
	if _big:
		_big.queue_free()
	_big = _letters(text, size_px, colour, Vector2(size().x / 2.0, size().y * 0.40))
	_root.add_child(_big)
	var mine := _big
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(mine):
		var t := create_tween()
		t.tween_property(mine, "modulate:a", 0.0, 0.25)
		t.tween_callback(mine.queue_free)


## A floating "+18" under the meter.
func score(points: int) -> void:
	if points == 0:
		return
	var at := Vector2(size().x / 2.0 - 380.0 + 7.6 * clampf(meter.value, 4.0, 96.0), 210.0)
	var l := _letters(("+%d" if points > 0 else "%d") % points, 88, TEAL if points > 0 else RED, at)
	_root.add_child(l)
	var t := create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - 46.0, 1.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	t.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.9)
	t.chain().tween_callback(l.queue_free)


func title(on: bool, hint := "Press SPACE", tagline := "Make the king laugh. With your voice.", corner := "") -> void:
	if _title:
		var old := _title
		_title = null
		var t := create_tween()
		t.tween_property(old, "position:y", old.position.y + 420.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_callback(old.queue_free)
	if not on:
		return
	_title = Control.new()
	_root.add_child(_title)
	var c := Vector2(size().x / 2.0, size().y * 0.80)
	_title.add_child(_letters("NOT AMUSED", 190, GOLD, c + Vector2(0, -34)))
	_title.add_child(_line(tagline, 46, CREAM, c + Vector2(0, 112)))
	if corner != "":
		_title.add_child(_line(corner, 28, CREAM, size() - Vector2(70.0 + ink_font().get_string_size(corner, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x / 2.0, 80.0)))
	var h := _line(hint, 34, GOLD, c + Vector2(0, 176))
	_title.add_child(h)
	var t := h.create_tween().set_loops()
	t.tween_property(h, "modulate:a", 0.35, 0.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(h, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


## The end: what happened, how long it took and the line that did it.
func card(on: bool, won := false, big := "", small := "", quote := "", hint := "Press SPACE to try again") -> void:
	if _card:
		_card.queue_free()
		_card = null
	if not on:
		return
	_card = CardBox.new()
	_root.add_child(_card)
	_card.setup(won, big, small, quote, hint)


func _letters(text: String, px: int, colour: Color, centre: Vector2) -> Control:
	var box := Control.new()
	var f := ink_font()
	var total := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var k := minf(1.0, (size().x - 160.0) / maxf(total, 1.0))
	px = int(px * k)
	total = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var x := -total / 2.0
	box.position = centre
	for i in text.length():
		var ch := text[i]
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var l := Letter.new()
		l.setup(ch, px, colour)
		l.position = Vector2(x + w / 2.0, 0)
		l.rotation = (0.05 if i % 2 else -0.05) * (1.0 if text.length() > 2 else 0.4)
		box.add_child(l)
		l.scale = Vector2.ZERO
		var t := l.create_tween()
		t.tween_interval(i * 0.035)
		t.tween_property(l, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		x += w
	return box


func _line(text: String, px: int, colour: Color, centre: Vector2) -> Control:
	var l := Letter.new()
	l.setup(text, px, colour)
	l.position = centre
	return l


## A word drawn in colour with an ink border and a hard shadow.
class Letter extends Control:
	var text := ""
	var px := 60
	var colour := Color.WHITE

	func setup(new_text: String, new_px: int, new_colour: Color) -> void:
		text = new_text
		px = new_px
		colour = new_colour
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		var f := Hud.ink_font()
		var s := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var at := Vector2(-s.x / 2.0, f.get_ascent(px) - s.y / 2.0)
		var o := maxi(6, int(px * 0.17))
		draw_string_outline(f, at + Vector2(0, px * 0.07), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, o, Hud.INK)
		draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, o, Hud.INK)
		draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, colour.lerp(Color.BLACK, 0.16))
		draw_set_transform(Vector2(0, -px * 0.022))
		draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, colour)


## A speech bubble with a tail.
class Bubble extends Control:
	var anchor := Vector2.ZERO
	var _text := ""
	var _side := 1.0
	var _px := 44
	var _pop := 0.0
	var _pop_v := 0.0
	var _want := 0.0

	func say(text: String, at: Vector2, side: float, small: bool) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if text != _text or _want == 0.0:
			_pop = minf(_pop, 0.86)
		_text = text
		_side = side
		_px = 36 if small else 44
		anchor = at
		_want = 1.0

	func hush() -> void:
		_want = 0.0

	func _process(delta: float) -> void:
		for n in 3:
			_pop_v += ((_want - _pop) * 420.0 - _pop_v * 24.0) * delta / 3.0
			_pop += _pop_v * delta / 3.0
		visible = _pop > 0.02
		queue_redraw()

	func _draw() -> void:
		if _text == "":
			return
		var f := Hud.ink_font()
		var wide := 620.0
		var t := f.get_multiline_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, wide, _px)
		var pad := Vector2(34, 22)
		var box := t + pad * 2.0
		var view := get_viewport_rect().size
		var at := anchor + Vector2(62.0 * _side - (box.x if _side < 0.0 else 0.0), -box.y * 0.5 - 34.0)
		at.x = clampf(at.x, 40.0, view.x - box.x - 40.0)
		at.y = clampf(at.y, 130.0, view.y - box.y - 60.0)
		var k := maxf(_pop, 0.0)
		var tip := anchor
		draw_set_transform(tip * (1.0 - k), 0.0, Vector2(k, k))
		var edge := Vector2(at.x if _side > 0.0 else at.x + box.x, clampf(anchor.y, at.y + 34.0, at.y + box.y - 34.0))
		var tail := PackedVector2Array([edge + Vector2(14.0 * _side, -20), edge + Vector2(14.0 * _side, 22), tip])
		var style := StyleBoxFlat.new()
		style.bg_color = Hud.CREAM
		style.border_color = Hud.INK
		style.set_border_width_all(6)
		style.set_corner_radius_all(34)
		style.corner_detail = 12
		style.shadow_color = Color(Hud.INK, 0.35)
		style.shadow_size = 1
		style.shadow_offset = Vector2(0, 9)
		draw_style_box(style, Rect2(at, box))
		draw_colored_polygon(tail, Hud.CREAM)
		draw_polyline(PackedVector2Array([tail[0] - Vector2(14.0 * _side, 0), tail[2], tail[1] - Vector2(14.0 * _side, 0)]), Hud.INK, 6.0, true)
		draw_line(tail[0] - Vector2(10.0 * _side, -5), tail[1] - Vector2(10.0 * _side, 5), Hud.CREAM, 12.0)
		draw_multiline_string(f, at + pad + Vector2(0, f.get_ascent(_px)), _text, HORIZONTAL_ALIGNMENT_LEFT, wide, _px, -1, Hud.INK)


## How amused the king is, with his face riding the bar.
class Meter extends Control:
	var value := 0.0
	var _shown := 0.0
	var _v := 0.0
	var _time := 0.0
	var _kick := 0.0

	func set_value(v: float) -> void:
		_kick = 1.0 if v > value else -0.6
		value = v

	func _process(delta: float) -> void:
		_time += delta
		for n in 3:
			_v += ((value - _shown) * 90.0 - _v * 9.0) * delta / 3.0
			_shown += _v * delta / 3.0
		_kick = move_toward(_kick, 0.0, delta * 1.6)
		queue_redraw()

	func _draw() -> void:
		var view := get_viewport_rect().size
		var w := 760.0
		var h := 50.0
		var at := Vector2(view.x / 2.0 - w / 2.0, 52.0)
		var body := StyleBoxFlat.new()
		body.bg_color = Color("#5a3a66")
		body.border_color = Hud.INK
		body.set_border_width_all(7)
		body.set_corner_radius_all(26)
		body.corner_detail = 12
		body.shadow_color = Color(Hud.INK, 0.35)
		body.shadow_size = 1
		body.shadow_offset = Vector2(0, 8)
		draw_style_box(body, Rect2(at, Vector2(w, h)))
		var k := clampf(_shown / 100.0, 0.0, 1.0)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("#36c6b4").lerp(Color("#ffc52e"), clampf(k * 2.0, 0.0, 1.0)).lerp(Color("#ff5a5f"), clampf(k * 2.0 - 1.0, 0.0, 1.0))
		fill.set_corner_radius_all(19)
		fill.corner_detail = 10
		if k > 0.03:
			draw_style_box(fill, Rect2(at + Vector2(7, 7), Vector2(maxf(38.0, (w - 14.0) * k), h - 14.0)))
			draw_rect(Rect2(at + Vector2(24, 13), Vector2(maxf(0.0, (w - 14.0) * k - 46.0), 7)), Color(1, 1, 1, 0.45))
		for i in range(1, 4):
			draw_line(at + Vector2(w * i / 4.0, 10), at + Vector2(w * i / 4.0, h - 10), Color(Hud.INK, 0.35), 4.0)
		_face(at + Vector2(clampf(w * k, 26.0, w - 26.0), h / 2.0 + sin(_time * 22.0) * 5.0 * absf(_kick)), 46.0 + 9.0 * maxf(_kick, 0.0), k)

	## The king, small: what the bar means.
	func _face(c: Vector2, r: float, k: float) -> void:
		draw_set_transform(c, sin(_time * 18.0) * 0.12 * absf(_kick) + sin(_time * 1.3) * 0.03)
		var crown := PackedVector2Array([Vector2(-0.62, -0.62), Vector2(-0.74, -1.30), Vector2(-0.32, -0.98), Vector2(0, -1.42), Vector2(0.32, -0.98), Vector2(0.74, -1.30), Vector2(0.62, -0.62)])
		for i in crown.size():
			crown[i] *= r
		draw_colored_polygon(crown, Hud.GOLD)
		draw_polyline(crown + PackedVector2Array([crown[0]]), Hud.INK, 5.0, true)
		draw_circle(Vector2.ZERO, r, Hud.INK)
		draw_circle(Vector2.ZERO, r - 5.0, Color("#ffc59b"))
		var beard := PackedVector2Array()
		for i in 21:
			var a := lerpf(0.10, PI - 0.10, i / 20.0)
			beard.append(Vector2(cos(a), sin(a)) * (r - 5.0))
		beard.append(Vector2(-0.62, 0.22) * r)
		beard.append(Vector2(0.62, 0.22) * r)
		draw_colored_polygon(beard, Color("#fff8ec"))
		for s in [-1.0, 1.0]:
			var e: Vector2 = Vector2(0.34 * s, -0.16) * r
			if k > 0.55:
				draw_arc(e + Vector2(0, 0.10 * r), 0.20 * r, PI + 0.3, TAU - 0.3, 12, Hud.INK, 6.0, true)
			else:
				draw_circle(e, 0.22 * r, Color.WHITE)
				draw_circle(e + Vector2(0, 0.03 * r), 0.12 * r, Hud.INK)
				var lid := lerpf(0.10, -0.24, clampf(k * 2.2, 0.0, 1.0))
				draw_rect(Rect2(e + Vector2(-0.24, -0.26) * r, Vector2(0.48, 0.26 + lid) * r), Color("#ffc59b"))
				draw_line(e + Vector2(-0.24, lid) * r, e + Vector2(0.24, lid) * r, Hud.INK, 5.0)
			draw_line(e + Vector2(-0.22, -0.34 - 0.12 * k) * r, e + Vector2(0.22, -0.34 - 0.12 * k) * r, Color("#fff8ec"), 8.0)
		if k > 0.4:
			var m := PackedVector2Array()
			for i in 13:
				var a := PI * i / 12.0
				m.append(Vector2(cos(a) * 0.40, 0.34 + sin(a) * 0.42 * k) * r)
			draw_colored_polygon(m, Color("#5b1226"))
		else:
			draw_arc(Vector2(0, (0.62 if k < 0.2 else 0.40) * r), 0.24 * r, (PI + 0.5) if k < 0.2 else 0.5, (TAU - 0.5) if k < 0.2 else PI - 0.5, 10, Hud.INK, 6.0, true)
		draw_circle(Vector2(0, 0.10) * r, 0.16 * r, Color("#ff9d86"))
		draw_set_transform(Vector2.ZERO)


## Seconds left.
class Clock extends Control:
	var left := 60.0
	var total := 60.0
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var view := get_viewport_rect().size
		var hurry := left < 10.5 and left > 0.0
		var r := 66.0 * (1.0 + (0.06 * maxf(0.0, sin(_time * TAU * 2.0)) if hurry else 0.0))
		draw_set_transform(Vector2(view.x - 130.0, 118.0))
		draw_circle(Vector2(0, 8), r, Color(Hud.INK, 0.35))
		draw_circle(Vector2.ZERO, r, Hud.INK)
		draw_circle(Vector2.ZERO, r - 7.0, Hud.CREAM)
		var k := clampf(left / total, 0.0, 1.0)
		if k > 0.001:
			var pie := PackedVector2Array([Vector2.ZERO])
			for i in 49:
				var a := -PI / 2.0 - TAU * k * i / 48.0
				pie.append(Vector2(cos(a), sin(a)) * (r - 13.0))
			draw_colored_polygon(pie, Hud.RED if hurry else Hud.TEAL)
		var f := Hud.ink_font()
		var text := str(int(ceil(left)))
		var s := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 54)
		var at := Vector2(-s.x / 2.0, f.get_ascent(54) - s.y / 2.0)
		draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, 14, Hud.INK)
		draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color.WHITE)


## The microphone: whether it hears you.
class MicBadge extends Control:
	var level := 0.0
	var open := true
	## Which one, over the badge. Empty: nothing is written.
	var device := ""
	var _bars := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0])
	var _clock := 0.0

	func _process(delta: float) -> void:
		_clock += delta
		if _clock > 0.05:
			_clock = 0.0
			for i in range(_bars.size() - 1, 0, -1):
				_bars[i] = _bars[i - 1]
			_bars[0] = clampf(level * 4.0, 0.0, 1.0) if open else 0.0
		queue_redraw()

	func _draw() -> void:
		var view := get_viewport_rect().size
		var at := Vector2(70.0, view.y - 120.0)
		var body := StyleBoxFlat.new()
		body.bg_color = Hud.CREAM if open else Color("#c9b8c9")
		body.border_color = Hud.INK
		body.set_border_width_all(6)
		body.set_corner_radius_all(34)
		body.corner_detail = 12
		body.shadow_color = Color(Hud.INK, 0.35)
		body.shadow_size = 1
		body.shadow_offset = Vector2(0, 8)
		draw_style_box(body, Rect2(at, Vector2(250, 68)))
		var m := at + Vector2(48, 34)
		draw_line(m + Vector2(0, -10), m + Vector2(0, 4), Hud.RED if open else Hud.INK, 18.0)
		draw_circle(m + Vector2(0, -10), 9.0, Hud.RED if open else Hud.INK)
		draw_circle(m + Vector2(0, 4), 9.0, Hud.RED if open else Hud.INK)
		draw_arc(m + Vector2(0, 2), 16.0, 0.15, PI - 0.15, 14, Hud.INK, 4.0, true)
		draw_line(m + Vector2(0, 18), m + Vector2(0, 26), Hud.INK, 4.0)
		for i in _bars.size():
			var h := 6.0 + 36.0 * _bars[i]
			draw_line(at + Vector2(92 + i * 20, 34 - h / 2.0), at + Vector2(92 + i * 20, 34 + h / 2.0), Hud.INK if not open else Hud.TEAL.darkened(0.1), 10.0)
		if device != "":
			var f := Hud.ink_font()
			draw_string_outline(f, at + Vector2(6, -18), device, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 10, Hud.INK)
			draw_string(f, at + Vector2(6, -18), device, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Hud.CREAM)


## The card at the end.
class CardBox extends Control:
	var _won := false
	var _quote := ""
	var _t := 0.0

	func setup(won: bool, big: String, small: String, quote: String, hint: String) -> void:
		_won = won
		_quote = quote
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		var view := get_viewport_rect().size
		var c := Vector2(view.x * 0.735, view.y * 0.36)
		for part in [[big, 124, Hud.GOLD if won else Hud.RED, c + Vector2(0, -130)], [small, 44, Hud.CREAM, c + Vector2(0, -28)], [hint, 32, Hud.GOLD, c + Vector2(0, 208 if _quote != "" else 62)]]:
			var l := Letter.new()
			l.setup(part[0], part[1], part[2])
			l.position = part[3]
			add_child(l)
			l.scale = Vector2.ZERO
			l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.12 * get_child_count())

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if _quote == "":
			return
		var view := get_viewport_rect().size
		var f := Hud.ink_font()
		var text := "“%s”" % _quote
		var wide := 760.0
		var s := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, wide, 42)
		var box := Vector2(minf(wide, s.x) + 76.0, s.y + 34.0)
		var k := clampf((_t - 0.5) * 4.0, 0.0, 1.0)
		var at := Vector2(view.x * 0.735, view.y * 0.36 + 70.0 + s.y / 2.0)
		draw_set_transform(at, -0.012, Vector2(k, k))
		var style := StyleBoxFlat.new()
		style.bg_color = Hud.CREAM
		style.border_color = Hud.INK
		style.set_border_width_all(6)
		style.set_corner_radius_all(30)
		style.corner_detail = 12
		draw_style_box(style, Rect2(-box / 2.0, box))
		draw_multiline_string(f, Vector2(-wide / 2.0, -s.y / 2.0 + f.get_ascent(42)), text, HORIZONTAL_ALIGNMENT_CENTER, wide, 42, -1, Hud.INK)
