extends Node3D
## Contact sheets of a character, with the game's own shading: turntable, every viseme, every expression, every clip.
##   godot --path <game> res://addons/toonkit/qa/sheet.tscn -- model=res://assets/king.glb out=C:/sheets [only=visemes]

const W := 420
const H := 420

var _vp: SubViewport
var _cam: Camera3D
var _model: Node3D
var _face: MeshInstance3D
var _out := "user://sheets"
var _args := {}
var _face_size := 1.5


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		_args[p[0]] = p[1] if p.size() > 1 else ""
	_out = _args.get("out", _out)
	DirAccess.make_dir_recursive_absolute(_out)
	_vp = SubViewport.new()
	_vp.size = Vector2i(W * 2, H * 2)
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#bfe3df")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9a86c8")
	env.ambient_light_energy = 0.62
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 32, 0)
	sun.light_color = Color("#fff1d8")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.shadow_normal_bias = 3.0
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 28
	_vp.add_child(_cam)
	_model = (load(_args.model) as PackedScene).instantiate()
	_vp.add_child(_model)
	Toon.apply(_model, 3.0)
	_face = _model.find_children("*", "MeshInstance3D", true, false)[0]
	var box := _face.get_aabb()
	var label := str(_args.model).get_file().get_basename()
	var only := str(_args.get("only", "turn,visemes,expressions,moods,clips"))
	var about = JSON.parse_string(FileAccess.get_file_as_string(str(_args.model).get_basename() + ".json"))
	var head := box.position.y + box.size.y * 0.72
	if about is Dictionary and about.has("face_z"):
		head = about.face_z - 0.03
		_face_size = (about.head[1] - about.head[0]) * 1.25
	if only.contains("turn"):
		await _sheet(label + "_turn", range(8), func(i):
			_frame(box, deg_to_rad(i * 45.0))
			return "%d" % (i * 45), 4)
	var shapes: Array = []
	for i in _face.get_blend_shape_count():
		shapes.append(str(_face.mesh.get_blend_shape_name(i)))
	for group in [["visemes", shapes.filter(func(s): return s.begins_with("viseme_"))], ["expressions", shapes.filter(func(s): return not s.begins_with("viseme_"))]]:
		if only.contains(group[0]):
			await _sheet(label + "_" + group[0], group[1], func(s):
				_close(head, box)
				for i in shapes.size():
					_face.set_blend_shape_value(i, 1.0 if shapes[i] == s else 0.0)
				return s, 6)
			for i in shapes.size():
				_face.set_blend_shape_value(i, 0.0)
	if only.contains("moods"):
		await _sheet(label + "_moods", ToonFace.MOODS.keys(), func(m):
			_close(head, box)
			for i in shapes.size():
				_face.set_blend_shape_value(i, ToonFace.MOODS[m].get(shapes[i], 0.0))
			return m, 5)
		for i in shapes.size():
			_face.set_blend_shape_value(i, 0.0)
	if only.contains("clips"):
		var ap: AnimationPlayer = _model.find_children("*", "AnimationPlayer", true, false)[0]
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var tiles: Array = []
		for c in (str(_args.clip).split(",") if _args.has("clip") else PackedStringArray()):
			if not ap.has_animation(c):
				print("ERROR no clip called ", c, ". There are: ", ", ".join(ap.get_animation_list()))
				get_tree().quit(1)
				return
		for c in ap.get_animation_list():
			if _args.has("clip") and not str(_args.clip).split(",").has(c):
				continue
			for k in 8:
				tiles.append([c, k / 7.0])
		await _sheet(label + "_clips", tiles, func(t):
			_frame(box, deg_to_rad(float(_args.get("yaw", "20"))))
			ap.play(t[0])
			ap.seek(t[1] * ap.get_animation(t[0]).length * 0.999, true)
			return "%s %.2f" % [t[0], t[1] * ap.get_animation(t[0]).length], 8)
	get_tree().quit()


func _frame(box: AABB, yaw: float) -> void:
	var c := box.get_center()
	var r := maxf(box.size.y, maxf(box.size.x, box.size.z)) * 0.62
	_cam.position = c + Vector3(sin(yaw), 0.10, cos(yaw)) * r / tan(deg_to_rad(14.0)) * 1.15
	_cam.look_at(c)


func _close(head: float, box: AABB) -> void:
	var c := Vector3(0, head, box.get_center().z)
	_cam.position = c + Vector3(0.1, 0.02, 1.0) * maxf(0.4, _face_size) * 0.5 / tan(deg_to_rad(_cam.fov / 2.0)) * 1.1 + Vector3(0, 0, box.size.z * 0.5)
	_cam.look_at(c)


func _sheet(file: String, items, set_up: Callable, columns: int) -> void:
	var rows := ceili(items.size() / float(columns))
	var sheet := Image.create(W * columns, (H + 26) * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color("#2b1633"))
	for i in items.size():
		var text: String = set_up.call(items[i])
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(W, H, Image.INTERPOLATE_LANCZOS)
		var at := Vector2i((i % columns) * W, (i / columns) * (H + 26))
		sheet.blit_rect(img, Rect2i(0, 0, W, H), at)
		sheet.blit_rect(await _text(text), Rect2i(0, 0, W, 26), at + Vector2i(0, H))
	sheet.save_png(_out.path_join(file + ".png"))
	print("SHEET ", _out.path_join(file + ".png"))


var _label_vp: SubViewport
var _label: Label


func _text(t: String) -> Image:
	if _label_vp == null:
		_label_vp = SubViewport.new()
		_label_vp.size = Vector2i(W, 26)
		_label_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_label_vp)
		_label = Label.new()
		_label.size = Vector2(W, 26)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label_vp.add_child(_label)
	_label.text = t
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _label_vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img
