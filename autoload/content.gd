extends Node
## Indexes every resource under res://content by class and id, so layouts and
## tools can refer to content by name ("enemy:sniper", "pickup:spread").

const ROOT := "res://content"

var _by_type := {}


func _ready() -> void:
	_scan(ROOT)


func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan(dir_path.path_join(sub))
	for file in dir.get_files():
		file = file.trim_suffix(".remap")
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var res := load(dir_path.path_join(file))
		if res == null or res.get_script() == null or not ("id" in res):
			continue
		var type: String = res.get_script().get_global_name()
		if not _by_type.has(type):
			_by_type[type] = {}
		_by_type[type][String(res.id)] = res


func get_def(type: String, id: String) -> Resource:
	return _by_type.get(type, {}).get(id)


func all_of(type: String) -> Array:
	return _by_type.get(type, {}).values()


func enemy(id: String) -> EnemyDef:
	return get_def("EnemyDef", id)


func pickup(id: String) -> PickupDef:
	return get_def("PickupDef", id)


func boss(id: String) -> BossDef:
	return get_def("BossDef", id)
