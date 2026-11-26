class_name Toon
extends RefCounted
## Turns any imported model into a cel-shaded one: each material keeps its colour and gets the toon shader, and the outline
## where a line belongs. Rules go by material name, so a model made anywhere works if its materials are named by what
## they are.

const SHADER := preload("toon.gdshader")
const OUTLINE := preload("outline.gdshader")

## Looks by the start of the material's name, first match wins. "line": outline width in pixels at 1080p (0 = none).
static var LOOKS := {
	"face_ink": {"flat_colour": 1.0, "line": 0.0}, "face_pupil": {"flat_colour": 1.0, "line": 0.0},
	"face_white": {"flat_colour": 0.85, "line": 0.0, "receive_shadow": 0.0}, "face_teeth": {"flat_colour": 0.85, "line": 0.0, "receive_shadow": 0.0},
	"face_mouth": {"flat_colour": 0.6, "line": 0.0, "receive_shadow": 0.0}, "face_tongue": {"flat_colour": 0.6, "line": 0.0, "receive_shadow": 0.0},
	"face_": {"line": 0.0, "rim": 0.0, "receive_shadow": 0.0, "halftone": 0.0},
	"ink": {"flat_colour": 1.0, "line": 0.0},
	"gold": {"shine": 0.9, "shine_size": 0.4, "rim": 0.4}, "steel": {"shine": 1.6, "shine_size": 0.5, "rim": 0.6}, "armor": {"shine": 0.45, "shine_size": 0.16, "rim": 0.5},
	"helmet": {"shine": 0.5, "shine_size": 0.18, "rim": 0.4}, "gem": {"shine": 2.0, "shine_size": 0.4}, "nose": {"shine": 0.5, "shine_size": 0.35, "receive_shadow": 0.0},
	"flame": {"flat_colour": 1.0, "glow": 1.6, "line": 0.0}, "glow": {"flat_colour": 1.0, "glow": 1.2, "line": 0.0},
	"skin": {"rim": 0.15, "receive_shadow": 0.0}, "fur": {"rim": 0.2, "halftone": 0.5}, "hair": {"halftone": 0.5, "rim": 0.1, "receive_shadow": 0.0},
}

static var _cache := {}


## Applies it to every mesh under `node`. `line`: outline width. `overrides`: {material name: {parameter: value}}.
## `colours`: {material name: colour}, to recolour a model.
static func apply(node: Node, line := 3.0, overrides := {}, colours := {}) -> void:
	for mesh in node.find_children("*", "MeshInstance3D", true, false) + ([node] if node is MeshInstance3D else []):
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var old: Material = mesh.get_active_material(i)
			var label: String = old.resource_name if old else "plain"
			var colour := (old as BaseMaterial3D).albedo_color if old is BaseMaterial3D else Color.WHITE
			mesh.set_surface_override_material(i, material(label, colours.get(label, colour), line, overrides.get(label, {})))


## The toon material for a thing called `label`.
static func material(label: String, colour: Color, line := 3.0, extra := {}) -> ShaderMaterial:
	var key := "%s|%s|%.2f|%s" % [label, colour.to_html(), line, extra]
	if _cache.has(key):
		return _cache[key]
	var look := {}
	for prefix in LOOKS:
		if label.begins_with(prefix):
			look = LOOKS[prefix].duplicate()
			break
	look.merge(extra, true)
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.resource_name = label
	m.set_shader_parameter("albedo", colour)
	for p in look:
		if p != "line":
			m.set_shader_parameter(p, look[p])
	var width: float = look.get("line", line)
	if width > 0.0:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE
		o.set_shader_parameter("width", width)
		o.set_shader_parameter("ink", Color("#2b1633").lerp(colour.darkened(0.6), 0.45))
		m.next_pass = o
	_cache[key] = m
	return m


# ---- Fewer draw calls ---------------------------------------------------------------------------------------------------

## The look values each vertex carries once Toon.batch has packed its surface with others: CUSTOM0 and CUSTOM1 in the
## shaders, four each, in this order ("line" is the outline's width).
const PACKED := ["flat_colour", "receive_shadow", "rim", "halftone", "shine", "shine_size", "glow", "line"]
const _CUSTOM := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)

static var _packed := {}


## True where draw calls cost most: the Compatibility renderer (WebGL 2 in a browser, and old GPUs). There each surface is
## a draw call, two with its outline, and each surface of a skinned mesh is reworked on the GPU every frame, once more for
## each face shape that is not at rest, so a character in thirty surfaces weighs far more than one in a few.
static func few_draws() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


## Puts the toon surfaces under `root` together: the same picture in far fewer draw calls. Each vertex takes its colour
## and its look (PACKED) along, so surfaces that differ only in those become one. A skinned or shaped mesh keeps its node
## (its skeleton and face shapes work as before), in one surface; still meshes become one new mesh (two: with and without
## shadows), a child of `root`, and lose theirs. `skip`: nodes (and what hangs from them) left as they are, because they
## move or come and go.
static func batch(root: Node3D, skip: Array = []) -> void:
	var still: Array[MeshInstance3D] = []
	for mi in _meshes(root, skip):
		if mi.skin != null or (mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).get_blend_shape_count() > 0):
			_merge_own(mi)
		elif range(mi.mesh.get_surface_count()).all(func(s): return _toon(mi.get_active_material(s))):
			still.append(mi)
	if still.size() > 1:
		_merge_still(root, still)


static func _meshes(n: Node, skip: Array) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if skip.has(n) or (n is Node3D and not (n as Node3D).visible):
		return out
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c, skip))
	return out


static func _toon(m: Material) -> bool:
	return m is ShaderMaterial and (m as ShaderMaterial).shader == SHADER


## What surfaces packed together must share: the toon values that stay in the material.
static func _key(m: ShaderMaterial) -> String:
	var k := ""
	for u in SHADER.get_shader_uniform_list():
		if u.name != "albedo" and u.name != "packed" and not PACKED.has(u.name):
			var v = m.get_shader_parameter(u.name)
			k += "%s=%s;" % [u.name, str((v as Object).get_instance_id()) if v is Object else str(v)]
	return k


## One of `m`'s look values, or the shader's default.
static func _value(m: ShaderMaterial, what: String) -> float:
	if what == "line":
		return m.next_pass.get_shader_parameter("width") if m.next_pass else 0.0
	var v = m.get_shader_parameter(what)
	return v if v != null else RenderingServer.shader_get_parameter_default(SHADER.get_rid(), what)


## The material of the surfaces packed under `key`: `m`'s, with the outline if any of them has one.
static func _packed_material(m: ShaderMaterial, key: String, line: bool) -> ShaderMaterial:
	key += "|line=%s" % line
	if not _packed.has(key):
		var p := ShaderMaterial.new()
		p.shader = SHADER
		p.resource_name = "packed"
		for u in SHADER.get_shader_uniform_list():
			var v = m.get_shader_parameter(u.name)
			if v != null and u.name != "albedo" and not PACKED.has(u.name):
				p.set_shader_parameter(u.name, v)
		p.set_shader_parameter("packed", true)
		if line:
			var o := ShaderMaterial.new()
			o.shader = OUTLINE
			o.set_shader_parameter("packed", true)
			p.next_pass = o
		_packed[key] = p
	return _packed[key]


## A surface's arrays with its material in its vertices: the colour (albedo times the vertex tint, as much as
## flat_colour lets it, in sRGB as vertex colours are kept) and the look (PACKED).
static func _pack(arrays: Array, m: ShaderMaterial) -> void:
	var n := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	arrays[Mesh.ARRAY_COLOR] = _colours(arrays, m)
	for c in 2:
		var look := PackedFloat32Array()
		for i in 4:
			look.append(_value(m, PACKED[4 * c + i]))
		while look.size() < 4 * n:                   # doubled until it covers every vertex
			look.append_array(look)
		look.resize(4 * n)
		arrays[Mesh.ARRAY_CUSTOM0 + c] = look


## A surface's colours as the packed shader reads them.
static func _colours(arrays: Array, m: ShaderMaterial) -> PackedColorArray:
	var n := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var a: Color = m.get_shader_parameter("albedo")
	a = a.srgb_to_linear()
	var flat := _value(m, "flat_colour")
	var tint = arrays[Mesh.ARRAY_COLOR]
	var out := PackedColorArray()
	out.resize(n)
	if tint == null or (tint as PackedColorArray).is_empty() or flat >= 1.0:
		out.fill(Color(a.r, a.g, a.b).linear_to_srgb())
		return out
	for i in n:
		var t: Color = (tint[i] as Color).srgb_to_linear()
		out[i] = Color(a.r * lerpf(t.r, 1.0, flat), a.g * lerpf(t.g, 1.0, flat), a.b * lerpf(t.b, 1.0, flat)).linear_to_srgb()
	return out


## An empty array of the type a mesh array `kind` has.
static func _empty(kind: int):
	match kind:
		Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL:
			return PackedVector3Array()
		Mesh.ARRAY_TEX_UV:
			return PackedVector2Array()
		Mesh.ARRAY_COLOR:
			return PackedColorArray()
		Mesh.ARRAY_BONES:
			return PackedInt32Array()
	return PackedFloat32Array()


## Surfaces ([arrays, face shapes] each) one after the other in one: vertex arrays joined, indices moved along.
## Tangents go (the toon shaders use none); an array that some surfaces lack is filled in for them.
static func _join(parts: Array) -> Array:
	var kinds := [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_COLOR, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS,
			Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var per_bone := 0
	for p in parts:
		var w = p[0][Mesh.ARRAY_WEIGHTS]
		if w != null and w.size() > 0:
			per_bone = w.size() / (p[0][Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for k in kinds:
		if parts.any(func(q): return q[0][k] != null and q[0][k].size() > 0):
			out[k] = _empty(k)
	var index := PackedInt32Array()
	var base := 0
	for p in parts:
		var arrays: Array = p[0]
		var n := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		for k in kinds:
			if out[k] == null:
				continue
			var have = arrays[k]
			if have != null and have.size() > 0:
				out[k].append_array(have)
				continue
			var count := n * (per_bone if k == Mesh.ARRAY_BONES or k == Mesh.ARRAY_WEIGHTS else 4 if k >= Mesh.ARRAY_CUSTOM0 else 1)
			if k == Mesh.ARRAY_COLOR:
				var white := PackedColorArray()
				white.resize(count)
				white.fill(Color.WHITE)
				out[k].append_array(white)
			elif k == Mesh.ARRAY_NORMAL:
				var up := PackedVector3Array()
				up.resize(count)
				up.fill(Vector3.UP)
				out[k].append_array(up)
			else:
				var zero = _empty(k)
				zero.resize(count)
				out[k].append_array(zero)
		var idx = arrays[Mesh.ARRAY_INDEX]
		var moved := PackedInt32Array(range(n)) if idx == null or (idx as PackedInt32Array).is_empty() else PackedInt32Array(idx)
		if base > 0:
			for i in moved.size():
				moved[i] += base
		index.append_array(moved)
		base += n
	out[Mesh.ARRAY_INDEX] = index
	var shapes := []
	for b in (parts[0][1] as Array).size():
		var s := []
		s.resize(Mesh.ARRAY_MAX)
		s[Mesh.ARRAY_VERTEX] = PackedVector3Array()
		s[Mesh.ARRAY_NORMAL] = PackedVector3Array()
		for p in parts:
			s[Mesh.ARRAY_VERTEX].append_array(p[1][b][Mesh.ARRAY_VERTEX])
			s[Mesh.ARRAY_NORMAL].append_array(p[1][b][Mesh.ARRAY_NORMAL])
		shapes.append(s)
	return [out, shapes]


## A skinned or shaped mesh with its toon surfaces packed into one, in place (one per kind of skinning).
static func _merge_own(mi: MeshInstance3D) -> void:
	var src := mi.mesh as ArrayMesh
	if src == null or src.get_surface_count() < 2:
		return
	var groups := {}
	for s in src.get_surface_count():
		var m := mi.get_active_material(s)
		var key := (_key(m) + "|%d" % (src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)) if _toon(m) else "own%d" % s
		(groups.get_or_add(key, []) as Array).append(s)
	if groups.size() == src.get_surface_count():
		return
	var out := ArrayMesh.new()
	out.blend_shape_mode = src.blend_shape_mode
	for b in src.get_blend_shape_count():
		out.add_blend_shape(src.get_blend_shape_name(b))
	var materials: Array[Material] = []
	for key in groups:
		var first: int = groups[key][0]
		var fm := mi.get_active_material(first)
		var flags := src.surface_get_format(first) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		if not _toon(fm):                              # as it was
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(first), src.surface_get_blend_shape_arrays(first), {}, flags)
			materials.append(fm)
			continue
		var parts := []
		var line := false
		for s in groups[key]:
			var arrays := src.surface_get_arrays(s)
			var m := mi.get_active_material(s) as ShaderMaterial
			_pack(arrays, m)
			line = line or _value(m, "line") > 0.0
			parts.append([arrays, src.surface_get_blend_shape_arrays(s)])
		var joined := _join(parts)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, joined[0], joined[1], {}, flags | _CUSTOM)
		materials.append(_packed_material(fm, key, line))
	mi.material_override = null
	mi.mesh = out
	for s in out.get_surface_count():
		mi.set_surface_override_material(s, null)
		out.surface_set_material(s, materials[s])


## Still meshes packed into new meshes under `root`: one per set of toon values that stay in the material, and per
## whether they cast shadows.
static func _merge_still(root: Node3D, meshes: Array[MeshInstance3D]) -> void:
	var inv := root.global_transform.affine_inverse()
	var groups := {}
	for mi in meshes:
		var to_root := inv * mi.global_transform
		var normals := Transform3D(to_root.basis.inverse().transposed(), Vector3.ZERO)
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as ShaderMaterial
			var key := "%s|%d" % [_key(m), mi.cast_shadow]
			var arrays := mi.mesh.surface_get_arrays(s)
			arrays[Mesh.ARRAY_VERTEX] = to_root * (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			if arrays[Mesh.ARRAY_NORMAL] != null:
				arrays[Mesh.ARRAY_NORMAL] = normals * (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)
			_pack(arrays, m)
			var g: Array = groups.get_or_add(key, [m, mi.cast_shadow, [], false])
			(g[2] as Array).append([arrays, []])
			g[3] = g[3] or _value(m, "line") > 0.0
		mi.mesh = null
	var by_shadow := {}
	for key in groups:
		var g: Array = groups[key]
		if not by_shadow.has(g[1]):
			var put := MeshInstance3D.new()
			put.name = "Batched"
			put.mesh = ArrayMesh.new()
			put.cast_shadow = g[1]
			root.add_child(put)
			by_shadow[g[1]] = put
		var mesh: ArrayMesh = by_shadow[g[1]].mesh
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _join(g[2])[0], [], {}, _CUSTOM)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _packed_material(g[0], key, g[3]))
