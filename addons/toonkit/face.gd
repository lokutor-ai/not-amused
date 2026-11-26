class_name ToonFace
extends Node
## A face that is never still: moods that ease from one to the next, blinks, glances, and room for the visemes, which
## LokutorLipSync writes on the same mesh. A face can be in several meshes (a character cut in parts for the web: see
## lokutor-games/pipeline/web/slim.gd): each shape is set on every mesh that has it.

## Moods: blend shape -> weight. Anything not listed goes back to 0.
const MOODS := {
	"neutral": {},
	"bored": {"bored_eyes": 0.85, "frown": 0.55, "brow_sad": 0.15, "look_d": 0.15},
	"listen": {"brow_up_r": 0.35, "bored_eyes": 0.15},
	"amused": {"smirk": 0.75, "squint": 0.35, "brow_up_l": 0.45},
	"happy": {"smile": 0.9, "squint": 0.15, "brow_up_l": 0.35, "brow_up_r": 0.35},
	"giggle": {"grin": 0.9, "happy_eyes": 0.9, "brow_up_l": 0.4, "brow_up_r": 0.4},
	"laugh": {"laugh": 1.0, "happy_eyes": 1.0, "brow_up_l": 0.7, "brow_up_r": 0.7},
	"hold": {"puff": 1.0, "wobble": 0.35, "wide_eyes": 0.35, "brow_sad": 0.9, "look_u": 0.4},
	"angry": {"grit": 0.75, "angry_eyes": 1.0, "brow_angry": 1.0},
	"offended": {"gasp": 0.9, "wide_eyes": 0.9, "brow_up_l": 0.6, "brow_up_r": 0.6},
	"confused": {"brow_up_l": 1.0, "brow_angry": 0.25, "frown": 0.35, "squint": 0.2},
	"sly": {"smirk": 1.0, "squint": 0.7, "brow_angry": 0.5},
	"sad": {"sad_eyes": 0.9, "brow_sad": 1.0, "frown": 0.8},
	"surprised": {"gasp": 0.7, "wide_eyes": 1.0, "brow_up_l": 0.8, "brow_up_r": 0.8},
	"scared": {"grit": 0.6, "wide_eyes": 0.9, "brow_sad": 1.0},
}
## Mouth shapes of moods give way to the visemes while the character speaks.
const MOUTHS := ["smile", "grin", "laugh", "frown", "gasp", "grit", "pout", "smirk", "wobble", "puff"]

var mesh: MeshInstance3D                 # the first of them
var meshes: Array[MeshInstance3D] = []
var mood := "neutral"
## Extra weights on top of the mood.
var extra := {}
## Seconds a mood takes to arrive.
var speed := 0.16
## Where the character looks, as (left +, up +), each -1..1. Glances are added.
var gaze := Vector2.ZERO
## 0..1: how much the mouth is busy speaking.
var speaking := 0.0
## How far each expression brings the upper lids down.
const LIDS := {"bored_eyes": 0.55, "angry_eyes": 0.34, "squint": 0.34, "sad_eyes": 0.26}
var blinking := true

var _now := {}
var _vel := {}
var _index := {}
var _blink_in := 1.5
var _blink := 0.0
var _glance := Vector2.ZERO
var _glance_in := 1.0
var _look := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


## `face`: the mesh with the face's shapes, or all of them.
func setup(face, random_seed := 7) -> ToonFace:
	meshes.assign(face if face is Array else [face])
	mesh = meshes[0]
	_rng.seed = random_seed
	for m in meshes:
		for i in m.get_blend_shape_count():
			(_index.get_or_add(str(m.mesh.get_blend_shape_name(i)), []) as Array).append([m, i])
	return self


## A shape's weight, on every mesh that has it. Barely on is off: a shape at rest costs nothing, while one that is on at
## all is one more pass over the mesh on the GPU every frame in a browser.
func _put(shape: String, weight: float) -> void:
	if absf(weight) < 0.004:
		weight = 0.0
	for at in _index[shape]:
		(at[0] as MeshInstance3D).set_blend_shape_value(at[1], weight)


func set_mood(new_mood: String, seconds := 0.16) -> void:
	mood = new_mood
	speed = seconds


func _process(delta: float) -> void:
	if mesh == null:
		return
	var want: Dictionary = MOODS.get(mood, {}).duplicate()
	for k in extra:
		want[k] = maxf(want.get(k, 0.0), extra[k])
	for k in _index:
		if k.begins_with("viseme_") or k.begins_with("blink_") or k.begins_with("look_"):
			continue
		var target: float = want.get(k, 0.0)
		if k in MOUTHS:
			target *= lerpf(1.0, 0.30, speaking)
		# A spring that goes a touch past the mood and settles: expressions pop.
		var x: float = _now.get(k, 0.0)
		var v: float = _vel.get(k, 0.0)
		if absf(target - x) < 0.0005 and absf(v) < 0.0005:
			if x != target:
				_now[k] = target
				_put(k, target)
			continue
		var w := 4.0 / maxf(speed, 0.02)
		for n in 4:
			var h := delta / 4.0
			v += (w * w * (target - x) - 2.0 * 0.62 * w * v) * h
			x += v * h
		_now[k] = x
		_vel[k] = v
		_put(k, clampf(x, -0.15, 1.2))
	_eyes(delta)


func _eyes(delta: float) -> void:
	_blink_in -= delta
	if _blink_in <= 0.0 and blinking:
		_blink_in = _rng.randf_range(1.6, 4.6) if _rng.randf() > 0.18 else 0.28       # now and then, two in a row
		_blink = 1.0
	_blink = maxf(0.0, _blink - delta / 0.17)
	var lid := sin(clampf(1.0 - _blink, 0.0, 1.0) * PI) if _blink > 0.0 else 0.0
	var shut: float = 1.0 - clampf(_now.get("happy_eyes", 0.0), 0.0, 1.0)
	# A blink takes the lids from wherever the mood has them to closed, so the mood's lids give way while it lasts.
	var b := {"l": maxf(lid * shut, extra.get("blink_l", 0.0)), "r": maxf(lid * shut, extra.get("blink_r", 0.0))}
	var both := minf(b.l, b.r)
	var down := 0.0
	for k in LIDS:
		down += LIDS[k] * clampf(_now.get(k, 0.0), 0.0, 1.0)
		if _index.has(k):
			_put(k, clampf(_now.get(k, 0.0), -0.15, 1.2) * (1.0 - both))
	down = minf(down, 1.0)
	for e in ["l", "r"]:
		if _index.has("blink_" + e):
			var x: float = both + (b[e] - both) * (1.0 - down * (1.0 - both))
			_put("blink_" + e, x)
			if _index.has("blink_mid_" + e):             # round the eye, not through it: see in_betweens() in chubby.py
				_put("blink_mid_" + e, 4.0 * x * (1.0 - x) * (1.0 - down) * (1.0 - down))
	_glance_in -= delta
	if _glance_in <= 0.0:
		_glance_in = _rng.randf_range(0.5, 2.4)
		_glance = Vector2(_rng.randfn(0.0, 0.22), _rng.randfn(0.0, 0.12)) if _rng.randf() > 0.35 else Vector2.ZERO
	var mood_look := Vector2(_want("look_l") - _want("look_r"), _want("look_u") - _want("look_d"))
	# Eyes jump, they do not slide.
	_look = _look.lerp((gaze + _glance + mood_look).limit_length(1.0), 1.0 - exp(-delta * 28.0))
	for p in [["look_l", _look.x], ["look_r", -_look.x], ["look_u", _look.y], ["look_d", -_look.y]]:
		if _index.has(p[0]):
			_put(p[0], maxf(0.0, p[1]))


func _want(k: String) -> float:
	return MOODS.get(mood, {}).get(k, 0.0)
