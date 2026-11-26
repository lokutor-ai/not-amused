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
