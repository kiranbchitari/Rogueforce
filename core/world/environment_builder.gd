class_name EnvironmentBuilder
extends RefCounted
## Turns an EnvironmentDef into scene nodes: sky, parallax layers, lighting
## tint, haze and weather. Nothing here creates collision.


## Builds the visual world under `parent`. Returns {"weather": Node2D or null}
## so the caller can attach weather to its camera.
static func build(env: EnvironmentDef, parent: Node, level_size: Vector2) -> Dictionary:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -20
	parent.add_child(sky_layer)
	var sky := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, env.sky_top_color)
	grad.gradient.set_color(1, env.sky_bottom_color)
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(0, 1)
	sky.texture = grad
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_layer.add_child(sky)

	for i in env.parallax_layers.size():
		parent.add_child(_make_parallax(env.parallax_layers[i], i, level_size))

	var tint := CanvasModulate.new()
	tint.color = env.ambient_tint
	parent.add_child(tint)

	if env.fog_color.a > 0.0:
		var fog_layer := CanvasLayer.new()
		fog_layer.layer = 5
		parent.add_child(fog_layer)
		var fog := ColorRect.new()
		fog.color = env.fog_color
		fog.set_anchors_preset(Control.PRESET_FULL_RECT)
		fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fog_layer.add_child(fog)

	return {"weather": make_weather(env.weather, env.weather_intensity)}


static func _make_parallax(def: ParallaxLayerDef, index: int, level_size: Vector2) -> Parallax2D:
	var p := Parallax2D.new()
	p.scroll_scale = Vector2(def.scroll_scale, 1.0)
	p.z_index = 40 + index if def.foreground else -60 + index
	var tex := Assets.get_texture(def.asset_id)
	if tex == null:
		Assets.report_missing(def.asset_id)
		tex = placeholder_layer(def)
	var scale := float(def.height) / float(tex.get_height())
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.scale = Vector2.ONE * scale
	spr.modulate = def.modulate
	spr.texture_filter = Assets.texture_filter(def.asset_id)
	spr.position = Vector2(0, level_size.y - def.height + def.y_offset)
	p.add_child(spr)
	var w := tex.get_width() * scale
	p.repeat_size = Vector2(w, 0)
	p.repeat_times = int(ceil(RF.VIEW_SIZE.x / w)) + 2
	p.autoscroll = Vector2(-def.autoscroll, 0)
	return p


## Procedural silhouette used until real background art exists. Tiles seamlessly.
static func placeholder_layer(def: ParallaxLayerDef) -> Texture2D:
	# Drawn at 2x so silhouettes stay sharp on 4K displays.
	var w := 2560
	var h := maxi(def.height, 16) * 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := def.placeholder_color
	var rng := RandomNumberGenerator.new()
	rng.seed = def.placeholder_seed
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	match def.placeholder_shape:
		"mountains", "ice_peaks":
			for x in w:
				var u := float(x) / w * TAU
				var ridge := 1.0 - absf(sin(u * 1.5 + p1))
				var v := 0.35 + 0.4 * ridge * ridge + 0.08 * sin(u * 7.0 + p2) + 0.03 * sin(u * 23.0)
				_column(img, x, int(v * h), c, def.placeholder_shape == "ice_peaks")
		"hills":
			for x in w:
				var u := float(x) / w * TAU
				_column(img, x, int((0.45 + 0.18 * sin(u * 2.0 + p1) + 0.1 * sin(u * 5.0 + p2)) * h), c)
		"dunes":
			for x in w:
				var u := float(x) / w * TAU
				var s := sin(u * 3.0 + p1)
				_column(img, x, int((0.35 + 0.15 * s + 0.08 * s * s * s + 0.05 * sin(u * 8.0 + p2)) * h), c)
		"mesa":
			for x in w:
				var u := float(x) / w * TAU
				var s := clampf(sin(u * 2.0 + p1) * 3.0, -1.0, 1.0)
				_column(img, x, int((0.4 + 0.3 * s + 0.02 * sin(u * 30.0)) * h), c)
		"jungle_canopy", "trees", "foliage":
			var base := 0.25 if def.placeholder_shape != "foliage" else 0.0
			for x in w:
				_column(img, x, int(base * h), c)
			var n := 14 if def.placeholder_shape == "jungle_canopy" else 9
			for i in n:
				var cx := int((i + rng.randf_range(0.0, 0.6)) * w / n)
				var r := rng.randi_range(int(h * 0.12), int(h * 0.24))
				var top := rng.randi_range(int(h * 0.2), int(h * 0.5))
				if def.placeholder_shape != "foliage":
					img.fill_rect(Rect2i(cx - 6, top, 12, h - top), c.darkened(0.25))
				for k in 3:
					var ox := rng.randi_range(-r, r)
					_circle(img, cx + ox, top + rng.randi_range(-r / 2, r / 2), r, c.lightened(0.04 * k))
					_circle(img, cx + ox + w, top, r, c)
					_circle(img, cx + ox - w, top, r, c)
		"buildings":
			var x := 0
			while x < w:
				var bw := rng.randi_range(60, 140)
				var bh := rng.randi_range(int(h * 0.35), int(h * 0.95))
				img.fill_rect(Rect2i(x, h - bh, mini(bw, w - x), bh), c)
				for wy in range(h - bh + 12, h - 10, 22):
					for wx in range(x + 8, mini(x + bw - 8, w - 6), 18):
						if rng.randf() < 0.35:
							img.fill_rect(Rect2i(wx, wy, 8, 10), c.lightened(0.35))
				x += bw + rng.randi_range(4, 30)
		"clouds":
			for i in 8:
				var cx := rng.randi_range(0, w)
				var cy := rng.randi_range(int(h * 0.1), int(h * 0.6))
				for k in 4:
					var r := rng.randi_range(18, 46)
					var ox := rng.randi_range(-50, 50)
					_circle(img, cx + ox, cy + rng.randi_range(-10, 10), r, c)
					_circle(img, cx + ox - w, cy, r, c)
		"stalactites":
			img.fill_rect(Rect2i(0, 0, w, int(h * 0.15)), c)
			var x := 0
			while x < w:
				var sw := rng.randi_range(20, 70)
				var sl := rng.randi_range(int(h * 0.2), int(h * 0.8))
				for k in sl:
					var half := int(sw * 0.5 * (1.0 - float(k) / sl))
					img.fill_rect(Rect2i(clampi(x + sw / 2 - half, 0, w - 1), int(h * 0.15) + k, maxi(half * 2, 1), 1), c)
				x += sw + rng.randi_range(0, 40)
		"fog":
			for y in h:
				var a := c.a * sin(PI * float(y) / h)
				img.fill_rect(Rect2i(0, y, w, 1), Color(c, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _column(img: Image, x: int, height: int, c: Color, snow_cap := false) -> void:
	var h := img.get_height()
	height = clampi(height, 0, h)
	if height <= 0:
		return
	img.fill_rect(Rect2i(x, h - height, 1, height), c)
	img.fill_rect(Rect2i(x, h - height, 1, mini(3, height)), c.lightened(0.15))
	if snow_cap:
		img.fill_rect(Rect2i(x, h - height, 1, mini(int(height * 0.12), height)), Color(0.95, 0.97, 1.0, c.a))


static func _circle(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for dy in range(-r, r + 1):
		var half := int(sqrt(float(r * r - dy * dy)))
		var y := cy + dy
		if y < 0 or y >= img.get_height():
			continue
		var x0 := clampi(cx - half, 0, img.get_width())
		var x1 := clampi(cx + half, 0, img.get_width())
		if x1 > x0:
			img.fill_rect(Rect2i(x0, y, x1 - x0, 1), c)


static func make_weather(kind: String, intensity: float) -> Node2D:
	if kind == "none":
		return null
	var p := CPUParticles2D.new()
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.z_index = 45
	var view := RF.VIEW_SIZE
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex_size := Vector2i(2, 2)
	match kind:
		"rain":
			tex_size = Vector2i(2, 16)
			p.amount = int(260 * intensity)
			p.lifetime = 0.9
			p.position = Vector2(100, -view.y * 0.5 - 40)
			p.emission_rect_extents = Vector2(view.x * 0.7, 10)
			p.direction = Vector2(-0.2, 1)
			p.spread = 2.0
			p.initial_velocity_min = 950.0
			p.initial_velocity_max = 1150.0
			p.color = Color(0.75, 0.85, 1.0, 0.45)
		"snow", "ash":
			p.amount = int(180 * intensity)
			p.lifetime = 6.0
			p.position = Vector2(150, -view.y * 0.5 - 20)
			p.emission_rect_extents = Vector2(view.x * 0.7, 10)
			p.direction = Vector2(-0.3, 1)
			p.spread = 25.0
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 130.0
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.5
			p.color = Color(1, 1, 1, 0.85) if kind == "snow" else Color(0.5, 0.5, 0.5, 0.7)
		"sand":
			tex_size = Vector2i(14, 2)
			p.amount = int(240 * intensity)
			p.lifetime = 1.8
			p.position = Vector2(view.x * 0.5 + 40, 0)
			p.emission_rect_extents = Vector2(10, view.y * 0.55)
			p.direction = Vector2(-1, 0.08)
			p.spread = 6.0
			p.initial_velocity_min = 700.0
			p.initial_velocity_max = 950.0
			p.color = Color(0.95, 0.8, 0.55, 0.4)
		"embers", "spores":
			p.amount = int(90 * intensity)
			p.lifetime = 4.0
			p.position = Vector2(0, view.y * 0.5 + 20)
			p.emission_rect_extents = Vector2(view.x * 0.6, 10)
			p.direction = Vector2(0.1, -1)
			p.spread = 30.0
			p.initial_velocity_min = 50.0
			p.initial_velocity_max = 140.0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 3.0
			p.color = Color(1.0, 0.55, 0.15, 0.9) if kind == "embers" else Color(0.6, 1.0, 0.5, 0.6)
	img = Image.create(tex_size.x, tex_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	p.particle_flag_align_y = kind == "rain"
	p.preprocess = p.lifetime
	return p
