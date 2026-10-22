class_name ScreenBase
extends Control
## Small helper for menu screens built in code.

var box: VBoxContainer


func _build_frame(top_color := Color(0.06, 0.08, 0.07), bottom_color := Color(0.16, 0.12, 0.08)) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.set_color(0, top_color)
	g.gradient.set_color(1, bottom_color)
	g.fill_to = Vector2(0, 1)
	bg.texture = g
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(760, 0)
	center.add_child(box)


func add_text(text: String, font_size := 20, color := Color(0.9, 0.9, 0.85), align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	box.add_child(l)
	return l


func add_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(action)
	box.add_child(b)
	return b


func add_gap(h := 12.0) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	box.add_child(c)


func clear() -> void:
	for c in box.get_children():
		c.queue_free()
