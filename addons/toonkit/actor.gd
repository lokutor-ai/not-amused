class_name Actor
extends Node3D
## A character built by the pipeline: the model in toon colours, its clips, its springs, its face and the mouth of its voice.
## res://assets/<kind>.glb, and <kind>.json beside it, which says what loops and what wobbles.

var kind := ""
## Material name -> colour, for extras that share a model.
var colours := {}
var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var mesh: MeshInstance3D
var face: ToonFace
var lips: LokutorLipSync
var look: HeadLook
## The clip it goes back to.
var base := ""
## Set while its voice sounds: the mouth leaves the mood and the head moves with the words.
var speaking := false
## How much the head moves with the voice, in degrees.
var nod := 7.0
## Metres, with its hat.
var height := 1.75

var _squash := 1.0
var _squash_v := 0.0
var _beat := 0.0
var _time := 0.0


static func create(new_kind: String) -> Actor:
	var a := Actor.new()
	a.kind = new_kind
	a.name = new_kind
	return a


func _ready() -> void:
	model = (load("res://assets/%s.glb" % kind) as PackedScene).instantiate()
	add_child(model)
	Toon.apply(model, 3.4, {}, colours)
	if Toon.few_draws():
		Toon.batch(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	mesh = meshes[0]
	for m in meshes:
		m.extra_cull_margin = 2.0
	# The meshes with the face's shapes: one, or a few for the web (lokutor-games/pipeline/web/slim.gd).
	var faces: Array[MeshInstance3D] = []
	faces.assign(meshes.filter(func(m): return m.mesh != null and m.mesh.get_blend_shape_count() > 0))
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/%s.json" % kind))
	height = report.get("height", height)
	for c in report.clips:
		anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR if report.clips[c].loop else Animation.LOOP_NONE
	look = HeadLook.new()
	skeleton.add_child(look)
	var springs := JellySprings.new()
	springs.swing = report.springs.get("swing", {})
	springs.soft = report.springs.get("soft", {})
	skeleton.add_child(springs)
	face = ToonFace.new().setup(faces, hash(kind))
	add_child(face)
	lips = LokutorLipSync.new()
	lips.faces = faces
	add_child(lips)


## Out of sight (the jester before he comes in, the queue behind the door when the camera looks ahead) it does nothing:
## its clips, skeleton, springs and face wait until it shows again.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		process_mode = PROCESS_MODE_INHERIT if is_visible_in_tree() else PROCESS_MODE_DISABLED


## Plays a clip. A clip that does not loop goes back to `base`, or to `then`.
func play(clip: String, blend := 0.22, pace := 1.0, then := "") -> void:
	var loops := anim.get_animation(clip).loop_mode != Animation.LOOP_NONE
	anim.speed_scale = pace
	if loops and anim.current_animation == clip:
		return
	anim.play(clip, blend)
	if not loops and (then != "" or base != ""):
		_after(clip, then if then != "" else base)


func idle(clip: String, blend := 0.35) -> void:
	base = clip
	play(clip, blend)


func _after(clip: String, then: String) -> void:
	await get_tree().create_timer(maxf(0.05, anim.get_animation(clip).length / anim.speed_scale - 0.12)).timeout
	if is_inside_tree() and anim.current_animation == clip:
		anim.speed_scale = 1.0
		anim.play(then, 0.28)


func mood(new_mood: String, seconds := 0.16) -> void:
	face.set_mood(new_mood, seconds)


## A hop without leaving the ground: positive stretches, negative squashes.
func bump(strength := 1.5) -> void:
	_squash_v += strength


func head_position() -> Vector3:
	return (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("head"))).origin


func _process(delta: float) -> void:
	_time += delta
	face.speaking = move_toward(face.speaking, 1.0 if speaking else 0.0, delta * 9.0)
	# The head leans into the loud syllables and drifts between phrases: nobody talks with a still head.
	_beat = lerpf(_beat, lips.mouth_open if speaking else 0.0, 1.0 - exp(-delta * 9.0))
	var drift := Vector3(sin(_time * 1.7) * 0.55 + sin(_time * 2.9 + 1.0) * 0.3, sin(_time * 2.3 + 2.0) * 0.35, sin(_time * 1.3 + 4.0) * 0.6)
	look.offset = Vector3(drift.x * nod * 0.7, -_beat * nod * 0.9 + drift.y * nod * 0.4, drift.z * nod * 0.6) * face.speaking
	for n in 4:
		var h := delta / 4.0
		_squash_v += ((1.0 - _squash) * 260.0 - _squash_v * 13.0) * h
		_squash += _squash_v * h
	var s := clampf(_squash, 0.72, 1.3)
	model.scale = Vector3(1.0 / sqrt(s), s, 1.0 / sqrt(s))
