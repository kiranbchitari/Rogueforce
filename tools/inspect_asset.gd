extends SceneTree
## Inspects an incoming image and suggests how to integrate it. It never
## assumes a sprite sheet: it classifies the file as a background/illustration,
## single sprite, uniform sprite sheet, tile sheet, or a catalog of separate
## objects, and prints a suggested asset_manifest.json entry.
##
##   godot --headless --path . -s res://tools/inspect_asset.gd -- path/to/image.png [--id enemy.mech] [--split out_dir]
##
## --split writes each object of a catalog to its own PNG (trimmed).

const MAX_SCAN := 400


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <image.png> [--id asset.id] [--split out_dir]")
		quit(2)
		return
	var path := args[0]
	var id := _arg(args, "--id", path.get_file().get_basename())
	var split_dir := _arg(args, "--split", "")
	var img := Image.load_from_file(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
	if img == null or img.is_empty():
		printerr("Could not load image: ", path)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var report := inspect(img)
	print("\n%s  (%dx%d)" % [path, img.get_width(), img.get_height()])
	print("  transparent pixels: %d%%" % int(report.transparent * 100.0))
	print("  verdict: %s" % report.kind)
	for note in report.notes:
		print("  - " + note)
	var entry: Dictionary = report.entry
	entry["path"] = "res://assets/<folder>/%s" % path.get_file()
	print("\nSuggested manifest entry:\n  \"%s\": %s" % [id, JSON.stringify(entry)])
	if split_dir != "" and report.kind == "catalog":
		DirAccess.make_dir_recursive_absolute(split_dir)
		var i := 0
		for r in report.boxes:
			var out := "%s/%s_%02d.png" % [split_dir, id.replace(".", "_"), i]
			img.get_region(r).save_png(out)
			print("  wrote ", out)
			i += 1
	quit()


func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var i := args.find(name)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback


func inspect(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var step := maxi(1, int(ceil(maxf(w, h) / float(MAX_SCAN))))
	var gw := int(ceil(w / float(step)))
	var gh := int(ceil(h / float(step)))
	var mask := PackedByteArray()
	mask.resize(gw * gh)
	var transparent := 0
	for gy in gh:
		for gx in gw:
			var a := img.get_pixel(mini(gx * step, w - 1), mini(gy * step, h - 1)).a
			if a > 0.08:
				mask[gy * gw + gx] = 1
			else:
				transparent += 1
	var t_frac := transparent / float(gw * gh)
	var notes: Array[String] = []

	if t_frac < 0.03:
		var tile := _tile_size(img)
		if tile > 0:
			notes.append("Opaque image with strong seams every %dpx: looks like a tile sheet." % tile)
			notes.append("Name the tiles you want (ground_top, ground_fill, platform, block) by [column, row].")
			return {"kind": "tile sheet", "transparent": t_frac, "notes": notes,
				"entry": {"type": "tiles", "tile_size": [tile, tile], "tiles": {"ground_top": [0, 0], "ground_fill": [1, 0], "platform": [2, 0], "block": [3, 0]}}}
		notes.append("Fully opaque: a background illustration or parallax layer. Use it as a ParallaxLayerDef asset.")
		if float(w) / h < 1.5:
			notes.append("Narrow for a scrolling layer; make sure the left and right edges tile, or widen it.")
		return {"kind": "background / single illustration", "transparent": t_frac, "notes": notes, "entry": {"type": "single"}}

	var boxes := _components(mask, gw, gh, step, w, h)
	if boxes.size() <= 1:
		notes.append("One object on a transparent background: a single sprite (prop, pickup, boss part, still enemy).")
		return {"kind": "single sprite", "transparent": t_frac, "notes": notes, "entry": {"type": "single", "fit": "height"}, "boxes": boxes}

	var grid := _grid(boxes, w, h)
	if not grid.is_empty():
		notes.append("%d objects on a regular %d x %d grid of %dx%d cells: a sprite sheet." % [boxes.size(), grid.cols, grid.rows, grid.cw, grid.ch])
		notes.append("Check each row is one animation; rename rows in \"animations\" to idle/run/jump/crouch/attack.")
		var anims := {}
		var names := ["idle", "run", "jump", "crouch", "attack", "hurt", "death"]
		for r in grid.rows:
			anims[names[r] if r < names.size() else "row%d" % r] = {"row": r, "frames": grid.per_row[r], "fps": 10}
		return {"kind": "sprite sheet", "transparent": t_frac, "notes": notes, "boxes": boxes,
			"entry": {"type": "sheet", "frame_size": [grid.cw, grid.ch], "animations": anims}}

	notes.append("%d separate objects of different sizes, not on a grid: an asset catalog." % boxes.size())
	notes.append("Split it with --split <dir>, then register each piece as its own \"single\" entry.")
	for b in boxes:
		notes.append("object at %d,%d size %dx%d" % [b.position.x, b.position.y, b.size.x, b.size.y])
	return {"kind": "catalog", "transparent": t_frac, "notes": notes, "boxes": boxes, "entry": {"type": "single"}}


## Bounding boxes (in image pixels) of opaque islands, after merging close ones.
func _components(mask: PackedByteArray, gw: int, gh: int, step: int, w: int, h: int) -> Array[Rect2i]:
	var label := PackedInt32Array()
	label.resize(gw * gh)
	var boxes: Array[Rect2i] = []
	var min_cells := maxi(4, int(gw * gh * 0.0005))
	for start in gw * gh:
		if mask[start] == 0 or label[start] != 0:
			continue
		var stack := [start]
		label[start] = boxes.size() + 1
		var x0 := gw
		var y0 := gh
		var x1 := 0
		var y1 := 0
		var count := 0
		while not stack.is_empty():
			var i: int = stack.pop_back()
			var x := i % gw
			var y := i / gw
			count += 1
			x0 = mini(x0, x)
			y0 = mini(y0, y)
			x1 = maxi(x1, x)
			y1 = maxi(y1, y)
			# 2-cell reach bridges anti-aliasing gaps inside one object.
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= gw or ny >= gh:
						continue
					var j := ny * gw + nx
					if mask[j] == 1 and label[j] == 0:
						label[j] = boxes.size() + 1
						stack.append(j)
		if count >= min_cells:
			boxes.append(Rect2i(x0 * step, y0 * step, mini((x1 - x0 + 1) * step, w - x0 * step), mini((y1 - y0 + 1) * step, h - y0 * step)))
	return boxes


## Detects a uniform grid: equal-sized cells whose centres line up in rows/columns.
func _grid(boxes: Array[Rect2i], w: int, h: int) -> Dictionary:
	var rows := _clusters(boxes.map(func(b): return b.get_center().y), h)
	var cols := _clusters(boxes.map(func(b): return b.get_center().x), w)
	if rows.is_empty() or cols.is_empty():
		return {}
	var cw := w / cols.size()
	var ch := h / rows.size()
	for b in boxes:
		if b.size.x > cw * 1.05 or b.size.y > ch * 1.05:
			return {}
	var per_row := []
	for r in rows.size():
		per_row.append(boxes.filter(func(b): return int(b.get_center().y / ch) == r).size())
	return {"cols": cols.size(), "rows": rows.size(), "cw": cw, "ch": ch, "per_row": per_row}


## Groups 1-D positions into evenly spaced clusters. Empty if spacing is irregular.
func _clusters(values: Array, extent: int) -> Array:
	values.sort()
	var groups := []
	for v in values:
		if groups.is_empty() or v - groups[-1][-1] > extent * 0.04:
			groups.append([v])
		else:
			groups[-1].append(v)
	var centres := groups.map(func(g): return g.reduce(func(a, b): return a + b, 0.0) / g.size())
	if centres.size() < 2:
		return centres
	var gap: float = (centres[-1] - centres[0]) / (centres.size() - 1)
	for i in range(1, centres.size()):
		if absf((centres[i] - centres[i - 1]) - gap) > gap * 0.2:
			return []
	return centres


## For opaque images: finds a tile size whose grid lines show strong seams.
func _tile_size(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	for t in [128, 96, 64, 48, 32, 16]:
		if w % t != 0 or h % t != 0 or (w / t) * (h / t) < 4 or w / t > 64:
			continue
		var seam := 0.0
		var inner := 0.0
		var n := 0
		for x in range(t, w, t):
			for y in range(0, h, maxi(1, h / 64)):
				seam += _diff(img.get_pixel(x - 1, y), img.get_pixel(x, y))
				inner += _diff(img.get_pixel(x - t / 2 - 1, y), img.get_pixel(x - t / 2, y))
				n += 1
		if n > 0 and seam / n > 0.08 and seam > inner * 2.5:
			return t
	return 0


func _diff(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
