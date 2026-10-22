class_name CheckpointFlag
extends Node2D
## Checkpoint or exit marker drawn at a layout C / E symbol.

var is_exit := false
var reached := false:
	set(v):
		reached = v
		queue_redraw()


func _ready() -> void:
	z_index = -1


func _draw() -> void:
	draw_line(Vector2(0, 0), Vector2(0, -120), Color(0.8, 0.8, 0.8), 4.0)
	var c := Color(0.2, 0.9, 0.3) if reached else Color(0.9, 0.3, 0.2)
	if is_exit:
		c = Color(1.0, 0.85, 0.2)
		draw_string(ThemeDB.fallback_font, Vector2(-24, -132), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, c)
	draw_colored_polygon(PackedVector2Array([Vector2(2, -120), Vector2(50, -104), Vector2(2, -88)]), c)
