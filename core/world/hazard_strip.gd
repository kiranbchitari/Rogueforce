class_name HazardStrip
extends Node2D
## Draws a run of spikes or liquid. Uses the hazard's asset (tiled) if present.

var def: HazardDef
var rect: Rect2
var kind := "spikes"
var _tex: Texture2D
var _t := 0.0


func setup(d: HazardDef, r: Rect2, k: String) -> void:
	def = d
	rect = r
	kind = k
	_tex = Assets.get_texture(d.asset_id)
	if _tex == null:
		Assets.report_missing(d.asset_id)
	z_index = 3 if kind == "liquid" else 1


func _process(delta: float) -> void:
	if kind == "liquid" and _tex == null:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if _tex:
		draw_texture_rect(_tex, rect, true)
		return
	if kind == "spikes":
		var n := int(rect.size.x / 16.0)
		for i in n:
			var x := rect.position.x + i * 16.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, rect.end.y), Vector2(x + 8, rect.position.y), Vector2(x + 16, rect.end.y)]), def.color)
			draw_line(Vector2(x + 8, rect.position.y), Vector2(x + 8, rect.position.y + 6), def.surface_color, 2.0)
	else:
		draw_rect(rect, def.color)
		var pts := PackedVector2Array()
		var x := rect.position.x
		while x <= rect.end.x:
			pts.append(Vector2(x, rect.position.y + sin(x * 0.05 + _t * 3.0) * 3.0))
			x += 8.0
		draw_polyline(pts, def.surface_color, 3.0)
