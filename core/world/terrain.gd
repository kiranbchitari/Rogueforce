class_name Terrain
extends Node2D
## Gameplay geometry built from an ASCII layout. Collision comes only from
## this grid, never from background art, so the same layout can be reskinned
## by any environment and any art can sit behind any layout.

## Symbols every mission understands. Missions add their own via MissionDef.legend.
const BASE_LEGEND := {
	"#": "solid", "%": "block", "=": "platform", "^": "spikes", "~": "liquid",
	"P": "player", "C": "checkpoint", "B": "boss", "E": "exit", "*": "prop",
}
const EMPTY := ". "
## Placeholder tiles are drawn at this multiple of world size so they stay crisp on 4K.
const PLACEHOLDER_SCALE := 4

var rows := 0
var cols := 0
var size_px := Vector2.ZERO
## [{symbol, meaning, cell: Vector2i, center: Vector2, foot: Vector2}]
var markers: Array[Dictionary] = []
## [{rect: Rect2, def: HazardDef}]
var hazards: Array[Dictionary] = []
var tile_layer: TileMapLayer

var _grid: PackedStringArray = []
var _kinds := {}


func build(text: String, legend: Dictionary, env: EnvironmentDef, rng: RandomNumberGenerator) -> void:
	var lines := text.replace("\r", "").split("\n")
	while lines.size() > 0 and lines[lines.size() - 1].strip_edges() == "":
		lines.remove_at(lines.size() - 1)
	rows = lines.size()
	for l in lines:
		cols = maxi(cols, l.length())
	for l in lines:
		_grid.append(l.rpad(cols, "."))
	size_px = Vector2(cols, rows) * RF.TILE
	var full_legend := BASE_LEGEND.duplicate()
	full_legend.merge(legend, true)
	for y in rows:
		for x in cols:
			var ch := _grid[y][x]
			if EMPTY.contains(ch):
				continue
			var meaning: String = full_legend.get(ch, "")
			if meaning == "" and ch.is_valid_int():
				meaning = "trigger:%d" % (int(ch) - 1)
			if meaning == "":
				push_warning("Layout symbol '%s' at %d,%d is not in the legend." % [ch, x, y])
				continue
			_kinds[Vector2i(x, y)] = meaning
			if not meaning in ["solid", "block", "platform", "spikes", "liquid"]:
				markers.append({
					"symbol": ch, "meaning": meaning, "cell": Vector2i(x, y),
					"center": (Vector2(x, y) + Vector2(0.5, 0.5)) * RF.TILE,
					"foot": Vector2(x + 0.5, y + 1) * RF.TILE,
				})
	_build_tiles(env)
	_build_hazards(env)
	_decorate(env, rng)


# --- Queries --------------------------------------------------------------

func kind_at_cell(c: Vector2i) -> String:
	return _kinds.get(c, "")


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / RF.TILE), floori(p.y / RF.TILE))


func is_solid_at(p: Vector2) -> bool:
	var k := kind_at_cell(cell_of(p))
	return k == "solid" or k == "block"


func is_platform_at(p: Vector2) -> bool:
	return kind_at_cell(cell_of(p)) == "platform"


func is_ground_at(p: Vector2) -> bool:
	return is_solid_at(p) or is_platform_at(p)


func blocks_projectile(p: Vector2, include_platforms: bool) -> bool:
	if is_solid_at(p):
		return true
	return include_platforms and is_platform_at(p) and fposmod(p.y, RF.TILE) < RF.TILE * 0.3


## Top of the first ground cell at or below from_y. Returns below the level if none.
func ground_y_at(x: float, from_y: float) -> float:
	var cx := floori(x / RF.TILE)
	for y in range(maxi(floori(from_y / RF.TILE), 0), rows):
		var k := kind_at_cell(Vector2i(cx, y))
		if k == "solid" or k == "block" or k == "platform":
			return y * RF.TILE
	return size_px.y + 400.0


func hazard_at(r: Rect2) -> HazardDef:
	for h in hazards:
		if h.rect.intersects(r):
			return h.def
	return null


# --- Building ---------------------------------------------------------------

func _build_tiles(env: EnvironmentDef) -> void:
	var tile_px := RF.TILE
	var margin := 0
	var separation := 0
	var coords := {}
	var tex := Assets.get_texture(env.tileset_asset_id)
	var entry := Assets.get_entry(env.tileset_asset_id)
	if tex and entry.get("type", "") == "tiles":
		tile_px = int(entry.get("tile_size", [RF.TILE])[0])
		# Gutters between tiles stop mipmaps bleeding neighbours into each other.
		margin = int(entry.get("margin", 0))
		separation = int(entry.get("separation", 0))
		for k in Assets.tile_coords(env.tileset_asset_id):
			var c: Array = Assets.tile_coords(env.tileset_asset_id)[k]
			coords[k] = Vector2i(c[0], c[1])
	else:
		Assets.report_missing(env.tileset_asset_id)
		tex = _placeholder_atlas(env)
		tile_px = RF.TILE * PLACEHOLDER_SCALE
		coords = {"ground_top": Vector2i(0, 0), "ground_fill": Vector2i(1, 0), "platform": Vector2i(2, 0), "block": Vector2i(3, 0)}
	for required in ["ground_top", "ground_fill", "platform", "block"]:
		if not coords.has(required):
			coords[required] = coords.get("ground_fill", Vector2i.ZERO)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile_px, tile_px)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, RF.LAYER_WORLD)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, RF.LAYER_PLATFORM)
	ts.set_physics_layer_collision_mask(1, 0)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(tile_px, tile_px)
	src.margins = Vector2i(margin, margin)
	src.separation = Vector2i(separation, separation)
	ts.add_source(src, 0)
	var h := tile_px * 0.5
	for k in coords:
		var c: Vector2i = coords[k]
		if src.has_tile(c):
			continue
		src.create_tile(c)
		var td := src.get_tile_data(c, 0)
		if k == "platform":
			td.add_collision_polygon(1)
			td.set_collision_polygon_points(1, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, -h * 0.5), Vector2(-h, -h * 0.5)]))
			td.set_collision_polygon_one_way(1, 0, true)
		else:
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))

	tile_layer = TileMapLayer.new()
	tile_layer.tile_set = ts
	tile_layer.scale = Vector2.ONE * RF.TILE / float(tile_px)
	add_child(tile_layer)
	for cell in _kinds:
		var k: String = _kinds[cell]
		var name := ""
		match k:
			"solid":
				var above := kind_at_cell(cell + Vector2i.UP)
				name = "ground_fill" if above == "solid" or above == "block" else "ground_top"
			"block":
				name = "block"
			"platform":
				name = "platform"
		if name != "":
			tile_layer.set_cell(cell, 0, coords[name])


func _placeholder_atlas(env: EnvironmentDef) -> Texture2D:
	var t := RF.TILE
	var img := Image.create(t * 4, t, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(env.id)
	# ground_top, ground_fill, platform, block
	var fills := [env.ground_color, env.ground_color, env.platform_color, env.block_color]
	for i in 4:
		var x0 := i * t
		img.fill_rect(Rect2i(x0, 0, t, t), fills[i])
		for n in 60:
			var c: Color = fills[i].darkened(rng.randf_range(0.05, 0.25)) if rng.randf() < 0.6 else fills[i].lightened(0.1)
			img.fill_rect(Rect2i(x0 + rng.randi_range(0, t - 4), rng.randi_range(0, t - 4), rng.randi_range(2, 5), rng.randi_range(2, 4)), c)
	img.fill_rect(Rect2i(0, 0, t, 14), env.ground_top_color)
	img.fill_rect(Rect2i(0, 14, t, 3), env.ground_top_color.darkened(0.4))
	for n in 10:
		img.fill_rect(Rect2i(rng.randi_range(0, t - 3), 14, 3, rng.randi_range(3, 9)), env.ground_top_color.darkened(0.15))
	# Platform: plank strip with transparent lower part so one-way platforms read clearly.
	img.fill_rect(Rect2i(2 * t, t / 2, t, t / 2), Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(2 * t, 0, t, 4), env.platform_color.lightened(0.3))
	img.fill_rect(Rect2i(2 * t, t / 2 - 4, t, 4), env.platform_color.darkened(0.4))
	img.fill_rect(Rect2i(2 * t + 6, t / 2, 6, t / 2), env.platform_color.darkened(0.3))
	img.fill_rect(Rect2i(3 * t - 12, t / 2, 6, t / 2), env.platform_color.darkened(0.3))
	# Block: bevelled panel.
	img.fill_rect(Rect2i(3 * t, 0, t, 3), env.block_color.lightened(0.3))
	img.fill_rect(Rect2i(3 * t, t - 3, t, 3), env.block_color.darkened(0.4))
	img.fill_rect(Rect2i(3 * t, 0, 3, t), env.block_color.lightened(0.2))
	img.fill_rect(Rect2i(4 * t - 3, 0, 3, t), env.block_color.darkened(0.3))
	img.resize(img.get_width() * PLACEHOLDER_SCALE, img.get_height() * PLACEHOLDER_SCALE, Image.INTERPOLATE_NEAREST)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _build_hazards(env: EnvironmentDef) -> void:
	for y in rows:
		var x := 0
		while x < cols:
			var k := kind_at_cell(Vector2i(x, y))
			if k == "spikes" or k == "liquid":
				var start := x
				while x < cols and kind_at_cell(Vector2i(x, y)) == k:
					x += 1
				var def: HazardDef = env.spike_hazard if k == "spikes" else env.liquid_hazard
				if def == null:
					continue
				var r := Rect2(start * RF.TILE, y * RF.TILE, (x - start) * RF.TILE, RF.TILE)
				if k == "spikes":
					r = Rect2(r.position + Vector2(0, RF.TILE * 0.55), Vector2(r.size.x, RF.TILE * 0.45))
				else:
					r = Rect2(r.position + Vector2(0, RF.TILE * 0.2), Vector2(r.size.x, RF.TILE * 0.8))
				hazards.append({"rect": r, "def": def})
				var strip := HazardStrip.new()
				strip.setup(def, r, k)
				add_child(strip)
			else:
				x += 1


func _decorate(env: EnvironmentDef, rng: RandomNumberGenerator) -> void:
	if env.props.is_empty():
		return
	for m in markers:
		if m.meaning == "prop":
			_place_prop(env.props[rng.randi() % env.props.size()], m.foot)
	for x in cols:
		for y in range(1, rows):
			var k := kind_at_cell(Vector2i(x, y))
			if (k == "solid" or k == "block") and kind_at_cell(Vector2i(x, y - 1)) == "":
				if rng.randf() < env.prop_density:
					_place_prop(env.props[rng.randi() % env.props.size()], Vector2(x + 0.5, y) * RF.TILE)
				break


func _place_prop(vd: VisualDef, foot: Vector2) -> void:
	var v := ActorVisual.new()
	v.setup(vd, vd.size if vd.size != Vector2.ZERO else Vector2(64, 64))
	v.position = foot - Vector2(0, v.size.y * 0.5) + vd.offset
	v.z_index = -2
	add_child(v)
