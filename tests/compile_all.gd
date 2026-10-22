extends SceneTree
## Loads every script and resource in the project so parse/compile errors
## surface in one run:  godot --headless --path . -s res://tests/compile_all.gd


func _init() -> void:
	# Autoload names only resolve once the tree is running.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var failures := 0
	for path in _files("res://", ["gd", "tres", "tscn"]):
		if path.begins_with("res://.godot"):
			continue
		var r := load(path)
		if r == null:
			printerr("FAILED: ", path)
			failures += 1
		elif r is GDScript and not r.can_instantiate() and not r.is_abstract():
			printerr("NOT INSTANTIABLE: ", path)
			failures += 1
	print("compile_all: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func _files(dir_path: String, exts: Array) -> Array:
	var out := []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			out.append_array(_files(dir_path.path_join(sub), exts))
	for f in dir.get_files():
		if f.get_extension() in exts:
			out.append(dir_path.path_join(f))
	return out
