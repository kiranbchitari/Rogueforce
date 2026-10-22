class_name Telegraph
extends Node2D
## Warns the player before an attack lands: a flashing outline, an aiming
## laser, or markers where shells will hit.

var kind := "flash"
var actor: Actor
var attack: AttackDef
var ctx: Dictionary
var duration := 0.4
var _t := 0.0


func setup(k: String, a: Actor, atk: AttackDef, c: Dictionary, d: float) -> void:
	kind = k
	actor = a
	attack = atk
	ctx = c
	duration = d
	z_index = 30


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration or not is_instance_valid(actor) or not actor.alive:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / duration
	var blink := 0.5 + 0.5 * sin(_t * 30.0)
	var red := Color(1.0, 0.15, 0.1, 0.4 + 0.6 * blink)
	match kind:
		"flash":
			var r := actor.get_hit_rect()
			r.position -= global_position
			draw_rect(r.grow(6.0), red, false, 3.0)
			_bang(Vector2(r.get_center().x, r.position.y - 22.0), red)
		"aim_line":
			var from := attack.muzzle_position(actor) - global_position
			var to: Vector2 = ctx.target - global_position
			var dir := (to - from).normalized()
			draw_line(from, from + dir * 1600.0, Color(1, 0.1, 0.1, 0.25 + 0.5 * k), 1.0 + 3.0 * k)
			draw_circle(to, 6.0 + 6.0 * blink, Color(1, 0.1, 0.1, 0.5))
		"ground_marker":
			for p in ctx.get("points", PackedVector2Array([ctx.target])):
				var lp: Vector2 = p - global_position
				draw_rect(Rect2(lp + Vector2(-26, -260), Vector2(52, 260)), Color(1, 0.1, 0.1, 0.08 + 0.1 * k))
				draw_line(lp + Vector2(-30, 0), lp + Vector2(30, 0), red, 4.0)
				draw_arc(lp, 18.0 + 10.0 * (1.0 - k), PI, TAU, 16, red, 3.0)
				_bang(lp + Vector2(0, -36), red)


func _bang(p: Vector2, c: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string_outline(font, p - Vector2(6, 0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 4, Color(0, 0, 0, c.a))
	draw_string(font, p - Vector2(6, 0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, c)
