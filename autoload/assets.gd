extends Node
## Asset registry. Gameplay code never uses texture paths directly: it asks
## for stable ids (e.g. "enemy.infantry") which res://assets/asset_manifest.json
## maps to files and sheet layouts. Unknown or not-yet-generated assets return
## null, and callers fall back to placeholders.

const MANIFEST_PATH := "res://assets/asset_manifest.json"

var show_placeholder_labels := true
var _entries := {}
var _textures := {}
var _frames := {}
var _missing := {}
var _rig_info := {}


func _ready() -> void:
	reload()


func reload() -> void:
	_entries.clear()
	_textures.clear()
	_frames.clear()
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("Asset manifest missing: %s" % MANIFEST_PATH)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if typeof(data) != TYPE_DICTIONARY or not data.has("assets"):
		push_error("Asset manifest is not valid JSON with an \"assets\" object.")
		return
	_entries = data.assets


func get_entry(id: StringName) -> Dictionary:
	return _entries.get(String(id), {}) if id != &"" else {}


func all_ids() -> Array:
	return _entries.keys()


## True when the id is declared and its file can be loaded.
func is_available(id: StringName) -> bool:
	return get_texture(id) != null or get_stream(id) != null


func get_texture(id: StringName) -> Texture2D:
	if id == &"":
		return null
	if _textures.has(id):
		return _textures[id]
	var tex: Texture2D = null
	var path: String = get_entry(id).get("path", "")
	if path != "" and not path.get_extension().to_lower() in ["ogg", "wav", "mp3"]:
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
		elif FileAccess.file_exists(path):
			# Freshly dropped files that the editor has not imported yet.
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img:
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
	_textures[id] = tex
	return tex


func get_stream(id: StringName) -> AudioStream:
	var path: String = get_entry(id).get("path", "")
	if path != "" and ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null


func frame_size(id: StringName) -> Vector2:
	var e := get_entry(id)
	if e.has("frame_size"):
		return Vector2(e.frame_size[0], e.frame_size[1])
	var tex := get_texture(id)
	return tex.get_size() if tex else Vector2.ONE


## Scale that fits source art into the requested world size.
func fit_scale(id: StringName, world_size: Vector2, source_size: Vector2) -> float:
	var e := get_entry(id)
	if e.has("scale"):
		return float(e.scale)
	match e.get("fit", "height"):
		"width":
			return world_size.x / maxf(source_size.x, 1.0)
		"contain":
			return minf(world_size.x / maxf(source_size.x, 1.0), world_size.y / maxf(source_size.y, 1.0))
		_:
			return world_size.y / maxf(source_size.y, 1.0)


## "filter": "nearest" keeps hard pixel edges (painted pixel-art backgrounds
## shown at whole-number scales). Default: smooth with mipmaps.
func texture_filter(id: StringName) -> CanvasItem.TextureFilter:
	if get_entry(id).get("filter", "") == "nearest":
		return CanvasItem.TEXTURE_FILTER_NEAREST
	return CanvasItem.TEXTURE_FILTER_PARENT_NODE


func entry_offset(id: StringName) -> Vector2:
	var o = get_entry(id).get("offset", [0, 0])
	return Vector2(o[0], o[1])


## Builds SpriteFrames for a "sheet" entry. Animations are rows (or runs of
## frames) in a uniform grid: {"run": {"row": 1, "start": 0, "frames": 6, "fps": 12}}.
func get_sprite_frames(id: StringName) -> SpriteFrames:
	if _frames.has(id):
		return _frames[id]
	var tex := get_texture(id)
	var e := get_entry(id)
	var result: SpriteFrames = null
	if tex and e.has("frame_size"):
		result = SpriteFrames.new()
		result.remove_animation("default")
		var fs := Vector2(e.frame_size[0], e.frame_size[1])
		var columns := int(tex.get_width() / fs.x)
		var anims: Dictionary = e.get("animations", {"idle": {"row": 0, "frames": columns}})
		for anim_name in anims:
			var a: Dictionary = anims[anim_name]
			result.add_animation(anim_name)
			result.set_animation_speed(anim_name, a.get("fps", 10))
			result.set_animation_loop(anim_name, a.get("loop", true))
			var start := int(a.get("start", 0))
			for i in int(a.get("frames", 1)):
				var idx := start + i
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(Vector2(idx % columns, int(a.get("row", 0)) + idx / columns) * fs, fs)
				result.add_frame(anim_name, at)
	_frames[id] = result
	return result


## Named tile coordinates for a "tiles" entry: {"ground_top": [0, 0], ...}.
func tile_coords(id: StringName) -> Dictionary:
	return get_entry(id).get("tiles", {})


## Hip/leg analysis for a "biped" rig, cached per asset.
func rig_info(id: StringName, tex: Texture2D, region: Rect2) -> Dictionary:
	if not _rig_info.has(id):
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		img = img.get_region(Rect2i(region))
		_rig_info[id] = CutoutRig.analyze(img)
	return _rig_info[id]


func report_missing(id: StringName) -> void:
	if id != &"":
		_missing[id] = true


func missing_ids() -> Array:
	return _missing.keys()
