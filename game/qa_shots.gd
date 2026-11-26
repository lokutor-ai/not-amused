extends Node3D
## Stills of every camera shot: godot --path . res://game/qa_shots.tscn -- out=C:/shots [only=play,king] [scene=laugh]


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		args[p[0]] = p[1] if p.size() > 1 else ""
	var out: String = args.get("out", "user://shots")
	DirAccess.make_dir_recursive_absolute(out)
	get_window().borderless = true
	get_window().size = Vector2i(1920, 1080)
	var shots: PackedStringArray = (args.get("only", ",".join(Stage.SHOTS.keys())) as String).split(",")
	for s in shots:
		if not Stage.SHOTS.has(s):
			print("ERROR no shot called ", s, ". There are: ", ", ".join(Stage.SHOTS.keys()))
			get_tree().quit(1)
			return
	var stage := Stage.new()
	add_child(stage)
	if not args.get("scene", "") in ["", "laugh", "hold", "lever"]:
		print("ERROR no scene called ", args.scene, ". There are: laugh, hold, lever")
		get_tree().quit(1)
		return
	match args.get("scene", ""):
		"laugh":
			stage.king.play("belly_laugh")
			stage.king.mood("laugh")
			for g in stage.guards():
				g.play("laugh")
				g.mood("laugh")
			stage.jester.play("win")
			stage.jester.mood("laugh")
		"hold":
			stage.king.play("giggle")
			stage.king.mood("giggle")
			for g in stage.guards():
				g.play("hold_it")
				g.mood("hold")
			stage.jester.play("perform")
		"lever":
			stage.king.play("lever")
			stage.king.mood("angry")
			stage.jester.mood("scared")
			stage.jester.play("nervous")
	for shot in shots:
		stage.rig.go(shot)
		await get_tree().create_timer(float(args.get("wait", "0.9"))).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("shot_%s.png" % shot))
		print("SHOT ", shot)
	get_tree().quit()
