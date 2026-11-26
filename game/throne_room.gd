class_name ThroneRoom
extends Node3D
## The set: props from props.glb in toon colours, a tiled floor with a hole in it, light, dust and candles.

const TRAP := Vector3(0, 0, 4.9)
const SEAT := Vector3(0, 1.48, 0)

var leaf_l: Node3D
var leaf_r: Node3D
var lever: Node3D
var back: Node3D
var sun: DirectionalLight3D
var _flames: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []
var _time := 0.0
var _kit: Node3D


func _ready() -> void:
	_kit = (load("res://assets/props.glb") as PackedScene).instantiate()
	_light()
	_floor()
	_put("throne", SEAT)
	_put("dais", Vector3.ZERO)
	_put("wall", Vector3.ZERO, 0.0, 0.0)
	_ceiling()
	_back()
	for a in [0.0, -58.0, 58.0]:
		var r := deg_to_rad(a)
		_put("bunting", Vector3(5.6 * sin(r), 5.35, 3.2 - 5.6 * cos(r)), -a, 2.0)
	for a in [-72.0, -38.0, 38.0, 72.0]:
		_wall("window", a, 1.75)
	for a in [-55.0, -19.5, 19.5, 55.0]:
		_wall("banner", a, 4.65)
	for a in [-88.0, -29.0, 29.0, 88.0]:
		_wall("column", a, 0.0, 0.85)
	for x in [-1.0, 1.0]:
		_candles(Vector3(4.15 * x, 0.0, 0.2), -14.0 * x)
		_candles(Vector3(5.3 * x, 0.0, 4.2), -40.0 * x)
	for z in [[2.75, 3.3, 0.2], [2.2, 2.75, 0.4], [0.9, 2.2, 0.6]]:
		_rug(Vector3(0, z[2] + 0.015, (z[0] + z[1]) / 2.0), Vector2(1.9, z[1] - z[0] + 0.06))
		_rug(Vector3(0, z[2] - 0.09, z[1] + 0.022), Vector2(1.9, 0.03), 0.21)
	_rug(Vector3(0, 0.015, 3.66), Vector2(1.9, 0.72))
	_rug(Vector3(0, 0.015, 8.4), Vector2(1.9, 5.2))
	leaf_l = _put("leaf_l", TRAP + Vector3(-0.745, 0.0, 0))
	leaf_r = _put("leaf_r", TRAP + Vector3(0.745, 0.0, 0))
	_put("trap_frame", TRAP)
	_put("shaft", TRAP + Vector3(0, -0.02, 0), 0.0, 0.0)
	_put("lever_base", Vector3(-1.62, 0.6, 0.62))
	lever = _put("lever_arm", Vector3(-1.62, 1.42, 0.62))
	_dust()


## The half of the room behind the player. Only there when the camera looks that way.
func _back() -> void:
	back = Node3D.new()
	add_child(back)
	var made := get_child_count()
	_put("wall", Vector3(0, 0, 6.4), 180.0, 0.0)
	_put("door", Vector3(0, 0, 10.2), 180.0)
	for x in [-1.0, 1.0]:
		_put("column", Vector3(2.5 * x, 0, 9.4))
		_put("banner", Vector3(4.2 * x, 4.65, 9.05), 180.0 + 37.0 * x)
		_put("bunting", Vector3(2.4 * x, 5.2, 7.2), 180.0 + 35.0 * x, 2.0)
	for c in get_children().slice(made):
		c.reparent(back)
	back.visible = false


func _ceiling() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 11.0
	disc.bottom_radius = 11.0
	disc.height = 0.1
	var m := MeshInstance3D.new()
	m.mesh = disc
	m.position = Vector3(0, 5.8, 3.2)
	m.material_override = Toon.material("ceiling", Color("#2f5366"), 0.0, {"rim": 0.0})
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	for i in 7:
		var beam := BoxMesh.new()
		beam.size = Vector3(0.34, 0.3, 16.0)
		var b := MeshInstance3D.new()
		b.mesh = beam
		b.position = Vector3(-7.2 + i * 2.4, 5.65, 3.2)
		b.material_override = Toon.material("wood", Color("#8a4f2a"), 0.0)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(b)


func _put(prop: String, at: Vector3, turn := 0.0, line := 3.2) -> MeshInstance3D:
	var m: MeshInstance3D = (_kit.find_child(prop, true, false) as MeshInstance3D).duplicate()
	add_child(m)
	m.position = at
	m.rotation_degrees = Vector3(0, turn, 0)
	Toon.apply(m, line)
	return m


## On the curved wall, `angle` degrees round from the middle.
func _wall(prop: String, angle: float, y: float, inset := 0.16) -> void:
	var a := deg_to_rad(angle)
	var r := 7.2 - inset
	_put(prop, Vector3(r * sin(a), y, 3.2 - r * cos(a)), -angle)


func _candles(at: Vector3, turn: float) -> void:
	_put("candelabrum", at, turn, 2.6)
	for x in [-0.42, 0.0, 0.42]:
		_flames.append(_put("flame", at + Vector3(x, 1.95, 0).rotated(Vector3.UP, deg_to_rad(turn))))
	var l := OmniLight3D.new()
	l.light_color = Color("#ffb347")
	l.light_energy = 0.9
	l.omni_range = 3.4
	l.position = at + Vector3(0, 2.2, 0)
	add_child(l)
	_lights.append(l)


func _rug(at: Vector3, size: Vector2, height := 0.03) -> void:
	for part in [["carpet", Color("#c2233a"), size.x, 0.0], ["carpet_edge", Color("#ffc52e"), 0.11, -0.82], ["carpet_edge", Color("#ffc52e"), 0.11, 0.82]]:
		var box := BoxMesh.new()
		box.size = Vector3(part[2], height + (0.006 if part[3] else 0.0), size.y + (0.004 if part[3] else 0.0))
		var m := MeshInstance3D.new()
		m.mesh = box
		m.position = at + Vector3(part[3], 0, 0)
		m.material_override = Toon.material(part[0], part[1], 0.0, {"rim": 0.0})
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)


func _floor() -> void:
	# Two-tone tiles with soft seams, drawn once into a small texture.
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var a := Color("#d9b48f")
	var b := Color("#c49a7a")
	var seam := Color("#9c7560")
	for y in n:
		for x in n:
			var tile := a if (x < n / 2) == (y < n / 2) else b
			var d := mini(mini(x % (n / 2), n / 2 - 1 - x % (n / 2)), mini(y % (n / 2), n / 2 - 1 - y % (n / 2)))
			img.set_pixel(x, y, seam if d < 2 else tile)
	img.generate_mipmaps()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.745
	for r in [[-9.0, 9.0, -6.0, TRAP.z - h], [-9.0, 9.0, TRAP.z + h, 14.0], [-9.0, -h, TRAP.z - h, TRAP.z + h], [h, 9.0, TRAP.z - h, TRAP.z + h]]:
		for p in [Vector2(r[0], r[2]), Vector2(r[1], r[2]), Vector2(r[1], r[3]), Vector2(r[0], r[2]), Vector2(r[1], r[3]), Vector2(r[0], r[3])]:
			st.set_normal(Vector3.UP)
			st.set_color(Color.WHITE)
			st.set_uv(p / 2.2 + Vector2(0.25, 0.0))
			st.add_vertex(Vector3(p.x, 0, p.y))
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = Toon.material("floor", Color.WHITE, 0.0, {"paint": ImageTexture.create_from_image(img), "rim": 0.0, "halftone": 0.0})
	add_child(m)


func _light() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2a1633")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9a86c8")
	env.ambient_light_energy = 0.62
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.25
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.03
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, 34, 0)
	sun.light_color = Color("#fff1d8")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.shadow_normal_bias = 2.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 18.0
	sun.shadow_blur = 0.6
	add_child(sun)


func _dust() -> void:
	var p := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(5, 2.2, 4)
	mat.gravity = Vector3(0, 0.015, 0)
	mat.initial_velocity_min = 0.02
	mat.initial_velocity_max = 0.09
	mat.spread = 180.0
	mat.scale_min = 0.4
	mat.scale_max = 1.0
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 0.9, 0.6, 0), Color(1, 0.9, 0.6, 0.5), Color(1, 0.9, 0.6, 0)])
	fade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	mat.color_ramp = ramp
	p.process_material = mat
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.025)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	var disc := Gradient.new()
	disc.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	disc.offsets = PackedFloat32Array([0.55, 1.0])
	var dot := GradientTexture2D.new()
	dot.gradient = disc
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	sm.albedo_texture = dot
	q.material = sm
	p.draw_pass_1 = q
	p.amount = 90
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = Vector3(0, 2.2, 2.5)
	add_child(p)


func open_trap() -> void:
	for leaf in [[leaf_l, -1.0], [leaf_r, 1.0]]:
		var t := create_tween()
		t.tween_property(leaf[0], "rotation_degrees:z", 100.0 * leaf[1], 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(leaf[0], "rotation_degrees:z", 78.0 * leaf[1], 0.16)
		t.tween_property(leaf[0], "rotation_degrees:z", 92.0 * leaf[1], 0.20)
		t.tween_property(leaf[0], "rotation_degrees:z", 88.0 * leaf[1], 0.18)


func close_trap() -> void:
	for leaf in [leaf_l, leaf_r]:
		create_tween().tween_property(leaf, "rotation_degrees:z", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func pull_lever() -> void:
	var t := create_tween()
	t.tween_property(lever, "rotation_degrees:x", 70.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.6)
	t.tween_property(lever, "rotation_degrees:x", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	for i in _flames.size():
		var w := sin(_time * 9.0 + i * 2.1) * 0.5 + sin(_time * 14.3 + i) * 0.5
		_flames[i].scale = Vector3(1.0 - 0.08 * w, 1.0 + 0.16 * w, 1.0 - 0.08 * w)
		_flames[i].rotation.z = 0.08 * sin(_time * 5.0 + i * 1.7)
	for i in _lights.size():
		_lights[i].light_energy = 0.85 + 0.12 * sin(_time * 8.0 + i * 1.3) + 0.06 * sin(_time * 17.0 + i)
