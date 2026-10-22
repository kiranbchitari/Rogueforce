class_name ActorVisual
extends Node2D
## Draws an actor, prop or pickup from a VisualDef.
##   * manifest "sheet"  -> AnimatedSprite2D built from the sheet's animations
##   * manifest "single" -> Sprite2D
##   * missing asset     -> a procedural placeholder labelled with the asset id
## Gameplay code only calls play(), and sets facing / aim / tint.

var def: VisualDef
var size := Vector2(64, 64)
var facing := 1:
	set(v):
		facing = v
		_apply_flip()
var aim := Vector2.RIGHT
var tint := Color.WHITE:
	set(v):
		tint = v
		self_modulate = v
		if _sprite:
			_sprite.modulate = v
var label_text := ""
var anim := "idle"
var is_placeholder := true
## Set by the owner every frame so motion matches movement.
var move_speed := 0.0
var velocity := Vector2.ZERO
var grounded := true
## Draw a soft contact shadow under the feet.
var shadow := false

var _sprite: Node2D
var _t := 0.0
var _base_y := 0.0
var _rig: CutoutRig
var _rig_mode := ""
var _phase := 0.0
var _run := 0.0
var _recoil := 0.0


func setup(vd: VisualDef, size_hint: Vector2) -> void:
	def = vd if vd else VisualDef.new()
	size = def.size if def.size != Vector2.ZERO else size_hint
	position = def.offset
	var entry := Assets.get_entry(def.asset_id)
	if entry.get("type", "") == "sheet":
		var frames := Assets.get_sprite_frames(def.asset_id)
		if frames:
			var a := AnimatedSprite2D.new()
			a.sprite_frames = frames
			var fs: Vector2 = Assets.frame_size(def.asset_id)
			a.scale = Vector2.ONE * Assets.fit_scale(def.asset_id, size, fs)
			_sprite = a
	if _sprite == null:
		var tex := Assets.get_texture(def.asset_id)
		if tex:
			var s := Sprite2D.new()
			s.texture = tex
			s.scale = Vector2.ONE * Assets.fit_scale(def.asset_id, size, tex.get_size())
			_sprite = s
	if _sprite:
		is_placeholder = false
		_sprite.texture_filter = Assets.texture_filter(def.asset_id)
		_sprite.position = Assets.entry_offset(def.asset_id)
		_base_y = _sprite.position.y
		add_child(_sprite)
		_rig_mode = entry.get("rig", "")
		if _rig_mode == "biped":
			_build_rig(entry)
		_apply_flip()
		play("idle")
	else:
		Assets.report_missing(def.asset_id)


func _build_rig(entry: Dictionary) -> void:
	var tex: Texture2D
	var region: Rect2
	if _sprite is AnimatedSprite2D:
		tex = Assets.get_texture(def.asset_id)
		var fs := Assets.frame_size(def.asset_id)
		var cell: Array = entry.get("rig_frame", [0, 0])
		region = Rect2(Vector2(cell[0], cell[1]) * fs, fs)
	else:
		tex = (_sprite as Sprite2D).texture
		region = Rect2(Vector2.ZERO, tex.get_size())
	_rig = CutoutRig.new()
	_rig.build(tex, region, Assets.rig_info(def.asset_id, tex, region))
	_rig.scale = _sprite.scale
	_rig.position = _sprite.position
	add_child(_rig)


## Gun recoil: the torso kicks back briefly.
func kick() -> void:
	_recoil = 1.0


func play(anim_name: String) -> void:
	anim = anim_name
	if _rig:
		var use_rig := anim_name in ["idle", "run", "attack"]
		_rig.visible = use_rig
		_sprite.visible = not use_rig
		if use_rig:
			return
	if _sprite is AnimatedSprite2D:
		var a := _sprite as AnimatedSprite2D
		var frames := a.sprite_frames
		var pick := anim_name
		if not frames.has_animation(pick):
			pick = "idle" if frames.has_animation("idle") else frames.get_animation_names()[0]
		if a.animation != pick or not a.is_playing():
			a.play(pick)


func _apply_flip() -> void:
	if _sprite:
		# Art is authored facing right unless the manifest says otherwise.
		var faces_left: bool = Assets.get_entry(def.asset_id if def else &"").get("faces_left", false)
		_sprite.scale.x = absf(_sprite.scale.x) * (facing if not faces_left else -facing)
		if _rig:
			_rig.scale.x = absf(_rig.scale.x) * (facing if not faces_left else -facing)


func _process(delta: float) -> void:
	_t += delta
	_recoil = move_toward(_recoil, 0.0, delta * 12.0)
	if is_placeholder or shadow:
		queue_redraw()
	if is_placeholder:
		return
	if _rig and _rig.visible:
		_run = move_toward(_run, 1.0 if anim == "run" and move_speed > 5.0 else 0.0, delta * 6.0)
		# One full stride cycle covers roughly 1.6 body heights of ground.
		_phase += TAU * move_speed * delta / maxf(size.y * 1.6, 1.0)
		if _run < 0.05:
			_phase = lerpf(_phase, roundf(_phase / PI) * PI, delta * 8.0)
		var lean := clampf(aim.y * 0.45, -0.5, 0.5)
		_rig.pose(_run, _phase, lean, _recoil, sin(_t * 2.4))
		return
	match _rig_mode:
		"vehicle":
			var rumble := sin(_t * 47.0) * size.y * 0.008 if move_speed > 5.0 else sin(_t * 23.0) * size.y * 0.003
			_sprite.position.y = _base_y + rumble
			_sprite.rotation = clampf(velocity.x * 0.00008, -0.04, 0.04) * (1.0 if move_speed > 5.0 else 0.0)
		"hover":
			rotation = lerp_angle(rotation, clampf(velocity.x / 420.0, -1.0, 1.0) * 0.2, clampf(delta * 6.0, 0.0, 1.0))
			_sprite.position.y = _base_y + sin(_t * 3.2) * size.y * 0.03
		_:
			if _sprite is Sprite2D:
				_sprite.position.y = _base_y - (absf(sin(_t * 12.0)) * size.y * 0.04 if anim == "run" else 0.0)
	if _recoil > 0.0 and _sprite:
		_sprite.position.x = Assets.entry_offset(def.asset_id).x - _recoil * size.x * 0.04 * float(facing)


func _draw() -> void:
	if shadow and grounded:
		_draw_ellipse(Vector2(0, size.y * 0.5 - 2.0), Vector2(size.x * 0.42, maxf(size.y * 0.06, 4.0)), Color(0, 0, 0, 0.32))
	if not is_placeholder:
		return
	var c := def.placeholder_color
	var f := float(facing)
	var h := size * 0.5
	match def.placeholder_shape:
		"humanoid":
			_draw_humanoid(c, f, h)
		"drone":
			var bob := sin(_t * 10.0) * 2.0
			draw_circle(Vector2(0, bob), h.y * 0.7, c)
			draw_circle(Vector2(h.x * 0.25 * f, bob), h.y * 0.25, Color(1, 0.3, 0.2))
			for s in [-1.0, 1.0]:
				var rx: float = s * h.x * 0.9
				draw_line(Vector2(rx - 14, -h.y * 0.8 + bob), Vector2(rx + 14, -h.y * 0.8 + bob), c.lightened(0.4), 3.0)
			draw_line(Vector2(0, bob), Vector2(0, bob) + aim * h.x, c.darkened(0.4), 4.0)
		"turret":
			draw_rect(Rect2(-h.x, 0, size.x, h.y), c.darkened(0.3))
			draw_circle(Vector2(0, 0), h.x * 0.6, c)
			draw_line(Vector2.ZERO, aim * h.x * 1.3, c.darkened(0.5), 10.0)
		"tank":
			draw_rect(Rect2(-h.x, -h.y * 0.1, size.x, h.y * 0.75), c)
			draw_rect(Rect2(-h.x * 0.95, h.y * 0.55, size.x * 0.95, h.y * 0.45), c.darkened(0.5))
			for i in 6:
				draw_circle(Vector2(-h.x * 0.8 + i * h.x * 0.32, h.y * 0.78), h.y * 0.16, c.darkened(0.25))
			draw_rect(Rect2(-h.x * 0.45, -h.y * 0.75, h.x * 0.9, h.y * 0.7), c.lightened(0.1))
			draw_line(Vector2(0, -h.y * 0.45), Vector2(0, -h.y * 0.45) + aim * h.x * 1.1, c.darkened(0.4), 12.0)
		"heli":
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(f, 1))
			draw_rect(Rect2(h.x * 0.1, -h.y * 0.25, h.x * 0.9, h.y * 0.35), c.darkened(0.2))
			_draw_ellipse(Vector2(-h.x * 0.2, 0), Vector2(h.x * 0.55, h.y * 0.6), c)
			draw_circle(Vector2(-h.x * 0.55, -h.y * 0.05), h.y * 0.28, Color(0.6, 0.85, 1.0, 0.9))
			var blade := absf(sin(_t * 30.0)) * h.x * 1.1
			draw_line(Vector2(-h.x * 0.2 - blade, -h.y * 0.7), Vector2(-h.x * 0.2 + blade, -h.y * 0.7), Color(0.9, 0.9, 0.9, 0.8), 4.0)
			draw_rect(Rect2(-h.x * 0.6, h.y * 0.55, h.x * 0.9, 5), c.darkened(0.5))
			draw_set_transform(Vector2.ZERO)
		"creature":
			_draw_ellipse(Vector2.ZERO, h, c)
			for s in [-0.3, 0.3]:
				draw_circle(Vector2(h.x * (0.35 * f + s * 0.5), -h.y * 0.3), h.y * 0.12, Color(1, 0.9, 0.2))
		"mech":
			draw_rect(Rect2(-h.x * 0.6, -h.y, size.x * 0.6, h.y), c)
			draw_rect(Rect2(-h.x * 0.6, 0, h.x * 0.35, h.y), c.darkened(0.3))
			draw_rect(Rect2(h.x * 0.25, 0, h.x * 0.35, h.y), c.darkened(0.3))
			draw_line(Vector2(0, -h.y * 0.5), Vector2(0, -h.y * 0.5) + aim * h.x, c.darkened(0.5), 12.0)
		"crate":
			draw_rect(Rect2(-h, size), c)
			draw_rect(Rect2(-h, size), c.darkened(0.4), false, 3.0)
			draw_line(-h, h, c.darkened(0.4), 3.0)
			draw_line(Vector2(h.x, -h.y), Vector2(-h.x, h.y), c.darkened(0.4), 3.0)
		"barrel":
			draw_rect(Rect2(-h, size), c)
			for y in [-0.5, 0.5]:
				draw_rect(Rect2(-h.x, h.y * y - 3, size.x, 6), c.darkened(0.4))
			draw_circle(Vector2(0, 0), h.x * 0.35, Color(1, 0.85, 0.1))
		"capsule":
			var bob := sin(_t * 4.0) * 3.0
			_draw_ellipse(Vector2(0, bob), h, c)
			_draw_ellipse(Vector2(0, bob), h * 0.8, c.lightened(0.3))
		"orb":
			draw_circle(Vector2.ZERO, h.x, c)
			draw_circle(Vector2.ZERO, h.x * (0.5 + 0.1 * sin(_t * 6.0)), c.lightened(0.5))
		"plant":
			for i in 5:
				var a := -PI * 0.5 + (i - 2) * 0.35
				draw_line(Vector2(0, h.y), Vector2(0, h.y) + Vector2.from_angle(a) * size.y, c, 6.0)
		"rock":
			draw_colored_polygon(PackedVector2Array([Vector2(-h.x, h.y), Vector2(-h.x * 0.6, -h.y * 0.4), Vector2(0, -h.y), Vector2(h.x * 0.7, -h.y * 0.3), Vector2(h.x, h.y)]), c)
		_:
			draw_rect(Rect2(-h, size), c)
			draw_rect(Rect2(-h, size), c.darkened(0.5), false, 3.0)
	if label_text != "":
		_draw_text(label_text, Vector2(0, 7), 20, Color.WHITE)
	if Assets.show_placeholder_labels and def.asset_id != &"":
		_draw_text(String(def.asset_id), Vector2(0, h.y + 12), 10, Color(1, 1, 1, 0.75))


func _draw_humanoid(c: Color, f: float, h: Vector2) -> void:
	var crouch := anim == "crouch"
	var top := -h.y * (0.2 if crouch else 1.0)
	var stride := sin(_t * 14.0) * 8.0 if anim == "run" else 0.0
	if not crouch:
		draw_line(Vector2(-6, h.y * 0.2), Vector2(-6 + stride, h.y), c.darkened(0.45), 9.0)
		draw_line(Vector2(6, h.y * 0.2), Vector2(6 - stride, h.y), c.darkened(0.45), 9.0)
	else:
		draw_rect(Rect2(-h.x, h.y * 0.55, size.x, h.y * 0.45), c.darkened(0.45))
	var torso := Rect2(-h.x * 0.6, top + h.y * 0.35, size.x * 0.6, (h.y * 0.85) if not crouch else h.y * 0.55)
	draw_rect(torso, c)
	var head := Vector2(0, top + h.y * 0.18)
	draw_circle(head, h.x * 0.42, c.lightened(0.25))
	draw_rect(Rect2(head + Vector2(f * 2.0 - 4.0 + f * 4.0, -3), Vector2(10, 6)), Color(0.1, 0.1, 0.1))
	var shoulder := Vector2(0, top + h.y * 0.55)
	draw_line(shoulder, shoulder + aim * h.x * 1.25, Color(0.15, 0.15, 0.15), 7.0)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


func _draw_text(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string_outline(font, pos - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, 0.8))
	draw_string(font, pos - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
