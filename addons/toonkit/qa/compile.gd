extends SceneTree
## Compiles every script and shader of the game, and says which do not.
##   godot --headless --path <game> --script res://addons/toonkit/qa/compile.gd


func _initialize() -> void:
	var found: Array[String] = []
	_walk("res://", found)
	var bad := 0
	for path in found:
		var loaded: Resource = load(path)
		var code := loaded as GDScript
		if loaded == null or (code != null and not code.can_instantiate() and not code.is_abstract()):
			bad += 1
			print("ERROR ", path, " does not compile")
	print("COMPILED %d files, %d do not compile" % [found.size(), bad])
	quit(1 if bad else 0)


func _walk(folder: String, found: Array[String]) -> void:
	for f in DirAccess.get_files_at(folder):
		if f.get_extension() in ["gd", "gdshader", "tscn"] and not folder.path_join(f) == get_script().resource_path:
			found.append(folder.path_join(f))
	for d in DirAccess.get_directories_at(folder):
		if not d.begins_with(".") and not FileAccess.file_exists(folder.path_join(d).path_join(".gdignore")):
			_walk(folder.path_join(d), found)
