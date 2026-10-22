class_name BossBar
extends Control
## Boss health bar. "segmented" style marks each phase threshold.

var def: BossDef
var value := 1.0
var shown := 1.0
var phase := 0


func setup(d: BossDef) -> void:
	def = d
	value = 1.0
	shown = 1.0


func set_value(v: float) -> void:
	value = clampf(v, 0.0, 1.0)


func _process(delta: float) -> void:
	shown = move_toward(shown, value, delta * 0.6)
	queue_redraw()


func _draw() -> void:
	if def == null:
		return
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0, 0, 0, 0.7))
	draw_rect(Rect2(r.position, Vector2(r.size.x * shown, r.size.y)), Color(1, 1, 1, 0.5))
	draw_rect(Rect2(r.position, Vector2(r.size.x * value, r.size.y)), def.health_bar_color)
	if def.health_bar_style == "segmented":
		for p in def.phases:
			if p.enter_at_health < 1.0:
				var x := r.size.x * p.enter_at_health
				draw_line(Vector2(x, -4), Vector2(x, r.size.y + 4), Color(1, 1, 1, 0.9), 3.0)
	draw_rect(r, Color(1, 1, 1, 0.8), false, 2.0)
