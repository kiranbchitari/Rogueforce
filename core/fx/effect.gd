class_name Effect
extends Node2D
## One-shot visual effect. If the manifest has a sheet for "fx.<kind>" it is
## played; otherwise a procedural version is drawn.

var kind := "explosion"
var size := 1.0
var color := Color(1, 0.7, 0.2)
var duration := 0.5
var text := ""
var _t := 0.0
var _debris: Array[Dictionary] = []


func setup(k: String, s := 1.0, c := Color(1, 0.7, 0.2)) -> void:
	kind = k
	size = s
	color = c
	z_index = 20
	match kind:
		"explosion":
			duration = 0.55
			for i in int(8 * size) + 4:
				_debris.append({"p": Vector2.ZERO, "v": Vector2.from_angle(randf() * TAU) * randf_range(120, 380) * sqrt(size), "r": randf_range(2, 5) * sqrt(size)})
		"spark":
			duration = 0.12
		"ping":
			duration = 0.16
		"muzzle":
			duration = 0.05
		"popup":
			duration = 0.9
	var frames := Assets.get_sprite_frames(StringName("fx." + kind))
	if frames:
		var a := AnimatedSprite2D.new()
		a.sprite_frames = frames
		a.scale = Vector2.ONE * size
		add_child(a)
		a.play(frames.get_animation_names()[0])
		a.animation_finished.connect(queue_free)
		duration = 999.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	for d in _debris:
		d.v.y += 900.0 * delta
		d.p += d.v * delta
	if kind == "popup":
		position.y -= 40.0 * delta
	queue_redraw()


func _draw() -> void:
	if get_child_count() > 0:
		return
	var k := _t / duration
	match kind:
		"explosion":
			var r := 50.0 * size * (0.4 + k)
			draw_circle(Vector2.ZERO, r, Color(1.0, 0.6, 0.15, 1.0 - k))
			draw_circle(Vector2.ZERO, r * 0.65, Color(1.0, 0.95, 0.6, 1.0 - k))
			draw_arc(Vector2.ZERO, r * 1.2, 0, TAU, 24, Color(0.3, 0.3, 0.3, (1.0 - k) * 0.6), 4.0 * size)
			for d in _debris:
				draw_circle(d.p, d.r, Color(0.25, 0.2, 0.15, 1.0 - k))
		"spark":
			for i in 5:
				var dir := Vector2.from_angle(i * TAU / 5.0 + 0.4)
				draw_line(dir * 3.0, dir * (6.0 + 12.0 * k), Color(color, 1.0 - k), 2.0)
		"ping":
			draw_arc(Vector2.ZERO, 6.0 + 14.0 * k, 0, TAU, 16, Color(1, 1, 1, 1.0 - k), 2.0)
		"muzzle":
			draw_circle(Vector2.ZERO, 12.0, color)
			draw_circle(Vector2.ZERO, 6.0, Color.WHITE)
		"popup":
			var font := ThemeDB.fallback_font
			draw_string_outline(font, Vector2(-20, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 40, 18, 4, Color(0, 0, 0, 1.0 - k))
			draw_string(font, Vector2(-20, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 40, 18, Color(1, 0.9, 0.3, 1.0 - k))
